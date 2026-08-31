# keycloak Ansible Role

This Ansible role prepares an LXC container and deploys [Keycloak](https://www.keycloak.org/) plus its dedicated Postgres, the homelab's identity and access management server, using Docker Compose.

The role is responsible for configuring the host and deploying the application. The underlying LXC infrastructure is managed separately by Terraform.

## Responsibilities

This role handles:

- Docker installation (via the `docker` role dependency)
- Credential injection (`KEYCLOAK_ADMIN_USERNAME` / `KEYCLOAK_ADMIN_PASSWORD` / `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD`)
- Docker Compose deployment
- Service startup and updates

It does **not** mount the NAS — see "NAS Export" below.

Terraform is responsible for creating the LXC container.

## Directory Structure

```text
ansible/roles/keycloak/
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
services/keycloak/compose.yaml
```

The Ansible role deploys this configuration to the keycloak LXC, under:

```text
/opt/keycloak/
├── compose.yaml
└── .env
```

The `.env` file contains the Keycloak admin and Postgres credentials and must not be committed to Git.

## Variables

Role defaults are defined in `defaults/main.yaml`:

```yaml
keycloak_app_dir: /opt/keycloak

keycloak_admin_username: admin
keycloak_admin_password: ""

keycloak_postgres_db: keycloak
keycloak_postgres_user: keycloak
keycloak_postgres_password: ""
```

## NAS Export

Postgres *data* never touches the LXC's own disk — `/mnt/nas/keycloak` inside the container comes from a **Proxmox-level bind mount**, not this role. Unprivileged LXCs (all of them in this repo) can't mount CIFS/NFS themselves, even with `features.mount = ["cifs", "nfs"]` set (`mount error(1): Operation not permitted` — a kernel limitation, same issue documented in `ansible/roles/rustfs/README.md` and `ansible/roles/minecraft/README.md`).

The NAS share is mounted on the **Proxmox host itself** (systemd mount unit + credentials file) and bind-mounted into the LXC via `pct set <vm_id> -mp0 ...` — both manual, one-time, host-level steps, not managed by this role or by Terraform (Proxmox requires `root@pam` for `mount_point`/`features` changes; this repo's API token is deliberately least-privilege). See `services/keycloak/README.md` for the exact commands, including why the mount needs UID/GID `100999` (the official `postgres:16` image's fixed non-root user `999`, mapped through the LXC's unprivileged offset).

## Secrets

`keycloak_admin_password` and `keycloak_postgres_password` are required — there is no sane default, so the role fails loudly via `ansible.builtin.assert` if either is empty, same approach as `rustfs` and `cookidoo-mcp`.

Provide real values through:

1. Ansible Vault
2. `-e`/`--extra-vars` from CI secrets

```yaml
keycloak_admin_password: "{{ vault_keycloak_admin_password }}"
keycloak_postgres_password: "{{ vault_keycloak_postgres_password }}"
```

## Deployment

The role is normally executed through:

```text
ansible/playbooks/keycloak.yaml
```

```yaml
---
- name: Deploy Keycloak
  hosts: keycloak
  become: true

  roles:
    - keycloak
```

Run it with:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/keycloak.yaml \
  -e "keycloak_admin_password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -e "keycloak_postgres_password=${KEYCLOAK_POSTGRES_PASSWORD}"
```

or, from the repo root:

```bash
make deploy-keycloak
```

## Idempotency

The role should be safe to run repeatedly. Running it again should only modify the host when the desired configuration differs from the current state.

## Monitoring

- Availability: Uptime Kuma + blackbox_exporter against the admin console (`http://192.168.0.221:8080`) — see `config/services.yaml`.
- Host-level: Node Exporter + Promtail, applied automatically via this role's `meta/main.yml` dependencies.

## Related Components

### Terraform

```text
terraform/proxmox/lxc.tf
```

Terraform creates the keycloak LXC, sized from `config/hosts.yaml`.

### Service Configuration

```text
services/keycloak/
├── README.md
└── compose.yaml
```

### Inventory

The keycloak host is generated into the Ansible inventory from `config/hosts.yaml` — see `ansible/README.md`.

## Design Principles

Same as every other role in this repository: Terraform creates infrastructure, Ansible configures the host, `services/keycloak/` defines the application, secrets stay outside Git, and a new keycloak LXC should be deployable from scratch using Terraform and Ansible without manual configuration (beyond the one-time NAS export setup, same caveat as `rustfs`/`minecraft`).
