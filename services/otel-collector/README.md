# OTel Collector

The [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) (`otelcol-contrib`) is the OTLP ingestion point for homelab applications that export traces/metrics/logs via OpenTelemetry — currently `cookidoo-mcp` — and fans them out to the existing observability stack.

## Responsibilities

- Receive OTLP (gRPC `:4317` / HTTP `:4318`) from applications on the LAN.
- Expose received metrics on a Prometheus-scrapeable endpoint (`:8889/metrics`) — Prometheus pulls from the collector, the collector never pushes to Prometheus (no `remote-write-receiver` flag needed on the shared Prometheus instance).
- Forward logs to Loki's native OTLP endpoint (`http://loki:3100/otlp`).
- Forward traces to Tempo (`services/tempo/`) over OTLP gRPC.

The Collector is not itself a dashboard or storage backend — Grafana, Prometheus, Loki, and Tempo remain the systems of record.

## Directory Structure

```text
services/otel-collector/
├── README.md
├── compose.yaml
└── config.yaml
```

## Networking

Published on the LXC host (`192.168.0.209:4317`/`4318`) so applications on other LXCs (e.g. `cookidoo-mcp` at `192.168.0.212`) can reach it over the LAN. Also attached to the shared `monitoring` Docker network so it can reach `loki` and `tempo` by container name.

## Deployment

Deployed by the `monitoring` Ansible role alongside Prometheus, Grafana, Loki, Alertmanager, and Tempo onto the shared `monitoring` LXC.

## Adding another OTel-instrumented service

Point its `OTEL_EXPORTER_OTLP_ENDPOINT` at `http://192.168.0.209:4318` — no changes needed here unless a new signal type or exporter is required.
