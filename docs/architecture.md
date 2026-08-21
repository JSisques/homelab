# Homelab Architecture

This document describes the target architecture of the homelab and the role of each infrastructure layer.

## Design Principles

- Git is the source of truth.
- Infrastructure and configuration are declarative and reproducible.
- Changes are reviewed before they are deployed.
- Kubernetes workloads are reconciled through Argo CD.
- Stateful services use persistent storage and an explicit recovery plan.
- Monitoring and access paths are treated as platform concerns, not application details.

## High-Level Overview

```text
                                   GitHub
                                      |
                             GitHub Actions / Git
                                      |
                  +-------------------+-------------------+
                  |                                       |
              Terraform                                Ansible
                  |                                       |
                  v                                       v
               Proxmox                         Operating systems and services
          +-------+--------+
          |                |
         VMs              LXCs / Raspberry Pi
          |
         K3s
          |
       Argo CD
          |
   Kubernetes workloads
```

## Infrastructure Layers

### Proxmox

Proxmox is the virtualization layer. Terraform is responsible for declaring virtual machines, LXC containers, disks, CPU, memory, networking, and cloud-init metadata.

### Host Configuration

Ansible configures provisioned operating systems and hosts. Typical responsibilities include users and SSH, packages, Docker, firewall rules, exporters, and service configuration.

The intended inventory and service catalog live in `config/hosts.yaml` and `config/services.yaml`.

### Kubernetes

K3s runs as a single-node server on the `k3s-server` VM (`ansible/roles/k3s/`) and can be extended with worker VMs and/or the Raspberry Pi nodes already tagged `role: [k3s, worker]` in `config/hosts.yaml` — joining them as agents isn't built yet. Argo CD watches the repository and reconciles Kubernetes resources from Git; it's installed and empty until `Application` resources are applied.

The Kubernetes tree is split into:

- `kubernetes/infrastructure/`: shared platform components such as Kafka and its operators.
- `kubernetes/argocd/`: Argo CD applications and GitOps entry points.
- Application-specific manifests as the platform grows.

### Services Outside Kubernetes

Most services run directly on dedicated LXC containers (or, for Proxmox Backup Server, a VM) rather than Kubernetes: Prometheus, Grafana, Loki, Alertmanager, Tempo, and the OTel Collector (all on the shared `monitoring` LXC), Homepage, IT-Tools, n8n, `cookidoo-mcp`, Uptime Kuma, `cloudflared`, AdGuard Home, and WireGuard. Each has a matching directory under `services/` (the Compose source of truth) and an Ansible role under `ansible/roles/` that deploys it unmodified. Proxmox Backup Server and Promtail are the exceptions — native packages installed by Ansible, no Docker involved. Prometheus stores its data in the Docker volume `prometheus-data`.

Applications that emit OpenTelemetry data (currently `cookidoo-mcp`) push OTLP traces/metrics/logs to the OTel Collector on the `monitoring` LXC (`192.168.0.209:4317`/`4318`), which fans them out: metrics are exposed on a Prometheus-scrapeable endpoint (pull, not `remote_write`, so the shared Prometheus instance's configuration doesn't change), logs go to Loki's native OTLP endpoint, and traces go to Tempo. This keeps the existing scrape-based Prometheus model intact while giving OTel-native services somewhere to push to.

## Data and Control Flow

```text
Developer change
      |
      v
Git repository
      |
      +--> Terraform --> Proxmox resources
      +--> Ansible ----> Host configuration
      +--> Argo CD ---> Kubernetes resources
      +--> Compose ----> Standalone services
```

## Operational Boundaries

- Terraform should manage resource lifecycle, not application configuration.
- Ansible should configure hosts and standalone services, not replace Argo CD for Kubernetes workloads.
- Kubernetes stateful workloads must declare storage explicitly.
- Secrets must be injected through the selected secret-management process and never committed in plaintext.
- Public access terminates at the Cloudflare Tunnel (`services/cloudflared/`, deployed on its own LXC). It is the only ingress path for `tier: public` (`sisqueslabs.com`) and `tier: personal` (`jsisques.net`) services; `tier: internal` services (no domain, plain LAN `IP:port`) must never get an entry in its ingress config and stay reachable only over the LAN/VPN.

## Source of Truth

When the running system and Git disagree, first determine which layer owns the resource. Make the correction in that layer, then allow the normal reconciliation or configuration process to apply it.

Useful entry points:

- [Repository overview](../README.md)
- [Argo CD](../kubernetes/argocd/README.md)
- [Kafka](../kubernetes/infrastructure/kafka/README.md)
