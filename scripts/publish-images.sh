#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/publish-images.sh --account-id <id> --tag <git-sha-or-version> [--region <region>] [--project-name <name>]

Builds all six Docker contexts, tags each with the supplied Git commit SHA
or explicit version, authenticates Docker to ECR, and pushes each image to
its matching repository:
  <account-id>.dkr.ecr.<region>.amazonaws.com/<project-name>/<service>

Services (source directory -> ECR repository name):
  srcs/api-gateway-app    -> api-gateway-app
  srcs/inventory-app      -> inventory-app
  srcs/inventory-database -> inventory-database
  srcs/rabbit-queue       -> rabbit-queue
  srcs/billing-app        -> billing-app
  srcs/billing-database   -> billing-database

--tag must not be "latest": the ECR repos are image_tag_mutability=IMMUTABLE,
so every push needs a new, traceable tag.

Does not store or embed AWS credentials - relies on the AWS CLI already
being configured (profile, environment variables, or an assumed role) in
the shell that runs it. Not run automatically by anything else; invoke it
deliberately, and only as part of the coordinated deployment step.

Requires: aws CLI, docker.
USAGE
}

account_id=""
region="${AWS_REGION:-eu-central-1}"
project_name="cloud-design"
tag=""

while [ $# -gt 0 ]; do
  case "$1" in
    --account-id)
      account_id="$2"
      shift 2
      ;;
    --region)
      region="$2"
      shift 2
      ;;
    --project-name)
      project_name="$2"
      shift 2
      ;;
    --tag)
      tag="$2"
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

if [ -z "$account_id" ]; then
  echo "Error: --account-id is required" >&2
  usage
  exit 1
fi

if [ -z "$tag" ]; then
  echo "Error: --tag is required (a Git commit SHA or explicit version)" >&2
  usage
  exit 1
fi

if [ "$tag" = "latest" ]; then
  echo "Error: --tag must not be \"latest\" - the ECR repos are image_tag_mutability=IMMUTABLE and this must be a unique, traceable version" >&2
  exit 1
fi

for dependency in aws docker; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Error: $dependency is required but not found on PATH" >&2
    exit 1
  fi
done

registry="${account_id}.dkr.ecr.${region}.amazonaws.com"

services=(
  "api-gateway-app:srcs/api-gateway-app"
  "inventory-app:srcs/inventory-app"
  "inventory-database:srcs/inventory-database"
  "rabbit-queue:srcs/rabbit-queue"
  "billing-app:srcs/billing-app"
  "billing-database:srcs/billing-database"
)

for entry in "${services[@]}"; do
  context="${entry#*:}"
  if [ ! -d "$context" ]; then
    echo "Error: build context not found: $context" >&2
    exit 1
  fi
done

echo "Authenticating Docker to ${registry}..."
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"

for entry in "${services[@]}"; do
  service="${entry%%:*}"
  context="${entry#*:}"
  repository="${registry}/${project_name}/${service}"

  echo "Building ${service} from ${context}..."
  # ECR basic scanning expects a directly scannable image manifest. Disabling
  # BuildKit provenance avoids publishing a one-platform OCI image index whose
  # attestation makes StartImageScan reject the artifact type.
  docker build --provenance=false -t "${repository}:${tag}" "$context"

  echo "Pushing ${repository}:${tag}..."
  docker push "${repository}:${tag}"
done

echo "Done. Published tag ${tag} for all six services to ${registry}/${project_name}/*."
