# Traefik

The single reverse proxy for everything Cloudflare Tunnel forwards in — `tier: personal`/`tier: public` services (`*.jsisques.net`, `*.sisqueslabs.com`), including a service's `external:` alias (see `config/README.md#external`). `tier: internal` services never go through Traefik: they're plain LAN `IP:port`, linked straight from Homepage.

```text
Cloudflared -> Traefik -> backend (LXC/VM/K3s NodePort, by IP:port)
```

## Responsibilities

- Receive plain HTTP on `:80` from Cloudflared (`services/cloudflared/`) — Cloudflare Tunnel already encrypts the public leg up to the cloudflared LXC, so this internal LAN hop doesn't need its own TLS.
- Route each hostname to its backend by LAN IP:port (`dynamic/routes.yml`) — Traefik runs on its own LXC, so it can't discover other services' containers via Docker labels the way a same-host Traefik setup normally would. Every backend is listed explicitly.
- Expose its own dashboard and Prometheus metrics like any other internal-tier service — by IP:port, no domain (`api.insecure: true` on `:8080`, metrics on `:8082`).

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

A service gets a router + backend automatically once it declares a `traefik: {enabled: true, port: <n>}` block in `config/services.yaml` — either at the top level (its own `tier: personal`/`tier: public`, e.g. Blog, Sisques Labs Landing, Days Off) or nested under `external:` (a service that's `tier: internal` day-to-day but also has a remote-access alias, e.g. Jellyfin). The router's hostname comes from that exposure's `url:`; the backend address comes from `config/hosts.yaml` — a host whose key matches the service name directly, or (for services that share a host rather than getting one of their own) whose `role` list includes the service name.

`services/cloudflared/config.yml` is generated from the same catalog (`generate-cloudflared.sh`) and always points every hostname at Traefik's own LAN address — never at the backend directly.

## TLS

None, by design, on the Cloudflared → Traefik hop: Cloudflare Tunnel terminates and encrypts the public side, so plain HTTP on `:80` between cloudflared and Traefik (both on the trusted LAN) adds no real risk and avoids self-signed-cert / trust-store hassle entirely.

## Adding a new personal/public service

1. Set `tier: personal` or `tier: public` on the service in `config/services.yaml` (or add an `external:` block if it stays `tier: internal` for LAN access), with a `traefik: {enabled: true, port: <n>}` block and its `url:`.
2. Make sure the backend host/role is resolvable in `config/hosts.yaml`.
3. Run `make generate` (regenerates both `dynamic/routes.yml` and `services/cloudflared/config.yml`) and commit.
4. Add the matching Cloudflare DNS CNAME record — see `services/cloudflared/README.md`.
5. Deploy — Traefik picks up the new file automatically (`providers.file.watch: true` in `traefik.yml`, no restart needed).

## Deployment

Terraform creates the `traefik` LXC (`terraform/proxmox/lxc.tf`, via `config/hosts.yaml`). Ansible deploys this Compose file (see `ansible/roles/traefik/`).

## Local Development

```bash
cd services/traefik
docker compose up -d
```
