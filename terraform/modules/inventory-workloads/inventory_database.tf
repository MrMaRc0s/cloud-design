data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "inventory_database" {
  name              = "/ecs/${local.name_prefix}/inventory-database"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-inventory-database"
  }
}

resource "aws_ecs_task_definition" "inventory_database" {
  family                   = "${local.name_prefix}-inventory-database"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.inventory_database_cpu)
  memory                   = tostring(var.inventory_database_memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arns["inventory-database"]

  volume {
    name = "inventory-database-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.inventory_database.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "inventory-database"
      image     = "${var.ecr_repository_urls["inventory-database"]}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 5432, protocol = "tcp" },
      ]

      mountPoints = [
        { sourceVolume = "inventory-database-data", containerPath = "/var/lib/postgresql/data" },
      ]

      environment = [
        { name = "POSTGRES_DB", value = var.inventory_db_name },
      ]

      secrets = [
        { name = "POSTGRES_USER", valueFrom = "${var.inventory_database_secret_arn}:username::" },
        { name = "POSTGRES_PASSWORD", valueFrom = "${var.inventory_database_secret_arn}:password::" },
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
          "awslogs-group"         = aws_cloudwatch_log_group.inventory_database.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "inventory-database"
        }
      }
    },
  ])

  tags = {
    Name = "${local.name_prefix}-inventory-database"
  }
}

# min_healthy_percent=0: avoid two Postgres processes racing to open the
# same PGDATA on EFS during a rolling replacement (same reasoning as
# billing-database).
resource "aws_ecs_service" "inventory_database" {
  name            = "inventory-database"
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.inventory_database.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.inventory_database_security_group_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.inventory_database.arn
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  # The task cannot mount EFS until a mount target exists in each selected AZ.
  depends_on = [aws_efs_mount_target.inventory_database]

  tags = {
    Name = "${local.name_prefix}-inventory-database"
  }
}
