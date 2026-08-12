---
title: Almacenamiento
description: Dónde vive cada dato del homelab — discos de Proxmox, volúmenes de Kubernetes, volúmenes Docker — y qué hay que respaldar de verdad.
---

El almacenamiento se reparte entre discos de Proxmox, volúmenes persistentes de Kubernetes y volúmenes Docker para los servicios independientes, más la configuración que vive en Git. Cada servicio con estado debe tener claro dónde están sus datos y cómo se respaldan.

## Clases de almacenamiento

### Almacenamiento de Proxmox

Proxmox proporciona el almacenamiento subyacente para los discos de VM y los volúmenes de LXC. Terraform declara el tamaño y la asociación del disco; la política de almacenamiento a nivel de host determina el backend físico.

### Almacenamiento persistente de Kubernetes

El pool de nodos de Kafka usa la `StorageClass` `local-path` de K3s:

- Tres réplicas de Kafka.
- Una `PersistentVolumeClaim` de 50 GiB por nodo.
- `deleteClaim: false`, así que borrar el recurso Kafka no borra intencionadamente sus claims.

El almacenamiento `local-path` está atado al disco local de cada nodo. No sustituye a un almacenamiento replicado ni a una copia fuera del host: perder el nodo puede dejar los datos inaccesibles aunque el claim siga existiendo.

### Volúmenes Docker

Cada servicio en `services/` que necesita persistencia declara su propio volumen Docker con nombre. Los más relevantes:

| Volumen | Servicio | Contiene |
| --- | --- | --- |
| `prometheus-data` | Prometheus | Series temporales de métricas — sin él no hay histórico |
| `grafana-data` | Grafana | Dashboards y configuración no provisionada por código |
| `uptime-kuma-data` | Uptime Kuma | Monitores, historial y ajustes — no hay config-as-code, es la única copia |
| `n8n-data` + `postgres-data` | n8n | Workflows y credenciales (Postgres, no SQLite) |
| `jellyfin-config` | Jellyfin | Configuración, usuarios e historial de reproducción |
| `cookidoo-mcp-data` | Cookidoo MCP | Cookie de sesión — trátese como una credencial |
| `wireguard-config` | WireGuard | Configuraciones de los peers generadas en el primer arranque |
| `adguard-work` / `adguard-conf` | AdGuard Home | Reglas de filtrado y estado del DNS |
| `tempo-data` | Tempo | Trazas — retención de 48h, **excluido a propósito** de los backups |

## Clasificación de datos

| Clase | Ejemplos | Prioridad de recuperación |
| --- | --- | --- |
| Configuración | Manifiestos de Git, ficheros Compose, Ansible y Terraform | Máxima |
| Métricas | Series temporales de Prometheus y dashboards de Grafana | Media |
| Datos de eventos | Topics de Kafka y estado de los consumidores | Alta |
| Secretos | Credenciales, claves, certificados | Máxima, cifrados |
| Caché | Descargas temporales y datos derivados | Baja |

## Reglas de almacenamiento

- Declarar el almacenamiento persistente en el manifiesto o fichero Compose propietario del servicio.
- No guardar credenciales ni tokens en Git.
- Mantener explícitos la capacidad, la retención y el comportamiento de borrado.
- Monitorizar espacio libre, uso de inodos, estado de los claims y salud a nivel de aplicación.
- Probar las restauraciones, no solo los backups.
- Tratar el almacenamiento local de cada nodo como un dominio de fallo.

## Planificación de capacidad

Antes de aumentar réplicas o retención, comprobar:

1. Almacenamiento de Proxmox disponible en el nodo afectado.
2. Espacio libre local de los nodos de Kubernetes para volúmenes `local-path`.
3. Sobrecarga de replicación y retención.
4. Capacidad del destino de backup.
5. Tiempo de restauración y ancho de banda de red.

Los cambios en la retención y el número de particiones de Kafka deben tomarse con cuidado porque afectan al crecimiento del disco y al tiempo de recuperación.

## Qué cubren los backups

- Este repositorio Git y su historial.
- El estado de Terraform y su backend remoto, si se usa.
- Backups de VM y LXC de Proxmox — vía Proxmox Backup Server (`ansible/roles/pbs/`), con el datastore en el NAS por NFS, no en el disco del propio host Proxmox.
- El vault de Obsidian (`ansible/roles/obsidian/`) — montado desde una exportación NFS del NAS (`192.168.0.111:/export/obsidian`) en `/mnt/nas/obsidian`, montado dentro del contenedor. Es la única copia de las notas Markdown; el volumen Docker `obsidian-config` de al lado solo guarda estado de la app, regenerable.
- El volumen `jellyfin-config` de Jellyfin — configuración, usuarios e historial de reproducción. Los propios ficheros multimedia, montados en solo lectura desde exportaciones NFS del NAS (`192.168.0.111:/export/Multimedia/{peliculas,series}`) en `/mnt/nas/multimedia`, **no** entran en el alcance de backup de este repositorio: son contenido masivo, no producido por este homelab, y se espera que sean reobtenibles o se respalden aparte a nivel de NAS en vez de vía Proxmox/volúmenes Docker.
- Definiciones de recursos de Kubernetes y datos de los volúmenes persistentes.
- Los volúmenes Docker de Prometheus y Loki.
- El aprovisionamiento y los dashboards de Grafana.
- El volumen `cookidoo-mcp-data` de `cookidoo-mcp` (`ansible/roles/cookidoo-mcp/`) — guarda el fichero de cookie de sesión persistida (`COOKIDOO_COOKIE_FILE`); trátese como una credencial.
- Material de secretos, en un formato de backup cifrado.

El volumen `tempo-data` de Tempo (`services/tempo/`) se **excluye a propósito**: las trazas tienen retención corta (48h) y son datos operativos, no un sistema de registro.

Los backups de configuración no son suficientes cuando un servicio guarda estado importante fuera de Git.

Ver también: [recuperación ante desastres](/homelab/arquitectura/recuperacion-ante-desastres/).
