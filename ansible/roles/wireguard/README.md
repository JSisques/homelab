# WireGuard Ansible Role

Deploys the wg-easy VPN gateway and dashboard on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

## Responsibilities

- Create the application directory (`wireguard_app_dir`, default `/opt/wireguard`)
- Deploy `services/wireguard/compose.yaml` (the single source of truth for the application configuration)
- Start the stack with `community.docker.docker_compose_v2`

wg-easy v15 configures everything else (admin account, WireGuard host/endpoint, client DNS, peers) through its own web onboarding wizard rather than environment variables — there's no per-host templating left for this role to do. See `services/wireguard/README.md`.

This role does **not** handle router port-forwarding or Dynamic DNS — those are manual, hardware-dependent steps. See `services/wireguard/README.md` before the first deploy.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/wireguard.yaml
```
