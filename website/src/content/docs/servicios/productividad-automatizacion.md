---
title: Productividad y automatización
description: n8n, Cookidoo MCP y Obsidian — automatización de flujos y dos "cerebros" para agentes de IA.
---

Estos tres servicios comparten un rasgo: guardan estado sensible (workflows, sesiones, notas) que no vive en Git y que hay que respaldar aparte — ver [almacenamiento](/homelab/arquitectura/almacenamiento/).

## n8n

<span class="slh-tier slh-tier--internal">interna</span> · `n8n.home.arpa`

Plataforma de automatización de flujos de trabajo (webhooks, tareas programadas, integraciones).

- Usa PostgreSQL (no SQLite) para un montaje orientado a producción; dos volúmenes, `n8n-data` y `postgres-data`, ambos necesarios para el backup — los workflows y credenciales viven en los datos persistentes, no en el fichero Compose.
- La variable `WEBHOOK_URL` debe coincidir con la URL alcanzable desde fuera para que los workflows disparados externamente funcionen.
- Secretos vía `.env` (nunca commiteado); plantilla en `.env.example`. Necesita `N8N_POSTGRES_PASSWORD` en el entorno antes de `make deploy-n8n` — si falta, se despliega igualmente con `changeme` por defecto, un riesgo silencioso.
- Zona horaria `TZ`/`GENERIC_TIMEZONE` fijada a `Europe/Madrid` — importante para los workflows programados.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/n8n).

## Cookidoo MCP

<span class="slh-tier slh-tier--internal">interna</span> · `cookidoo-mcp.home.arpa`

Servidor MCP que expone una cuenta de Cookidoo (recetas, lista de la compra, planificador de comidas) a agentes de IA vía Streamable HTTP. Solo MCP, sin interfaz web.

- Contenedor único sin estado, sin base de datos — el volumen `cookidoo-mcp-data` solo guarda la persistencia de sesión (`COOKIDOO_COOKIE_FILE=/data/session.json`) para evitar tener que reautenticarse por OAuth2 en cada reinicio. Trátese como una credencial; se respalda vía PBS junto con la LXC.
- Requiere los secretos `COOKIDOO_EMAIL` y `COOKIDOO_PASSWORD`, inyectados por Ansible Vault/CI — nunca en un `.env` commiteado.
- `tier: internal` estricto — expone credenciales de una cuenta real, nunca a través del Cloudflare Tunnel.
- Endpoint MCP en `POST /api/mcp` (sin estado, servidor nuevo por petición); el healthcheck está en `GET /api/health` — la raíz `/` devuelve 404, así que el monitor de Uptime Kuma debe apuntar a `/api/health`, no a `/`.
- Envía trazas/métricas/logs por OTLP al OTel Collector; no expone `/metrics` propio.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/cookidoo-mcp).

## Obsidian

<span class="slh-tier slh-tier--internal">interna</span> · `obsidian.home.arpa`

Vault de Obsidian sin cabeza (*headless*), expuesto a clientes MCP (Streamable HTTP en `/mcp`, SSE en `/sse`). Sin interfaz gráfica de navegador — es un "segundo cerebro" para agentes de IA, no una app de notas al uso.

- Construido a partir del repositorio `shanehull/obsidian-remote`, fijado al tag de release `v1.2.0` (no hay imagen publicada) — subir de versión es cambiar una línea.
- `TEST_MODE=true` es intencional, no un flag de desarrollo olvidado: en el primer arranque autoinicializa un vault nuevo con el plugin Local REST API directamente sobre el montaje `/vaults` respaldado por NFS, ya que no hay una fuente de vault basada en Git configurada. Es seguro dejarlo así indefinidamente — los arranques siguientes no hacen nada.
- El vault vive en el NAS vía montaje NFS `/mnt/nas/obsidian:/vaults` — solo `/vaults` necesita backup; el volumen `/config` se regenera de forma determinista.
- Requiere que exista antes la exportación NFS `192.168.0.111:/export/obsidian` en el NAS.
- Sin autenticación delante del endpoint MCP, por diseño (mismo patrón que otros servicios internos); existe soporte OAuth2 pero está deliberadamente sin configurar.
- Usa Chromium sin interfaz gráfica internamente, lo que pesa más de lo habitual (2 vCPU/2 GB/20 GB); necesita `shm_size: 1gb` y `nesting=true` en la LXC para el sandbox — el punto de fallo más probable en el primer despliegue.
- Monitorizar como **TCP** en el puerto `4000`, no como HTTP — el endpoint MCP no sirve un 200 plano en `GET /`.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/obsidian).
