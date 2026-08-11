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

K3s runs on virtual machines and can be extended with Raspberry Pi nodes. Argo CD watches the repository and reconciles Kubernetes resources from Git.

The Kubernetes tree is split into:

- `kubernetes/infrastructure/`: shared platform components such as Kafka and its operators.
- `kubernetes/argocd/`: Argo CD applications and GitOps entry points.
- Application-specific manifests as the platform grows.

### Services Outside Kubernetes

Most services run directly on dedicated LXC containers rather than Kubernetes: Prometheus and Grafana (both on the shared `monitoring` LXC), Homepage, IT-Tools, n8n, Uptime Kuma, and the `cloudflared` tunnel. Each has a matching directory under `services/` (the Compose source of truth) and an Ansible role under `ansible/roles/` that deploys it unmodified. Prometheus stores its data in the Docker volume `prometheus-data`.

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
- Public access terminates at the Cloudflare Tunnel (`services/cloudflared/`, deployed on its own LXC). It is the only ingress path for `tier: public` (`sisqueslabs.com`) and `tier: personal` (`jsisques.net`) services; `tier: internal` (`*.home.arpa`) services must never get an entry in its ingress config and stay reachable only over the LAN/VPN.

## Source of Truth

When the running system and Git disagree, first determine which layer owns the resource. Make the correction in that layer, then allow the normal reconciliation or configuration process to apply it.

Useful entry points:

- [Repository overview](../README.md)
- [Argo CD](../kubernetes/argocd/README.md)
- [Kafka](../kubernetes/infrastructure/kafka/README.md)
