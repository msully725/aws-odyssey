#!/usr/bin/env python3

import os
import aws_cdk as cdk
from app.backup_stack import BackupStack
from app.constants import STACK_NAME

app = cdk.App()
env = cdk.Environment(
    account=os.environ.get('CDK_DEFAULT_ACCOUNT'),
    region=os.environ.get('CDK_DEFAULT_REGION', 'us-east-1')
)

BackupStack(app, STACK_NAME, env=env)
app.synth() 