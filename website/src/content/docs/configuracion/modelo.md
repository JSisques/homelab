---
title: Modelo de configuración
description: config/hosts.yaml y config/services.yaml — la fuente de verdad de la que se genera todo lo demás.
---

`config/` es la fuente de verdad central de metadatos del homelab. Describe el estado deseado a alto nivel y lo consumen las herramientas de infraestructura, automatización y generación de configuración — nunca al revés.

```text
config/
├── README.md
├── services.yaml
└── hosts.yaml
```

:::tip[Modelo mental]
Si quieres entender **por qué** existe este directorio y cómo encaja con Terraform/Ansible, la guía [cómo funciona (flujo de datos)](/homelab/guides/flujo-de-datos/) lo explica con ejemplos paso a paso. Esta página documenta el **modelo de datos** en sí: qué campos tiene cada fichero y qué significan.
:::

## Fuente de verdad

```text
                     config/
                        │
             ┌──────────┴──────────┐
             │                     │
        services.yaml          hosts.yaml
             │                     │
     ┌───────┼────────┐            │
     │       │        │            │
     ▼       ▼        ▼            ▼
 Homepage  Prometheus  Uptime   Ansible
                       Kuma
```

El objetivo es no definir la misma información varias veces en herramientas distintas.

## `services.yaml`

`services.yaml` es el catálogo de servicios del homelab. Describe cada servicio con independencia de cómo se despliega — no es un fichero de Compose ni de Ansible, es metadato.

```yaml
services:
  grafana:
    name: Grafana
    category: Monitoring
    tier: internal
    url: https://grafana.home.arpa
    icon: grafana.png

    homepage:
      enabled: true
      description: Monitoring dashboards

    monitoring:
      enabled: true
      type: prometheus
      endpoint: http://grafana:3000/metrics

    uptime:
      enabled: true
```

### Metadatos comunes

```yaml
name:
category:
tier:
url:
icon:
```

Estos campos describen el servicio en sí y los puede consumir cualquier sistema.

### `tier`

`tier` declara a qué nivel de acceso pertenece el servicio. Determina el dominio usado en `url` y si se espera que sea alcanzable fuera de la LAN.

```yaml
tier: internal
```

Valores válidos:

| Valor | Dominio | Acceso |
| --- | --- | --- |
| `internal` | `*.home.arpa` | Solo LAN/VPN, nunca registro DNS público ni ruta de Cloudflare |
| `personal` | `*.jsisques.net` | Servicio personal, expuesto vía Cloudflare Tunnel |
| `public` | `*.sisqueslabs.com` | Aplicación pública del homelab, expuesta vía Cloudflare Tunnel |

Los servicios `personal` y `public` deben tener una entrada `ingress` correspondiente en `services/cloudflared/config.yml`; los `internal` no deben tenerla nunca — ver [redes y acceso](/homelab/servicios/redes/).

Por defecto se asume `internal` a menos que un servicio tenga una razón deliberada para ser alcanzable desde fuera de la red doméstica.

### `homepage`

Controla si el servicio aparece en Homepage.

```yaml
homepage:
  enabled: true
  description: Monitoring dashboards
```

`scripts/generation/generate-homepage.sh` genera la configuración real de Homepage a partir de este bloque en cada servicio.

### `monitoring`

Describe cómo debe monitorizarlo Prometheus.

```yaml
monitoring:
  enabled: true
  type: prometheus
  endpoint: http://grafana:3000/metrics
```

Lo consume `scripts/generation/generate-prometheus.sh`. Los servicios sin `monitoring` (o sin `/metrics` nativo) se cubren en su lugar con blackbox_exporter — ver [monitorización y observabilidad](/homelab/servicios/monitorizacion/).

### `uptime`

Define si el servicio debe monitorizarse en Uptime Kuma.

```yaml
uptime:
  enabled: true
```

A diferencia de Homepage y Prometheus, Uptime Kuma no tiene todavía un generador — este campo documenta la intención, pero los monitores se siguen creando a mano en su interfaz.

## `hosts.yaml`

`hosts.yaml` describe las máquinas físicas y virtuales que forman el homelab.

```yaml
hosts:
  proxmox:
    type: server
    address: 192.168.1.10
    platform: proxmox

  monitoring:
    type: lxc
    platform: proxmox
    address: 192.168.1.20
    cpu: 4
    memory: 4096
    disk: 32
    role:
      - prometheus
      - grafana

  k3s-01:
    type: vm
    address: 192.168.1.30
    platform: linux
    cpu: 4
    memory: 8192
    disk: 50
    role:
      - k3s
      - control-plane

  raspberrypi-01:
    type: physical
    address: 192.168.1.40
    platform: raspberry-pi
    role:
      - k3s
      - worker
```

`cpu`/`memory` (en MB)/`disk` (en GB) solo tienen sentido en entradas `type: lxc` y `type: vm` — son justo los campos que Terraform necesita para dimensionar el recurso. Los hosts físicos (`server`, `physical`) no los llevan porque Terraform no los aprovisiona.

Esta información se usa para generar:

- **Variables de Terraform** — `scripts/generation/generate-terraform-vars.sh` convierte cada entrada `lxc`/`vm` en `terraform/proxmox/hosts.auto.tfvars.json` (`lxc_network` / `k3s_nodes`), que Terraform carga automáticamente. **Las direcciones y el dimensionado solo se escriben aquí, nunca duplicados en `terraform.tfvars`.**
- **Inventario de Ansible** — `scripts/generation/generate-inventory.sh` convierte cada entrada en `ansible/inventory/hosts.yml`, agrupado por nombre de host y por `role`.
- Targets de monitorización, configuración de Node Exporter y documentación de infraestructura, a medida que esas piezas se completan.

Un host con `address: TBD` es omitido por ambos generadores (con un aviso) en vez de producir una IP rota.

## Configuración vs. infraestructura

`config/` describe **qué existe y cómo se representa**. No crea infraestructura directamente — cada capa tiene una responsabilidad distinta:

```text
config/
   │
   ├── services.yaml
   └── hosts.yaml
          │
          ▼
      Automatización
          │
    ┌─────┼─────┐
    │     │     │
    ▼     ▼     ▼
Terraform Ansible Generación
    │     │     │
    ▼     ▼     ▼
Proxmox Hosts  Configs de servicio
                │
                ▼
             Servicios
```

**Terraform** gestiona recursos de infraestructura (VMs, LXC, redes, almacenamiento) en `terraform/`. **Ansible** configura sistemas operativos y hosts (paquetes, Docker, Node Exporter, configuración del sistema, prerrequisitos de K3s) en `ansible/`. **Kubernetes / Argo CD** gestionan los workloads de Kubernetes (Kafka, monitorización, aplicaciones, ingress, certificados) en `kubernetes/`. Los **scripts** de `scripts/` consumen la configuración cuando hace falta una transformación:

```text
config/services.yaml
        │
        ▼
generate-homepage.sh
        │
        ▼
services/homepage/config/services.yaml
```

## Secretos

La información sensible no debe guardarse directamente en este directorio. No commitear contraseñas, tokens de API, claves privadas, claves SSH privadas, credenciales de bases de datos ni credenciales de nube.

Las referencias a secretos sí son aceptables:

```yaml
credentials:
  secretRef: grafana-admin
```

pero el valor real del secreto debe vivir fuera del repositorio o en un formato de secreto cifrado.

## Convenciones de nombres

Usar nombres en minúscula con guiones para los identificadores de servicio:

```yaml
uptime-kuma:
prometheus:
kafka-exporter:
gardenia-api:
```

Usar categorías descriptivas: `Infrastructure`, `Monitoring`, `Networking`, `Applications`, `Storage`, `Security`.

Los identificadores de servicio deben mantenerse estables porque pueden estar referenciados por configuración generada.

## Validación

La configuración debe validarse antes de desplegar:

```bash
./scripts/validation/validate.sh
```

La validación debe comprobar sintaxis YAML, campos obligatorios, referencias inválidas, identificadores de servicio duplicados, valores de configuración inválidos y fugas de secretos.

## Flujo de trabajo Git

```bash
git diff config/

./scripts/validation/validate.sh

git add config/
git commit -m "config: add kafka monitoring"
git push
```

## Principios de diseño

- **Fuente única de verdad** — evitar duplicar metadatos de servicio en distintos ficheros de configuración.
- **Agnóstico de herramienta** — la configuración central describe el homelab, no queda acoplada a una herramienta concreta cuando es posible evitarlo.
- **Declarativo** — describe el estado deseado, no una secuencia de comandos.
- **Reproducible** — un homelab nuevo debe poder reconstruir su configuración a partir del repositorio.
- **Versionado** — toda la configuración no sensible vive en Git.
- **Explícito** — se prefiere la configuración explícita al descubrimiento automático cuando la fiabilidad importa.

`config/` se mantiene deliberadamente independiente de los detalles de implementación de la infraestructura: define el homelab a alto nivel, y son las demás capas las que determinan cómo se implementa ese estado deseado.
