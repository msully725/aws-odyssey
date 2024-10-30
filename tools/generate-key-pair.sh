# Check if KEY_NAME is provided as a parameter
if [ -z "$1" ]; then
  echo "Usage: $0 <key-name>"
  exit 1
fi

KEY_NAME="$1"
KEY_FILE="$KEY_NAME.pem"

# Check if the local key file exists
if [ -f "$KEY_FILE" ]; then
  echo "The local key file '$KEY_FILE' already exists. No need to create."
else
  # Check if the key pair exists on AWS
  if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
    echo "Key pair '$KEY_NAME' does not exist on AWS. Creating it..."
    
    # Create the key pair and store the private key locally
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query "KeyMaterial" --output text > "$KEY_FILE"
    
    # Set the appropriate permissions for the private key file
    chmod 400 "$KEY_FILE"
    
    echo "Key pair '$KEY_NAME' created on AWS and saved as '$KEY_FILE'."
  else
    echo "Key pair '$KEY_NAME' already exists on AWS, but no local file was found. Be careful if the private key is missing!"
  fi
fi