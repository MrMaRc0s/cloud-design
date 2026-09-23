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

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Interface stub: wire to Developer A's network module output. Scopes the ECS instance security group's ingress to in-VPC traffic only."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the ECS container instances launch into. Interface stub: wire to Developer A's network module output (module.network.private_subnet_ids)."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances."
  type        = string
  default     = "t3.micro"
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

variable "owned_services" {
  description = "Developer B owned service names; each gets its own ECR repository and ECS task role."
  type        = list(string)
  default     = ["rabbit-queue", "billing-app", "billing-database"]
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
