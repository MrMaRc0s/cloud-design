# billing-workloads

Three ECS services — `rabbit-queue`, `billing-database`, `billing-app` —
on the shared cluster from `compute-foundation`. Owns its own security
groups (Developer A's `security` module doesn't model the billing side),
EFS-backed persistent storage for the two stateful services, and Cloud Map
registration under the shared namespace. See the repo README for
architecture detail, the RabbitMQ node-identity bug found and fixed, the
backup/restore evidence, and the locally-verified failure-scenario demo.

Not yet wired into a root — every network-related input below is still an
interface stub.

## Example invocation

```hcl
module "billing_workloads" {
  source = "./modules/billing-workloads"

  project_name = "cloud-design"
  environment  = "dev"

  # From Developer A's network module:
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  # From compute-foundation:
  ecs_cluster_name                 = module.compute_foundation.ecs_cluster_name
  ecs_capacity_provider_name       = module.compute_foundation.ecs_capacity_provider_name
  task_execution_role_arn          = module.compute_foundation.task_execution_role_arn
  task_role_arns                   = module.compute_foundation.task_role_arns
  ecr_repository_urls              = module.compute_foundation.ecr_repository_urls
  service_discovery_namespace_id   = module.compute_foundation.service_discovery_namespace_id
  service_discovery_namespace_name = module.compute_foundation.service_discovery_namespace_name
  billing_database_secret_arn      = module.compute_foundation.secret_arns["billing-database"]
  rabbitmq_secret_arn              = module.compute_foundation.secret_arns["rabbitmq"]

  image_tag = "a1b2c3d" # a Git commit SHA - never "latest"

  # Add Developer A's api-gateway-app task security group ID here once it
  # exists, so it can reach rabbit-queue on 5672:
  additional_rabbitmq_client_security_group_ids = []

  # Everything else has a sensible default - override only if needed:
  # billing_db_name  = "billing"
  # rabbitmq_queue   = "billing_queue"
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
| `ecs_cluster_name`, `ecs_capacity_provider_name`, `task_execution_role_arn`, `task_role_arns`, `ecr_repository_urls`, `service_discovery_namespace_id`, `service_discovery_namespace_name` | yes | All `compute-foundation` outputs, passed through as-is. |
| `billing_database_secret_arn`, `rabbitmq_secret_arn` | yes | `compute-foundation`'s `secret_arns["billing-database"]` / `["rabbitmq"]`. |
| `image_tag` | yes, no default | A Git commit SHA or explicit version — never `"latest"`. |
| `additional_rabbitmq_client_security_group_ids` | no (`[]`) | Add Developer A's `api-gateway-app` task SG ID here at integration. |
| `billing_db_name` | no (`billing`) | Not sensitive. |
| `rabbitmq_queue` | no (`billing_queue`) | Must match Developer A's `api-gateway-app` exactly — already confirmed against their actual `srcs/api-gateway-app` config. |
| `rabbitmq_cpu`/`memory`, `billing_database_cpu`/`memory`, `billing_app_cpu`/`memory` | no | Task sizing. |
| `log_retention_days`, `cpu_alarm_threshold_percent`, `alarm_notification_email` | no | Observability. |

## Outputs

| Name | Used by |
|---|---|
| `rabbitmq_internal_dns` | Developer A's `api-gateway-app`, as its `RABBITMQ_HOST`. |
| `rabbitmq_queue` | Developer A's `api-gateway-app`, as its `RABBITMQ_QUEUE` — must match exactly. |
| `rabbitmq_task_security_group_id` | Reference only — the actual cross-team wiring is `additional_rabbitmq_client_security_group_ids` (an input on *this* module), not this output. |
| `billing_database_internal_dns`, `billing_app_task_security_group_id` | Reference / observability only. |

RabbitMQ credentials themselves aren't an output of this module — Developer
A's `api-gateway-app` should read
`module.compute_foundation.secret_arns["rabbitmq"]` directly, the same way
this module does.
