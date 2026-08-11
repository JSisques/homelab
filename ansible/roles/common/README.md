# Common Ansible Role

The `common` role provides the base configuration shared by all homelab hosts.

It is designed to be applied to every LXC container and VM managed by Ansible.

The role contains only generic operating system configuration. Service-specific configuration belongs to dedicated roles.

## Responsibilities

The `common` role is responsible for:

- Updating the APT package cache
- Upgrading installed packages
- Installing common system utilities
- Configuring the system timezone
- Configuring the hostname when required
- Creating common directories
- Applying basic system configuration

The role does **not** install:

- Docker
- Kubernetes
- Node Exporter
- Prometheus
- Grafana
- Application-specific software

Those components are managed by dedicated roles.

## Directory Structure

```text id="zr45ml"
ansible/roles/common/
├── README.md
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
└── tasks/
    └── main.yml
```

## Variables

Default variables are defined in:

```text id="9b4k7f"
ansible/roles/common/defaults/main.yml
```

Example:

```yaml id="6n9g2t"
common_timezone: Europe/Madrid

common_packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - jq
  - unzip
  - ca-certificates
```

Variables should have the `common_` prefix to avoid conflicts with other roles.

## System Updates

The role updates the APT package cache:

```yaml id="n7c9o1"
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600
```

It can also upgrade installed packages:

```yaml id="2w3qxa"
- name: Upgrade packages
  ansible.builtin.apt:
    upgrade: dist
```

This ensures newly created LXC containers start from an up-to-date base system.

## Common Packages

The role installs a small set of utilities that are useful across the homelab.

Typical packages include:

```text id="6r8qxs"
curl
wget
git
vim
htop
jq
unzip
ca-certificates
```

The package list should remain intentionally small.

Application-specific dependencies must be installed by the corresponding application role.

## Timezone

The homelab uses:

```text id="0e0z6p"
Europe/Madrid
```

The timezone should be configurable through:

```text id="2x0q1m"
common_timezone
```

This ensures scheduled jobs and logs use a consistent timezone across the infrastructure.

## Idempotency

The role must be idempotent.

Running:

```bash id="z2xj8a"
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/site.yml
```

multiple times should not produce unnecessary changes.

An already configured host should remain unchanged unless its desired configuration differs.

## Usage

The role is normally applied to all managed hosts through:

```text id="5slq3e"
ansible/playbooks/site.yml
```

Example:

```yaml id="w7y0e5"
---
- name: Configure all homelab hosts
  hosts: all
  become: true

  roles:
    - common
```

This means every host in the Ansible inventory receives the base configuration.

## Relationship With Other Roles

The `common` role provides the foundation for other roles.

For example:

```text id="h9r7pd"
                    common
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     node-exporter   docker       k3s
          │            │            │
          ▼            ▼            ▼
       metrics      containers   Kubernetes
```

For an application host:

```text id="5q1z9b"
common
  │
  ├── node-exporter
  ├── docker
  └── n8n
```

For a monitoring host:

```text id="z8j6qk"
common
  │
  ├── node-exporter
  ├── docker
  └── grafana
```

For a Kubernetes node:

```text id="3w4v8d"
common
  │
  ├── node-exporter
  └── k3s
```

## What Does Not Belong Here

Avoid turning `common` into a catch-all role.

The following should have dedicated roles:

```text id="0e1q5x"
Docker          → roles/docker/
Node Exporter   → roles/node-exporter/
K3s             → roles/k3s/
Grafana         → roles/grafana/
n8n             → roles/n8n/
Homepage        → roles/homepage/
IT-Tools        → roles/it-tools/
Prometheus      → roles/prometheus/
```

This keeps the Ansible architecture modular and easier to maintain.

## Deployment Flow

A newly created LXC follows this process:

```text id="s4m8yk"
Terraform
    │
    ▼
Proxmox
    │
    ▼
New LXC
    │
    ▼
Ansible
    │
    ▼
common role
    │
    ├── apt update
    ├── apt upgrade
    ├── install common packages
    └── configure timezone
    │
    ▼
Service-specific roles
```

For example, a new n8n LXC:

```text id="v5k7p2"
Terraform
    │
    ▼
LXC n8n
    │
    ▼
common
    │
    ▼
node-exporter
    │
    ▼
docker
    │
    ▼
n8n
    │
    ▼
Docker Compose
    │
    ├── n8n
    └── PostgreSQL
```

## Design Principles

### Minimal

The role should only contain configuration that makes sense for every host.

### Reusable

The same role must work for:

- LXC containers
- Virtual machines
- Monitoring hosts
- Application hosts
- Kubernetes nodes

### Idempotent

Repeated executions must be safe.

### Declarative

The desired system state should be represented in Ansible rather than through manual SSH commands.

### Separation of Concerns

Infrastructure, base operating system configuration, monitoring and applications are managed independently.

```text
Terraform
    ↓
Infrastructure

common
    ↓
Operating system

node-exporter
    ↓
Host metrics

docker
    ↓
Container runtime

application roles
    ↓
Applications
```

## Source of Truth

The Ansible repository is the source of truth for base host configuration.

Terraform remains the source of truth for infrastructure.

Service-specific application configuration remains under:

```text
services/
```

This separation allows the entire homelab to be rebuilt from the repository without relying on manual configuration.
