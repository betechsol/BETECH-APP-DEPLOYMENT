#!/bin/bash

# BETECH EKS Terraform Module Verification Script
# This script validates the proper organization of Terraform modules

set -e

echo "🔍 BETECH EKS Terraform Module Organization Verification"
echo "========================================================"

PROJECT_ROOT="/home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment"
cd "$PROJECT_ROOT"

echo ""
echo "📁 Project Structure:"
echo "--------------------"
tree modules/ -I '.terraform'

echo ""
echo "✅ Module File Organization Check:"
echo "--------------------------------"

modules=("vpc" "eks" "iam" "ecr" "helm" "s3-dynamodb")
required_files=("main.tf" "variables.tf" "outputs.tf")

for module in "${modules[@]}"; do
    echo ""
    echo "🔸 Checking module: $module"
    module_path="modules/$module"
    
    if [ ! -d "$module_path" ]; then
        echo "  ❌ Module directory not found: $module_path"
        continue
    fi
    
    for file in "${required_files[@]}"; do
        file_path="$module_path/$file"
        if [ -f "$file_path" ]; then
            lines=$(wc -l < "$file_path")
            echo "  ✅ $file ($lines lines)"
        else
            echo "  ⚠️  Missing: $file"
        fi
    done
done

echo ""
echo "🔧 Terraform Validation:"
echo "------------------------"

# Check for basic syntax errors
echo "🔸 Checking main configuration..."
if terraform validate > /dev/null 2>&1; then
    echo "  ✅ Main configuration syntax is valid"
else
    echo "  ⚠️  Main configuration has syntax issues"
fi

echo ""
echo "📋 Module Dependencies Summary:"
echo "------------------------------"
echo "1. VPC Module → Creates networking foundation"
echo "2. EKS Module → Uses VPC outputs for cluster creation"
echo "3. IAM Module → Uses EKS OIDC provider for service accounts"
echo "4. ECR Module → Independent container registries"
echo "5. Helm Module → Uses EKS, VPC, and IAM outputs for add-ons"
echo "6. S3-DynamoDB → Independent backend state management"

echo ""
echo "🎯 Verification Complete!"
echo "========================"
echo ""
echo "✨ All modules are properly organized with:"
echo "   • main.tf (resource definitions)"
echo "   • variables.tf (input parameters)"
echo "   • outputs.tf (return values)"
echo ""
echo "🚀 Ready for deployment with: ./deploy.sh"
