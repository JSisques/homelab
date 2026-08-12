# SonarQube Ansible Role

This Ansible role prepares an LXC container and deploys SonarQube (Community Build) using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation
- Docker Compose installation
- The `vm.max_map_count` kernel setting Elasticsearch (bundled inside SonarQube) requires
- SonarQube application directory creation
- PostgreSQL configuration
- Docker Compose deployment
- Environment configuration
- Service startup and updates

Terraform is responsible for creating the LXC container.

Ansible is responsible for configuring the LXC and deploying SonarQube.

## Directory Structure

```text
ansible/roles/sonarqube/
├── README.md
├── defaults/
│   └── main.yaml
├── meta/
│   └── main.yml
├── templates/
│   └── env.j2
└── tasks/
    └── main.yaml
```

## Service Definition

The Docker Compose definition is maintained in:

```text
services/sonarqube/compose.yaml
```

The Ansible role deploys this configuration to the SonarQube LXC.

The service should be deployed under:

```text
/opt/sonarqube/
```

with:

```text
/opt/sonarqube/
├── compose.yaml
└── .env
```

The `.env` file contains deployment-specific secrets and must not be committed to Git.

## Variables

Role defaults are defined in `defaults/main.yaml`:

```yaml
sonarqube_app_dir: /opt/sonarqube

sonarqube_postgres_db: sonarqube
sonarqube_postgres_user: sonarqube
sonarqube_db_password: changeme # override via Vault/CI secrets

sonarqube_vm_max_map_count: 524288
```

The hostname and application port are defined directly in `services/sonarqube/compose.yaml` (the single source of truth for the application configuration) rather than templated, since they don't vary between environments.

Secrets should not be stored directly in `defaults/main.yaml`.

Sensitive values should be supplied through Ansible Vault or another secret management mechanism (see `SONARQUBE_DB_PASSWORD` in `.github/workflows/deploy.yaml`).

## Kernel Requirement: `vm.max_map_count`

Elasticsearch (bundled inside the SonarQube image) requires `vm.max_map_count >= 524288`. This is a **host-wide** kernel setting, not namespaced per-container, so it can't be set through Docker Compose.

The role attempts to set it from inside the LXC via `ansible.posix.sysctl`. This can fail on an unprivileged LXC, since writing certain `vm.*` sysctls from inside an unprivileged container is often blocked at the kernel/namespace level. If it fails, the role logs a warning rather than failing the whole play — the fallback is setting it once, manually, on the Proxmox host itself:

- Per-container: add `lxc.sysctl.vm.max_map_count = 524288` to the container's config on the PVE host, or
- Host-wide: `vm.max_map_count = 524288` in `/etc/sysctl.d/` on the PVE host (LXC containers share the host kernel, so this covers every container on it).

## Deployment

The role is normally executed through:

```text
ansible/playbooks/sonarqube.yaml
```

```yaml
---
- name: Deploy SonarQube
  hosts: sonarqube
  become: true

  roles:
    - sonarqube
```

Run the playbook with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/sonarqube.yaml \
  -e "sonarqube_db_password=${SONARQUBE_DB_PASSWORD}"
```

or `make deploy-sonarqube` from the repository root.

## Deployment Flow

```text
Terraform
    │
    ▼
LXC sonarqube
    │
    ▼
Ansible
    │
    ├── Install Docker
    ├── Set vm.max_map_count
    ├── Create /opt/sonarqube
    ├── Deploy compose.yaml
    ├── Configure secrets
    └── Start containers
            │
            ├── SonarQube
            └── PostgreSQL
```

## Idempotency

The role should be safe to run repeatedly. Running the playbook again should only modify the host when the desired configuration differs from the current state.

## Updates

Updating SonarQube should be performed by changing the image tag in `services/sonarqube/compose.yaml` (e.g. pinning `sonarqube:community` to a specific digest), then running the Ansible deployment again. Avoid manually updating containers inside the LXC because those changes would not be represented in Git.

## Monitoring

The SonarQube host should be monitored through the homelab observability stack (Node Exporter → Prometheus → Grafana). Service availability is monitored with Uptime Kuma and `blackbox_exporter`, since Community Build has no native `/metrics` endpoint.

The service is expected to be available at:

```text
https://sonarqube.home.arpa
https://sonarqube.jsisques.net
```

## Related Components

### Terraform

Infrastructure:

```text
terraform/proxmox/lxc.tf
```

Terraform creates the sonarqube LXC.

### Service Configuration

Application configuration:

```text
services/sonarqube/
```

### Inventory

The sonarqube host is defined in the Ansible inventory (generated from `config/hosts.yaml`):

```text
ansible/inventory/hosts.yml
```

## Design Principles

Same as every other role in this repo: Terraform creates the infrastructure, Ansible configures the host, `services/sonarqube/` defines the application, secrets stay outside Git, and a new SonarQube LXC should be deployable from scratch without manual configuration beyond the documented `vm.max_map_count` fallback above.
