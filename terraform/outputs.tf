output "vpc_id" {
  description = "ID of the project VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for internet-facing entry resources."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs for application and data workloads."
  value       = module.network.private_subnet_ids
}

output "vpc_link_security_group_id" {
  description = "Security group used by the API Gateway VPC Link."
  value       = module.security.vpc_link_security_group_id
}

output "internal_load_balancer_security_group_id" {
  description = "Security group used by the internal load balancer."
  value       = module.security.internal_load_balancer_security_group_id
}

output "workload_security_group_ids" {
  description = "Security group IDs keyed by workload name."
  value       = module.security.workload_security_group_ids
}
