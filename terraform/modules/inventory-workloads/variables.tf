variable "project_name" {
  description = "Name used to identify and tag project resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

# --- Network stubs (Developer A's network + security modules) ---

variable "vpc_id" {
  description = "VPC that owns the EFS mount-target security group. Interface stub: wire to Developer A's network module output."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the ECS tasks and EFS mount targets use. Interface stub: wire to Developer A's network module output."
  type        = list(string)
}

variable "inventory_app_security_group_id" {
  description = "Security group for the inventory-app ECS task. Owned by Developer A's security module (workload_security_group_ids[\"inventory-app\"]) - this module does not create its own, unlike billing-workloads, since Developer A's security module already models both inventory workloads and their traffic paths to api-gateway-app."
  type        = string
}

variable "inventory_database_security_group_id" {
  description = "Security group for the inventory-database ECS task. Owned by Developer A's security module (workload_security_group_ids[\"inventory-database\"])."
  type        = string
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
  description = "Name of the private DNS namespace, e.g. cloud-design.internal (compute-foundation module output)."
  type        = string
}

variable "inventory_database_secret_arn" {
  description = "ARN of the inventory-database credentials secret (compute-foundation module output secret_arns[\"inventory-database\"]). JSON keys: username, password."
  type        = string
}

# --- Images ---

variable "image_tag" {
  description = "Tag to deploy for both owned images - a Git commit SHA or explicit version. Required, no default: the ECR repos are image_tag_mutability=IMMUTABLE, and \"latest\" must never be the deployed release."
  type        = string
}

# --- Inventory database config ---

variable "inventory_db_name" {
  description = "inventory-database database name. Not sensitive - the credentials that matter are in Secrets Manager."
  type        = string
  default     = "inventory"
}

# --- Inventory app config ---

variable "inventory_port" {
  description = "Port inventory-app listens on, per the joint contract's internal DNS/ports table (inventory-app:8080)."
  type        = number
  default     = 8080
}

# --- Sizing ---

variable "inventory_database_cpu" {
  type    = number
  default = 256
}

variable "inventory_database_memory" {
  type    = number
  default = 400
}

variable "inventory_app_cpu" {
  type    = number
  default = 128
}

variable "inventory_app_memory" {
  type    = number
  default = 200
}

# --- Auto scaling (inventory-app only - the stateless, CRUD-heavy service) ---

variable "inventory_app_min_capacity" {
  type    = number
  default = 1
}

variable "inventory_app_max_capacity" {
  type    = number
  default = 4
}

variable "inventory_app_cpu_target_percent" {
  description = "Target CPUUtilization percent for inventory-app's target-tracking scaling policy."
  type        = number
  default     = 60
}

# --- Observability ---

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "cpu_alarm_threshold_percent" {
  type    = number
  default = 80
}

variable "alarm_notification_email" {
  description = "Email address subscribed to the inventory alerts SNS topic. Leave null to create the topic with no subscriber."
  type        = string
  default     = null
}
