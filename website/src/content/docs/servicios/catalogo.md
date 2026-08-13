---
title: Catálogo de servicios
description: Todos los servicios del homelab, su categoría, su nivel de acceso y su URL — generado a partir de config/services.yaml.
---

Esta tabla refleja `config/services.yaml`, el catálogo único del que se generan Homepage, el scraping de Prometheus y (parcialmente) Uptime Kuma — ver [modelo de configuración](/homelab/configuracion/modelo/). Si un servicio cambia de nivel de acceso, de URL o desaparece, el cambio se hace ahí, no aquí.

Las páginas de esta sección agrupan los mismos servicios por función, con el detalle operativo de cada uno: [monitorización](/homelab/servicios/monitorizacion/), [redes y acceso](/homelab/servicios/redes/), [multimedia y descargas](/homelab/servicios/multimedia-descargas/), [productividad y automatización](/homelab/servicios/productividad-automatizacion/), [aplicaciones](/homelab/servicios/aplicaciones/) e [infraestructura](/homelab/servicios/infraestructura/).

:::note[Niveles de acceso]
`interna` → `*.home.arpa`, solo LAN/VPN · `personal` → `*.jsisques.net`, vía Cloudflare Tunnel · `pública` → `*.sisqueslabs.com`, vía Cloudflare Tunnel. Detalle completo en [redes y acceso](/homelab/servicios/redes/).
:::

## Monitorización

| Servicio | Nivel | URL | Descripción |
| --- | --- | --- | --- |
| Prometheus | interna | `prometheus.home.arpa` | Recolección y almacenamiento de métricas |
| Grafana | interna | `grafana.home.arpa` | Dashboards de monitorización |
| Loki | interna | *(solo vía Grafana)* | Agregación de logs |
| Alertmanager | interna | *(sin URL aún)* | Enrutado de alertas de Prometheus |
| Tempo | interna | *(solo vía Grafana)* | Almacenamiento de trazas |
| OTel Collector | interna | *(sin UI)* | Ingesta OTLP (trazas/métricas/logs) |
| Uptime Kuma | interna | `uptime.home.arpa` | Monitorización de disponibilidad |

## Redes y acceso

| Servicio | Nivel | URL | Descripción |
| --- | --- | --- | --- |
| Traefik | interna | `traefik.home.arpa` | Proxy inverso interno para `*.home.arpa` |
| Cloudflared | interna | *(sin UI)* | Túnel de Cloudflare hacia `sisqueslabs.com`/`jsisques.net` |
| AdGuard Home (Primary) | interna | `adguard1.home.arpa` | DNS primario y bloqueo de anuncios de toda la red |
| AdGuard Home (Secondary) | interna | `adguard2.home.arpa` | DNS secundario, sincronizado desde el primario |
| WireGuard | interna | *(sin URL, es VPN)* | Puerta de enlace VPN para acceso remoto interno |

`adguard-home-sync` (ver [redes y acceso](/homelab/servicios/redes/#sincronizaci%C3%B3n-adguard-home-sync)) no tiene fila propia aquí — no declara `traefik`/`homepage`/`monitoring` en `config/services.yaml`, solo existe como rol de Ansible sobre la LXC de `adguard-home-2`.

## Multimedia y descargas

| Servicio | Nivel | URL | Descripción |
| --- | --- | --- | --- |
| Jellyfin | interna | `jellyfin.home.arpa` · también `jellyfin.jsisques.net` | Servidor de streaming multimedia |
| qBittorrent | interna | `qbittorrent.home.arpa` | Cliente de torrents (tras VPN) |
| Prowlarr | interna | `prowlarr.home.arpa` | Gestor de indexadores para Sonarr/Radarr |
| Sonarr | interna | `sonarr.home.arpa` | Automatización de series |
| Radarr | interna | `radarr.home.arpa` | Automatización de películas |
| pyLoad | interna | `pyload.home.arpa` | Descargador de enlaces HTTP/FTP directos |
| MeTube | interna | `metube.home.arpa` | Descargador de vídeo/YouTube (yt-dlp) |

## Productividad y automatización

| Servicio | Nivel | URL | Descripción |
| --- | --- | --- | --- |
| n8n | interna | `n8n.home.arpa` | Automatización de flujos de trabajo |
| Cookidoo MCP | interna | `cookidoo-mcp.home.arpa` | Servidor MCP que expone una cuenta Cookidoo a agentes de IA |
| Obsidian | interna | `obsidian.home.arpa` | Vault "second brain" expuesto por MCP a agentes de IA |

## Aplicaciones

| Servicio | Nivel | URL | Descripción |
| --- | --- | --- | --- |
| Portfolio | interna | `portfolio-web.home.arpa` · también `portfolio.jsisques.net` | Portfolio personal de desarrollador |
| Gardenia* | pública | `gardenia.sisqueslabs.com` | Plataforma de gestión de huertos |
| Sisques Labs Landing* | pública | `landing.sisqueslabs.com` | Landing pública de Sisques Labs |
| Days Off* | pública | `daysoff.sisqueslabs.com` | Calculadora de puentes/vacaciones |
| Blog* | personal | `blog.jsisques.net` | Blog personal |

<small>* Gardenia, Sisques Labs Landing, Days Off y Blog viven en repositorios propios; aquí solo se documenta cómo se despliegan y exponen, no su código.</small>

## Infraestructura y utilidades

| Servicio | Nivel | URL | Descripción |
| --- | --- | --- | --- |
| Proxmox | interna | `proxmox.home.arpa` | Plataforma de virtualización |
| Kafka* | interna | `kafka.home.arpa` | Plataforma de streaming de eventos |
| Homepage | interna | `home.home.arpa` | Dashboard central del homelab |
| Proxmox Backup Server | interna | *(solo entrada de catálogo)* | Backups de VM/LXC de Proxmox |
| K3s API Server | interna | *(solo entrada de catálogo)* | Plano de control de Kubernetes |
| IT-Tools | interna | `it-tools.home.arpa` | Colección de herramientas para desarrolladores |

<small>* Kafka está definido pero deliberadamente no desplegado todavía — ver [aplicaciones](/homelab/servicios/aplicaciones/#kafka).</small>
