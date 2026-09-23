variable "project_name" {
  description = "Name used as a prefix for network resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 address range reserved for the VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "enable_nat_gateway" {
  description = "Create one NAT Gateway so private workloads can reach ECR and CloudWatch."
  type        = bool
  default     = true
}
