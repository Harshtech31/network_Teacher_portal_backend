#!/bin/bash

# BITS Teacher Portal - AWS Resources Cleanup Script
# This script deletes ALL AWS resources created by the deployment scripts

set -e

# Configuration - Update these to match your deployment
REGION="us-east-1"
APP_NAME="bits-teacher-portal"

# Backend resources
BACKEND_INSTANCE_NAME="bits-teacher-portal-backend"
BACKEND_KEY_NAME="teacher-portal-backend-key"
BACKEND_SECURITY_GROUP="teacher-portal-backend-sg"

# Frontend resources
FRONTEND_INSTANCE_NAME="bits-teacher-portal-frontend"
FRONTEND_KEY_NAME="teacher-portal-frontend-key"
FRONTEND_SECURITY_GROUP="teacher-portal-frontend-sg"
FRONTEND_BUCKET="bits-teacher-portal-frontend"

# Old deployment resources (from the original deploy.sh)
OLD_KEY_NAME="teacher-portal-key"
OLD_SECURITY_GROUP="teacher-portal-sg"
OLD_DB_INSTANCE="bits-teacher-portal-db"
OLD_SUBNET_GROUP="bits-teacher-portal-db-subnet-group"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}🗑️  AWS Resources Cleanup Script${NC}"
echo "=================================="
echo -e "${YELLOW}⚠️  WARNING: This will delete ALL AWS resources created for the Teacher Portal!${NC}"
echo ""
echo "Resources to be deleted:"
echo "  • EC2 Instances (Backend & Frontend)"
echo "  • Security Groups"
echo "  • SSH Key Pairs"
echo "  • S3 Buckets"
echo "  • CloudFront Distributions"
echo "  • RDS Instances (if any)"
echo "  • RDS Subnet Groups"
echo ""
read -p "Are you sure you want to continue? (type 'DELETE' to confirm): " confirmation

if [ "$confirmation" != "DELETE" ]; then
    echo -e "${GREEN}✅ Cleanup cancelled. No resources were deleted.${NC}"
    exit 0
fi

echo -e "${RED}🚨 Starting cleanup process...${NC}"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI configured successfully${NC}"

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local resource_name=$2
    local delete_command=$3
    
    echo -e "${YELLOW}🔍 Checking $resource_type: $resource_name${NC}"
    if eval "$delete_command" 2>/dev/null; then
        echo -e "${GREEN}✅ Deleted $resource_type: $resource_name${NC}"
    else
        echo -e "${BLUE}ℹ️  $resource_type not found or already deleted: $resource_name${NC}"
    fi
}

# 1. Terminate EC2 Instances
echo -e "${BLUE}🖥️  Terminating EC2 Instances...${NC}"

# Get instance IDs by name
BACKEND_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$BACKEND_INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped,stopping" \
    --region $REGION \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null || echo "")

FRONTEND_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$FRONTEND_INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped,stopping" \
    --region $REGION \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null || echo "")

OLD_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$APP_NAME" "Name=instance-state-name,Values=running,stopped,stopping" \
    --region $REGION \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null || echo "")

# Terminate instances
for instance_id in $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID $OLD_INSTANCE_ID; do
    if [ ! -z "$instance_id" ] && [ "$instance_id" != "None" ]; then
        echo -e "${YELLOW}🛑 Terminating instance: $instance_id${NC}"
        aws ec2 terminate-instances --instance-ids $instance_id --region $REGION
        echo -e "${YELLOW}⏳ Waiting for instance to terminate...${NC}"
        aws ec2 wait instance-terminated --instance-ids $instance_id --region $REGION
        echo -e "${GREEN}✅ Instance terminated: $instance_id${NC}"
    fi
done

# 2. Delete RDS Instances
echo -e "${BLUE}🗄️  Deleting RDS Instances...${NC}"
safe_delete "RDS Instance" "$OLD_DB_INSTANCE" \
    "aws rds delete-db-instance --db-instance-identifier $OLD_DB_INSTANCE --skip-final-snapshot --region $REGION"

# Wait for RDS deletion
if aws rds describe-db-instances --db-instance-identifier $OLD_DB_INSTANCE --region $REGION &>/dev/null; then
    echo -e "${YELLOW}⏳ Waiting for RDS instance to be deleted...${NC}"
    aws rds wait db-instance-deleted --db-instance-identifier $OLD_DB_INSTANCE --region $REGION 2>/dev/null || true
fi

# 3. Delete RDS Subnet Groups
echo -e "${BLUE}🔗 Deleting RDS Subnet Groups...${NC}"
safe_delete "RDS Subnet Group" "$OLD_SUBNET_GROUP" \
    "aws rds delete-db-subnet-group --db-subnet-group-name $OLD_SUBNET_GROUP --region $REGION"

# 4. Delete CloudFront Distributions
echo -e "${BLUE}☁️  Deleting CloudFront Distributions...${NC}"
DISTRIBUTIONS=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='BITS Teacher Portal Frontend'].Id" --output text 2>/dev/null || echo "")

for dist_id in $DISTRIBUTIONS; do
    if [ ! -z "$dist_id" ] && [ "$dist_id" != "None" ]; then
        echo -e "${YELLOW}🔄 Disabling CloudFront distribution: $dist_id${NC}"
        # Get current config
        ETAG=$(aws cloudfront get-distribution --id $dist_id --query 'ETag' --output text)
        aws cloudfront get-distribution-config --id $dist_id --query 'DistributionConfig' > temp-dist-config.json
        
        # Disable distribution
        sed -i 's/"Enabled": true/"Enabled": false/' temp-dist-config.json
        aws cloudfront update-distribution --id $dist_id --distribution-config file://temp-dist-config.json --if-match $ETAG
        
        echo -e "${YELLOW}⏳ Waiting for distribution to be disabled...${NC}"
        aws cloudfront wait distribution-deployed --id $dist_id
        
        # Delete distribution
        ETAG=$(aws cloudfront get-distribution --id $dist_id --query 'ETag' --output text)
        aws cloudfront delete-distribution --id $dist_id --if-match $ETAG
        echo -e "${GREEN}✅ CloudFront distribution deleted: $dist_id${NC}"
        
        rm -f temp-dist-config.json
    fi
done

# 5. Delete S3 Buckets
echo -e "${BLUE}🪣 Deleting S3 Buckets...${NC}"
if aws s3 ls s3://$FRONTEND_BUCKET --region $REGION &>/dev/null; then
    echo -e "${YELLOW}🗑️  Emptying S3 bucket: $FRONTEND_BUCKET${NC}"
    aws s3 rm s3://$FRONTEND_BUCKET --recursive
    echo -e "${YELLOW}🗑️  Deleting S3 bucket: $FRONTEND_BUCKET${NC}"
    aws s3 rb s3://$FRONTEND_BUCKET --region $REGION
    echo -e "${GREEN}✅ S3 bucket deleted: $FRONTEND_BUCKET${NC}"
else
    echo -e "${BLUE}ℹ️  S3 bucket not found: $FRONTEND_BUCKET${NC}"
fi

# 6. Delete Security Groups
echo -e "${BLUE}🛡️  Deleting Security Groups...${NC}"
for sg_name in "$BACKEND_SECURITY_GROUP" "$FRONTEND_SECURITY_GROUP" "$OLD_SECURITY_GROUP"; do
    SG_ID=$(aws ec2 describe-security-groups --group-names "$sg_name" --region $REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
        safe_delete "Security Group" "$sg_name ($SG_ID)" \
            "aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
    fi
done

# 7. Delete Key Pairs
echo -e "${BLUE}🔑 Deleting Key Pairs...${NC}"
for key_name in "$BACKEND_KEY_NAME" "$FRONTEND_KEY_NAME" "$OLD_KEY_NAME"; do
    safe_delete "Key Pair" "$key_name" \
        "aws ec2 delete-key-pair --key-name $key_name --region $REGION"
    
    # Delete local key files
    if [ -f "${key_name}.pem" ]; then
        rm -f "${key_name}.pem"
        echo -e "${GREEN}✅ Deleted local key file: ${key_name}.pem${NC}"
    fi
done

# 8. Clean up local files
echo -e "${BLUE}🧹 Cleaning up local files...${NC}"
rm -f backend-deployment-info.txt
rm -f deployment-info.txt
rm -f bucket-policy.json
rm -f cloudfront-config.json
rm -f user-data.sh
rm -f backend-user-data.sh
rm -f frontend-user-data.sh
echo -e "${GREEN}✅ Local deployment files cleaned up${NC}"

echo ""
echo -e "${GREEN}🎉 AWS Resources Cleanup Complete!${NC}"
echo "=================================="
echo -e "${GREEN}✅ All Teacher Portal AWS resources have been deleted:${NC}"
echo "  • EC2 Instances: Terminated"
echo "  • Security Groups: Deleted"
echo "  • SSH Key Pairs: Deleted"
echo "  • S3 Buckets: Deleted"
echo "  • CloudFront Distributions: Deleted"
echo "  • RDS Instances: Deleted"
echo "  • Local files: Cleaned up"
echo ""
echo -e "${BLUE}💰 Cost Impact:${NC}"
echo "  • No more charges for running instances"
echo "  • No more storage costs"
echo "  • No more data transfer costs"
echo ""
echo -e "${YELLOW}📝 Note:${NC}"
echo "  • You can now start fresh with new deployments"
echo "  • All deployment scripts are still available"
echo "  • No AWS resources remain from previous deployments"
echo ""
echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
