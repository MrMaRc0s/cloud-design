output "inventory_app_internal_dns" {
  description = "Internal DNS name for inventory-app, e.g. inventory-app.cloud-design.internal. Developer A's api-gateway-app proxies to this host as INVENTORY_API_URL."
  value       = "${aws_service_discovery_service.inventory_app.name}.${var.service_discovery_namespace_name}"
}

output "inventory_database_internal_dns" {
  description = "Internal DNS name for inventory-database."
  value       = local.inventory_database_host
}

output "inventory_app_service_name" {
  description = "ECS service name for inventory-app."
  value       = aws_ecs_service.inventory_app.name
}

output "inventory_database_service_name" {
  description = "ECS service name for inventory-database."
  value       = aws_ecs_service.inventory_database.name
}

output "inventory_app_task_definition_family" {
  description = "Task definition family for inventory-app."
  value       = aws_ecs_task_definition.inventory_app.family
}

output "inventory_database_task_definition_family" {
  description = "Task definition family for inventory-database."
  value       = aws_ecs_task_definition.inventory_database.family
}
