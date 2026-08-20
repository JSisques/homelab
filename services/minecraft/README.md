# Minecraft (PaperMC)

A [PaperMC](https://papermc.io/) server that starts itself when someone tries to join and goes back to sleep after 10 minutes with nobody online — no manually starting/stopping a server nobody's using 24/7 for a few hours of play a week.

## How it works

Three containers:

- **lazymc** ([lazymc-docker-proxy](https://github.com/joesturge/lazymc-docker-proxy)) — the only container that actually listens on the public Minecraft port (`25565`). While `mc` is asleep it answers with a "sleeping, join to start" status; on a real join attempt it starts the `mc` container (via the Docker socket) and holds the client until it's ready. After `lazymc.time.sleep_after=600` seconds (10 min) with no players, it stops `mc` again.
- **mc** ([itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server), `TYPE=PAPER`) — the actual Paper server. `restart: "no"` — it's managed entirely by lazymc; Docker's own restart policy would fight lazymc's stop/start cycle.
- **mc-exporter** ([dirien/minecraft-exporter](https://github.com/dirien/minecraft-prometheus-exporter)) — Prometheus metrics via RCON, no in-game plugin needed. Naturally reports nothing (Prometheus sees `up=0` for the scrape) while `mc` is asleep — that's expected, not a fault.

## Plugins

`mc`'s `MODRINTH_PROJECTS` env var lists plugin slugs that [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server) downloads (latest compatible release) on every startup — no manual jar management. Currently: [LuckPerms](https://modrinth.com/plugin/luckperms) (permissions), [EssentialsX](https://modrinth.com/plugin/essentialsx) (core commands), [CoreProtect](https://modrinth.com/plugin/coreprotect) (grief rollback/logging), [GriefPrevention](https://modrinth.com/plugin/griefprevention) (claim-based land protection), [spark](https://modrinth.com/plugin/spark) (performance profiler), [Chunky](https://modrinth.com/plugin/chunky) (chunk pre-generation), [PlaceholderAPI](https://modrinth.com/plugin/placeholderapi).

Every slug carries a trailing `?` (optional) — **without it, one plugin with no build yet for the server's Minecraft version fails the whole `mc-image-helper` step and the container refuses to start**, taking every other plugin down with it (hit this in practice: EssentialsX had no 26.2/paper build yet). With `?`, an incompatible/missing project just logs a warning and startup continues; it picks itself back up automatically once that project publishes a compatible build, no redeploy needed. Check `docker logs minecraft-paper | grep "no compatible version"` after a restart to see what's currently being skipped. Paper itself bundles a `spark` profiler regardless of whether the plugin installs (`/spark` commands work either way — see [Load testing](#load-testing)).

[Vault](https://github.com/MilkBowl/Vault) isn't on Modrinth, so it's fetched separately via `PLUGINS` from its GitHub releases (`.../releases/latest/download/Vault.jar` always resolves to the newest build).

To add another plugin: append its Modrinth slug (with a trailing `?`) to `MODRINTH_PROJECTS` (comma-separated, no spaces), or its direct jar URL to `PLUGINS` if it isn't on Modrinth. Redeploy (`make deploy-minecraft` or rerun the Ansible playbook) — plugins persist in the NAS-backed `/data/plugins` volume but the env var list is what gets reconciled on each boot, so removing a slug does **not** delete an already-downloaded jar; remove it manually from `/mnt/nas/minecraft/plugins` if needed.

## Before deploying this — things only you can do

1. **Create the NAS share folder.** The world lives on your NAS over CIFS/SMB, at `//<nas>/proxmox/data/minecraft` — create the `data/minecraft` folder inside your existing `proxmox` share before the first deploy.

2. **Mount it on the Proxmox host and bind it into the LXC.** Unprivileged LXCs (all of them here) can't mount CIFS/NFS themselves — see `ansible/roles/minecraft/README.md` for why. Run this once on the **Proxmox host** (`192.168.0.157`), as root, after the `minecraft` LXC (`vm_id 217`) exists:

   ```bash
   mkdir -p /mnt/pve/minecraft

   cat > /etc/pve-nas-minecraft-credentials <<'EOF'
   username=<your NAS username>
   password=<your NAS password>
   EOF
   chmod 600 /etc/pve-nas-minecraft-credentials

   cat > /etc/systemd/system/mnt-pve-minecraft.mount <<'EOF'
   [Unit]
   Description=CIFS mount for Minecraft world data (proxmox/data/minecraft NAS share)
   After=network-online.target
   # Without this, pve-guests.service (which starts LXCs on boot) has no
   # ordering relative to this mount and can start the container before
   # the share is mounted, leaving the bind mount empty on that boot.
   Before=pve-guests.service
   Wants=network-online.target

   [Mount]
   What=//<nas-ip>/proxmox/data/minecraft
   Where=/mnt/pve/minecraft
   Type=cifs
   # uid/gid 101000 = the LXC's unprivileged UID 1000 (itzg/minecraft-server's
   # default user) mapped through the standard root:100000:65536 offset
   # (check /etc/subuid if this LXC's mapping is non-default).
   Options=credentials=/etc/pve-nas-minecraft-credentials,uid=101000,gid=101000,vers=3.0,_netdev

   [Install]
   WantedBy=multi-user.target
   EOF

   systemctl daemon-reload
   systemctl enable --now mnt-pve-minecraft.mount

   pct set 217 -mp0 /mnt/pve/minecraft,mp=/mnt/nas/minecraft
   ```

   The `pct set` step applies live to a running container (no reboot needed) but is **not tracked by Terraform** (adding a `mount_point` requires `root@pam`; this repo's API token is deliberately least-privilege) — if the LXC is ever destroyed and recreated, redo just that last `pct set` line (the systemd mount unit on the host survives on its own).

3. **Provide an RCON password** via Ansible Vault or `-e`/CI secrets (`MINECRAFT_RCON_PASSWORD`, read by the `Makefile`) — the role refuses to run without it. Never commit a real value.

4. **Create a scoped WireGuard client** for players once wg-easy is set up (`http://192.168.0.203:51821`, see `services/wireguard/README.md`): a new client per player (or one shared), with **Allowed IPs restricted to `192.168.0.217/32`** — that peer can reach the Minecraft server and nothing else on the LAN. This server is `tier: internal` on purpose: no router port-forward, no public exposure — Minecraft's raw TCP protocol doesn't work well behind the Cloudflare Tunnel used for `personal`/`public` services anyway.

## Connecting

Once on the VPN, point the Minecraft client at `192.168.0.217:25565`. The first join after 10 minutes idle will show "server starting" for a few seconds while `mc` boots — that's lazymc, not a hang.

## Monitoring

- **Uptime Kuma / blackbox** (`tcp_connect` on `25565`) — checks lazymc itself is reachable, not whether `mc` happens to be awake right now (it's supposed to cycle up/down; that's not a fault to monitor for).
- **Grafana** (`homelab-minecraft` dashboard, provisioned automatically) — TPS, tick time, online players, per-player health/food/XP, active entity counts. Populated only while `mc` is actually running.
- **Host-level** (CPU/mem/disk of the LXC itself) — the existing `homelab-host-detail` dashboard, pick `minecraft` from the instance selector.

## Load testing

Not a permanent part of the stack — a manual procedure to run occasionally, using [SoulFire](https://github.com/soulfiremc-com/SoulFire), a bot framework that runs real client code so bots behave like real players at the protocol level (unlike scripted-packet tools). Uses `spark` (already in `MODRINTH_PROJECTS`, see [Plugins](#plugins)) to read the impact.

### 1. Prerequisites

- Run the SoulFire container from a machine on the WireGuard VPN or LAN — `mc` is `tier: internal`, only reachable at `192.168.0.217:25565` (see [Before deploying this](#before-deploying-this--things-only-you-can-do), point 4).
- Check the server's Minecraft version first (`docker logs minecraft-paper | grep -i "Minecraft Server"` on the `minecraft` LXC, or `/version` in-game) — SoulFire's bots need to speak the same protocol version.

### 2. Temporarily allow offline (non-Microsoft) bot accounts

The `mc` service doesn't set `ONLINE_MODE`, so it defaults to `TRUE` (real Microsoft-authenticated accounts required to join). SoulFire can auto-generate fake accounts for load testing, but only if the server accepts offline auth — real per-bot Microsoft accounts aren't practical at the scale needed to find a breaking point.

This is a **manual, temporary edit on the LXC, not a repo change** — do not commit `ONLINE_MODE: "FALSE"` to `compose.yaml`, it would leave the production server open to username spoofing (low risk given VPN-only exposure, but no reason to leave it that way outside a test window):

```bash
ssh <user>@192.168.0.217
sudo sed -i '/RCON_PASSWORD/a\      ONLINE_MODE: "FALSE"' /opt/minecraft/compose.yaml
cd /opt/minecraft && sudo docker compose up -d mc
```

Revert the same way after testing (remove the added line, `docker compose up -d mc` again) — or just rerun the Ansible playbook, since `ONLINE_MODE` isn't in the tracked `compose.yaml` and won't be reintroduced.

### 3. Run SoulFire

From the VPN-connected machine, as a throwaway container (no need to add this to any `compose.yaml` — it's not part of the stack):

```bash
docker run -d --name soulfire-stress-test --rm -p 38765:38765 ghcr.io/soulfiremc-com/soulfire
```

Open `http://<that machine's IP>:38765`, create the admin account on first visit, then create an instance with:

- **Bot address**: `192.168.0.217:25565`
- **Protocol version**: matching what you checked in step 1
- **Accounts**: leave empty — SoulFire generates offline accounts automatically since `ONLINE_MODE` is now `FALSE`
- **Bot amount**: start at `10` (see ramp-up plan below)
- **Join delay min/max**: keep the defaults (1000–3000 ms) — a burst of simultaneous cold connections can confuse lazymc's wake-up handling and skew results

Join with **one real client first** to wake `mc` via lazymc before starting bots, so the lazymc startup delay doesn't pollute the first measurement.

### 4. Ramp up and measure

Don't jump straight to hundreds of bots — that only proves "it crashes," not where the limit is. Step through bot counts, holding each level 10–15 min, recording metrics before moving on:

| Step | Bots | What to check |
| ---- | ---- | -------------- |
| 0 | 0 (baseline) | `/spark tps` on an idle, awake server |
| 1 | 10 | |
| 2 | 25 | |
| 3 | 50 | |
| 4 | 100 | |
| 5 | 200+ | until TPS degrades |

Metrics, via `spark` (RCON console or in-game):

- `/spark tps` — **TPS** (target 20; below 15 = severe lag) and **MSPT** (healthy under 40 ms, 45 ms+ = near the limit)
- `/spark profiler start` / `/spark profiler stop` — find what's actually consuming tick time at a given bot count
- Grafana `homelab-minecraft` dashboard (see [Monitoring](#monitoring)) — same metrics over time, plus entity counts
- Grafana `homelab-host-detail` (`minecraft` instance) — LXC-level CPU/memory; sustained >80% CPU means no headroom for real-player spikes

Optional: a spike test (burst-connect 50 more bots on top of an already-stable 10) to simulate an event-driven joins, and an endurance run (50–75% of the found capacity for 4–8h) to catch plugin memory leaks — CoreProtect and GriefPrevention both accumulate in-memory state over a session.

### 5. Clean up

```bash
docker stop soulfire-stress-test   # --rm already removes the container
```

Then revert `ONLINE_MODE` on the LXC (step 2) so the production server goes back to requiring real Microsoft accounts.

## Deployment

Terraform creates the `minecraft` LXC (`terraform/proxmox/lxc.tf`). The NAS mount is a one-time manual step on the Proxmox host (see above). Ansible just deploys this Compose file (see `ansible/roles/minecraft/`).

## Local Development

```bash
cd services/minecraft
MINECRAFT_RCON_PASSWORD=changeme docker compose up -d
```

Note: without the NAS mount at `/mnt/nas/minecraft`, the bind-mounted volumes in `compose.yaml` will just create/use plain local directories instead — fine for testing, not for a real deploy.
