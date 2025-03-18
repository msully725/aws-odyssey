from aws_cdk import (
    Stack,
    aws_s3 as s3,
    aws_lambda as lambda_,
    aws_iam as iam,
    aws_scheduler as scheduler,
    aws_sns as sns,
    aws_sns_subscriptions as subscriptions,
    aws_cloudwatch as cloudwatch,
    aws_cloudwatch_actions as cloudwatch_actions,
    Duration,
    RemovalPolicy,
    CfnOutput,
    DockerImage,
    AssetHashType
)
from constructs import Construct
import os
from dotenv import load_dotenv
from pathlib import Path
from .constants import (
    STACK_NAME,
    STACK_DESCRIPTION,
    LAMBDA_HANDLER,
    LAMBDA_RUNTIME,
    LAMBDA_MEMORY,
    LAMBDA_TIMEOUT,
    LAMBDA_ENV_VARS,
    ENV_VARS,
    TAGS
)

# Load environment variables
env_path = Path(__file__).parents[2] / '.env'
load_dotenv(dotenv_path=env_path)

class BackupStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, description=STACK_DESCRIPTION, **kwargs)

        # Create SNS Topic for alerts
        alerts_topic = sns.Topic(
            self,
            "BackupAlertsTopic",
            display_name="SFTP Backup Alerts"
        )

        # Add email subscription to SNS topic if email is provided
        if 'ALERT_EMAIL' in ENV_VARS:
            alerts_topic.add_subscription(
                subscriptions.EmailSubscription(ENV_VARS['ALERT_EMAIL'])
            )

        # Create S3 bucket for backups with specified name
        self.backup_bucket = s3.Bucket(
            self,
            "BackupBucket",
            bucket_name=ENV_VARS["S3_BUCKET"],
            versioned=True,
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[
                s3.LifecycleRule(
                    transitions=[
                        s3.Transition(
                            storage_class=s3.StorageClass.INTELLIGENT_TIERING,
                            transition_after=Duration.days(30)
                        )
                    ]
                )
            ]
        )

        # Create Lambda execution role
        lambda_role = iam.Role(
            self,
            "BackupLambdaRole",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AWSLambdaBasicExecutionRole"
                )
            ]
        )

        # Add permissions to access S3 and Secrets Manager
        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:ListBucket"
                ],
                resources=[
                    self.backup_bucket.bucket_arn,
                    f"{self.backup_bucket.bucket_arn}/*"
                ]
            )
        )

        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "secretsmanager:GetSecretValue"
                ],
                resources=[
                    f"arn:aws:secretsmanager:{self.region}:{self.account}:secret:{ENV_VARS['SECRET_NAME']}-*"
                ]
            )
        )

        # Add permission for Lambda to put custom metrics
        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "cloudwatch:PutMetricData"
                ],
                resources=["*"]
            )
        )

        # Create Lambda function with bundling options
        self.lambda_function = lambda_.Function(
            self,
            "BackupFunction",
            runtime=lambda_.Runtime(LAMBDA_RUNTIME),
            handler=LAMBDA_HANDLER,
            code=lambda_.Code.from_asset(
                "../",
                bundling={
                    "image": DockerImage.from_registry("public.ecr.aws/sam/build-python3.9:latest"),
                    "command": [
                        "bash", "-c",
                        """
                        pip install --platform manylinux2014_x86_64 \
                            --target=/asset-output \
                            --implementation cp \
                            --python-version 3.9 \
                            --only-binary=:all: --upgrade \
                            -r requirements.txt && \
                        cp backup-service.py /asset-output/
                        """
                    ]
                }
            ),
            memory_size=LAMBDA_MEMORY,
            timeout=Duration.seconds(LAMBDA_TIMEOUT),
            environment={
                **LAMBDA_ENV_VARS,
                "S3_BUCKET": self.backup_bucket.bucket_name
            },
            role=lambda_role
        )

        # Create EventBridge Scheduler role
        scheduler_role = iam.Role(
            self,
            "SchedulerRole",
            assumed_by=iam.ServicePrincipal("scheduler.amazonaws.com"),
            description="Role for EventBridge Scheduler to invoke Lambda function"
        )

        # Allow scheduler to invoke the Lambda function
        scheduler_role.add_to_policy(
            iam.PolicyStatement(
                actions=["lambda:InvokeFunction"],
                resources=[self.lambda_function.function_arn]
            )
        )

        # Create EventBridge Schedule to trigger Lambda daily at 5 AM UTC (midnight EST)
        schedule = scheduler.CfnSchedule(
            self,
            "DailyBackupSchedule",
            schedule_expression="cron(0 5 * * ? *)",  # 5 AM UTC daily
            flexible_time_window={
                "mode": "OFF"
            },
            target={
                "arn": self.lambda_function.function_arn,
                "roleArn": scheduler_role.role_arn
            },
            description="Triggers SFTP backup Lambda function daily at 5 AM UTC"
        )

        # Create CloudWatch Alarms

        # 1. Lambda Error Alarm
        lambda_errors_alarm = cloudwatch.Alarm(
            self,
            "LambdaErrorsAlarm",
            metric=self.lambda_function.metric_errors(),
            threshold=1,
            evaluation_periods=1,
            alarm_description="Alert when the backup Lambda function encounters any errors",
            alarm_name=f"{STACK_NAME}-lambda-errors"
        )
        lambda_errors_alarm.add_alarm_action(
            cloudwatch_actions.SnsAction(alerts_topic)
        )

        # 2. Lambda Success Metric and Alarm
        success_metric = cloudwatch.Metric(
            namespace="SFTPBackup",
            metric_name="SuccessfulBackup",
            dimensions_map={
                "FunctionName": self.lambda_function.function_name
            },
            period=Duration.hours(24)
        )

        backup_missing_alarm = cloudwatch.Alarm(
            self,
            "BackupMissingAlarm",
            metric=success_metric,
            threshold=1,
            comparison_operator=cloudwatch.ComparisonOperator.LESS_THAN_THRESHOLD,
            evaluation_periods=1,
            alarm_description="Alert when no successful backup has occurred in the past 24 hours",
            alarm_name=f"{STACK_NAME}-backup-missing",
            treat_missing_data=cloudwatch.TreatMissingData.BREACHING
        )
        backup_missing_alarm.add_alarm_action(
            cloudwatch_actions.SnsAction(alerts_topic)
        )

        # 3. Schedule Execution Alarm
        schedule_metric = cloudwatch.Metric(
            namespace="AWS/Scheduler",
            metric_name="TargetInvocations",
            dimensions_map={
                "ScheduleName": schedule.ref,
                "ScheduleGroup": "default"
            },
            period=Duration.hours(24)
        )

        schedule_failure_alarm = cloudwatch.Alarm(
            self,
            "ScheduleFailureAlarm",
            metric=schedule_metric,
            threshold=1,
            comparison_operator=cloudwatch.ComparisonOperator.LESS_THAN_THRESHOLD,
            evaluation_periods=1,
            alarm_description="Alert when the backup schedule fails to trigger",
            alarm_name=f"{STACK_NAME}-schedule-failure",
            treat_missing_data=cloudwatch.TreatMissingData.BREACHING
        )
        schedule_failure_alarm.add_alarm_action(
            cloudwatch_actions.SnsAction(alerts_topic)
        )

        # Add CloudFormation outputs
        CfnOutput(
            self,
            "BackupBucketName",
            value=self.backup_bucket.bucket_name,
            description="Name of the S3 bucket for backups"
        )

        CfnOutput(
            self,
            "LambdaFunctionArn",
            value=self.lambda_function.function_arn,
            description="ARN of the backup Lambda function"
        )

        CfnOutput(
            self,
            "ScheduleName",
            value=schedule.ref,
            description="Name of the EventBridge Schedule"
        )

        CfnOutput(
            self,
            "AlertsTopicArn",
            value=alerts_topic.topic_arn,
            description="ARN of the SNS topic for backup alerts"
        )

        # Apply tags
        for key, value in TAGS.items():
            self.tags.set_tag(key, value)
