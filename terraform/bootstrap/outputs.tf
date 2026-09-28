output "state_bucket_name" {
  description = "Name of the S3 bucket for shared Terraform state. Use this in the root's backend configuration."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "operator_role_arn" {
  description = "Role assumed for daily Terraform and AWS audit operations instead of using root directly."
  value       = aws_iam_role.operator.arn
}

output "operator_login_user_name" {
  description = "Minimal console user that can only assume the Cloud Design operator role. Create its console password outside Terraform."
  value       = aws_iam_user.operator_login.name
}

output "operator_login_url" {
  description = "AWS console URL for the minimal operator login user."
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}
