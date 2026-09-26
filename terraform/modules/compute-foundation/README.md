# compute-foundation

Shared ECS compute layer for all six services: one ECS cluster (EC2 launch
type), one ECR repository per service, one shared task execution role plus
one empty task role per service, one private DNS namespace for internal
service discovery, and one Secrets Manager container per credential set
(`billing-database`, `rabbitmq`, `inventory-database` — metadata only, no
values; see the repo README's "Secrets" section for why). Both developers'
workload modules (`billing-workloads`, `inventory-workloads`, and
Developer A's `api-gateway-app` workload once it exists) consume this
module's outputs as inputs.

Not yet wired into a root — every input below is still an interface stub.
Real values come from Developer A's `network` module (`vpc_id`,
`subnet_ids`) once both branches are integrated.

## Example invocation

```hcl
module "compute_foundation" {
  source = "./modules/compute-foundation"

  project_name = "cloud-design"
  environment  = "dev"

  # From Developer A's network module:
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  # Everything else has a sensible default - override only if needed:
  # instance_type              = "t3.micro"
  # asg_min_size               = 1
  # asg_max_size               = 3
  # asg_desired_capacity       = 1
  # service_discovery_namespace = "cloud-design.internal"
  # enable_container_insights   = true
  # service_names = [
  #   "api-gateway-app", "inventory-app", "inventory-database",
  #   "rabbit-queue", "billing-app", "billing-database",
  # ]
}
```

## Inputs

| Name | Required | Notes |
|---|---|---|
| `project_name` | yes | Tag/name prefix. |
| `environment` | yes | `dev` / `staging` / `prod`. |
| `vpc_id` | yes | Interface stub — Developer A's `network` module output. |
| `subnet_ids` | yes | Interface stub — Developer A's `network` module `private_subnet_ids`. |
| `instance_type` | no (`t3.micro`) | ECS container instance type. |
| `asg_min_size` / `asg_max_size` / `asg_desired_capacity` | no (`1`/`3`/`1`) | Auto Scaling Group sizing. |
| `service_names` | no (all six) | ECR repos + task roles are created for exactly this list. |
| `service_discovery_namespace` | no (`cloud-design.internal`) | Private DNS zone name. |
| `enable_container_insights` | no (`true`) | CloudWatch Container Insights on the cluster. |

## Outputs

| Name | Used by |
|---|---|
| `ecs_cluster_arn`, `ecs_cluster_name`, `ecs_capacity_provider_name` | Every workload module's `aws_ecs_service`. |
| `ecr_repository_urls` (map) | Every workload module's task definitions, and `scripts/publish-images.sh` at deploy time. |
| `task_execution_role_arn`, `task_role_arns` (map) | Every workload module's `aws_ecs_task_definition`. |
| `secret_arns` (map: `billing-database`, `rabbitmq`, `inventory-database`) | `billing-workloads`, `inventory-workloads`, and Developer A's `api-gateway-app` (for the shared `rabbitmq` secret). |
| `service_discovery_namespace_id` / `_name` | Every workload module's `aws_service_discovery_service`. |
| `ecs_instance_security_group_id`, `ecs_autoscaling_group_name` | Reference / observability only. |

