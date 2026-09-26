resource "aws_cognito_user_pool" "api" {
  name                = "${local.name_prefix}-api-users"
  deletion_protection = "INACTIVE"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  tags = {
    Name = "${local.name_prefix}-api-users"
  }
}

resource "aws_cognito_user_pool_client" "postman" {
  name         = "${local.name_prefix}-postman"
  user_pool_id = aws_cognito_user_pool.api.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
  prevent_user_existence_errors = "ENABLED"
}
