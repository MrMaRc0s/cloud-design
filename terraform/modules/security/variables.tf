variable "project_name" {
  description = "Name used as a prefix for security groups."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC that contains the workloads."
  type        = string
}
