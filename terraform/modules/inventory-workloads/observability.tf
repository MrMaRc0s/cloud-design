resource "aws_sns_topic" "inventory_alerts" {
  name = "${local.name_prefix}-inventory-alerts"

  tags = {
    Name = "${local.name_prefix}-inventory-alerts"
  }
}

resource "aws_sns_topic_subscription" "inventory_alerts_email" {
  for_each = toset(compact([var.alarm_notification_email]))

  topic_arn = aws_sns_topic.inventory_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# No log-based error-rate alarm here, unlike billing-app: inventory-app's
# routes return 400/404 as ordinary JSON responses for client validation
# failures (confirmed by reading app/routes/movies.py) rather than logging
# at ERROR level, so a metric filter on "ERROR" would just sit at zero -
# not a meaningful signal, not an oversight.
resource "aws_cloudwatch_metric_alarm" "inventory_app_unhealthy" {
  alarm_name          = "${local.name_prefix}-inventory-app-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = var.inventory_app_min_capacity

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.inventory_app.name
  }

  alarm_description  = "inventory-app has fewer running tasks than its configured minimum"
  treat_missing_data = "breaching"
  alarm_actions      = [aws_sns_topic.inventory_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-inventory-app-unhealthy"
  }
}

resource "aws_cloudwatch_metric_alarm" "inventory_app_cpu" {
  alarm_name          = "${local.name_prefix}-inventory-app-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_percent

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.inventory_app.name
  }

  alarm_description  = "inventory-app CPU above threshold for 15 minutes (independent of the autoscaling target-tracking policy, which reacts faster)"
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.inventory_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-inventory-app-cpu-high"
  }
}

# No storage alarm for inventory-database, same reasoning as
# billing-database: EFS scales storage automatically.
resource "aws_cloudwatch_metric_alarm" "inventory_database_cpu" {
  alarm_name          = "${local.name_prefix}-inventory-database-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_percent

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.inventory_database.name
  }

  alarm_description  = "inventory-database CPU above threshold for 15 minutes"
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.inventory_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-inventory-database-cpu-high"
  }
}

resource "aws_cloudwatch_dashboard" "inventory" {
  dashboard_name = "${local.name_prefix}-inventory"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.inventory_app.name],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.inventory_database.name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Running Tasks (inventory-app desired count reflects autoscaling)"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.inventory_app.name],
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.inventory_database.name],
          ]
        }
      },
    ]
  })
}
