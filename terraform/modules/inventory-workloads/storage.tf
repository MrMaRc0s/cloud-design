locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_efs_file_system" "inventory_database" {
  encrypted = true

  tags = {
    Name = "${local.name_prefix}-inventory-database-data"
  }
}

# EFS mount targets need their own security group - Developer A's security
# module has no concept of EFS/NFS traffic, only ECS task-to-task rules, so
# this module owns exactly this one security group (not the task-level
# security groups themselves, which are Developer A's).
resource "aws_security_group" "efs_inventory_database" {
  name        = "${local.name_prefix}-efs-inventory-database"
  description = "EFS mount targets for inventory-database data - NFS from its task only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-efs-inventory-database"
  }
}

resource "aws_security_group_rule" "efs_inventory_database_from_task" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs_inventory_database.id
  source_security_group_id = var.inventory_database_security_group_id
}

# The ECS EFS helper mounts inside the task network namespace, so the task
# ENI must also be allowed to initiate NFS traffic to the mount target.
resource "aws_security_group_rule" "inventory_database_to_efs" {
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = var.inventory_database_security_group_id
  source_security_group_id = aws_security_group.efs_inventory_database.id
}

resource "aws_efs_mount_target" "inventory_database" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.inventory_database.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs_inventory_database.id]
}
