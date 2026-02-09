# --- 1. CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name = "cloudtrail-waf-logs-group"
  # Retention is important so you don't pay for infinite storage
  retention_in_days = 30 
}

# --- 2. IAM Role for CloudTrail to write to CloudWatch ---
resource "aws_iam_role" "cloudtrail_cw_role" {
  name = "CloudTrail_CloudWatchLogs_Role_TF"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

# --- 3. IAM Policy for the Role ---
resource "aws_iam_role_policy" "cloudtrail_cw_policy" {
  name = "CloudTrail_CloudWatchLogs_Policy"
  role = aws_iam_role.cloudtrail_cw_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.waf_log_group.arn}:*"
      }
    ]
  })
}

# --- 4. The Metric Filter (The "Brain") ---
resource "aws_cloudwatch_log_metric_filter" "waf_change_filter" {
  name           = "WebACL-Modifications-Filter"
  pattern        = "{ ($.eventSource = wafv2.amazonaws.com) && (($.eventName = UpdateWebACL) || ($.eventName = CreateWebACL) || ($.eventName = DeleteWebACL)) && ($.requestParameters.name = \"${var.web_acl_name}\") }"
  log_group_name = aws_cloudwatch_log_group.waf_log_group.name

  metric_transformation {
    name      = "WebACLModifications"
    namespace = "WAF/Monitoring"
    value     = "1"
    default_value = "0"
  }
}

# --- 5. SNS Topic (Notification System) ---
resource "aws_sns_topic" "alerts" {
  name = "WebACL-Modification-Alerts"
}

# --- 6. Email Subscription ---
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- 7. CloudWatch Alarm ---
resource "aws_cloudwatch_metric_alarm" "waf_alarm" {
  alarm_name          = "WebACL-Modification-Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "WebACLModifications"
  namespace           = "WAF/Monitoring"
  period              = "300" # 5 minutes
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Triggers when WebACL is created, updated, or deleted"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
}