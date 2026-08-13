# AdGuard Home

[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) is the homelab's network-wide DNS resolver and ad/tracker blocker.

## Responsibilities

- DNS resolution for the LAN and for VPN clients (see `services/wireguard/`)
- Ad and tracker blocking at the DNS level, network-wide
- Per-client rules and query log

AdGuard Home is not a general-purpose reverse proxy or firewall — it only handles DNS.

## Directory Structure

```text
services/adguard-home/
├── README.md
└── compose.yaml
```

## Configuration

AdGuard Home has no declarative config file suitable for generation from `config/services.yaml` — like Uptime Kuma, its setup wizard and settings live entirely in its own persistent volumes (`adguard-work`, `adguard-conf`). First boot walks through a setup wizard on port `3000` (admin username/password, upstream DNS, which network interfaces to listen on).

Once that's done, add one DNS rewrite so `*.home.arpa` resolves to Traefik instead of nowhere — **Filters → DNS rewrites**, domain `*.home.arpa`, answer `192.168.0.204`. See `services/traefik/README.md`.

## Networking

- `53/tcp` + `53/udp` — DNS
- `3000/tcp` — admin UI (also the first-run setup wizard)

Point the router's DHCP-assigned DNS server, and/or each client, at this LXC's IP. Internal-only per the domain tiers in the root README — never exposed through the Cloudflare Tunnel.

## Deployment

Terraform creates the `adguard-home` LXC (`terraform/proxmox/lxc.tf`). Ansible deploys this Compose file (see `ansible/roles/adguard-home/`).

## Local Development

```bash
cd services/adguard-home
docker compose up -d
```

AdGuard Home's setup wizard will be available at `http://localhost:3000`.
