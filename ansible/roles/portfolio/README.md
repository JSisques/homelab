# Portfolio Ansible Role

This role deploys [Portfolio](https://github.com/JSisques/portfolio) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`portfolio_app_dir`, default `/opt/portfolio`)
- Deploy the Compose file from `services/portfolio/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## Variables

Defined in `defaults/main.yaml`:

```yaml
portfolio_app_dir: /opt/portfolio
```

Portfolio is a static site with no persistent state and no secrets, so no further configuration is required.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/portfolio.yaml
```

Service documentation: [`services/portfolio/README.md`](../../../services/portfolio/README.md).
