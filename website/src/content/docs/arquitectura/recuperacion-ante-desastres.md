---
title: Recuperación ante desastres
description: Cómo reconstruir el homelab tras un fallo de host, almacenamiento, cluster o configuración.
---

Este runbook describe cómo reconstruir el homelab tras un fallo de host, almacenamiento, cluster o configuración. Es un punto de partida — los objetivos de recuperación y las ubicaciones de backup deben registrarse en cuanto el despliegue en producción esté cerrado.

:::caution[RPO/RTO sin medir]
Todos los valores de la tabla siguen en `TBD`. Proxmox Backup Server da el *mecanismo* de backup, no cifras probadas. No escribas nada que no sea `TBD` en esa columna hasta haber ejecutado una restauración real.
:::

## Objetivos de recuperación

Documentar estos valores para cada servicio crítico:

| Servicio | RPO | RTO | Fuente de recuperación |
| --- | --- | --- | --- |
| Infraestructura Proxmox | TBD | TBD | Proxmox Backup Server, datastore en el NAS por NFS |
| K3s y Argo CD | TBD | TBD | Git y backup del cluster |
| Kafka | TBD | TBD | Backup de volumen persistente / replicación de topics |
| Prometheus | TBD | TBD | Backup de `prometheus-data` |
| Grafana | TBD | TBD | Ficheros de aprovisionamiento y backup de la base de datos |
| Loki | TBD | TBD | Backup de `loki-data` — logs, no es fuente de verdad de nada |

RPO es la pérdida de datos máxima aceptable. RTO es el tiempo máximo aceptable de restauración.

## Orden de recuperación

```text
Acceso a backups y credenciales
             │
             ▼
Red, DNS y Proxmox
             │
             ▼
VMs / LXC y sistemas operativos base
             │
             ▼
Plano de control y nodos de K3s
             │
             ▼
Argo CD y operadores de infraestructura
             │
             ▼
Servicios con estado y datos persistentes
             │
             ▼
Aplicaciones, monitorización y acceso externo
```

## Procedimiento de reconstrucción

1. Confirmar que el repositorio Git, el estado de Terraform, los secretos cifrados y los backups son accesibles.
2. Recrear la red de Proxmox y el almacenamiento necesario a partir de las definiciones de infraestructura.
3. Restaurar o aprovisionar las VMs y LXC, y aplicar la configuración base de Ansible.
4. Instalar K3s y verificar que los nodos están listos y el cluster conecta.
5. Instalar Argo CD y conectarlo a este repositorio.
6. Desplegar Strimzi y los recursos de Kafka a través de Argo CD.
7. Restaurar los datos persistentes antes de arrancar los workloads que dependen de ellos.
8. Desplegar la monitorización y los servicios independientes, incluyendo el volumen de datos de Prometheus.
9. Reactivar DNS, ingress y las rutas de Cloudflare solo después de que los health checks internos pasen.
10. Validar la conectividad entre servicios, los dashboards, las alertas y los backups.

## Recuperación de Kafka

Kafka usa tres réplicas broker/controller y claims persistentes. No borrar los claims durante una reconstrucción a menos que los datos se hayan descartado intencionadamente y se haya verificado una restauración.

Tras la restauración, verificar:

```bash
kubectl get kafka,kafkanodepool,pvc -n kafka
kubectl get pods -n kafka
kubectl get kafkatopic,kafkauser -n kafka
```

Comprobar la salud de los brokers, la replicación, las particiones sub-replicadas, la disponibilidad de los topics y las credenciales de las aplicaciones antes de dejar que productores y consumidores se reanuden.

## Recuperación de Prometheus y Grafana

Restaurar el volumen Docker `prometheus-data` antes de arrancar Prometheus cuando el histórico de métricas importe. Los dashboards de Grafana aprovisionados desde `services/grafana/` pueden recrearse desde Git, pero los dashboards o ajustes que solo existen en la base de datos de Grafana necesitan un backup de base de datos aparte.

## Checklist de validación

- Todos los hosts Proxmox y los guests necesarios son alcanzables.
- K3s reporta cada nodo esperado como `Ready`.
- Las aplicaciones de Argo CD están `Synced` y `Healthy`.
- Las `PersistentVolumeClaim` están `Bound` y montadas.
- Los topics de Kafka tienen la replicación esperada y no hay particiones sub-replicadas.
- Prometheus está scrapeando sus targets.
- Los dashboards de Grafana cargan y las alertas llegan a sus destinos de notificación.
- El DNS y el ingress solo exponen los servicios aprobados.
- Se ha registrado un backup reciente y una prueba de restauración.

## Pruebas de recuperación

Realizar un ejercicio de restauración periódicamente en un entorno aislado. Registrar la fecha, las versiones, los comandos usados, los prerrequisitos que faltaban, la duración de la restauración y los cambios de seguimiento en este repositorio o en su registro de operaciones.

Ver también: [almacenamiento](/homelab/arquitectura/almacenamiento/).
