# Keycloak

[Keycloak](https://www.keycloak.org/) is the homelab's identity and access management server — a single-sign-on / OIDC provider meant to sit in front of apps that shouldn't manage their own user accounts, including external-facing services and the k3s cluster's workloads.

## Responsibilities

- Serves the Keycloak admin console and OIDC/SAML endpoints.
- Persists all realm/user/client state in a dedicated Postgres, whose data lives on the NAS, not on the LXC's own disk.

Keycloak is deployed as a Docker Compose application (Keycloak + Postgres) inside a dedicated LXC container, same pattern as `n8n` (app + Postgres) and `rustfs` (NAS-backed data).

## Directory Structure

```text
services/keycloak/
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
        //<nas>/proxmox/data/keycloak
          mounted at /mnt/pve/keycloak
                        │
        bind-mounted into the LXC as mp0
                        │
                        ▼
                  keycloak LXC
                        │
                 Docker Compose
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
          keycloak             postgres
          :8080 (HTTP)     /mnt/nas/keycloak
```

## NAS prerequisite (one-time, manual)

Postgres data lives on the NAS over **CIFS/SMB** (a `proxmox` share, `data/keycloak` subfolder — user/password auth), mounted on the **Proxmox host itself and bind-mounted into the LXC**, not mounted by Ansible inside the container. Unprivileged LXCs can't mount CIFS/NFS themselves (confirmed while building `services/rustfs/` and `services/minecraft/` — `mount error(1): Operation not permitted`, even with Proxmox's `features.mount = ["cifs", "nfs"]` flag set); `ansible/roles/keycloak/` does not manage this mount at all.

Run this once on the **Proxmox host** (`192.168.0.157`), as root, after the `keycloak` LXC (`vm_id 221`) exists — create the `data/keycloak` folder inside the NAS's `proxmox` share first:

```bash
mkdir -p /mnt/pve/keycloak

cat > /etc/pve-nas-keycloak-credentials <<'EOF'
username=<your NAS username>
password=<your NAS password>
EOF
chmod 600 /etc/pve-nas-keycloak-credentials

cat > /etc/systemd/system/mnt-pve-keycloak.mount <<'EOF'
[Unit]
Description=CIFS mount for Keycloak Postgres data (proxmox/data/keycloak NAS share)
After=network-online.target
# Without this, pve-guests.service (which starts LXCs on boot) has no
# ordering relative to this mount and can start the container before
# the share is mounted, leaving the bind mount empty on that boot.
Before=pve-guests.service
Wants=network-online.target

[Mount]
What=//<nas-ip>/proxmox/data/keycloak
Where=/mnt/pve/keycloak
Type=cifs
# uid/gid 100999 = the official postgres:16 image's fixed non-root
# "postgres" user (UID/GID 999) mapped through the LXC's standard
# root:100000:65536 unprivileged offset (check /etc/subuid if this
# LXC's mapping is non-default).
Options=credentials=/etc/pve-nas-keycloak-credentials,uid=100999,gid=100999,vers=3.0,_netdev

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mnt-pve-keycloak.mount

pct set 221 -mp0 /mnt/pve/keycloak,mp=/mnt/nas/keycloak
```

The `pct set` step applies live to a running container (no reboot needed) but is **not tracked by Terraform** (adding a `mount_point` requires `root@pam`; this repo's API token is deliberately least-privilege) — if the LXC is ever destroyed and recreated, redo just that last `pct set` line (the systemd mount unit on the host survives on its own).

## Credentials

`KEYCLOAK_ADMIN_USERNAME` / `KEYCLOAK_ADMIN_PASSWORD` bootstrap the initial Keycloak admin account; `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` are the dedicated Postgres's own credentials. None of these must ever be committed to Git or left empty.

In the homelab deployment these come from Ansible Vault / CI secrets via the `keycloak` Ansible role (`ansible/roles/keycloak/`), not from a checked-in `.env`. The role refuses to run if the admin or Postgres password is empty.

## Networking

Reached directly by its LAN `IP:port`, no reverse proxy in front of it (`tier: internal`, see `config/services.yaml`):

```text
http://192.168.0.221:8080
```

Not routed through Traefik or Cloudflared. Apps on the LAN (including k3s workloads, which share the same flat network) reach it directly by this IP:port for OIDC discovery/token/login endpoints, the same way they'd reach any other internal backend. If a public-facing (`personal`/`public` tier) app ever needs the login page itself reachable from outside the LAN, add an `external:` block (see `jellyfin` in `config/services.yaml`) rather than changing Keycloak's own tier.

## Backup

Unlike RustFS's bulk object data, Postgres here holds realms, users, and client configuration — genuinely important state, the same category as the Obsidian vault. It's still out of this repo's Proxmox/Docker-volume backup scope (the data lives on the NAS, not in a Docker volume the LXC owns), but it must be covered by a NAS-level backup, not skipped. See [`docs/storage.md`](../../docs/storage.md).

## Local Development

```bash
cd services/keycloak
KEYCLOAK_ADMIN_USERNAME=admin \
KEYCLOAK_ADMIN_PASSWORD=devpassword \
POSTGRES_DB=keycloak \
POSTGRES_USER=keycloak \
POSTGRES_PASSWORD=devpassword \
docker compose up -d
```

Without a real NAS mount, `/mnt/nas/keycloak` won't exist locally — point Postgres's `volumes:` at a throwaway local directory first if testing outside Ansible.
