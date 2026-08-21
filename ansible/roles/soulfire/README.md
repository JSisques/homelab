# SoulFire Ansible Role

Prepares an LXC container and deploys SoulFire (see `services/soulfire/README.md`) using Docker Compose.

## Responsibilities

- Create the application directory and deploy `services/soulfire/compose.yaml` to it.
- Start the stack with Docker Compose.

Terraform is responsible for creating the LXC container. No NAS mount, no secrets — SoulFire's own admin account is created through its web UI on first visit, not injected via Ansible.

## Directory Structure

```text
ansible/roles/soulfire/
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
soulfire_app_dir: /opt/soulfire
```

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/soulfire.yaml
```

or, from the repo root:

```bash
make deploy-soulfire
```

This LXC is meant to be off between test sessions — start it in Proxmox before deploying/using it, and stop it again afterwards (see `services/soulfire/README.md`).

## Related

- `terraform/proxmox/lxc.tf` — creates the `soulfire` LXC.
- `services/soulfire/` — Compose definition and application-level documentation.
- `ansible/roles/stirling-pdf/` — closest model for this role: single container, no secrets, no NAS mount.
