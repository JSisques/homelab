# Homepage Ansible Role

Deploys [Homepage](https://gethomepage.dev/) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`homepage_app_dir`, default `/opt/homepage`)
- Deploy `services/homepage/compose.yaml` and `services/homepage/config/` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

`services/homepage/config/services.yaml` is generated from `config/services.yaml` by `scripts/generation/generate-homepage.sh` and should not be edited by hand.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/homepage.yaml
```

Service documentation: [`services/homepage/README.md`](../../../services/homepage/README.md).
