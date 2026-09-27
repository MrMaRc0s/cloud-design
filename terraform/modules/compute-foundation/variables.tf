variable "project_name" {
  description = "Name used to identify and tag project resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC that owns the service discovery namespace and the ECS instance security group. Interface stub: wire to Developer A's network module output (module.network.vpc_id) once it exists."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the ECS container instances launch into. Interface stub: wire to Developer A's network module output (module.network.private_subnet_ids)."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances."
  type        = string
  default     = "m7i-flex.large"
}

variable "asg_min_size" {
  description = "Minimum number of ECS container instances."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of ECS container instances."
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of ECS container instances."
  type        = number
  default     = 1
}

variable "service_names" {
  description = "All six application service names sharing this compute foundation; each gets its own ECR repository and ECS task role. One cluster, one set of shared infrastructure for both developers' workloads."
  type        = list(string)
  default = [
    "api-gateway-app",
    "inventory-app",
    "inventory-database",
    "rabbit-queue",
    "billing-app",
    "billing-database",
  ]
}

variable "service_discovery_namespace" {
  description = "Private DNS namespace for internal service discovery, matching the joint contract's internal DNS names (e.g. billing-app.cloud-design.internal)."
  type        = string
  default     = "cloud-design.internal"
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights on the ECS cluster."
  type        = bool
  default     = true
}
