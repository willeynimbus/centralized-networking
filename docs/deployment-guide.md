# Deployment Guide

This guide provides step-by-step instructions for deploying the centralized networking infrastructure.

## Prerequisites

### AWS Accounts
- [ ] Network Hub Account with admin access
- [ ] Spoke Account A with admin access
- [ ] Spoke Account B with admin access
- [ ] AWS CLI configured with appropriate credentials

### GitHub Setup
- [ ] GitHub repository created
- [ ] Code pushed to repository
- [ ] GitHub Actions enabled

### Tools Required
- AWS CLI v2 (latest version)
- Git
- Text editor

## Step 1: Prepare Configuration

### 1.1 Collect Account Information

Document your AWS account IDs:

```
Hub Account ID:     ___________________________
Spoke A Account ID: ___________________________
Spoke B Account ID: ___________________________
AWS Region:         ___________________________
```

### 1.2 Configure GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AWS_ROLE_ARN` | ARN of GitHub Actions role | `arn:aws:iam::123456789012:role/GitHubActionsDeploymentRole` |
| `HUB_ACCOUNT_ID` | Hub account ID | `123456789012` |
| `SPOKE_A_ACCOUNT_ID` | Spoke A account ID | `111111111111` |
| `SPOKE_B_ACCOUNT_ID` | Spoke B account ID | `222222222222` |

### 1.3 Configure GitHub Variables

Add the following variable:

| Variable Name | Value | Example |
|---------------|-------|---------|
| `AWS_REGION` | Deployment region | `us-east-1` |

## Step 2: Deploy StackSet Execution Roles in Spoke Accounts

**IMPORTANT**: This must be done before deploying spoke infrastructure.

### 2.1 Deploy to Spoke Account A

```bash
# Configure AWS CLI for Spoke Account A
export AWS_PROFILE=spoke-a
# OR
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# Deploy the execution role
aws cloudformation deploy \
  --template-file cloudformation/spoke/stackset-execution-role.yaml \
  --stack-name stackset-execution-role \
  --parameter-overrides HubAccountId=<YOUR_HUB_ACCOUNT_ID> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 2.2 Deploy to Spoke Account B

```bash
# Configure AWS CLI for Spoke Account B
export AWS_PROFILE=spoke-b
# OR
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# Deploy the execution role
aws cloudformation deploy \
  --template-file cloudformation/spoke/stackset-execution-role.yaml \
  --stack-name stackset-execution-role \
  --parameter-overrides HubAccountId=<YOUR_HUB_ACCOUNT_ID> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 2.3 Verify Execution Roles

```bash
# In Spoke Account A
aws iam get-role --role-name AWSCloudFormationStackSetExecutionRole

# In Spoke Account B
aws iam get-role --role-name AWSCloudFormationStackSetExecutionRole
```

## Step 3: Deploy Infrastructure

### Option A: Automated Deployment via GitHub Actions (Recommended)

1. **Push code to main branch:**

```bash
git add .
git commit -m "Initial deployment of centralized networking"
git push origin main
```

2. **Monitor deployment:**
   - Go to GitHub repository → Actions tab
   - Watch the "Deploy Infrastructure" workflow
   - Deployment takes approximately 15-20 minutes

3. **Verify deployment:**
   - Check workflow logs for any errors
   - Verify all jobs completed successfully

### Option B: Manual Deployment via Scripts

#### Using Bash (Linux/Mac)

```bash
# Set environment variables
export AWS_REGION=us-east-1
export HUB_ACCOUNT_ID=123456789012
export SPOKE_A_ACCOUNT_ID=111111111111
export SPOKE_B_ACCOUNT_ID=222222222222
export GITHUB_ORG=your-github-org
export GITHUB_REPO=centralized-networking

# Configure AWS CLI for Hub Account
export AWS_PROFILE=hub

# Deploy Hub infrastructure
chmod +x scripts/deploy-hub.sh
./scripts/deploy-hub.sh

# Wait for completion, then deploy spokes
chmod +x scripts/deploy-spokes.sh
./scripts/deploy-spokes.sh
```

#### Using PowerShell (Windows)

```powershell
# Set environment variables
$env:AWS_REGION = "us-east-1"
$env:HUB_ACCOUNT_ID = "123456789012"
$env:SPOKE_A_ACCOUNT_ID = "111111111111"
$env:SPOKE_B_ACCOUNT_ID = "222222222222"
$env:GITHUB_ORG = "your-github-org"
$env:GITHUB_REPO = "centralized-networking"

# Configure AWS CLI for Hub Account
$env:AWS_PROFILE = "hub"

# Deploy Hub infrastructure
.\scripts\deploy-hub.ps1

# Wait for completion, then deploy spokes
.\scripts\deploy-spokes.ps1
```

#### Using AWS CLI Directly

```bash
# 1. Deploy IAM Roles
aws cloudformation deploy \
  --template-file cloudformation/hub/03-iam-roles.yaml \
  --stack-name hub-iam-roles \
  --parameter-overrides \
    SpokeAccountAId=111111111111 \
    SpokeAccountBId=222222222222 \
    GitHubOrg=your-github-org \
    GitHubRepo=centralized-networking \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# 2. Deploy Hub VPC
aws cloudformation deploy \
  --template-file cloudformation/hub/01-vpc.yaml \
  --stack-name hub-vpc \
  --parameter-overrides EnvironmentName=Hub \
  --region us-east-1

# 3. Deploy Transit Gateway
aws cloudformation deploy \
  --template-file cloudformation/hub/02-transit-gateway.yaml \
  --stack-name hub-transit-gateway \
  --parameter-overrides EnvironmentName=Hub \
  --region us-east-1

# 4. Get Transit Gateway ID
TGW_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-transit-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Transit Gateway ID: $TGW_ID"

# 5. Create StackSet for Spoke A
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
  --administration-role-arn arn:aws:iam::123456789012:role/AWSCloudFormationStackSetAdministrationRole \
  --execution-role-name AWSCloudFormationStackSetExecutionRole \
  --region us-east-1

# 6. Create stack instances for Spoke A
aws cloudformation create-stack-instances \
  --stack-set-name spoke-a-vpc \
  --accounts 111111111111 \
  --regions us-east-1

# Repeat steps 5-6 for Spoke B with appropriate parameters
```

## Step 4: Verify Deployment

### 4.1 Check Stack Status

```bash
# Hub Account
aws cloudformation describe-stacks --stack-name hub-iam-roles --region us-east-1
aws cloudformation describe-stacks --stack-name hub-vpc --region us-east-1
aws cloudformation describe-stacks --stack-name hub-transit-gateway --region us-east-1

# StackSets
aws cloudformation describe-stack-set --stack-set-name spoke-a-vpc --region us-east-1
aws cloudformation describe-stack-set --stack-set-name spoke-b-vpc --region us-east-1
```

### 4.2 Verify Transit Gateway

```bash
# Get Transit Gateway ID
TGW_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-transit-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text \
  --region us-east-1)

# Check Transit Gateway status
aws ec2 describe-transit-gateways \
  --transit-gateway-ids $TGW_ID \
  --region us-east-1

# Check attachments
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=$TGW_ID" \
  --region us-east-1
```

Expected output: All attachments should show `State: available`

### 4.3 Verify Route Tables

```bash
# Get TGW Route Table ID
TGW_RT_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-transit-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayRouteTableId`].OutputValue' \
  --output text \
  --region us-east-1)

# Check TGW routes
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id $TGW_RT_ID \
  --filters "Name=type,Values=propagated" \
  --region us-east-1
```

Expected: Routes for 10.0.0.0/16, 10.1.0.0/16, and 10.2.0.0/16

## Step 5: Deploy Test Instances

### 5.1 Get VPC and Subnet Information

```bash
# Hub VPC
HUB_VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-vpc \
  --query 'Stacks[0].Outputs[?OutputKey==`VPC`].OutputValue' \
  --output text \
  --region us-east-1)

HUB_SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-vpc \
  --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnet1`].OutputValue' \
  --output text \
  --region us-east-1)
```

### 5.2 Deploy Test Instance in Hub

```bash
aws cloudformation deploy \
  --template-file cloudformation/test/ec2-test-instance.yaml \
  --stack-name hub-test-instance \
  --parameter-overrides \
    EnvironmentName=Hub \
    VpcId=$HUB_VPC_ID \
    SubnetId=$HUB_SUBNET_ID \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 5.3 Deploy Test Instances in Spokes

Repeat the process for Spoke A and Spoke B accounts, or use StackSets.

## Step 6: Test Connectivity

### 6.1 Connect to Test Instance

```bash
# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name hub-test-instance \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text \
  --region us-east-1)

# Connect via Session Manager
aws ssm start-session --target $INSTANCE_ID --region us-east-1
```

### 6.2 Run Connectivity Tests

Once connected to the instance:

```bash
# Run the test script
/home/ec2-user/test-connectivity.sh

# Manual ping tests
ping -c 3 10.0.11.10  # Hub VPC
ping -c 3 10.1.11.10  # Spoke A VPC
ping -c 3 10.2.11.10  # Spoke B VPC

# Check routes
ip route

# Test internet connectivity
ping -c 3 8.8.8.8
```

### 6.3 Expected Results

✅ All pings should succeed
✅ Route table should show routes to TGW
✅ Internet connectivity should work

## Troubleshooting

### Issue: StackSet deployment fails

**Solution:**
1. Verify StackSet execution role exists in spoke accounts
2. Check trust relationship allows Hub Account
3. Verify account IDs are correct

```bash
# Check role in spoke account
aws iam get-role --role-name AWSCloudFormationStackSetExecutionRole
```

### Issue: Transit Gateway attachment stuck in "pending"

**Solution:**
1. Wait 10-15 minutes (attachments can take time)
2. Check subnet availability
3. Verify VPC has available IP addresses

```bash
# Check attachment status
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=$TGW_ID"
```

### Issue: Connectivity test fails

**Solution:**
1. Verify security groups allow ICMP
2. Check route tables have TGW routes
3. Ensure TGW attachments are "available"
4. Verify instance IPs are correct

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Check route table
aws ec2 describe-route-tables --route-table-ids <rt-id>
```

## Cleanup

To remove all infrastructure:

```bash
# Delete test instances
aws cloudformation delete-stack --stack-name hub-test-instance

# Delete StackSet instances
aws cloudformation delete-stack-instances \
  --stack-set-name spoke-a-vpc \
  --accounts 111111111111 \
  --regions us-east-1 \
  --no-retain-stacks

aws cloudformation delete-stack-instances \
  --stack-set-name spoke-b-vpc \
  --accounts 222222222222 \
  --regions us-east-1 \
  --no-retain-stacks

# Wait for instances to delete, then delete StackSets
aws cloudformation delete-stack-set --stack-set-name spoke-a-vpc
aws cloudformation delete-stack-set --stack-set-name spoke-b-vpc

# Delete Hub stacks (in reverse order)
aws cloudformation delete-stack --stack-name hub-transit-gateway
aws cloudformation wait stack-delete-complete --stack-name hub-transit-gateway

aws cloudformation delete-stack --stack-name hub-vpc
aws cloudformation wait stack-delete-complete --stack-name hub-vpc

aws cloudformation delete-stack --stack-name hub-iam-roles
```

## Next Steps

After successful deployment:

1. ✅ Document actual account IDs and resource IDs
2. ✅ Take screenshots of successful connectivity tests
3. ✅ Review architecture diagram
4. ✅ Complete architecture overview document
5. ✅ Plan for production enhancements

## Support

For issues or questions:
- Review [Architecture Overview](architecture-overview.md)
- Check [README.md](../README.md)
- Review CloudFormation stack events for errors
