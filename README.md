# AWS WAF Monitoring Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-ready AWS WAF monitoring solution with automated deployment via GitHub Actions using OIDC authentication. This infrastructure provides real-time alerts for WAF modifications and comprehensive CloudTrail logging.

## 🚀 Features

- **🔒 Secure OIDC Authentication** - GitHub Actions deploys without storing AWS credentials
- **📊 Real-time Monitoring** - Instant alerts on WAF modifications (< 5 seconds)
- **📧 Detailed Email Notifications** - Know WHO changed WHAT, WHEN, and from WHERE
- **👤 User Tracking** - Identifies IAM users, roles, or root account
- **📝 Comprehensive Logging** - CloudTrail logs all WAF events to S3
- **🔄 Automated Deployment** - GitOps workflow with Terraform
- **🔐 State Management** - Remote state in S3 with DynamoDB locking
- **⚡ One-Click Deploy/Destroy** - Simple scripts for easy management
- **📈 Scalable Architecture** - Production-ready infrastructure

## 📋 Architecture

```
┌─────────────────┐
│   GitHub Push   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GitHub Actions  │◄──── OIDC Auth (No Credentials!)
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│              AWS Infrastructure             │
│                                             │
│  ┌──────────┐    ┌──────────────┐           │
│  │   WAF    │───▶│  CloudTrail  │           │
│  └──────────┘    └──────┬───────┘           │
│                         │                   │
│                         ▼                   │
│              ┌──────────────────┐           │
│              │  CloudWatch Logs │           │
│              └────────┬─────────┘           │
│                       │                     │
│                       ▼                     │
│              ┌──────────────────┐           │
│              │  Metric Filter   │           │
│              └────────┬─────────┘           │
│                       │                     │
│                       ▼                     │
│              ┌──────────────────┐           │
│              │ CloudWatch Alarm │           │
│              └────────┬─────────┘           │
│                       │                     │
│                       ▼                     │
│              ┌──────────────────┐           │
│              │    SNS Topic     │───▶ 📧    │ 
│              └──────────────────┘           │
└─────────────────────────────────────────────┘
```

## 🛠️ Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** configured with credentials
- **Terraform** >= 1.6.0
- **Git** installed
- **GitHub Account** with repository access

## 📦 Infrastructure Components

| Component | Purpose | File |
|-----------|---------|------|
| **WAF Web ACL** | Firewall protection | `main.tf` |
| **CloudTrail** | Event logging | `main.tf` |
| **S3 Bucket** | Log storage | `main.tf` |
| **CloudWatch Log Group** | Centralized logging | `monitoring.tf` |
| **Metric Filter** | Pattern matching for events | `monitoring.tf` |
| **CloudWatch Alarm** | Alert triggering | `monitoring.tf` |
| **SNS Topic** | Notification delivery | `monitoring.tf` |
| **OIDC Provider** | GitHub authentication | `github-oidc-setup.tf` |
| **S3 Backend** | Terraform state storage | `backend-setup.tf` |

## 🚀 Quick Start

### Method 1: One-Click Scripts (Easiest)

```bash
# Set your AWS profile
export AWS_PROFILE=hassan-account

# Deploy everything
./deploy.sh

# When done, cleanup everything
./cleanup.sh
```

### Method 2: Manual Terraform

#### Deploy:
```bash
export AWS_PROFILE=hassan-account
terraform init
terraform apply
```

#### Destroy:
```bash
export AWS_PROFILE=hassan-account
terraform destroy
```

That's it! ✅

## 🔄 GitHub Actions Workflow

The pipeline automatically runs on every push to `main`:

```yaml
Trigger: Push to main branch
  ↓
Checkout Code
  ↓
Authenticate via OIDC (No credentials!)
  ↓
Terraform Init
  ↓
Terraform Validate
  ↓
Terraform Plan
  ↓
Terraform Apply (Auto-approved)
  ↓
Infrastructure Updated ✅
```

## 📊 Monitoring & Alerts

### What Gets Monitored

- **WAF Web ACL Creation**
- **WAF Web ACL Updates**
- **WAF Web ACL Deletion**
- **WAF Logging Configuration Changes**

### Alert Details (Real-time)

You'll receive an email within **5 seconds** containing:

```
🚨 WAF MODIFICATION ALERT 🚨

ACTION: UpdateWebACL
TIME: 2026-02-11T12:30:45Z
WHO: IAM User: john.doe
SOURCE IP: 203.0.113.42
USER AGENT: aws-cli/2.0

DETAILS:
{
  "name": "MyWebACL-TF",
  "scope": "REGIONAL",
  "rules": [...]
}

AWS ACCOUNT: 904619734491
REGION: us-east-1
EVENT ID: abc-123-xyz
```

### Email Notification Setup

After deployment:
1. Check your email inbox
2. Click the confirmation link from AWS
3. You'll now receive detailed alerts for all WAF changes

## 🔐 Security Best Practices

✅ **OIDC Authentication** - No long-lived credentials  
✅ **Encrypted State** - S3 encryption at rest  
✅ **State Locking** - DynamoDB prevents concurrent modifications  
✅ **Versioned State** - S3 versioning enabled for rollback  
✅ **IAM Least Privilege** - Scoped to specific repository  
✅ **CloudTrail Logging** - Complete audit trail  

## 📁 Project Structure

```
waf-monitoring/
├── .github/
│   └── workflows/
│       └── terraform.yml          # GitHub Actions pipeline
├── main.tf                        # Core infrastructure (WAF, CloudTrail, S3)
├── monitoring.tf                  # Monitoring resources (CloudWatch, SNS)
├── provider.tf                    # AWS provider & backend config
├── variables.tf                   # Input variables
├── github-oidc-setup.tf          # OIDC provider for GitHub
├── backend-setup.tf              # S3 backend resources
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## 🔧 Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `us-east-1` |
| `alert_email` | Email for SNS notifications | Required |
| `web_acl_name` | Name of the Web ACL | `MyWebACL-TF` |
| `trail_name` | CloudTrail name | `web-acl-monitoring-trail-TF` |

### Outputs

| Output | Description |
|--------|-------------|
| `github_role_arn` | IAM role ARN for GitHub Actions |
| `s3_bucket_name` | S3 bucket for Terraform state |

## 🧪 Testing

Test the pipeline by making a change:

```bash
# Make a change
echo "# Test change" >> README.md

# Commit and push
git add .
git commit -m "Test automated deployment"
git push

# Check pipeline status
# Visit: https://github.com/YOUR_USERNAME/waf-monitoring/actions
```

## 🐛 Troubleshooting

### Pipeline Fails with "AccessDenied"

**Solution:** Verify the `AWS_ROLE_ARN` secret is correct in GitHub

### "Resource Already Exists" Error

**Solution:** Import existing resources:
```bash
terraform import aws_wafv2_web_acl.main <web-acl-id>/MyWebACL-TF/REGIONAL
```

### SNS Email Not Received

**Solution:** Check spam folder and confirm subscription via email link

### State Lock Error

**Solution:** Release the lock:
```bash
terraform force-unlock <LOCK_ID>
```

## 🧹 Cleanup

### One-Click Cleanup:
```bash
export AWS_PROFILE=hassan-account
./cleanup.sh
```

### Manual Cleanup:
```bash
export AWS_PROFILE=hassan-account
terraform destroy
```

That's it! All resources deleted, no charges. ✅

## 📚 Additional Resources

- [AWS WAF Documentation](https://docs.aws.amazon.com/waf/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Hassan Farooq**
- GitHub: [@hassan-farooq-6](https://github.com/hassan-farooq-6)

## ⭐ Show Your Support

Give a ⭐️ if this project helped you!

---

**Built with ❤️ using Terraform and AWS**
