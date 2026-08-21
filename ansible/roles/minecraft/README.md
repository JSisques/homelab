# Minecraft Ansible Role

Deploys a PaperMC server behind [lazymc](https://github.com/timvisee/lazymc) (via [lazymc-docker-proxy](https://github.com/joesturge/lazymc-docker-proxy)) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application. It does **not** handle the NAS mount — see below.

## Responsibilities

- Create the application directory (`minecraft_app_dir`, default `/opt/minecraft`)
- Render `.env` with `MINECRAFT_RCON_PASSWORD`
- Deploy `services/minecraft/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## World storage: a Proxmox-level bind mount, not an Ansible task

Unlike `rustfs` (which mounts NFS *inside* its own LXC via `ansible.posix.mount`), Minecraft's world data at `/mnt/nas/minecraft` comes from a **host-side CIFS mount bind-mounted into the LXC**, set up once on the Proxmox host itself — not by this role.

Why: unprivileged LXCs (all of them in this repo) cannot reliably mount CIFS/NFS themselves, even with `features.mount = ["cifs", "nfs"]` set in `terraform/proxmox/lxc.tf` — it fails with `mount error(1): Operation not permitted`. This is a kernel-level limitation of unprivileged containers, not something the feature flag or more `ansible.posix.mount` options can fix. The standard workaround (and what's used here) is to mount the network share on the Proxmox host and bind-mount that host directory into the container — the same pattern this Proxmox host already uses for PBS's own NAS-backed backup storage (`/etc/pve/storage.cfg`'s `cifs: backup` entry).

Concretely, on the **Proxmox host** (`192.168.0.157`), not the LXC:

1. A systemd mount unit (`/etc/systemd/system/mnt-pve-minecraft.mount`) mounts `//<nas>/proxmox/data/minecraft` at `/mnt/pve/minecraft`, using a credentials file at `/etc/pve-nas-minecraft-credentials` (mode `0600`) and `uid=101000,gid=101000` — the LXC's unprivileged UID/GID mapping (`root:100000:65536` in `/etc/subuid`) means container UID `1000` (itzg/minecraft-server's default) maps to host UID `101000`.
2. `pct set 217 -mp0 /mnt/pve/minecraft,mp=/mnt/nas/minecraft` gives the LXC that directory as `mp0`.

Both steps are manual, host-level, and **cannot be applied through this repo's Terraform** — changing an LXC's `features` or adding a `mount_point` requires `root@pam` per the [provider docs](https://github.com/bpg/terraform-provider-proxmox/blob/main/docs/resources/virtual_environment_container.md), and this repo's Proxmox API token is deliberately least-privilege, not `root@pam`. If the `minecraft` LXC is ever destroyed and recreated, both the systemd mount unit survives (it's host-level, untouched by recreating the LXC) but **step 2 (`pct set -mp0`) must be redone** — the new container won't have it. See `services/minecraft/README.md` for the exact commands.

## Secrets

`minecraft_rcon_password` is required — the role fails loudly via `ansible.builtin.assert` if it's empty, same approach as `cookidoo-mcp`, `cloudflared`, and `rustfs`. Provide it via Ansible Vault or `-e`/CI secrets.

NAS credentials for the host-side mount are **not** an Ansible secret — they live only in `/etc/pve-nas-minecraft-credentials` on the Proxmox host (created manually, see above).

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/minecraft.yaml
```
