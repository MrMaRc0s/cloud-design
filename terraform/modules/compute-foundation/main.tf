locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Derived instead of taken as a separate input: Developer A's network module
# doesn't output vpc_cidr, and deriving it here means it can never drift
# from the VPC's actual range.
data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

# EC2 launch type: cheaper per compute-hour than Fargate and the instance
# fits the AWS Free Tier (t3.micro, 750 hrs/month), at the cost of owning
# AMI updates/patching and ASG capacity planning ourselves instead of AWS
# managing it.
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_iam_role" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-instance"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_managed" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# SSM Session Manager instead of SSH: no key pair, no port 22 ingress rule,
# no public IP needed to reach a shell on the instance.
resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance"
  role = aws_iam_role.ecs_instance.name
}

# No ingress from the internet; only from inside the VPC (task-to-instance
# dynamic port mappings, internal load balancer health checks). Access for
# operators is via SSM Session Manager, not SSH, so there is no port 22 rule.
resource "aws_security_group" "ecs_instance" {
  name        = "${local.name_prefix}-ecs-instance"
  description = "ECS container instances - in-VPC ingress only, no SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "All TCP from within the VPC (dynamic host ports)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-instance"
  }
}

resource "aws_launch_template" "ecs_instance" {
  name_prefix   = "${local.name_prefix}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  vpc_security_group_ids = [aws_security_group.ecs_instance.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.name_prefix}-ecs-instance"
    }
  }

  tags = {
    Name = "${local.name_prefix}-ecs-launch-template"
  }
}

resource "aws_autoscaling_group" "ecs_instance" {
  name                  = "${local.name_prefix}-ecs-asg"
  vpc_zone_identifier   = var.subnet_ids
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  desired_capacity      = var.asg_desired_capacity
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.ecs_instance.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "${local.name_prefix}-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_instance.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.ec2.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    base              = 0
    weight            = 1
  }
}

resource "aws_ecr_repository" "owned" {
  for_each = toset(var.service_names)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  # Without this, `terraform destroy` fails on any repo that still has
  # images in it instead of just deleting them - a dev/audit exercise that
  # gets torn down between sessions needs destroy to actually complete.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.name_prefix}-${each.value}"
  }
}

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-execution"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# One task role per service, shared by both developers' workloads. Empty
# for now; each workload module attaches the specific permissions its own
# service needs (e.g. Secrets Manager reads for billing-database,
# rabbit-queue, and inventory-database credentials).
resource "aws_iam_role" "task" {
  for_each = toset(var.service_names)

  name = "${local.name_prefix}-${each.value}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-${each.value}-task"
  }
}

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = var.service_discovery_namespace
  vpc  = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-service-discovery"
  }
}
