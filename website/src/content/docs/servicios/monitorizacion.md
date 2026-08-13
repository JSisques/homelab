---
title: Monitorización y observabilidad
description: Prometheus, Grafana, Loki, Alertmanager, Tempo, el OTel Collector, blackbox_exporter y Uptime Kuma — quién hace qué y cómo encajan.
---

Toda la pila de observabilidad corre junta en la LXC compartida `monitoring`, en la misma red Docker, para poder resolverse por nombre entre sí. El [rol de Ansible `monitoring`](https://github.com/JSisques/homelab/tree/main/ansible/roles/monitoring) despliega Prometheus, Grafana, Loki, Alertmanager, Tempo, el OTel Collector y blackbox_exporter de una sola vez. Ver [visión general de arquitectura](/homelab/arquitectura/vision-general/#servicios-fuera-de-kubernetes) para dónde encaja esto en el conjunto.

```text
                         Grafana
                       /    │    \
                      /     │     \
             Prometheus    Loki  Tempo
                 │           │      ▲
              Métricas      Logs    │
                 ▲           ▲      │
                 │           │      │
          blackbox_exporter  Promtail   OTel Collector
          (servicios sin      (todo     (cookidoo-mcp
           /metrics propio)    host)     y futuros)
```

## Prometheus

<span class="slh-tier slh-tier--internal">interna</span> · `prometheus.home.arpa`

Motor de recolección y almacenamiento de métricas. Scrapea todos los targets del homelab y evalúa las reglas de alerta que después enruta Alertmanager.

- `prometheus.yml` y `blackbox-targets.yml` se **generan** a partir de `config/services.yaml`/`config/hosts.yaml` (`scripts/generation/generate-prometheus.sh`) — nunca se editan a mano.
- Tres vías de scraping: `/metrics` nativo (servicios con `monitoring.type: prometheus` en el catálogo), agentes de host (`node-exporter` en `:9100` + `promtail` en `:9080`, obligatorios en toda LXC/VM) y sondas de blackbox_exporter para servicios con UI pero sin métricas propias.
- Los datos viven en el volumen Docker `prometheus-data` — imprescindible en cualquier backup si el histórico importa.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/prometheus).

## Grafana

<span class="slh-tier slh-tier--internal">interna</span> · `grafana.home.arpa`

Visualización de los datos de Prometheus, Loki y Tempo — no recolecta nada por sí mismo.

- Datasources y dashboards aprovisionados como código bajo `config/provisioning/` y `config/dashboards/`, montados en `/etc/grafana/provisioning`.
- El datasource de Prometheus usa la dirección interna `http://prometheus:9090`, no la URL pública.
- Estado en el volumen `grafana-data`; monitorizado también desde Uptime Kuma.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/grafana).

## Loki

<span class="slh-tier slh-tier--internal">interna</span> · sin UI propia, se navega desde Grafana

Backend de agregación de logs, alimentado por Promtail (instalado en todos los hosts) y consultado únicamente a través de Grafana.

- Modo single-binary, almacenamiento en filesystem, retención de 7 días (`config.yml`).
- Comparte la red Docker `monitoring` con Prometheus/Grafana/Alertmanager para resolverse por nombre.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/loki).

## Alertmanager

<span class="slh-tier slh-tier--internal">interna</span> · sin URL pública todavía (no está detrás de Traefik)

Enruta las alertas que dispara Prometheus — hoy, hacia Telegram.

- `alertmanager.yml.j2` lo renderiza Ansible, no es un fichero estático: el receiver de Telegram necesita dos secretos, `monitoring_alertmanager_telegram_bot_token` y `monitoring_alertmanager_telegram_chat_id`.
- Sin esos secretos las alertas se siguen disparando pero caen en un receiver nulo — no falla el despliegue, simplemente no llegan a ningún sitio.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/alertmanager).

## Tempo

<span class="slh-tier slh-tier--internal">interna</span> · sin UI propia, se navega desde Grafana

Almacenamiento de trazas, alimentado por el OTel Collector.

- Solo recibe OTLP por gRPC internamente — no publica puerto en el host, solo es alcanzable por el OTel Collector y Grafana en la red `monitoring`.
- Retención de 48h; los datos del volumen `tempo-data` están **excluidos a propósito** del alcance de backup (ver [almacenamiento](/homelab/arquitectura/almacenamiento/)) — son datos operativos de corta vida, no un sistema de registro.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/tempo).

## OTel Collector

<span class="slh-tier slh-tier--internal">interna</span> · sin UI

Punto de ingesta OTLP (trazas/métricas/logs) para aplicaciones instrumentadas con OpenTelemetry — hoy, solo `cookidoo-mcp`.

- Publicado en el host de la LXC `monitoring` en `192.168.0.20:4317` (gRPC) y `:4318` (HTTP) para que apps de la LAN puedan enviarle datos.
- Reparte lo recibido: las métricas quedan en un endpoint que Prometheus scrapea (`:8889/metrics`, *pull*, no `remote_write` — la configuración de Prometheus no cambia), los logs van al endpoint OTLP nativo de Loki, y las trazas a Tempo.
- Añadir un nuevo servicio instrumentado es solo apuntar su `OTEL_EXPORTER_OTLP_ENDPOINT` a `http://192.168.0.20:4318`.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/otel-collector).

## Blackbox Exporter

<span class="slh-tier slh-tier--internal">interna</span> · sin UI, no aparece en el catálogo de `services.yaml`

Sonda de disponibilidad y latencia para servicios que tienen interfaz HTTP(S) pero no exponen métricas Prometheus nativas — IT-Tools, n8n, Jellyfin, AdGuard Home, Homepage, la pila de descargas, y los endpoints autofirmados de PBS y el apiserver de K3s.

- Prometheus scrapea `blackbox-exporter:9115/probe` pasando el target y el módulo como parámetros de consulta, no el target directamente.
- La lista de targets (`services/prometheus/blackbox-targets.yml`) se **genera** desde `config/services.yaml` (`generate-blackbox.sh`) — no se edita a mano.
- Tres módulos: `http_2xx`, `http_2xx_insecure` (para backends autofirmados como PBS/K3s) y `tcp_connect`.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/blackbox-exporter).

## Uptime Kuma

<span class="slh-tier slh-tier--internal">interna</span> · `uptime.home.arpa`

Monitorización de disponibilidad y alertado de caídas — una preocupación distinta de las métricas de Prometheus/Grafana.

- Sin configuración declarativa: los monitores se crean a mano en la interfaz/API. El campo `uptime.enabled: true` en `config/services.yaml` documenta la intención, pero todavía no existe un generador que cree los monitores automáticamente.
- Los datos (monitores, historial, ajustes) están en el volumen `uptime-kuma-data` — es la única copia, debe respaldarse.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/uptime-kuma).
