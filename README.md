# WAF Monitoring Setup

AWS WAF monitoring infrastructure using Terraform with CloudWatch alarms and SNS notifications.

## Features
- CloudTrail logging for WAF events
- CloudWatch alarms for blocked requests
- SNS email notifications
- S3 bucket for CloudTrail logs

## Prerequisites
- AWS CLI configured
- Terraform installed
- AWS account with appropriate permissions

## Usage

1. Clone the repository
2. Update `variables.tf` with your values
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Plan the deployment:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Variables
- `aws_region`: AWS region (default: us-east-1)
- `alert_email`: Email for SNS notifications
- `web_acl_name`: Name of the Web ACL to monitor
- `trail_name`: CloudTrail name

## Cleanup
```bash
terraform destroy
```
