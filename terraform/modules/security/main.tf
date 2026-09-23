locals {
  name_prefix = "${var.project_name}-${var.environment}"

  workload_names = toset([
    "api-gateway-app",
    "inventory-app",
    "inventory-database",
    "rabbit-queue",
    "billing-app",
    "billing-database",
  ])
}

resource "aws_security_group" "vpc_link" {
  name        = "${local.name_prefix}-vpc-link"
  description = "API Gateway VPC Link network interfaces"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-vpc-link"
  }
}

resource "aws_security_group" "internal_load_balancer" {
  name        = "${local.name_prefix}-internal-alb"
  description = "Internal load balancer in front of the API gateway container"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-internal-alb"
  }
}

resource "aws_security_group" "workload" {
  for_each = local.workload_names

  name        = "${local.name_prefix}-${each.key}"
  description = "Network access for ${each.key} ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_load_balancer" {
  security_group_id            = aws_security_group.vpc_link.id
  referenced_security_group_id = aws_security_group.internal_load_balancer.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer_from_vpc_link" {
  security_group_id            = aws_security_group.internal_load_balancer.id
  referenced_security_group_id = aws_security_group.vpc_link.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_egress_rule" "load_balancer_to_gateway" {
  security_group_id            = aws_security_group.internal_load_balancer.id
  referenced_security_group_id = aws_security_group.workload["api-gateway-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_ingress_rule" "gateway_from_load_balancer" {
  security_group_id            = aws_security_group.workload["api-gateway-app"].id
  referenced_security_group_id = aws_security_group.internal_load_balancer.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_egress_rule" "gateway_to_inventory" {
  security_group_id            = aws_security_group.workload["api-gateway-app"].id
  referenced_security_group_id = aws_security_group.workload["inventory-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "inventory_from_gateway" {
  security_group_id            = aws_security_group.workload["inventory-app"].id
  referenced_security_group_id = aws_security_group.workload["api-gateway-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "inventory_to_database" {
  security_group_id            = aws_security_group.workload["inventory-app"].id
  referenced_security_group_id = aws_security_group.workload["inventory-database"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "inventory_database_from_app" {
  security_group_id            = aws_security_group.workload["inventory-database"].id
  referenced_security_group_id = aws_security_group.workload["inventory-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "gateway_to_rabbitmq" {
  security_group_id            = aws_security_group.workload["api-gateway-app"].id
  referenced_security_group_id = aws_security_group.workload["rabbit-queue"].id
  ip_protocol                  = "tcp"
  from_port                    = 5672
  to_port                      = 5672
}

resource "aws_vpc_security_group_ingress_rule" "rabbitmq_from_gateway" {
  security_group_id            = aws_security_group.workload["rabbit-queue"].id
  referenced_security_group_id = aws_security_group.workload["api-gateway-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 5672
  to_port                      = 5672
}

resource "aws_vpc_security_group_egress_rule" "billing_to_rabbitmq" {
  security_group_id            = aws_security_group.workload["billing-app"].id
  referenced_security_group_id = aws_security_group.workload["rabbit-queue"].id
  ip_protocol                  = "tcp"
  from_port                    = 5672
  to_port                      = 5672
}

resource "aws_vpc_security_group_ingress_rule" "rabbitmq_from_billing" {
  security_group_id            = aws_security_group.workload["rabbit-queue"].id
  referenced_security_group_id = aws_security_group.workload["billing-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 5672
  to_port                      = 5672
}

resource "aws_vpc_security_group_egress_rule" "billing_to_database" {
  security_group_id            = aws_security_group.workload["billing-app"].id
  referenced_security_group_id = aws_security_group.workload["billing-database"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "billing_database_from_app" {
  security_group_id            = aws_security_group.workload["billing-database"].id
  referenced_security_group_id = aws_security_group.workload["billing-app"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "workload_https" {
  for_each = aws_security_group.workload

  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Pull images and send logs through the NAT Gateway"
}
