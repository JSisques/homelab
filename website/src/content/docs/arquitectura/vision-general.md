---
title: Visión general
description: Las capas de infraestructura del homelab, de Proxmox a Kubernetes, y por qué cada una hace solo una cosa.
---

Este documento describe la arquitectura objetivo del homelab y el papel de cada capa. No es una foto de lo que está corriendo hoy — es el diseño hacia el que apunta el repositorio; el [estado actual](/homelab/#estado-del-proyecto) puede ir por detrás.

## Principios de diseño

- Git es la fuente de verdad.
- La infraestructura y la configuración son declarativas y reproducibles.
- Los cambios se revisan antes de desplegarse.
- Los workloads de Kubernetes se reconcilian a través de Argo CD.
- Los servicios con estado usan almacenamiento persistente y un plan de recuperación explícito.
- La monitorización y las rutas de acceso son responsabilidad de la plataforma, no un detalle de cada aplicación.

## Panorama general

```text
                                   GitHub
                                      │
                             GitHub Actions / Git
                                      │
                  ┌───────────────────┴───────────────────┐
                  │                                       │
              Terraform                                Ansible
                  │                                       │
                  ▼                                       ▼
               Proxmox                         Sistemas operativos y servicios
          ┌───────┴────────┐
          │                │
         VMs              LXC / Raspberry Pi
          │
         K3s
          │
       Argo CD
          │
   Workloads de Kubernetes
```

## Capas de infraestructura

### Proxmox

Proxmox es la capa de virtualización. Terraform declara máquinas virtuales, contenedores LXC, discos, CPU, memoria, redes y metadatos de cloud-init — ver [`terraform/proxmox/`](https://github.com/JSisques/homelab/tree/main/terraform/proxmox).

### Configuración de hosts

Ansible configura los sistemas operativos y hosts ya provisionados: usuarios y SSH, paquetes, Docker, reglas de firewall, exporters y configuración de cada servicio. El inventario y el catálogo de servicios previstos viven en `config/hosts.yaml` y `config/services.yaml` — ver [modelo de configuración](/homelab/configuracion/modelo/).

### Kubernetes

K3s corre como servidor de un único nodo en la VM `k3s-server` (`ansible/roles/k3s/`) y puede ampliarse con VMs worker y/o los nodos Raspberry Pi ya etiquetados `role: [k3s, worker]` en `config/hosts.yaml` — unirlos como agentes todavía no está implementado. Argo CD vigila el repositorio y reconcilia los recursos de Kubernetes desde Git; está instalado y vacío hasta que se aplican recursos `Application`.

El árbol de Kubernetes se divide en:

- `kubernetes/infrastructure/` — componentes de plataforma compartidos, como Kafka y sus operadores.
- `kubernetes/argocd/` — aplicaciones de Argo CD y puntos de entrada de GitOps.
- `kubernetes/applications/` — manifiestos de aplicaciones concretas (Gardenia, Sisques Labs Landing, Days Off) a medida que la plataforma crece.

### Servicios fuera de Kubernetes

La mayoría de los servicios corren directamente en contenedores LXC dedicados (o, en el caso de Proxmox Backup Server, en una VM) en lugar de en Kubernetes: Prometheus, Grafana, Loki, Alertmanager, Tempo y el OTel Collector (todos en la LXC compartida `monitoring`), Homepage, IT-Tools, n8n, `cookidoo-mcp`, Uptime Kuma, `cloudflared`, AdGuard Home, Traefik, WireGuard, Obsidian, Jellyfin, la pila de descargas y el portfolio. Cada uno tiene un directorio equivalente bajo `services/` (la fuente de verdad del `compose.yaml`) y un rol de Ansible bajo `ansible/roles/` que lo despliega sin modificarlo. Proxmox Backup Server y Promtail son la excepción — paquetes nativos instalados por Ansible, sin Docker de por medio.

Las aplicaciones que emiten datos OpenTelemetry (hoy, `cookidoo-mcp`) envían trazas/métricas/logs OTLP al OTel Collector de la LXC `monitoring` (`192.168.0.20:4317`/`4318`), que los reparte: las métricas quedan expuestas en un endpoint que Prometheus scrapea (pull, no `remote_write`, así que la configuración de la instancia de Prometheus compartida no cambia), los logs van al endpoint OTLP nativo de Loki, y las trazas a Tempo. Esto mantiene intacto el modelo de Prometheus basado en scraping mientras da a los servicios nativos de OTel un sitio al que enviar datos.

## Flujo de datos y control

```text
Cambio del desarrollador
      │
      ▼
Repositorio Git
      │
      ├──▶ Terraform ──▶ Recursos de Proxmox
      ├──▶ Ansible ────▶ Configuración de hosts
      ├──▶ Argo CD ───▶ Recursos de Kubernetes
      └──▶ Compose ────▶ Servicios independientes
```

Para el detalle de cómo `config/hosts.yaml` y `config/services.yaml` alimentan todo lo demás sin duplicación, ver [cómo funciona (flujo de datos)](/homelab/guides/flujo-de-datos/).

## Límites operativos

- Terraform gestiona el ciclo de vida de los recursos, no la configuración de las aplicaciones.
- Ansible configura hosts y servicios independientes; no sustituye a Argo CD para workloads de Kubernetes.
- Los workloads con estado de Kubernetes deben declarar su almacenamiento explícitamente.
- Los secretos se inyectan a través del mecanismo de gestión de secretos elegido y nunca se commitean en plano.
- El acceso público termina en el Cloudflare Tunnel (`services/cloudflared/`, desplegado en su propia LXC). Es la única vía de entrada para los servicios `tier: public` (`sisqueslabs.com`) y `tier: personal` (`jsisques.net`); los servicios `tier: internal` (`*.home.arpa`) nunca deben tener entrada en su configuración de ingress y solo deben ser alcanzables desde la LAN/VPN.

## Fuente de verdad

Cuando el sistema en ejecución y Git no coinciden, primero hay que determinar qué capa es dueña del recurso. La corrección se hace en esa capa, y luego se deja que el proceso de reconciliación o configuración normal la aplique.

Puntos de entrada útiles:

- [Repositorio en GitHub](https://github.com/JSisques/homelab)
- [Argo CD](https://github.com/JSisques/homelab/tree/main/kubernetes/argocd)
- [Modelo de configuración](/homelab/configuracion/modelo/)
