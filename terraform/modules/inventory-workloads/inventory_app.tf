resource "aws_cloudwatch_log_group" "inventory_app" {
  name              = "/ecs/${local.name_prefix}/inventory-app"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-inventory-app"
  }
}

resource "aws_ecs_task_definition" "inventory_app" {
  family                   = "${local.name_prefix}-inventory-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.inventory_app_cpu)
  memory                   = tostring(var.inventory_app_memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arns["inventory-app"]

  container_definitions = jsonencode([
    {
      name      = "inventory-app"
      image     = "${var.ecr_repository_urls["inventory-app"]}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = var.inventory_port, protocol = "tcp" },
      ]

      environment = [
        { name = "INVENTORY_PORT", value = tostring(var.inventory_port) },
        { name = "INVENTORY_DB_HOST", value = local.inventory_database_host },
        { name = "INVENTORY_DB_PORT", value = "5432" },
        { name = "INVENTORY_DB_NAME", value = var.inventory_db_name },
      ]

      secrets = [
        { name = "INVENTORY_DB_USER", valueFrom = "${var.inventory_database_secret_arn}:username::" },
        { name = "INVENTORY_DB_PASSWORD", valueFrom = "${var.inventory_database_secret_arn}:password::" },
      ]

      # inventory-app has no dedicated health endpoint (confirmed by
      # reading app/__init__.py and app/routes/movies.py - no health.py,
      # no /healthz route, unlike billing-app and api-gateway-app). GET
      # /api/movies is the only side-effect-free route that exists, so it
      # doubles as the health check: it fails unless the app is up and the
      # database connection it opened at startup is actually working.
      healthCheck = {
        command     = ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.inventory_port}/api/movies', timeout=2)\" || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 5
        startPeriod = 20
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.inventory_app.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "inventory-app"
        }
      }
    },
  ])

  tags = {
    Name = "${local.name_prefix}-inventory-app"
  }
}

resource "aws_ecs_service" "inventory_app" {
  name            = "inventory-app"
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.inventory_app.arn
  desired_count   = var.inventory_app_min_capacity

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.inventory_app_security_group_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.inventory_app.arn
  }

  # Stateless: unlike rabbit-queue/billing-database/inventory-database,
  # there's no single-writer constraint here, so the default rolling
  # deployment (start new before stopping old) is fine.

  # Scaling changes desired_count outside Terraform; ignore drift instead
  # of fighting the autoscaling policy on every plan.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_service.inventory_database]

  tags = {
    Name = "${local.name_prefix}-inventory-app"
  }
}

# CPU-based auto scaling: inventory-app is the one stateless, CRUD-heavy
# service here, and the natural fit for scaling with load - rabbit-queue
# and both databases are architecturally capped at one writer.
resource "aws_appautoscaling_target" "inventory_app" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.inventory_app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.inventory_app_min_capacity
  max_capacity       = var.inventory_app_max_capacity
}

resource "aws_appautoscaling_policy" "inventory_app_cpu" {
  name               = "${local.name_prefix}-inventory-app-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.inventory_app.service_namespace
  resource_id        = aws_appautoscaling_target.inventory_app.resource_id
  scalable_dimension = aws_appautoscaling_target.inventory_app.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.inventory_app_cpu_target_percent
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
