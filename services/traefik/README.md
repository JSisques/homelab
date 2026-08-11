# Traefik

Internal reverse proxy for every `tier: internal` service — the piece that makes `https://grafana.home.arpa`, `https://n8n.home.arpa`, etc. (already the `url:` in `config/services.yaml`, and already what those apps' own compose files assume — see e.g. `GF_SERVER_ROOT_URL` in `services/grafana/compose.yaml`) actually resolve to something, instead of nowhere.

## Responsibilities

- Terminate HTTPS for `*.home.arpa` (self-signed — see below) and redirect plain HTTP to it.
- Route each hostname to its backend by LAN IP:port (`dynamic/routes.yml`) — Traefik runs on its own LXC, so it can't discover other services' containers via Docker labels the way a same-host Traefik setup normally would. Every backend is listed explicitly.
- Expose its own dashboard at `https://traefik.home.arpa` and Prometheus metrics on `:8082`.

## Directory Structure

```text
services/traefik/
├── README.md
├── compose.yaml
├── traefik.yml          # static config
└── dynamic/
    └── routes.yml        # routers + backend addresses — generated
```

## Configuration

`dynamic/routes.yml` is **generated** from the central service and host catalogs and must not be edited by hand:

```text
config/services.yaml, config/hosts.yaml
        │
        ▼
scripts/generation/generate-traefik.sh
        │
        ▼
services/traefik/dynamic/routes.yml
```

A service gets a router + backend automatically once it declares a `traefik: {enabled: true, port: <n>}` block in `config/services.yaml` (see grafana, prometheus, homepage, uptime-kuma, it-tools, n8n, adguard-home for examples). The router's hostname comes from that service's own `url:`; the backend address comes from `config/hosts.yaml` — a host whose key matches the service name directly, or (for services like Grafana/Prometheus that share the `monitoring` host rather than getting one of their own) whose `role` list includes the service name.

## One-time setup: point `*.home.arpa` at Traefik

Nothing resolves these hostnames until AdGuard Home is told to. AdGuard Home has no config-as-code path (see `services/adguard-home/README.md`), so this is manual, once:

1. Open AdGuard Home's UI (`http://192.168.1.26:3000` until Traefik itself is up, `https://adguard.home.arpa` after).
2. **Filters → DNS rewrites → Add**.
3. Domain: `*.home.arpa`, Answer: `192.168.1.28` (Traefik's address).

Every hostname in `dynamic/routes.yml` will resolve from then on for any client using AdGuard as its DNS server.

## TLS

Routers request TLS with an empty `tls: {}`, which makes Traefik hand out its own auto-generated self-signed certificate — zero config, but every browser will warn on first visit. That's expected for now. Trust the cert manually per device, or replace this with a real internal CA later; either way it's a `dynamic/routes.yml`-level change, not a redesign.

## Adding a new internal service

1. Add a `traefik: {enabled: true, port: <n>}` block to that service's entry in `config/services.yaml` (its `url:` and the matching entry/role in `config/hosts.yaml` must already exist).
2. Run `./scripts/generation/generate-traefik.sh` (or `make generate`) and commit the regenerated `dynamic/routes.yml`.
3. Deploy — Traefik picks up the new file automatically (`providers.file.watch: true` in `traefik.yml`, no restart needed).
4. Make sure the hostname is covered by the `*.home.arpa` AdGuard rewrite above (it already is, for anything under `.home.arpa`).

## Deployment

Terraform creates the `traefik` LXC (`terraform/proxmox/lxc.tf`, via `config/hosts.yaml`). Ansible deploys this Compose file (see `ansible/roles/traefik/`).

## Local Development

```bash
cd services/traefik
docker compose up -d
```
