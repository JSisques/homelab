# Ansible

This directory configures every LXC-based host and deploys the application running on it, using Docker Compose files from `services/` as the single source of truth.

## Directory Structure

```text
ansible/
├── README.md
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── hosts.yml        # generated, do not edit — see below
│   └── group_vars/
│       └── all.yml       # repo_root / services_dir, used by every role
├── playbooks/
│   ├── site.yaml          # everything, in order
│   ├── it-tools.yaml  n8n.yaml  monitoring.yaml
│   └── homepage.yaml  uptime-kuma.yaml  cloudflared.yaml
└── roles/
    ├── common/  node-exporter/  docker/    # mandatory baseline
    └── it-tools/  n8n/  monitoring/  homepage/  uptime-kuma/  cloudflared/
```

## Mandatory Baseline: Every Host Gets Node Exporter

Every LXC (and, once provisioned, every VM) must be monitored. This is not opt-in per role — it's enforced structurally: every service role declares `common`, `node-exporter`, and `docker` as **role dependencies** in its own `meta/main.yml`:

```yaml
# roles/<service>/meta/main.yml
dependencies:
  - role: common
  - role: node-exporter
  - role: docker
```

Because of this, playbooks only need to list the service role itself:

```yaml
---
- name: Deploy IT-Tools
  hosts: it-tools
  become: true

  roles:
    - it-tools
```

Ansible resolves `it-tools`'s dependencies first, so the actual run order is `common → node-exporter → docker → it-tools` — automatically, every time, regardless of whether the playbook is run on its own or as part of `site.yaml`. There is no way to deploy a service without also getting Node Exporter.

**When adding a new role**, give it the same `meta/main.yml`. If a future host type doesn't run Docker (e.g. a plain VM), drop the `docker` dependency but keep `common` and `node-exporter`.

## Inventory

`inventory/hosts.yml` is **generated** from `config/hosts.yaml` — the single source of truth for hostnames, addresses, and roles (see `config/README.md`). Regenerate it with:

```bash
./scripts/generation/generate-inventory.sh
# or: make inventory
```

Never edit `inventory/hosts.yml` by hand; the change will be overwritten and CI checks that it stays in sync with `config/hosts.yaml`.

`inventory/group_vars/all.yml` defines `repo_root` and `services_dir`, computed from the inventory file's own location — every role's `tasks/main.yaml` uses `services_dir` to copy its Compose file straight from `services/<name>/`, so application configuration is never duplicated between `services/` and `ansible/roles/`.

## Secrets

No secret is ever committed. Roles that need one (`n8n`, `cloudflared`) read it from a variable with an empty/placeholder default and either fail (`cloudflared`, via an explicit `assert`) or ship an insecure default that must be overridden (`n8n`). Provide real values via Ansible Vault, or as `-e`/`--extra-vars` from CI secrets — see `ansible/roles/n8n/README.md` and `ansible/roles/cloudflared/README.md`.

## Running

Prefer the root `Makefile` (`make deploy`, `make deploy-<service>`, `make ping`, ...). Run Ansible directly when you need more control:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml   # once

ansible-playbook -i inventory/hosts.yml playbooks/site.yaml \
  -e "n8n_postgres_password=${N8N_POSTGRES_PASSWORD}" \
  -e "cloudflared_credentials_json=${CLOUDFLARED_CREDS_JSON}"

# or a single service:
ansible-playbook -i inventory/hosts.yml playbooks/it-tools.yaml
```
