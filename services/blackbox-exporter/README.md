# blackbox_exporter

Probes services that have no native Prometheus `/metrics` endpoint (a static tools page, a DNS admin UI, a backup server's web console, ...) so they still show up in Prometheus with basic up/down status and request latency.

Runs on the shared `monitoring` LXC alongside Prometheus, Grafana, Loki, and Alertmanager (see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md)), on the shared `monitoring` Docker network.

## How it fits together

Prometheus scrapes `blackbox-exporter:9115/probe` with the target and module passed as query params, rather than scraping the target directly. The target list lives in [`../prometheus/blackbox-targets.yml`](../prometheus/blackbox-targets.yml), a hand-authored `file_sd_config` — Prometheus watches this file directly, so adding a target only needs a Prometheus reload (or `docker compose restart prometheus`), not a full `make generate`.

`scripts/generation/generate-prometheus.sh` emits a static `blackbox` scrape job (relabeling `__address__`/`__param_target`/`instance`/`__param_module`) that points at that file — see that script and [`../prometheus/README.md`](../prometheus/README.md).

## Modules (`config.yml`)

- `http_2xx` — standard HTTP probe, expects any 2xx response. Used for services with valid TLS or plain HTTP.
- `http_2xx_insecure` — same, but skips TLS certificate verification and accepts any status code. Used for self-signed backends (Proxmox Backup Server, the K3s apiserver) where even a 401/403 response proves the service is up.
- `tcp_connect` — plain TCP connect probe, for non-HTTP services. Not currently used by any target but available.

## Adding a target

Add an entry to [`../prometheus/blackbox-targets.yml`](../prometheus/blackbox-targets.yml) under the group matching the module you need (or add a new group). No script or generator needs to change.

## Deployment

Deployed by the `monitoring` Ansible role — see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md).
