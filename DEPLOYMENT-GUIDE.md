# BETECH Application Deployment Guide

## 🚀 Deployment Options

The BETECH application supports multiple deployment strategies:

### 1. Local Development (Docker Compose)
For local development and testing:
```bash
docker-compose up --build
```

### 2. EKS Deployment (eksctl + kubectl)
Using the traditional Kubernetes deployment approach:
```bash
./deploy-eks.sh
```

### 3. EKS Deployment (Terraform)
Using Infrastructure as Code with Terraform:
```bash
cd eks-deployment/
./deploy.sh
```

## 📋 Prerequisites for EKS Deployment

### Required Tools
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# eksctl (for eksctl method)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Terraform (for Terraform method)
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Helm (optional)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### AWS Configuration
```bash
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

## 🔄 Deployment Methods Comparison

| Feature | Docker Compose | eksctl + kubectl | Terraform |
|---------|----------------|------------------|-----------|
| **Use Case** | Local Development | Quick EKS Setup | Production Infrastructure |
| **Infrastructure** | Local containers | Manual EKS setup | Complete IaC |
| **Complexity** | Low | Medium | High |
| **Scalability** | Limited | High | Very High |
| **Reproducibility** | Medium | Medium | Very High |
| **Cost** | Free | EKS charges | EKS charges |

## 📁 File Organization by Deployment Method

### Docker Compose Files
```
├── docker-compose.yml           # Multi-container orchestration
├── betech-login-backend/        # Backend source + Dockerfile
├── betech-login-frontend/       # Frontend source + Dockerfile
└── betech-postgresql-db/        # Database source + Dockerfile
```

### eksctl + kubectl Files
```
├── deploy-eks.sh                # Main deployment script
├── validate-deployment.sh       # Validation script
├── manifests/                   # Kubernetes manifests
│   ├── eks-cluster-config.yaml  # eksctl cluster config
│   ├── aws-load-balancer-controller.yaml
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── postgres-deployment.yaml
│   ├── ingress.yaml
│   └── secrets.yaml
└── persistent-volume-claim/     # Storage configuration
    └── manifests/
```

### Terraform Files
```
└── eks-deployment/              # Complete Terraform setup
    ├── main.tf                  # Main configuration
    ├── providers.tf             # Provider configurations
    ├── variables.tf             # Variable definitions
    ├── terraform.tfvars         # Variable values
    ├── vpc.tf                   # VPC and networking
    ├── eks.tf                   # EKS cluster
    ├── iam.tf                   # IAM roles and policies
    ├── helm.tf                  # Helm charts
    ├── backend.tf               # Terraform backend
    ├── outputs.tf               # Output values
    ├── deploy.sh                # Terraform deployment script
    ├── validate.sh              # Terraform validation script
    └── README.md                # Terraform documentation
```

## 🚀 Quick Start Guides

### Method 1: Local Development
```bash
# Clone and start
git clone <repository-url>
cd BETECH-APP-DEPLOYMENT
docker-compose up --build

# Access application
# Frontend: http://localhost:3000
# Backend: http://localhost:8080
# Database: localhost:5432
```

### Method 2: EKS with eksctl
```bash
# Deploy infrastructure and applications
./deploy-eks.sh

# Validate deployment
./validate-deployment.sh

# Get application URL
kubectl get ingress betechnet-ingress
```

### Method 3: EKS with Terraform
```bash
# Deploy infrastructure
cd eks-deployment/
./deploy.sh

# Validate infrastructure
./validate.sh

# Check application status
kubectl get pods
```

## 🔍 Validation and Monitoring

### Application Health Checks
```bash
# Check pod status
kubectl get pods

# Check service endpoints
kubectl get services

# Check ingress status
kubectl get ingress

# View application logs
kubectl logs -l app=betechnet-frontend
kubectl logs -l app=betechnet-backend
kubectl logs -l app=betechnet-postgres
```

### Infrastructure Health Checks
```bash
# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes

# Check AWS Load Balancer Controller
kubectl get deployment aws-load-balancer-controller -n kube-system

# Check storage
kubectl get pvc
kubectl get storageclass
```

### Troubleshooting Commands
```bash
# Describe resources for detailed information
kubectl describe pod <pod-name>
kubectl describe service <service-name>
kubectl describe ingress <ingress-name>

# Check recent events
kubectl get events --sort-by=.metadata.creationTimestamp

# Port forward for local testing
kubectl port-forward service/betechnet-frontend 3000:3000
kubectl port-forward service/betechnet-backend 8080:8080
```

## 🧹 Cleanup Procedures

### Docker Compose Cleanup
```bash
docker-compose down -v
docker system prune -a
```

### EKS Cleanup (eksctl method)
```bash
# Delete applications
kubectl delete -f manifests/ingress.yaml
kubectl delete -f manifests/frontend-deployment.yaml
kubectl delete -f manifests/backend-deployment.yaml
kubectl delete -f manifests/postgres-deployment.yaml
kubectl delete -f manifests/secrets.yaml
kubectl delete -f persistent-volume-claim/manifests/

# Delete cluster
eksctl delete cluster --name betech-eks-cluster --region us-west-2
```

### EKS Cleanup (Terraform method)
```bash
cd eks-deployment/
./deploy.sh destroy
# OR
terraform destroy
```

## 📊 Resource Requirements

### Local Development
- **CPU**: 2 cores minimum
- **RAM**: 4GB minimum
- **Storage**: 5GB available space
- **Network**: Internet connection for image pulls

### EKS Deployment
- **AWS Account**: With appropriate permissions
- **EKS Cluster**: t3.medium nodes (minimum)
- **Storage**: 20GB EBS volumes per node
- **Network**: VPC with public/private subnets
- **Cost**: ~$75-150/month (depending on usage)

## 🔐 Security Considerations

### Local Development
- Use non-production credentials
- Keep containers updated
- Isolate development environment

### EKS Production
- Use IAM roles with least privilege
- Enable VPC Flow Logs
- Configure pod security policies
- Use secrets for sensitive data
- Enable container image scanning
- Implement network policies

## 📈 Scaling Considerations

### Horizontal Scaling
```bash
# Scale deployments
kubectl scale deployment betechnet-frontend --replicas=3
kubectl scale deployment betechnet-backend --replicas=2

# Enable auto-scaling
kubectl autoscale deployment betechnet-frontend --cpu-percent=50 --min=1 --max=10
```

### Cluster Scaling
```bash
# For eksctl-managed clusters
eksctl scale nodegroup --cluster=betech-eks-cluster --nodes=3 --name=betech-node-group

# For Terraform-managed clusters
# Update terraform.tfvars and apply
```

## 📞 Support and Documentation

### Additional Resources
- [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md) - Detailed project structure
- [EKS-DEPLOYMENT-README.md](EKS-DEPLOYMENT-README.md) - EKS-specific documentation
- [eks-deployment/README.md](eks-deployment/README.md) - Terraform documentation

### Common Issues
1. **AWS Permissions**: Ensure proper IAM permissions
2. **Resource Limits**: Check AWS service quotas
3. **Network Issues**: Verify VPC and subnet configuration
4. **Storage Issues**: Check EBS volume availability
5. **Image Pull Issues**: Verify ECR permissions

### Getting Help
- Check application logs with `kubectl logs`
- Review AWS CloudWatch for infrastructure logs
- Validate configurations with provided scripts
- Consult AWS EKS documentation for cluster issues

This guide provides multiple deployment paths to suit different use cases, from local development to production-ready EKS clusters.
