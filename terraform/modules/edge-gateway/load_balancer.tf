resource "aws_lb" "gateway" {
  name               = "${local.name_prefix}-gateway"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.load_balancer_security_group_id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-gateway"
  }
}

resource "aws_lb_target_group" "gateway" {
  name        = "${local.name_prefix}-gateway"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/healthz"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-gateway"
  }
}

resource "aws_lb_listener" "gateway" {
  load_balancer_arn = aws_lb.gateway.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  tags = {
    Name = "${local.name_prefix}-gateway"
  }
}

resource "aws_apigatewayv2_vpc_link" "gateway" {
  name               = "${local.name_prefix}-gateway"
  security_group_ids = [var.vpc_link_security_group_id]
  subnet_ids         = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-gateway"
  }
}
