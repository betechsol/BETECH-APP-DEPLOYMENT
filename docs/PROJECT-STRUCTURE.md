# BETECH-APP-DEPLOYMENT Project Structure

## 📁 Project Overview

The BETECH-APP-DEPLOYMENT project is organized into several key directories for efficient development, deployment, and management of a full-stack application on Amazon EKS.

```
BETECH-APP-DEPLOYMENT/
├── 📁 Application Components
│   ├── betech-login-backend/          # Spring Boot backend application
│   ├── betech-login-frontend/         # React frontend application
│   └── betech-postgresql-db/          # PostgreSQL database setup
│
├── 📁 EKS Infrastructure (Terraform)
│   └── eks-deployment/
│       ├── main.tf                    # Main Terraform configuration
│       ├── providers.tf               # Provider configurations
│       ├── variables.tf               # Variable definitions
│       ├── terraform.tfvars           # Variable values
│       ├── vpc.tf                     # VPC and networking
│       ├── eks.tf                     # EKS cluster configuration
│       ├── iam.tf                     # IAM roles and policies
│       ├── helm.tf                    # Helm charts for add-ons
│       ├── backend.tf                 # Terraform backend configuration
│       ├── outputs.tf                 # Output values
│       ├── deploy.sh                  # Terraform deployment script
│       ├── validate.sh                # Terraform validation script
│       ├── README.md                  # Terraform documentation
│       └── modules/                   # Custom Terraform modules
│
├── 📁 Kubernetes Manifests
│   └── manifests/
│       ├── aws-load-balancer-controller.yaml  # ALB controller
│       ├── backend-deployment.yaml            # Backend K8s deployment
│       ├── frontend-deployment.yaml           # Frontend K8s deployment
│       ├── postgres-deployment.yaml           # PostgreSQL K8s deployment
│       ├── ingress.yaml                       # ALB ingress configuration
│       ├── secrets.yaml                       # Database credentials
│       └── eks-cluster-config.yaml            # eksctl cluster config
│
├── 📁 Storage Configuration
│   └── persistent-volume-claim/
│       ├── README.md                  # Storage documentation
│       └── manifests/
│           ├── storageclass.yaml      # EBS storage class
│           └── pvc.yaml               # Persistent volume claim
│
├── 📁 Deployment Scripts
│   ├── deploy-eks.sh                 # Main EKS deployment script
│   ├── validate-deployment.sh        # Application validation script
│   └── docker-compose.yml            # Local development setup
│
├── 📁 Documentation
│   ├── README.md                     # Main project documentation
│   ├── EKS-DEPLOYMENT-README.md      # EKS deployment guide
│   └── PROJECT-STRUCTURE.md          # This file
│
└── 📁 Configuration Files
    ├── .git/                         # Git repository
    ├── .idea/                        # IDE configuration
    └── .gitignore                    # Git ignore rules
```

## 🏗️ Component Details

### Application Components

#### `betech-login-backend/`
- **Technology**: Spring Boot, Java
- **Purpose**: REST API backend for user authentication
- **Key Files**:
  - `src/` - Java source code
  - `Dockerfile` - Container image definition
  - `pom.xml` - Maven dependencies
  - `target/` - Compiled artifacts

#### `betech-login-frontend/`
- **Technology**: React, Node.js
- **Purpose**: Web frontend for user interface
- **Key Files**:
  - `src/` - React source code
  - `public/` - Static assets
  - `Dockerfile` - Container image definition
  - `package.json` - NPM dependencies
  - `nginx.conf` - Nginx configuration

#### `betech-postgresql-db/`
- **Technology**: PostgreSQL
- **Purpose**: Database initialization and configuration
- **Key Files**:
  - `Dockerfile` - Custom PostgreSQL image
  - `init.sql` - Database initialization scripts

### Infrastructure as Code

#### `eks-deployment/`
- **Technology**: Terraform
- **Purpose**: Complete EKS infrastructure provisioning
- **Components**:
  - **VPC**: Multi-AZ networking with public/private subnets
  - **EKS Cluster**: Managed Kubernetes with auto-scaling
  - **IAM Roles**: Service accounts and permissions
  - **ECR Repositories**: Container image storage
  - **Helm Charts**: Cluster add-ons and controllers

### Kubernetes Resources

#### `manifests/`
- **Technology**: Kubernetes YAML
- **Purpose**: Application deployment on EKS
- **Components**:
  - **Deployments**: Application workloads
  - **Services**: Network endpoints
  - **Ingress**: Load balancer configuration
  - **Secrets**: Sensitive configuration data

#### `persistent-volume-claim/`
- **Technology**: Kubernetes Storage
- **Purpose**: Persistent data storage for PostgreSQL
- **Components**:
  - **StorageClass**: EBS volume configuration
  - **PVC**: Volume claim for database

## 🚀 Deployment Workflows

### 1. Infrastructure Deployment
```bash
cd eks-deployment/
./deploy.sh
```

### 2. Application Deployment
```bash
# From project root
./deploy-eks.sh
```

### 3. Validation
```bash
./validate-deployment.sh
cd eks-deployment/ && ./validate.sh
```

## 🔄 Development Workflow

### Local Development
1. Use `docker-compose.yml` for local testing
2. Develop and test application components
3. Build and push images to ECR

### Infrastructure Changes
1. Modify Terraform files in `eks-deployment/`
2. Plan and apply changes
3. Validate infrastructure

### Application Updates
1. Update Kubernetes manifests in `manifests/`
2. Apply changes to cluster
3. Validate deployments

## 📊 File Organization Principles

### Separation of Concerns
- **Infrastructure**: Terraform in `eks-deployment/`
- **Applications**: Source code in component directories
- **Deployment**: Kubernetes manifests in `manifests/`
- **Storage**: Volume configuration in `persistent-volume-claim/`

### Environment Isolation
- **Development**: `docker-compose.yml` for local testing
- **Production**: EKS cluster with Terraform
- **Configuration**: Environment-specific values in tfvars

### Security Best Practices
- **Secrets**: Kubernetes secrets for sensitive data
- **IAM**: Least privilege roles and policies
- **Networking**: Private subnets for worker nodes

## 🛠️ Maintenance

### Regular Tasks
1. **Update Dependencies**: Keep application dependencies current
2. **Security Patches**: Apply security updates to base images
3. **Monitoring**: Review cluster and application metrics
4. **Backup**: Ensure database backup procedures

### Scaling Considerations
1. **Horizontal**: Increase replica counts in deployments
2. **Vertical**: Adjust resource requests/limits
3. **Cluster**: Modify node group configurations
4. **Storage**: Monitor and expand PVC sizes

## 📈 Monitoring and Observability

### Infrastructure Monitoring
- **CloudWatch**: EKS cluster metrics
- **VPC Flow Logs**: Network traffic analysis
- **ALB Logs**: Load balancer access logs

### Application Monitoring
- **Kubernetes Events**: Cluster event monitoring
- **Pod Logs**: Application log aggregation
- **Health Checks**: Liveness and readiness probes

## 🔐 Security Architecture

### Network Security
- **VPC**: Isolated network environment
- **Subnets**: Public/private subnet separation
- **Security Groups**: Controlled access rules
- **NAT Gateways**: Secure outbound internet access

### Application Security
- **Service Accounts**: RBAC for pod permissions
- **Secrets Management**: Encrypted secret storage
- **Image Scanning**: Container vulnerability detection
- **Pod Security**: Security contexts and policies

## 📚 Documentation Structure

### Technical Documentation
- **README.md**: Project overview and quick start
- **EKS-DEPLOYMENT-README.md**: Detailed EKS deployment guide
- **PROJECT-STRUCTURE.md**: This comprehensive structure guide

### Component Documentation
- Each component directory contains its own README
- Terraform modules include usage documentation
- Kubernetes manifests include inline comments

## 🎯 Best Practices Implemented

### Infrastructure
- **Immutable Infrastructure**: Infrastructure as Code with Terraform
- **Version Control**: All configurations in Git
- **Environment Parity**: Consistent environments across stages

### Development
- **Containerization**: Docker for consistent environments
- **Microservices**: Loosely coupled application components
- **Configuration Management**: External configuration injection

### Operations
- **Automation**: Scripted deployment and validation
- **Monitoring**: Comprehensive observability setup
- **Documentation**: Extensive documentation for maintenance

This structure supports scalable, maintainable, and secure deployment of the BETECH application on Amazon EKS.
