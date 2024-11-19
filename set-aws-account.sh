# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Script is sourced, continuing..."
else
    echo "Error: Script must be sourced to work correctly: source ./set-aws-account.sh"
    exit 1
fi

# Path to the .env file
ENV_FILE="./.env"

if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  echo "Environment variables loaded from $ENV_FILE."
else
  echo "Error: $ENV_FILE not found. Please create the file with necessary environment variables."
  return 1  # Use 'exit 1' if not sourcing
fi

echo "AWS_PROFILE: $AWS_PROFILE"

# Verify the active account
account_info=$(aws sts get-caller-identity 2>&1)
if [[ $? -ne 0 ]]; then
  if [[ "$account_info" == *"Error when retrieving token from sso: Token has expired and refresh failed"* ]]; then
    echo "SSO token has expired. Attempting to refresh token..."
    aws sso login
    account_info=$(aws sts get-caller-identity 2>&1)
    if [[ $? -ne 0 ]]; then
      echo "Error retrieving AWS account information after SSO login:"
      echo "$account_info"
      return 1  # Use 'exit 1' if not sourcing
    fi
  else
    echo "Error retrieving AWS account information:"
    echo "$account_info"
    return 1  # Use 'exit 1' if not sourcing
  fi
fi

echo "You are now using the following account:"
echo $account_info