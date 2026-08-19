# Minecraft (PaperMC)

A [PaperMC](https://papermc.io/) server that starts itself when someone tries to join and goes back to sleep after 10 minutes with nobody online — no manually starting/stopping a server nobody's using 24/7 for a few hours of play a week.

## How it works

Three containers:

- **lazymc** ([lazymc-docker-proxy](https://github.com/joesturge/lazymc-docker-proxy)) — the only container that actually listens on the public Minecraft port (`25565`). While `mc` is asleep it answers with a "sleeping, join to start" status; on a real join attempt it starts the `mc` container (via the Docker socket) and holds the client until it's ready. After `lazymc.time.sleep_after=600` seconds (10 min) with no players, it stops `mc` again.
- **mc** ([itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server), `TYPE=PAPER`) — the actual Paper server. `restart: "no"` — it's managed entirely by lazymc; Docker's own restart policy would fight lazymc's stop/start cycle.
- **mc-exporter** ([dirien/minecraft-exporter](https://github.com/dirien/minecraft-prometheus-exporter)) — Prometheus metrics via RCON, no in-game plugin needed. Naturally reports nothing (Prometheus sees `up=0` for the scrape) while `mc` is asleep — that's expected, not a fault.

## Before deploying this — things only you can do

1. **Create the NAS share folder.** The world lives on your NAS over CIFS/SMB (not NFS — see `ansible/roles/minecraft/README.md`), at `//<nas>/proxmox/data/minecraft` by default (`minecraft_nas_share` in `ansible/roles/minecraft/defaults/main.yaml`). Create the `data/minecraft` folder inside your existing `proxmox` share before the first deploy — nothing here creates it for you.
2. **Provide NAS credentials and an RCON password** via Ansible Vault or `-e`/CI secrets (`MINECRAFT_NAS_USERNAME`, `MINECRAFT_NAS_PASSWORD`, `MINECRAFT_RCON_PASSWORD` env vars, read by the `Makefile`) — the role refuses to run without them. Never commit real values.
3. **Create a scoped WireGuard client** for players once wg-easy is set up (`http://192.168.0.203:51821`, see `services/wireguard/README.md`): a new client per player (or one shared), with **Allowed IPs restricted to `192.168.0.217/32`** — that peer can reach the Minecraft server and nothing else on the LAN. This server is `tier: internal` on purpose: no router port-forward, no public exposure — Minecraft's raw TCP protocol doesn't work well behind the Cloudflare Tunnel used for `personal`/`public` services anyway.

## Connecting

Once on the VPN, point the Minecraft client at `192.168.0.217:25565`. The first join after 10 minutes idle will show "server starting" for a few seconds while `mc` boots — that's lazymc, not a hang.

## Monitoring

- **Uptime Kuma / blackbox** (`tcp_connect` on `25565`) — checks lazymc itself is reachable, not whether `mc` happens to be awake right now (it's supposed to cycle up/down; that's not a fault to monitor for).
- **Grafana** (`homelab-minecraft` dashboard, provisioned automatically) — TPS, tick time, online players, per-player health/food/XP, active entity counts. Populated only while `mc` is actually running.
- **Host-level** (CPU/mem/disk of the LXC itself) — the existing `homelab-host-detail` dashboard, pick `minecraft` from the instance selector.

## Deployment

Terraform creates the `minecraft` LXC (`terraform/proxmox/lxc.tf`). Ansible mounts the NAS share and deploys this Compose file (see `ansible/roles/minecraft/`).

## Local Development

```bash
cd services/minecraft
MINECRAFT_RCON_PASSWORD=changeme docker compose up -d
```

Note: without the NAS mount at `/mnt/nas/minecraft`, the bind-mounted volumes in `compose.yaml` will just create/use plain local directories instead — fine for testing, not for a real deploy.
