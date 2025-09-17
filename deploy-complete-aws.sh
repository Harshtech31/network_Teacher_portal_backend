#!/bin/bash

# BITS Pilani Teacher Portal - Complete AWS Deployment Script
# This script deploys the entire application with AWS RDS PostgreSQL

set -e

# Configuration
APP_NAME="bits-teacher-portal"
REGION="us-east-1"
INSTANCE_TYPE="t3.small"
KEY_NAME="teacher-portal-key"
SECURITY_GROUP="teacher-portal-sg"
DB_INSTANCE_CLASS="db.t3.micro"
DB_NAME="teacherportal"
DB_USERNAME="teacherportal"
AMI_ID="ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS

# Generate secure passwords
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 BITS Pilani Teacher Portal - Complete AWS Deployment${NC}"
echo "========================================================"
echo -e "${PURPLE}📋 Deployment Configuration:${NC}"
echo "  • App Name: $APP_NAME"
echo "  • Region: $REGION"
echo "  • Instance Type: $INSTANCE_TYPE"
echo "  • Database: PostgreSQL on RDS ($DB_INSTANCE_CLASS)"
echo "  • OS: Ubuntu 22.04 LTS"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI configured successfully${NC}"

# 1. Create Key Pair
echo -e "${BLUE}🔑 Creating SSH Key Pair...${NC}"
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &> /dev/null; then
    aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo -e "${GREEN}✅ Key pair created: ${KEY_NAME}.pem${NC}"
else
    echo -e "${YELLOW}⚠️  Key pair already exists${NC}"
fi

# 2. Create Security Group
echo -e "${BLUE}🛡️  Creating Security Group...${NC}"
if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION &> /dev/null; then
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "Security group for Teacher Portal" \
        --region $REGION \
        --query 'GroupId' --output text)
    
    # Add inbound rules
    aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
    aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 3001 --cidr 0.0.0.0/0 --region $REGION
    aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
    aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
    aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 5432 --source-group $SECURITY_GROUP_ID --region $REGION
    
    echo -e "${GREEN}✅ Security group created: $SECURITY_GROUP_ID${NC}"
else
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION --query 'SecurityGroups[0].GroupId' --output text)
    echo -e "${YELLOW}⚠️  Security group already exists: $SECURITY_GROUP_ID${NC}"
fi

# 3. Create RDS Subnet Group
echo -e "${BLUE}🗄️  Creating RDS Subnet Group...${NC}"
SUBNET_GROUP_NAME="${APP_NAME}-db-subnet-group"

# Get default VPC and subnets
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

# 4. Create RDS PostgreSQL Instance
echo -e "${BLUE}🗄️  Creating RDS PostgreSQL Database...${NC}"
DB_INSTANCE_ID="${APP_NAME}-db"

# Get the latest available PostgreSQL version
echo -e "${YELLOW}🔍 Finding available PostgreSQL versions...${NC}"
POSTGRES_VERSION=$(aws rds describe-db-engine-versions --engine postgres --region $REGION --query 'DBEngineVersions[?contains(EngineVersion, `14.`) || contains(EngineVersion, `15.`) || contains(EngineVersion, `13.`)].EngineVersion' --output text | head -1)

if [ -z "$POSTGRES_VERSION" ]; then
    # Fallback to a common version
    POSTGRES_VERSION="14.9"
fi

echo -e "${GREEN}✅ Using PostgreSQL version: $POSTGRES_VERSION${NC}"

if ! aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $REGION &> /dev/null; then
    aws rds create-db-instance \
        --db-instance-identifier $DB_INSTANCE_ID \
        --db-instance-class $DB_INSTANCE_CLASS \
        --engine postgres \
        --engine-version $POSTGRES_VERSION \
        --master-username $DB_USERNAME \
        --master-user-password $DB_PASSWORD \
        --allocated-storage 20 \
        --db-name $DB_NAME \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --region $REGION \
        --backup-retention-period 7 \
        --storage-encrypted \
        --no-publicly-accessible
    
    echo -e "${YELLOW}⏳ Waiting for RDS instance to be available (this may take 10-15 minutes)...${NC}"
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID --region $REGION
    echo -e "${GREEN}✅ RDS PostgreSQL instance created and available${NC}"
else
    echo -e "${YELLOW}⚠️  RDS instance already exists${NC}"
fi

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $REGION --query 'DBInstances[0].Endpoint.Address' --output text)
echo -e "${GREEN}📍 Database endpoint: $DB_ENDPOINT${NC}"

# 5. Create User Data Script for EC2
echo -e "${BLUE}📝 Creating server setup script...${NC}"
cat > user-data.sh << 'EOF'
#!/bin/bash

# Update system
apt update -y
apt upgrade -y

# Install Node.js 18 LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install PostgreSQL client
apt install -y postgresql-client

# Install PM2 globally
npm install -g pm2

# Install Git
apt install -y git

# Install Nginx
apt install -y nginx

# Create application directory
mkdir -p /opt/teacher-portal
cd /opt/teacher-portal

# Set permissions
chown -R ubuntu:ubuntu /opt/teacher-portal

# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/teacher-portal << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    # API routes
    location /api {
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

    # Health check
    location /health {
        proxy_pass http://localhost:3001/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Root
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

# Enable the site
ln -sf /etc/nginx/sites-available/teacher-portal /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t && systemctl restart nginx
systemctl enable nginx

# Create temporary health check server
cat > /opt/teacher-portal/temp-server.js << 'TEMPEOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json());

app.get('/', (req, res) => {
    res.json({ 
        message: 'BITS Teacher Portal Backend - Ready for deployment!',
        status: 'healthy',
        database: 'PostgreSQL on AWS RDS',
        timestamp: new Date().toISOString()
    });
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'teacher-portal-backend',
        database: 'postgresql',
        timestamp: new Date().toISOString()
    });
});

app.listen(PORT, () => {
    console.log(`Temporary server running on port ${PORT}`);
});
TEMPEOF

# Install express for temporary server
cd /opt/teacher-portal
npm init -y
npm install express

# Start temporary server
pm2 start temp-server.js --name teacher-portal-temp
pm2 startup
pm2 save

# Log completion
echo "Complete AWS setup completed at $(date)" >> /var/log/setup.log
EOF

# 6. Launch EC2 Instance
echo -e "${BLUE}🖥️  Launching EC2 Instance...${NC}"
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
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

# 7. Create Environment Configuration
echo -e "${BLUE}⚙️  Creating environment configuration...${NC}"
cat > production.env << EOF
NODE_ENV=production
PORT=3001

# PostgreSQL Database Configuration
DB_HOST=$DB_ENDPOINT
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DATABASE_URL=postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/$DB_NAME

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

# CORS Configuration
CORS_ORIGIN=*

# Email Configuration (Update with your SMTP details)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password

# Frontend URL
FRONTEND_URL=http://localhost:3000

# AWS Configuration (for file uploads, etc.)
AWS_REGION=$REGION
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_BUCKET_NAME=teacher-portal-uploads
EOF

# 8. Create Database Migration Script
echo -e "${BLUE}🗄️  Creating database migration script...${NC}"
cat > migrate-database.sql << 'EOF'
-- BITS Teacher Portal Database Schema
-- PostgreSQL Migration Script

-- Create Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'teacher',
    department VARCHAR(100),
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    verification_token VARCHAR(255),
    reset_password_token VARCHAR(255),
    reset_password_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Events table
CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50) NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    location VARCHAR(255),
    max_participants INTEGER,
    registration_deadline TIMESTAMP,
    status VARCHAR(50) DEFAULT 'draft',
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Event Registrations table
CREATE TABLE IF NOT EXISTS event_registrations (
    id SERIAL PRIMARY KEY,
    event_id INTEGER REFERENCES events(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'registered',
    notes TEXT,
    UNIQUE(event_id, user_id)
);

-- Create Announcements table
CREATE TABLE IF NOT EXISTS announcements (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    priority VARCHAR(50) DEFAULT 'normal',
    target_audience VARCHAR(100) DEFAULT 'all',
    is_published BOOLEAN DEFAULT false,
    published_at TIMESTAMP,
    expires_at TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Departments table
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    code VARCHAR(10) UNIQUE NOT NULL,
    description TEXT,
    head_of_department INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Sessions table for user sessions
CREATE TABLE IF NOT EXISTS sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events(start_date);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_event_registrations_event_id ON event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_user_id ON event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_announcements_published ON announcements(is_published);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);

-- Insert default admin user (password: admin123 - change this!)
INSERT INTO users (email, password, first_name, last_name, role, is_active, is_verified)
VALUES (
    'admin@bitspilani.ae',
    '$2a$10$rOzJqQZQQZQQZQZQQZQQZOzJqQZQQZQQZQZQQZQQZOzJqQZQQZQQZQ',
    'Admin',
    'User',
    'admin',
    true,
    true
) ON CONFLICT (email) DO NOTHING;

-- Insert sample departments
INSERT INTO departments (name, code, description) VALUES
    ('Computer Science', 'CS', 'Computer Science and Engineering Department'),
    ('Electrical Engineering', 'EE', 'Electrical and Electronics Engineering Department'),
    ('Mechanical Engineering', 'ME', 'Mechanical Engineering Department'),
    ('Business Administration', 'BA', 'Business Administration Department')
ON CONFLICT (code) DO NOTHING;
EOF

# 9. Save Deployment Information
cat > complete-deployment-info.txt << EOF
BITS Pilani Teacher Portal - Complete AWS Deployment Info
========================================================

🖥️  EC2 Instance:
   Instance ID: $INSTANCE_ID
   Public IP: $PUBLIC_IP
   Private IP: $(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
   SSH Command: ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP

🗄️  RDS PostgreSQL Database:
   Instance ID: $DB_INSTANCE_ID
   Endpoint: $DB_ENDPOINT
   Database Name: $DB_NAME
   Username: $DB_USERNAME
   Password: $DB_PASSWORD
   Connection String: postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/$DB_NAME

🔐 Security:
   Key Pair: $KEY_NAME
   Security Group: $SECURITY_GROUP ($SECURITY_GROUP_ID)
   JWT Secret: $JWT_SECRET

🌐 URLs:
   Backend API: http://$PUBLIC_IP:3001
   Health Check: http://$PUBLIC_IP/health

📁 Files Created:
   - ${KEY_NAME}.pem (SSH key)
   - production.env (Environment variables)
   - migrate-database.sql (Database schema)
   - user-data.sh (Server setup script)

📋 Next Steps:
   1. Wait 10 minutes for server setup to complete
   2. Upload your backend code
   3. Run database migrations
   4. Update environment variables
   5. Deploy your frontend

Deployment Date: $(date)
Region: $REGION
EOF

# Cleanup temporary files
rm -f user-data.sh

echo ""
echo -e "${GREEN}🎉 Complete AWS Deployment Finished!${NC}"
echo "=============================================="
echo -e "${PURPLE}📊 Deployment Summary:${NC}"
echo -e "${GREEN}✅ EC2 Instance: $INSTANCE_ID (Ubuntu 22.04 LTS)${NC}"
echo -e "${GREEN}✅ Public IP: $PUBLIC_IP${NC}"
echo -e "${GREEN}✅ PostgreSQL Database: $DB_ENDPOINT${NC}"
echo -e "${GREEN}✅ Security Group: $SECURITY_GROUP_ID${NC}"
echo -e "${GREEN}✅ SSH Key: ${KEY_NAME}.pem${NC}"
echo ""
echo -e "${BLUE}🔗 Access Information:${NC}"
echo "   SSH: ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
echo "   Backend: http://$PUBLIC_IP:3001"
echo "   Health: http://$PUBLIC_IP/health"
echo ""
echo -e "${YELLOW}⏳ Server Setup Progress:${NC}"
echo "   1. ✅ Infrastructure created"
echo "   2. ⏳ Installing software (10 minutes)"
echo "   3. ⏳ Configuring services"
echo "   4. ⏳ Starting temporary server"
echo ""
echo -e "${PURPLE}📝 Next Steps:${NC}"
echo "   1. Wait 10 minutes for setup completion"
echo "   2. Test: curl http://$PUBLIC_IP/health"
echo "   3. Upload your PostgreSQL-compatible backend code"
echo "   4. Run database migrations"
echo "   5. Deploy frontend"
echo ""
echo -e "${GREEN}💾 Important Files Created:${NC}"
echo "   • complete-deployment-info.txt (All deployment details)"
echo "   • production.env (Environment variables)"
echo "   • migrate-database.sql (Database schema)"
echo "   • ${KEY_NAME}.pem (SSH key - keep secure!)"
echo ""
echo -e "${RED}🔐 Security Reminders:${NC}"
echo "   • Keep your SSH key secure: ${KEY_NAME}.pem"
echo "   • Database password: $DB_PASSWORD"
echo "   • Change default admin password after first login"
echo "   • Update email configuration in production.env"
echo ""
echo -e "${GREEN}✅ AWS Infrastructure Ready for Teacher Portal!${NC}"
