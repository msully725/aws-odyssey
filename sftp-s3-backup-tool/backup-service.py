import paramiko
import boto3
import json
import tarfile
import os
import re
from stat import S_ISDIR
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
DEFAULT_SFTP_PORT = int(os.getenv("SFTP_PORT", 22))
TEMP_LOCAL_PATH = "/tmp/data"  # Define the temporary directory for backups

def emit_success_metric():
    """Emit a CloudWatch metric indicating successful backup."""
    try:
        cloudwatch = boto3.client('cloudwatch')
        cloudwatch.put_metric_data(
            Namespace='SFTPBackup',
            MetricData=[
                {
                    'MetricName': 'SuccessfulBackup',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'FunctionName',
                            'Value': os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'unknown')
                        }
                    ]
                }
            ]
        )
        print("✅ Emitted success metric to CloudWatch")
    except Exception as e:
        print(f"⚠️ Failed to emit success metric: {e}")

def parse_sftp_host(sftp_host):
    """Extract hostname and port if included in the host string."""
    sftp_host = sftp_host.replace("sftp://", "").strip()
    match = re.match(r"^(.*?):(\d+)$", sftp_host)
    if match:
        host, port = match.groups()
        return host, int(port)
    return sftp_host, DEFAULT_SFTP_PORT

def get_sftp_credentials():
    """Fetch SFTP credentials from AWS Secrets Manager and extract host & port properly."""
    print("🔹 Fetching SFTP credentials from AWS Secrets Manager...")
    secrets_client = boto3.client("secretsmanager")
    secret_value = secrets_client.get_secret_value(SecretId=SECRET_NAME)
    credentials = json.loads(secret_value["SecretString"])

    raw_host = credentials["SFTP_HOST"].strip()
    sftp_host, extracted_port = parse_sftp_host(raw_host)
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
            allow_agent=False  
        )
        print("✅ Successfully connected via SFTP!")
        return ssh.open_sftp(), ssh  
    except paramiko.AuthenticationException:
        print("❌ Authentication failed! Check your username and password.")
    except paramiko.SSHException as e:
        print(f"❌ SSH Error: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    
    return None, None  

def is_sftp_directory(sftp, remote_path):
    """Check if a remote path is a directory on the SFTP server."""
    try:
        return S_ISDIR(sftp.stat(remote_path).st_mode)
    except IOError:
        return False

def download_sftp_directory(sftp, remote_path, local_path):
    """Recursively download directories from SFTP to local storage."""
    if os.path.exists(local_path):
        if not os.path.isdir(local_path):  
            print(f"⚠️ Conflict detected: {local_path} exists as a file. Removing it.")
            os.remove(local_path)
        else:
            print(f"📂 Directory already exists: {local_path}")
    else:
        print(f"📂 Creating directory: {local_path}")
        os.makedirs(local_path, exist_ok=True)

    for item in sftp.listdir(remote_path):
        remote_item_path = f"{remote_path}/{item}"
        local_item_path = os.path.join(local_path, item)

        try:
            if is_sftp_directory(sftp, remote_item_path):
                download_sftp_directory(sftp, remote_item_path, local_item_path)
            else:
                print(f"⬇ Downloading file: {remote_item_path} → {local_item_path}")
                sftp.get(remote_item_path, local_item_path)
        except Exception as e:
            print(f"❌ Error downloading {remote_item_path}: {e}")

def backup_sftp_data():
    """Connect to SFTP, clear old data, download files, compress them, and upload to S3."""
    print("🔹 Starting backup process...")

    # ✅ Ensure a clean directory before downloading
    if os.path.exists(TEMP_LOCAL_PATH):
        print("🧹 Clearing old backup data...")
        os.system(f"rm -rf {TEMP_LOCAL_PATH}")

    sftp, ssh = connect_sftp()
    if not sftp or not ssh:
        print("❌ Failed to connect to SFTP. Exiting backup process.")
        return {"status": "SFTP connection failed"}

    print("✅ SFTP session opened.")

    os.makedirs(TEMP_LOCAL_PATH, exist_ok=True)  # Ensure fresh directory

    print(f"🔹 Downloading from {REMOTE_PATH}...")
    try:
        download_sftp_directory(sftp, REMOTE_PATH, TEMP_LOCAL_PATH)
    except Exception as e:
        print(f"❌ Error during download: {e}")
        return {"status": f"Error downloading files: {e}"}

    sftp.close()
    ssh.close()
    print("✅ All files downloaded.")

    print("🔹 Compressing backup...")
    try:
        with tarfile.open(LOCAL_BACKUP_PATH, "w:gz") as tar:
            tar.add(TEMP_LOCAL_PATH, arcname="data")
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
    os.system(f"rm -rf {TEMP_LOCAL_PATH} {LOCAL_BACKUP_PATH}")

    # Emit success metric
    emit_success_metric()

    print("✅ Backup process completed successfully.")
    return {"status": "Backup successful"}

def lambda_handler(event, context):
    return backup_sftp_data()

if __name__ == "__main__":
    print("🔹 Running backup locally...")
    backup_sftp_data()