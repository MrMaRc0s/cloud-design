locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_security_group" "billing_app_task" {
  name        = "${local.name_prefix}-billing-app-task"
  description = "billing-app ECS task - health checks only, no inbound API traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Health check from within the VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-billing-app-task"
  }
}

resource "aws_security_group" "rabbitmq_task" {
  name        = "${local.name_prefix}-rabbit-queue-task"
  description = "rabbit-queue ECS task - 5672 from authorized clients only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rabbit-queue-task"
  }
}

resource "aws_security_group_rule" "rabbitmq_from_billing_app" {
  type                     = "ingress"
  from_port                = 5672
  to_port                  = 5672
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rabbitmq_task.id
  source_security_group_id = aws_security_group.billing_app_task.id
}

# Developer A's api-gateway-app also publishes to this queue (same
# RABBITMQ_USER/QUEUE, confirmed against srcs/api-gateway-app). Add its task
# security group ID here at integration time.
resource "aws_security_group_rule" "rabbitmq_from_additional_clients" {
  for_each = toset(var.additional_rabbitmq_client_security_group_ids)

  type                     = "ingress"
  from_port                = 5672
  to_port                  = 5672
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rabbitmq_task.id
  source_security_group_id = each.value
}

resource "aws_security_group" "billing_database_task" {
  name        = "${local.name_prefix}-billing-database-task"
  description = "billing-database ECS task - 5432 from billing-app only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-billing-database-task"
  }
}

resource "aws_security_group_rule" "billing_database_from_billing_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.billing_database_task.id
  source_security_group_id = aws_security_group.billing_app_task.id
}

resource "aws_security_group" "efs_rabbitmq" {
  name        = "${local.name_prefix}-efs-rabbit-queue"
  description = "EFS mount targets for rabbit-queue data - NFS from its task only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-efs-rabbit-queue"
  }
}

resource "aws_security_group_rule" "efs_rabbitmq_from_task" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs_rabbitmq.id
  source_security_group_id = aws_security_group.rabbitmq_task.id
}

resource "aws_security_group" "efs_billing_database" {
  name        = "${local.name_prefix}-efs-billing-database"
  description = "EFS mount targets for billing-database data - NFS from its task only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-efs-billing-database"
  }
}

resource "aws_security_group_rule" "efs_billing_database_from_task" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs_billing_database.id
  source_security_group_id = aws_security_group.billing_database_task.id
}
