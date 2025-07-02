# Persistent Volume Claim and Storage Class Documentation

This project contains Kubernetes manifests for creating a Persistent Volume Claim (PVC) and a Storage Class in your cluster.

## Manifests

1. **pvc.yaml**: This file defines the Persistent Volume Claim. It specifies the desired storage size, access modes, and the storage class to be used.

2. **storageclass.yaml**: This file defines the Storage Class that will be used by the PVC. It includes parameters for provisioning the storage, such as the type of storage backend and reclaim policy.

## Usage Instructions

To apply the manifests and create the Persistent Volume Claim and Storage Class in your Kubernetes cluster, follow these steps:

1. Ensure you have access to your Kubernetes cluster and have `kubectl` installed.

2. Navigate to the directory containing the manifests:

   ```bash
   cd persistent-volume-claim/manifests
   ```

3. Apply the Storage Class manifest:

   ```bash
   kubectl apply -f storageclass.yaml
   ```

4. Apply the Persistent Volume Claim manifest:

   ```bash
   kubectl apply -f pvc.yaml
   ```

5. Verify that the Persistent Volume Claim has been created successfully:

   ```bash
   kubectl get pvc
   ```

This will show the status of your PVC and confirm that it is bound to a Persistent Volume.