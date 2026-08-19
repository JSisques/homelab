# Minecraft Ansible Role

Deploys a PaperMC server behind [lazymc](https://github.com/timvisee/lazymc) (via [lazymc-docker-proxy](https://github.com/joesturge/lazymc-docker-proxy)) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role), mounts the NAS-backed world storage, and deploys the application.

## Responsibilities

- Mount the NAS CIFS/SMB share that holds the world data (`minecraft_nas_share`, default `//<nas>/proxmox/data/minecraft`) at `minecraft_data_mount_path` (default `/mnt/nas/minecraft`)
- Create the application directory (`minecraft_app_dir`, default `/opt/minecraft`)
- Render `.env` with `MINECRAFT_RCON_PASSWORD`
- Deploy `services/minecraft/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## NAS share

Unlike `rustfs` (NFS), this NAS share is **CIFS/SMB** — it needs a username and password. The share (`proxmox`) and the `data/minecraft` folder inside it must already exist on the NAS before this role runs; nothing here creates them. See `services/minecraft/README.md`.

## Secrets

`minecraft_nas_username`, `minecraft_nas_password`, and `minecraft_rcon_password` are all required — the role fails loudly via `ansible.builtin.assert` if any is empty, same approach as `cookidoo-mcp`, `cloudflared`, and `rustfs`.

Provide real values through:

1. Ansible Vault
2. `-e`/`--extra-vars` from CI secrets

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/minecraft.yaml
```
