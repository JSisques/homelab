# WireGuard Easy

Self-hosted VPN gateway with a management dashboard ([wg-easy](https://github.com/wg-easy/wg-easy)) for remote, internal-only access to the homelab — this is how `tier: internal` services (plain LAN `IP:port`, no domain) get reached from outside the LAN without ever going through the Cloudflare Tunnel.

## Responsibilities

- Terminate WireGuard connections from road-warrior clients (phone, laptop)
- Route those clients into the LAN subnet so they can reach every LXC on the LAN by IP:port
- Provide a web dashboard (`http://192.168.0.203:51821`) to create, enable/disable, and revoke client peers — no more hand-editing a fixed `PEERS=N` count

## Directory Structure

```text
services/wireguard/
├── README.md
└── compose.yaml
```

## Before deploying this — things only you can do

1. **Port-forward UDP 51820** on your router to this LXC's address (`config/hosts.yaml`). Do **not** forward TCP 51821 (the dashboard) — it's plain HTTP with no TLS in front of it, LAN-only by design (`tier: internal`).
2. Have a hostname that resolves to your home's public IP ready (Dynamic DNS if your ISP doesn't give you a static one) — you'll enter it during first-run setup, not in this repo.

## First-run setup

wg-easy v15 moved all of this out of environment variables and into an onboarding wizard on first visit to the dashboard — there's no `WG_HOST`/`PASSWORD_HASH`/`PEERS` to set in `compose.yaml` anymore:

1. Open `http://192.168.0.203:51821` and create the admin account.
2. Set the WireGuard host/endpoint to your public hostname (see above).
3. Set the default client DNS to both AdGuard Home instances (`192.168.0.201`, `192.168.0.202`) so peers get ad-blocking and DNS redundancy.
4. Create client peers from the dashboard — QR code and config file are both downloadable per client.

None of this can be automated from here — it's a one-time interactive step tied to your account/domain, not derived config.

## Networking

`compose.yaml` gives the container its own bridge network (`10.42.42.0/24` / `fdcc:ad94:bacf:61a3::/64`) per wg-easy's own recommendation, plus `NET_ADMIN`/`SYS_MODULE` and the sysctls it needs to forward traffic. `INSECURE=true` is required because the dashboard is served over plain HTTP on the LAN (`tier: internal`) — v15 refuses to serve the UI over HTTP without it.

This is the piece most likely to need hands-on debugging on real hardware — if VPN clients can reach the WireGuard host but nothing else on the LAN, check that IPv4 forwarding is on (already set via sysctls) and that the Proxmox firewall isn't blocking forwarded traffic from the LXC.

## Deployment

Terraform creates the `wireguard` LXC (`terraform/proxmox/lxc.tf`). Ansible deploys this Compose file (see `ansible/roles/wireguard/`).

## Local Development

```bash
cd services/wireguard
docker compose up -d
```
