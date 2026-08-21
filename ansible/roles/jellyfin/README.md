# Jellyfin Ansible Role

Prepares an LXC container and deploys Jellyfin (see `services/jellyfin/README.md`) using Docker Compose, with its media libraries mounted from a NAS share.

## Responsibilities

- Create the application directory and deploy `services/jellyfin/compose.yaml` to it.
- Start the stack with Docker Compose.

It does **not** mount the NAS — see "NAS Export" below.

Terraform is responsible for creating the LXC container.

## Directory Structure

```text
ansible/roles/jellyfin/
├── README.md
├── defaults/
│   └── main.yaml
├── meta/
│   └── main.yml
└── tasks/
    └── main.yaml
```

## Variables

```yaml
jellyfin_app_dir: /opt/jellyfin
```

No secrets — Jellyfin's admin account is created through its own first-run setup wizard, so there is nothing to inject via Vault.

## NAS Export

Media never touches the LXC's own disk — `/mnt/nas/jellyfin/{movies,series}` inside the container comes from a **Proxmox-level bind mount**, not this role. Unprivileged LXCs (all of them in this repo) can't mount CIFS/NFS themselves, even with `features.mount = ["cifs", "nfs"]` set (`mount error(1): Operation not permitted` — a kernel limitation, confirmed while building `ansible/roles/minecraft/` and `ansible/roles/rustfs/`, which hit the exact same issue).

The whole `data/jellyfin` folder (covering both `movies` and `series`, and any future subfolder added under it — no extra host-side setup needed for those) is mounted on the **Proxmox host itself** (systemd mount unit + credentials file) and bind-mounted into the LXC via `pct set <vm_id> -mp0 ...` — both manual, one-time steps, not managed by this role or by Terraform (Proxmox requires `root@pam` for `mount_point`/`features` changes; this repo's API token is deliberately least-privilege). See `services/jellyfin/README.md` for the exact commands.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/jellyfin.yaml
```

or, from the repo root:

```bash
make deploy-jellyfin
```

## Deployment Flow

```text
Terraform
    │
    ▼
LXC jellyfin
    │
    ▼
Ansible
    │
    ▼
jellyfin role
    │
    ├── Create /opt/jellyfin
    ├── Deploy compose.yaml
    └── docker compose up -d
             │
             ▼
        jellyfin/jellyfin (:8096)
             │
             ├── LAN IP:port directly → 192.168.0.215:8096 (no Traefik)
             └── Cloudflare Tunnel → Traefik → jellyfin.jsisques.net (remote)
```

(media at `/mnt/nas/jellyfin/{movies,series}` comes from a Proxmox-host-level bind mount set up before any of this runs — see "NAS Export" above.)

## Related

- `terraform/proxmox/lxc.tf` — creates the `jellyfin` LXC.
- `services/jellyfin/` — Compose definition and application-level documentation.
- `ansible/roles/minecraft/`, `ansible/roles/rustfs/` — same host-mount + bind-mount pattern, used as the model for this role.
