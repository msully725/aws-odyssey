# AWS Odyssey

## Set Up
1. Set up a new AWS account. For example, `abc-aws-odyssey`
1. Set your AWS profile in `.env`
1. Run `source ./set-aws-account.sh`
1. Verify the Account ID is what you expect.
1. Set up IAM Identity Center to enable SSO-based AWS CLI access. 
    * Note: Had to use AWS Organization path as the single account path did not offer Permission Sets, which is needed for giving users/groups access to an account. No documentation sugggested that will be a problem (not even Q Assistant), had to trial and error. 
1. Add an Admin group, give them Admin access.
1. Add a new User, put them in the Admin group.
1. Set up AWS CLI access via `aws configure sso`
    * You will need the "start" SSO URL that can be found under IAM Identity Center - Settings
1. Install or update `terraform`
1. Generate a Key Pair for configuring EC2 instances with `generate-key-pair.sh`


## Creating EC2 instances and SSH'ing to them
1. Set up an initial `main.tf` to make basic calls and prove out terraform access to the AWS account.
1. Add VPC creation to `main.tf`.
1. Add a Public Subnet.
    * Command for veryfying Subnet: 
    ```aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" --query "Subnets[?Tags[?Value=='terraform-public-subnet']].SubnetId"```
1. Add a Private Subnet.
1. Add an Internet Gateway.
1. Add an EC2 instance.
1. Add a Route for SSH to EC2
1. SSH to the EC2 instance, e.g. `ssh -i aws-odyssey-key-pair.pem ec2-user@[IP ADDRESS]`
