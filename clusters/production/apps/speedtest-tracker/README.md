# Speedtest Tracker (production)

URL: https://speedtest.ndlovucloud.co.zw

Runs one LinuxServer Speedtest Tracker container with SQLite stored in a 1Gi
`local-path` PVC at `/config`. Updates use `Recreate` to avoid concurrent database
writers. The data stays on the provisioned node; back up `/config` before replacing
that node or deleting the PVC. Tests run every six hours, with Africa/Harare as
the container and display timezone. Tests measure the cluster's internet connection
and consume bandwidth. No CPU limit is imposed to avoid throttling measurements.

## Before deployment

Create a SecureString parameter in AWS SSM Parameter Store, region `eu-west-1`:

`/K8s/Clusters/Prod/SpeedtestTracker/credentials`

Its JSON value must contain:

```json
{
  "APP_KEY": "base64:<base64-encoded 32 random bytes>",
  "ADMIN_EMAIL": "<your admin email>",
  "ADMIN_PASSWORD": "<a strong unique password>"
}
```

Generate the APP_KEY with `openssl rand -base64 32` and prefix it with `base64:`.
Keep the key stable and back it up with the database. Store credentials only in
Parameter Store, never in this repository. Ensure the cluster's Parameter Store
credentials can read the new path (and decrypt it if using a custom KMS key).
The ExternalSecret requires all three properties, so the container waits for
custom admin credentials instead of bootstrapping with the default password.
ADMIN_EMAIL and ADMIN_PASSWORD are used only when the database is first created;
later account changes must be made in the application.

Add a DNS record for `speedtest.ndlovucloud.co.zw` pointing to the same ingress
endpoint as the other prod applications. The certificate uses the existing
`cloudflare-letsencrypt-prod` ClusterIssuer; DNS routing is managed separately.

## Deploy and verify

The existing Flux `flux-system` Kustomization recursively includes manifests
under `clusters/production`. No new source or Flux Kustomization is required.
Commit and push this app directory to `main`, then run:

```sh
flux reconcile kustomization flux-system --with-source --context homelab-prod
kubectl --context homelab-prod -n default get externalsecret speedtest-tracker-env
kubectl --context homelab-prod -n default get pvc speedtest-tracker-config
kubectl --context homelab-prod -n default rollout status deployment/speedtest-tracker
kubectl --context homelab-prod -n default get certificate speedtest-tracker-tls
```

Log in using the admin credentials from Parameter Store and run a manual test
to verify connectivity to Ookla. Homepage discovers the ingress automatically.

Official references:

- [Container configuration](https://docs.linuxserver.io/images/docker-speedtest-tracker/)
- [Application environment variables](https://docs.speedtest-tracker.dev/getting-started/environment-variables)

## Homepage results widget

The discovered ingress card displays the latest download speed, upload speed,
and ping using widget version 2. Homepage connects through the internal Kubernetes
Service. Its deployment is pinned to v1.2.0 for authenticated API support and
allows the host `homepage.ndlovucloud.co.zw`.

Create a read-only API token in Speedtest Tracker and store the token itself
(plain text, not JSON) in a separate SSM SecureString parameter:

`/K8s/Clusters/Prod/SpeedtestTracker/homepage-api-token`

For example, with your AWS profile configured, run this in Bash or Zsh:

```sh
(
  set -e
  umask 077
  token_file=$(mktemp)
  trap 'rm -f "$token_file"' EXIT
  python3 - "$token_file" <<'PY'
import getpass
import sys
token = getpass.getpass("Speedtest Tracker read-only API token: ").strip()
if not token:
    raise SystemExit("Token is required.")
with open(sys.argv[1], "w") as f:
    f.write(token)
PY
  aws ssm put-parameter \
    --region eu-west-1 \
    --name /K8s/Clusters/Prod/SpeedtestTracker/homepage-api-token \
    --type SecureString \
    --value "file://$token_file"
)
```

After Flux has applied the manifests, refresh the ExternalSecret and wait for it
to synchronize before restarting Homepage to load the token:

```sh
kubectl --context homelab-prod -n default annotate externalsecret homepage-speedtest-env \
  force-sync="$(date +%s)" --overwrite
kubectl --context homelab-prod -n default wait \
  --for=condition=Ready externalsecret/homepage-speedtest-env --timeout=120s
kubectl --context homelab-prod -n default rollout restart deployment/homepage
kubectl --context homelab-prod -n default rollout status deployment/homepage
```

The token secret is optional for pod startup, allowing Homepage to remain
available before the token exists. The widget needs a valid token and at least
one completed speed test. Restart Homepage after token rotation as well.

- [Homepage Speedtest Tracker widget](https://gethomepage.dev/widgets/services/speedtest-tracker/)
