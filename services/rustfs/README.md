# RustFS

[RustFS](https://rustfs.com/) is an S3-compatible object storage server. It's the general-purpose storage layer planned in the root `README.md`/`docs/storage.md` — a place for application data (backups, artifacts, anything that wants an S3 API) that isn't already covered by Proxmox Backup Server or a service's own NFS mount.

## Responsibilities

- Serves an S3 API (bucket create/list, object put/get/delete, etc.) and a web console.
- Keeps all object data on the NAS, not on the LXC's own disk.

RustFS is deployed as a Docker Compose application inside a dedicated LXC container, same as `obsidian`/`jellyfin`.

## Directory Structure

```text
services/rustfs/
├── README.md
└── compose.yaml
```

## Architecture

```text
             Proxmox host (192.168.0.157)
                        │
          systemd mount unit (CIFS/SMB)
                        │
                        ▼
        //<nas>/proxmox/data/rustfs
          mounted at /mnt/pve/rustfs
                        │
        bind-mounted into the LXC as mp0
                        │
                        ▼
                   rustfs LXC
                        │
                 Docker Compose
                        │
                        ▼
                     RustFS
                :9000 (S3 API)
              :9001 (console)
                        │
                        ▼
              /data → /mnt/nas/rustfs
```

## NAS prerequisite (one-time, manual)

Object data lives on the NAS over **CIFS/SMB** (a `proxmox` share, `data/rustfs` subfolder — user/password auth), mounted on the **Proxmox host itself and bind-mounted into the LXC**, not mounted by Ansible inside the container. Unprivileged LXCs (this one included) can't mount CIFS/NFS themselves — confirmed directly (`mount error(1): Operation not permitted`, even with Proxmox's `features.mount = ["cifs", "nfs"]` flag set) while working through the same issue for `services/minecraft/`; see `ansible/roles/minecraft/README.md` for the full explanation. `ansible/roles/rustfs/` does not manage this mount at all.

Run this once on the **Proxmox host** (`192.168.0.157`), as root, after the `rustfs` LXC (`vm_id 208`) exists — create the `data/rustfs` folder inside the NAS's `proxmox` share first:

```bash
mkdir -p /mnt/pve/rustfs

cat > /etc/pve-nas-rustfs-credentials <<'EOF'
username=<your NAS username>
password=<your NAS password>
EOF
chmod 600 /etc/pve-nas-rustfs-credentials

cat > /etc/systemd/system/mnt-pve-rustfs.mount <<'EOF'
[Unit]
Description=CIFS mount for RustFS object data (proxmox/data/rustfs NAS share)
After=network-online.target
# Without this, pve-guests.service (which starts LXCs on boot) has no
# ordering relative to this mount and can start the container before
# the share is mounted, leaving the bind mount empty on that boot.
Before=pve-guests.service
Wants=network-online.target

[Mount]
What=//<nas-ip>/proxmox/data/rustfs
Where=/mnt/pve/rustfs
Type=cifs
# uid/gid 110001 = RustFS's fixed non-root container user (10001)
# mapped through the LXC's standard root:100000:65536 unprivileged
# offset (check /etc/subuid if this LXC's mapping is non-default).
Options=credentials=/etc/pve-nas-rustfs-credentials,uid=110001,gid=110001,vers=3.0,_netdev
EOF

systemctl daemon-reload
systemctl enable --now mnt-pve-rustfs.mount

pct set 208 -mp0 /mnt/pve/rustfs,mp=/mnt/nas/rustfs
```

The `pct set` step applies live to a running container (no reboot needed) but is **not tracked by Terraform** (adding a `mount_point` requires `root@pam`; this repo's API token is deliberately least-privilege) — if the LXC is ever destroyed and recreated, redo just that last `pct set` line (the systemd mount unit on the host survives on its own).

## Credentials

`RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` are the root S3/console credentials. They must never be committed to Git and must never be left unset — RustFS's own defaults (`rustfsadmin`/`rustfsadmin`) are public.

In the homelab deployment these come from Ansible Vault / CI secrets via the `rustfs` Ansible role (`ansible/roles/rustfs/`), not from a checked-in `.env`. The role refuses to run if they're empty.

## Networking

The console is reached directly by its LAN `IP:port`, no reverse proxy in front of it:

```text
http://192.168.0.208:9001   (console)
```

The S3 API (`:9000`) is **not** routed through Traefik either — other services reach it directly by the `rustfs` LXC's LAN IP:port (`config/hosts.yaml`), the same way Prometheus reaches its scrape targets or Promtail reaches Loki. It's machine-to-machine traffic, not something a browser needs a hostname for.

## Backup

The NFS-mounted object data itself is out of this repo's Proxmox/Docker-volume backup scope, same reasoning as Jellyfin's media library — it's expected to be backed up at the NAS level, not re-backed-up through the LXC. See [`docs/storage.md`](../../docs/storage.md).

## Local Development

```bash
cd services/rustfs
RUSTFS_ACCESS_KEY=devkey RUSTFS_SECRET_KEY=devsecret docker compose up -d
```

Without a real NAS mount, `/mnt/nas/rustfs` won't exist locally — point `volumes:` at a throwaway local directory first if testing outside Ansible.
