# cookidoo-mcp Ansible Role

This Ansible role prepares an LXC container and deploys the cookidoo-mcp MCP server using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation (via the `docker` role dependency)
- cookidoo-mcp application directory creation
- Cookidoo credential injection
- Docker Compose deployment
- Service startup and updates

Terraform is responsible for creating the LXC container.

Ansible is responsible for configuring the LXC and deploying cookidoo-mcp.

## Directory Structure

```text
ansible/roles/cookidoo-mcp/
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
services/cookidoo-mcp/compose.yml
```

The Ansible role deploys this configuration to the cookidoo-mcp LXC, under:

```text
/opt/cookidoo-mcp/
├── compose.yml
└── .env
```

The `.env` file contains the Cookidoo credentials and must not be committed to Git.

## Variables

Role defaults are defined in `defaults/main.yaml`:

```yaml
cookidoo_mcp_app_dir: /opt/cookidoo-mcp

cookidoo_mcp_email: ""
cookidoo_mcp_password: ""
```

Non-secret application configuration (localization, `PORT`, `OTEL_EXPORTER_OTLP_ENDPOINT`, ...) is defined directly in `services/cookidoo-mcp/compose.yml` rather than templated, since it doesn't vary between environments — same convention as `n8n`.

## Secrets

`cookidoo_mcp_email` and `cookidoo_mcp_password` are required. Unlike `n8n_postgres_password` (which has a working-but-insecure `changeme` default), there is no sane default for real Cookidoo account credentials — the role fails loudly via `ansible.builtin.assert` if either is empty, the same approach used by the `cloudflared` role.

Provide real values through:

1. Ansible Vault
2. `-e`/`--extra-vars` from CI secrets

```yaml
cookidoo_mcp_email: "{{ vault_cookidoo_mcp_email }}"
cookidoo_mcp_password: "{{ vault_cookidoo_mcp_password }}"
```

## Deployment

The role is normally executed through:

```text
ansible/playbooks/cookidoo-mcp.yaml
```

```yaml
---
- name: Deploy cookidoo-mcp
  hosts: cookidoo-mcp
  become: true

  roles:
    - cookidoo-mcp
```

Run it with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/cookidoo-mcp.yaml \
  -e "cookidoo_mcp_email=${COOKIDOO_MCP_EMAIL}" \
  -e "cookidoo_mcp_password=${COOKIDOO_MCP_PASSWORD}"
```

or, from the repo root:

```bash
make deploy-cookidoo-mcp
```

## Idempotency

The role should be safe to run repeatedly. Running it again should only modify the host when the desired configuration differs from the current state.

## Updates

Updating cookidoo-mcp is done by changing the image tag in `services/cookidoo-mcp/compose.yml` (e.g. `sisqueslabs/cookidoo-mcp:0.4.0`), then running the Ansible deployment again. Avoid manually updating the container inside the LXC — those changes would not be represented in Git.

## Monitoring

- Availability: Uptime Kuma, HTTP monitor against `GET https://cookidoo-mcp.home.arpa/api/health` (see `services/cookidoo-mcp/README.md` for why the root path can't be used).
- Traces/metrics/logs: pushed via OTLP to the homelab OTel Collector — see `services/otel-collector/`.
- Host-level: Node Exporter + Promtail, applied automatically via this role's `meta/main.yml` dependencies.

## Related Components

### Terraform

```text
terraform/proxmox/lxc.tf
```

Terraform creates the cookidoo-mcp LXC, sized from `config/hosts.yaml`.

### Service Configuration

```text
services/cookidoo-mcp/
├── README.md
├── compose.yml
└── .env.example
```

### Inventory

The cookidoo-mcp host is generated into the Ansible inventory from `config/hosts.yaml` — see `ansible/README.md`.

## Design Principles

Same as every other role in this repository: Terraform creates infrastructure, Ansible configures the host, `services/cookidoo-mcp/` defines the application, secrets stay outside Git, and a new cookidoo-mcp LXC should be deployable from scratch using Terraform and Ansible without manual configuration.
