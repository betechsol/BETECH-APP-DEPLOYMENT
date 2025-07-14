# BETECH Application - Quick Access Commands

## 🚀 Application Access

### Method 1: Port Forwarding (Recommended for Testing)
```bash
# Access Frontend (React App)
kubectl port-forward svc/betechnet-frontend 3000:3000
# Then open: http://localhost:3000

# Access Backend API  
kubectl port-forward svc/betechnet-backend 8080:8080
# Then access: http://localhost:8080

# Access Database (if needed)
kubectl port-forward svc/betechnet-postgres-temp 5432:5432
# Connect via: postgresql://admin:admin123@localhost:5432/betech_db
```

### Method 2: NodePort (External Access)
```bash
# Create NodePort services for external access
kubectl patch svc betechnet-frontend -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc betechnet-backend -p '{"spec":{"type":"NodePort"}}'

# Get NodePort numbers
kubectl get svc

# Access via worker node IPs:
# Frontend: http://<node-ip>:<frontend-nodeport>
# Backend: http://<node-ip>:<backend-nodeport>
```

## 📊 Monitoring Commands

### Check Application Status
```bash
# Overall pod status
kubectl get pods

# Check specific application logs
kubectl logs deployment/betechnet-frontend
kubectl logs deployment/betechnet-backend  
kubectl logs deployment/betechnet-postgres-temp

# Check service endpoints
kubectl get endpoints
```

### Resource Utilization
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage  
kubectl top pods

# Describe any failing components
kubectl describe pod <pod-name>
```

## 🔧 Troubleshooting Commands

### Backend Issues
```bash
# Check backend connectivity to database
kubectl exec -it deployment/betechnet-backend -- curl -v http://betechnet-postgres-temp:5432

# View detailed backend logs
kubectl logs deployment/betechnet-backend --tail=100 -f
```

### Database Issues
```bash
# Connect to PostgreSQL directly
kubectl exec -it deployment/betechnet-postgres-temp -- psql -U admin -d betech_db

# Check database processes
kubectl exec -it deployment/betechnet-postgres-temp -- ps aux
```

### Network Issues
```bash
# Test internal connectivity
kubectl run test-pod --image=busybox --rm -it -- sh
# Inside pod: wget -qO- http://betechnet-frontend:3000
# Inside pod: wget -qO- http://betechnet-backend:8080
```

## 🔄 Application Management

### Scale Application
```bash
# Scale frontend
kubectl scale deployment betechnet-frontend --replicas=5

# Scale backend  
kubectl scale deployment betechnet-backend --replicas=5

# Check scaling status
kubectl get deployments
```

### Update Application
```bash
# Update with new image version
kubectl set image deployment/betechnet-backend betechnet-backend=374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-backend:v2.0

# Roll back if needed
kubectl rollout undo deployment/betechnet-backend

# Check rollout status
kubectl rollout status deployment/betechnet-backend
```

### Configuration Management
```bash
# Update environment variables
kubectl set env deployment/betechnet-backend NEW_VAR=value

# View current configuration
kubectl describe deployment betechnet-backend
```

## 🗄️ Database Management

### Backup Database (Temporary Solution)
```bash
# Create database dump
kubectl exec deployment/betechnet-postgres-temp -- pg_dump -U admin betech_db > backup.sql

# Restore database (if needed)
kubectl exec -i deployment/betechnet-postgres-temp -- psql -U admin betech_db < backup.sql
```

### Connect to Database
```bash
# Interactive PostgreSQL session
kubectl exec -it deployment/betechnet-postgres-temp -- psql -U admin -d betech_db

# Run specific query
kubectl exec deployment/betechnet-postgres-temp -- psql -U admin -d betech_db -c "SELECT version();"
```

## 📋 Cluster Management

### EKS Cluster Info
```bash
# Cluster details
aws eks describe-cluster --name betech-eks-cluster --region us-west-2

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name betech-eks-cluster

# Node information
kubectl get nodes -o wide
```

### Resource Cleanup (If Needed)
```bash
# Delete application (keep cluster)
kubectl delete -f /home/ubuntu/BETECH-APP-DEPLOYMENT/manifests/

# Delete temporary postgres
kubectl delete -f /home/ubuntu/BETECH-APP-DEPLOYMENT/postgres-temp-deployment.yaml

# Delete entire cluster (destructive!)
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment
terraform destroy
```

## 🔍 Validation & Testing

### Quick Health Check
```bash
# Run validation script
cd /home/ubuntu/BETECH-APP-DEPLOYMENT
./validate-deployment.sh
```

### Application Testing
```bash
# Test frontend (via port-forward)
kubectl port-forward svc/betechnet-frontend 3000:3000 &
curl -I http://localhost:3000

# Test backend API (via port-forward)  
kubectl port-forward svc/betechnet-backend 8080:8080 &
curl -I http://localhost:8080

# Kill port-forward processes
pkill -f "port-forward"
```

## 🎯 Current Application URLs

**Note**: External ALB is not available due to IAM OIDC issue. Use port-forwarding or NodePort for access.

- **Frontend**: Available via port-forward to 3000
- **Backend API**: Available via port-forward to 8080  
- **Database**: PostgreSQL on port 5432 (internal only)
- **Configured Domain**: betech-app.example.com (ALB pending)

## 📞 Support Information

**Deployment Location**: `/home/ubuntu/BETECH-APP-DEPLOYMENT/`  
**Container Registry**: 374965156099.dkr.ecr.us-west-2.amazonaws.com  
**Cluster Name**: betech-eks-cluster  
**Region**: us-west-2  
**Account**: 374965156099
