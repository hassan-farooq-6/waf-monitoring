#!/bin/bash

# One-Click Cleanup Script for WAF Monitoring

set -e

echo "🗑️  Starting WAF Monitoring Cleanup..."
echo ""

# Check if AWS profile is set
if [ -z "$AWS_PROFILE" ]; then
    echo "⚠️  AWS_PROFILE not set. Using default profile."
    echo "   To use a specific profile, run: export AWS_PROFILE=your-profile-name"
    echo ""
fi

# Destroy infrastructure
echo "💥 Destroying all infrastructure..."
terraform destroy -auto-approve

echo ""
echo "✅ Cleanup Complete!"
echo ""
echo "All AWS resources have been deleted."
echo "💰 No more charges will be incurred."
echo ""
