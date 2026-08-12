---
title: Multimedia y descargas
description: Jellyfin y la pila de descargas (qBittorrent, Prowlarr, Sonarr, Radarr, pyLoad, MeTube) — todo alimentado desde el NAS.
---

Jellyfin y la pila de descargas comparten patrón: guardan poco estado propio y dependen del NAS por NFS para el contenido real. Sonarr y Radarr son el puente entre ambos mundos — mueven lo descargado directamente a las carpetas que Jellyfin sirve.

```text
qBittorrent ─┐
Prowlarr ────┼──▶ Sonarr / Radarr ──▶ NAS (NFS) ──▶ Jellyfin
pyLoad ──────┤        │
MeTube ──────┘        └── organiza series/películas
```

## Jellyfin

<span class="slh-tier slh-tier--internal">interna</span> · `jellyfin.home.arpa` · también `jellyfin.jsisques.net` (Cloudflare Tunnel)

Servidor multimedia que sirve las bibliotecas de vídeo/audio almacenadas enteramente en el NAS.

- Transcodificación por software/CPU por defecto — sin passthrough de GPU/iGPU configurado; revisar dimensionado o añadir transcodificación por hardware si empieza a haber varias transcodificaciones simultáneas.
- Los puntos de montaje multimedia (`/media/peliculas`, `/media/series`) son NFS de solo lectura; solo el volumen `jellyfin-config` necesita backup (configuración del servidor, usuarios, historial de reproducción) — la caché es descartable.
- Requiere que existan antes las exportaciones NFS `192.168.0.111:/export/Multimedia/{peliculas,series}` en el NAS.
- Sin secretos — la cuenta de administrador se crea en el asistente de primer arranque.
- Alcanzable tanto en LAN (`https://jellyfin.home.arpa`) como en remoto/personal (`https://jellyfin.jsisques.net`) vía el mismo Cloudflare Tunnel, ambos apuntando al puerto interno `8096`.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/jellyfin).

## Pila de descargas

<span class="slh-tier slh-tier--internal">interna, todo `*.home.arpa`</span>

qBittorrent, Prowlarr, Sonarr, Radarr, pyLoad y MeTube corren como una sola definición de Compose de siete contenedores (incluyendo gluetun) en una LXC dedicada. Pegar un enlace torrent/magnet, un enlace HTTP/FTP directo o un enlace de un sitio de vídeo y termina en el NAS; Sonarr/Radarr además organizan las descargas terminadas de TV/películas directamente en la biblioteca de Jellyfin. Todo queda en la LAN (`*.home.arpa`), nunca se enruta por el Cloudflare Tunnel.

- **Requisito manual en Proxmox, no expresado en Terraform**: la LXC sin privilegios `downloads` necesita que el host Proxmox exponga `/dev/net/tun` para la interfaz WireGuard de gluetun. Si gluetun no levanta su interfaz, es el primer sitio donde mirar.
- Necesita tres secretos que nunca se commitean: `DOWNLOADS_VPN_SERVICE_PROVIDER`, `DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY`, `DOWNLOADS_VPN_WIREGUARD_ADDRESSES`, pasados como variables de entorno a `make deploy-downloads`.
- Requiere tres exportaciones NFS del NAS: `/export/Downloads` (nueva, lectura/escritura) y las mismas `/export/Multimedia/{peliculas,series}` que usa Jellyfin, con permisos de escritura añadidos para la IP de esta LXC.
- Dimensionado: 4 vCPU / 4 GB / 24 GB.
- Ninguna de las seis apps expone `/metrics` nativo — todas se sondean con blackbox_exporter y se dan de alta en Uptime Kuma como monitores HTTP.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/downloads).

### qBittorrent

`qbittorrent.home.arpa` — cliente de torrents. Solo su tráfico (no la interfaz web) pasa por la VPN: comparte el espacio de red de gluetun (`network_mode: service:gluetun`), así que no tiene IP/puertos propios y otros servicios deben alcanzarlo en `http://gluetun:8080`. linuxserver.io genera y registra una contraseña real en el primer arranque (no es `admin`/`adminadmin` por defecto real) — cambiarla de inmediato. Ruta de guardado: `/downloads`.

### Prowlarr

`prowlarr.home.arpa` — gestor de indexadores que alimenta a Sonarr y Radarr. Se conecta a qBittorrent/Sonarr/Radarr a mano, después del despliegue, desde *Settings → Apps*.

### Sonarr / Radarr

`sonarr.home.arpa` / `radarr.home.arpa` — vigilan series y películas deseadas, se las envían a qBittorrent y mueven los ficheros terminados a las mismas exportaciones NFS que lee Jellyfin. La importación es copiar-y-borrar (no *hardlink* instantáneo) porque las carpetas de descarga y de biblioteca están en exportaciones NFS distintas — una ineficiencia conocida, solucionable más adelante consolidando exportaciones.

### pyLoad

`pyload.home.arpa` — descargador genérico de enlaces HTTP/FTP directos hacia el NAS, sin necesidad de configuración adicional.

### MeTube

`metube.home.arpa` — descargador de YouTube y sitios compatibles con `yt-dlp` hacia el NAS, sin necesidad de configuración adicional.
