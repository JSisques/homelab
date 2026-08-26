# Days Off Ansible Role

This role deploys [Days Off](https://github.com/sisques-labs/daysoff) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`daysoff_app_dir`, default `/opt/daysoff`)
- Deploy the Compose file from `services/daysoff/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## Variables

Defined in `defaults/main.yaml`:

```yaml
daysoff_app_dir: /opt/daysoff
```

Days Off has no persistent state and no secrets, so no further configuration is required.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/daysoff.yaml
```

Service documentation: [`services/daysoff/README.md`](../../../services/daysoff/README.md).
