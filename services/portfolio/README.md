# Portfolio

## Overview

Personal portfolio of Javier Plaza Sisqués. Static Astro site
(source: https://github.com/JSisques/portfolio), pre-built into a Docker
image by the repo's own release pipeline and served by
nginx-unprivileged on port 8080.

## Deployment

Portfolio runs on a dedicated LXC container.

Host:
portfolio

IP:
192.168.0.220

Public URL (Cloudflared -> Traefik -> this container):
https://portfolio.jsisques.net

## Infrastructure

Terraform:
terraform/proxmox/lxc.tf

Ansible:
ansible/roles/portfolio/

Monitoring:
Uptime Kuma, blackbox_exporter

Homepage:
Homepage
