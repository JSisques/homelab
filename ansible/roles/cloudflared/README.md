# Cloudflared Ansible Role

Deploys `cloudflared` on a dedicated LXC container using Docker Compose, running the Cloudflare Tunnel that exposes `sisqueslabs.com` (public) and `jsisques.net` (personal) to the internet.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the tunnel.

## Responsibilities

- Deploy `services/cloudflared/compose.yaml` and `services/cloudflared/config.yml` (ingress rules — the single source of truth for routing)
- Write the tunnel credentials to `{{ cloudflared_app_dir }}/credentials.json` from the `cloudflared_credentials_json` variable
- Start the tunnel with `community.docker.docker_compose_v2`

## Variables

```yaml
cloudflared_app_dir: /opt/cloudflared
cloudflared_credentials_json: "" # required, see below
```

## Secrets

`cloudflared_credentials_json` must hold the **full contents** of the credentials JSON file produced by `cloudflared tunnel create` (see `services/cloudflared/README.md` for the one-time setup). The role refuses to run if it is empty.

Never commit a real value. Provide it through:

1. An Ansible Vault-encrypted `group_vars`/`host_vars` file, or
2. A CI secret passed as `--extra-vars` when running the playbook, for example:

```bash
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/cloudflared.yaml \
  --extra-vars "cloudflared_credentials_json=${CLOUDFLARED_CREDS_JSON}"
```

The task that writes the file uses `no_log: true` so the secret never appears in Ansible output.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/cloudflared.yaml \
  --extra-vars "cloudflared_credentials_json=${CLOUDFLARED_CREDS_JSON}"
```

Service documentation: [`services/cloudflared/README.md`](../../../services/cloudflared/README.md).
