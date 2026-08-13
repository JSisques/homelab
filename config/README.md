# Configuration

This directory contains the central configuration and metadata used by the homelab.

The files in this directory describe the desired state of the homelab at a high level and are consumed by infrastructure, automation, and configuration-generation tools.

## Structure

```text
config/
├── README.md
├── services.yaml
└── hosts.yaml
```

Additional configuration files can be added as the homelab grows.

## Source of Truth

The configuration directory acts as the central source of truth for shared homelab metadata.

```text
                     config/
                        │
             ┌──────────┴──────────┐
             │                     │
        services.yaml          hosts.yaml
             │                     │
     ┌───────┼────────┐            │
     │       │        │            │
     ▼       ▼        ▼            ▼
 Homepage  Prometheus  Uptime   Ansible
                       Kuma
```

The goal is to avoid defining the same information multiple times across different tools.

## `services.yaml`

`services.yaml` contains the service catalog for the homelab.

It describes services independently from how they are deployed.

Example:

```yaml
services:

  grafana:
    name: Grafana
    category: Monitoring
    tier: internal
    url: https://grafana.home.arpa
    icon: grafana.png

    homepage:
      enabled: true
      description: Monitoring dashboards

    monitoring:
      enabled: true
      type: prometheus
      endpoint: http://grafana:3000/metrics

    uptime:
      enabled: true
```

### Service Metadata

Common fields include:

```yaml
name:
category:
tier:
url:
icon:
```

These fields describe the service itself.

They can be consumed by multiple systems.

### Tier

`tier` declares which access tier the service belongs to. It determines the domain used in `url` and whether the service is expected to be reachable outside the LAN.

```yaml
tier: internal
```

Valid values:

* `internal` — LAN/VPN only, served under `*.home.arpa`, never given a public DNS record or Cloudflare route.
* `personal` — personal-facing service, served under `*.jsisques.net`, exposed through Cloudflare Tunnel.
* `public` — public homelab app, served under `*.sisqueslabs.com`, exposed through Cloudflare Tunnel.

Both `personal` and `public` services must get a matching `ingress` entry in `services/cloudflared/config.yml`; `internal` services must not.

Default to `internal` unless a service has a deliberate reason to be reachable from outside the home network.

### Homepage

The `homepage` section controls whether the service appears in Homepage.

```yaml
homepage:
  enabled: true
  description: Monitoring dashboards
```

### Monitoring

The `monitoring` section describes how the service should be monitored by Prometheus.

```yaml
monitoring:
  enabled: true
  type: prometheus
  endpoint: http://grafana:3000/metrics
```

This information is consumed by:

```text
scripts/generation/generate-prometheus.sh
```

### Uptime Monitoring

The `uptime` section defines whether the service should be monitored by Uptime Kuma.

```yaml
uptime:
  enabled: true
```

Additional Uptime Kuma configuration can be added as required.

## `hosts.yaml`

`hosts.yaml` describes the physical and virtual machines that make up the homelab, plus the `network:` block every one of them resolves its address against.

Example:

```yaml
network:
  lan:
    prefix: "192.168.1"
    mask: 24
    gateway: "192.168.0.1"
    bridge: "vmbr0"
  nas:
    prefix: "192.168.0"

hosts:

  proxmox:
    type: server
    address: TBD  # LAN IP not confirmed yet
    platform: proxmox

  nas:
    type: physical
    platform: nas
    network: nas
    octet: 111
    role:
      - storage

  monitoring:
    type: lxc
    platform: proxmox
    octet: 20
    cpu: 4
    memory: 4096
    disk: 32
    role:
      - prometheus
      - grafana

  k3s-server:
    type: vm
    octet: 31
    platform: proxmox
    cpu: 4
    memory: 8192
    disk: 50
    role:
      - k3s
      - server

  raspberrypi-01:
    type: physical
    octet: 40
    platform: raspberry-pi
    role:
      - k3s
      - worker
```

### Resolving a host's address

Every host resolves to a full IPv4 address one of three ways, in order:

1. `address: TBD` — unconfirmed, skipped everywhere (see below).
2. `address: <literal IP>` — an explicit override, used as-is. Reach for this only when a host's IP genuinely isn't `<network>.<prefix>.<octet>` (today, only `proxmox` while its real IP is still unknown).
3. `octet: <n>` — the common case. Resolves to `network.<network // "lan">.prefix` + `.` + `octet`, so `octet: 20` under the default `lan` network becomes `192.168.0.20`. Set `network: nas` (see the `nas` host above) to resolve against `network.nas.prefix` instead.

This means changing your home network's subnet — `192.168.0.0/24` today, `10.0.0.0/24` tomorrow — is a one-line change to `network.lan.prefix` (and `network.lan.gateway`), not 25 hand-edited IPs. `cpu`/`memory` (MB)/`disk` (GB) are only meaningful for `type: lxc` and `type: vm` — they're the exact fields Terraform needs to size the resource. Physical hosts (`server`, `physical`) don't set them since Terraform doesn't provision those.

This information is used to generate:

* **Terraform variables** — `scripts/generation/generate-terraform-vars.sh` turns every `lxc`/`vm` entry into `terraform/proxmox/hosts.auto.tfvars.json` (`lxc_network` / `vm_nodes`), plus `network_gateway` / `network_bridge` / `network_mask` from the `network.lan` block — all loaded by Terraform automatically. **Addresses, sizing, gateway, and bridge are only ever set here, never duplicated in `terraform.tfvars`.**
* **Ansible inventory** — `scripts/generation/generate-inventory.sh` turns every entry into `ansible/inventory/hosts.yml`, grouped by hostname and by `role`, plus an `all.vars.lan_cidr` (e.g. `192.168.0.0/24`) that roles like `wireguard` consume instead of hardcoding the LAN subnet.
* Monitoring targets, Node Exporter configuration, Traefik routes, and blackbox_exporter targets — every generator in `scripts/generation/` resolves addresses the same way, via the shared `resolve_addresses` helper in `scripts/generation/lib.sh`.

A host with `address: TBD` is skipped by every generator (with a warning) instead of producing a broken IP.

## Configuration vs Infrastructure

The `config/` directory describes **what exists and how it should be represented**.

It does not directly create infrastructure.

The different layers have separate responsibilities:

```text
config/
   │
   ├── services.yaml
   └── hosts.yaml
          │
          ▼
      Automation
          │
    ┌─────┼─────┐
    │     │     │
    ▼     ▼     ▼
Terraform Ansible Generation
    │     │     │
    ▼     ▼     ▼
Proxmox Hosts  Service configs
                │
                ▼
             Services
```

### Terraform

Terraform manages infrastructure resources.

```text
terraform/
```

Examples:

* VMs
* LXCs
* Networks
* Storage

### Ansible

Ansible configures operating systems and hosts.

```text
ansible/
```

Examples:

* Packages
* Docker
* Node Exporter
* System configuration
* K3s prerequisites

### Kubernetes / Argo CD

Kubernetes and Argo CD manage Kubernetes workloads.

```text
kubernetes/
```

Examples:

* Kafka
* Monitoring
* Applications
* Ingress
* Certificates

### Scripts

Scripts consume configuration when a transformation or helper operation is required.

```text
scripts/
```

For example:

```text
config/services.yaml
        │
        ▼
generate-homepage.sh
        │
        ▼
services/homepage/config/services.yaml
```

## Secrets

Sensitive information must not be stored directly in this directory.

Do not commit:

* Passwords
* API tokens
* Private keys
* SSH private keys
* Database credentials
* Cloud credentials

Instead, use the homelab's secret management solution.

References to secrets are acceptable:

```yaml
credentials:
  secretRef: grafana-admin
```

but the actual secret value must be stored outside the repository or in an encrypted secret format.

## Naming Conventions

Use lowercase names with hyphens for service identifiers:

```yaml
uptime-kuma:
prometheus:
kafka-exporter:
gardenia-api:
```

Use descriptive categories:

```text
Infrastructure
Monitoring
Networking
Applications
Storage
Security
```

Keep service identifiers stable because they may be referenced by generated configuration.

## Validation

Configuration should be validated before deployment.

For example:

```bash
./scripts/validation/validate.sh
```

Validation should check:

* YAML syntax
* Required fields
* Invalid references
* Duplicate service identifiers
* Invalid configuration values
* Secret leaks

## Git Workflow

Configuration changes should follow the normal Git workflow:

```text
Edit configuration
       │
       ▼
Validate
       │
       ▼
Review diff
       │
       ▼
Commit
       │
       ▼
Push
       │
       ▼
CI/CD
```

Example:

```bash
git diff config/

./scripts/validation/validate.sh

git add config/
git commit -m "config: add kafka monitoring"
git push
```

## Design Principles

### Single Source of Truth

Avoid duplicating service metadata across different configuration files.

### Tool Agnostic

The central configuration should describe the homelab rather than being tightly coupled to a particular tool whenever possible.

### Declarative

Configuration should describe the desired state rather than a sequence of commands.

### Reproducible

A fresh homelab should be able to reconstruct its configuration from the repository.

### Version Controlled

All non-secret configuration should live in Git.

### Explicit

Prefer explicit configuration over automatic discovery when reliability matters.

## Relationship With The Repository

```text
homelab/
│
├── config/                 # Central configuration
│   ├── services.yaml
│   └── hosts.yaml
│
├── terraform/              # Infrastructure
│   └── proxmox/
│
├── ansible/                # Host configuration
│
├── kubernetes/             # Kubernetes workloads
│   ├── argocd/
│   ├── infrastructure/
│   └── applications/
│
├── services/               # Non-Kubernetes services
│
└── scripts/                # Automation and generators
    ├── generation/
    └── validation/
```

The `config/` directory is intentionally kept independent from the implementation details of the infrastructure.

It defines the homelab at a high level; the other layers determine how that desired state is implemented.
