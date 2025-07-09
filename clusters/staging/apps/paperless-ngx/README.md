# Paperless Application

The Paperless application is a document management system that allows users to digitize and organize their documents efficiently. It is deployed in the staging environment using Kubernetes manifests.

## Deployment Instructions

1. **Run the setup scripts**:
   Before deploying the secrets, ensure that you run the necessary setup scripts in the [./scripts](scripts) directory to configure the environment and populate the required external secret stores.

2. **Deploy the application**:
   Apply the Kubernetes manifests in the following order:
   - Secrets
   - Persistent Volume Claims (PVCs)
   - StatefulSets and Deployments
   - Services
   - Ingress

This ensures that all dependencies are correctly initialized before the application starts.
