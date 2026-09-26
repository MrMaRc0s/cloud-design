output "rabbitmq_internal_dns" {
  description = "Internal DNS name for rabbit-queue, e.g. rabbit-queue.cloud-design.internal. Developer A's api-gateway-app publishes to this host."
  value       = local.rabbitmq_host
}

output "billing_database_internal_dns" {
  description = "Internal DNS name for billing-database."
  value       = local.billing_database_host
}

output "rabbitmq_queue" {
  description = "Durable queue name. Developer A's api-gateway-app must use this exact value."
  value       = var.rabbitmq_queue
}

output "rabbitmq_task_security_group_id" {
  description = "Security group attached to the rabbit-queue task, for reference."
  value       = aws_security_group.rabbitmq_task.id
}

output "billing_app_task_security_group_id" {
  description = "Security group attached to the billing-app task, for reference."
  value       = aws_security_group.billing_app_task.id
}
