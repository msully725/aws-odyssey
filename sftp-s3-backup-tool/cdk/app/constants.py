from typing import Dict
import os
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from .env file
env_path = Path(__file__).parents[2] / '.env'
load_dotenv(dotenv_path=env_path)

# Stack name and description
STACK_NAME = "SftpBackupStack"
STACK_DESCRIPTION = "Infrastructure for SFTP to S3 backup service"

# Lambda configuration
LAMBDA_HANDLER = "backup-service.lambda_handler"
LAMBDA_RUNTIME = "python3.9"
LAMBDA_MEMORY = 512
LAMBDA_TIMEOUT = 900  # 15 minutes

# Environment variables loaded from .env
ENV_VARS = {
    "SECRET_NAME": os.getenv("SECRET_NAME"),
    "REMOTE_PATH": os.getenv("REMOTE_PATH"),
    "LOCAL_BACKUP_PATH": os.getenv("LOCAL_BACKUP_PATH"),
    "S3_BUCKET": os.getenv("S3_BUCKET"),
    "ALERT_EMAIL": os.getenv("ALERT_EMAIL")
}

# Lambda environment variables (subset of ENV_VARS)
LAMBDA_ENV_VARS: Dict[str, str] = {
    "SECRET_NAME": ENV_VARS["SECRET_NAME"],
    "REMOTE_PATH": ENV_VARS["REMOTE_PATH"],
    "LOCAL_BACKUP_PATH": ENV_VARS["LOCAL_BACKUP_PATH"]
    # Note: S3_BUCKET is dynamically set in the stack using the bucket name
}

# Tags
TAGS = {
    "Project": "SFTP Backup Service",
    "Environment": "Production"
}
