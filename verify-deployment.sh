#!/bin/bash

# BETECH EKS Deployment Verification Script
echo "======================================"
echo "BETECH EKS DEPLOYMENT VERIFICATION"
echo "======================================"
echo "Date: $(date)"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}1. CHECKING CLUSTER CONNECTIVITY${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Cluster connectivity: OK${NC}"
else
    echo -e "${RED}❌ Cluster connectivity: FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. CHECKING PERSISTENT VOLUME CLAIM${NC}"
PVC_STATUS=$(kubectl get pvc postgres-pvc -o jsonpath='{.status.phase}' 2>/dev/null)
PVC_STORAGE_CLASS=$(kubectl get pvc postgres-pvc -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
PVC_SIZE=$(kubectl get pvc postgres-pvc -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)

if [ "$PVC_STATUS" = "Bound" ]; then
    echo -e "${GREEN}✅ PVC Status: $PVC_STATUS${NC}"
    echo -e "${GREEN}✅ Storage Class: $PVC_STORAGE_CLASS${NC}"
    echo -e "${GREEN}✅ Storage Size: $PVC_SIZE${NC}"
else
    echo -e "${RED}❌ PVC Status: $PVC_STATUS${NC}"
fi

echo ""
echo -e "${YELLOW}3. CHECKING STORAGE CLASS AVAILABILITY${NC}"
if kubectl get storageclass gp2 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Storage Class 'gp2': Available${NC}"
else
    echo -e "${RED}❌ Storage Class 'gp2': Not found${NC}"
fi

if kubectl get storageclass betech-storage-class >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Storage Class 'betech-storage-class': Available${NC}"
else
    echo -e "${YELLOW}⚠️  Storage Class 'betech-storage-class': Not found${NC}"
fi

echo ""
echo -e "${YELLOW}4. CHECKING APPLICATION PODS${NC}"
kubectl get pods --no-headers | while read pod ready status restarts age; do
    if [ "$status" = "Running" ]; then
        echo -e "${GREEN}✅ $pod: $status${NC}"
    else
        echo -e "${RED}❌ $pod: $status${NC}"
    fi
done

echo ""
echo -e "${YELLOW}5. CHECKING SERVICES${NC}"
kubectl get services --no-headers | grep betechnet | while read service type cluster_ip external_ip ports age; do
    echo -e "${GREEN}✅ $service: $type ($cluster_ip:${ports%/*})${NC}"
done

echo ""
echo -e "${YELLOW}6. CHECKING INGRESS${NC}"
INGRESS_ADDRESS=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$INGRESS_ADDRESS" ]; then
    echo -e "${GREEN}✅ Ingress ALB: $INGRESS_ADDRESS${NC}"
else
    echo -e "${RED}❌ Ingress ALB: Not available${NC}"
fi

echo ""
echo -e "${YELLOW}7. CHECKING EXTERNAL ACCESS${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://betech-app.betechsol.com/ || echo "FAILED")
if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Frontend HTTPS: $HTTP_STATUS${NC}"
else
    echo -e "${RED}❌ Frontend HTTPS: $HTTP_STATUS${NC}"
fi

API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://betech-app.betechsol.com/api/test || echo "FAILED")
if [ "$API_STATUS" = "404" ]; then
    echo -e "${GREEN}✅ Backend API HTTPS: $API_STATUS (expected)${NC}"
else
    echo -e "${YELLOW}⚠️  Backend API HTTPS: $API_STATUS${NC}"
fi

echo ""
echo -e "${YELLOW}8. CONFIGURATION FILE CONSISTENCY CHECK${NC}"

# Check PVC file storage class
PVC_FILE_STORAGE_CLASS=$(grep "storageClassName:" /home/ubuntu/BETECH-APP-DEPLOYMENT/persistent-volume-claim/manifests/pvc.yaml | awk '{print $2}')
if [ "$PVC_FILE_STORAGE_CLASS" = "$PVC_STORAGE_CLASS" ]; then
    echo -e "${GREEN}✅ PVC file storage class matches cluster: $PVC_FILE_STORAGE_CLASS${NC}"
else
    echo -e "${RED}❌ PVC file storage class mismatch: file=$PVC_FILE_STORAGE_CLASS, cluster=$PVC_STORAGE_CLASS${NC}"
fi

# Check postgres deployment PVC reference
POSTGRES_CLAIM_NAME=$(kubectl get deployment betechnet-postgres -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null)
if [ "$POSTGRES_CLAIM_NAME" = "postgres-pvc" ]; then
    echo -e "${GREEN}✅ Postgres deployment PVC reference: $POSTGRES_CLAIM_NAME${NC}"
else
    echo -e "${RED}❌ Postgres deployment PVC reference: $POSTGRES_CLAIM_NAME${NC}"
fi

echo ""
echo -e "${YELLOW}9. MANIFEST FILES STATUS${NC}"
for file in /home/ubuntu/BETECH-APP-DEPLOYMENT/manifests/*.yaml; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $(basename $file): Present${NC}"
    else
        echo -e "${RED}❌ $(basename $file): Missing${NC}"
    fi
done

echo ""
echo "======================================"
echo -e "${GREEN}VERIFICATION COMPLETE${NC}"
echo "======================================"
echo ""
echo "For future deployments, ensure:"
echo "1. EKS cluster is accessible"
echo "2. Storage class 'gp2' is available"
echo "3. All manifest files are present"
echo "4. PVC configuration matches cluster state"
echo ""
echo "To redeploy the application:"
echo "kubectl apply -f /home/ubuntu/BETECH-APP-DEPLOYMENT/manifests/"
echo ""
