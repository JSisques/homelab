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
                  jellyfin LXC
                        │
                 Docker Compose
                        │
                        ▼
                  jellyfin/jellyfin
                        │
        ┌───────────────┴───────────────┐
        │                               │
  /media/peliculas               /media/series
  (bind mount, ro)                (bind mount, ro)
        │                               │
        ▼                               ▼
        192.168.0.111:/export/Multimedia/{peliculas,series}
                   NFS exports on the NAS
```

## Persistence

Three paths matter:

| Path               | Backing                                | Contents                                      |
| ------------------- | --------------------------------------- | ---------------------------------------------- |
| `/media/peliculas`  | NFS export on the NAS (bind mount, ro)  | Movie library files                            |
| `/media/series`     | NFS export on the NAS (bind mount, ro)  | TV show library files                          |
| `/config`           | Docker named volume `jellyfin-config`   | Server config, users, watched-state, metadata  |
| `/cache`            | Docker named volume `jellyfin-cache`    | Transcoding scratch space, image cache (regenerable) |

The media mounts are read-only: Jellyfin only needs to read the library, not write into it. `/config` is the one volume worth backing up (library setup, user accounts, playback history) — `/cache` is disposable.

### NAS prerequisite

Before deploying, the following NFS exports must exist on the NAS, following the same pattern as `ansible/roles/obsidian/`:

```text
192.168.0.111:/export/Multimedia/peliculas
192.168.0.111:/export/Multimedia/series
```

Adjust `ansible/roles/jellyfin/defaults/main.yaml` if the real export paths on the NAS differ from this placeholder — the Ansible role mounts them at `/mnt/nas/multimedia/{peliculas,series}` on the LXC, and `compose.yaml` bind-mounts those into the container.

## Networking

Jellyfin is exposed two ways:

- **LAN**: `https://jellyfin.home.arpa` through Traefik, same trust model as every other `tier: internal` service — no auth in front of it beyond being on the LAN/WireGuard (Jellyfin has its own login).
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

mkdir -p /tmp/jellyfin-media/{peliculas,series}   # stand-in for the NAS mounts

docker compose up -d
```

Then open `http://localhost:8096` and walk through the first-run setup wizard.

## Monitoring

Jellyfin has no native Prometheus `/metrics` endpoint, so it's probed by `blackbox_exporter` for up/down + latency instead (see `config/services.yaml`, `services/blackbox-exporter/README.md`) and added to Uptime Kuma as an HTTP monitor on port `8096`.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration, the NFS mounts, and Docker Compose deployment. This directory manages the Compose definition and application configuration.
