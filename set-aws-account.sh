# Path to the .env file
ENV_FILE="./.env"

if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  echo "Environment variables loaded from $ENV_FILE."
else
  echo "Error: $ENV_FILE not found. Please create the file with necessary environment variables."
  return 1  # Use 'exit 1' if not sourcing
fi

# Verify the active account
account_info=$(aws sts get-caller-identity 2>&1)
if [ $? -ne 0 ]; then
  echo "Error retrieving AWS account information:"
  echo "$account_info"
  unset AWS_PROFILE  # Optionally unset the profile if verification fails
  return 1  # Use 'exit 1' if not sourcing
fi

echo "You are now using the following account:"
echo $account_info