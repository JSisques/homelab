# WireGuard

Self-hosted VPN gateway ([linuxserver/wireguard](https://docs.linuxserver.io/images/docker-wireguard/)) for remote, internal-only access to the homelab — this is how `tier: internal` (`*.home.arpa`) services get reached from outside the LAN without ever going through the Cloudflare Tunnel.

## Responsibilities

- Terminate WireGuard connections from road-warrior clients (phone, laptop)
- Route those clients into the LAN subnet (`ALLOWEDIPS`, `config/hosts.yaml`'s `network.lan`) so they can reach every LXC on the LAN
- Hand out AdGuard Home as the DNS server (`PEERDNS`), so VPN clients resolve `*.home.arpa` and get ad-blocking too

## Directory Structure

```text
services/wireguard/
├── README.md
└── compose.yaml
```

No `.env.example` — `PEERDNS`/`ALLOWEDIPS` aren't secrets, just derived config; see Networking below for where they actually come from.

## Before deploying this — things only you can do

1. **Replace `SERVERURL`** in `compose.yaml`. It has to be a hostname that resolves to your home's public IP. If your ISP doesn't give you a static IP, this needs Dynamic DNS (most consumer routers support one of the common providers) rather than a fixed value.
2. **Port-forward UDP 51820** on your router to this LXC's address (`config/hosts.yaml`).

None of this can be automated from here — it depends on hardware (the router) this repo doesn't manage.

## Getting client configs

`PEERS=5` makes the container generate 5 client configs (and matching QR codes) on first start, under the `wireguard-config` volume at `/config/peer1` … `/config/peer5`. Pull one out with:

```bash
docker compose cp wireguard:/config/peer1/peer1.conf ./peer1.conf
# or scan /config/peer1/peer1.png directly from the LXC
```

## Networking

`ALLOWEDIPS` tells connected clients to route all LAN-bound traffic through the tunnel, and the container NATs that traffic onto the LAN bridge on their behalf. Neither `ALLOWEDIPS` nor `PEERDNS` is hardcoded here — `compose.yaml` reads them from a `.env` that the Ansible role renders (`ansible/roles/wireguard/templates/env.j2`) from:

- `ALLOWEDIPS` ← `lan_cidr`, an Ansible inventory var generated from `config/hosts.yaml`'s `network.lan` block (`scripts/generation/generate-inventory.sh`).
- `PEERDNS` ← `hostvars['adguard-home'].ansible_host`, AdGuard Home's resolved LAN address.

So changing the LAN subnet (`config/hosts.yaml`'s `network.lan.prefix`) or AdGuard Home's address doesn't need a `compose.yaml` edit — re-running Ansible picks up both automatically.

This is the piece most likely to need hands-on debugging on real hardware — if VPN clients can reach the WireGuard host but nothing else on the LAN, check `net.ipv4.conf.all.src_valid_mark` (already set) and that the Proxmox firewall isn't blocking forwarded traffic from the LXC.

## Deployment

Terraform creates the `wireguard` LXC (`terraform/proxmox/lxc.tf`). Ansible deploys this Compose file and its `.env` (see `ansible/roles/wireguard/`).

## Local Development

```bash
cd services/wireguard
ALLOWEDIPS=192.168.0.0/24 PEERDNS=192.168.0.26 docker compose up -d
```
