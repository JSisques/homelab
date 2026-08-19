# Obsidian Ansible Role

Prepares an LXC container and deploys Obsidian (headless, MCP-only — see `services/obsidian/README.md`) using Docker Compose, with its vault mounted from a NAS share.

## Responsibilities

- Create the application directory and deploy `services/obsidian/compose.yaml` to it.
- Start the stack with Docker Compose (which itself does a `docker build` from a pinned upstream git tag — no image is pulled from a registry).

It does **not** mount the NAS — see "NAS Export" below.

Terraform is responsible for creating the LXC container.

## Directory Structure

```text
ansible/roles/obsidian/
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
obsidian_app_dir: /opt/obsidian
```

No secrets — this role's compose file runs Obsidian without OAuth or git-based vault sync (see `services/obsidian/README.md` for why), so there is nothing to inject via Vault.

## NAS Export

The vault never touches the LXC's own disk — `/mnt/nas/obsidian` inside the container comes from a **Proxmox-level bind mount**, not this role. Unprivileged LXCs (all of them in this repo) can't mount CIFS/NFS themselves, even with `features.mount = ["cifs", "nfs"]` set (`mount error(1): Operation not permitted` — a kernel limitation, confirmed while building `ansible/roles/minecraft/`).

The NAS share is mounted on the **Proxmox host itself** (systemd mount unit + credentials file) and bind-mounted into the LXC via `pct set <vm_id> -mp0 ...` — both manual, one-time steps, not managed by this role or by Terraform (Proxmox requires `root@pam` for `mount_point`/`features` changes; this repo's API token is deliberately least-privilege). See `services/obsidian/README.md` for the exact commands, including why the mount needs UID/GID `100911` (obsidian-remote's default container user `911`, mapped through the LXC's unprivileged offset).

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/obsidian.yaml
```

or, from the repo root:

```bash
make deploy-obsidian
```

## Deployment Flow

```text
Terraform
    │
    ▼
LXC obsidian
    │
    ▼
Ansible
    │
    ▼
obsidian role
    │
    ├── Create /opt/obsidian
    ├── Deploy compose.yaml
    └── docker compose up -d --build
             │
             ▼
        obsidian-remote
        (headless Obsidian + MCP bridge, :4000)
             │
             ▼
        192.168.0.213:4000 (LAN IP:port, no Traefik)
```

(the vault at `/mnt/nas/obsidian` comes from a Proxmox-host-level bind mount set up before any of this runs — see "NAS Export" above.)

## Related

- `terraform/proxmox/lxc.tf` — creates the `obsidian` LXC.
- `services/obsidian/` — Compose definition and application-level documentation.
- `ansible/roles/minecraft/`, `ansible/roles/rustfs/`, `ansible/roles/jellyfin/`, `ansible/roles/downloads/` — same host-mount + bind-mount pattern, used as the model for this role.
