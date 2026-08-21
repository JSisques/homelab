# Downloads

The homelab's "give it a URL and it lands on the NAS" stack. It covers the three shapes a download request takes — a torrent/magnet link, a direct HTTP/FTP link, or a video-site link — and, for TV/movies, automates moving the finished file into Jellyfin's library.

## Responsibilities

- **qBittorrent** — torrent client. Its traffic (only its traffic) is routed through a VPN via **gluetun**, so the homelab's real IP is never exposed to other peers.
- **Prowlarr** — indexer manager, feeds search results to Sonarr/Radarr.
- **Sonarr** / **Radarr** — watch for wanted TV episodes/movies, send them to qBittorrent, then rename and move the finished files into the same NAS folder Jellyfin reads from (`/mnt/nas/jellyfin/series`, `/mnt/nas/jellyfin/movies`).
- **pyLoad** — paste a direct HTTP/FTP link, it downloads straight to the NAS. The generic case: no indexer, no torrent, no video site — just a file behind a URL.
- **MeTube** — paste a YouTube (or any [yt-dlp](https://github.com/yt-dlp/yt-dlp)-supported site) link, it downloads the video/audio straight to the NAS. Tracks yt-dlp's nightly channel (`YTDL_NIGHTLY_UPDATE_TIME` in `compose.yaml`, auto-updates daily) rather than stable — YouTube's anti-bot changes are usually patched in nightly well before the next stable release, and a stable-only yt-dlp means every `HTTP Error 403: Forbidden` download failure just sits broken until stable catches up.
- **ClamAV** (`clamav` + `clamav-scanner`) — scans everything that lands in `/mnt/nas/downloads`, independently of which of the above put it there. See "Virus scanning" below.

All nine containers are deployed together as one Docker Compose application inside a dedicated LXC (`downloads`), same pattern as `jellyfin`, `n8n`, and the `monitoring` stack (multiple related containers, one LXC).

## Directory Structure

```text
services/downloads/
├── README.md
├── compose.yaml
└── .env.example
```

## Architecture

```text
             Proxmox host (192.168.0.157)
                        │
          systemd mount units (CIFS/SMB)
                        │
        ┌───────────────┴───────────────┐
        ▼                                ▼
//<nas>/proxmox/data/downloads   //<nas>/proxmox/data/jellyfin
  /mnt/pve/downloads (rw)          /mnt/pve/jellyfin (rw)
        │                                │
        │            bind-mounted into both the downloads LXC (rw, mp0/mp1)
        │            and the jellyfin LXC (ro there — see ansible/roles/jellyfin/)
        ▼                                ▼
                     downloads LXC
                           │
                    Docker Compose
                           │
      ┌───────────┬───────────┬────┴────┬───────────┬───────────┐
      │           │           │         │           │           │
  gluetun     prowlarr     sonarr    radarr      pyload      metube
      │        :9696       :8989    :7878        :8000       :8081
      │
  qbittorrent
     :8080
  (shares gluetun's
   network namespace)
      │
      ├── /downloads ──────────────────────┐
      │                                    │
      ▼                                    ▼
/mnt/nas/downloads/torrents      sonarr/radarr also read this path,
                                  then move the finished file to:
                                        │
                        ┌───────────────┴───────────────┐
                        ▼                                ▼
              /mnt/nas/jellyfin/series        /mnt/nas/jellyfin/movies
           (same folder Jellyfin reads,     (same folder Jellyfin reads,
                  read-only there)                 read-only there)

pyload   → /mnt/nas/downloads/direct
metube   → /mnt/nas/downloads/youtube

clamav-scanner polls all of /mnt/nas/downloads (read-only) and reports
to clamav:3310 — independent of qBittorrent/pyLoad/MeTube, so it covers
whatever any of them writes.
```

## Persistence

| Path                            | Backing                              | Contents                                             |
| -------------------------------- | ------------------------------------- | ----------------------------------------------------- |
| `/mnt/nas/downloads/torrents`    | NAS share, bind-mounted (rw)           | qBittorrent's active + finished torrent data           |
| `/mnt/nas/downloads/direct`      | NAS share, bind-mounted (rw)           | pyLoad's finished downloads                            |
| `/mnt/nas/downloads/youtube`     | NAS share, bind-mounted (rw)           | MeTube's finished downloads                            |
| `/mnt/nas/jellyfin/movies`       | NAS share, bind-mounted (rw)           | Radarr's organized movie library — same path Jellyfin reads (read-only there) |
| `/mnt/nas/jellyfin/series`       | NAS share, bind-mounted (rw)           | Sonarr's organized TV library — same path Jellyfin reads (read-only there) |
| `gluetun-config`, `*-config`     | Docker named volumes                   | App state: VPN state, WebUI settings, indexer/download-client wiring, watch lists, history |

Every `*-config` volume is worth backing up (indexer config, download-client wiring, watch/wanted lists); the NAS paths are the actual media, backed up (or not) as part of whatever NAS-level backup policy applies to the NAS itself.

### Why Sonarr/Radarr copy instead of hardlink

Sonarr/Radarr can do an instant, zero-extra-space "hardlink" import instead of a copy, but only when the download folder and the final library folder are on the **same filesystem**. Here they're two separate bind mounts (even though both ultimately live on the same NAS), so imports are a copy-then-delete-source instead — slower and briefly doubles disk usage for the file being moved, but correct. If this becomes a real bottleneck, the fix is putting `/downloads/torrents` and the library folders under one shared NAS folder instead of two separate ones.

### NAS prerequisite (mostly one-time, partly automated)

Downloads staging and the media library live on the NAS over **CIFS/SMB** (a `proxmox` share, `data/downloads` and `data/jellyfin/{movies,series}` subfolders — user/password auth), mounted on the **Proxmox host itself and bind-mounted into the LXC**. Unprivileged LXCs (this one included) can't mount CIFS/NFS themselves — see `ansible/roles/minecraft/README.md` for the full explanation (kernel limitation, not a permissions gap).

The CIFS mount on the Proxmox host (below) is still a one-time manual step. Binding it into the LXC (`pct set -mp0/-mp1`) is **not** manual — the `downloads` Ansible role does this itself on every deploy (delegating to the `proxmox` inventory host over SSH, since `pct set` needs `root@pam` and this repo's Terraform API token is deliberately least-privilege — see `ansible/roles/downloads/README.md#nas-bind-mounts`). It's idempotent and self-heals if the LXC is ever destroyed and recreated (the systemd mount units on the Proxmox host survive on their own regardless).

`data/jellyfin` is the **same NAS folder** `ansible/roles/jellyfin/` already bind-mounts — its own bind into the `jellyfin` LXC stays read-only there (`pct set ... ro=1`), while this LXC needs read-write, so the underlying host-side CIFS mount itself has to be read-write (with permissive `file_mode`/`dir_mode` so both LXCs' UIDs can access it — see below).

Run this once on the **Proxmox host** (`192.168.0.157`), as root, after the `downloads` LXC (`vm_id 216`) exists — create the `data/downloads` folder inside the NAS's `proxmox` share first (`data/jellyfin/{movies,series}` should already exist from the Jellyfin deploy):

```bash
mkdir -p /mnt/pve/downloads

cat > /etc/pve-nas-downloads-credentials <<'EOF'
username=<your NAS username>
password=<your NAS password>
EOF
chmod 600 /etc/pve-nas-downloads-credentials

cat > /etc/systemd/system/mnt-pve-downloads.mount <<'EOF'
[Unit]
Description=CIFS mount for downloads staging (proxmox/data/downloads NAS share)
After=network-online.target
Before=pve-guests.service
Wants=network-online.target

[Mount]
What=//<nas-ip>/proxmox/data/downloads
Where=/mnt/pve/downloads
Type=cifs
# uid/gid 101000 = PUID/PGID 1000 (linuxserver.io images) mapped through
# the LXC's standard root:100000:65536 unprivileged offset.
Options=credentials=/etc/pve-nas-downloads-credentials,uid=101000,gid=101000,vers=3.0,_netdev

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mnt-pve-downloads.mount
```

The `pct set -mp0/-mp1` binds into the LXC itself are handled by the Ansible role from here on — no need to run them by hand (see above).

If `mnt-pve-jellyfin.mount` (from the Jellyfin deploy) is still mounted read-only at the CIFS level, switch it to read-write here too — Jellyfin's own access stays read-only via its `ro=1` bind flag regardless:

```bash
# In /etc/systemd/system/mnt-pve-jellyfin.mount, change:
#   uid=100000,gid=100000,vers=3.0,ro,_netdev
# to:
#   uid=101000,gid=101000,vers=3.0,file_mode=0664,dir_mode=0775,_netdev
systemctl daemon-reload
systemctl restart mnt-pve-jellyfin.mount
```

`pct set` applies live to a running container, no reboot needed, and isn't tracked by Terraform (see above) — but is tracked and reapplied by Ansible, so a recreated LXC gets its NAS mounts back on the next `make deploy-downloads` without anyone having to remember this.

## VPN (gluetun)

Only qBittorrent's traffic goes through the VPN — `network_mode: service:gluetun` in `compose.yaml` makes it share gluetun's network namespace, so it has no IP/ports of its own; every request the container makes leaves through the tunnel. Prowlarr, Sonarr, Radarr, pyLoad, and MeTube are unaffected and reach the internet directly, same as any other service in this homelab.

gluetun needs a WireGuard-capable VPN provider (Mullvad, ProtonVPN, AirVPN, etc. — see the [provider list](https://github.com/qdm12/gluetun/wiki)) and three secrets that must **never** be committed:

```text
VPN_SERVICE_PROVIDER
WIREGUARD_PRIVATE_KEY
WIREGUARD_ADDRESSES
```

These are passed in the same way `n8n_postgres_password` is today — as environment variables consumed by the Makefile's `ANSIBLE_EXTRA_VARS` at deploy time (see `ansible/roles/downloads/README.md`).

### LXC prerequisite: `/dev/net/tun`

gluetun needs `/dev/net/tun` and `NET_ADMIN` to bring up the WireGuard interface *inside* the container, which in turn needs the **Proxmox host** to expose `/dev/net/tun` into the (unprivileged) `downloads` LXC. This is a manual, one-time Proxmox-side step the same way the Cloudflare Tunnel credentials and AdGuard's first-run wizard are — it isn't expressed in `terraform/proxmox/lxc.tf` today. If gluetun fails to create the WireGuard interface after deploying, this is the first thing to check.

## Virus scanning

VirusTotal was considered and rejected as the primary mechanism: its public API caps uploads at 650MB and 4 requests/minute, and a movie or a good-quality TV episode routinely exceeds that — the file just doesn't fit.

Instead, **ClamAV** (`clamav` + `clamav-scanner` in `compose.yaml`) scans locally, with no size limit and no API key:

- `clamav` runs `clamd` — the AV engine and virus database, reachable only at `clamav:3310` on this Compose network. No ports published to the host or LAN; clamd's wire protocol is unencrypted, so nothing outside this stack should ever talk to it.
- `clamav-scanner` (`scripts/clamav-scan-watch.sh`) polls `/mnt/nas/downloads` (read-only) every 60s for files that are new and have stopped growing (i.e. not still mid-download), and scans each one against `clamav` over TCP. It's independent of qBittorrent/pyLoad/MeTube, so it covers whatever any of them writes, not just torrents.
- Size limits are raised well past clamd's email-oriented defaults (`StreamMaxLength`/`MaxFileSize`/`MaxScanSize` default to 25-100MB) via `CLAMD_CONF_*` env vars — see `compose.yaml`. Files larger than 8GB (an oversized 4K remux, say) are skipped rather than scanned; that's a deliberate homelab-scale tradeoff, not an oversight.
- Infected files are **logged, not deleted or quarantined automatically** — `docker exec downloads-clamav-scanner cat /state/infected.log`. Sonarr/Radarr import on their own schedule and don't know about this scanner, so automatically deleting mid-import felt riskier than a manual check.

A verified-known-file hash lookup against VirusTotal (no upload, no size limit, free) would be a reasonable complement to add later, but isn't implemented — ClamAV's local signature scan is the one actually running.

## Networking

Every service in this stack is `tier: internal` — reached directly by LAN `IP:port`, no Traefik. None of it is routed through the Cloudflare Tunnel: a torrent client and download automation have no business being reachable from the public internet.

| Service     | LAN IP:port            |
| ----------- | ----------------------- |
| qBittorrent | `192.168.0.216:8080`    |
| Prowlarr    | `192.168.0.216:9696`    |
| Sonarr      | `192.168.0.216:8989`    |
| Radarr      | `192.168.0.216:7878`    |
| pyLoad      | `192.168.0.216:8000`    |
| MeTube      | `192.168.0.216:8081`    |

`clamav` and `clamav-scanner` publish no ports at all — nothing outside this Compose stack needs to reach clamd, and its wire protocol is unencrypted, so it stays off both the LAN and the host's own network namespace.

## Resource sizing

4 vCPU / 6GB RAM, 24GB disk (image layers + `*-config` volumes only — all downloaded/media data is on the NAS). Nine containers share this budget; Sonarr/Radarr/Prowlarr (.NET) and ClamAV's virus databases (~300-700MB loaded in memory) are the heavier ones. Revisit (`config/hosts.yaml`) if imports start queueing up or the WebUIs feel sluggish under load.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── downloads.yaml
└── roles/
    └── downloads/
```

```bash
export DOWNLOADS_VPN_SERVICE_PROVIDER=...
export DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY=...
export DOWNLOADS_VPN_WIREGUARD_ADDRESSES=...
make deploy-downloads
```

## First-run configuration

Most of the wiring a fresh Jellyfin-style setup wizard would normally make you click through by hand is done automatically by the `downloads` Ansible role, on every deploy, idempotently — see `ansible/roles/downloads/README.md#app-wiring`:

- **qBittorrent** — permanent WebUI username/password (`downloads_qbittorrent_username`/`downloads_qbittorrent_password`), since there's no env var for this upstream. Also configured to only run at full speed overnight (23:00-08:00 by default, throttled to a trickle the rest of the day) via its Alternative Speed Limits scheduler — see `ansible/roles/downloads/README.md#qbittorrent-night-only-schedule` to change the hours or turn it off (`downloads_qbittorrent_scheduler_enabled: false`).
- **Radarr** — root folder `/movies`, qBittorrent as its download client.
- **Sonarr** — root folder `/tv`, qBittorrent as its download client.
- **Prowlarr** — Radarr and Sonarr added as connected apps (`Settings → Apps`), so any indexer added to Prowlarr propagates to both automatically.

**Not automated, and never will be** — this is the one genuinely manual step left: add your indexers in Prowlarr (`Settings → Indexers → Add Indexer`, public or private trackers, with your own credentials for private ones). Which indexers to use is a personal choice this role has no business making; they live in the `prowlarr-config` volume once added, and survive redeploys same as everything else in `*-config`.

pyLoad and MeTube need no wiring at all — open the WebUI and paste a link.

## Usage

### Requesting a TV show

Sonarr (`:8989`) → **Series → Add New**, search the title, pick what to monitor (everything, only future episodes, current season only, …), and add it. If the show is still airing, Sonarr watches the RSS feed and grabs new episodes on its own from then on.

### Requesting a movie

Radarr (`:7878`) → **Movies → Add New**, search, add with a quality profile and the `/movies` root folder. Radarr searches Prowlarr's indexers, sends the best result to qBittorrent, and renames + imports the finished file into `/movies` once it lands.

Either way, the file shows up in Jellyfin on its next library scan (or trigger one by hand from Jellyfin's admin panel if you don't want to wait).

### Direct link or video

These two skip Prowlarr and the VPN entirely — paste a link and it downloads:

- **pyLoad** (`:8000`) — a direct HTTP/FTP link, not a torrent or a video site, lands in `/mnt/nas/downloads/direct`.
- **MeTube** (`:8081`) — a YouTube (or any yt-dlp-supported site) link, lands in `/mnt/nas/downloads/youtube`.

## Local Development

```bash
cd services/downloads

cp .env.example .env
mkdir -p /tmp/downloads-nas/{torrents,direct,youtube,multimedia/peliculas,multimedia/series}   # stand-in for the NAS mounts

docker compose up -d
```

Note: `compose.yaml`'s bind mounts point at `/mnt/nas/...` (what the Ansible role sets up on the real LXC). For local development, either create those exact paths locally or edit the bind mounts to point at `/tmp/downloads-nas/...` before running.

## Monitoring

None of these have a native Prometheus `/metrics` endpoint, so each WebUI is probed by `blackbox_exporter` for up/down + latency instead (see `config/services.yaml`, `services/blackbox-exporter/README.md`) and added to Uptime Kuma as an HTTP monitor on its port.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration, the NFS mounts, secrets templating, and Docker Compose deployment. This directory manages the Compose definition and application configuration.
