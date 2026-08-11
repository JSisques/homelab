# AdGuard Home Ansible Role

Deploys [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`adguard_home_app_dir`, default `/opt/adguard-home`)
- Deploy `services/adguard-home/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

The first-run setup wizard (admin credentials, upstream DNS) is done once through the web UI, not by this role — see `services/adguard-home/README.md`.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/adguard-home.yaml
```
