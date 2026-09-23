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

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for shared Terraform state. Decide this together (Phase 0 joint contract) before ever applying - bucket names can't be changed later without a full migration."
  type        = string
}
