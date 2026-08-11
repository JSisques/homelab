# Node Exporter Ansible Role

Instala y ejecuta Prometheus Node Exporter para exponer métricas del host al sistema de monitorización.

## Responsabilidades

- Instalar el paquete `prometheus-node-exporter`.
- Habilitar el servicio al arrancar.
- Iniciar el servicio de métricas del host.

El scraping de Prometheus y sus targets pertenecen a la configuración de monitorización, no a este rol.

## Uso

```yaml
roles:
  - common
  - node-exporter
```

## Variables

- `node_exporter_packages`: paquetes instalados.
- `node_exporter_service_name`: nombre del servicio, por defecto `prometheus-node-exporter`.

El rol es idempotente y usa los paquetes mantenidos por la distribución Debian-family.
