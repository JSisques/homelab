# Uptime Kuma

[Uptime Kuma](https://github.com/louislam/uptime-kuma) monitors the availability of homelab services and alerts on downtime.

## Responsibilities

- Availability / uptime monitoring for services with `uptime.enabled: true` in `config/services.yaml`
- Status page and downtime notifications

Uptime Kuma is not responsible for metrics collection (Prometheus) or dashboards (Grafana).

## Directory Structure

```text
services/uptime-kuma/
├── README.md
└── compose.yaml
```

## Persistence

Uptime Kuma stores monitors, history, and settings in the `uptime-kuma-data` Docker volume, mounted at `/app/data`. This volume must be included in backups — see [`docs/storage.md`](../../docs/storage.md).

## Configuration

Unlike Homepage and Prometheus, Uptime Kuma has no declarative configuration file — monitors are created through its web UI (or its API). There is no generator script for it yet; adding a service to `config/services.yaml` with `uptime.enabled: true` currently only documents the intent, it does not create the monitor automatically.

## Networking

Uptime Kuma is exposed through the homelab reverse proxy:

```text
https://uptime.home.arpa
```

The internal Docker port is `3001`.

## Deployment

Terraform creates the `uptime-kuma` LXC (`terraform/proxmox/lxc.tf`). Ansible deploys this Compose file (see `ansible/roles/uptime-kuma/`).

## Local Development

```bash
cd services/uptime-kuma
docker compose up -d
```

Uptime Kuma will be available at `http://localhost:3001`.
