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
2. Have a hostname that resolves to your home's public IP ready (Dynamic DNS if your ISP doesn't give you a static one — see below) — you'll enter it during first-run setup, not in this repo.

## Dynamic DNS

Most residential ISPs hand out a dynamic public IP, so a plain IP in wg-easy's `Host` setting will eventually go stale and silently break every client (they keep trying to reach an address that's no longer yours). Point wg-easy at a DDNS hostname instead so it survives an IP change:

1. Create a free hostname with a DDNS provider your router supports (e.g. [No-IP](https://www.noip.com/) — `DDNS y acceso remoto` → `DNS Records` → `Crear nombre de host`, type `A`, pointing at your current public IP). Tick **Enable Dynamic DNS** on the record so it accepts updates.
2. On the router, configure the matching DDNS client (`DNS & DDNS` on Sercomm/Vodafone routers): provider, the hostname from step 1, and the DDNS account credentials. Apply, and confirm the status shows as updated — this is what keeps the record in sync automatically when your IP changes.
3. In the wg-easy dashboard (`Configuración` → `Host`), set the hostname from step 1 instead of a raw IP.
4. Re-download (or re-scan the QR for) every existing client peer so its `Endpoint` picks up the new hostname — peers created before this change keep whatever `Host` was set at the time.

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

If a client never connects at all (`docker exec wg-easy wg show` reports `latest handshake: (none)` for its peer), no UDP packet is reaching the container — that's upstream of Docker/WireGuard entirely. Check in this order: the router's port-forward rule is UDP (not TCP) 51820 → the wireguard LXC; the `Host` in wg-easy's `Configuración` matches your actual current public IP (see Dynamic DNS above); the client's `Endpoint` was generated after `Host` was set correctly (re-download the config otherwise). If all of that checks out and it's still stuck, try the client on a different network — some mobile carriers throttle or block outbound UDP on non-standard ports.

## Deployment

Terraform creates the `wireguard` LXC (`terraform/proxmox/lxc.tf`). Ansible deploys this Compose file (see `ansible/roles/wireguard/`).

## Local Development

```bash
cd services/wireguard
docker compose up -d
```
