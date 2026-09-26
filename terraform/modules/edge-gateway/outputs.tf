output "api_endpoint" {
  description = "Public HTTPS endpoint protected by the Cognito JWT authorizer."
  value       = aws_apigatewayv2_api.gateway.api_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID used to create audit users."
  value       = aws_cognito_user_pool.api.id
}

output "cognito_user_pool_client_id" {
  description = "Public Cognito client ID used by Postman to request a token."
  value       = aws_cognito_user_pool_client.postman.id
}

output "gateway_service_name" {
  description = "ECS service name for operational checks and scaling tests."
  value       = aws_ecs_service.gateway.name
}

output "gateway_target_group_arn" {
  description = "Internal ALB target group serving the gateway ECS tasks."
  value       = aws_lb_target_group.gateway.arn
}

output "internal_load_balancer_dns" {
  description = "Private DNS name of the internal ALB."
  value       = aws_lb.gateway.dns_name
}
