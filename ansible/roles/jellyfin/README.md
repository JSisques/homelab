# Jellyfin Ansible Role

Prepares an LXC container and deploys Jellyfin (see `services/jellyfin/README.md`) using Docker Compose, with its media libraries mounted from NFS exports on the NAS.

## Responsibilities

- Install NFS client utilities and mount the NAS exports (`jellyfin_nas_export_peliculas`, `jellyfin_nas_export_series`, **adjust the defaults to your real export paths**) at `jellyfin_media_mount_path`.
- Create the application directory and deploy `services/jellyfin/compose.yaml` to it.
- Start the stack with Docker Compose.

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

jellyfin_nas_export_peliculas: "192.168.0.111:/export/Multimedia/peliculas"
jellyfin_nas_export_series: "192.168.0.111:/export/Multimedia/series"
jellyfin_media_mount_path: /mnt/nas/multimedia
```

No secrets — Jellyfin's admin account is created through its own first-run setup wizard, so there is nothing to inject via Vault.

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
    ├── Install nfs-common
    ├── Mount NAS exports at /mnt/nas/multimedia/{peliculas,series}
    ├── Create /opt/jellyfin
    ├── Deploy compose.yaml
    └── docker compose up -d
             │
             ▼
        jellyfin/jellyfin (:8096)
             │
             ├── Traefik → jellyfin.home.arpa (LAN)
             └── Cloudflare Tunnel → jellyfin.jsisques.net (remote)
```

## Related

- `terraform/proxmox/lxc.tf` — creates the `jellyfin` LXC.
- `services/jellyfin/` — Compose definition and application-level documentation.
- `ansible/roles/obsidian/` — same NFS-mount-from-NAS pattern, used as the model for this role.
