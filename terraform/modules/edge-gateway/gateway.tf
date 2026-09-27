data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/ecs/${local.name_prefix}/api-gateway-app"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-api-gateway-app"
  }
}

resource "aws_ecs_task_definition" "gateway" {
  family                   = "${local.name_prefix}-api-gateway-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.gateway_cpu)
  memory                   = tostring(var.gateway_memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.gateway_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api-gateway-app"
      image     = "${var.gateway_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 3000, protocol = "tcp" },
      ]

      environment = [
        { name = "GATEWAY_PORT", value = "3000" },
        { name = "INVENTORY_API_URL", value = "http://${var.inventory_app_internal_dns}:8080" },
        { name = "RABBITMQ_HOST", value = var.rabbitmq_internal_dns },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_QUEUE", value = var.rabbitmq_queue },
      ]

      secrets = [
        { name = "RABBITMQ_USER", valueFrom = "${var.rabbitmq_secret_arn}:username::" },
        { name = "RABBITMQ_PASSWORD", valueFrom = "${var.rabbitmq_secret_arn}:password::" },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:3000/healthz', timeout=2)\" || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 5
        startPeriod = 20
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.gateway.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "api-gateway-app"
        }
      }
    },
  ])

  tags = {
    Name = "${local.name_prefix}-api-gateway-app"
  }
}

resource "aws_ecs_service" "gateway" {
  name                               = "api-gateway-app"
  cluster                            = var.ecs_cluster_name
  task_definition                    = aws_ecs_task_definition.gateway.arn
  desired_count                      = var.gateway_min_capacity
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.gateway_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "api-gateway-app"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener.gateway]

  tags = {
    Name = "${local.name_prefix}-api-gateway-app"
  }
}

resource "aws_appautoscaling_target" "gateway" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.gateway_min_capacity
  max_capacity       = var.gateway_max_capacity
}

resource "aws_appautoscaling_policy" "gateway_cpu" {
  name               = "${local.name_prefix}-api-gateway-app-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.gateway.service_namespace
  resource_id        = aws_appautoscaling_target.gateway.resource_id
  scalable_dimension = aws_appautoscaling_target.gateway.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.gateway_cpu_target_percent
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
