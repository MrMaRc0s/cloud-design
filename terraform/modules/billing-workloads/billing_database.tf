resource "aws_ecs_task_definition" "billing_database" {
  family                   = "${local.name_prefix}-billing-database"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.billing_database_cpu)
  memory                   = tostring(var.billing_database_memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arns["billing-database"]

  volume {
    name = "billing-database-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.billing_database.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "billing-database"
      image     = "${var.ecr_repository_urls["billing-database"]}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 5432, protocol = "tcp" },
      ]

      mountPoints = [
        { sourceVolume = "billing-database-data", containerPath = "/var/lib/postgresql/data" },
      ]

      environment = [
        { name = "POSTGRES_DB", value = var.billing_db_name },
      ]

      # Fetched by the ECS task execution role at launch, never a plain
      # environment value - see variables.tf for why.
      secrets = [
        { name = "POSTGRES_USER", valueFrom = "${var.billing_database_secret_arn}:username::" },
        { name = "POSTGRES_PASSWORD", valueFrom = "${var.billing_database_secret_arn}:password::" },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.billing_database.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "billing-database"
        }
      }
    },
  ])

  tags = {
    Name = "${local.name_prefix}-billing-database"
  }
}

# min_healthy_percent=0: avoid two Postgres processes racing to open the
# same PGDATA on EFS during a rolling replacement.
resource "aws_ecs_service" "billing_database" {
  name            = "billing-database"
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.billing_database.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.billing_database_task.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.billing_database.arn
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "${local.name_prefix}-billing-database"
  }
}
