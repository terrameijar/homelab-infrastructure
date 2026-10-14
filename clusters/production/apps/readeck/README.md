# Readeck

Readeck runs alongside Wallabag at `https://readeck.ndlovucloud.co.zw`.
Production Flux discovers these manifests under `clusters/production`.

## Storage

All four claims use the existing `nfs` storage class, backed by
`192.168.100.2:/mnt/HDD/k8s-nfs`:

| Claim | Size | Contents |
| --- | --- | --- |
| readeck-config-nfs | 1Gi | Generated configuration and persistent application secret key |
| readeck-data | 5Gi | Saved article content and resources |
| readeck-postgres | 2Gi | Dedicated PostgreSQL database |
| readeck-redis | 1Gi | Background task data and progress, with Redis append-only logging |

Readeck uses PostgreSQL rather than SQLite because SQLite on NFS is
[explicitly unsupported](https://readeck.org/en/docs/configuration).
All deployments use one replica and `Recreate` to avoid concurrent writers
during updates. NFS-backed PostgreSQL requires reliable server-side locking,
fsync, and durable writes; confirm these settings on the NAS. NFS availability
is required for the application to run.

The Redis worker backend persists task data and import progress outside the
application process. Scheduling still happens inside Readeck, so interrupted
imports can require cleanup and re-import; avoid redeploying during a bulk
import. Redis append-only logging syncs every second. The generated NFS `config.toml` has
`[extractor] workers = 4` to process imported articles concurrently.

The NFS provisioner retains PVs when claims are deleted. Storage sizes are
claims, not enforced directory quotas. Back up the PostgreSQL database with
`pg_dump` and the configuration and article directories together; quiesce
Readeck during the backup for consistency. A live copy of PostgreSQL's data
directory alone is not a consistent database backup. Preserve `config.toml`
and its generated secret key when restoring.

## Secrets and account

The ExternalSecret reads the SecureString JSON parameter
`/K8s/Clusters/Prod/Readeck/credentials` in AWS SSM, region `eu-west-1`.
It contains `POSTGRES_PASSWORD`, `READECK_DATABASE_SOURCE`, and the generated
initial `ADMIN_PASSWORD`. No credential values are stored in Git.

The initial account is `wallabag`. Retrieve its password privately:

```sh
aws ssm get-parameter \
  --name /K8s/Clusters/Prod/Readeck/credentials \
  --region eu-west-1 --with-decryption \
  --query Parameter.Value --output text | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["ADMIN_PASSWORD"])'
```

Changing the SSM `ADMIN_PASSWORD` does not change an existing Readeck account's
password. Change it through Readeck's profile or `readeck user` instead.
Changing the PostgreSQL password also requires changing the database role;
the image's `POSTGRES_PASSWORD` only initializes a new database.

## Access

The ingress uses the existing nginx controller and Cloudflare DNS-01 issuer.
For LAN access, resolve `readeck.ndlovucloud.co.zw` to `192.168.100.11` in your
local DNS or hosts file. A certificate does not create an application DNS record.

The proxied CNAME points to Wallabag's existing Cloudflare Tunnel.
For remote access, add a Cloudflare Tunnel public hostname:

- Hostname: `readeck.ndlovucloud.co.zw`
- Origin service: `https://192.168.100.11:443`
- Origin server name and HTTP Host header: `readeck.ndlovucloud.co.zw`

Use the same tunnel as Wallabag. Keep origin certificate verification enabled.
The existing cert-manager Cloudflare token can edit DNS but cannot edit tunnel
configuration. Disable Cloudflare Rocket Loader for Readeck, as required by
its [deployment documentation](https://readeck.org/en/docs/deploy).

## Wallabag migration

Wallabag remains deployed for comparison. The source account `wallabag` had
88 entries at setup time. Its official `wallabag:export` command provides a
read-only JSON snapshot containing saved HTML, tags, dates, favorite status,
and archive status.

Readeck's native Wallabag importer consumes the Wallabag API, not this JSON
export directly. For the initial migration, the snapshot was served through
a temporary private API bridge and passed to this native importer. Export tag
strings were converted to objects with a `label` property. The bridge
and its temporary credentials were removed after import. The native importer preserves saved
text and metadata, but may fetch external images again. It does not migrate
Wallabag annotations; the initial export contained none.

All 88 article URLs, creation dates, labels, favorite states, and archive states
matched the export after import: 52 archived articles, 3 favorites, and 189
label assignments. The original JSON export is retained privately at
`/readeck/migration/wallabag-export-2026-10-14.json` on `readeck-config-nfs`,
with its SHA-256 checked against the source.

For future imports directly from Wallabag, create an API client in Wallabag's
API clients page, then choose Wallabag in Readeck's import page. Supply your
Wallabag username/password and the client ID/secret. Use the internal URL
`http://wallabag.default.svc.cluster.local:8083` to avoid the existing Wallabag
ingress port mismatch. Enable duplicate skipping when repeating an import.

Before replacing Wallabag, compare article counts, labels, archive/favorite
states, and a sample of saved texts and images. Keep Wallabag and its database
until you are satisfied with the migration and have a tested backup.
