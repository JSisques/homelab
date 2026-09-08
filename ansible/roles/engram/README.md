# engram Ansible Role

This Ansible role prepares an LXC container and deploys Engram Cloud (`engram cloud serve`) using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation (via the `docker` role dependency)
- engram application directory creation
- Secret injection (Postgres password, `ENGRAM_CLOUD_TOKEN`, `ENGRAM_CLOUD_ADMIN`, `ENGRAM_JWT_SECRET`)
- Docker Compose deployment

Terraform is responsible for creating the LXC container.

Ansible is responsible for configuring the LXC and deploying engram.

## Directory Structure

```text
ansible/roles/engram/
├── README.md
├── meta/
│   └── main.yml
├── defaults/
│   └── main.yaml
├── templates/
│   └── env.j2
└── tasks/
    └── main.yaml
```

## Service Definition

The Docker Compose definition is maintained in:

```text
services/engram/compose.yml
```

The Ansible role deploys this configuration to the engram LXC, under:

```text
/opt/engram/
├── compose.yml
└── .env
```

The `.env` file contains the Postgres and Engram Cloud secrets and must not be committed to Git.

## Variables

Role defaults are defined in `defaults/main.yaml`:

```yaml
engram_app_dir: /opt/engram

engram_image_tag: v2.0.0-rc.8

engram_postgres_db: engram_cloud
engram_postgres_user: engram
engram_postgres_password: changeme

engram_cloud_allowed_projects: "*"

engram_cloud_token: ""
engram_cloud_admin: ""
engram_jwt_secret: ""
```

`engram_image_tag` pins the `ghcr.io/gentleman-programming/engram` image tag — never `:latest`, see `services/engram/README.md#image`.

## Secrets

`engram_cloud_token`, `engram_cloud_admin`, and `engram_jwt_secret` are required, with no sane default — the role fails loudly via `ansible.builtin.assert` if any is empty, if the token and admin secret collide, or if the JWT secret is left at upstream's insecure smoke-test default (`engram-dev-jwt-secret-for-local-smoke-1234`). Same approach as the `cloudflared`/`cookidoo-mcp` roles.

`engram_postgres_password` has a working-but-insecure `changeme` default, same convention as `n8n_postgres_password`.

Provide real values through:

1. Ansible Vault
2. `-e`/`--extra-vars` from CI secrets

```yaml
engram_postgres_password: "{{ vault_engram_postgres_password }}"
engram_cloud_token: "{{ vault_engram_cloud_token }}"
engram_cloud_admin: "{{ vault_engram_cloud_admin }}"
engram_jwt_secret: "{{ vault_engram_jwt_secret }}"
```

## Deployment

The role is normally executed through:

```text
ansible/playbooks/engram.yaml
```

```yaml
---
- name: Deploy engram
  hosts: engram
  become: true

  roles:
    - engram
```

Run it with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/engram.yaml \
  -e "engram_postgres_password=${ENGRAM_POSTGRES_PASSWORD}" \
  -e "engram_cloud_token=${ENGRAM_CLOUD_TOKEN}" \
  -e "engram_cloud_admin=${ENGRAM_CLOUD_ADMIN}" \
  -e "engram_jwt_secret=${ENGRAM_JWT_SECRET}"
```

or, from the repo root:

```bash
make deploy-engram
```

## Idempotency

The role should be safe to run repeatedly. Running it again should only modify the host when the desired configuration differs from the current state.

## Updates

Bump `engram_image_tag` (Vault/CI extra-var, defaulted in `defaults/main.yaml`) after reading the target release's notes, then re-run `make deploy-engram`. Unlike `cookidoo-mcp`/`portfolio`, this image is not ours and does not float on `:latest`, so there is no `pull_policy: always` or prune step here — see `AGENTS.md#self-built-images-own-tools` for why that pattern is reserved for images we build ourselves.

## Monitoring

- Availability: Uptime Kuma, HTTP monitor against `http://192.168.0.221:18080` (see `services/engram/README.md` for why the root path is a known false-negative-risk check, and why no `blackbox:` block is set).
- Host-level: Node Exporter + Promtail, applied automatically via this role's `meta/main.yml` dependencies.

## Related Components

### Terraform

```text
terraform/proxmox/lxc.tf
```

Terraform creates the engram LXC, sized from `config/hosts.yaml`.

### Service Configuration

```text
services/engram/
├── README.md
├── compose.yml
└── .env.example
```

### Inventory

The engram host is generated into the Ansible inventory from `config/hosts.yaml` — see `ansible/README.md`.

## Design Principles

Same as every other role in this repository: Terraform creates infrastructure, Ansible configures the host, `services/engram/` defines the application, secrets stay outside Git, and a new engram LXC should be deployable from scratch using Terraform and Ansible without manual configuration.
