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

`conf/AdGuardHome.yaml` is **not** in this directory. Ansible seeds it on the host once (see `ansible/roles/adguard-home/`) so the first-run wizard is skipped: admin credentials from `ADGUARD_SYNC_*`, UI on port `80`, and a DNS rewrite of `*.home.arpa` to Traefik. After that, AdGuard owns the file and later deploys leave it alone.

## Configuration

The seed covers only what Git must own (credentials, listen ports, the Traefik rewrite). Blocklists, clients, and other UI settings live in that host file and are copied from `adguard-home-1` to `adguard-home-2` by `adguard-home-sync`.

`compose.yaml` still publishes `3000` so a local `docker compose up` without a seeded `conf/` can run the wizard. On a real host with the Ansible seed, the UI is on `80` from the first start.

## Networking

- `53/tcp` + `53/udp` — DNS
- `3000/tcp` — first-run setup wizard only (unused when `conf/AdGuardHome.yaml` already exists)
- `80/tcp` — admin UI / API

Point the router's DHCP-assigned DNS server, and/or each client, at this LXC's IP. Internal-only per the domain tiers in the root README — never exposed through the Cloudflare Tunnel.

## Deployment

Terraform creates the `adguard-home` LXC (`terraform/proxmox/lxc.tf`). Ansible seeds the config and deploys this Compose file (see `ansible/roles/adguard-home/`).

## Local Development

```bash
cd services/adguard-home
docker compose up -d
```

Without a pre-seeded `conf/AdGuardHome.yaml`, AdGuard Home's setup wizard will be available at `http://localhost:3000`.
