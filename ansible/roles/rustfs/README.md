# rustfs Ansible Role

This Ansible role prepares an LXC container and deploys [RustFS](https://rustfs.com/), the homelab's S3-compatible object storage, using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation (via the `docker` role dependency)
- NFS client installation and mounting the NAS export that backs RustFS's object data
- Credential injection (`RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`)
- Docker Compose deployment
- Service startup and updates

Terraform is responsible for creating the LXC container.

## Directory Structure

```text
ansible/roles/rustfs/
├── README.md
├── meta/
│   └── main.yml
├── defaults/
│   └── main.yaml
├── templates/
│   └── env.j2
└── tasks/
    └── main.yaml
```

## Service Definition

The Docker Compose definition is maintained in:

```text
services/rustfs/compose.yaml
```

The Ansible role deploys this configuration to the rustfs LXC, under:

```text
/opt/rustfs/
├── compose.yaml
└── .env
```

The `.env` file contains the RustFS root credentials and must not be committed to Git.

## Variables

Role defaults are defined in `defaults/main.yaml`:

```yaml
rustfs_app_dir: /opt/rustfs

rustfs_nas_export: "192.168.0.111:/export/rustfs"
rustfs_data_mount_path: /mnt/nas/rustfs

rustfs_access_key: ""
rustfs_secret_key: ""
```

## NAS Export

Unlike the app config above, object *data* never touches the LXC's own disk — see `services/rustfs/README.md` for the NAS-side prerequisite (creating the export, and why it must allow writes from UID/GID `10001:10001`, the fixed non-root user RustFS's container runs as).

## Secrets

`rustfs_access_key` and `rustfs_secret_key` are required — there is no sane default, and RustFS's own built-in default (`rustfsadmin`/`rustfsadmin`) is public, so the role fails loudly via `ansible.builtin.assert` if either is empty, same approach as `cookidoo-mcp` and `cloudflared`.

Provide real values through:

1. Ansible Vault
2. `-e`/`--extra-vars` from CI secrets

```yaml
rustfs_access_key: "{{ vault_rustfs_access_key }}"
rustfs_secret_key: "{{ vault_rustfs_secret_key }}"
```

## Deployment

The role is normally executed through:

```text
ansible/playbooks/rustfs.yaml
```

```yaml
---
- name: Deploy RustFS
  hosts: rustfs
  become: true

  roles:
    - rustfs
```

Run it with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/rustfs.yaml \
  -e "rustfs_access_key=${RUSTFS_ACCESS_KEY}" \
  -e "rustfs_secret_key=${RUSTFS_SECRET_KEY}"
```

or, from the repo root:

```bash
make deploy-rustfs
```

## Idempotency

The role should be safe to run repeatedly. Running it again should only modify the host when the desired configuration differs from the current state.

## Monitoring

- Availability: Uptime Kuma + blackbox_exporter against the console (`https://rustfs.home.arpa`) — see `config/services.yaml`.
- Host-level: Node Exporter + Promtail, applied automatically via this role's `meta/main.yml` dependencies.

## Related Components

### Terraform

```text
terraform/proxmox/lxc.tf
```

Terraform creates the rustfs LXC, sized from `config/hosts.yaml`.

### Service Configuration

```text
services/rustfs/
├── README.md
└── compose.yaml
```

### Inventory

The rustfs host is generated into the Ansible inventory from `config/hosts.yaml` — see `ansible/README.md`.

## Design Principles

Same as every other role in this repository: Terraform creates infrastructure, Ansible configures the host, `services/rustfs/` defines the application, secrets stay outside Git, and a new rustfs LXC should be deployable from scratch using Terraform and Ansible without manual configuration (beyond the one-time NAS export setup, same caveat as `obsidian`/`jellyfin`/`pbs`).
