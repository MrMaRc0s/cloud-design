resource "aws_ecs_task_definition" "billing_app" {
  family                   = "${local.name_prefix}-billing-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.billing_app_cpu)
  memory                   = tostring(var.billing_app_memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arns["billing-app"]

  container_definitions = jsonencode([
    {
      name      = "billing-app"
      image     = "${var.ecr_repository_urls["billing-app"]}:${var.image_tag}"
      essential = true

      # 8080 is health-only: billing orders arrive exclusively via RabbitMQ,
      # per the joint contract's internal DNS/ports table.
      portMappings = [
        { containerPort = 8080, protocol = "tcp" },
      ]

      environment = [
        { name = "BILLING_DB_HOST", value = local.billing_database_host },
        { name = "BILLING_DB_PORT", value = "5432" },
        { name = "BILLING_DB_NAME", value = var.billing_db_name },
        { name = "BILLING_DB_USER", value = var.billing_db_user },
        { name = "BILLING_DB_PASSWORD", value = var.billing_db_password },
        { name = "RABBITMQ_HOST", value = local.rabbitmq_host },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_USER", value = var.rabbitmq_user },
        { name = "RABBITMQ_PASSWORD", value = var.rabbitmq_password },
        { name = "RABBITMQ_QUEUE", value = var.rabbitmq_queue },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz', timeout=2)\" || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 5
        startPeriod = 20
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${local.name_prefix}/billing-app"
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "billing-app"
          "awslogs-create-group"  = "true"
        }
      }
    },
  ])

  tags = {
    Name = "${local.name_prefix}-billing-app"
  }
}

resource "aws_ecs_service" "billing_app" {
  name            = "billing-app"
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.billing_app.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.billing_app_task.id]
    assign_public_ip = false
  }

  # Starts after its dependencies exist, so the first bootstrap/health
  # cycle has something to actually connect to.
  depends_on = [aws_ecs_service.rabbitmq, aws_ecs_service.billing_database]

  tags = {
    Name = "${local.name_prefix}-billing-app"
  }
}
