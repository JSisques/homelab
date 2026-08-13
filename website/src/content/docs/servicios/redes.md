---
title: Redes y acceso
description: Traefik, Cloudflare Tunnel, AdGuard Home y WireGuard — cómo se resuelve y se llega a cada servicio según su nivel de acceso.
---

Los servicios se reparten en tres niveles de acceso, declarados explícitamente en el campo `tier` de `config/services.yaml` (ver [modelo de configuración](/homelab/configuracion/modelo/#tier)) — nada es público por defecto.

| Nivel | Dominio | Acceso |
| --- | --- | --- |
| Interno | `*.home.arpa` | Solo LAN/VPN, nunca expuesto a internet |
| Personal | `jsisques.net` | Servicios de cara personal, vía Cloudflare Tunnel |
| Público | `sisqueslabs.com` | Aplicaciones públicas del homelab, vía Cloudflare Tunnel |

`home.arpa` es el nombre reservado por el [RFC 8375](https://datatracker.ietf.org/doc/html/rfc8375) para redes domésticas, y se usa para todo lo que debe quedarse en LAN/VPN — nunca tiene registro DNS público ni ruta de Cloudflare. La resolución y el TLS de `*.home.arpa` se gestionan enteramente dentro de la red: AdGuard Home reescribe `*.home.arpa` hacia Traefik, que termina HTTPS (autofirmado) y enruta cada nombre a su LXC backend por IP:puerto. `jsisques.net` y `sisqueslabs.com` pasan por el **mismo** Cloudflare Tunnel, que termina en una LXC dedicada y reenvía cada nombre a su destino interno. No se abre ningún puerto entrante en la red doméstica para esto.

```text
Cliente LAN/VPN                         Cliente externo
      │                                        │
      ▼                                        ▼
AdGuard Home                          Cloudflare Tunnel
(*.home.arpa → Traefik)          (jsisques.net / sisqueslabs.com)
      │                                        │
      ▼                                        ▼
   Traefik  ──────────────────────────▶  LXC / servicio destino
(TLS autofirmado, enrutado por IP:puerto)
```

## Traefik

<span class="slh-tier slh-tier--internal">interna</span> · `traefik.home.arpa`

Proxy inverso interno para todos los servicios `tier: internal` (`*.home.arpa`).

- `dynamic/routes.yml` se **genera** desde `config/services.yaml`/`config/hosts.yaml` (`generate-traefik.sh`) — las rutas apuntan a la IP:puerto exacta de cada LXC porque Traefik corre en su propia LXC, sin *service discovery* por etiquetas de Docker.
- El TLS es autofirmado/generado automáticamente (`tls: {}` vacío) — el navegador avisará, es el comportamiento esperado hasta que se sustituya por una CA real.
- Paso manual de una sola vez, **en ambas instancias de AdGuard**: reescritura DNS `*.home.arpa → 192.168.0.204` (la IP de Traefik) — nada resuelve hasta hacerlo, porque AdGuard no tiene configuración como código. Una vez desplegado `adguard-home-sync`, basta con añadirla en `adguard-home-1`; se replica sola a `adguard-home-2`.
- Dashboard propio en `https://traefik.home.arpa`; métricas Prometheus en `:8082`. La configuración se recarga sola (`providers.file.watch: true`), sin reiniciar tras regenerar las rutas.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/traefik).

## Cloudflared

<span class="slh-tier slh-tier--internal">interna (túnel)</span> · sin UI

Ejecuta un Cloudflare Tunnel para los dominios público y personal (`sisqueslabs.com`, `jsisques.net`); no se abre ningún puerto entrante en casa.

- Configuración manual de una sola vez, fuera de Git: `cloudflared tunnel login` + `cloudflared tunnel create homelab`, anotar el tunnel ID en `config.yml`, añadir un CNAME de DNS por cada hostname, y mantener el JSON de credenciales **fuera de Git** — se entrega a Ansible como `cloudflared_credentials_json` (secreto de Vault/CI).
- `config.yml` (las reglas de ingress) sí se commitea — no lleva secretos, solo el enrutado. El catch-all por defecto es `404`.
- Los servicios `tier: internal` nunca deben tener entrada aquí — solo los de tier `public`/`personal`. Ver la nota de la [guía de despliegue](/homelab/guides/desplegar/#cloudflare-tunnel).

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/cloudflared).

## AdGuard Home

<span class="slh-tier slh-tier--internal">interna</span> · `adguard1.home.arpa` / `adguard2.home.arpa`

Resolutor DNS de toda la red y bloqueador de anuncios/trackers para clientes LAN y VPN, desplegado como **dos instancias independientes** — `adguard-home-1` (primaria) y `adguard-home-2` (secundaria), en LXC separadas — para que la resolución DNS no dependa de una sola máquina. Los clientes (DHCP del router, o `PEERDNS` en WireGuard) reciben las dos IPs, primaria y secundaria.

- Sin configuración como código: el primer arranque exige un asistente manual (credenciales de admin, DNS upstream, interfaces de escucha) en el puerto `3000`, **en cada instancia por separado**.
- Tras el asistente, hay que añadir a mano la reescritura DNS `*.home.arpa → 192.168.0.204` para que Traefik funcione (ver nota de sincronización más abajo).
- Estado persistente en los volúmenes `adguard-work`/`adguard-conf` de cada LXC — no comparten datos entre sí. Puertos: `53/tcp+udp` (DNS), `3000/tcp` (panel de administración). Solo interno, nunca a través del Cloudflare Tunnel.

### Sincronización (`adguard-home-sync`)

Las dos instancias no comparten estado por sí solas — [AdGuardHome-Sync](https://github.com/bakito/adguardhome-sync) corre como contenedor aparte en la LXC de `adguard-home-2`, y copia periódicamente la configuración (filtros, reescrituras DNS, reglas por cliente) de `adguard-home-1` (origen) hacia `adguard-home-2` (réplica).

- Necesita las credenciales de admin de **ambas** instancias (creadas a mano en su asistente de primer arranque) — se pasan como secretos de Ansible (`adguard_sync_origin_username`/`_password`, `adguard_sync_replica_username`/`_password`), nunca commiteados.
- La URL de origen se resuelve sola desde el inventario de Ansible (`hostvars['adguard-home-1'].ansible_host`) — no hay IP hardcodeada.
- Si este contenedor se cae, ambas instancias de AdGuard siguen resolviendo DNS con normalidad; solo dejan de mantenerse sincronizadas entre sí.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/adguard-home) y [adguard-home-sync](https://github.com/JSisques/homelab/tree/main/services/adguard-home-sync).

## WireGuard

<span class="slh-tier slh-tier--internal">interna (VPN)</span> · sin URL, es una VPN

Puerta de enlace VPN autoalojada (`linuxserver/wireguard`) para acceder en remoto a los servicios `*.home.arpa` sin pasar por el Cloudflare Tunnel.

- Pasos manuales que solo puede hacer el operador antes de desplegar: sustituir `SERVERURL` por un hostname que resuelva a la IP pública de casa (DNS dinámico si no hay IP fija) y abrir el puerto UDP `51820` en el router hacia la LXC.
- `PEERS=5` genera automáticamente 5 configuraciones de cliente + códigos QR en el volumen `wireguard-config` en el primer arranque; se extraen con `docker compose cp`.
- Enruta los clientes hacia `192.168.0.0/24` y les entrega las dos instancias de AdGuard Home como DNS primario/secundario (`PEERDNS`), así que los clientes VPN también tienen bloqueo de anuncios y no pierden resolución si una de las dos cae.

Ver [código fuente](https://github.com/JSisques/homelab/tree/main/services/wireguard).
