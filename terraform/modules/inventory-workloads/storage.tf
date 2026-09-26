locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_efs_file_system" "inventory_database" {
  encrypted = true

  tags = {
    Name = "${local.name_prefix}-inventory-database-data"
  }
}

# Access point (billing-database, built earlier, uses a bare EFS mount
# without one - this module adds it per this task's explicit ask). Fixed at
# uid/gid 0: the container's own entrypoint does `chown -R postgres:postgres`
# as root on first boot, and Debian's postgresql package doesn't guarantee a
# stable postgres uid across rebuilds - locking the access point to a
# non-root uid would fight that chown instead of cooperating with it. The
# access point still earns its keep by giving the mount a scoped root
# directory with defined creation permissions, separate from the raw
# filesystem root.
resource "aws_efs_access_point" "inventory_database" {
  file_system_id = aws_efs_file_system.inventory_database.id

  posix_user {
    uid = 0
    gid = 0
  }

  root_directory {
    path = "/inventory-database"

    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0700"
    }
  }

  tags = {
    Name = "${local.name_prefix}-inventory-database-access-point"
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

resource "aws_efs_mount_target" "inventory_database" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.inventory_database.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_inventory_database.id]
}
