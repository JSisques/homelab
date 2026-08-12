# Portfolio Web Ansible Role

Deploys my personal portfolio (a static Astro site, built and published as a
Docker image by [JSisques/portfolio-web](https://github.com/JSisques/portfolio-web)'s
own CI) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs
Docker (via the `docker` role) and pulls/runs the published image — it never
builds the site itself, see `services/portfolio-web/compose.yaml`.

## Responsibilities

- Create the application directory (`portfolio_web_app_dir`, default `/opt/portfolio-web`)
- Deploy the Compose file from `services/portfolio-web/compose.yaml` (the
  single source of truth for the application configuration)
- Pull the latest image and start the stack with `community.docker.docker_compose_v2`

## Variables

Defined in `defaults/main.yaml`:

```yaml
portfolio_web_app_dir: /opt/portfolio-web
```

No persistent state and no secrets, so no further configuration is required.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/portfolio-web.yaml
```

Service documentation: [`services/portfolio-web/README.md`](../../../services/portfolio-web/README.md).
