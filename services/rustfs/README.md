# RustFS

[RustFS](https://rustfs.com/) is an S3-compatible object storage server. It's the general-purpose storage layer planned in the root `README.md`/`docs/storage.md` — a place for application data (backups, artifacts, anything that wants an S3 API) that isn't already covered by Proxmox Backup Server or a service's own NFS mount.

## Responsibilities

- Serves an S3 API (bucket create/list, object put/get/delete, etc.) and a web console.
- Keeps all object data on the NAS over NFS, not on the LXC's own disk — same pattern as Obsidian and Jellyfin.

RustFS is deployed as a Docker Compose application inside a dedicated LXC container, same as `obsidian`/`jellyfin`.

## Directory Structure

```text
services/rustfs/
├── README.md
└── compose.yaml
```

## Architecture

```text
                   rustfs LXC
                        │
                 Docker Compose
                        │
                        ▼
                     RustFS
                :9000 (S3 API)
              :9001 (console)
                        │
                     /data
                        │
                        ▼
                 NFS export on NAS
              192.168.0.111:/export/rustfs
```

## NAS prerequisite (one-time, manual)

Like Obsidian's and Jellyfin's, this export doesn't exist until it's created on the NAS itself:

1. Create an NFS export at `/export/rustfs` on the NAS (`192.168.0.111`), readable/writable from the `rustfs` LXC's address (`config/hosts.yaml`).
2. RustFS's container runs as a fixed non-root user, UID/GID `10001:10001`, and needs write access to that export. The Ansible role (`ansible/roles/rustfs/`) `chown`s the mount point to `10001:10001` after mounting it, which only succeeds if the export doesn't map root to an unprivileged user (i.e. `no_root_squash`, or the export is already owned by `10001:10001` on the NAS side). Set that up on the NAS before the first run.

## Credentials

`RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` are the root S3/console credentials. They must never be committed to Git and must never be left unset — RustFS's own defaults (`rustfsadmin`/`rustfsadmin`) are public.

In the homelab deployment these come from Ansible Vault / CI secrets via the `rustfs` Ansible role (`ansible/roles/rustfs/`), not from a checked-in `.env`. The role refuses to run if they're empty.

## Networking

The console is exposed through the homelab reverse proxy:

```text
https://rustfs.home.arpa   → :9001 (console)
```

The S3 API (`:9000`) is **not** routed through Traefik — other services reach it directly by the `rustfs` LXC's LAN IP:port (`config/hosts.yaml`), the same way Prometheus reaches its scrape targets or Promtail reaches Loki. It's machine-to-machine traffic, not something a browser needs a `*.home.arpa` hostname for.

## Backup

The NFS-mounted object data itself is out of this repo's Proxmox/Docker-volume backup scope, same reasoning as Jellyfin's media library — it's expected to be backed up at the NAS level, not re-backed-up through the LXC. See [`docs/storage.md`](../../docs/storage.md).

## Local Development

```bash
cd services/rustfs
RUSTFS_ACCESS_KEY=devkey RUSTFS_SECRET_KEY=devsecret docker compose up -d
```

Without a real NAS mount, `/mnt/nas/rustfs` won't exist locally — point `volumes:` at a throwaway local directory first if testing outside Ansible.
