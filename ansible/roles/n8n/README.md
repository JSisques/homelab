# n8n Ansible Role

This Ansible role prepares an LXC container and deploys the n8n workflow automation platform using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation
- Docker Compose installation
- n8n application directory creation
- PostgreSQL configuration
- Docker Compose deployment
- Environment configuration
- Service startup and updates

Terraform is responsible for creating the LXC container.

Ansible is responsible for configuring the LXC and deploying n8n.

## Directory Structure

```text
ansible/roles/n8n/
├── README.md
├── defaults/
│   └── main.yml
└── tasks/
    └── main.yml
```

The role can be extended later with:

```text
ansible/roles/n8n/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   └── docker.yml
├── templates/
│   └── env.j2
├── handlers/
│   └── main.yml
└── README.md
```

## Service Definition

The Docker Compose definition is maintained in:

```text
services/n8n/compose.yml
```

The Ansible role deploys this configuration to the n8n LXC.

The service should be deployed under:

```text
/opt/n8n/
```

with:

```text
/opt/n8n/
├── compose.yml
└── .env
```

The `.env` file contains deployment-specific secrets and must not be committed to Git.

## Variables

Role defaults should be defined in:

```text
defaults/main.yml
```

Example:

```yaml
n8n_app_dir: /opt/n8n

n8n_postgres_db: n8n
n8n_postgres_user: n8n
n8n_postgres_password: changeme # override via Vault/CI secrets
```

The hostname, protocol, and timezone used by n8n are defined directly in `services/n8n/compose.yml` (the single source of truth for the application configuration) rather than templated, since they don't vary between environments.

Secrets should not be stored directly in `defaults/main.yaml`.

Sensitive values should be supplied through Ansible Vault or another secret management mechanism.

## Deployment

The role is normally executed through:

```text
ansible/playbooks/n8n.yml
```

Example:

```yaml
---
- name: Deploy n8n
  hosts: n8n
  become: true

  roles:
    - n8n
```

Run the playbook with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/n8n.yml
```

## Deployment Flow

```text
Terraform
    │
    ▼
LXC n8n
    │
    ▼
Ansible
    │
    ▼
n8n role
    │
    ├── Install Docker
    ├── Create /opt/n8n
    ├── Deploy compose.yml
    ├── Configure secrets
    └── Start containers
            │
            ├── n8n
            └── PostgreSQL
```

## Docker

The role ensures that Docker and Docker Compose are available on the target LXC before deploying the application.

The role should be idempotent.

Running the role multiple times should not result in unnecessary changes or duplicate containers.

## Configuration

The source Compose configuration is:

```text
services/n8n/compose.yml
```

The role should deploy the repository version to:

```text
/opt/n8n/compose.yml
```

Application-specific configuration should remain in the `services/n8n` directory rather than being duplicated inside the Ansible role.

## Secrets

n8n requires database credentials and may contain sensitive workflow credentials.

Secrets must never be committed to Git.

Preferred options are:

1. Ansible Vault
2. Environment variables supplied by the deployment system
3. External secret management

For example:

```yaml
n8n_postgres_password: "{{ vault_n8n_postgres_password }}"
```

The actual value should be stored in an encrypted Ansible Vault file.

## Idempotency

The role should be safe to run repeatedly.

For example:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/n8n.yml
```

Running the command again should only modify the host when the desired configuration differs from the current state.

## Updates

Updating n8n should be performed by changing the image version in:

```text
services/n8n/compose.yml
```

For example:

```yaml
image: n8nio/n8n:<version>
```

Then run the Ansible deployment again.

Avoid manually updating containers inside the LXC because those changes would not be represented in Git.

## Monitoring

The n8n host should be monitored through the homelab observability stack.

At minimum:

```text
Node Exporter
     │
     ▼
Prometheus
     │
     ▼
Grafana
```

Service availability should be monitored with:

```text
Uptime Kuma
```

The service is expected to be available at:

```text
https://n8n.home.arpa
```

## Related Components

### Terraform

Infrastructure:

```text
terraform/proxmox/lxc.tf
```

Terraform creates the n8n LXC.

### Service Configuration

Application configuration:

```text
services/n8n/
```

Contains:

```text
services/n8n/
├── README.md
├── compose.yml
└── .env.example
```

### Inventory

The n8n host should be defined in the Ansible inventory:

```text
ansible/inventory/hosts.yml
```

Example:

```yaml
n8n:
  hosts:
    n8n:
      ansible_host: 192.168.0.24
```

## Design Principles

### Infrastructure and Configuration Separation

Terraform creates the infrastructure.

Ansible configures the host.

The `services/n8n` directory defines the application.

### Git as Source of Truth

Application configuration should be version-controlled.

Manual changes inside the LXC should be avoided.

### Secrets Outside Git

Credentials and sensitive configuration must never be committed to the repository.

### Reproducibility

A new n8n LXC should be deployable from scratch using Terraform and Ansible without manual configuration.

## Full Deployment Architecture

```text
                    Git Repository
                          │
          ┌───────────────┴────────────────┐
          │                                │
          ▼                                ▼
terraform/proxmox/                   services/n8n/
          │                                │
          ▼                                ▼
      Proxmox LXC                     compose.yml
          │                                │
          └──────────────┬─────────────────┘
                         ▼
                      Ansible
                         │
                         ▼
                    n8n role
                         │
                         ▼
                   Docker Compose
                    ┌────┴────┐
                    ▼         ▼
                   n8n    PostgreSQL
                    │
                    ▼
                 Traefik
                    │
                    ▼
             n8n.home.arpa
```
