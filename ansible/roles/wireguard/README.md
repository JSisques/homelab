# WireGuard Ansible Role

Deploys the WireGuard VPN gateway on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`wireguard_app_dir`, default `/opt/wireguard`)
- Render `.env` (`templates/env.j2`) with `ALLOWEDIPS`/`PEERDNS`, derived from the Ansible inventory's `lan_cidr` var and AdGuard Home's resolved address — both ultimately sourced from `config/hosts.yaml`'s `network:` block, see `services/wireguard/README.md`
- Deploy `services/wireguard/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

This role does **not** handle router port-forwarding or Dynamic DNS — those are manual, hardware-dependent steps. See `services/wireguard/README.md` before the first deploy.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/wireguard.yaml
```
