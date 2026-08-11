# Prometheus

Prometheus is the metrics collection and storage engine for the homelab. Every service in the homelab ends up scraped one of three ways — see [Coverage](#coverage) below.

It scrapes the targets defined in `prometheus.yml` and stores time-series data used by Grafana dashboards. Alerts are evaluated against `alerts.yml` and routed to Alertmanager.

## Directory Structure

```text
services/prometheus/
├── README.md
├── compose.yaml
├── prometheus.yml          # generated — do not edit
├── alerts.yml              # hand-authored
└── blackbox-targets.yml    # generated — do not edit
```

## Configuration

`prometheus.yml` is **generated** from the central service and host catalogs and must not be edited by hand:

```text
config/services.yaml, config/hosts.yaml
        │
        ▼
scripts/generation/generate-prometheus.sh
        │
        ▼
services/prometheus/prometheus.yml
```

## Coverage

Every service and host in the homelab is scraped one of three ways:

1. **Native `/metrics`** — any service with `monitoring.enabled: true` and `monitoring.type: prometheus` in `config/services.yaml` gets a scrape job automatically.
2. **Host-level agents** — every `type: lxc`/`type: vm` host in `config/hosts.yaml` gets `node-exporter` (`:9100`) and `promtail` (`:9080`) scrape targets automatically, since both are a mandatory Ansible baseline on every host (see [`ansible/README.md`](../../ansible/README.md)) regardless of which application is deployed there.
3. **blackbox_exporter** — services with an HTTP(S) UI but no native `/metrics` (e.g. IT-Tools, n8n, AdGuard Home) are probed for up/down + latency instead. Targets live in `blackbox-targets.yml`, generated from each service's `blackbox:` block in `config/services.yaml` by `scripts/generation/generate-blackbox.sh`, see [`../blackbox-exporter/README.md`](../blackbox-exporter/README.md).

## Deployment

Prometheus is deployed by Ansible onto the shared `monitoring` LXC (see `ansible/roles/monitoring/`), alongside Grafana, Loki, Alertmanager, and blackbox_exporter.

## Local Development

```bash
cd services/prometheus
docker compose up -d
```

Prometheus will be available at `http://localhost:9090`.

## Persistence

Metrics are stored in the `prometheus-data` Docker volume. See [`docs/storage.md`](../../docs/storage.md).
