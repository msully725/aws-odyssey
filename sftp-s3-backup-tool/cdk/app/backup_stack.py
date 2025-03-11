from aws_cdk import (
    Stack,
    aws_s3 as s3,
    aws_lambda as lambda_,
    aws_iam as iam,
    Duration,
    RemovalPolicy,
    CfnOutput,
    DockerImage
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
                        "pip install -r requirements.txt -t /asset-output && cp backup-service.py /asset-output/"
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

        # Apply tags
        for key, value in TAGS.items():
            self.tags.set_tag(key, value)
