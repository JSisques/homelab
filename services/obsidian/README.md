# Obsidian

Obsidian is the homelab's "second brain" — a Markdown vault that AI agents (Claude, etc.) can read and write through MCP, rather than a note-taking app you open in a browser.

## Responsibilities

- Hosts a single Obsidian vault, headless (no GUI exposed).
- Exposes that vault to MCP clients over Streamable HTTP / SSE, so an agent can list, read, search, and edit notes.
- Keeps the vault's actual Markdown files on the NAS, not on the LXC's local disk.

Obsidian is deployed as a Docker Compose application inside a dedicated LXC container, same as `n8n` and `it-tools`.

## Directory Structure

```text
services/obsidian/
├── README.md
└── compose.yaml
```

No `.env.example` — there are no secrets in the default (no-OAuth, no git-sync) configuration this deploys with.

## Architecture

```text
             Proxmox host (192.168.0.157)
                        │
          systemd mount unit (CIFS/SMB)
                        │
                        ▼
           //<nas>/proxmox/data/obsidian
          mounted at /mnt/pve/obsidian
                        │
        bind-mounted into the LXC as mp0
                        │
                        ▼
                  obsidian LXC
                        │
                 Docker Compose
                        │
                        ▼
              ┌───────────────────┐
              │obsidian-remote     │
              │(shanehull)         │
              │                    │
              │ headless Obsidian  │
              │       +            │
              │ Local REST API     │
              │  plugin (internal, │
              │  127.0.0.1 only)   │
              │       +            │
              │ Go MCP bridge      │
              │  :4000 (HTTP/SSE)  │
              └─────────┬──────────┘
                        │
              /vaults (bind mount)
                        │
                        ▼
                 /mnt/nas/obsidian
```

## What this container is

[`shanehull/obsidian-remote`](https://github.com/shanehull/obsidian-remote) runs a real (headless) Obsidian instance under Xvfb, with the community [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) plugin pre-installed and bound to `127.0.0.1` only, fronted by a small Go server that speaks MCP (Streamable HTTP on `/mcp`, SSE on `/sse`) and translates tool calls into REST API calls. There is no browser GUI exposed — everything happens through MCP tool calls (list/read/update/delete notes, search, manage frontmatter and tags).

There is no published image for this project, so `compose.yaml` builds it straight from its GitHub repository (`build: https://github.com/shanehull/obsidian-remote.git#v1.2.0`), pinned to a release tag rather than `main`, so a redeploy doesn't silently pick up upstream changes. Bumping the version is a one-line change to that tag.

## Vault persistence — why `TEST_MODE=true` is intentional

`shanehull/obsidian-remote` has two vault-sourcing modes, chosen by `TEST_MODE`:

- `TEST_MODE=false` expects `GIT_REPO_URL`/`GITHUB_PAT` and clones/pulls a vault from git on every boot. That means running a git host as a dependency, and it's the only path upstream actually downloads the Local REST API plugin's code on a **first** boot.
- `TEST_MODE=true` seeds a **new** vault directory — including the Local REST API plugin — the first time `/vaults` has no `.obsidian` directory, and does nothing on every boot after that.

This deployment has no git remote at all: the vault lives entirely on the NAS via the `/mnt/nas/obsidian:/vaults` bind mount in `compose.yaml`. `TEST_MODE=true` is what makes the very first boot self-bootstrap a working vault (with the REST API plugin actually installed) directly onto that NFS-backed path. Because persistence comes from the bind mount, not from the container, that "seed" is not disposable in this setup — it's the vault, permanently. Every boot after the first is a no-op for `init-vault.sh` (`.obsidian` already exists), so this is safe to leave as-is indefinitely.

## Persistence

Two volumes matter:

| Path      | Backing                              | Contents                                                   |
| --------- | ------------------------------------ | ------------------------------------------------------------ |
| `/vaults` | NAS share, bind-mounted (rw)         | The actual vault: Markdown notes, attachments, plugin config |
| `/config` | Docker named volume `obsidian-config`| Obsidian app state (vault ID, trust/open flags)               |

Only `/vaults` needs to be backed up — `/config` regenerates itself deterministically from `init-vault.sh` if lost.

### NAS prerequisite (one-time, manual)

The vault lives on the NAS over **CIFS/SMB** (a `proxmox` share, `data/obsidian` subfolder — user/password auth), mounted on the **Proxmox host itself and bind-mounted into the LXC**, not mounted by Ansible inside the container. Unprivileged LXCs (this one included) can't mount CIFS/NFS themselves — see `ansible/roles/minecraft/README.md` for the full explanation (kernel limitation, not a permissions gap).

Run this once on the **Proxmox host** (`192.168.0.157`), as root, after the `obsidian` LXC (`vm_id 213`) exists — create the `data/obsidian` folder inside the NAS's `proxmox` share first:

```bash
mkdir -p /mnt/pve/obsidian

cat > /etc/pve-nas-obsidian-credentials <<'EOF'
username=<your NAS username>
password=<your NAS password>
EOF
chmod 600 /etc/pve-nas-obsidian-credentials

cat > /etc/systemd/system/mnt-pve-obsidian.mount <<'EOF'
[Unit]
Description=CIFS mount for Obsidian vault (proxmox/data/obsidian NAS share)
After=network-online.target
# Without this, pve-guests.service (which starts LXCs on boot) has no
# ordering relative to this mount and can start the container before
# the share is mounted, leaving the bind mount empty on that boot.
Before=pve-guests.service
Wants=network-online.target

[Mount]
What=//<nas-ip>/proxmox/data/obsidian
Where=/mnt/pve/obsidian
Type=cifs
# uid/gid 100911 = obsidian-remote's default container user (911, the
# linuxserver.io convention) mapped through the LXC's standard
# root:100000:65536 unprivileged offset (check /etc/subuid if this
# LXC's mapping is non-default).
Options=credentials=/etc/pve-nas-obsidian-credentials,uid=100911,gid=100911,vers=3.0,_netdev

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mnt-pve-obsidian.mount

pct set 213 -mp0 /mnt/pve/obsidian,mp=/mnt/nas/obsidian
```

The `pct set` step applies live to a running container (no reboot needed) but is **not tracked by Terraform** (adding a `mount_point` requires `root@pam`; this repo's API token is deliberately least-privilege) — if the LXC is ever destroyed and recreated, redo just that last `pct set` line (the systemd mount unit on the host survives on its own).

## Networking

Obsidian's MCP endpoint is reached directly by its LAN `IP:port`, no reverse proxy in front of it:

```text
http://192.168.0.213:4000/mcp   (Streamable HTTP)
http://192.168.0.213:4000/sse   (SSE)
```

Same trust model as `n8n`/`grafana`/other internal services: no auth in front of it beyond being on the LAN or WireGuard — see "Auth" below if that ever needs to change. The internal application port is `4000`.

## Auth

`obsidian-remote` supports optional OAuth 2.0 (`OAUTH_ISSUER`, `OAUTH_JWKS_URL`, `OAUTH_AUDIENCE`, `OAUTH_CLIENT_SECRET`, `OAUTH_ALLOWED_EMAIL`) in front of the MCP endpoint. It's deliberately not configured here, matching every other `tier: internal` service in this repo — if this ever needs to be reachable from outside the LAN/VPN, add OAuth (or put it behind the Cloudflare Tunnel + Authelia/Authentik once that lands, see the repo root README's roadmap) rather than exposing it bare.

## Resource sizing

Headless Chromium/Electron is heavier than the other single-container services here (`it-tools`, `adguard-home-1`): 2 vCPU / 2GB RAM, 20GB disk (image layers from the `docker build` step, not vault data — that's all on the NAS). `shm_size: "1gb"` in `compose.yaml` avoids Chromium crashing on the default 64MB `/dev/shm`.

If the container fails to start on first deploy, the most likely cause is the unprivileged LXC's `nesting=true` feature not being enough for headless Chromium's sandbox — see `terraform/proxmox/lxc.tf`. That's a per-container Proxmox feature flag, not something this role can fix on its own.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── obsidian.yaml
└── roles/
    └── obsidian/
```

```bash
make deploy-obsidian
```

## Local Development

```bash
cd services/obsidian

mkdir -p /mnt/nas/obsidian   # stand-in for the bind-mounted NAS folder

docker compose up -d --build
```

The first boot builds the image from the pinned upstream tag (needs internet access) and seeds the vault — check `docker compose logs -f obsidian` for `Init complete. Headless Obsidian is ready.`.

## Monitoring

Obsidian should be monitored by Uptime Kuma as a **TCP** monitor on port `4000`, not an HTTP one — the MCP endpoint doesn't serve a plain `GET /` 200 response, so an HTTP monitor would flap. Not wired into `blackbox_exporter`/Prometheus for the same reason (see `config/services.yaml`, `services/blackbox-exporter/README.md`).

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). The Proxmox host mounts the NAS share and bind-mounts it into the LXC (manual, see "NAS prerequisite" above). Ansible manages host configuration and Docker Compose deployment. This directory manages the Compose definition and application configuration.
