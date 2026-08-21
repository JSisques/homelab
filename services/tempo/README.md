# Tempo

[Grafana Tempo](https://grafana.com/oss/tempo/) is the trace storage backend for the homelab, fed by the OTel Collector (`services/otel-collector/`) and queried from Grafana.

## Responsibilities

- Receive traces over OTLP gRPC (`:4317`, internal to the `monitoring` Docker network only — not published on the host).
- Store them locally (`storage.trace.backend: local`, `tempo.yaml`) with a 48h retention (`compactor.compaction.block_retention`).
- Serve as a Grafana datasource (`services/grafana/config/provisioning/datasources/tempo.yaml`).

Tempo is not responsible for metrics (Prometheus) or logs (Loki).

## Directory Structure

```text
services/tempo/
├── README.md
├── compose.yaml
└── tempo.yaml
```

## Networking

Tempo only needs to be reachable by the OTel Collector and Grafana, both on the same shared `monitoring` Docker network — no host port is published.

## Persistence

Trace data lives in the `tempo-data` Docker volume (`/var/tempo`). Given the 48h retention this is disposable operational data, not covered by the homelab backup scope (see [`docs/storage.md`](../../docs/storage.md)).

## Deployment

Deployed by the `monitoring` Ansible role alongside Prometheus, Grafana, Loki, Alertmanager, and the OTel Collector onto the shared `monitoring` LXC.
