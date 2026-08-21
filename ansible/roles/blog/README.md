# Blog Ansible Role

This role deploys [Blog](https://github.com/JSisques/blog) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`blog_app_dir`, default `/opt/blog`)
- Deploy the Compose file from `services/blog/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

## Variables

Defined in `defaults/main.yaml`:

```yaml
blog_app_dir: /opt/blog
```

Blog has no persistent state and no secrets, so no further configuration is required.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/blog.yaml
```

Service documentation: [`services/blog/README.md`](../../../services/blog/README.md).
