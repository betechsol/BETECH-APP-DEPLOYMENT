#!/bin/bash

set -e

# BETECH Application-Only Deployment Script
# Use this when EKS infrastructure is already deployed

echo "=============================================="
echo "🚀 BETECH APPLICATION DEPLOYMENT SCRIPT"
echo "=============================================="
echo "Generated: $(date)"
echo ""

# Configuration
CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "UNKNOWN")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📋 Configuration:"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Update kubeconfig
echo "🔑 Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Check cluster connectivity
echo "🧪 Testing cluster connectivity..."
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "❌ Cannot connect to cluster. Please check:"
    echo "   - AWS credentials are configured"
    echo "   - Cluster exists and is accessible"
    echo "   - Region is correct"
    exit 1
fi
echo "✅ Cluster is accessible"

# Clean up any existing deployments
echo ""
echo "🧹 Cleaning up existing deployments..."
kubectl delete deployment betechnet-backend betechnet-frontend betechnet-postgres --ignore-not-found=true
kubectl delete pvc postgres-pvc --ignore-not-found=true
kubectl delete ingress betechnet-ingress --ignore-not-found=true

# Build and push images
echo ""
echo "🐳 Building and pushing Docker images..."
cd "$SCRIPT_DIR"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build backend
echo "🔨 Building backend..."
cd betech-login-backend
docker build -t betech-backend .
docker tag betech-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest

# Build frontend
echo "🔨 Building frontend..."
cd ../betech-login-frontend
docker build -t betech-frontend .
docker tag betech-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest

# Build postgres
echo "🔨 Building postgres..."
cd ../betech-postgresql-db
docker build -t betech-postgres .
docker tag betech-postgres:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest

cd "$SCRIPT_DIR"

# Deploy PostgreSQL with emptyDir (stable solution)
echo ""
echo "🗄️  Deploying PostgreSQL..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: betechnet-postgres
  labels:
    app: betechnet-postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: betechnet-postgres
  template:
    metadata:
      labels:
        app: betechnet-postgres
    spec:
      containers:
      - name: betechnet-postgres
        image: $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "betech_db"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          value: "admin123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "1Gi"
            cpu: "500m"
            ephemeral-storage: "2Gi"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: betechnet-postgres
spec:
  selector:
    app: betechnet-postgres
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
  type: ClusterIP
EOF

# Wait for postgres to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/betechnet-postgres

# Deploy application manifests (clean versions)
echo ""
echo "📄 Deploying application manifests..."

# Deploy secrets first
kubectl apply -f manifests/secrets.yaml

# Deploy backend
kubectl apply -f manifests/backend-deployment.yaml

# Deploy frontend  
kubectl apply -f manifests/frontend-deployment.yaml

# Wait for application deployments
echo "⏳ Waiting for application deployments..."
kubectl wait --for=condition=available --timeout=600s deployment/betechnet-backend
kubectl wait --for=condition=available --timeout=600s deployment/betechnet-frontend

# Deploy ingress with correct configuration
echo ""
echo "🌐 Deploying ingress..."
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: betechnet-ingress
  annotations:
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:$REGION:$AWS_ACCOUNT_ID:certificate/d8a6af47-551b-493e-a375-6134a905fcf2
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/success-codes: 200,404
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
spec:
  ingressClassName: alb
  rules:
  - host: betech-app.betechsol.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: betechnet-frontend
            port:
              number: 3000
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: betechnet-backend
            port:
              number: 8080
EOF

# Final status check
echo ""
echo "📊 Final deployment status:"
echo ""
echo "Pods:"
kubectl get pods -n default
echo ""
echo "Services:"
kubectl get svc -n default
echo ""
echo "Ingress:"
kubectl get ingress -n default

echo ""
echo "🎉 Application deployment completed successfully!"
echo ""
echo "🧪 Testing commands:"
echo "  Frontend: kubectl port-forward svc/betechnet-frontend 3000:3000"
echo "  Backend:  kubectl port-forward svc/betechnet-backend 8080:8080"
echo "  Monitor ALB: kubectl describe ingress betechnet-ingress"
echo ""
echo "⚠️  Notes:"
echo "  - ALB provisioning may take 5-10 minutes"
echo "  - PostgreSQL data won't persist across pod restarts (emptyDir)"
echo "  - Update DNS when ALB address is available"
