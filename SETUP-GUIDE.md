# Complete Setup Guide (Step-by-Step for Beginners)

## Part 1: Setup AWS OIDC Provider

### Step 1: Run Terraform Commands
Open your terminal and run:

```bash
cd /home/hassan/Desktop/waf-monitoring
terraform init
terraform apply -target=aws_iam_openid_connect_provider.github -target=aws_iam_role.github_actions -target=aws_iam_role_policy_attachment.github_actions_admin
```

### Step 2: Confirm the Apply
- Terraform will show you what it will create
- Type `yes` and press Enter
- Wait for it to complete (takes 10-30 seconds)

### Step 3: Get Your Role ARN
After the apply completes, run:
```bash
terraform output github_role_arn
```

You'll see something like:
```
"arn:aws:iam::123456789012:role/GitHubActionsOIDCRole"
```

**COPY THIS ENTIRE LINE** (including the quotes or without - both work)

---

## Part 2: Add Secret to GitHub

### Step 1: Go to GitHub Secrets Page
Open this link in your browser:
```
https://github.com/hassan-farooq-6/waf-monitoring/settings/secrets/actions
```

**If you see "404 Not Found":**
- Go to: https://github.com/hassan-farooq-6/waf-monitoring
- Click "Settings" tab (top right)
- Click "Secrets and variables" in left sidebar
- Click "Actions"

### Step 2: Create New Secret
1. Click the green button "New repository secret"
2. In "Name" field, type exactly: `AWS_ROLE_ARN`
3. In "Secret" field, paste the ARN you copied (the arn:aws:iam::... thing)
4. Click "Add secret" button

---

## Part 3: Push to GitHub

```bash
cd /home/hassan/Desktop/waf-monitoring
git add .
git commit -m "Fix OIDC setup"
git push
```

---

## Part 4: Verify Pipeline is Running

### Step 1: Go to Actions Tab
Open: https://github.com/hassan-farooq-6/waf-monitoring/actions

### Step 2: Check the Workflow
- You should see a workflow running (yellow dot = running, green check = success)
- Click on it to see details
- If it's green ✓ = SUCCESS! Your pipeline is working!
- If it's red ✗ = Failed, click on it to see error details

---

## What Each Thing Means:

- **ARN**: Amazon Resource Name - a unique ID for AWS resources
- **OIDC**: OpenID Connect - secure way to authenticate without passwords
- **Role**: Permission set that GitHub Actions will use
- **Secret**: Hidden value stored in GitHub (not visible in code)

---

## Troubleshooting:

**Q: I don't see the Settings tab on GitHub**
A: You might not be the owner. Make sure you're logged in as hassan-farooq-6

**Q: terraform output shows nothing**
A: Run the terraform apply command again from Step 1

**Q: Pipeline fails with "AccessDenied"**
A: Double-check the AWS_ROLE_ARN secret is correct
