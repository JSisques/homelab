# Sisques Labs Landing

## Overview

Public landing page for Sisques Labs —
[github.com/sisques-labs/sisques-labs-landing](https://github.com/sisques-labs/sisques-labs-landing).
A static Astro site, built into a Docker image and pushed to
`sisqueslabs/sisques-labs-landing` on Docker Hub (and mirrored to
`ghcr.io/sisques-labs/sisques-labs-landing`) by that repo's release-train
CI. This LXC just pulls and runs the latest published image — nothing
here builds the site itself.

No persistent state, no secrets.

## Deployment

Sisques Labs Landing runs on a dedicated LXC container.

Host:
sisqueslabs-landing

IP:
192.168.0.221

LAN URL (no reverse proxy):
http://192.168.0.221:8080

Public URL:
https://landing.sisqueslabs.com, via the Cloudflare Tunnel → Traefik
(`services/cloudflared/config.yml`, `services/traefik/dynamic/routes.yml`,
both generated from `config/services.yaml`'s `traefik:` block).

## Infrastructure

Terraform:
terraform/proxmox/lxc.tf

Ansible:
ansible/roles/sisqueslabs-landing/

Monitoring:
Uptime Kuma, blackbox_exporter (no native `/metrics` — static site, no
backend)

Homepage:
Homepage

## Rolling out a new image build

The `latest` tag is what's pinned in `compose.yaml`, so a new push to
`sisques-labs-landing`'s `main` branch is picked up on the next redeploy.
Force one with:

```bash
make deploy-sisqueslabs-landing
```

or, directly on the host:

```bash
docker compose -f /opt/sisqueslabs-landing/compose.yaml pull
docker compose -f /opt/sisqueslabs-landing/compose.yaml up -d
```
