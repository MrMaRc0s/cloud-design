variable "aws_region" {
  description = "AWS region where the project resources will be created."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name used to identify and tag project resources."
  type        = string
  default     = "cloud-design"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

