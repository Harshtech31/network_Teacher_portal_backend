#!/bin/bash

# BITS Pilani Teacher Portal - AWS Deployment Script
# This script deploys the teacher portal backend to AWS using EC2, RDS, and other services

set -e  # Exit on any error

# Configuration
APP_NAME="bits-teacher-portal"
REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
KEY_NAME="teacher-portal-key"
SECURITY_GROUP="teacher-portal-sg"
DB_INSTANCE_CLASS="db.t3.micro"
DB_NAME="teacherportal"
DB_USERNAME="teacherportal"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting BITS Pilani Teacher Portal AWS Deployment${NC}"
echo "=================================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI configured successfully${NC}"

# Generate random password for database
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo -e "${YELLOW}📋 Deployment Configuration:${NC}"
echo "  App Name: $APP_NAME"
echo "  Region: $REGION"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Database: $DB_INSTANCE_CLASS"
echo ""

# Create key pair if it doesn't exist
echo -e "${BLUE}🔑 Creating EC2 Key Pair...${NC}"
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &> /dev/null; then
    aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo -e "${GREEN}✅ Key pair created: ${KEY_NAME}.pem${NC}"
else
    echo -e "${YELLOW}⚠️  Key pair already exists${NC}"
fi

# Create security group
echo -e "${BLUE}🛡️  Creating Security Group...${NC}"
if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION &> /dev/null; then
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "Security group for Teacher Portal" \
        --region $REGION \
        --query 'GroupId' --output text)
    
    # Add inbound rules
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 3001 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    echo -e "${GREEN}✅ Security group created: $SECURITY_GROUP_ID${NC}"
else
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION --query 'SecurityGroups[0].GroupId' --output text)
    echo -e "${YELLOW}⚠️  Security group already exists: $SECURITY_GROUP_ID${NC}"
fi

# Create RDS subnet group
echo -e "${BLUE}🗄️  Creating RDS Subnet Group...${NC}"
SUBNET_GROUP_NAME="${APP_NAME}-db-subnet-group"

# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region $REGION --query 'Vpcs[0].VpcId' --output text)
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'Subnets[*].SubnetId' --output text)

if ! aws rds describe-db-subnet-groups --db-subnet-group-name $SUBNET_GROUP_NAME --region $REGION &> /dev/null; then
    aws rds create-db-subnet-group \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --db-subnet-group-description "Subnet group for Teacher Portal DB" \
        --subnet-ids $SUBNETS \
        --region $REGION
    echo -e "${GREEN}✅ RDS subnet group created${NC}"
else
    echo -e "${YELLOW}⚠️  RDS subnet group already exists${NC}"
fi

# Create RDS instance
echo -e "${BLUE}🗄️  Creating RDS MongoDB-compatible Database...${NC}"
DB_INSTANCE_ID="${APP_NAME}-db"

if ! aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $REGION &> /dev/null; then
    aws rds create-db-instance \
        --db-instance-identifier $DB_INSTANCE_ID \
        --db-instance-class $DB_INSTANCE_CLASS \
        --engine postgres \
        --master-username $DB_USERNAME \
        --master-user-password $DB_PASSWORD \
        --allocated-storage 20 \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --region $REGION \
        --no-publicly-accessible
    
    echo -e "${YELLOW}⏳ Waiting for RDS instance to be available...${NC}"
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID --region $REGION
    echo -e "${GREEN}✅ RDS instance created and available${NC}"
else
    echo -e "${YELLOW}⚠️  RDS instance already exists${NC}"
fi

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $REGION --query 'DBInstances[0].Endpoint.Address' --output text)

# Create user data script for EC2
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y nodejs npm git

# Install PM2 globally
npm install -g pm2

# Create app directory
mkdir -p /opt/teacher-portal
cd /opt/teacher-portal

# Clone or copy application code (you'll need to modify this)
# For now, we'll create a placeholder
echo "Application code should be deployed here"

# Install dependencies
# npm install

# Create environment file
cat > .env << 'ENVEOF'
NODE_ENV=production
PORT=3001
MONGODB_URI=mongodb://localhost:27017/teacher_portal
JWT_SECRET=super-secret-jwt-key-change-in-production
FRONTEND_URL=https://your-frontend-domain.com
ENVEOF

# Start application with PM2
# pm2 start server.js --name teacher-portal
# pm2 startup
# pm2 save

# Install and configure nginx
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# Configure nginx as reverse proxy
cat > /etc/nginx/conf.d/teacher-portal.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINXEOF

systemctl restart nginx
EOF

# Launch EC2 instance
echo -e "${BLUE}🖥️  Launching EC2 Instance...${NC}"
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ami-0bb4c991fa89d4b9b \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --user-data file://user-data.sh \
    --region $REGION \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$APP_NAME}]" \
    --query 'Instances[0].InstanceId' --output text)

echo -e "${YELLOW}⏳ Waiting for EC2 instance to be running...${NC}"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get instance public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo -e "${GREEN}✅ EC2 instance launched successfully${NC}"

# Create deployment summary
echo ""
echo -e "${GREEN}🎉 Deployment Summary${NC}"
echo "===================="
echo -e "${BLUE}EC2 Instance:${NC}"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  SSH Command: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo ""
echo -e "${BLUE}RDS Database:${NC}"
echo "  Instance ID: $DB_INSTANCE_ID"
echo "  Endpoint: $DB_ENDPOINT"
echo "  Username: $DB_USERNAME"
echo "  Password: $DB_PASSWORD"
echo ""
echo -e "${BLUE}Application URLs:${NC}"
echo "  Backend API: http://$PUBLIC_IP:3001"
echo "  Health Check: http://$PUBLIC_IP:3001/health"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. SSH into the instance: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo "2. Deploy your application code to /opt/teacher-portal"
echo "3. Update the .env file with correct database credentials"
echo "4. Install dependencies: npm install"
echo "5. Start the application: pm2 start server.js --name teacher-portal"
echo "6. Configure your domain and SSL certificate"
echo ""
echo -e "${RED}⚠️  Security Notes:${NC}"
echo "- Change the JWT_SECRET in production"
echo "- Store the database password securely: $DB_PASSWORD"
echo "- Configure proper firewall rules"
echo "- Set up SSL/TLS certificates"
echo ""

# Save deployment info to file
cat > deployment-info.txt << EOF
BITS Pilani Teacher Portal - AWS Deployment Info
===============================================

Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
Security Group: $SECURITY_GROUP_ID
Key Pair: $KEY_NAME

Database Instance: $DB_INSTANCE_ID
Database Endpoint: $DB_ENDPOINT
Database Username: $DB_USERNAME
Database Password: $DB_PASSWORD

SSH Command: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP
Backend URL: http://$PUBLIC_IP:3001

Deployment Date: $(date)
EOF

echo -e "${GREEN}💾 Deployment info saved to: deployment-info.txt${NC}"
echo -e "${GREEN}🚀 Teacher Portal Backend deployed successfully!${NC}"

# Cleanup
rm -f user-data.sh
