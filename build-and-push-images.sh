#!/bin/bash

# Build and push BETECH application Docker images to ECR
set -e

REGION="us-west-2"
ACCOUNT_ID="374965156099"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "🔧 Building and pushing BETECH application images to ECR..."
echo "📍 Region: $REGION"
echo "🏪 Registry: $REGISTRY"
echo ""

# Login to ECR
echo "🔑 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY

echo ""
echo "🏗️  Building and pushing images..."

# Build and push backend image
echo "📦 Building backend image..."
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/betech-login-backend
docker build -t betech-backend .
docker tag betech-backend:latest ${REGISTRY}/betech-backend:latest

echo "📤 Pushing backend image..."
docker push ${REGISTRY}/betech-backend:latest

# Build and push frontend image
echo "📦 Building frontend image..."
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/betech-login-frontend
docker build -t betech-frontend .
docker tag betech-frontend:latest ${REGISTRY}/betech-frontend:latest

echo "📤 Pushing frontend image..."
docker push ${REGISTRY}/betech-frontend:latest

# Build and push postgres image
echo "📦 Building postgres image..."
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/betech-postgresql-db
docker build -t betech-postgres .
docker tag betech-postgres:latest ${REGISTRY}/betech-postgres:latest

echo "📤 Pushing postgres image..."
docker push ${REGISTRY}/betech-postgres:latest

echo ""
echo "✅ All images built and pushed successfully!"
echo ""
echo "🔍 Verifying images in ECR..."
echo "Backend images:"
aws ecr list-images --repository-name betech-backend --region $REGION --query 'imageIds[*].imageTag' --output table

echo "Frontend images:"
aws ecr list-images --repository-name betech-frontend --region $REGION --query 'imageIds[*].imageTag' --output table

echo "Postgres images:"
aws ecr list-images --repository-name betech-postgres --region $REGION --query 'imageIds[*].imageTag' --output table

echo ""
echo "🎉 Image build and push completed!"
echo ""
echo "📝 Next steps:"
echo "   1. Run: ./deploy-application.sh"
echo "   2. Wait for pods to start successfully"
echo "   3. Check ingress for Load Balancer URL"
