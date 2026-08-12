# Supabase Ansible Role

This Ansible role prepares an LXC container, mounts its NFS-backed persistent storage, and deploys the self-hosted Supabase stack using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation (via the `docker` role dependency)
- NFS client installation and mounting the NAS export at `/mnt/nas/supabase`
- Supabase application directory creation
- Environment/secrets configuration
- Deploying the vendored Compose stack and its supporting config (`volumes/`)
- Service startup and updates

Terraform is responsible for creating the LXC container.

Ansible is responsible for configuring the LXC and deploying Supabase.

## Directory Structure

```text
ansible/roles/supabase/
├── README.md
├── defaults/
│   └── main.yaml
├── meta/
│   └── main.yml
├── tasks/
│   └── main.yaml
└── templates/
    └── env.j2
```

## Service Definition

The Docker Compose definition and vendored Supabase configuration are maintained in:

```text
services/supabase/compose.yaml
services/supabase/volumes/
```

The Ansible role deploys both to the Supabase LXC, under:

```text
/opt/supabase/
├── compose.yaml
├── volumes/
└── .env
```

The `.env` file is rendered from `templates/env.j2` and must not be committed to Git.

## Persistent Storage

Before deploying the application, this role mounts the NAS NFS export:

```text
{{ supabase_nas_export }}  →  {{ supabase_nas_mount_path }}
```

and creates three subdirectories under it — `db/` (PGDATA), `db-config/` (pgsodium's key), and `storage/` (Storage bucket files) — which `services/supabase/compose.yaml` bind-mounts directly. See `services/supabase/README.md` "Persistence" for why Postgres data lives on NFS here and what that tradeoff implies.

## Variables

Role defaults are defined in `defaults/main.yaml`. It covers three groups of variables:

1. **Mount configuration** — `supabase_nas_export`, `supabase_nas_mount_path`, `supabase_app_dir`.
2. **Secrets** — `supabase_postgres_password`, `supabase_jwt_secret`, `supabase_anon_key`, `supabase_service_role_key`, `supabase_dashboard_password`, `supabase_secret_key_base`, `supabase_realtime_db_enc_key`, `supabase_vault_enc_key`, `supabase_pg_meta_crypto_key`, `supabase_logflare_public_access_token`, `supabase_logflare_private_access_token`, `supabase_s3_protocol_access_key_id`, `supabase_s3_protocol_access_key_secret`. Every one of these defaults to `"changeme"` and **must** be overridden via Ansible Vault before deploying for real. Generate all of them at once:

   ```bash
   cd services/supabase
   sh utils/generate-keys.sh
   ```

   then copy the printed values into a vaulted `group_vars`/`host_vars` file, e.g.:

   ```yaml
   supabase_postgres_password: "{{ vault_supabase_postgres_password }}"
   ```

3. **Application configuration** — URLs, Postgres/pooler settings, Studio branding, Auth behavior, Storage/Functions/PostgREST settings. These are not secret and have sensible defaults already set; override only if the deployment's needs differ (e.g. a real SMTP provider, see `services/supabase/README.md` "Email (Auth)").

Every variable maps 1:1 to an environment variable Supabase's Compose stack expects — see `services/supabase/.env.example` for the authoritative list and `templates/env.j2` for how they're rendered into `.env`.

## Deployment

The role is normally executed through:

```text
ansible/playbooks/supabase.yaml
```

```yaml
---
- name: Deploy Supabase
  hosts: supabase
  become: true

  roles:
    - supabase
```

Run the playbook with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/supabase.yaml
```

or via the root `Makefile`:

```bash
make deploy-supabase
```

## Deployment Flow

```text
Terraform
    │
    ▼
LXC supabase
    │
    ▼
Ansible
    │
    ▼
supabase role
    │
    ├── Install Docker
    ├── Mount NAS export at /mnt/nas/supabase
    ├── Create db/, db-config/, storage/ subdirectories
    ├── Create /opt/supabase
    ├── Render .env from Vault-backed secrets
    ├── Deploy compose.yaml + volumes/
    └── Start containers (see services/supabase/README.md "Architecture")
```

## Idempotency

The role should be safe to run repeatedly. Re-running the playbook after only changing a non-secret setting in `defaults/main.yaml` (or a real secret in Vault) updates `.env` and recreates only the containers that read the changed value on `docker compose up`.

## Updates

Updating Supabase is a two-step change, since this role deploys a vendored copy of upstream's Compose stack:

1. Refresh `services/supabase/compose.yaml` and `services/supabase/volumes/` from upstream (see `services/supabase/README.md` "Upstream").
2. Re-run this role — it copies the refreshed files to `/opt/supabase/` and restarts the stack.

Avoid manually updating containers inside the LXC because those changes would not be represented in Git.

## Monitoring

The Supabase host should be monitored through the homelab observability stack (Node Exporter → Prometheus → Grafana) and Uptime Kuma, same as every other role. See `services/supabase/README.md` "Monitoring" for Supabase's own log explorer (Logflare + Vector).

## Related Components

### Terraform

```text
terraform/proxmox/lxc.tf
```

Terraform creates the `supabase` LXC (sizing in `config/hosts.yaml`).

### Service Configuration

```text
services/supabase/
├── README.md
├── compose.yaml
├── .env.example
├── utils/generate-keys.sh
└── volumes/
```

### Inventory

```yaml
supabase:
  hosts:
    supabase:
      ansible_host: 192.168.1.36
```

Generated from `config/hosts.yaml` by `scripts/generation/generate-inventory.sh`.

## Design Principles

Same as every other role in this repo (see `ansible/roles/n8n/README.md` for the fuller writeup): Terraform creates infrastructure, Ansible configures the host and injects secrets, `services/supabase/` defines the application, and nothing here should be hand-edited on the running LXC — every change flows through Git.
