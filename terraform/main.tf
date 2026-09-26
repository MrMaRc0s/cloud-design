module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  vpc_cidr     = var.vpc_cidr
}

module "compute_foundation" {
  source = "./modules/compute-foundation"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids
}

module "billing_workloads" {
  source = "./modules/billing-workloads"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids

  ecs_cluster_name                 = module.compute_foundation.ecs_cluster_name
  ecs_capacity_provider_name       = module.compute_foundation.ecs_capacity_provider_name
  task_execution_role_arn          = module.compute_foundation.task_execution_role_arn
  task_role_arns                   = module.compute_foundation.task_role_arns
  ecr_repository_urls              = module.compute_foundation.ecr_repository_urls
  service_discovery_namespace_id   = module.compute_foundation.service_discovery_namespace_id
  service_discovery_namespace_name = module.compute_foundation.service_discovery_namespace_name
  billing_database_secret_arn      = module.compute_foundation.secret_arns["billing-database"]
  rabbitmq_secret_arn              = module.compute_foundation.secret_arns["rabbitmq"]

  image_tag = var.image_tag

  additional_rabbitmq_client_security_group_ids = [
    module.security.workload_security_group_ids["api-gateway-app"],
  ]

  alarm_notification_email = var.alarm_notification_email
}

module "inventory_workloads" {
  source = "./modules/inventory-workloads"

  project_name                         = var.project_name
  environment                          = var.environment
  vpc_id                               = module.network.vpc_id
  subnet_ids                           = module.network.private_subnet_ids
  inventory_app_security_group_id      = module.security.workload_security_group_ids["inventory-app"]
  inventory_database_security_group_id = module.security.workload_security_group_ids["inventory-database"]

  ecs_cluster_name                 = module.compute_foundation.ecs_cluster_name
  ecs_capacity_provider_name       = module.compute_foundation.ecs_capacity_provider_name
  task_execution_role_arn          = module.compute_foundation.task_execution_role_arn
  task_role_arns                   = module.compute_foundation.task_role_arns
  ecr_repository_urls              = module.compute_foundation.ecr_repository_urls
  service_discovery_namespace_id   = module.compute_foundation.service_discovery_namespace_id
  service_discovery_namespace_name = module.compute_foundation.service_discovery_namespace_name
  inventory_database_secret_arn    = module.compute_foundation.secret_arns["inventory-database"]

  image_tag = var.image_tag

  alarm_notification_email = var.alarm_notification_email
}

module "edge_gateway" {
  source = "./modules/edge-gateway"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                          = module.network.vpc_id
  private_subnet_ids              = module.network.private_subnet_ids
  gateway_security_group_id       = module.security.workload_security_group_ids["api-gateway-app"]
  load_balancer_security_group_id = module.security.internal_load_balancer_security_group_id
  vpc_link_security_group_id      = module.security.vpc_link_security_group_id

  ecs_cluster_name           = module.compute_foundation.ecs_cluster_name
  ecs_capacity_provider_name = module.compute_foundation.ecs_capacity_provider_name
  task_execution_role_arn    = module.compute_foundation.task_execution_role_arn
  gateway_task_role_arn      = module.compute_foundation.task_role_arns["api-gateway-app"]
  gateway_repository_url     = module.compute_foundation.ecr_repository_urls["api-gateway-app"]
  rabbitmq_secret_arn        = module.compute_foundation.secret_arns["rabbitmq"]

  inventory_app_internal_dns = module.inventory_workloads.inventory_app_internal_dns
  rabbitmq_internal_dns      = module.billing_workloads.rabbitmq_internal_dns
  rabbitmq_queue             = module.billing_workloads.rabbitmq_queue

  image_tag                = var.image_tag
  alarm_notification_email = var.alarm_notification_email
}
