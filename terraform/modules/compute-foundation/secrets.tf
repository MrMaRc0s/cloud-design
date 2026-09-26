# Metadata only - these secrets have no value until scripts/put-secret-value.sh
# runs against them out-of-band. Terraform never sees or stores a real
# username/password: creating a value here (an aws_secretsmanager_secret_version
# resource) would put it in this module's state even if it never appeared in
# source, which defeats the point of using Secrets Manager at all.
resource "aws_secretsmanager_secret" "credentials" {
  for_each = toset(["billing-database", "rabbitmq", "inventory-database"])

  name        = "${local.name_prefix}-${each.value}-credentials"
  description = "Runtime username/password for ${each.value}, populated out-of-band via scripts/put-secret-value.sh."

  # No recovery window: this is a dev/audit exercise torn down and recreated
  # between sessions, and AWS blocks creating a new secret with the same
  # name while an old one is still in its recovery window. Not the right
  # trade-off for a real production account.
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-${each.value}-credentials"
  }
}

# The ECS *execution* role fetches these at task launch to populate the
# `secrets` block in each container definition - not the task role, which
# is only relevant if application code calls the Secrets Manager API
# itself at runtime. One shared execution role for all six services, so
# this grants read access to exactly the three secrets that exist, not a
# wildcard.
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${local.name_prefix}-secrets-read"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = [for secret in aws_secretsmanager_secret.credentials : secret.arn]
    }]
  })
}
