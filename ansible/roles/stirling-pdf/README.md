# Stirling PDF Ansible Role

Prepares an LXC container and deploys Stirling PDF (see `services/stirling-pdf/README.md`) using Docker Compose.

## Responsibilities

- Create the application directory and deploy `services/stirling-pdf/compose.yaml` to it.
- Start the stack with Docker Compose.

Terraform is responsible for creating the LXC container. Unlike most Docker services in this repo, there's no NAS mount to set up first — Stirling PDF is stateless per request and keeps only its own config/database in a local Docker volume.

## Directory Structure

```text
ansible/roles/stirling-pdf/
├── README.md
├── defaults/
│   └── main.yaml
├── meta/
│   └── main.yml
└── tasks/
    └── main.yaml
```

## Variables

```yaml
stirling_pdf_app_dir: /opt/stirling-pdf
```

No secrets — Stirling PDF's built-in login is disabled in `compose.yaml` (`SECURITY_ENABLELOGIN=false`), matching every other `tier: internal` service in this repo, so there's nothing to inject via Vault.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/stirling-pdf.yaml
```

or, from the repo root:

```bash
make deploy-stirling-pdf
```

## Related

- `terraform/proxmox/lxc.tf` — creates the `stirling-pdf` LXC.
- `services/stirling-pdf/` — Compose definition and application-level documentation.
- `ansible/roles/it-tools/` — closest model for this role: single container, no secrets, no NAS mount.
