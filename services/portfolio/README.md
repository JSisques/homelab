# Portfolio

## Overview

Personal portfolio of Javier Plaza Sisqués. Static Astro site
(source: https://github.com/JSisques/portfolio), pre-built into a Docker
image by the repo's own release pipeline and served by
nginx-unprivileged, which listens internally on 8080 — published on the
host as port 80 (`ports: ["80:8080"]` in `compose.yaml`).

## Deployment

Portfolio runs on a dedicated LXC container.

Host:
portfolio

IP:
192.168.0.220

Public URL (Cloudflared -> Traefik -> this container):
https://portfolio.jsisques.net

## Updates

Portfolio is our own image (`ghcr.io/jsisques/portfolio`), re-tagged on every release rather than version-pinned. `compose.yaml` sets `pull_policy: always`, so every `make deploy-portfolio` re-pulls `:latest` and compares digests instead of reusing whatever was cached locally — a plain container/LXC restart does not re-pull, only an Ansible-driven `docker compose up` does. The Ansible role prunes unused images afterwards (`community.docker.docker_prune`) so the digest `:latest` pointed at before the deploy doesn't linger on disk. See `AGENTS.md#self-built-images-own-tools`.

## Infrastructure

Terraform:
terraform/proxmox/lxc.tf

Ansible:
ansible/roles/portfolio/

Monitoring:
Uptime Kuma, blackbox_exporter

Homepage:
Homepage
