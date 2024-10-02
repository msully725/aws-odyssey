# AWS Odyssey

## Work Log
1. Set up a new AWS account. For example, `abc-aws-odyssey`
1. Set up IAM Identity Center to enable SSO-based AWS CLI access. 
    * Note: Had to use AWS Organization path as the single account path did not offer Permission Sets, which is needed for giving users/groups access to an account. No documentation sugggested that will be a problem (not even Q Assistant), had to trial and error. 
1. Add an Admin group, give them Admin access.
1. Add a new User, put them in the Admin group.
1. Set up AWS CLI access via `aws configure sso`
    * You will need the "start" SSO URL that can be found under IAM Identity Center - Settings
1. Install or update `terraform`
1. Set up an initial `main.tf` to make basic calls and prove out terraform access to the AWS account.