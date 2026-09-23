data "aws_region" "current" {}

# rabbit-queue's custom image has no equivalent of the official image's
# RABBITMQ_DEFAULT_USER/PASS, so nothing provisions the account billing-app
# and api-gateway-app authenticate as. Bootstrapped here by a sidecar that
# calls the Management HTTP API (already enabled in the image) as guest,
# which RabbitMQ restricts to loopback by default - safe specifically
# because "loopback" here means "inside this same ECS task" (awsvpc mode
# puts both containers on one network namespace), not reachable from
# anywhere else. PUT is idempotent, so this runs safely on every start.
resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "${local.name_prefix}-rabbit-queue"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.rabbitmq_cpu)
  memory                   = tostring(var.rabbitmq_memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arns["rabbit-queue"]

  volume {
    name = "rabbit-queue-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.rabbitmq.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "rabbit-queue"
      image     = "${var.ecr_repository_urls["rabbit-queue"]}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 5672, protocol = "tcp" },
      ]

      mountPoints = [
        { sourceVolume = "rabbit-queue-data", containerPath = "/var/lib/rabbitmq" },
      ]

      # Without a pinned node name, RabbitMQ derives it from the container's
      # hostname, which is random per task. On replacement the new task
      # can't find its old Mnesia directory (named after the old node) and
      # silently boots an empty database instead - confirmed locally: the
      # bootstrap user and the durable queue both vanished. rabbit@localhost
      # is both stable across replacements and always resolvable, so this
      # never happens.
      environment = [
        { name = "RABBITMQ_NODENAME", value = "rabbit@localhost" },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "rabbitmq-diagnostics -q ping || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rabbitmq.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "rabbit-queue"
        }
      }
    },
    {
      name       = "rabbit-queue-bootstrap"
      image      = "${var.ecr_repository_urls["rabbit-queue"]}:${var.image_tag}"
      essential  = false
      entryPoint = ["sh", "-c"]
      command = [
        <<-SCRIPT
        until curl -sf -u guest:guest http://localhost:15672/api/whoami >/dev/null; do sleep 2; done # gitleaks:allow - RabbitMQ's own public default cred, loopback-only
        curl -sf -u guest:guest -X PUT "http://localhost:15672/api/users/$RABBITMQ_USER" -H 'content-type: application/json' -d "{\"password\":\"$RABBITMQ_PASSWORD\",\"tags\":\"administrator\"}" # gitleaks:allow - same
        curl -sf -u guest:guest -X PUT "http://localhost:15672/api/permissions/%2F/$RABBITMQ_USER" -H 'content-type: application/json' -d '{"configure":".*","write":".*","read":".*"}' # gitleaks:allow - same
        SCRIPT
      ]

      dependsOn = [
        { containerName = "rabbit-queue", condition = "HEALTHY" },
      ]

      environment = [
        { name = "RABBITMQ_USER", value = var.rabbitmq_user },
        { name = "RABBITMQ_PASSWORD", value = var.rabbitmq_password },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rabbitmq_bootstrap.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "bootstrap"
        }
      }
    },
  ])

  tags = {
    Name = "${local.name_prefix}-rabbit-queue"
  }
}

# min_healthy_percent=0 forces ECS to stop the old task before starting a
# replacement rather than briefly running two - the joint contract
# explicitly forbids two live brokers sharing one data directory.
resource "aws_ecs_service" "rabbitmq" {
  name            = "rabbit-queue"
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.rabbitmq_task.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq.arn
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "${local.name_prefix}-rabbit-queue"
  }
}
