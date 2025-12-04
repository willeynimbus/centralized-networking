#!/bin/bash

# Deployment script for Hub Account infrastructure
# This script deploys the Hub Account CloudFormation stacks in the correct order

set -e

# Configuration
REGION="${AWS_REGION:-us-east-1}"
SPOKE_A_ACCOUNT_ID="${SPOKE_A_ACCOUNT_ID:-111111111111}"
SPOKE_B_ACCOUNT_ID="${SPOKE_B_ACCOUNT_ID:-222222222222}"
GITHUB_ORG="${GITHUB_ORG:-your-github-org}"
GITHUB_REPO="${GITHUB_REPO:-centralized-networking}"

echo "=========================================="
echo "Hub Account Infrastructure Deployment"
echo "=========================================="
echo "Region: $REGION"
echo "Spoke A Account: $SPOKE_A_ACCOUNT_ID"
echo "Spoke B Account: $SPOKE_B_ACCOUNT_ID"
echo ""

# Step 1: Deploy IAM Roles
echo "Step 1/3: Deploying IAM Roles..."
aws cloudformation deploy \
  --template-file cloudformation/hub/03-iam-roles.yaml \
  --stack-name hub-iam-roles \
  --parameter-overrides \
    SpokeAccountAId=$SPOKE_A_ACCOUNT_ID \
    SpokeAccountBId=$SPOKE_B_ACCOUNT_ID \
    GitHubOrg=$GITHUB_ORG \
    GitHubRepo=$GITHUB_REPO \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION \
  --no-fail-on-empty-changeset

echo "✅ IAM Roles deployed successfully"
echo ""

# Step 2: Deploy Hub VPC
echo "Step 2/3: Deploying Hub VPC..."
aws cloudformation deploy \
  --template-file cloudformation/hub/01-vpc.yaml \
  --stack-name hub-vpc \
  --parameter-overrides \
    EnvironmentName=Hub \
    VpcCIDR=10.0.0.0/16 \
    PublicSubnet1CIDR=10.0.1.0/24 \
    PublicSubnet2CIDR=10.0.2.0/24 \
    PrivateSubnet1CIDR=10.0.11.0/24 \
    PrivateSubnet2CIDR=10.0.12.0/24 \
  --region $REGION \
  --no-fail-on-empty-changeset

echo "✅ Hub VPC deployed successfully"
echo ""

# Step 3: Deploy Transit Gateway
echo "Step 3/3: Deploying Transit Gateway..."
aws cloudformation deploy \
  --template-file cloudformation/hub/02-transit-gateway.yaml \
  --stack-name hub-transit-gateway \
  --parameter-overrides \
    EnvironmentName=Hub \
    TransitGatewayDescription="Central Transit Gateway for multi-account networking" \
  --region $REGION \
  --no-fail-on-empty-changeset

echo "✅ Transit Gateway deployed successfully"
echo ""

# Get Transit Gateway ID
TGW_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-transit-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text \
  --region $REGION)

echo "=========================================="
echo "🎉 Hub Account Deployment Complete!"
echo "=========================================="
echo "Transit Gateway ID: $TGW_ID"
echo ""
echo "Next Steps:"
echo "1. Deploy StackSet Execution Roles in spoke accounts"
echo "2. Run deploy-spokes.sh to deploy spoke infrastructure"
echo "=========================================="
