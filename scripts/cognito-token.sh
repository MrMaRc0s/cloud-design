#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
terraform_dir="$repo_root/terraform"

aws_profile=${AWS_PROFILE:-cloud-design}
aws_region=${AWS_REGION:-eu-central-1}
username=${1:-}

if [[ -z "$username" ]]; then
  read -r -p "Audit user email: " username
fi

read -r -s -p "Audit user password: " password
printf '\n' >&2

if [[ ${#password} -lt 12 ]]; then
  printf 'Password must contain at least 12 characters.\n' >&2
  exit 1
fi

user_pool_id=$(terraform -chdir="$terraform_dir" output -raw cognito_user_pool_id)
client_id=$(terraform -chdir="$terraform_dir" output -raw cognito_user_pool_client_id)

if ! aws cognito-idp admin-get-user \
  --profile "$aws_profile" \
  --region "$aws_region" \
  --user-pool-id "$user_pool_id" \
  --username "$username" >/dev/null 2>&1; then
  aws cognito-idp admin-create-user \
    --profile "$aws_profile" \
    --region "$aws_region" \
    --user-pool-id "$user_pool_id" \
    --username "$username" \
    --user-attributes Name=email,Value="$username" Name=email_verified,Value=true \
    --message-action SUPPRESS >/dev/null
fi

aws cognito-idp admin-set-user-password \
  --profile "$aws_profile" \
  --region "$aws_region" \
  --user-pool-id "$user_pool_id" \
  --username "$username" \
  --password "$password" \
  --permanent

aws cognito-idp initiate-auth \
  --profile "$aws_profile" \
  --region "$aws_region" \
  --client-id "$client_id" \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$username",PASSWORD="$password" \
  --query 'AuthenticationResult.IdToken' \
  --output text
