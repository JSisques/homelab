# Blog

## Overview

Personal blog — [github.com/JSisques/blog](https://github.com/JSisques/blog).
A static Astro site, built into a Docker image and pushed to `jsisques/blog`
on Docker Hub (and mirrored to `ghcr.io/jsisques/blog`) by that repo's
release-train CI. This LXC just pulls and runs the latest published image —
nothing here builds the site itself.

No persistent state, no secrets.

## Deployment

Blog runs on a dedicated LXC container.

Host:
blog

IP:
192.168.0.220

LAN URL (no reverse proxy):
http://192.168.0.220:8080

Public URL:
https://blog.jsisques.net, via the Cloudflare Tunnel → Traefik
(`services/cloudflared/config.yml`, `services/traefik/dynamic/routes.yml`,
both generated from `config/services.yaml`'s `traefik:` block).

## Infrastructure

Terraform:
terraform/proxmox/lxc.tf

Ansible:
ansible/roles/blog/

Monitoring:
Uptime Kuma, blackbox_exporter (no native `/metrics` — static site, no
backend)

Homepage:
Homepage

## Rolling out a new image build

The `latest` tag is what's pinned in `compose.yaml`, so a new push to
`blog`'s `main` branch is picked up on the next redeploy. Force one with:

```bash
make deploy-blog
```

or, directly on the host:

```bash
docker compose -f /opt/blog/compose.yaml pull
docker compose -f /opt/blog/compose.yaml up -d
```
