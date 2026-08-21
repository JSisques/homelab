# Downloads Ansible Role

Prepares an LXC container and deploys the downloads stack (see `services/downloads/README.md`) using Docker Compose, with the download and media libraries mounted **read-write** from a NAS share.

## Responsibilities

- Bind the NAS shares into the LXC (`pct set -mp0/-mp1`, delegated to the `proxmox` host) — see "NAS bind mounts" below.
- Create the `torrents`/`direct`/`youtube` subdirectories the compose stack writes into (under `downloads_mount_path`).
- Template the `.env` file (VPN credentials, PUID/PGID/TZ) and deploy `services/downloads/compose.yaml`.
- Start the stack with Docker Compose.
- Give qBittorrent's WebUI a permanent username/password via its REST API (it has no env var for this — see "qBittorrent WebUI credentials" below).
- Configure qBittorrent's Alternative Speed Limits scheduler so it only downloads at full speed overnight — see "qBittorrent night-only schedule" below.
- Wire Sonarr, Radarr, and Prowlarr together via their REST APIs — root folders, the qBittorrent download client, Prowlarr's connected apps — see "App wiring" below.

It does **not** create the underlying CIFS mounts on the Proxmox host itself — that's a one-time manual step, see `services/downloads/README.md#nas-prerequisite-mostly-one-time-partly-automated`.

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
downloads_jellyfin_mount_path: /mnt/nas/jellyfin
downloads_nas_source_path: /mnt/pve/downloads
downloads_jellyfin_nas_source_path: /mnt/pve/jellyfin
downloads_lxc_vmid: 216

downloads_puid: 1000
downloads_pgid: 1000
downloads_timezone: Europe/Madrid

downloads_vpn_service_provider: changeme
downloads_vpn_wireguard_private_key: changeme
downloads_vpn_wireguard_addresses: changeme
downloads_vpn_server_countries: ""

downloads_qbittorrent_username: changeme
downloads_qbittorrent_password: changeme

downloads_qbittorrent_scheduler_enabled: true
downloads_qbittorrent_throttle_from_hour: 8
downloads_qbittorrent_throttle_from_minute: 0
downloads_qbittorrent_throttle_to_hour: 23
downloads_qbittorrent_throttle_to_minute: 0
downloads_qbittorrent_throttle_days: 0
downloads_qbittorrent_throttle_speed_kib: 1
```

## NAS bind mounts

Neither download staging nor the media library touch the LXC's own disk — `/mnt/nas/downloads` and `/mnt/nas/jellyfin` inside the container both come from **Proxmox-level bind mounts**. Unprivileged LXCs (all of them in this repo) can't mount CIFS/NFS themselves, even with `features.mount = ["cifs", "nfs"]` set (`mount error(1): Operation not permitted` — a kernel limitation, confirmed while building `ansible/roles/minecraft/`).

`/mnt/nas/jellyfin` is the same NAS folder `ansible/roles/jellyfin/` bind-mounts read-only into the `jellyfin` LXC — Sonarr/Radarr need to write into it (organized imports), so the underlying host-side CIFS mount is read-write; Jellyfin's own read-only-ness comes from its `pct set ... ro=1` bind flag, not from the mount itself. See `services/downloads/README.md` for the exact host-side CIFS setup, including why the mounts use uid/gid `101000` (PUID/PGID `1000` mapped through the LXC's unprivileged offset).

The role's first three tasks bind those already-mounted host paths into the LXC:

1. `pct config {{ downloads_lxc_vmid }}` (delegated to the `proxmox` inventory host) to read the LXC's current `mp0`/`mp1` lines.
2. `pct set {{ downloads_lxc_vmid }} -mp0 {{ downloads_nas_source_path }},mp={{ downloads_mount_path }}` — only if that exact mount isn't already there.
3. Same for `-mp1` / `downloads_jellyfin_*`.

This needs `root@pam` on the Proxmox side (`pct set` isn't exposed to API tokens), which is why it goes through Ansible's SSH connection to the `proxmox` host (`ansible_user: root` there) instead of Terraform's least-privilege API token. If either mount just changed, the role also restarts the containers that read them (`sonarr`, `radarr`, `qbittorrent`, `pyload`, `metube`) — a bind mount added under a path a container already has open doesn't show up inside it without a restart.

Because this now runs on every deploy, a destroyed-and-recreated `downloads` LXC gets its NAS mounts back automatically on the next `make deploy-downloads` — no manual `pct set` step to remember.

### Secrets

`downloads_vpn_service_provider`, `downloads_vpn_wireguard_private_key`, `downloads_vpn_wireguard_addresses`, `downloads_qbittorrent_username`, and `downloads_qbittorrent_password` must **never** be committed with real values. Pass them at deploy time the same way `n8n_postgres_password` is passed today — as environment variables consumed by the Makefile's `ANSIBLE_EXTRA_VARS`:

```bash
export DOWNLOADS_VPN_SERVICE_PROVIDER=mullvad
export DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY=...
export DOWNLOADS_VPN_WIREGUARD_ADDRESSES=10.x.x.x/32
export DOWNLOADS_QBITTORRENT_USERNAME=...
export DOWNLOADS_QBITTORRENT_PASSWORD=...
make deploy-downloads
```

### qBittorrent WebUI credentials

The `linuxserver/qbittorrent` image has no env var for the WebUI username/password (feature request closed as not planned upstream — [linuxserver/docker-qbittorrent#228](https://github.com/linuxserver/docker-qbittorrent/issues/228)). Since qBittorrent 4.6.1, if the password is never changed from the WebUI, it generates a new random temporary one on every container start and prints it to `docker logs qbittorrent`.

To make this idempotent, the role's last task:

1. Tries logging in with `downloads_qbittorrent_username`/`downloads_qbittorrent_password` — if that already works (a previous run already set it), it's a no-op.
2. Otherwise, reads the current temporary password from `docker logs qbittorrent`, logs in with it, and calls the WebUI API (`/api/v2/app/setPreferences`) to set the permanent username/password.

This runs from the Ansible controller (`delegate_to: localhost`) against the LXC's LAN IP, since the minimal Debian image the LXC runs doesn't have `curl` and this avoids needing it.

### qBittorrent night-only schedule

qBittorrent's API has no schedule-based pause/resume — only the **Alternative Speed Limits scheduler** (`Settings → Speed → Scheduling` in the WebUI). "Only downloads at night" is implemented as: unlimited speed during `downloads_qbittorrent_throttle_to_hour:minute`→`downloads_qbittorrent_throttle_from_hour:minute` (23:00→08:00 by default), throttled to `downloads_qbittorrent_throttle_speed_kib` KiB/s (1 KiB/s by default — a real pause isn't possible since qBittorrent treats a `0` limit as *unlimited*, not *paused*) the rest of the day, every day (`downloads_qbittorrent_throttle_days: 0`; see `defaults/main.yaml` for the other day-of-week values).

Set `downloads_qbittorrent_scheduler_enabled: false` to leave qBittorrent's speed limits alone entirely (no schedule, always unlimited) — the role skips this whole block when that's set.

Idempotent the same way as the credentials task: logs in with the permanent credentials (already guaranteed to work by the previous task), reads current preferences, and only calls `setPreferences` if any of the schedule/limit fields differ from what's wanted.

## App wiring

Sonarr, Radarr, and Prowlarr each expose a REST API authenticated with a per-app key (auto-generated on first start, written to `/config/config.xml` inside each container). The role's last block reads those three keys (`docker exec <app> cat /config/config.xml | grep -oP ...`, retried until present — config.xml isn't written the instant the port opens) and, for each of the following, checks first and only `POST`s if missing:

- Radarr: root folder `/movies`, qBittorrent as a download client (host `gluetun`, port `8080`, category `radarr`).
- Sonarr: root folder `/tv`, qBittorrent as a download client (host `gluetun`, port `8080`, category `sonarr`).
- Prowlarr: Radarr and Sonarr added as connected apps (`syncLevel: fullSync`), so indexers added in Prowlarr propagate to both.

This mirrors exactly what `services/downloads/README.md`'s former "First-run configuration" steps had you click through by hand — same field values, just idempotent and applied through each app's `/api/v3/...` (Prowlarr: `/api/v1/...`) endpoints instead of the WebUI. **Indexers themselves are deliberately not touched** — which trackers to use is a personal choice, not something this role should decide; add those once in Prowlarr's WebUI and they persist in the `prowlarr-config` volume.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/downloads.yaml \
  -e "downloads_vpn_service_provider=$DOWNLOADS_VPN_SERVICE_PROVIDER" \
  -e "downloads_vpn_wireguard_private_key=$DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY" \
  -e "downloads_vpn_wireguard_addresses=$DOWNLOADS_VPN_WIREGUARD_ADDRESSES" \
  -e "downloads_qbittorrent_username=$DOWNLOADS_QBITTORRENT_USERNAME" \
  -e "downloads_qbittorrent_password=$DOWNLOADS_QBITTORRENT_PASSWORD"
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
    ├── pct set -mp0/-mp1 on the proxmox host (NAS bind mounts)
    ├── Create /opt/downloads and template .env
    ├── Deploy compose.yaml + scripts/
    ├── docker compose up -d
    │        │
    │        ├── gluetun (VPN) ── qbittorrent  :8080  (torrents, via VPN)
    │        ├── prowlarr                       :9696  (indexers)
    │        ├── sonarr                         :8989  (TV automation)
    │        ├── radarr                         :7878  (movie automation)
    │        ├── pyload                         :8000  (direct HTTP/FTP links)
    │        ├── metube                         :8081  (yt-dlp video links)
    │        └── clamav + clamav-scanner               (no published ports)
    │                 │
    │                 └── reached by LAN IP:port directly (no Traefik, no Cloudflare route)
    ├── qBittorrent: set permanent WebUI credentials via its API
    └── Sonarr/Radarr/Prowlarr: root folders, download client, connected apps via their APIs
```

(The underlying CIFS mounts on the Proxmox host itself are set up once, manually — see `services/downloads/README.md`. Everything from `pct set` down runs on every deploy.)

## Related

- `terraform/proxmox/lxc.tf` — creates the `downloads` LXC.
- `services/downloads/` — Compose definition and application-level documentation.
- `ansible/roles/jellyfin/`, `ansible/roles/minecraft/`, `ansible/roles/rustfs/` — same host-mount + bind-mount pattern (this role's mounts are read-write instead of read-only, since this stack writes into the NAS).
