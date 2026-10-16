# Paperless Application

The Paperless application is a document management system that allows users to digitize and organize their documents efficiently. It is deployed in the production environment using Kubernetes manifests.

## Deployment Instructions

1. **Run the setup scripts**:
   Before deploying the secrets, ensure that you run the necessary setup scripts in the [./scripts](scripts) directory to configure the environment and populate the required external secret stores.

   Make the script executable:

   ```shell
   chmod +x scripts/create-paperless-secrets.sh
   ```

   Export values for `DB_PASS`, `DB_USER` and `SECRET_KEY`

   Run the script `./create-paperless-secrets.sh`

2. **Deploy the application**:
   Apply the Kubernetes manifests in the following order:
   - Secrets
   - Persistent Volume Claims (PVCs)
   - StatefulSets and Deployments
   - Services
   - Ingress

This ensures that all dependencies are correctly initialized before the application starts.


## Storage and placement

Paperless runs on `hp635`. Its media and application data use NFS on
`192.168.100.2`, at `/mnt/HDD/k8s-nfs/paperless/media` and
`/mnt/HDD/k8s-nfs/paperless/data`, through `paperless-media-nfs` and
`paperless-data-nfs`. PostgreSQL remains on its existing local volume on hp635.
Redis remains on media-center.

The deployment uses Recreate to prevent concurrent application instances writing
to the shared data directory, and pins the image digest used during migration.
Its CPU request is 50m to fit hp635 scheduling capacity; the CPU limit is 1500m.

The 2026-10-16 migration verified SHA-256 checksums for 41 media files and 97
application data files. The original `paperless-media` and `paperless-data` local
claims remain intact as pre-cutover recovery copies. Earlier NAS contents were
preserved under `.pre-20261016-cutover` in each destination directory. A database
dump, checksum manifests, and the prior deployment are stored locally under
`.local-backups/paperless-20261016/` and must not be committed.

Both nodes lack the X86_V2 CPU features required by the pinned image's NumPy
build. Relocation does not resolve automatic classification failures.

For rollback, first stop Paperless and preserve any post-cutover uploads and
metadata changes. Reconcile current NFS contents back to local storage before
restoring the old local claims and media-center placement; the original local
files are a snapshot, not an automatically updated replica.
