# Homelab as Code

This repository contains the complete infrastructure and configuration of my homelab.

The goal is to make the entire environment **reproducible, declarative, version controlled, and automatically deployable**. Infrastructure, services, monitoring, dashboards, networking, and application configuration are managed from this repository.

The homelab should be recoverable from scratch by deploying the desired state defined in Git.

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
* Traefik
* Cloudflare
* Home Assistant
* Additional services and personal projects

The exact services are expected to evolve as the homelab grows.

## Repository Structure

```text
homelab/
│
├── config/
│   ├── hosts.yaml
│   ├── services.yaml
│   └── networks.yaml
│
├── terraform/
│   ├── proxmox/
│   └── modules/
│
├── ansible/
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
│
├── kubernetes/
│   ├── argocd/
│   ├── infrastructure/
│   └── applications/
│
├── services/
│   ├── monitoring/
│   ├── homepage/
│   ├── uptime-kuma/
│   ├── adguard/
│   └── ...
│
├── scripts/
│
├── .github/
│   └── workflows/
│
├── Makefile
└── README.md
```

## Configuration

The `config/` directory contains the high-level desired state of the homelab.

### Hosts

`config/hosts.yaml` describes the machines that should exist.

```yaml
hosts:

  k3s-server:
    type: vm
    platform: proxmox
    cpu: 4
    memory: 8192
    disk: 50G

  monitoring:
    type: lxc
    platform: proxmox
    cpu: 2
    memory: 4096
```

This information can be consumed by Terraform and Ansible to provision and configure the corresponding hosts.

### Services

`config/services.yaml` is intended to become the central service catalog.

```yaml
services:

  grafana:
    name: Grafana
    host: monitoring
    url: https://grafana.home.example.com

    homepage:
      enabled: true

    uptime:
      enabled: true

    monitoring:
      enabled: true
```

The service catalog allows different parts of the homelab to derive their configuration from the same source of truth.

For example:

```text
                    services.yaml
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
       Homepage      Uptime Kuma     Prometheus
          │              │              │
       service         monitor        metrics
```

This avoids duplicating service definitions across multiple configuration files.

## Infrastructure as Code

### Terraform

Terraform is responsible for provisioning infrastructure on Proxmox.

It manages resources such as:

* Virtual machines
* LXC containers
* CPU and memory allocation
* Disks
* Network configuration
* Cloud-init
* VM and container metadata

Terraform defines **what infrastructure exists**.

```text
Terraform
    │
    ▼
Proxmox
    │
    ├── VMs
    └── LXCs
```

## Configuration Management

### Ansible

Ansible is responsible for configuring the operating systems and services running on the provisioned hosts.

Typical responsibilities include:

* Base operating system configuration
* Users and SSH
* Packages
* Docker
* Node Exporter
* Service configuration
* Firewall rules
* Configuration files
* Service deployment

Terraform answers:

> What machines should exist?

Ansible answers:

> How should those machines be configured?

## Kubernetes

K3s is used for container orchestration.

The cluster can run on virtual machines hosted by Proxmox and Raspberry Pi nodes.

```text
Proxmox
│
├── k3s-server
│
├── Raspberry Pi
│
└── Raspberry Pi
```

Kubernetes infrastructure and applications are managed declaratively.

### Helm

Helm is used to package and deploy Kubernetes applications.

### Argo CD

Argo CD provides GitOps-based continuous delivery for Kubernetes.

```text
GitHub
   │
   ▼
Argo CD
   │
   ▼
K3s
```

Changes committed to the repository are automatically reconciled with the Kubernetes cluster.

## Observability

Observability is centralized rather than deploying a separate monitoring stack for every application.

The planned architecture is:

```text
                         Grafana
                       /    |    \
                      /     |     \
             Prometheus    Loki   Tempo
                 │          │       │
              Metrics      Logs   Traces
                 │
       ┌─────────┼──────────────┐
       │         │              │
    Proxmox     K3s          Services
       │         │              │
      LXCs      Pods       Applications
       │
   Raspberry Pi
```

Prometheus collects metrics from:

* Proxmox
* LXC containers
* Virtual machines
* Raspberry Pi nodes
* Kubernetes nodes
* Kubernetes workloads
* Applications

Grafana provides centralized dashboards.

## Example: Grafana

Grafana configuration is stored in Git and provisioned automatically.

```text
services/
└── monitoring/
    ├── compose.yaml
    ├── prometheus/
    │   └── prometheus.yml
    └── grafana/
        └── provisioning/
            ├── datasources/
            │   └── prometheus.yaml
            └── dashboards/
                ├── dashboards.yaml
                └── homelab-test.json
```

This allows dashboards and datasources to be recreated without manually configuring Grafana.

## Uptime Monitoring

Uptime Kuma is used to monitor the availability of homelab services.

Monitor definitions are intended to be declarative:

```text
config/services.yaml
        │
        ▼
   Uptime Kuma
        │
        ├── Grafana
        ├── Prometheus
        ├── Proxmox
        ├── Home Assistant
        └── Applications
```

Adding a service to the central service catalog can automatically create the corresponding uptime monitor.

## Homepage

Homepage provides a central dashboard for accessing homelab services.

Its configuration is generated from the service catalog where possible.

```text
services.yaml
      │
      ▼
  Homepage
      │
 ┌────┼──────────────┐
 │    │              │
Infra Monitoring   Apps
```

## GitOps Workflow

The intended workflow is:

```text
1. Edit configuration locally
        │
        ▼
2. Commit changes
        │
        ▼
3. Push to GitHub
        │
        ▼
4. GitHub Actions
        │
        ▼
5. Validate configuration
        │
        ▼
6. Terraform / Ansible
        │
        ▼
7. Proxmox / Hosts
        │
        ▼
8. Argo CD reconciles Kubernetes
        │
        ▼
9. Homelab reaches desired state
```

The goal is to make manual configuration the exception rather than the normal workflow.

## Deployment

The repository will provide a simple interface for common operations.

```bash
make plan
make apply
make deploy
make status
make validate
```

The exact implementation may evolve as the platform grows.

The desired end state is to be able to bootstrap the homelab from a clean environment with a minimal number of manual steps.

## Secrets

Secrets should never be committed in plaintext.

Sensitive configuration will use mechanisms such as:

* SOPS
* Age
* Ansible Vault
* Kubernetes Secrets
* External Secrets

Example:

```text
secrets/
└── production/
    ├── monitoring.enc.yaml
    └── services.enc.yaml
```

Public configuration remains in Git while sensitive values remain encrypted.

## Design Principles

### Declarative

Describe the desired state instead of writing procedural setup scripts whenever possible.

### Reproducible

The environment should be rebuildable from the repository.

### Version Controlled

Infrastructure and configuration changes should be tracked through Git.

### Automated

A Git push should be enough to trigger the required deployment workflow.

### Observable

Every important host and service should expose useful health and performance information.

### Modular

Services should be independently deployable and configurable.

### Single Source of Truth

Service metadata should be defined once and reused to generate configuration for different systems.

## Project Status

This repository is a work in progress.

The homelab is continuously evolving as new infrastructure, services, automation, and experiments are added.

The long-term goal is to turn the homelab into a fully reproducible **Internal Developer Platform** managed through Infrastructure as Code and GitOps.

---

## License

Personal homelab infrastructure and configuration. Use at your own risk.
