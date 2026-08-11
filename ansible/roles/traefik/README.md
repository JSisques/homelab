# Traefik Ansible Role

Deploys [Traefik](https://traefik.io/) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`traefik_app_dir`, default `/opt/traefik`)
- Deploy `services/traefik/{compose.yaml,traefik.yml,dynamic/}` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

Traefik itself needs no secrets. Getting `*.home.arpa` to actually resolve to it is a separate, manual, one-time step in AdGuard Home — see `services/traefik/README.md`.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/traefik.yaml
```
