# --- 1. CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name = "cloudtrail-waf-logs-group"
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

# --- 4. SNS Topic (Notification System) ---
resource "aws_sns_topic" "alerts" {
  name = "WebACL-Modification-Alerts"
}

# --- 5. Email Subscription (Manual - Subscribe via AWS Console or CLI) ---
# To subscribe manually, run:
# aws sns subscribe --topic-arn <TOPIC_ARN> --protocol email --notification-endpoint your-email@example.com
# Then confirm via email link