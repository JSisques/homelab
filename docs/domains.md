# Domains

A **domain** is a folder in this repository and a functional area of the homelab. A domain can contain several LXC containers when the grouping rule requires it.

> **Status: proposed.** `monitoring`, `tools`, and `downloads` (here `media`) were chosen by the owner, and `platform` was confirmed ([ADR-0017](decisions/0017-platform-includes-the-host.md)). The remaining domains are recommendations pending confirmation ([open questions](open-questions.md)).

## Grouping rule

From [ADR-0002](decisions/0002-lxc-grouping-rule.md):

- **Group** services in the same LXC when they share a functional domain.
- **Never group** replicas that exist for redundancy, or services that accept connections from the internet.
- **Always** set CPU and memory limits per container when grouping.

## Catalog

`|` separates LXC containers inside the same domain.

| Domain | LXC containers | Why it is split |
|--------|----------------|-----------------|
| `platform` | Proxmox host (`answer.toml`, host configuration), LXC base, and inside every LXC: common base, Docker, Grafana Alloy | — |
| `control` | deploy agent | — |
| `monitoring` | prometheus, grafana, loki, alertmanager, tempo, otel-collector, uptime-kuma | — |
| `network` | adguard-home-1 \| adguard-home-2 + adguard-home-sync \| traefik + homepage \| wireguard | DNS replicas (redundancy); WireGuard accepts internet connections |
| `media` | jellyfin \| downloads (qbittorrent, prowlarr, sonarr, radarr, pyload, metube) | qBittorrent accepts peer connections from the internet |
| `tools` | it-tools, stirling-pdf | — |
| `automation` | n8n | — |
| `ai` | engram, cookidoo-mcp | — |
| `storage` | rustfs \| pbs | PBS must be a VM |
| `games` | minecraft + friends VPN \| soulfire | Minecraft is reached by people outside the household |

### What goes in `platform`

**The ground every domain stands on**: the Proxmox host, what creates an empty LXC, and what is installed inside every LXC. Anything that runs in one place and is reached over the network belongs to a domain, even if every other service uses it. Traefik and Prometheus are used by everything, and they live in `network` and `monitoring`.

## Removed from the old repository

| Item | Reason |
|------|--------|
| Kubernetes, k3s, Argo CD, Rancher, Kafka, Raspberry Pi workers | Second orchestrator with no benefit ([ADR-0001](decisions/0001-single-deployment-path.md)) |
| obsidian | Not needed |
| portfolio | Hosted elsewhere |
| cloudflared | Nothing needs public HTTP today (YAGNI). Returns when a self-developed app is published ([ADR-0010](decisions/0010-vpn-only-access.md)) |
| Promtail | End of life since 2026-03-02 (Grafana). Replaced by Grafana Alloy in `platform` |
| Portainer | Pending decision: clicking changes into containers creates drift from Git ([open questions](open-questions.md)) |

## Per-domain documents

Each domain gets `docs/domains/<domain>.md` in the same release that adds it.
