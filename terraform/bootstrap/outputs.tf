output "state_bucket_name" {
  description = "Name of the S3 bucket for shared Terraform state. Use this in the root's backend configuration."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}
