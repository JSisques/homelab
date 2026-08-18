# Downloads Ansible Role

Prepares an LXC container and deploys the downloads stack (see `services/downloads/README.md`) using Docker Compose, with the download and media libraries mounted **read-write** from NFS exports on the NAS.

## Responsibilities

- Install NFS client utilities and mount the NAS exports (`downloads_nas_export_downloads`, `downloads_nas_export_peliculas`, `downloads_nas_export_series` — **adjust the defaults to your real export paths**) at `downloads_mount_path` / `downloads_media_mount_path`.
- Create the `torrents`/`direct`/`youtube` subdirectories the compose stack writes into.
- Template the `.env` file (VPN credentials, PUID/PGID/TZ) and deploy `services/downloads/compose.yaml`.
- Start the stack with Docker Compose.

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

downloads_nas: "{{ hostvars['nas'].ansible_host }}"
downloads_nas_export_downloads: "{{ downloads_nas }}:/export/Downloads"
downloads_nas_export_peliculas: "{{ downloads_nas }}:/export/Multimedia/peliculas"
downloads_nas_export_series: "{{ downloads_nas }}:/export/Multimedia/series"

downloads_mount_path: /mnt/nas/downloads
downloads_media_mount_path: /mnt/nas/multimedia

downloads_puid: 1000
downloads_pgid: 1000
downloads_timezone: Europe/Madrid

downloads_vpn_service_provider: changeme
downloads_vpn_wireguard_private_key: changeme
downloads_vpn_wireguard_addresses: changeme
downloads_vpn_server_countries: ""
```

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
    ├── Install nfs-common
    ├── Mount NAS exports (rw) at /mnt/nas/downloads and /mnt/nas/multimedia/{peliculas,series}
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

## Related

- `terraform/proxmox/lxc.tf` — creates the `downloads` LXC.
- `services/downloads/` — Compose definition and application-level documentation.
- `ansible/roles/jellyfin/` — same NFS-mount-from-NAS pattern (this role's mounts are read-write instead of read-only, since this stack writes into the NAS).
