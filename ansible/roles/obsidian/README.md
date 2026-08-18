# Obsidian Ansible Role

Prepares an LXC container and deploys Obsidian (headless, MCP-only — see `services/obsidian/README.md`) using Docker Compose, with its vault mounted from an NFS export on the NAS.

## Responsibilities

- Install NFS client utilities and mount the NAS export (`obsidian_nas_export`, **adjust the default to your real export path**) at `obsidian_vault_mount_path`.
- Create the application directory and deploy `services/obsidian/compose.yaml` to it.
- Start the stack with Docker Compose (which itself does a `docker build` from a pinned upstream git tag — no image is pulled from a registry).

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

obsidian_nas_export: "{{ hostvars['nas'].ansible_host }}:/export/obsidian"
obsidian_vault_mount_path: /mnt/nas/obsidian
```

No secrets — this role's compose file runs Obsidian without OAuth or git-based vault sync (see `services/obsidian/README.md` for why), so there is nothing to inject via Vault.

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
    ├── Install nfs-common
    ├── Mount NAS export at /mnt/nas/obsidian
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

## Related

- `terraform/proxmox/lxc.tf` — creates the `obsidian` LXC.
- `services/obsidian/` — Compose definition and application-level documentation.
- `ansible/roles/pbs/` — same NFS-mount-from-NAS pattern, used as the model for this role.
