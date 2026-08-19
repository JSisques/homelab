# Downloads Ansible Role

Prepares an LXC container and deploys the downloads stack (see `services/downloads/README.md`) using Docker Compose, with the download and media libraries mounted **read-write** from a NAS share.

## Responsibilities

- Create the `torrents`/`direct`/`youtube` subdirectories the compose stack writes into (under `downloads_mount_path`, which itself comes from a Proxmox-level bind mount — see "NAS Export" below).
- Template the `.env` file (VPN credentials, PUID/PGID/TZ) and deploy `services/downloads/compose.yaml`.
- Start the stack with Docker Compose.

It does **not** mount the NAS — see "NAS Export" below.

Terraform is responsible for creating the LXC container.

## Directory Structure

```text
ansible/roles/downloads/
├── README.md
├── defaults/
│   └── main.yaml
├── meta/
│   └── main.yml
├── templates/
│   └── env.j2
└── tasks/
    └── main.yaml
```

## Variables

```yaml
downloads_app_dir: /opt/downloads

downloads_mount_path: /mnt/nas/downloads

downloads_puid: 1000
downloads_pgid: 1000
downloads_timezone: Europe/Madrid

downloads_vpn_service_provider: changeme
downloads_vpn_wireguard_private_key: changeme
downloads_vpn_wireguard_addresses: changeme
downloads_vpn_server_countries: ""
```

## NAS Export

Neither download staging nor the media library touch the LXC's own disk — `/mnt/nas/downloads` and `/mnt/nas/jellyfin` inside the container both come from **Proxmox-level bind mounts**, not this role. Unprivileged LXCs (all of them in this repo) can't mount CIFS/NFS themselves, even with `features.mount = ["cifs", "nfs"]` set (`mount error(1): Operation not permitted` — a kernel limitation, confirmed while building `ansible/roles/minecraft/`).

`/mnt/nas/jellyfin` is the same NAS folder `ansible/roles/jellyfin/` bind-mounts read-only into the `jellyfin` LXC — Sonarr/Radarr need to write into it (organized imports), so the underlying host-side CIFS mount is read-write; Jellyfin's own read-only-ness comes from its `pct set ... ro=1` bind flag, not from the mount itself. See `services/downloads/README.md` for the exact host-side commands, including why the mounts use uid/gid `101000` (PUID/PGID `1000` mapped through the LXC's unprivileged offset).

### Secrets

`downloads_vpn_service_provider`, `downloads_vpn_wireguard_private_key`, and `downloads_vpn_wireguard_addresses` must **never** be committed with real values. Pass them at deploy time the same way `n8n_postgres_password` is passed today — as environment variables consumed by the Makefile's `ANSIBLE_EXTRA_VARS`:

```bash
export DOWNLOADS_VPN_SERVICE_PROVIDER=mullvad
export DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY=...
export DOWNLOADS_VPN_WIREGUARD_ADDRESSES=10.x.x.x/32
make deploy-downloads
```

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/downloads.yaml \
  -e "downloads_vpn_service_provider=$DOWNLOADS_VPN_SERVICE_PROVIDER" \
  -e "downloads_vpn_wireguard_private_key=$DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY" \
  -e "downloads_vpn_wireguard_addresses=$DOWNLOADS_VPN_WIREGUARD_ADDRESSES"
```

or, from the repo root:

```bash
make deploy-downloads
```

## Deployment Flow

```text
Terraform
    │
    ▼
LXC downloads
    │
    ▼
Ansible
    │
    ▼
downloads role
    │
    ├── Create /opt/downloads and template .env
    ├── Deploy compose.yaml
    └── docker compose up -d
             │
             ├── gluetun (VPN) ── qbittorrent  :8080  (torrents, via VPN)
             ├── prowlarr                       :9696  (indexers)
             ├── sonarr                         :8989  (TV automation)
             ├── radarr                         :7878  (movie automation)
             ├── pyload                         :8000  (direct HTTP/FTP links)
             └── metube                         :8081  (yt-dlp video links)
                      │
                      └── reached by LAN IP:port directly (no Traefik, no Cloudflare route)
```

(NAS mounts at `/mnt/nas/downloads` and `/mnt/nas/jellyfin` come from Proxmox-host-level bind mounts set up before any of this runs — see "NAS Export" above.)

## Related

- `terraform/proxmox/lxc.tf` — creates the `downloads` LXC.
- `services/downloads/` — Compose definition and application-level documentation.
- `ansible/roles/jellyfin/`, `ansible/roles/minecraft/`, `ansible/roles/rustfs/` — same host-mount + bind-mount pattern (this role's mounts are read-write instead of read-only, since this stack writes into the NAS).
