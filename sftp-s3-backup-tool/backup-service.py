import paramiko
import boto3
import json
import tarfile
import os
import re
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file if available
if os.path.exists(".env"):
    load_dotenv()
    print("✅ .env file loaded")

# Fetch config values from .env file
SECRET_NAME = os.getenv("SECRET_NAME")
REMOTE_PATH = os.getenv("REMOTE_PATH")
LOCAL_BACKUP_PATH = os.getenv("LOCAL_BACKUP_PATH")
S3_BUCKET = os.getenv("S3_BUCKET")
DEFAULT_SFTP_PORT = int(os.getenv("SFTP_PORT", 22))  # Default to port 22 if not set

def parse_sftp_host(sftp_host):
    """Extract hostname and port if the port is included in the host string."""
    # Remove protocol prefix if present
    sftp_host = sftp_host.replace("sftp://", "").strip()

    # Extract port if included
    match = re.match(r"^(.*?):(\d+)$", sftp_host)
    if match:
        host, port = match.groups()
        return host, int(port)
    return sftp_host, DEFAULT_SFTP_PORT  # Default to port 22

def get_sftp_credentials():
    """Fetch SFTP credentials from AWS Secrets Manager and extract host & port properly."""
    print("🔹 Fetching SFTP credentials from AWS Secrets Manager...")
    secrets_client = boto3.client("secretsmanager")
    secret_value = secrets_client.get_secret_value(SecretId=SECRET_NAME)
    credentials = json.loads(secret_value["SecretString"])

    # Extract hostname & port (and remove "sftp://")
    raw_host = credentials["SFTP_HOST"].strip()
    sftp_host, extracted_port = parse_sftp_host(raw_host)

    # Use extracted port if available, otherwise check Secrets Manager
    sftp_port = int(credentials.get("SFTP_PORT", extracted_port))

    print(f"✅ Using SFTP Host: {sftp_host}, Port: {sftp_port}")
    
    return {
        "host": sftp_host,
        "user": credentials["SFTP_USER"],
        "password": credentials["SFTP_PASSWORD"],
        "port": sftp_port
    }

def connect_sftp():
    """Establish an SFTP connection and return the session."""
    credentials = get_sftp_credentials()
    SFTP_HOST = credentials["host"]
    SFTP_USER = credentials["user"]
    SFTP_PASSWORD = credentials["password"]
    SFTP_PORT = credentials["port"]

    print(f"🔹 Connecting to SFTP server at {SFTP_HOST}:{SFTP_PORT} as {SFTP_USER}...")

    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(
            SFTP_HOST, 
            port=SFTP_PORT, 
            username=SFTP_USER, 
            password=SFTP_PASSWORD, 
            allow_agent=False,  # Prevents SSH key authentication
        )
        print("✅ Successfully connected via SFTP!")
        return ssh.open_sftp(), ssh  # Return both the SFTP session and the SSH connection
    except paramiko.AuthenticationException:
        print("❌ Authentication failed! Check your username and password.")
    except paramiko.SSHException as e:
        print(f"❌ SSH Error: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    
    return None, None  # Return None if the connection fails

def backup_sftp_data():
    """Connect to SFTP, download files, compress them, and upload to S3."""
    print("🔹 Starting backup process...")

    # Establish SFTP connection
    sftp, ssh = connect_sftp()
    if not sftp or not ssh:
        print("❌ Failed to connect to SFTP. Exiting backup process.")
        return {"status": "SFTP connection failed"}

    print("✅ SFTP session opened.")

    # Ensure local backup directory exists
    os.makedirs("/tmp/data", exist_ok=True)

    print(f"🔹 Downloading files from {REMOTE_PATH}...")
    try:
        for file in sftp.listdir(REMOTE_PATH):
            remote_file_path = f"{REMOTE_PATH}/{file}"
            local_file_path = f"/tmp/data/{file}"
            print(f"⬇ Downloading {file}...")
            sftp.get(remote_file_path, local_file_path)
    except Exception as e:
        print(f"❌ Error downloading files: {e}")
        return {"status": f"Error downloading files: {e}"}

    sftp.close()
    ssh.close()
    print("✅ All files downloaded.")

    print("🔹 Compressing backup...")
    try:
        with tarfile.open(LOCAL_BACKUP_PATH, "w:gz") as tar:
            tar.add("/tmp/data", arcname="data")
        print("✅ Backup compressed.")
    except Exception as e:
        print(f"❌ Error compressing backup: {e}")
        return {"status": f"Error compressing backup: {e}"}

    print(f"🔹 Uploading backup to S3 bucket {S3_BUCKET}...")
    s3 = boto3.client("s3")
    timestamp = datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
    s3_key = f"backups/backup_{timestamp}.tar.gz"
    try:
        s3.upload_file(LOCAL_BACKUP_PATH, S3_BUCKET, s3_key)
        print(f"✅ Backup uploaded to S3: {s3_key}")
    except Exception as e:
        print(f"❌ Error uploading to S3: {e}")
        return {"status": f"Error uploading to S3: {e}"}

    print("🔹 Cleaning up temporary files...")
    os.system("rm -rf /tmp/data /tmp/backup.tar.gz")

    print("✅ Backup process completed successfully.")
    return {"status": "Backup successful"}

def lambda_handler(event, context):
    return backup_sftp_data()

# Run locally if executed directly
if __name__ == "__main__":
    print("🔹 Running backup locally...")
    backup_sftp_data()