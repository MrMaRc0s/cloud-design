variable "project_name" {
  description = "Name used to identify and tag project resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

# --- Network stubs (Developer A's future network module) ---

variable "vpc_id" {
  description = "VPC that owns the task/EFS security groups. Interface stub: wire to Developer A's network module output."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the ECS tasks and EFS mount targets use. Interface stub: wire to Developer A's network module output."
  type        = list(string)
}

# --- Compute foundation outputs ---

variable "ecs_cluster_name" {
  description = "Name of the shared ECS cluster (compute-foundation module output)."
  type        = string
}

variable "ecs_capacity_provider_name" {
  description = "Name of the EC2 capacity provider (compute-foundation module output)."
  type        = string
}

variable "task_execution_role_arn" {
  description = "Shared ECS task execution role ARN (compute-foundation module output)."
  type        = string
}

variable "task_role_arns" {
  description = "Map of service name to its dedicated ECS task role ARN (compute-foundation module output)."
  type        = map(string)
}

variable "ecr_repository_urls" {
  description = "Map of service name to its ECR repository URL (compute-foundation module output)."
  type        = map(string)
}

variable "service_discovery_namespace_id" {
  description = "ID of the private DNS namespace (compute-foundation module output)."
  type        = string
}

variable "service_discovery_namespace_name" {
  description = "Name of the private DNS namespace, e.g. cloud-design.internal (compute-foundation module output). Used to build internal DNS names such as billing-database.cloud-design.internal."
  type        = string
}

# --- Images ---

variable "image_tag" {
  description = "Tag to deploy for all three owned images - a Git commit SHA or explicit version. Required, no default: the ECR repos are image_tag_mutability=IMMUTABLE, so a real deploy pipeline must push a new unique tag each build, and \"latest\" must never be the deployed release."
  type        = string
}

# --- Secrets (compute-foundation module outputs) ---
# Usernames and passwords are never Terraform variables here - both secrets
# are populated out-of-band via scripts/put-secret-value.sh, and the ECS
# task execution role reads them directly into each container's `secrets`
# block. See the README for why (a Terraform-managed value would land in
# state even if never written to source).

variable "billing_database_secret_arn" {
  description = "ARN of the billing-database credentials secret (compute-foundation module output secret_arns[\"billing-database\"]). JSON keys: username, password."
  type        = string
}

variable "rabbitmq_secret_arn" {
  description = "ARN of the rabbitmq credentials secret (compute-foundation module output secret_arns[\"rabbitmq\"]). JSON keys: username, password. Shared with Developer A's api-gateway-app, which authenticates as the same account to publish to the same queue."
  type        = string
}

# --- Billing database config ---

variable "billing_db_name" {
  description = "billing-database database name. Not sensitive - the credentials that matter are in Secrets Manager."
  type        = string
  default     = "billing"
}

# --- RabbitMQ config ---
# rabbitmq_queue is a cross-team interface: Developer A's api-gateway-app
# publishes to the same queue with the same credentials (confirmed via
# srcs/api-gateway-app/tests using rabbitmq_queue="billing_queue").

variable "rabbitmq_queue" {
  description = "Durable queue name shared by billing-app (consumer) and api-gateway-app (producer). Must match api-gateway-app's configured queue name exactly."
  type        = string
  default     = "billing_queue"
}

variable "additional_rabbitmq_client_security_group_ids" {
  description = "Extra security group IDs allowed to reach rabbit-queue on 5672, beyond billing-app's own. Populate with Developer A's api-gateway-app task security group ID at integration time."
  type        = list(string)
  default     = []
}

# --- Sizing ---
# Deliberately modest: three tasks won't fit on one t3.micro instance
# alongside OS/agent overhead, so the compute-foundation ASG (managed
# scaling, max_size=3) will add instances as needed. Running multiple
# t3.micro instances 24/7 exceeds the combined 750 hrs/month Free Tier
# allowance faster than a single instance would - factor this into the
# budget check before any apply.

variable "rabbitmq_cpu" {
  type    = number
  default = 256
}

variable "rabbitmq_memory" {
  type    = number
  default = 400
}

variable "billing_database_cpu" {
  type    = number
  default = 256
}

variable "billing_database_memory" {
  type    = number
  default = 400
}

variable "billing_app_cpu" {
  type    = number
  default = 128
}

variable "billing_app_memory" {
  type    = number
  default = 200
}

# --- Observability ---

variable "log_retention_days" {
  description = "CloudWatch Logs retention for all four owned log groups (rabbit-queue, its bootstrap sidecar, billing-database, billing-app)."
  type        = number
  default     = 14
}

variable "alarm_notification_email" {
  description = "Email address subscribed to the billing alerts SNS topic. Leave null to create the topic with no subscriber (e.g. for a first validate-only pass)."
  type        = string
  default     = null
}

variable "cpu_alarm_threshold_percent" {
  description = "CPUUtilization percent that triggers a high-CPU alarm on each service."
  type        = number
  default     = 80
}
