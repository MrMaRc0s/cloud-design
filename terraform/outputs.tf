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

output "api_endpoint" {
  description = "Public HTTPS API Gateway endpoint protected by Cognito."
  value       = module.edge_gateway.api_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito user pool used for audit authentication."
  value       = module.edge_gateway.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito client used by Postman to obtain tokens."
  value       = module.edge_gateway.cognito_user_pool_client_id
}

output "ecs_cluster_name" {
  description = "Shared ECS cluster name used for operational checks."
  value       = module.compute_foundation.ecs_cluster_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs used by the image publishing script."
  value       = module.compute_foundation.ecr_repository_urls
}

output "secret_arns" {
  description = "Secrets Manager metadata populated out-of-band."
  value       = module.compute_foundation.secret_arns
}
