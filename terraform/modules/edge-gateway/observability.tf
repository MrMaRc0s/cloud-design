resource "aws_sns_topic" "edge_alarms" {
  name = "${local.name_prefix}-edge-alarms"

  tags = {
    Name = "${local.name_prefix}-edge-alarms"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_notification_email == null ? 0 : 1

  topic_arn = aws_sns_topic.edge_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

resource "aws_cloudwatch_metric_alarm" "gateway_cpu" {
  alarm_name          = "${local.name_prefix}-gateway-high-cpu"
  alarm_description   = "Gateway ECS CPU remained above the operational threshold."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.gateway_cpu_alarm_percent
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.edge_alarms.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.gateway.name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name_prefix}-api-5xx"
  alarm_description   = "Public HTTP API returned repeated server errors."
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = var.api_5xx_alarm_count
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.edge_alarms.arn]

  dimensions = {
    ApiId = aws_apigatewayv2_api.gateway.id
    Stage = aws_apigatewayv2_stage.default.name
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_gateway_targets" {
  alarm_name          = "${local.name_prefix}-gateway-unhealthy-targets"
  alarm_description   = "The internal ALB has an unhealthy Gateway target."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.edge_alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.gateway.arn_suffix
    TargetGroup  = aws_lb_target_group.gateway.arn_suffix
  }
}

resource "aws_cloudwatch_dashboard" "edge" {
  dashboard_name = "${local.name_prefix}-edge"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Gateway CPU"
          region = data.aws_region.current.region
          stat   = "Average"
          period = 60
          metrics = [[
            "AWS/ECS", "CPUUtilization",
            "ClusterName", var.ecs_cluster_name,
            "ServiceName", aws_ecs_service.gateway.name,
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Public API responses"
          region = data.aws_region.current.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.gateway.id, "Stage", aws_apigatewayv2_stage.default.name],
            [".", "4xx", ".", ".", ".", "."],
            [".", "5xx", ".", ".", ".", "."],
          ]
        }
      },
    ]
  })
}
