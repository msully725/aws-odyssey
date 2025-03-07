import paramiko
import boto3
import json
import tarfile
import os
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Fetch config values from .env file
SECRET_NAME = os.getenv("SECRET_NAME")
REMOTE_PATH = os.getenv("REMOTE_PATH")
LOCAL_BACKUP_PATH = os.getenv("LOCAL_BACKUP_PATH")
S3_BUCKET = os.getenv("S3_BUCKET")

def get_sftp_credentials():
    """Fetch SFTP credentials from AWS Secrets Manager."""
    secrets_client = boto3.client("secretsmanager")
    secret_value = secrets_client.get_secret_value(SecretId=SECRET_NAME)
    return json.loads(secret_value["SecretString"])

def backup_sftp_data():
    """Connect to SFTP, download files, compress them, and upload to S3."""

    # Fetch SFTP credentials securely
    credentials = get_sftp_credentials()
    SFTP_HOST = credentials["SFTP_HOST"]
    SFTP_USER = credentials["SFTP_USER"]
    SFTP_PASSWORD = credentials["SFTP_PASSWORD"]

    # Connect to SFTP server
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(SFTP_HOST, username=SFTP_USER, password=SFTP_PASSWORD)
    
    sftp = ssh.open_sftp()
    
    # Ensure local backup directory exists
    os.makedirs("/tmp/data", exist_ok=True)

    # Download all files from remote directory
    for file in sftp.listdir(REMOTE_PATH):
        remote_file_path = f"{REMOTE_PATH}/{file}"
        local_file_path = f"/tmp/data/{file}"
        sftp.get(remote_file_path, local_file_path)

    sftp.close()
    ssh.close()
    
    # Compress downloaded files
    with tarfile.open(LOCAL_BACKUP_PATH, "w:gz") as tar:
        tar.add("/tmp/data", arcname="data")

    # Upload backup to S3
    s3 = boto3.client("s3")
    timestamp = datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
    s3.upload_file(LOCAL_BACKUP_PATH, S3_BUCKET, f"backups/backup_{timestamp}.tar.gz")

    # Cleanup local files
    os.system("rm -rf /tmp/data /tmp/backup.tar.gz")

    return {"status": "Backup successful"}

def lambda_handler(event, context):
    return backup_sftp_data()