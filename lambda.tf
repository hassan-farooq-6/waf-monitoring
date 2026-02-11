# Lambda function to parse CloudTrail events and send detailed notifications
resource "aws_lambda_function" "waf_alert_parser" {
  filename      = "lambda_function.zip"
  function_name = "WAF-Alert-Parser"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy]
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "WAF-Alert-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda policy
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "lambda-sns-publish"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sns:Publish",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# EventBridge rule to trigger Lambda on WAF changes
resource "aws_cloudwatch_event_rule" "waf_changes" {
  name        = "WAF-Modification-Events"
  description = "Capture WAF modification events"

  event_pattern = jsonencode({
    source      = ["aws.wafv2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = [
        "CreateWebACL",
        "UpdateWebACL",
        "DeleteWebACL",
        "PutLoggingConfiguration",
        "DeleteLoggingConfiguration"
      ]
      requestParameters = {
        name = [var.web_acl_name]
      }
    }
  })
}

# EventBridge target
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.waf_changes.name
  target_id = "WAFAlertLambda"
  arn       = aws_lambda_function.waf_alert_parser.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_alert_parser.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.waf_changes.arn
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
from datetime import datetime

sns = boto3.client('sns')

def handler(event, context):
    try:
        detail = event['detail']
        
        # Extract key information
        event_name = detail.get('eventName', 'Unknown')
        event_time = detail.get('eventTime', 'Unknown')
        user_identity = detail.get('userIdentity', {})
        source_ip = detail.get('sourceIPAddress', 'Unknown')
        user_agent = detail.get('userAgent', 'Unknown')
        request_params = detail.get('requestParameters', {})
        
        # Determine who made the change
        principal_type = user_identity.get('type', 'Unknown')
        if principal_type == 'IAMUser':
            actor = f"IAM User: {user_identity.get('userName', 'Unknown')}"
        elif principal_type == 'AssumedRole':
            actor = f"Role: {user_identity.get('sessionContext', {}).get('sessionIssuer', {}).get('userName', 'Unknown')}"
        elif principal_type == 'Root':
            actor = "Root Account"
        else:
            actor = f"{principal_type}: {user_identity.get('principalId', 'Unknown')}"
        
        # Format the message
        message = f"""
🚨 WAF MODIFICATION ALERT 🚨

ACTION: {event_name}
TIME: {event_time}
WHO: {actor}
SOURCE IP: {source_ip}
USER AGENT: {user_agent}

DETAILS:
{json.dumps(request_params, indent=2)}

AWS ACCOUNT: {detail.get('recipientAccountId', 'Unknown')}
REGION: {detail.get('awsRegion', 'Unknown')}
EVENT ID: {detail.get('eventID', 'Unknown')}

---
This is an automated alert from your WAF monitoring system.
        """
        
        # Send to SNS
        response = sns.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Subject=f'🚨 WAF Alert: {event_name} by {actor}',
            Message=message
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('Alert sent successfully')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
EOF
    filename = "index.py"
  }
}
