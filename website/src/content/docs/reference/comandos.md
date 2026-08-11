---
title: Comandos de referencia
description: Chuleta del Makefile y qué hace cada workflow de CI.
---

## Makefile

| Comando | Hace |
| --- | --- |
| `make help` | Lista todos los targets con su descripción. |
| `make generate` | Regenera Homepage, Prometheus, inventario y variables de Terraform desde `config/`. |
| `make plan` / `make apply` | `terraform plan` / `apply`, regenerando antes las variables. |
| `make deploy` | Todo: `apply` + los 6 roles de Ansible. |
| `make deploy-<servicio>` | Solo ese playbook. `make services` lista los nombres válidos. |
| `make ping` | Conectividad Ansible a todo el inventario. |
| `make validate` | Terraform + Ansible + YAML + shell + Compose, y comprueba que lo generado está al día. |
| `make status` | `terraform show` del estado actual. |
| `make destroy` | Destruye toda la infraestructura gestionada por Terraform. Con cuidado. |

## Workflows de GitHub Actions

| Workflow | Cuándo | Runner | Qué hace |
| --- | --- | --- | --- |
| `ci.yaml` | cada push/PR | GitHub | yamllint, shellcheck, `terraform validate`, ansible-lint, `docker compose config` en cada servicio. |
| `generate.yaml` | PR/push a `config/**` | GitHub | Corre los 4 generadores y falla si el resultado no coincide con lo commiteado. |
| `terraform.yaml` | PR/push a `terraform/**` | self-hosted | `terraform plan` de verdad — Proxmox solo escucha en la LAN, un runner de GitHub no llegaría. |
| `ansible.yaml` | PR/push a `ansible/**` | GitHub | ansible-lint + `--syntax-check` de cada playbook. |
| `deploy.yaml` | manual (`workflow_dispatch`) | self-hosted | El `make deploy` real: Terraform apply + Ansible `site.yaml`, con los secretos del repo. |

Ver la [guía de despliegue](/homelab/guides/desplegar/) para el paso a paso completo, y [cómo funciona](/homelab/guides/flujo-de-datos/) para el modelo mental.
