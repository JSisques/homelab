# Days Off

## Overview

Vacation bridge calculator —
[github.com/sisques-labs/daysoff](https://github.com/sisques-labs/daysoff).
A static Astro site, built into a Docker image and pushed to
`sisqueslabs/daysoff` on Docker Hub (and mirrored to
`ghcr.io/sisques-labs/daysoff`) by that repo's release-train CI. This LXC
just pulls and runs the latest published image — nothing here builds the
site itself.

No persistent state, no secrets.

## Deployment

Days Off runs on a dedicated LXC container.

Host:
daysoff

IP:
192.168.0.222

LAN URL (no reverse proxy):
http://192.168.0.222:8080

Public URL:
https://daysoff.sisqueslabs.com, via the Cloudflare Tunnel → Traefik
(`services/cloudflared/config.yml`, `services/traefik/dynamic/routes.yml`,
both generated from `config/services.yaml`'s `traefik:` block).

## Infrastructure

Terraform:
terraform/proxmox/lxc.tf

Ansible:
ansible/roles/daysoff/

Monitoring:
Uptime Kuma, blackbox_exporter (no native `/metrics` — static site, no
backend)

Homepage:
Homepage

## Rolling out a new image build

The `latest` tag is what's pinned in `compose.yaml`, so a new push to
`daysoff`'s `main` branch is picked up on the next redeploy. Force one
with:

```bash
make deploy-daysoff
```

or, directly on the host:

```bash
docker compose -f /opt/daysoff/compose.yaml pull
docker compose -f /opt/daysoff/compose.yaml up -d
```
