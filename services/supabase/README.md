# Supabase

Self-hosted Supabase: a Postgres database plus the Auth, REST, Realtime, Storage, and Edge Functions services built around it, fronted by a single API gateway. It exists to give other homelab services (n8n workflows, future apps on K3s, personal projects) a shared Postgres-backed backend instead of every service bringing its own database.

## Responsibilities

- **db** — Postgres 17, the actual data store. Every other component is a service layered on top of the same database.
- **kong** — API gateway. The single entry point (`:8000`), routes `/auth/v1`, `/rest/v1`, `/realtime/v1`, `/storage/v1`, `/functions/v1` to their backend, and protects the Studio dashboard (`/`) with HTTP basic auth.
- **auth** (GoTrue) — user accounts, JWT issuance, email/phone signup.
- **rest** (PostgREST) — auto-generated REST API over the Postgres schema.
- **realtime** — WebSocket subscriptions to database changes.
- **storage** + **imgproxy** — file/object storage with on-the-fly image transformation. Backed by the `file` backend (a directory on the NAS, not S3).
- **meta** (postgres-meta) — the API Studio uses to introspect/manage the database.
- **functions** (edge-runtime) — Deno-based Edge Functions.
- **supavisor** — Postgres connection pooler. Also the pooled entry point other homelab services should use to reach Postgres directly (see Networking).
- **studio** — the web dashboard, reached through Kong.
- **analytics** (Logflare) + **vector** — collect and index logs from every other container so Studio's log explorer works.

All twelve containers are deployed together as one Docker Compose application inside a dedicated LXC (`supabase`), same pattern as `n8n`, `jellyfin`, and the `downloads` stack (multiple related containers, one LXC).

## Directory Structure

```text
services/supabase/
├── README.md
├── compose.yaml
├── .env.example
├── utils/
│   └── generate-keys.sh
└── volumes/
    ├── api/
    │   ├── kong.yml
    │   └── kong-entrypoint.sh
    ├── db/
    │   ├── _supabase.sql
    │   ├── jwt.sql
    │   ├── logs.sql
    │   ├── pooler.sql
    │   ├── realtime.sql
    │   ├── roles.sql
    │   └── webhooks.sql
    ├── functions/
    │   ├── main/index.ts
    │   └── hello/index.ts
    ├── logs/
    │   └── vector.yml
    └── pooler/
        └── pooler.exs
```

`compose.yaml`, `.env.example`, and everything under `volumes/` are vendored from [`supabase/supabase`](https://github.com/supabase/supabase)'s `docker/` self-hosting reference (see "Upstream" below) and adapted to this repo's conventions. `volumes/db/data`, `volumes/storage`, and `volumes/db-config` are **not** in this directory — those are the actual Postgres data, Storage bucket files, and pgsodium key, and they live on the NAS instead (see Persistence).

## Architecture

```text
                                   supabase LXC
                                        │
                                 Docker Compose
                                        │
        ┌──────────┬──────────┬────────┼────────┬──────────┬───────────┐
        │          │          │        │        │          │           │
      kong        auth      rest   realtime  storage    imgproxy      meta
     :8000       :9999     :3000    :4000     :5000      :5001       :8080
        │
        ├──────────┬───────────┬─────────────┬───────────────┐
        │          │           │             │               │
     studio    functions   supavisor      analytics        vector
     :3000       :9000    :5432/:6543      :4000
                                │
                                ▼
                               db
                             :5432
                                │
                                ▼
                        NAS (NFS, PGDATA)
```

Kong is the only container reachable from outside the compose network via a published port; every other service talks to its peers over the internal Docker network.

## Docker Compose

The service is defined in:

```text
services/supabase/compose.yaml
```

`kong` is Supabase's traditional API gateway rather than the newer default (Envoy). Since Traefik already terminates TLS and does host-based routing at the edge, a static declarative `kong.yml` is simpler to operate here than Envoy's CDS/LDS config templates layered on top of another proxy. See the comment at the top of `compose.yaml`.

## Persistence

The following must survive container restarts and recreation:

| What | Where | Backing |
| ---- | ----- | ------- |
| Postgres data (`PGDATA`) | `/mnt/nas/supabase/db` | NAS, NFS |
| pgsodium's decryption key | `/mnt/nas/supabase/db-config` | NAS, NFS |
| Storage bucket files | `/mnt/nas/supabase/storage` | NAS, NFS |
| Edge Functions' Deno module cache | `deno-cache` Docker volume | LXC local disk (regenerable, not backed up) |

The NAS export is expected at `192.168.0.111:/export/supabase`, mounted at `/mnt/nas/supabase` by the Ansible role (`ansible/roles/supabase/`), same pattern as `services/obsidian/` and `services/jellyfin/`. The export itself must already exist on the NAS before the role runs.

**Postgres data on NFS is a deliberate tradeoff, not the default recommendation.** Running `PGDATA` over NFS depends on the NAS's NFS server correctly supporting POSIX file locking (`flock`/`fcntl`) for `fsync` durability to behave as Postgres expects — most modern NFSv4 servers handle this correctly, but it's a real dependency that local disk doesn't have. This was chosen deliberately to keep all of Supabase's state centralized on the NAS alongside everything else backed up there (PBS's datastore, the Obsidian vault). If Postgres correctness issues ever show up in practice, moving `db`'s and `db-config`'s volumes back to local LXC disk (and keeping only `storage` on NFS, where it doesn't matter) is a one-line change in `compose.yaml`.

## Database

A single Postgres 17 instance (`supabase/postgres`, not stock `postgres`) backs every other service. The init scripts under `volumes/db/*.sql` (vendored from upstream, run once via `docker-entrypoint-initdb.d` on first boot) create the schemas and roles Auth, Realtime, Storage, and the pooler expect (`supabase_auth_admin`, `supabase_storage_admin`, `authenticator`, `_realtime`, `_analytics`, `_supavisor`, etc.) — they should not be edited by hand.

Other homelab services that want their own schema/tables in this Postgres instance connect as the `postgres` superuser (or a role created for them) rather than going through PostgREST.

## Networking

Supabase is exposed through the homelab reverse proxy:

```text
https://supabase.home.arpa
```

which routes to Kong on the `supabase` LXC. Traffic flow:

```text
Client
  │
  ▼
Reverse Proxy (Traefik)
  │
  ▼
supabase LXC : 8000
  │
  ▼
Kong
  │
  ├─→ /auth/v1/*        → auth
  ├─→ /rest/v1/*         → rest
  ├─→ /realtime/v1/*     → realtime
  ├─→ /storage/v1/*      → storage
  ├─→ /functions/v1/*    → functions
  └─→ /* (basic auth)    → studio
```

The Studio dashboard, sitting behind Kong's catch-all route, is protected by HTTP basic auth (`DASHBOARD_USERNAME`/`DASHBOARD_PASSWORD`) on top of whatever access Traefik itself allows — since this is `tier: internal`, that's LAN/VPN only, never a public DNS record or Cloudflare route.

### Direct Postgres access

`supavisor` (the connection pooler) additionally publishes raw Postgres wire-protocol ports directly on the LXC, **not** through Traefik (Traefik only proxies HTTP/HTTPS):

```text
<supabase-lxc-ip>:5432   # session mode pooling
<supabase-lxc-ip>:6543   # transaction mode pooling
```

Other homelab services (e.g. an n8n Postgres node, a future K3s app) that want to use this Supabase instance as a shared backend connect to one of these ports directly over the LAN/VPN, rather than going through the REST API.

## Monitoring

Supabase should be monitored by Uptime Kuma against `https://supabase.home.arpa`. Detailed application logs (across every container) are available inside Studio's own log explorer, powered by the bundled Logflare + Vector.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── supabase.yaml
└── roles/
    └── supabase/
```

The deployment flow is:

```text
Terraform
    │
    ▼
LXC supabase
    │
    ▼
Ansible
    │
    ├── Install Docker
    ├── Mount the NAS NFS export at /mnt/nas/supabase
    ├── Create application directory
    ├── Configure secrets (.env from Vault)
    ├── Copy compose.yaml + volumes/
    └── Start Compose
             │
             ▼
       12 containers (see Architecture)
```

## Local Development

Start the stack locally (e.g. to try a `compose.yaml` change before pushing):

```bash
cd services/supabase

cp .env.example .env
sh utils/generate-keys.sh --update-env   # fills in real secrets

docker compose up -d
```

Studio is then reachable at `http://localhost:8000` (basic auth: `DASHBOARD_USERNAME`/`DASHBOARD_PASSWORD` from `.env`).

View logs:

```bash
docker compose logs -f kong
```

Stop the stack:

```bash
docker compose down
```

## Configuration

Application configuration belongs in:

```text
services/supabase/compose.yaml
services/supabase/volumes/
```

Secrets belong outside Git. The repository contains `.env.example` but must never contain a real `.env`.

## Secrets

This stack needs more secrets than most services in this repo: `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `DASHBOARD_PASSWORD`, `SECRET_KEY_BASE`, `VAULT_ENC_KEY`, `PG_META_CRYPTO_KEY`, `LOGFLARE_PUBLIC_ACCESS_TOKEN`, `LOGFLARE_PRIVATE_ACCESS_TOKEN`, `S3_PROTOCOL_ACCESS_KEY_ID`/`SECRET`. Generate all of them at once with the vendored upstream script:

```bash
cd services/supabase
sh utils/generate-keys.sh
```

This prints `KEY=value` pairs (openssl-based; `ANON_KEY`/`SERVICE_ROLE_KEY` come out as HS256 JWTs signed with the generated `JWT_SECRET`). Store each value in Ansible Vault (`ansible/roles/supabase/defaults/main.yaml` documents the variable names) rather than in a committed `.env`.

The stack runs in **legacy-only mode**: `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `JWT_KEYS`, `JWT_JWKS`, and the `*_ASYMMETRIC` keys are left empty. These are Supabase's newer opaque-API-key / ES256 asymmetric-JWT scheme (see `sh utils/add-new-auth-keys.sh` upstream if that's ever needed) — the legacy HS256 `JWT_SECRET` + static `ANON_KEY`/`SERVICE_ROLE_KEY` pair is simpler to generate and manage by hand and is still fully supported by every component here.

## Email (Auth)

No SMTP provider is configured yet (`SMTP_HOST` is empty in `.env.example`), so `ENABLE_EMAIL_AUTOCONFIRM=true` — new accounts are confirmed immediately instead of waiting on a confirmation email that would never arrive. This is acceptable for an internal-only deployment with a small number of trusted users. If a real SMTP provider is wired in later, flip `ENABLE_EMAIL_AUTOCONFIRM` back to `false` and fill in `SMTP_HOST`/`SMTP_PORT`/`SMTP_USER`/`SMTP_PASS`/`SMTP_ADMIN_EMAIL`/`SMTP_SENDER_NAME` so password recovery and email confirmation work for real.

## Backups

The following must be backed up:

- `/mnt/nas/supabase/db` (PGDATA) — this is the actual data for every project built on top of this instance. A `docker compose exec db pg_dumpall` (or NAS-level snapshotting of the export, same as the rest of the NAS) should be exercised and its restore tested, not just assumed to work.
- `/mnt/nas/supabase/db-config` — losing pgsodium's key makes any data encrypted through Vault/pgsodium unrecoverable even if `PGDATA` itself is intact.
- `/mnt/nas/supabase/storage` — uploaded files.

Since all three already live on the NAS, they're covered by whatever backup strategy applies to the NAS export itself (see `docs/storage.md`), the same as Obsidian's vault and Jellyfin's config volume.

## Security

Supabase should not be directly exposed to the public Internet without a lot more thought than this deployment gives it — it is `tier: internal` (LAN/VPN only) specifically because it now holds credentials, JWTs, and whatever data other services choose to store in it.

```text
Internet
   │
   ✗  (no route — internal tier)
   ▼
Reverse Proxy (Traefik, LAN/VPN only)
   │
   ▼
Kong (basic auth on the dashboard, apikey/JWT on every API route)
```

`DASHBOARD_PASSWORD`, `POSTGRES_PASSWORD`, and every JWT-signing secret must be real generated values (see Secrets), never the placeholders in `.env.example`.

## Upstream

`compose.yaml` and `volumes/` are vendored from [`supabase/supabase`](https://github.com/supabase/supabase)`/docker/` (the `docker-compose.yml` base plus the `kong` and `logs` overlays), with the Envoy gateway swapped for Kong and the `db`/`storage`/`db-config` volumes pointed at the NAS instead of local Docker volumes. To pick up an upstream update:

1. Diff the current `docker/docker-compose.yml`, `docker/docker-compose.kong.yml`, `docker/docker-compose.logs.yml`, and `docker/volumes/` in the upstream repo against what's vendored here.
2. Re-apply this repo's changes on top (Kong instead of Envoy for `api-gw`, the NFS volume paths, `SUPABASE_URL: http://kong:8000` instead of `http://api-gw:8000`).
3. Check `docker/CHANGELOG.md` upstream for breaking changes to secrets or env vars.

## Source of Truth

Terraform manages:

- LXC existence
- CPU
- Memory
- Disk
- Network

Ansible manages:

- Host configuration
- NFS mount
- Docker
- Docker Compose deployment
- Secrets injection

This directory manages:

- Docker Compose configuration
- Supabase application configuration (vendored from upstream + homelab adaptations)
- Service documentation

The goal is for the Supabase deployment to be reproducible from the repository while keeping secrets and persistent application data (Postgres, Storage) outside Git, on the NAS.
