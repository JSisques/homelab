# Loki

[Loki](https://grafana.com/oss/loki/) is the log aggregation backend for the homelab, paired with Grafana for querying/visualization and Promtail as the log-shipping agent running on every host.

## Responsibilities

- Store logs shipped by Promtail from every LXC/VM (`ansible/roles/promtail/`)
- Serve as a Grafana datasource (`services/grafana/config/provisioning/datasources/loki.yaml`)

Loki is not responsible for metrics (Prometheus) or alerting (Alertmanager).

## Directory Structure

```text
services/loki/
├── README.md
├── compose.yaml
└── config.yml
```

Single-binary mode, filesystem storage, 7-day retention (`limits_config.retention_period` in `config.yml`) — plenty for a homelab, adjust to taste.

## Networking

Loki, Prometheus, Grafana, and Alertmanager all attach to a shared external Docker network named `monitoring` (created once by the Ansible role) so they can reach each other by container name — `http://loki:3100`, `http://prometheus:9090`, etc. Each is still deployed as its own Compose project.

## Deployment

Deployed by the `monitoring` Ansible role alongside Prometheus, Grafana, and Alertmanager onto the shared `monitoring` LXC.
