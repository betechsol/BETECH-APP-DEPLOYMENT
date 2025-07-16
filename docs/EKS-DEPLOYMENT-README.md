# BETECH EKS Deployment Guide

This guide provides instructions for deploying the BETECH application on Amazon EKS with Application Load Balancer (ALB) support.

## Prerequisites

1. **AWS CLI** - Configure with your AWS credentials
2. **eksctl** - EKS cluster management tool
3. **kubectl** - Kubernetes command-line tool
4. **Docker** - For building container images
5. **Helm** (optional) - For AWS Load Balancer Controller installation

### Installation Commands

```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm (optional)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Architecture Overview

The deployment consists of:

- **EKS Cluster** with worker nodes in private subnets
- **Application Load Balancer (ALB)** for external traffic
- **React Frontend** - Served via ALB
- **Spring Boot Backend** - API endpoints via ALB
- **PostgreSQL Database** - With persistent storage using EBS volumes
- **ECR Repositories** - For container images

## Configuration Files

### Core Kubernetes Manifests

- `manifests/eks-cluster-config.yaml` - EKS cluster configuration
- `manifests/aws-load-balancer-controller.yaml` - ALB controller deployment
- `manifests/frontend-deployment.yaml` - React frontend deployment
- `manifests/backend-deployment.yaml` - Spring Boot backend deployment
- `manifests/postgres-deployment.yaml` - PostgreSQL database deployment
- `manifests/ingress.yaml` - ALB ingress configuration
- `manifests/secrets.yaml` - Database credentials
- `persistent-volume-claim/manifests/` - Storage configuration

### Terraform Infrastructure

- `eks-deployment/` - Complete Terraform infrastructure setup
  - `main.tf` - Main configuration
  - `vpc.tf` - VPC and networking
  - `eks.tf` - EKS cluster
  - `iam.tf` - IAM roles and policies
  - `helm.tf` - Helm charts
  - `outputs.tf` - Output values

### Account-Specific Configuration

- **AWS Account ID**: 374965156099
- **Region**: us-west-2
- **ECR Registry**: 374965156099.dkr.ecr.us-west-2.amazonaws.com

## Deployment Steps

### 1. Quick Deployment (Automated)

```bash
# Make the script executable
chmod +x deploy-eks.sh

# Run the deployment script
./deploy-eks.sh
```

### 2. Manual Deployment

#### Step 1: Create EKS Cluster

```bash
eksctl create cluster -f manifests/eks-cluster-config.yaml
```

#### Step 2: Install AWS Load Balancer Controller

```bash
# Create IAM service account
eksctl create iamserviceaccount \
  --cluster=betech-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve \
  --region=us-west-2

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=betech-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### Step 3: Build and Push Docker Images

```bash
# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 374965156099.dkr.ecr.us-west-2.amazonaws.com

# Create ECR repositories
aws ecr create-repository --repository-name betech-frontend --region us-west-2
aws ecr create-repository --repository-name betech-backend --region us-west-2
aws ecr create-repository --repository-name betech-postgres --region us-west-2

# Build and push images
cd betech-login-frontend
docker build -t betech-frontend:latest .
docker tag betech-frontend:latest 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-frontend:latest
docker push 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-frontend:latest

cd ../betech-login-backend
docker build -t betech-backend:latest .
docker tag betech-backend:latest 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-backend:latest
docker push 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-backend:latest

cd ../betech-postgresql-db
docker build -t betech-postgres:latest .
docker tag betech-postgres:latest 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-postgres:latest
docker push 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-postgres:latest
```

#### Step 4: Deploy Storage Components

```bash
kubectl apply -f persistent-volume-claim/manifests/storageclass.yaml
kubectl apply -f persistent-volume-claim/manifests/pvc.yaml
```

#### Step 5: Deploy Application

```bash
# Deploy secrets
kubectl apply -f manifests/secrets.yaml

# Deploy PostgreSQL
kubectl apply -f manifests/postgres-deployment.yaml
kubectl wait --for=condition=available --timeout=300s deployment/betechnet-postgres

# Deploy backend
kubectl apply -f manifests/backend-deployment.yaml
kubectl wait --for=condition=available --timeout=300s deployment/betechnet-backend

# Deploy frontend
kubectl apply -f manifests/frontend-deployment.yaml
kubectl wait --for=condition=available --timeout=300s deployment/betechnet-frontend

# Deploy ingress
kubectl apply -f manifests/ingress.yaml
```

## Post-Deployment Configuration

### 1. Get ALB URL

```bash
kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 2. Configure DNS

Update your DNS records to point `betech-app.example.com` to the ALB URL.

### 3. SSL Certificate

Update the certificate ARN in `ingress.yaml`:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:374965156099:certificate/YOUR_CERTIFICATE_ID
```

## Monitoring and Troubleshooting

### Check Pod Status

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Check Services

```bash
kubectl get services
kubectl describe service <service-name>
```

### Check Ingress

```bash
kubectl get ingress
kubectl describe ingress betechnet-ingress
```

### Check ALB Controller

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## Scaling

### Horizontal Pod Autoscaler

```bash
kubectl autoscale deployment betechnet-frontend --cpu-percent=50 --min=1 --max=10
kubectl autoscale deployment betechnet-backend --cpu-percent=50 --min=1 --max=10
```

### Cluster Autoscaler

The cluster is configured with autoscaling enabled. Nodes will be added/removed based on demand.

## Security Considerations

1. **Network Policies** - Implement network policies to restrict pod-to-pod communication
2. **RBAC** - Use Role-Based Access Control for fine-grained permissions
3. **Secrets Management** - Consider using AWS Secrets Manager or External Secrets Operator
4. **Pod Security Standards** - Implement pod security policies

## Cleanup

To delete the entire deployment:

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

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS EKS documentation
3. Check ALB controller logs
4. Verify IAM roles and policies

## Cost Optimization

1. Use spot instances for non-critical workloads
2. Right-size your instances based on actual usage
3. Enable cluster autoscaler to scale down unused nodes
4. Use EBS gp3 volumes for better cost/performance ratio
