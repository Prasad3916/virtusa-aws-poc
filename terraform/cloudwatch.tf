# 1. CloudWatch Log Group with 14-day retention (Checklist #28)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-logs"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# 2. SNS Topic for Alarm Notifications (Checklist #30)
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms-topic"

  tags = {
    Name = "${var.project_name}-alarms-topic"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# 3. Alarm 1: ALB 5xx HTTP Errors (Checklist #30)
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-ALB-5xx-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alarm triggered when HTTP 5xx error count exceeds 5 in 1 minute"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# 4. Alarm 2: Unhealthy Target Count (Checklist #30)
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.project_name}-Unhealthy-Targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alarm triggered when ALB target group has unhealthy tasks"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.api.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# 5. Alarm 3: RDS High Database CPU Utilization (Checklist #30)
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${var.project_name}-RDS-High-CPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm triggered when RDS MySQL CPU exceeds 80% for 4 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

# 6. CloudWatch Operational Dashboard (Checklist #29)
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count & Errors (2xx / 4xx / 5xx)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Target Response Time (Latency)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.api.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Fargate CPU & Memory Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            [".", "DatabaseConnections", ".", "."]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Database Connections & CPU Utilization"
        }
      }
    ]
  })
}
