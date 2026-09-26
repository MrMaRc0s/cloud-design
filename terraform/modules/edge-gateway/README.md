# edge-gateway

Deploys the private `api-gateway-app` ECS service behind an internal ALB, then
publishes it through an API Gateway HTTP API connected by VPC Link. Cognito JWT
authorization protects every public route. CloudWatch receives application and
API access logs, alarms on failures, and displays the edge dashboard.

This module does not create the VPC, ECS cluster, images, credentials,
Inventory service or RabbitMQ service. Those values are passed from the network,
security, compute-foundation, inventory-workloads and billing-workloads modules.

## Integration contract

```hcl
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

  image_tag = var.image_tag
}
```

After deployment, create a Cognito audit user and obtain a token with the AWS
CLI. Postman sends that token as `Authorization: Bearer <token>` to the exported
`api_endpoint`.
