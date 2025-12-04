#!/bin/bash

# Deployment script for Spoke Account infrastructure via StackSets
# This script creates/updates StackSets for spoke VPCs

set -e

# Configuration
REGION="${AWS_REGION:-us-east-1}"
HUB_ACCOUNT_ID="${HUB_ACCOUNT_ID:-000000000000}"
SPOKE_A_ACCOUNT_ID="${SPOKE_A_ACCOUNT_ID:-111111111111}"
SPOKE_B_ACCOUNT_ID="${SPOKE_B_ACCOUNT_ID:-222222222222}"

echo "=========================================="
echo "Spoke Account Infrastructure Deployment"
echo "=========================================="
echo "Region: $REGION"
echo "Hub Account: $HUB_ACCOUNT_ID"
echo "Spoke A Account: $SPOKE_A_ACCOUNT_ID"
echo "Spoke B Account: $SPOKE_B_ACCOUNT_ID"
echo ""

# Get Transit Gateway ID
echo "Retrieving Transit Gateway ID..."
TGW_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-transit-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text \
  --region $REGION)

echo "Transit Gateway ID: $TGW_ID"
echo ""

# Deploy Spoke A
echo "Step 1/2: Deploying Spoke A VPC via StackSet..."

if aws cloudformation describe-stack-set \
  --stack-set-name spoke-a-vpc \
  --region $REGION 2>/dev/null; then
  echo "StackSet exists, updating..."
  aws cloudformation update-stack-set \
    --stack-set-name spoke-a-vpc \
    --template-body file://cloudformation/spoke/vpc.yaml \
    --parameters \
      ParameterKey=EnvironmentName,ParameterValue=SpokeA \
      ParameterKey=VpcCIDR,ParameterValue=10.1.0.0/16 \
      ParameterKey=PublicSubnetCIDR,ParameterValue=10.1.1.0/24 \
      ParameterKey=PrivateSubnetCIDR,ParameterValue=10.1.11.0/24 \
      ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
      ParameterKey=HubVpcCIDR,ParameterValue=10.0.0.0/16 \
      ParameterKey=OtherSpokeCIDR,ParameterValue=10.2.0.0/16 \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --operation-preferences \
      FailureToleranceCount=0,MaxConcurrentCount=1 \
    --accounts $SPOKE_A_ACCOUNT_ID \
    --regions $REGION
else
  echo "Creating new StackSet..."
  aws cloudformation create-stack-set \
    --stack-set-name spoke-a-vpc \
    --template-body file://cloudformation/spoke/vpc.yaml \
    --parameters \
      ParameterKey=EnvironmentName,ParameterValue=SpokeA \
      ParameterKey=VpcCIDR,ParameterValue=10.1.0.0/16 \
      ParameterKey=PublicSubnetCIDR,ParameterValue=10.1.1.0/24 \
      ParameterKey=PrivateSubnetCIDR,ParameterValue=10.1.11.0/24 \
      ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
      ParameterKey=HubVpcCIDR,ParameterValue=10.0.0.0/16 \
      ParameterKey=OtherSpokeCIDR,ParameterValue=10.2.0.0/16 \
    --capabilities CAPABILITY_IAM \
    --administration-role-arn arn:aws:iam::$HUB_ACCOUNT_ID:role/AWSCloudFormationStackSetAdministrationRole \
    --execution-role-name AWSCloudFormationStackSetExecutionRole \
    --region $REGION
  
  echo "Creating stack instances..."
  aws cloudformation create-stack-instances \
    --stack-set-name spoke-a-vpc \
    --accounts $SPOKE_A_ACCOUNT_ID \
    --regions $REGION \
    --operation-preferences \
      FailureToleranceCount=0,MaxConcurrentCount=1
fi

echo "✅ Spoke A VPC StackSet deployed"
echo ""

# Deploy Spoke B
echo "Step 2/2: Deploying Spoke B VPC via StackSet..."

if aws cloudformation describe-stack-set \
  --stack-set-name spoke-b-vpc \
  --region $REGION 2>/dev/null; then
  echo "StackSet exists, updating..."
  aws cloudformation update-stack-set \
    --stack-set-name spoke-b-vpc \
    --template-body file://cloudformation/spoke/vpc.yaml \
    --parameters \
      ParameterKey=EnvironmentName,ParameterValue=SpokeB \
      ParameterKey=VpcCIDR,ParameterValue=10.2.0.0/16 \
      ParameterKey=PublicSubnetCIDR,ParameterValue=10.2.1.0/24 \
      ParameterKey=PrivateSubnetCIDR,ParameterValue=10.2.11.0/24 \
      ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
      ParameterKey=HubVpcCIDR,ParameterValue=10.0.0.0/16 \
      ParameterKey=OtherSpokeCIDR,ParameterValue=10.1.0.0/16 \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --operation-preferences \
      FailureToleranceCount=0,MaxConcurrentCount=1 \
    --accounts $SPOKE_B_ACCOUNT_ID \
    --regions $REGION
else
  echo "Creating new StackSet..."
  aws cloudformation create-stack-set \
    --stack-set-name spoke-b-vpc \
    --template-body file://cloudformation/spoke/vpc.yaml \
    --parameters \
      ParameterKey=EnvironmentName,ParameterValue=SpokeB \
      ParameterKey=VpcCIDR,ParameterValue=10.2.0.0/16 \
      ParameterKey=PublicSubnetCIDR,ParameterValue=10.2.1.0/24 \
      ParameterKey=PrivateSubnetCIDR,ParameterValue=10.2.11.0/24 \
      ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
      ParameterKey=HubVpcCIDR,ParameterValue=10.0.0.0/16 \
      ParameterKey=OtherSpokeCIDR,ParameterValue=10.1.0.0/16 \
    --capabilities CAPABILITY_IAM \
    --administration-role-arn arn:aws:iam::$HUB_ACCOUNT_ID:role/AWSCloudFormationStackSetAdministrationRole \
    --execution-role-name AWSCloudFormationStackSetExecutionRole \
    --region $REGION
  
  echo "Creating stack instances..."
  aws cloudformation create-stack-instances \
    --stack-set-name spoke-b-vpc \
    --accounts $SPOKE_B_ACCOUNT_ID \
    --regions $REGION \
    --operation-preferences \
      FailureToleranceCount=0,MaxConcurrentCount=1
fi

echo "✅ Spoke B VPC StackSet deployed"
echo ""

echo "=========================================="
echo "🎉 Spoke Account Deployment Complete!"
echo "=========================================="
echo "Next Steps:"
echo "1. Wait for StackSet operations to complete (5-10 minutes)"
echo "2. Verify Transit Gateway attachments are 'available'"
echo "3. Deploy test instances for connectivity verification"
echo "=========================================="
