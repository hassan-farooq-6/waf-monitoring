# GitHub Actions OIDC Pipeline Setup

## Step 1: Setup AWS OIDC Provider (One-time setup)

Run these commands locally:

```bash
terraform init
terraform apply -target=aws_iam_openid_connect_provider.github -target=aws_iam_role.github_actions -target=aws_iam_role_policy_attachment.github_actions_admin
```

This creates:
- OIDC provider for GitHub
- IAM role that GitHub Actions will assume
- Necessary permissions

## Step 2: Get the Role ARN

After apply completes, copy the output:
```bash
terraform output github_role_arn
```

## Step 3: Add Secret to GitHub

1. Go to: https://github.com/hassan-farooq-6/waf-monitoring/settings/secrets/actions
2. Click "New repository secret"
3. Name: `AWS_ROLE_ARN`
4. Value: Paste the role ARN from Step 2
5. Click "Add secret"

## Step 4: Push to GitHub

```bash
git add .
git commit -m "Add GitHub Actions OIDC pipeline"
git push
```

## How It Works

- **On Push to main**: Runs terraform plan and apply automatically
- **On Pull Request**: Runs terraform plan only (no apply)
- **No AWS credentials needed**: Uses OIDC to authenticate securely

## Pipeline Triggers

- Automatically runs when you push to `main` branch
- Runs validation on pull requests
- No manual intervention needed after setup
