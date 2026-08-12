---
title: Infraestructura y utilidades
description: Proxmox, Homepage, Proxmox Backup Server, K3s/Argo CD e IT-Tools — los cimientos sobre los que corre todo lo demás.
---

## Proxmox

<span class="slh-tier slh-tier--internal">interna</span> · `proxmox.home.arpa`

Plataforma de virtualización. Es la base sobre la que Terraform provisiona cada LXC y VM del homelab — ver [visión general de arquitectura](/homelab/arquitectura/vision-general/#proxmox). Se monitoriza vía `prometheus-pve-exporter`.

## Homepage

<span class="slh-tier slh-tier--internal">interna</span> · `home.home.arpa`

Dashboard central que lista y enlaza los servicios del homelab.

- Su configuración (`services.yaml` interno de Homepage) se **genera** desde `config/services.yaml` vía `generate-homepage.sh` — fuente única, no se edita a mano.
- No es una herramienta de monitorización en sí misma: depende de Uptime Kuma y Prometheus para el estado real de salud y las métricas.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/homepage).

## Proxmox Backup Server

<span class="slh-tier slh-tier--internal">interna</span> · sin URL en el catálogo, solo entrada para blackbox_exporter

Servidor de backups para los guests de Proxmox VE. No tiene directorio en `services/` — es un [rol de Ansible](https://github.com/JSisques/homelab/tree/main/ansible/roles/pbs) que instala un paquete nativo, sin Docker de por medio.

- Corre en una VM dedicada, con el datastore respaldado por una exportación NFS del NAS (no en disco local) — perder la VM solo exige una instalación limpia apuntando a la misma exportación NFS para recuperar el historial de backups.
- Pasos manuales que **no** están automatizados: crear un token de API en PBS, añadir PBS como backend de almacenamiento en la UI de Proxmox VE, y crear el propio job de backup (guests, calendario, retención) desde la web (`https://<ip-pbs>:8007`).
- Corre en el mismo nodo físico que el host Proxmox VE al que respalda (contra la recomendación de buenas prácticas de Proxmox) — una concesión aceptada en este homelab.

## K3s y Argo CD

<span class="slh-tier slh-tier--internal">interna</span> · el apiserver aparece en el catálogo solo para blackbox_exporter

Cluster de Kubernetes de un solo nodo (plano de control y a la vez *schedulable*), con Argo CD ya instalado encima. Sin directorio en `services/` — es un [rol de Ansible](https://github.com/JSisques/homelab/tree/main/ansible/roles/k3s).

- Instalación nativa vía el script oficial de K3s (trae su propio `containerd`), sin Docker.
- Sin nodos worker todavía — los dos Raspberry Pi están etiquetados `role: [k3s, worker]` en `config/hosts.yaml` para ese futuro, pero unirlos como agentes es un paso aparte, aún no construido. Kafka está deliberadamente sin desplegar por esta misma razón — ver [aplicaciones](/homelab/servicios/aplicaciones/#kafka).
- Argo CD queda vacío tras la instalación — no aplica ningún recurso `Application` por sí solo; se aplican a mano (`kubectl apply -f kubernetes/argocd/...`). La contraseña de administrador inicial se obtiene del secreto `argocd-initial-admin-secret` y debería rotarse/borrarse tras el primer login.
- El kubeconfig se descarga a la máquina de control de Ansible en `~/.kube/homelab-k3s.yaml` — nunca se commitea.

## IT-Tools

<span class="slh-tier slh-tier--internal">interna</span> · `it-tools.home.arpa`

Colección de herramientas para desarrolladores en una sola app web estática — conversores, generadores, formateadores. Sin persistencia ni secretos; es el servicio más sencillo del catálogo. Monitorizado vía Uptime Kuma y listado en Homepage.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/it-tools).
