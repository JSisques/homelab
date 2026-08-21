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
    url: http://192.168.0.209:3000
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

`tier` declares which access tier the service belongs to. It determines whether the service has a domain at all, and whether it's routed through Traefik/Cloudflare Tunnel.

```yaml
tier: internal
```

Valid values:

* `internal` — no domain. `url` is a LAN `IP:port`, linked directly from Homepage. Never routed through Traefik, never given a Cloudflare Tunnel entry. This is the default for everything.
* `personal` — served under `*.jsisques.net`, exposed via Cloudflare Tunnel → Traefik → backend.
* `public` — served under `*.sisqueslabs.com`, exposed via Cloudflare Tunnel → Traefik → backend.

`personal` and `public` services need a `traefik: {enabled: true, port: <n>}` block (the backend port Traefik forwards to) — `generate-traefik.sh` and `generate-cloudflared.sh` both key off it. `internal` services must not set `traefik:` at all.

Default to `internal` unless a service has a deliberate reason to be reachable from outside the home network.

#### `external:` — a service that's internal but also has a public alias

Some services are used day-to-day on the LAN (`tier: internal`, plain `IP:port`) but also need a remote-access alias — e.g. Jellyfin, reachable at `192.168.0.215:8096` on the LAN and at `https://jellyfin.jsisques.net` from anywhere. Rather than change the service's own `tier`, it gets an `external:` block with the same shape as a top-level `personal`/`public` service:

```yaml
jellyfin:
  tier: internal
  url: http://192.168.0.215:8096

  external:
    tier: personal
    url: https://jellyfin.jsisques.net
    traefik:
      enabled: true
      port: 8096
```

`generate-traefik.sh` and `generate-cloudflared.sh` treat `external:` as a second exposure of the same backend (resolved via the same host key in `config/hosts.yaml`), alongside whatever the service's own top-level `tier` gives it. A plain `personal`/`public` service does not need an `external:` block — it's already exposed via its top-level `tier`.

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
    prefix: "192.168.0"
    mask: 24
    gateway: "192.168.0.1"
    bridge: "vmbr0"
  nas:
    prefix: "192.168.0"

hosts:

  proxmox:
    type: server
    platform: proxmox
    node: proxmox
    octet: 157

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

### `swap` (LXC only)

`swap: <MB>` is an optional field on `type: lxc` hosts (defaults to `0`, i.e. none). It's a cgroup swap limit backed by the Proxmox *host's* own swap device — unlike disk-based guest swap, it costs no space on the container's own `disk`, so it's safe to add even to hosts with a tight `disk` allocation. It's not available for `type: vm`: a VM's swap would have to live inside the guest (a swapfile/partition on its own disk), which this repo doesn't provision.

Only add `swap` where a service has a real, bursty memory pattern (e.g. `n8n` workflow executions, `minecraft`'s JVM GC headroom, the `downloads` stack under load) — not blanket across every LXC. Most single-purpose containers here are already sized close to their steady-state usage (see the sizing comments throughout `hosts.yaml`); swap is a safety net for spikes, not a substitute for correct `memory` sizing.

### Proxmox VMID

Terraform always sets a pinned Proxmox ID (`vm_id`) so a lost state file cannot spawn a second CT/VM with "the next free ID". The ID is `vmid:` if set, otherwise `octet` — so `it-tools` at `octet: 214` is CT `214` at `192.168.0.214`. Set `vmid:` only when the Proxmox ID must differ from the last IP octet (for example when adopting a guest that was created by hand with another ID).

### Proxmox node name

LXCs and VMs are created on the node named by the hypervisor host's `node:` field (falling back to that host's key). Today that host is `proxmox` with `node: proxmox`. A per-VM `proxmox_node:` override exists for a future multi-node cluster; do not set `proxmox_node` in `terraform.tfvars`.

This information is used to generate:

* **Terraform variables** — `scripts/generation/generate-terraform-vars.sh` turns every `lxc`/`vm` entry into `terraform/proxmox/hosts.auto.tfvars.json` (`lxc_network` / `vm_nodes` / `proxmox_node`), plus `gateway` / `network_bridge` / `network_mask` from the `network.lan` block — all loaded by Terraform automatically. **Addresses, VMIDs, node name, sizing, gateway, and bridge are only ever set here, never duplicated in `terraform.tfvars`.**
* **Ansible inventory** — `scripts/generation/generate-inventory.sh` turns every entry into `ansible/inventory/hosts.yml`, grouped by hostname and by `role`, plus an `all.vars.lan_cidr` (e.g. `192.168.0.0/24`) that roles like `wireguard` consume instead of hardcoding the LAN subnet.
* Monitoring targets, Node Exporter configuration, Traefik routes, and blackbox_exporter targets — every generator in `scripts/generation/` resolves addresses the same way, via the shared `resolve_addresses` helper in `scripts/generation/lib.sh`.

A host with `address: TBD` is skipped by every generator (with a warning) instead of producing a broken IP.

### Proxmox tags

Every `lxc`/`vm` host gets a `tags` list on its Proxmox resource, generated automatically — there's no `tags:` field to set by hand in `hosts.yaml`. Tags are the generic `category` values (from `services.yaml`, e.g. `monitoring`, `networking`, `downloads`, `media`, `automation`, `productivity`, `utilities`, `applications`, `infrastructure`) of the services matched by the host's `role` list — not the role/service names themselves, and not `lxc`/`vm` (that's already visible on the resource). E.g. the `monitoring` host above (`role: [prometheus, grafana, loki, alertmanager, otel-collector, tempo]`, all `category: Monitoring` in `services.yaml`) gets `tags: ["monitoring"]`; `k3s-server` (`role: [k3s, server, daysoff, rancher, blog]`, a mix of `Applications` and `Infrastructure`) gets `tags: ["applications", "infrastructure"]`. A role with no matching `services.yaml` entry (e.g. `k3s`, `server`, `worker`) contributes no tag; if a host ends up with no category at all, it falls back to `tags: ["infrastructure"]` so nothing is left untagged. Renaming a `role` or changing a service's `category` updates the tags on the next `make terraform-vars` + `terraform apply`; nothing else to maintain.

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
