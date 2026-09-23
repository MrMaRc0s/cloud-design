output "vpc_id" {
  description = "ID of the project VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for internet-facing entry resources."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs for application and data workloads."
  value       = module.network.private_subnet_ids
}
