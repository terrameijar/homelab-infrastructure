#!/bin/bash
# create-paperless-secrets.sh
# This script creates Paperless secrets in AWS SSM Parameter Store for use with ExternalSecret.

set -e

# Set your values here or export them as environment variables before running the script
DB_USER=${DB_USER:-paperless}
DB_PASS=${DB_PASS:-changeme}
SECRET_KEY=${SECRET_KEY:-$(openssl rand -hex 32)}

# Create the db-creds parameter as a JSON object
echo "Creating db-creds"

aws ssm put-parameter \
  --name "/K8s/Clusters/Prod/Paperless/db-creds" \
  --type "SecureString" \
  --value "{\"db_user\": \"$DB_USER\", \"db_pass\": \"$DB_PASS\"}"

echo "Creating secret key"
# Create the secret-key parameter
aws ssm put-parameter \
  --name "/K8s/Clusters/Prod/Paperless/secret-key" \
  --type "SecureString" \
  --value "{\"secret_key\": \"$SECRET_KEY\"}"

echo "Secrets created in AWS SSM Parameter Store."
