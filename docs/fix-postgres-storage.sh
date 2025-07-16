#!/bin/bash

echo "=== Fixing Postgres Storage Issue ==="

# Delete the existing deployment and PVC that are stuck
echo "Deleting stuck postgres deployment and PVC..."
kubectl delete deployment betechnet-postgres
kubectl delete pvc postgres-pvc

# Create a new postgres deployment with emptyDir volume (for testing)
echo "Creating postgres deployment with emptyDir volume..."
cat <<EOF | kubectl apply -f -
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
        image: 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-postgres:latest
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

echo "Waiting for postgres deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/betechnet-postgres

echo "Postgres deployment status:"
kubectl get pods -l app=betechnet-postgres

echo "=== Postgres storage fix completed ==="
