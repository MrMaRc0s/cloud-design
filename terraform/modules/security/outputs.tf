output "vpc_link_security_group_id" {
  description = "Security group used by the API Gateway VPC Link."
  value       = aws_security_group.vpc_link.id
}

output "internal_load_balancer_security_group_id" {
  description = "Security group used by the internal load balancer."
  value       = aws_security_group.internal_load_balancer.id
}

output "workload_security_group_ids" {
  description = "Security group IDs keyed by workload name."
  value       = { for name, security_group in aws_security_group.workload : name => security_group.id }
}
