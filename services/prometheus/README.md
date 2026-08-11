# Prometheus

Prometheus is the metrics collection and storage engine for the homelab.

It scrapes the targets defined in `prometheus.yml` and stores time-series data used by Grafana dashboards.

## Directory Structure

```text
services/prometheus/
├── README.md
├── compose.yaml
└── prometheus.yml
```

## Configuration

`prometheus.yml` is **generated** from the central service catalog and must not be edited by hand:

```text
config/services.yaml
        │
        ▼
scripts/generation/generate-prometheus.sh
        │
        ▼
services/prometheus/prometheus.yml
```

Any service with `monitoring.enabled: true` and `monitoring.type: prometheus` in `config/services.yaml` gets a scrape job automatically.

## Deployment

Prometheus is deployed by Ansible onto the shared `monitoring` LXC (see `ansible/roles/monitoring/`), alongside Grafana.

## Local Development

```bash
cd services/prometheus
docker compose up -d
```

Prometheus will be available at `http://localhost:9090`.

## Persistence

Metrics are stored in the `prometheus-data` Docker volume. See [`docs/storage.md`](../../docs/storage.md).
