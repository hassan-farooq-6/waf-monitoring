# GitHub Actions OIDC Pipeline - Complete Context & Guide

## 📋 What We Built

A fully automated CI/CD pipeline using GitHub Actions with OIDC authentication that deploys Terraform infrastructure to AWS without storing any credentials.

---

## 🎯 The Problem & Solution

### Problem:
- Manual `terraform apply` every time you make changes
- Storing AWS credentials in GitHub is insecure
- No automation for infrastructure deployment

### Solution:
- **OIDC Authentication**: GitHub authenticates to AWS without credentials
- **Automated Deployment**: Push code → Auto-deploy to AWS
- **Remote State**: S3 backend for shared state between local and GitHub Actions
- **GitOps Workflow**: Infrastructure changes through Git commits

---

## 🏗️ Architecture Components

### 1. **OIDC Provider** (`github-oidc-setup.tf`)
```hcl
# Creates AWS IAM OIDC provider that trusts GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role that GitHub Actions assumes
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
          "token.actions.githubusercontent.com:sub" = "repo:YOUR_USERNAME/YOUR_REPO:*"
        }
      }
    }]
  })
}

# Attach permissions (adjust as needed)
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_role_arn" {
  value = aws_iam_role.github_actions.arn
}
```

### 2. **S3 Backend** (`backend-setup.tf`)
```hcl
# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket_prefix = "terraform-state-YOUR_PROJECT-"
  force_destroy = false
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}
```

### 3. **Provider Configuration** (`provider.tf`)
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "YOUR_BUCKET_NAME"  # From backend-setup output
    key            = "YOUR_PROJECT/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
```

### 4. **GitHub Actions Workflow** (`.github/workflows/terraform.yml`)
```yaml
name: Terraform Deploy

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check
        continue-on-error: true

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -no-color
        continue-on-error: true

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve
```

### 5. **Git Ignore** (`.gitignore`)
```
# Terraform files
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
.terraform.lock.hcl

# Crash logs
crash.log
crash.*.log

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI configuration
.terraformrc
terraform.rc

# OS files
.DS_Store
Thumbs.db
```

---

## 🚀 Setup Steps (Copy-Paste for New Projects)

### Step 1: Create OIDC Provider & Backend
```bash
# Initialize Terraform
terraform init

# Create OIDC and backend resources
terraform apply -target=aws_iam_openid_connect_provider.github \
                -target=aws_iam_role.github_actions \
                -target=aws_iam_role_policy_attachment.github_actions_admin \
                -target=aws_s3_bucket.terraform_state \
                -target=aws_s3_bucket_versioning.terraform_state \
                -target=aws_dynamodb_table.terraform_locks

# Get the Role ARN and Bucket Name
terraform output github_role_arn
terraform output s3_bucket_name
```

### Step 2: Update Backend Configuration
Update `provider.tf` with the S3 bucket name from output:
```hcl
backend "s3" {
  bucket = "YOUR_BUCKET_NAME_FROM_OUTPUT"
  # ... rest of config
}
```

### Step 3: Migrate State to S3
```bash
terraform init -migrate-state -force-copy
```

### Step 4: Add GitHub Secret
1. Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `AWS_ROLE_ARN`
4. Value: Paste the ARN from Step 1
5. Click "Add secret"

### Step 5: Create GitHub Token (if needed)
1. Go to: `https://github.com/settings/tokens`
2. Generate new token (classic)
3. Check: `repo` and `workflow` scopes
4. Copy token

### Step 6: Update Git Remote (if using token)
```bash
git remote set-url origin https://YOUR_TOKEN@github.com/YOUR_USERNAME/YOUR_REPO.git
```

### Step 7: Push and Deploy
```bash
git add .
git commit -m "Add OIDC pipeline"
git push
```

---

## 🔄 How It Works

```
Developer pushes code to GitHub
         ↓
GitHub Actions workflow triggers
         ↓
Workflow requests temporary credentials from AWS
         ↓
AWS validates GitHub's OIDC token
         ↓
AWS issues temporary credentials (valid ~1 hour)
         ↓
GitHub Actions assumes IAM role
         ↓
Downloads Terraform state from S3
         ↓
Acquires state lock in DynamoDB
         ↓
Runs terraform plan & apply
         ↓
Updates state in S3
         ↓
Releases state lock
         ↓
Deployment complete! ✅
```

---

## 🔐 Security Benefits

| Feature | Benefit |
|---------|---------|
| **OIDC Authentication** | No long-lived credentials stored |
| **Temporary Credentials** | Auto-expire after ~1 hour |
| **Repository Scoping** | Only specific repo can assume role |
| **State Encryption** | S3 encrypts state at rest |
| **State Locking** | Prevents concurrent modifications |
| **State Versioning** | Rollback capability |
| **Audit Trail** | CloudTrail logs all actions |

---

## 📝 Customization for New Projects

### 1. Update Repository Reference
In `github-oidc-setup.tf`, change:
```hcl
"token.actions.githubusercontent.com:sub" = "repo:YOUR_USERNAME/YOUR_REPO:*"
```

### 2. Update Bucket Prefix
In `backend-setup.tf`, change:
```hcl
bucket_prefix = "terraform-state-YOUR_PROJECT-"
```

### 3. Update Backend Key
In `provider.tf`, change:
```hcl
key = "YOUR_PROJECT/terraform.tfstate"
```

### 4. Adjust IAM Permissions
Replace `AdministratorAccess` with least-privilege policy:
```hcl
resource "aws_iam_role_policy" "github_actions_policy" {
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:*",
        "s3:*",
        # Add only what you need
      ]
      Resource = "*"
    }]
  })
}
```

---

## 🐛 Common Issues & Fixes

### Issue: "Resource Already Exists"
**Solution:** Import existing resources
```bash
terraform import RESOURCE_TYPE.NAME RESOURCE_ID
```

### Issue: "AccessDenied" in Pipeline
**Solution:** Verify AWS_ROLE_ARN secret is correct

### Issue: State Lock Error
**Solution:** Force unlock
```bash
terraform force-unlock LOCK_ID
```

### Issue: "refusing to allow PAT without workflow scope"
**Solution:** Create new GitHub token with `workflow` scope

---

## 📚 Key Concepts

### OIDC (OpenID Connect)
- Industry-standard protocol for authentication
- GitHub generates short-lived tokens
- AWS validates tokens and issues temporary credentials
- No secrets stored anywhere

### Terraform State
- JSON file tracking deployed resources
- Must be shared between local and CI/CD
- S3 provides centralized storage
- DynamoDB prevents concurrent modifications

### GitOps
- Infrastructure changes through Git commits
- Git as single source of truth
- Automated deployment on push
- Full audit trail in Git history

---

## 🎯 Use This Template For:

✅ Any Terraform + AWS + GitHub project  
✅ Multi-environment deployments (dev/staging/prod)  
✅ Team collaboration (shared state)  
✅ Compliance requirements (no credentials)  
✅ Production workloads (secure & automated)  

---

## 📋 Checklist for New Projects

- [ ] Copy all 5 files (github-oidc-setup.tf, backend-setup.tf, provider.tf, .github/workflows/terraform.yml, .gitignore)
- [ ] Update repository name in github-oidc-setup.tf
- [ ] Update bucket prefix in backend-setup.tf
- [ ] Run terraform apply for OIDC and backend
- [ ] Update provider.tf with bucket name
- [ ] Run terraform init -migrate-state
- [ ] Add AWS_ROLE_ARN to GitHub secrets
- [ ] Create GitHub token with workflow scope (if needed)
- [ ] Push code and verify pipeline runs
- [ ] Confirm green checkmark in Actions tab

---

## 🔗 Resources

- [AWS OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub OIDC Guide](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [GitHub Actions AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)

---

**Copy this entire context to use in your next project!** 🚀
