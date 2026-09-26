# EFS instead of an instance-local/bind-mounted volume: data must survive
# both task replacement AND the underlying EC2 instance being replaced by
# the ASG, which a host-local mount cannot guarantee.

resource "aws_efs_file_system" "rabbitmq" {
  encrypted = true

  tags = {
    Name = "${local.name_prefix}-rabbit-queue-data"
  }
}

resource "aws_efs_mount_target" "rabbitmq" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.rabbitmq.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_rabbitmq.id]
}

resource "aws_efs_file_system" "billing_database" {
  encrypted = true

  tags = {
    Name = "${local.name_prefix}-billing-database-data"
  }
}

resource "aws_efs_mount_target" "billing_database" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.billing_database.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_billing_database.id]
}

# Infrastructure-level backup layer for billing data specifically (AWS
# Backup's daily automatic EFS backups). Complements, not replaces, the
# pg_dump-based logical backup/restore procedure documented and actually
# run against a local copy of this same database - see the plan doc.
# rabbit-queue is deliberately excluded: queue contents are transient
# in-flight data, not something with a "backup and restore" story.
resource "aws_efs_backup_policy" "billing_database" {
  file_system_id = aws_efs_file_system.billing_database.id

  backup_policy {
    status = "ENABLED"
  }
}
