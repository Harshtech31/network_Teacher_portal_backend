# BITS Pilani Teacher Portal Backend

A standalone Node.js backend API for the BITS Pilani Dubai NETWORK Teacher Portal, enabling teachers to create and manage events.

## 🚀 Quick Start

### Local Development

1. **Clone and Install**
   ```bash
   cd teacher-portal-backend
   npm install
   ```

2. **Environment Setup**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start Development Server**
   ```bash
   npm run dev
   ```

4. **Start Production Server**
   ```bash
   npm start
   ```

### AWS Deployment

1. **Prerequisites**
   - AWS CLI installed and configured
   - Valid AWS credentials with EC2, RDS permissions

2. **Deploy to AWS**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

## 📋 Required AWS Services

### Core Services
- **EC2** - Application hosting (t3.micro recommended)
- **RDS** - Database (PostgreSQL, t3.micro for development)
- **VPC** - Network isolation and security
- **Security Groups** - Firewall rules

### Optional Services
- **Route 53** - DNS management
- **Certificate Manager** - SSL/TLS certificates
- **CloudFront** - CDN for static assets
- **S3** - File uploads and static assets
- **ElastiCache** - Redis caching (for performance)
- **SES** - Email notifications

### Estimated Monthly Costs
- **Development**: $15-25/month
  - EC2 t3.micro: ~$8.50
  - RDS t3.micro: ~$12.50
  - Data transfer: ~$2-5

- **Production**: $50-100/month
  - EC2 t3.small: ~$17
  - RDS t3.small: ~$25
  - Load Balancer: ~$18
  - Additional services: ~$10-40

## 🔧 API Endpoints

### Authentication
- `POST /api/auth/login` - Teacher login
- `POST /api/auth/register` - Register new teacher
- `GET /api/auth/me` - Get current user profile
- `PUT /api/auth/profile` - Update profile
- `POST /api/auth/change-password` - Change password

### Events
- `GET /api/events` - Get teacher's events (with pagination/filters)
- `POST /api/events` - Create new event
- `GET /api/events/:id` - Get specific event
- `PUT /api/events/:id` - Update event
- `DELETE /api/events/:id` - Cancel event
- `GET /api/events/:id/participants` - Get event participants

### Teacher Dashboard
- `GET /api/teachers/dashboard` - Dashboard statistics
- `GET /api/teachers/stats` - Detailed analytics

## 🗄️ Database Schema

### User Model
```javascript
{
  name: String,
  email: String (unique),
  password: String (hashed),
  role: 'teacher' | 'admin',
  department: String,
  designation: String,
  campus: 'dubai' | 'pilani' | 'goa' | 'hyderabad',
  phone: String,
  isActive: Boolean,
  lastLogin: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### Event Model
```javascript
{
  title: String,
  description: String,
  category: 'academic' | 'cultural' | 'sports' | 'workshop' | 'seminar' | 'competition' | 'social',
  eventDate: Date,
  startTime: String,
  endTime: String,
  venue: String,
  maxParticipants: Number,
  registrationRequired: Boolean,
  isPublic: Boolean,
  tags: [String],
  imageUrl: String,
  requirements: String,
  contactEmail: String,
  contactPhone: String,
  createdBy: ObjectId,
  createdByName: String,
  createdByEmail: String,
  status: 'pending' | 'approved' | 'rejected' | 'cancelled',
  participants: [{
    userId: ObjectId,
    name: String,
    email: String,
    registeredAt: Date
  }],
  participantCount: Number,
  isActive: Boolean,
  campus: String,
  rejectionReason: String,
  approvedBy: ObjectId,
  approvedAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

## 🔒 Security Features

- JWT-based authentication
- Password hashing with bcrypt
- Role-based access control
- Rate limiting
- Input validation and sanitization
- CORS protection
- Helmet security headers
- Environment variable protection

## 🛠️ Development

### Scripts
- `npm start` - Production server
- `npm run dev` - Development with nodemon
- `npm test` - Run tests
- `npm run lint` - Code linting

### Environment Variables
```env
NODE_ENV=production
PORT=3001
MONGODB_URI=mongodb://localhost:27017/teacher_portal
JWT_SECRET=your-secret-key
JWT_EXPIRE=7d
FRONTEND_URL=http://localhost:3000
```

## 📊 Monitoring & Logging

- Request logging with Morgan
- Error handling middleware
- Health check endpoint: `/health`
- Performance monitoring ready
- AWS CloudWatch integration ready

## 🚀 Deployment Options

### Option 1: AWS EC2 (Recommended)
- Use provided `deploy.sh` script
- Automatic infrastructure setup
- Production-ready configuration

### Option 2: AWS Elastic Beanstalk
- Simple deployment
- Auto-scaling capabilities
- Managed platform updates

### Option 3: Docker Container
- Containerized deployment
- ECS or EKS compatible
- Consistent environments
