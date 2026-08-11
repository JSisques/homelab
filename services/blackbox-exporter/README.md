# blackbox_exporter

Probes services that have no native Prometheus `/metrics` endpoint (a static tools page, a DNS admin UI, a backup server's web console, ...) so they still show up in Prometheus with basic up/down status and request latency.

Runs on the shared `monitoring` LXC alongside Prometheus, Grafana, Loki, and Alertmanager (see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md)), on the shared `monitoring` Docker network.

## How it fits together

Prometheus scrapes `blackbox-exporter:9115/probe` with the target and module passed as query params, rather than scraping the target directly. The target list lives in [`../prometheus/blackbox-targets.yml`](../prometheus/blackbox-targets.yml), a generated `file_sd_config` — Prometheus watches this file directly, so a reload (or `docker compose restart prometheus`) picks up changes without a Prometheus restart, but the file itself is produced by `scripts/generation/generate-blackbox.sh` from `config/services.yaml`/`config/hosts.yaml` and should not be hand-edited.

`scripts/generation/generate-prometheus.sh` emits a static `blackbox` scrape job (relabeling `__address__`/`__param_target`/`instance`/`__param_module`) that points at that file — see that script, `scripts/generation/generate-blackbox.sh`, and [`../prometheus/README.md`](../prometheus/README.md).

## Modules (`config.yml`)

- `http_2xx` — standard HTTP probe, expects any 2xx response. Used for services with valid TLS or plain HTTP.
- `http_2xx_insecure` — same, but skips TLS certificate verification and accepts any status code. Used for self-signed backends (Proxmox Backup Server, the K3s apiserver) where even a 401/403 response proves the service is up.
- `tcp_connect` — plain TCP connect probe, for non-HTTP services. Not currently used by any target but available.

## Adding a target

Add a `blackbox: {enabled: true, port: <n>, scheme: http|https, module: <name>}` block to the service's entry in `config/services.yaml` and run `make generate` (or `./scripts/generation/generate-blackbox.sh` directly) — do not hand-edit [`../prometheus/blackbox-targets.yml`](../prometheus/blackbox-targets.yml), it's regenerated from that catalog. The backend address is resolved from `config/hosts.yaml` the same way Traefik does it (host key first, then `role`).

## Deployment

Deployed by the `monitoring` Ansible role — see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md).
