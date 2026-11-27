# ADR-0010: VPN-only access

- **Status:** Accepted. VPN layout proposed
- **Date:** 2026-11-27

## Decision

1. **Everything is reached through WireGuard.** Nothing is published to the internet unless there is no alternative.
2. **cloudflared is out of scope** until a self-developed app needs to be published (YAGNI).
3. **Access restrictions are enforced on the server, in Git**, never in client profiles and never by clicking in a web UI.

**Proposed:** two VPNs, one per trust level.

| VPN | Domain | Who | Reaches |
|-----|--------|-----|---------|
| Admin | `network` | The owner | Everything |
| Friends | `games` | Friends playing Minecraft | Only the `games` LXC containers, enforced by the server's firewall |

## Context

Friends join the Minecraft server through a VPN profile the owner hands out. The previous repository used `wg-easy` v15: allowed IPs were set in its web UI (not in Git), `net.ipv4.ip_forward=1` was enabled, and no firewall rule existed in the role or Compose file.

A client's `AllowedIPs` only tells the client what to route. **What lives on someone else's computer is controlled by them**: a friend who edits it to `192.168.0.0/24` reaches the whole LAN, including Proxmox and the NAS.

The free Cloudflare Tunnel was checked: it publishes only HTTP/HTTPS. Raw TCP such as Minecraft requires `cloudflared` on every client or paid Cloudflare Spectrum. With every other service behind the VPN, cloudflared has no job today.

## Consequences

- Smallest possible public surface: only the WireGuard UDP ports on the router.
- Removing `games/` removes the friends VPN with it.
- Two VPNs mean two router port forwards.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| One VPN with two IP ranges and per-range firewall rules | One port fewer, but a mistake in one rule puts friends inside the admin network |
| Restrict friends through their client profile | They control it |
