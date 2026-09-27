variable "project_name" {
  description = "Name used to identify and tag project resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the private gateway service and load balancer."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by ECS, the internal ALB and VPC Link."
  type        = list(string)
}

variable "gateway_security_group_id" {
  description = "Security group attached to the api-gateway-app ECS tasks."
  type        = string
}

variable "load_balancer_security_group_id" {
  description = "Security group attached to the internal ALB."
  type        = string
}

variable "vpc_link_security_group_id" {
  description = "Security group attached to API Gateway VPC Link interfaces."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the shared ECS cluster."
  type        = string
}

variable "ecs_capacity_provider_name" {
  description = "Name of the EC2 ECS capacity provider."
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS execution role used for ECR, logs and runtime secrets."
  type        = string
}

variable "gateway_task_role_arn" {
  description = "IAM task role dedicated to api-gateway-app."
  type        = string
}

variable "gateway_repository_url" {
  description = "ECR repository URL for api-gateway-app."
  type        = string
}

variable "image_tag" {
  description = "Immutable Git SHA or explicit image version to deploy."
  type        = string

  validation {
    condition     = length(trimspace(var.image_tag)) > 0 && var.image_tag != "latest"
    error_message = "image_tag must be an explicit immutable version, not latest."
  }
}

variable "inventory_app_internal_dns" {
  description = "Private Cloud Map DNS name of inventory-app."
  type        = string
}

variable "rabbitmq_internal_dns" {
  description = "Private Cloud Map DNS name of rabbit-queue."
  type        = string
}

variable "rabbitmq_secret_arn" {
  description = "Secrets Manager ARN containing username and password JSON keys."
  type        = string
}

variable "rabbitmq_queue" {
  description = "Durable queue shared by the gateway producer and billing consumer."
  type        = string
  default     = "billing_queue"
}

variable "gateway_cpu" {
  description = "CPU units reserved by the Gateway task."
  type        = number
  default     = 128
}

variable "gateway_memory" {
  description = "Memory in MiB reserved by the Gateway task."
  type        = number
  default     = 256
}

variable "gateway_min_capacity" {
  type    = number
  default = 1
}

variable "gateway_max_capacity" {
  type    = number
  default = 3
}

variable "gateway_cpu_target_percent" {
  type    = number
  default = 60
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alarm_notification_email" {
  description = "Optional email subscribed to edge alarms."
  type        = string
  default     = null
}

variable "gateway_cpu_alarm_percent" {
  type    = number
  default = 80
}

variable "api_5xx_alarm_count" {
  type    = number
  default = 5
}
