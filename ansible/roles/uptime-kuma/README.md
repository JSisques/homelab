# Uptime Kuma Ansible Role

Deploys [Uptime Kuma](https://github.com/louislam/uptime-kuma) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`uptime_kuma_app_dir`, default `/opt/uptime-kuma`)
- Deploy `services/uptime-kuma/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

Monitors themselves are configured through the Uptime Kuma web UI/API, not through Ansible — see `services/uptime-kuma/README.md`.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/uptime-kuma.yaml
```

Service documentation: [`services/uptime-kuma/README.md`](../../../services/uptime-kuma/README.md).
