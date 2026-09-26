resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/ecs/${local.name_prefix}/rabbit-queue"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-rabbit-queue"
  }
}

resource "aws_cloudwatch_log_group" "rabbitmq_bootstrap" {
  name              = "/ecs/${local.name_prefix}/rabbit-queue-bootstrap"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-rabbit-queue-bootstrap"
  }
}

resource "aws_cloudwatch_log_group" "billing_database" {
  name              = "/ecs/${local.name_prefix}/billing-database"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-billing-database"
  }
}

resource "aws_cloudwatch_log_group" "billing_app" {
  name              = "/ecs/${local.name_prefix}/billing-app"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-billing-app"
  }
}

resource "aws_sns_topic" "billing_alerts" {
  name = "${local.name_prefix}-billing-alerts"

  tags = {
    Name = "${local.name_prefix}-billing-alerts"
  }
}

resource "aws_sns_topic_subscription" "billing_alerts_email" {
  for_each = toset(compact([var.alarm_notification_email]))

  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# billing-app is the one service here whose logs are worth pattern-matching:
# it's plain Python logging ("... ERROR ..." lines). rabbit-queue's Erlang
# log format is noisier and error-prone to pattern-match without false
# positives from normal startup banners, so its "health" signal below is
# RunningTaskCount instead of a log-based error rate.
resource "aws_cloudwatch_log_metric_filter" "billing_app_errors" {
  name           = "${local.name_prefix}-billing-app-errors"
  log_group_name = aws_cloudwatch_log_group.billing_app.name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "${local.name_prefix}/billing-app"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "billing_app_errors" {
  alarm_name          = "${local.name_prefix}-billing-app-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.billing_app_errors.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.billing_app_errors.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "billing-app logged at least one ERROR line in the last 5 minutes"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.billing_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-billing-app-error-rate"
  }
}

resource "aws_cloudwatch_metric_alarm" "billing_app_unhealthy" {
  alarm_name          = "${local.name_prefix}-billing-app-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.billing_app.name
  }

  alarm_description  = "billing-app has fewer than 1 running task"
  treat_missing_data = "breaching"
  alarm_actions      = [aws_sns_topic.billing_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-billing-app-unhealthy"
  }
}

resource "aws_cloudwatch_metric_alarm" "billing_app_cpu" {
  alarm_name          = "${local.name_prefix}-billing-app-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_percent

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.billing_app.name
  }

  alarm_description  = "billing-app CPU above threshold for 15 minutes"
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.billing_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-billing-app-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "rabbitmq_unhealthy" {
  alarm_name          = "${local.name_prefix}-rabbit-queue-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.rabbitmq.name
  }

  alarm_description  = "rabbit-queue has fewer than 1 running task"
  treat_missing_data = "breaching"
  alarm_actions      = [aws_sns_topic.billing_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-rabbit-queue-unhealthy"
  }
}

resource "aws_cloudwatch_metric_alarm" "rabbitmq_cpu" {
  alarm_name          = "${local.name_prefix}-rabbit-queue-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_percent

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.rabbitmq.name
  }

  alarm_description  = "rabbit-queue CPU above threshold for 15 minutes"
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.billing_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-rabbit-queue-cpu-high"
  }
}

# No storage alarm for billing-database: EFS scales storage automatically,
# there is no "disk full" failure mode the way there is with EBS. The only
# EFS metric worth watching would be StorageBytes for cost tracking, which
# isn't a health/error alarm.
resource "aws_cloudwatch_metric_alarm" "billing_database_cpu" {
  alarm_name          = "${local.name_prefix}-billing-database-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_percent

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.billing_database.name
  }

  alarm_description  = "billing-database CPU above threshold for 15 minutes"
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.billing_alerts.arn]

  tags = {
    Name = "${local.name_prefix}-billing-database-cpu-high"
  }
}

resource "aws_cloudwatch_dashboard" "billing" {
  dashboard_name = "${local.name_prefix}-billing"

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
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.rabbitmq.name],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.billing_database.name],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.billing_app.name],
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
          title  = "Running Tasks"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.rabbitmq.name],
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.billing_database.name],
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", aws_ecs_service.billing_app.name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "billing-app Error Log Count"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            [aws_cloudwatch_log_metric_filter.billing_app_errors.metric_transformation[0].namespace, "ErrorCount"],
          ]
        }
      },
    ]
  })
}
