# Homelab as Code

This repository contains the complete infrastructure and configuration of my homelab.

The goal is to make the entire environment **reproducible, declarative, version controlled, and automatically deployable**. Infrastructure, services, monitoring, dashboards, networking, and application configuration are managed from this repository.

The homelab should be recoverable from scratch by deploying the desired state defined in Git.

## Project Status

🚧 **Early stage / work in progress.** This repository currently describes the *target* design of the homelab more than its current running state. Proxmox, K3s, Argo CD, and most of the service catalog in `config/services.yaml` are being defined here first and rolled out incrementally — treat the architecture below as the direction, not a snapshot of what is live today.

What exists so far:

* Terraform configuration for Proxmox (`terraform/proxmox/`) that provisions every LXC and VM declaratively from `config/hosts.yaml` (`lxc_network` / `vm_nodes`, both generated) — not yet applied to a running cluster.
* Ansible roles and playbooks for every LXC/VM service (`it-tools`, `n8n`, `monitoring` [Prometheus + Grafana + Loki + Alertmanager], `homepage`, `uptime-kuma`, `cloudflared`, `adguard-home`, `wireguard`, `pbs`) plus a mandatory base (`common`, `node-exporter`, `promtail`, `docker`), driven by a generated inventory (`scripts/generation/generate-inventory.sh`).
* Standalone Docker Compose definitions for `prometheus`, `grafana`, `loki`, `alertmanager`, `homepage`, `it-tools`, `n8n`, `uptime-kuma`, `cloudflared`, `adguard-home`, and `wireguard` under `services/` — each Ansible role deploys its matching directory as-is, no duplicated config. `pbs` and `promtail` are native packages instead (no Docker involved).
* A Cloudflare Tunnel (`services/cloudflared/`) scaffolded to route `sisqueslabs.com` and `jsisques.net` to internal services — the ingress rules are in Git, but the tunnel itself still needs a one-time manual setup (see `services/cloudflared/README.md`) before it can run for real.
* A WireGuard VPN gateway (`services/wireguard/`) for internal-only remote access, AdGuard Home for network-wide DNS/ad-blocking, and Traefik (`services/traefik/`) as the internal reverse proxy that makes every `*.home.arpa` URL in `config/services.yaml` actually resolve to something. All three still need a one-time manual step outside Git (router port-forward + Dynamic DNS for WireGuard; AdGuard's first-run wizard plus one DNS rewrite pointing `*.home.arpa` at Traefik).
* Proxmox Backup Server (`ansible/roles/pbs/`), backing up onto the NAS over NFS — installed as a native package (not Docker), on its own VM. The Proxmox VE side (registering PBS as a storage backend, the actual backup job) is still a manual one-time step; see `ansible/roles/pbs/README.md`.
* A single-node K3s server (`ansible/roles/k3s/`) with Argo CD bootstrapped on top, empty and ready for `Application` resources. Kafka (via Strimzi, under `kubernetes/`) is defined but deliberately not applied yet — see `kubernetes/argocd/applications/kafka.yaml`'s header comment for why. Gardenia is planned as the first application-level Kubernetes workload, exposed publicly at `gardenia.sisqueslabs.com`, once there's a cluster with enough capacity for it.
* A NAS already exists on the local network (`config/hosts.yaml`) and now has a concrete first consumer (PBS's datastore); a general-purpose storage layer (S3-compatible, backups) on top of it is still planned.
* A public documentation site built with Astro/Starlight under `website/`, deployed to GitHub Pages.

None of this has been applied to real infrastructure yet — `terraform apply`/the `deploy.yaml` workflow have not been run. Treat everything above as "ready to deploy," not "deployed."

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
| Internal only | `*.home.arpa` | LAN / VPN only, never exposed to the internet | Grafana, Proxmox, Prometheus, Kafka, Uptime Kuma, Homepage, IT-Tools, n8n, AdGuard Home |
| Personal | `jsisques.net` | Personal-facing services, exposed via Cloudflare Tunnel | Personal apps/site |
| Public | `sisqueslabs.com` | Public homelab apps, exposed via Cloudflare Tunnel | Gardenia (Kubernetes) |

Each service's tier is declared explicitly via the `tier` field in `config/services.yaml` (see [`config/README.md`](config/README.md#tier)) — nothing is public by default.

`home.arpa` is the [RFC 8375](https://datatracker.ietf.org/doc/html/rfc8375) reserved name for home networks and is used for anything that should stay LAN/VPN-only — it never gets a public DNS record or a Cloudflare route. Resolution and TLS for it are handled entirely inside the network: AdGuard Home (`services/adguard-home/`) rewrites `*.home.arpa` to Traefik (`services/traefik/`), which terminates HTTPS (self-signed) and routes each hostname to its backend LXC by IP:port — see `services/traefik/README.md`. `jsisques.net` and `sisqueslabs.com` are both routed through the **same** Cloudflare Tunnel (`services/cloudflared/`), which terminates on a dedicated LXC and forwards each hostname to its internal target per `services/cloudflared/config.yml`. No inbound ports are opened on the home network for this.

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
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/          # generated from config/hosts.yaml, do not edit
│   ├── playbooks/
│   └── roles/
│       ├── common/  docker/  node-exporter/  promtail/
│       ├── it-tools/  n8n/  monitoring/  homepage/  uptime-kuma/
│       └── cloudflared/  adguard-home/  traefik/  wireguard/  pbs/  k3s/
│
├── kubernetes/
│   ├── argocd/
│   └── infrastructure/
│       └── kafka/
│
├── services/
│   ├── prometheus/  grafana/  loki/  alertmanager/
│   ├── homepage/  it-tools/  n8n/  uptime-kuma/
│   └── cloudflared/  adguard-home/  traefik/  wireguard/
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
├── .github/
│   └── workflows/
│
└── Makefile
```

## Deployment

The root `Makefile` wraps Terraform, Ansible, and the `config/` generators behind a small set of targets — run `make help` for the full list.

```bash
make generate           # regenerate everything derived from config/ (inventory, Terraform vars, Homepage, Prometheus)
make plan                # terraform plan
make apply                # terraform apply — provisions/updates every LXC and VM
make deploy               # apply + deploy EVERY service (Terraform apply, then the full Ansible site.yaml)
make deploy-n8n           # deploy a single service only (see `make services` for the full list)
make ping                 # check SSH/Ansible connectivity to every host
make validate              # Terraform + Ansible + YAML + shell + Compose checks, all in one
make status                # show current Terraform-managed infrastructure
```

`make deploy-<service>` works for any of `it-tools`, `n8n`, `monitoring` (Prometheus + Grafana + Loki + Alertmanager), `homepage`, `uptime-kuma`, `cloudflared`, `adguard-home`, `traefik`, `wireguard`, `pbs`, `k3s-server`, or `promtail` alone (run it against every host at once) — `make services` lists them, and it only runs that one playbook, not the whole fleet. `n8n`, `cloudflared`, and `monitoring` need their secrets in the environment first (`N8N_POSTGRES_PASSWORD`, `CLOUDFLARED_CREDS_JSON`, `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID`); see the matching role's README.

## Configuration

The `config/` directory contains the high-level desired state of the homelab. See [`config/README.md`](config/README.md) for the full model.

### Hosts

`config/hosts.yaml` describes the machines that should exist: the Proxmox hypervisor itself (IP not confirmed yet), the NAS, every LXC Terraform provisions (`monitoring`, `homepage`, `uptime-kuma`, `it-tools`, `n8n`, `cloudflared`), and the two Raspberry Pi K3s workers.

```yaml
hosts:
  it-tools:
    type: lxc
    platform: proxmox
    address: 192.168.1.23
    cpu: 2
    memory: 1024
    disk: 8
    role:
      - it-tools

  raspberrypi-01:
    type: physical
    platform: raspberry-pi
    address: 192.168.1.40
    role:
      - k3s
      - worker
```

`cpu`/`memory`/`disk` are only set on `lxc`/`vm` entries — Terraform needs them, physical hosts don't.

This is the **only** place addresses and sizing are written down. Two generators consume it, and neither is edited by hand:

* `scripts/generation/generate-terraform-vars.sh` → `terraform/proxmox/hosts.auto.tfvars.json` (`lxc_network` / `k3s_nodes`, auto-loaded by Terraform — no more copy-pasting IPs into `terraform.tfvars`).
* `scripts/generation/generate-inventory.sh` → `ansible/inventory/hosts.yml` (one group per host, plus one per `role` value — e.g. `k3s` groups both Raspberry Pis together).

A host with `address: TBD` (like `proxmox` today) is skipped by both, with a warning, instead of generating a broken config.

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

Terraform provisions infrastructure on Proxmox: virtual machines, LXC containers, CPU/memory/disk allocation, networking, and cloud-init metadata. It uses the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) provider (see `terraform/proxmox/`). Every LXC is provisioned generically from the `lxc_network` map (`for_each`), generated straight from `config/hosts.yaml` — adding a new service's LXC is a `config/hosts.yaml` entry, not new HCL.

Terraform defines **what infrastructure exists** — it does not configure the OS or deploy applications.

### Ansible

Ansible configures the operating systems and services running on provisioned hosts: users/SSH, packages, Docker, Node Exporter, firewall rules, and service deployment (see `ansible/roles/`).

Terraform answers *"what machines should exist?"*; Ansible answers *"how should those machines be configured?"*

## Kubernetes

K3s runs as a **single-node server** (`ansible/roles/k3s/`, VM `k3s-server` at `192.168.1.31`) — no workers yet. The two Raspberry Pis are already tagged `role: [k3s, worker]` in `config/hosts.yaml` for exactly that future, but actually joining them as K3s agents is a separate, not-yet-built step.

### Helm / Argo CD

Helm packages Kubernetes applications; Argo CD provides GitOps-based continuous delivery, reconciling what's committed to the repo with the running cluster. The `k3s` Ansible role installs Argo CD (`argocd` namespace) as part of provisioning the node, but applies no `Application` resources — it comes up empty. `kubernetes/argocd/projects/homelab.yaml` (the `AppProject` everything should use) is ready to apply; `kubernetes/argocd/applications/kafka.yaml` is **not** — see the comment at the top of that file for why (missing Strimzi operator wiring, more capacity needed than a single node has). See `ansible/roles/k3s/README.md` for how to reach the Argo CD UI.

## Observability

Observability is meant to be centralized rather than deploying a separate monitoring stack per application:

```text
                         Grafana
                       /    |    \
                      /     |     \
             Prometheus    Loki  Alertmanager
                 │          │       │
              Metrics      Logs   Alerts (Telegram)
```

Prometheus, Grafana, Loki, and Alertmanager all run on the shared `monitoring` LXC (`services/prometheus/`, `services/grafana/`, `services/loki/`, `services/alertmanager/`, deployed together by the `monitoring` Ansible role), attached to a common Docker network so they can reach each other by name. Prometheus's scrape config is generated from `config/services.yaml` by `scripts/generation/generate-prometheus.sh`; its alert rules (`services/prometheus/alerts.yml`) are hand-authored and fire into Alertmanager, which routes them to Telegram once `monitoring_alertmanager_telegram_bot_token`/`_chat_id` are set (see `ansible/roles/monitoring/README.md`) — without them, alerts still fire but land nowhere.

Host-level metrics and logs are non-negotiable: every Ansible service role depends on `node-exporter` and `promtail` (via `meta/main.yml`), so any LXC or VM deployed through Ansible ships both automatically, with no per-playbook opt-in. See `ansible/README.md`.

## Uptime Monitoring & Homepage

[Uptime Kuma](https://github.com/louislam/uptime-kuma) (`services/uptime-kuma/`) and [Homepage](https://gethomepage.dev/) (`services/homepage/`) both read from the same service catalog conceptually, but only Homepage is actually generated from `config/services.yaml` today (`scripts/generation/generate-homepage.sh`) — Uptime Kuma has no config-as-code format, so its monitors are still created by hand through its UI.

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

Storage is split across Proxmox disks, Kubernetes persistent volumes (`local-path`, node-local), and Docker named volumes for standalone services. The NAS on the local network has its first concrete role: Proxmox Backup Server (`ansible/roles/pbs/`) mounts an NFS export from it as its datastore, so LXC/VM backups live off the host they protect. A general-purpose storage layer on top of the NAS — an S3-compatible object store (evaluating [rustfs](https://rustfs.com/) over MinIO) plus Restic/Borg for backups of anything outside Proxmox's own backup scope — is still planned. See [`docs/storage.md`](docs/storage.md) for details and rules.

## Secrets

Secrets should never be committed in plaintext. Sensitive configuration will use mechanisms such as SOPS, Age, Ansible Vault, Kubernetes Secrets, or External Secrets. Public configuration remains in Git while sensitive values remain encrypted or externally referenced.

## Roadmap / Planned Services

Scaffolded so far: monitoring (Prometheus/Grafana/Loki/Alertmanager), n8n, it-tools, uptime-kuma, Cloudflare Tunnel, WireGuard, AdGuard Home, Traefik, Proxmox Backup Server, a single-node K3s server with Argo CD. The next priorities:

* **K3s workers** — join the two Raspberry Pis (`config/hosts.yaml` already tags them `role: [k3s, worker]`) as K3s agents, giving the cluster real capacity. Needed before Kafka or Gardenia can actually run.
* **Kafka on K3s** — the manifests exist (`kubernetes/infrastructure/kafka/`) but need the Strimzi operator wired into the main kustomization first (see the comment in `kubernetes/argocd/applications/kafka.yaml`) and workers in place.
* **NAS-backed application storage** — PBS now uses the NAS for backups; a general S3-compatible layer on top of it (evaluating [rustfs](https://rustfs.com/) over MinIO) for application data is still open.
* **Vaultwarden** — self-hosted, Bitwarden-compatible password manager.
* **Authelia / Authentik** — SSO in front of exposed apps.
* **CrowdSec** — collaborative IPS/IDS reading logs from the exposed services (Cloudflared, AdGuard, Traefik).
* **OPNsense** (router/firewall) — on hold pending a check of the Proxmox host's actual NIC situation; it needs to sit inline as the real gateway, unlike everything else here, so it's being treated as a separate, more careful project rather than bolted on alongside routine services.

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
* [Cloudflare Tunnel](services/cloudflared/README.md) — one-time setup + ingress rules
* Public documentation site: `website/` (Astro/Starlight, deployed via GitHub Pages)

---

## License

Personal homelab infrastructure and configuration. Use at your own risk.
