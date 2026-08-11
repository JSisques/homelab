# Homelab as Code

This repository contains the complete infrastructure and configuration of my homelab.

The goal is to make the entire environment **reproducible, declarative, version controlled, and automatically deployable**. Infrastructure, services, monitoring, dashboards, networking, and application configuration are managed from this repository.

The homelab should be recoverable from scratch by deploying the desired state defined in Git.

## Project Status

🚧 **Early stage / work in progress.** This repository currently describes the *target* design of the homelab more than its current running state. Proxmox, K3s, Argo CD, and most of the service catalog in `config/services.yaml` are being defined here first and rolled out incrementally — treat the architecture below as the direction, not a snapshot of what is live today.

What exists so far:

* Terraform configuration for Proxmox (`terraform/proxmox/`) — not yet applied to a running cluster.
* Ansible roles and playbooks for a handful of services (`n8n`, `it-tools`) plus base host setup (`common`, `docker`, `node-exporter`).
* Standalone Docker Compose definitions for `prometheus`, `grafana`, `homepage`, `it-tools`, and `n8n` under `services/`.
* Kubernetes/Argo CD manifests for Kafka (via Strimzi) under `kubernetes/` — the K3s cluster itself is not yet provisioned; `config/hosts.yaml` currently only lists two Raspberry Pi nodes.
* A public documentation site built with Astro/Starlight under `website/`, deployed to GitHub Pages.

As pieces go from "defined in Git" to "actually running," this README and `docs/` should be updated to reflect it.

## Goals

* Manage the entire homelab as code
* Keep infrastructure and service configuration version controlled
* Reproduce the environment from a clean Proxmox installation
* Automate VM and LXC provisioning
* Automatically configure hosts and services
* Use Git as the single source of truth
* Automatically deploy changes after pushing to the repository
* Centralize observability across the entire homelab
* Manage Kubernetes workloads declaratively
* Avoid manually configuring services through web interfaces whenever possible

## Architecture

The homelab is built around Proxmox, with Kubernetes and traditional services running on virtual machines, LXC containers, and Raspberry Pi nodes.

```text
                           GitHub
                             │
                          git push
                             │
                             ▼
                      GitHub Actions
                             │
                    ┌────────┴────────┐
                    │                 │
                Terraform          Ansible
                    │                 │
                    ▼                 ▼
                 Proxmox          Hosts / LXCs
                    │                 │
              ┌─────┴─────┐           │
              │           │           │
             VMs         LXCs     Raspberry Pi
              │
             K3s
              │
        ┌─────┼─────────┐
        │     │         │
      Helm  Argo CD   Apps
```

The final architecture will combine:

* Proxmox
* Terraform
* Ansible
* K3s
* Helm
* Argo CD
* Docker
* Prometheus
* Grafana
* Loki
* Alertmanager
* Homepage
* Uptime Kuma
* Traefik / Cloudflare Tunnel
* VPN (internal-only access)
* Home Assistant
* Additional services and personal projects

The exact services are expected to evolve as the homelab grows.

## Domains and Network Access

Services are split across three access tiers, depending on who they're for and how exposed they should be:

| Tier | Domain | Access | Example services |
| ---- | ------ | ------ | ----------------- |
| Internal only | `*.home.arpa` | LAN / VPN only, never exposed to the internet | Grafana, Proxmox, Prometheus |
| Personal | `jsisques.net` | Personal-facing services and projects | Personal apps/site |
| Public | `sisqueslabs.com` | Public homelab apps, exposed via Cloudflare Tunnel | Public-facing apps and demos |

`home.arpa` is the [RFC 8375](https://datatracker.ietf.org/doc/html/rfc8375) reserved name for home networks and is used for anything that should stay LAN/VPN-only — it never gets a public DNS record or a Cloudflare route. `jsisques.net` and `sisqueslabs.com` are real domains routed through Cloudflare Tunnel for services that are meant to be reachable from outside the home network.

`config/services.yaml` should be updated to reflect which tier each service belongs to as the domain scheme is rolled out; today it still uses `home.arpa` as a placeholder for all services.

## Repository Structure

```text
homelab/
│
├── config/
│   ├── README.md
│   ├── hosts.yaml
│   └── services.yaml
│
├── terraform/
│   └── proxmox/
│
├── ansible/
│   ├── playbooks/
│   └── roles/
│
├── kubernetes/
│   ├── argocd/
│   └── infrastructure/
│       └── kafka/
│
├── services/
│   ├── prometheus/
│   ├── grafana/
│   ├── homepage/
│   ├── it-tools/
│   └── n8n/
│
├── scripts/
│   ├── bootstrap/
│   ├── generation/
│   └── validation/
│
├── docs/
│   ├── architecture.md
│   ├── storage.md
│   └── disaster-recovery.md
│
├── website/
│
└── .github/
    └── workflows/
```

## Configuration

The `config/` directory contains the high-level desired state of the homelab. See [`config/README.md`](config/README.md) for the full model.

### Hosts

`config/hosts.yaml` describes the machines that should exist. Today it only lists the two Raspberry Pi nodes; Proxmox itself, VMs, and the NAS still need to be added here as they're provisioned.

```yaml
hosts:
  raspberrypi-01:
    type: physical
    platform: raspberry-pi
    address: 192.168.1.40
    role:
      - k3s
      - worker
```

This information can be consumed by Terraform and Ansible to provision and configure the corresponding hosts.

### Services

`config/services.yaml` is the central service catalog.

```yaml
services:
  grafana:
    name: Grafana
    category: Monitoring
    url: https://grafana.home.arpa

    homepage:
      enabled: true
      description: Monitoring dashboards

    monitoring:
      enabled: true
      type: prometheus
      endpoint: http://grafana:3000/metrics
```

The service catalog allows different parts of the homelab to derive their configuration from the same source of truth, so services are not defined multiple times across different config files.

```text
                    services.yaml
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
       Homepage      Uptime Kuma     Prometheus
```

Note: some entries in `services.yaml` (`kafka`, `uptime-kuma`, `gardenia`, `proxmox`) are catalog-only today — they describe services that are planned or partially deployed, not necessarily something with a matching `services/<name>/` directory yet.

## Infrastructure as Code

### Terraform

Terraform provisions infrastructure on Proxmox: virtual machines, LXC containers, CPU/memory/disk allocation, networking, and cloud-init metadata. It uses the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) provider (see `terraform/proxmox/`).

Terraform defines **what infrastructure exists** — it does not configure the OS or deploy applications.

### Ansible

Ansible configures the operating systems and services running on provisioned hosts: users/SSH, packages, Docker, Node Exporter, firewall rules, and service deployment (see `ansible/roles/`).

Terraform answers *"what machines should exist?"*; Ansible answers *"how should those machines be configured?"*

## Kubernetes

K3s is intended to run the cluster's workloads, on VMs and/or Raspberry Pi nodes, reconciled via Argo CD. This layer is defined (`kubernetes/infrastructure/kafka/` via Strimzi, `kubernetes/argocd/`) but the cluster itself has not been provisioned yet — see the Project Status section above.

### Helm / Argo CD

Helm packages Kubernetes applications; Argo CD provides GitOps-based continuous delivery, reconciling what's committed to the repo with the running cluster.

## Observability

Observability is meant to be centralized rather than deploying a separate monitoring stack per application:

```text
                         Grafana
                       /    |    \
                      /     |     \
             Prometheus    Loki   Tempo
                 │          │       │
              Metrics      Logs   Traces
```

Prometheus (currently running as a standalone Compose service, see `services/prometheus/`) collects metrics from hosts, containers, VMs, and — once provisioned — Kubernetes nodes and workloads. Grafana provides centralized dashboards from `services/grafana/`.

## Uptime Monitoring & Homepage

Uptime Kuma (planned) and [Homepage](https://gethomepage.dev/) (`services/homepage/`) are both intended to be generated from `config/services.yaml`, so adding a service to the catalog can automatically create its dashboard entry and uptime monitor. See `scripts/generation/`.

## GitOps Workflow

```text
1. Edit configuration locally
2. Commit changes
3. Push to GitHub
4. GitHub Actions validates (YAML, Terraform, Ansible, Compose)
5. Terraform / Ansible apply (self-hosted runner)
6. Argo CD reconciles Kubernetes
7. Homelab reaches desired state
```

CI (`.github/workflows/`) validates every push/PR; the `deploy.yaml` workflow (manual dispatch, self-hosted runner) applies Terraform and Ansible against the real infrastructure.

## Storage

Storage is split across Proxmox disks, Kubernetes persistent volumes (`local-path`, node-local), and Docker named volumes for standalone services. A NAS on the local network is planned as the backing store for services that need shared/network storage rather than node-local disks — for example an S3-compatible object store (evaluating [rustfs](https://rustfs.com/) over MinIO) with its data actually living on the NAS. See [`docs/storage.md`](docs/storage.md) for details and rules.

## Secrets

Secrets should never be committed in plaintext. Sensitive configuration will use mechanisms such as SOPS, Age, Ansible Vault, Kubernetes Secrets, or External Secrets. Public configuration remains in Git while sensitive values remain encrypted or externally referenced.

## Roadmap / Planned Services

Beyond what's already scaffolded (monitoring, n8n, it-tools, Kafka), the next areas of focus are:

* **Security / Network** — VPN (WireGuard/Tailscale) for internal-only access to services like Grafana, Pi-hole/AdGuard for DNS, Vaultwarden as a password manager, Authelia/Authentik for SSO in front of exposed apps.
* **Backups / Storage** — a NAS-backed storage layer (S3-compatible, likely rustfs), plus Restic/Borg for backups and Syncthing for sync. Anything that needs real persistence should end up on the NAS rather than node-local disk.

This list will grow as needs are identified — the intent is that any new service gets an entry in `config/services.yaml`, a home in `terraform/`/`ansible/`/`services/`/`kubernetes/` depending on how it's deployed, and a tier from the [Domains](#domains-and-network-access) table above.

## Design Principles

* **Declarative** — describe the desired state instead of procedural setup scripts.
* **Reproducible** — the environment should be rebuildable from the repository.
* **Version Controlled** — infrastructure and configuration changes are tracked through Git.
* **Automated** — a Git push should be enough to trigger the required deployment workflow.
* **Observable** — every important host and service should expose useful health and performance information.
* **Modular** — services should be independently deployable and configurable.
* **Single Source of Truth** — service metadata is defined once and reused to generate configuration for different systems.

## Documentation

* [Architecture](docs/architecture.md)
* [Storage](docs/storage.md)
* [Disaster Recovery](docs/disaster-recovery.md)
* [Configuration model](config/README.md)
* [Scripts](scripts/README.md)
* [Terraform / Proxmox](terraform/proxmox/README.md)
* [Argo CD](kubernetes/argocd/README.md)
* Public documentation site: `website/` (Astro/Starlight, deployed via GitHub Pages)

---

## License

Personal homelab infrastructure and configuration. Use at your own risk.
