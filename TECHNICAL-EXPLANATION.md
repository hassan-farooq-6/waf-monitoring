# Technical Explanation: AWS WAF Monitoring with OIDC CI/CD Pipeline

## Executive Summary

This project implements a production-grade AWS WAF monitoring infrastructure with automated deployment using GitHub Actions and OpenID Connect (OIDC) authentication. The system eliminates the need for storing long-lived AWS credentials while providing real-time security monitoring and alerting.

---

## System Architecture Overview

### High-Level Flow
```
Code Push → GitHub Actions → OIDC Auth → AWS STS → Terraform Deployment → Infrastructure Update
```

---

## 1. Infrastructure Components (AWS)

### 1.1 WAF Web ACL (`main.tf`)
**Purpose:** Web Application Firewall for protecting applications

**Technical Details:**
- Resource Type: `aws_wafv2_web_acl`
- Scope: REGIONAL (can be CLOUDFRONT for CDN)
- Default Action: ALLOW (blocks based on rules)
- CloudWatch Metrics: Enabled for monitoring

**Code:**
```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "MyWebACL-TF"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MyWebACL-TF"
    sampled_requests_enabled   = true
  }
}
```

### 1.2 CloudTrail (`main.tf`)
**Purpose:** Audit logging for all WAF API calls

**Technical Details:**
- Logs all WAF events (CreateWebACL, UpdateWebACL, DeleteWebACL)
- Multi-region trail for comprehensive coverage
- Integrates with both S3 (long-term storage) and CloudWatch (real-time analysis)

**Key Features:**
- S3 bucket with bucket policy allowing CloudTrail write access
- CloudWatch Logs integration via IAM role
- Global service events included

### 1.3 CloudWatch Monitoring Stack (`monitoring.tf`)

#### a) Log Group
- Receives CloudTrail logs in real-time
- 30-day retention policy (cost optimization)

#### b) Metric Filter (The Brain)
**Purpose:** Pattern matching on CloudTrail logs

**Filter Pattern:**
```json
{
  ($.eventSource = wafv2.amazonaws.com) && 
  (($.eventName = UpdateWebACL) || 
   ($.eventName = CreateWebACL) || 
   ($.eventName = DeleteWebACL)) && 
  ($.requestParameters.name = "MyWebACL-TF")
}
```

**How It Works:**
1. Scans every log entry in real-time
2. Matches specific WAF modification events
3. Increments metric value by 1 when matched
4. Publishes to custom namespace `WAF/Monitoring`

#### c) CloudWatch Alarm
**Trigger Conditions:**
- Metric: `WebACLModifications`
- Threshold: ≥ 1 modification
- Period: 5 minutes
- Statistic: Sum
- Action: Publish to SNS topic

#### d) SNS Topic & Email Subscription
- Topic receives alarm notifications
- Email subscription sends alerts to configured address
- Requires manual confirmation (security measure)

---

## 2. CI/CD Pipeline (GitHub Actions + OIDC)

### 2.1 OIDC Authentication Flow

**Traditional Method (Insecure):**
```
AWS Access Key + Secret Key stored in GitHub Secrets
❌ Long-lived credentials
❌ Security risk if leaked
❌ Manual rotation required
```

**OIDC Method (Secure):**
```
GitHub generates JWT token → AWS validates token → Issues temporary credentials
✅ No stored credentials
✅ Auto-expiring tokens (~1 hour)
✅ Cryptographically secure
```

### 2.2 OIDC Setup (`github-oidc-setup.tf`)

#### Step 1: Create OIDC Provider in AWS
```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

**Technical Details:**
- `url`: GitHub's OIDC token endpoint
- `client_id_list`: AWS STS service identifier
- `thumbprint_list`: GitHub's SSL certificate fingerprint (for validation)

#### Step 2: Create IAM Role with Trust Policy
```hcl
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsOIDCRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:hassan-farooq-6/waf-monitoring:*"
        }
      }
    }]
  })
}
```

**Security Mechanisms:**
1. **Federated Principal**: Only GitHub OIDC provider can assume this role
2. **Audience Check**: Token must be intended for AWS STS
3. **Subject Check**: Only specific repository can use this role
4. **Action**: `AssumeRoleWithWebIdentity` (OIDC-specific)

### 2.3 GitHub Actions Workflow (`.github/workflows/terraform.yml`)

#### Workflow Triggers
```yaml
on:
  push:
    branches: [main]      # Auto-deploy on main branch
  pull_request:
    branches: [main]      # Plan-only on PRs
```

#### Critical Permissions
```yaml
permissions:
  id-token: write   # Required to request OIDC token from GitHub
  contents: read    # Read repository contents
```

#### Authentication Step
```yaml
- name: Configure AWS credentials using OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

**What Happens Behind the Scenes:**
1. GitHub generates JWT token with claims:
   - `aud`: sts.amazonaws.com
   - `sub`: repo:hassan-farooq-6/waf-monitoring:ref:refs/heads/main
   - `iss`: https://token.actions.githubusercontent.com
2. Action calls AWS STS `AssumeRoleWithWebIdentity` API
3. AWS validates token signature and claims
4. AWS issues temporary credentials (AccessKeyId, SecretAccessKey, SessionToken)
5. Credentials exported as environment variables
6. Valid for ~1 hour

#### Deployment Steps
```yaml
1. Checkout code          # Clone repository
2. Authenticate via OIDC  # Get temporary AWS credentials
3. Setup Terraform        # Install Terraform CLI
4. terraform init         # Download providers, configure backend
5. terraform fmt -check   # Code formatting validation
6. terraform validate     # Syntax validation
7. terraform plan         # Preview changes
8. terraform apply        # Deploy (only on main branch push)
```

---

## 3. State Management (S3 Backend)

### 3.1 The State Problem

**Without Remote Backend:**
- State file stored locally
- GitHub Actions can't access local state
- Results in "resource already exists" errors
- No collaboration possible

**With S3 Backend:**
- State stored in S3 bucket
- Both local and GitHub Actions access same state
- DynamoDB provides state locking
- Team collaboration enabled

### 3.2 Backend Configuration (`backend-setup.tf`)

#### S3 Bucket
```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket_prefix = "terraform-state-waf-"
  force_destroy = false  # Prevent accidental deletion
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"  # Rollback capability
  }
}
```

**Features:**
- Versioning: Every state change creates new version
- Encryption: Server-side encryption at rest (default)
- Unique naming: `bucket_prefix` adds random suffix

#### DynamoDB Table (State Locking)
```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

**How Locking Works:**
1. Before `terraform apply`, Terraform writes lock entry to DynamoDB
2. Lock contains: state file path, timestamp, operator info
3. Other operations check for lock before proceeding
4. If locked, operation waits or fails
5. After completion, lock is released

### 3.3 Backend Configuration (`provider.tf`)
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-waf-20260209154729646200000001"
    key            = "waf-monitoring/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

**State Migration:**
```bash
terraform init -migrate-state -force-copy
```
- Copies local state to S3
- Configures backend
- Future operations use S3

---

## 4. Security Architecture

### 4.1 Defense in Depth

| Layer | Mechanism | Benefit |
|-------|-----------|---------|
| **Authentication** | OIDC with JWT tokens | No long-lived credentials |
| **Authorization** | IAM role with trust policy | Repository-scoped access |
| **Encryption** | S3 server-side encryption | State data protected at rest |
| **Locking** | DynamoDB state locks | Prevents concurrent modifications |
| **Versioning** | S3 versioning | Rollback capability |
| **Audit** | CloudTrail logging | Complete audit trail |
| **Least Privilege** | Scoped IAM policies | Minimal permissions |

### 4.2 OIDC Security Deep Dive

**JWT Token Structure:**
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT"
  },
  "payload": {
    "iss": "https://token.actions.githubusercontent.com",
    "sub": "repo:hassan-farooq-6/waf-monitoring:ref:refs/heads/main",
    "aud": "sts.amazonaws.com",
    "exp": 1707489600,
    "iat": 1707486000
  },
  "signature": "..."
}
```

**AWS Validation Process:**
1. Verify signature using GitHub's public key
2. Check `iss` matches OIDC provider URL
3. Check `aud` matches expected audience
4. Check `sub` matches trust policy condition
5. Check token not expired (`exp` claim)
6. Issue temporary credentials if all checks pass

---

## 5. Monitoring & Alerting Flow

### Real-Time Event Processing

```
WAF Modification Event
    ↓
CloudTrail captures API call
    ↓
Log sent to CloudWatch Logs (< 1 second)
    ↓
Metric Filter evaluates log entry
    ↓
Match found → Metric value incremented
    ↓
CloudWatch Alarm evaluates metric
    ↓
Threshold breached → Alarm state changes to ALARM
    ↓
SNS topic receives notification
    ↓
Email sent to subscriber
    ↓
Security team notified (< 5 minutes total)
```

### Example CloudTrail Event
```json
{
  "eventVersion": "1.08",
  "eventTime": "2024-02-09T15:30:00Z",
  "eventSource": "wafv2.amazonaws.com",
  "eventName": "UpdateWebACL",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "203.0.113.0",
  "userAgent": "aws-cli/2.0",
  "requestParameters": {
    "name": "MyWebACL-TF",
    "scope": "REGIONAL",
    "id": "abc123..."
  },
  "responseElements": {...},
  "requestID": "xyz789...",
  "eventID": "unique-id",
  "eventType": "AwsApiCall"
}
```

---

## 6. Deployment Workflow

### Initial Setup (One-Time)
```bash
# 1. Create OIDC provider and backend
terraform apply -target=aws_iam_openid_connect_provider.github \
                -target=aws_iam_role.github_actions \
                -target=aws_s3_bucket.terraform_state \
                -target=aws_dynamodb_table.terraform_locks

# 2. Get outputs
terraform output github_role_arn
terraform output s3_bucket_name

# 3. Update provider.tf with bucket name
# 4. Migrate state
terraform init -migrate-state

# 5. Add AWS_ROLE_ARN to GitHub Secrets
# 6. Push code
```

### Continuous Deployment (Automated)
```bash
# Developer workflow
git add .
git commit -m "Update WAF rules"
git push origin main

# GitHub Actions automatically:
# 1. Authenticates via OIDC
# 2. Downloads state from S3
# 3. Acquires lock in DynamoDB
# 4. Runs terraform plan
# 5. Runs terraform apply
# 6. Updates state in S3
# 7. Releases lock
# 8. Infrastructure updated
```

---

## 7. Technical Advantages

### Compared to Manual Deployment
| Aspect | Manual | Automated (This Project) |
|--------|--------|--------------------------|
| **Deployment Time** | 5-10 minutes | 30-60 seconds |
| **Human Error** | High risk | Eliminated |
| **Credential Management** | Manual rotation | No credentials |
| **Audit Trail** | Limited | Complete (Git + CloudTrail) |
| **Rollback** | Manual | Git revert + redeploy |
| **Collaboration** | Difficult | Git-based workflow |
| **Consistency** | Variable | Guaranteed |

### Compared to Stored Credentials
| Aspect | Stored Credentials | OIDC |
|--------|-------------------|------|
| **Security** | High risk if leaked | Cryptographically secure |
| **Lifespan** | Permanent | ~1 hour |
| **Rotation** | Manual | Automatic |
| **Scope** | Broad | Repository-specific |
| **Revocation** | Manual | Automatic on expiry |

---

## 8. Key Technologies Explained

### Terraform
- **Infrastructure as Code (IaC)** tool
- Declarative syntax (describe desired state)
- Provider-based architecture (AWS, Azure, GCP, etc.)
- State management for tracking resources
- Plan before apply (preview changes)

### GitHub Actions
- **CI/CD platform** integrated with GitHub
- Event-driven workflows (push, PR, schedule, etc.)
- Matrix builds, parallel jobs, reusable workflows
- Marketplace with 10,000+ actions
- Built-in secrets management

### OIDC (OpenID Connect)
- **Authentication protocol** built on OAuth 2.0
- Uses JWT (JSON Web Tokens) for identity
- Eliminates need for passwords/keys
- Industry standard (Google, Microsoft, GitHub use it)
- Cryptographic signature verification

### AWS Services
- **IAM**: Identity and Access Management
- **STS**: Security Token Service (issues temporary credentials)
- **CloudTrail**: API audit logging
- **CloudWatch**: Monitoring and alerting
- **SNS**: Notification service
- **S3**: Object storage
- **DynamoDB**: NoSQL database (used for locking)

---

## 9. Potential Interview Questions & Answers

**Q: Why use OIDC instead of storing AWS keys?**
A: OIDC provides temporary, auto-expiring credentials that are cryptographically verified. Stored keys are permanent, can be leaked, and require manual rotation. OIDC eliminates the attack surface of long-lived credentials.

**Q: How does Terraform know what's already deployed?**
A: Terraform maintains a state file that maps configuration to real resources. The state is stored in S3 so both local and CI/CD can access it. DynamoDB provides locking to prevent concurrent modifications.

**Q: What happens if two people push code simultaneously?**
A: DynamoDB state locking prevents this. The first deployment acquires the lock, the second waits or fails. This prevents state corruption and conflicting changes.

**Q: How quickly are WAF changes detected?**
A: CloudTrail logs appear in CloudWatch within seconds. The metric filter processes them immediately. The alarm evaluates every 5 minutes. Total time: < 5 minutes from event to email.

**Q: Can this be extended to other AWS services?**
A: Yes. The same OIDC pipeline works for any Terraform-managed infrastructure. Just add resources to the .tf files and push. The monitoring can be extended by adding more metric filters and alarms.

**Q: What's the cost of this infrastructure?**
A: Minimal. CloudTrail: ~$2/month, CloudWatch Logs: ~$0.50/month, S3: ~$0.10/month, DynamoDB: ~$0.25/month, SNS: ~$0.01/month. Total: ~$3/month.

---

## 10. Conclusion

This project demonstrates enterprise-grade DevOps practices:
- **Security**: OIDC authentication, no stored credentials
- **Automation**: GitOps workflow, zero manual deployment
- **Reliability**: State locking, versioning, rollback capability
- **Monitoring**: Real-time alerting, comprehensive logging
- **Scalability**: Easily extended to more resources
- **Collaboration**: Git-based workflow, shared state

The architecture follows AWS Well-Architected Framework principles and industry best practices for secure, automated infrastructure deployment.

---

**Project Repository:** https://github.com/hassan-farooq-6/waf-monitoring
