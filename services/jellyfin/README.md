# Jellyfin

Jellyfin is the homelab's media server — it streams video/audio libraries whose files live entirely on the NAS, not on the LXC's local disk.

## Responsibilities

- Serves a web UI and streaming API for the media libraries mounted into it.
- Transcodes on demand (software/CPU transcoding by default — see "Resource sizing").
- Keeps all application state (config, metadata cache, thumbnails) local to the LXC; keeps the actual media files on the NAS.

Jellyfin is deployed as a Docker Compose application inside a dedicated LXC container, same as `n8n`, `it-tools`, and `obsidian`.

## Directory Structure

```text
services/jellyfin/
├── README.md
└── compose.yaml
```

No `.env.example` — there are no secrets in this deployment; Jellyfin's admin account is created through its first-run setup wizard.

## Architecture

```text
             Proxmox host (192.168.0.157)
                        │
          systemd mount unit (CIFS/SMB)
                        │
                        ▼
           //<nas>/proxmox/data/jellyfin
          mounted at /mnt/pve/jellyfin
                        │
        bind-mounted into the LXC as mp0
                        │
                        ▼
                  jellyfin LXC
                        │
                 Docker Compose
                        │
                        ▼
                  jellyfin/jellyfin
                        │
        ┌───────────────┴───────────────┐
        │                               │
   /media/movies                  /media/series
  (bind mount, ro)                (bind mount, ro)
        │                               │
        ▼                               ▼
/mnt/nas/jellyfin/movies      /mnt/nas/jellyfin/series
```

## Persistence

Three paths matter:

| Path               | Backing                                | Contents                                      |
| ------------------- | --------------------------------------- | ---------------------------------------------- |
| `/media/movies`     | NAS share (bind mount, ro)              | Movie library files                            |
| `/media/series`     | NAS share (bind mount, ro)              | TV show library files                          |
| `/config`           | Docker named volume `jellyfin-config`   | Server config, users, watched-state, metadata  |
| `/cache`            | Docker named volume `jellyfin-cache`    | Transcoding scratch space, image cache (regenerable) |

The media mounts are read-only: Jellyfin only needs to read the library, not write into it. `/config` is the one volume worth backing up (library setup, user accounts, playback history) — `/cache` is disposable.

### NAS prerequisite (one-time, manual)

Media lives on the NAS over **CIFS/SMB** (a `proxmox` share, `data/jellyfin/{movies,series}` subfolders — user/password auth), mounted on the **Proxmox host itself and bind-mounted into the LXC**, not mounted by Ansible inside the container. Unprivileged LXCs (this one included) can't mount CIFS/NFS themselves — see `ansible/roles/minecraft/README.md` for the full explanation (kernel limitation, not a permissions gap).

Run this once on the **Proxmox host** (`192.168.0.157`), as root, after the `jellyfin` LXC (`vm_id 215`) exists — this mounts the whole `data/jellyfin` folder (covering `movies` and `series`, and any future subfolder added under it later — no extra host-side setup needed for those):

```bash
mkdir -p /mnt/pve/jellyfin

cat > /etc/pve-nas-jellyfin-credentials <<'EOF'
username=<your NAS username>
password=<your NAS password>
EOF
chmod 600 /etc/pve-nas-jellyfin-credentials

cat > /etc/systemd/system/mnt-pve-jellyfin.mount <<'EOF'
[Unit]
Description=CIFS mount for Jellyfin media library (proxmox/data/jellyfin NAS share)
After=network-online.target
# Without this, pve-guests.service (which starts LXCs on boot) has no
# ordering relative to this mount and can start the container before
# the share is mounted, leaving the bind mount empty on that boot.
Before=pve-guests.service
Wants=network-online.target

[Mount]
What=//<nas-ip>/proxmox/data/jellyfin
Where=/mnt/pve/jellyfin
Type=cifs
# uid/gid 100000 = the LXC's unprivileged root (container UID 0), since
# the official jellyfin/jellyfin image always runs as root and ignores
# PUID/PGID — mapped through the standard root:100000:65536 offset
# (check /etc/subuid if this LXC's mapping is non-default). Read-only
# mount, so this only needs to be readable, not writable.
Options=credentials=/etc/pve-nas-jellyfin-credentials,uid=100000,gid=100000,vers=3.0,ro,_netdev

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mnt-pve-jellyfin.mount

pct set 215 -mp0 /mnt/pve/jellyfin,mp=/mnt/nas/jellyfin,ro=1
```

The `pct set` step applies live to a running container (no reboot needed) but is **not tracked by Terraform** (adding a `mount_point` requires `root@pam`; this repo's API token is deliberately least-privilege) — if the LXC is ever destroyed and recreated, redo just that last `pct set` line (the systemd mount unit on the host survives on its own).

## Networking

Jellyfin is exposed two ways:

- **LAN**: `http://192.168.0.215:8096` directly by IP:port, no Traefik, same trust model as every other `tier: internal` service — no auth in front of it beyond being on the LAN/WireGuard (Jellyfin has its own login).
- **Remote**: `https://jellyfin.jsisques.net` through the existing Cloudflare Tunnel (`services/cloudflared/config.yml`), for access outside the home network. This is the personal-apps ingress path already used for `jsisques.net`, not the public `sisqueslabs.com` one.

The internal application port is `8096` in both cases.

## Resource sizing

4 vCPU / 4GB RAM, 16GB disk (image layers and `/config` only — media data is all on the NAS). CPU-bound because this deployment relies on software (CPU) transcoding; there is no GPU/iGPU passthrough configured. If direct play (no transcoding) covers most playback, this is comfortable headroom. If multiple simultaneous transcodes become common, revisit — either raise `cpu`/`memory` in `config/hosts.yaml`, or move to hardware transcoding (LXC `/dev/dri` passthrough or a VM with GPU passthrough), which is a bigger change than this role currently supports.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── jellyfin.yaml
└── roles/
    └── jellyfin/
```

```bash
make deploy-jellyfin
```

## Local Development

```bash
cd services/jellyfin

mkdir -p /mnt/nas/jellyfin/{movies,series}   # stand-in for the bind-mounted NAS folders

docker compose up -d
```

Then open `http://localhost:8096` and walk through the first-run setup wizard.

## Monitoring

Jellyfin has no native Prometheus `/metrics` endpoint, so it's probed by `blackbox_exporter` for up/down + latency instead (see `config/services.yaml`, `services/blackbox-exporter/README.md`) and added to Uptime Kuma as an HTTP monitor on port `8096`.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). The Proxmox host mounts the NAS share and bind-mounts it into the LXC (manual, see "NAS prerequisite" above). Ansible manages host configuration and Docker Compose deployment. This directory manages the Compose definition and application configuration.
