output "ecs_cluster_arn" {
  description = "ARN of the shared ECS cluster. Consumed by both developers' workload modules."
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "Name of the shared ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_urls" {
  description = "Map of service name to its ECR repository URL, covering all six services."
  value       = { for name, repo in aws_ecr_repository.owned : name => repo.repository_url }
}

output "task_execution_role_arn" {
  description = "Shared ECS task execution role ARN (ECR pull + CloudWatch Logs)."
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arns" {
  description = "Map of service name to its dedicated ECS task role ARN, covering all six services."
  value       = { for name, role in aws_iam_role.task : name => role.arn }
}

output "secret_arns" {
  description = "Map of credential-set name (billing-database, rabbitmq, inventory-database) to its Secrets Manager secret ARN. Metadata only - no value until scripts/put-secret-value.sh runs."
  value       = { for name, secret in aws_secretsmanager_secret.credentials : name => secret.arn }
}

output "service_discovery_namespace_id" {
  description = "ID of the private DNS namespace for internal service discovery."
  value       = aws_service_discovery_private_dns_namespace.internal.id
}

output "service_discovery_namespace_name" {
  description = "Name of the private DNS namespace (e.g. cloud-design.internal)."
  value       = aws_service_discovery_private_dns_namespace.internal.name
}

output "ecs_capacity_provider_name" {
  description = "Name of the EC2 Auto Scaling capacity provider, for use in ECS service capacity provider strategies."
  value       = aws_ecs_capacity_provider.ec2.name
}

output "ecs_instance_security_group_id" {
  description = "Security group ID attached to the ECS container instances."
  value       = aws_security_group.ecs_instance.id
}

output "ecs_autoscaling_group_name" {
  description = "Name of the ECS container instance Auto Scaling group."
  value       = aws_autoscaling_group.ecs_instance.name
}
