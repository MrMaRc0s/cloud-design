#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/put-secret-value.sh --name-prefix <prefix> [--env-file <path>] [--region <region>]

Populates the three shared Secrets Manager secrets (billing-database,
rabbitmq, inventory-database) created by the compute-foundation Terraform
module with real credential values, read from a local, git-ignored env
file. Terraform never creates these values itself - only the empty secret
containers - specifically so a real username/password never has to appear
in .tf source, a .tfvars file, command history, or Terraform state.

This script does not store or embed AWS credentials; it relies on the AWS
CLI already being configured (profile, environment variables, or an
assumed role) in the shell that runs it.

Required in the env file (default: .env.secrets - see
.env.secrets.example for the template):
  BILLING_DATABASE_USERNAME, BILLING_DATABASE_PASSWORD
  RABBITMQ_USERNAME,         RABBITMQ_PASSWORD
  INVENTORY_DATABASE_USERNAME, INVENTORY_DATABASE_PASSWORD

--name-prefix is the compute-foundation name_prefix, e.g. "cloud-design-dev"
(secrets are named "<prefix>-<credential-set>-credentials").

Requires: aws CLI, jq.
USAGE
}

env_file=".env.secrets"
region="${AWS_REGION:-eu-central-1}"
name_prefix=""

while [ $# -gt 0 ]; do
  case "$1" in
    --name-prefix)
      name_prefix="$2"
      shift 2
      ;;
    --env-file)
      env_file="$2"
      shift 2
      ;;
    --region)
      region="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$name_prefix" ]; then
  echo "Error: --name-prefix is required" >&2
  usage
  exit 1
fi

for dependency in aws jq; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Error: $dependency is required but not found on PATH" >&2
    exit 1
  fi
done

if [ ! -f "$env_file" ]; then
  echo "Error: env file not found: $env_file (see .env.secrets.example)" >&2
  exit 1
fi

# shellcheck source=/dev/null
set -a
source "$env_file"
set +a

: "${BILLING_DATABASE_USERNAME:?missing in $env_file}"
: "${BILLING_DATABASE_PASSWORD:?missing in $env_file}"
: "${RABBITMQ_USERNAME:?missing in $env_file}"
: "${RABBITMQ_PASSWORD:?missing in $env_file}"
: "${INVENTORY_DATABASE_USERNAME:?missing in $env_file}"
: "${INVENTORY_DATABASE_PASSWORD:?missing in $env_file}"

put_secret() {
  local credential_set="$1"
  local username="$2"
  local password="$3"
  local secret_id="${name_prefix}-${credential_set}-credentials"
  local payload

  payload=$(jq -n --arg u "$username" --arg p "$password" '{username: $u, password: $p}')

  aws secretsmanager put-secret-value \
    --region "$region" \
    --secret-id "$secret_id" \
    --secret-string "$payload" \
    --output text \
    --query 'ARN' >/dev/null

  echo "Updated $secret_id"
}

put_secret "billing-database" "$BILLING_DATABASE_USERNAME" "$BILLING_DATABASE_PASSWORD"
put_secret "rabbitmq" "$RABBITMQ_USERNAME" "$RABBITMQ_PASSWORD"
put_secret "inventory-database" "$INVENTORY_DATABASE_USERNAME" "$INVENTORY_DATABASE_PASSWORD"
