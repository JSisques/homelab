# IT-Tools Ansible Role

This role deploys [IT-Tools](https://github.com/CorentinTh/it-tools) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`it_tools_app_dir`, default `/opt/it-tools`)
- Deploy the Compose file from `services/it-tools/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## Variables

Defined in `defaults/main.yaml`:

```yaml
it_tools_app_dir: /opt/it-tools
```

IT-Tools has no persistent state and no secrets, so no further configuration is required.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/it-tools.yaml
```

Service documentation: [`services/it-tools/README.md`](../../../services/it-tools/README.md).
