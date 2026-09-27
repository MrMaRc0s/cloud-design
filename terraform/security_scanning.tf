data "aws_caller_identity" "current" {}

# Inspector can continuously evaluate the ECS container instances and ECR
# images for known vulnerabilities. Some Free plan accounts reject the service
# subscription, so this is opt-in; keep cost monitoring active after its
# per-scan-type trial expires.
resource "aws_inspector2_enabler" "workloads" {
  count = var.enable_inspector ? 1 : 0

  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2", "ECR"]
}
