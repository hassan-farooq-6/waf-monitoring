variable "aws_region" {
  description = "The AWS region to deploy resources in (e.g., us-east-1)"
  type        = string
  default     = "us-east-1" 
}

variable "alert_email" {
  description = "The email address that will receive SNS notifications"
  type        = string
  default     = "hassan.bin.farooq@genclouds.com" 
}

variable "web_acl_name" {
  description = "The exact name of the Web ACL to monitor"
  type        = string
  default     = "MyWebACL-TF" 
}

variable "trail_name" {
  description = "Name of the CloudTrail"
  type        = string
  default     = "web-acl-monitoring-trail-TF"
}