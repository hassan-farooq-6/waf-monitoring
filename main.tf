# --- 1. Create the Web ACL ---
resource "aws_wafv2_web_acl" "main" {
  name        = var.web_acl_name
  description = "Production Web ACL for monitoring and security"
  scope       = "REGIONAL" # Use CLOUDFRONT if you are using it for CloudFront
  
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.web_acl_name
    sampled_requests_enabled   = true
  }
}

# --- 2. Get Current Account ID (Needed for Policies) ---
data "aws_caller_identity" "current" {}

# --- 3. Create S3 Bucket for CloudTrail Logs ---
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket_prefix = "cloudtrail-waf-logs-" # Adds a random suffix to make it unique
  force_destroy = true # Allows deleting bucket even if it has logs (for testing)
}

# --- 4. S3 Bucket Policy (CRITICAL) ---
# This allows CloudTrail to write logs to this S3 bucket
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# --- 5. Create CloudTrail ---
resource "aws_cloudtrail" "waf_trail" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  s3_key_prefix                 = "prefix"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  # --- NEW: CloudWatch Integration ---
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.waf_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw_role.arn
  
  # Ensure the Log Group exists before creating the trail
  depends_on = [aws_cloudwatch_log_group.waf_log_group] 
}