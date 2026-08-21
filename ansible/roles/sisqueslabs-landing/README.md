# Sisques Labs Landing Ansible Role

This role deploys [Sisques Labs Landing](https://github.com/sisques-labs/sisques-labs-landing) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`sisqueslabs_landing_app_dir`, default `/opt/sisqueslabs-landing`)
- Deploy the Compose file from `services/sisqueslabs-landing/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## Variables

Defined in `defaults/main.yaml`:

```yaml
sisqueslabs_landing_app_dir: /opt/sisqueslabs-landing
```

Sisques Labs Landing has no persistent state and no secrets, so no further configuration is required.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/sisqueslabs-landing.yaml
```

Service documentation: [`services/sisqueslabs-landing/README.md`](../../../services/sisqueslabs-landing/README.md).
