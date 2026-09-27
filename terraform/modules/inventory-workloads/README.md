# inventory-workloads

Two ECS services — `inventory-database`, `inventory-app` — on the shared
cluster from `compute-foundation`. Unlike `billing-workloads`, this module
does **not** create security groups for its two workloads: Developer A's
`security` module already owns `workload_security_group_ids["inventory-app"]`
and `["inventory-database"]`, plus the gateway↔inventory↔database traffic
path. This module owns exactly one security group of its own, for the EFS
mount targets, since Developer A's `security` module has no NFS/EFS
concept. See the repo README for the EFS access point design and the
missing-health-endpoint finding.

Not yet wired into a root — every network-related input below is still an
interface stub.

## Example invocation

```hcl
module "inventory_workloads" {
  source = "./modules/inventory-workloads"

  project_name = "cloud-design"
  environment  = "dev"

  # From Developer A's network module:
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  # From Developer A's security module:
  inventory_app_security_group_id      = module.security.workload_security_group_ids["inventory-app"]
  inventory_database_security_group_id = module.security.workload_security_group_ids["inventory-database"]

  # From compute-foundation:
  ecs_cluster_name                 = module.compute_foundation.ecs_cluster_name
  ecs_capacity_provider_name       = module.compute_foundation.ecs_capacity_provider_name
  task_execution_role_arn          = module.compute_foundation.task_execution_role_arn
  task_role_arns                   = module.compute_foundation.task_role_arns
  ecr_repository_urls               = module.compute_foundation.ecr_repository_urls
  service_discovery_namespace_id   = module.compute_foundation.service_discovery_namespace_id
  service_discovery_namespace_name = module.compute_foundation.service_discovery_namespace_name
  inventory_database_secret_arn    = module.compute_foundation.secret_arns["inventory-database"]

  image_tag = "a1b2c3d" # a Git commit SHA - never "latest"

  # Everything else has a sensible default - override only if needed:
  # inventory_db_name = "inventory"
  # inventory_port    = 8080
  # inventory_app_min_capacity      = 1
  # inventory_app_max_capacity      = 4
  # inventory_app_cpu_target_percent = 60
  # log_retention_days          = 14
  # cpu_alarm_threshold_percent = 80
  # alarm_notification_email    = null
}
```

## Inputs

| Name | Required | Notes |
|---|---|---|
| `project_name`, `environment` | yes | Same values passed to `compute-foundation`. |
| `vpc_id`, `subnet_ids` | yes | Interface stubs — Developer A's `network` module outputs. |
| `inventory_app_security_group_id`, `inventory_database_security_group_id` | yes | Developer A's `security` module `workload_security_group_ids` map entries — **not** created by this module. |
| `ecs_cluster_name`, `ecs_capacity_provider_name`, `task_execution_role_arn`, `task_role_arns`, `ecr_repository_urls`, `service_discovery_namespace_id`, `service_discovery_namespace_name` | yes | All `compute-foundation` outputs, passed through as-is. |
| `inventory_database_secret_arn` | yes | `compute-foundation`'s `secret_arns["inventory-database"]`. |
| `image_tag` | yes, no default | A Git commit SHA or explicit version — never `"latest"`. |
| `inventory_db_name` | no (`inventory`) | Not sensitive. |
| `inventory_port` | no (`8080`) | Per the joint contract's internal DNS/ports table. |
| `inventory_app_min_capacity`/`max_capacity`/`cpu_target_percent` | no (`1`/`4`/`60`) | Application Auto Scaling target-tracking policy. |
| `inventory_database_cpu`/`memory`, `inventory_app_cpu`/`memory` | no | Task sizing. |
| `log_retention_days`, `cpu_alarm_threshold_percent`, `alarm_notification_email` | no | Observability. |

## Outputs

| Name | Used by |
|---|---|
| `inventory_app_internal_dns` | Developer A's `api-gateway-app`, as its `INVENTORY_API_URL`. |
| `inventory_database_internal_dns` | Reference only — consumed internally by `inventory-app`, not exposed elsewhere. |
| `inventory_app_service_name`, `inventory_database_service_name`, `*_task_definition_family` | Reference / observability only. |
