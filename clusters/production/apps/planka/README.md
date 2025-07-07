# Planka

Planka is a self-hosted Trello alternative.

## Set up Instructions

- Generate and export a secret key

```shell
export SECRETKEY=$(openssl rand -hex 64)
```

### Create `secretkey` secret in secure vault

- Create an AWS SSM secret for the environment you're deploying to, e.g `Prod`

```shell
aws ssm put-parameter --name "/K8s/Clusters/Prod/Planka/planka-secretkey" \
--type "SecureString" \
--value "{\"SECRET_KEY\": \"$SECRETKEY\"}"
```

### Update Helm values

- Create or modify the `planka-externalsecret.yaml` referencing the SSM secret you just created
- Update the `planka-helmrelease.yaml` file with the appropriate domain name for the environment you're deploying to.
- Create external secrets for the Planka Postgresql user

```shell
export planka_db_username="planka"
export planka_db_password=$(openssl rand -base64 16)
export planka_db_name="planka"
```

**Create secret in AWS SSM**

```shell
aws ssm put-parameter --name "/K8s/Clusters/Prod/Planka/planka-postgres" \
\ --type "SecureString" \
\ --value "{\"username\": \"$planka_db_username\", \"password\": \"$planka_db_password\", \"database\": \"$planka_db_name\"}"
```

1. Update the postgres section in `planka-helmrelease.yaml` to reference the postgres SSM secret.
