resource "aws_service_discovery_service" "inventory_database" {
  name = "inventory-database"

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${local.name_prefix}-inventory-database-discovery"
  }
}

resource "aws_service_discovery_service" "inventory_app" {
  name = "inventory-app"

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${local.name_prefix}-inventory-app-discovery"
  }
}

locals {
  inventory_database_host = "${aws_service_discovery_service.inventory_database.name}.${var.service_discovery_namespace_name}"
}
