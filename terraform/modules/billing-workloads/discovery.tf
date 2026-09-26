resource "aws_service_discovery_service" "rabbitmq" {
  name = "rabbit-queue"

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${local.name_prefix}-rabbit-queue-discovery"
  }
}

resource "aws_service_discovery_service" "billing_database" {
  name = "billing-database"

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${local.name_prefix}-billing-database-discovery"
  }
}

locals {
  rabbitmq_host         = "${aws_service_discovery_service.rabbitmq.name}.${var.service_discovery_namespace_name}"
  billing_database_host = "${aws_service_discovery_service.billing_database.name}.${var.service_discovery_namespace_name}"
}
