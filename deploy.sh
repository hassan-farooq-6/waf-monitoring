#!/bin/bash

# One-Click Deploy Script for WAF Monitoring

set -e

echo "🚀 Starting WAF Monitoring Deployment..."
echo ""

# Check if AWS profile is set
if [ -z "$AWS_PROFILE" ]; then
    echo "⚠️  AWS_PROFILE not set. Using default profile."
    echo "   To use a specific profile, run: export AWS_PROFILE=your-profile-name"
    echo ""
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Deploy infrastructure
echo ""
echo "🏗️  Deploying infrastructure..."
terraform apply -auto-approve

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "📧 IMPORTANT: Check your email (${alert_email:-your email}) and confirm the SNS subscription!"
echo ""
echo "🎯 Next Steps:"
echo "   1. Confirm SNS subscription via email"
echo "   2. Test by modifying WAF in AWS Console"
echo "   3. Check your email for detailed alert"
echo ""
echo "💰 Estimated Cost: ~\$5.28/month"
echo ""
