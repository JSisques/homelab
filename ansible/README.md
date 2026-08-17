# Ansible

This directory configures every LXC/VM host and deploys the application running on it, using Docker Compose files from `services/` as the single source of truth (except for the handful of roles — `pbs`, `promtail`, `k3s` — that install a native package instead of a container).

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
│   ├── it-tools.yaml  n8n.yaml  monitoring.yaml  homepage.yaml
│   ├── uptime-kuma.yaml  cloudflared.yaml
│   ├── adguard-home-1.yaml  adguard-home-2.yaml  adguard-home-sync.yaml
│   ├── wireguard.yaml  pbs.yaml  k3s-server.yaml
│   └── promtail.yaml      # promtail alone, against every host
└── roles/
    ├── common/  node-exporter/  promtail/  docker/    # mandatory baseline
    └── it-tools/  n8n/  monitoring/  homepage/  uptime-kuma/
        cloudflared/  adguard-home/  adguard-home-sync/  wireguard/  pbs/  k3s/
```

## Mandatory Baseline: Every Host Gets Node Exporter + Promtail

Every LXC/VM must be monitored (metrics) and shipping its logs. This is not opt-in per role — it's enforced structurally: every service role declares `common`, `node-exporter`, `promtail`, and (if it runs containers) `docker` as **role dependencies** in its own `meta/main.yml`:

```yaml
# roles/<service>/meta/main.yml
dependencies:
  - role: common
  - role: node-exporter
  - role: promtail
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

Ansible resolves `it-tools`'s dependencies first, so the actual run order is `common → node-exporter → promtail → docker → it-tools` — automatically, every time, regardless of whether the playbook is run on its own or as part of `site.yaml`. Verified with `ansible-playbook --list-tasks` for every role in this repo. There is no way to deploy a service without also getting metrics and logs.

**When adding a new role**, give it the same `meta/main.yml`. If the host doesn't run Docker — `pbs` and `k3s` are the current examples, both native installs rather than containers — drop the `docker` dependency but keep `common`, `node-exporter`, and `promtail`.

`promtail` itself only depends on `common` (an empty dependency chain would work too, but the base packages don't hurt). It's installed as a native systemd service via Grafana's APT repo rather than Docker specifically so it also works on `pbs`, which has no Docker at all. Don't add `promtail` to `promtail`'s own dependencies — an earlier version of this repo did, and Ansible ran `common`'s tasks twice per host because of it (role dependency de-duplication doesn't reach across nested dependency chains the way you'd expect). If you ever see a role's tasks listed twice in `--list-tasks`, that's the symptom to look for.

## Inventory

`inventory/hosts.yml` is **generated** from `config/hosts.yaml` — the single source of truth for hostnames, addresses, and roles (see `config/README.md`). Regenerate it with:

```bash
./scripts/generation/generate-inventory.sh
# or: make inventory
```

Never edit `inventory/hosts.yml` by hand; the change will be overwritten and CI checks that it stays in sync with `config/hosts.yaml`.

`inventory/group_vars/all.yml` defines `repo_root` and `services_dir`, computed from the inventory file's own location — every role's `tasks/main.yaml` uses `services_dir` to copy its Compose file straight from `services/<name>/`, so application configuration is never duplicated between `services/` and `ansible/roles/`.

## Secrets

No secret is ever committed. Roles that need one read it from a variable with an empty/placeholder default and either fail loudly or ship an insecure default that must be overridden:

| Role | Variable | Behavior if unset |
| --- | --- | --- |
| `n8n` | `n8n_postgres_password` | Deploys anyway with `changeme` |
| `cookidoo-mcp` | `cookidoo_mcp_email` / `cookidoo_mcp_password` | Refuses to run (`assert`) |
| `cloudflared` | `cloudflared_credentials_json` | Refuses to run (`assert`) |
| `monitoring` | `monitoring_alertmanager_telegram_bot_token` / `_chat_id` | Deploys anyway; alerts fire into a `null` receiver |

Provide real values via Ansible Vault, or as `-e`/`--extra-vars` from CI secrets — see each role's README.

From a control machine, the root `Makefile` builds those `-e`/`--extra-vars` flags from your shell environment (see `ANSIBLE_EXTRA_VARS`). Rather than `export`ing each one by hand every session, copy `.env.example` (repo root) to `.env` — gitignored, never commit the real one — and fill in what you need; `make deploy`/`make deploy-<service>` source it automatically if it exists.

## Running

Prefer the root `Makefile` (`make deploy`, `make deploy-<service>`, `make ping`, ...). Run Ansible directly when you need more control:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml   # once

ansible-playbook -i inventory/hosts.yml playbooks/site.yaml \
  -e "n8n_postgres_password=${N8N_POSTGRES_PASSWORD}" \
  -e "cookidoo_mcp_email=${COOKIDOO_MCP_EMAIL}" \
  -e "cookidoo_mcp_password=${COOKIDOO_MCP_PASSWORD}" \
  -e "cloudflared_credentials_json=${CLOUDFLARED_CREDS_JSON}" \
  -e "monitoring_alertmanager_telegram_bot_token=${TELEGRAM_BOT_TOKEN}" \
  -e "monitoring_alertmanager_telegram_chat_id=${TELEGRAM_CHAT_ID}"

# or a single service:
ansible-playbook -i inventory/hosts.yml playbooks/it-tools.yaml
```
