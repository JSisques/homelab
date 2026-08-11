---
title: Cómo funciona (flujo de datos)
description: De dónde sale cada dato del homelab, qué genera qué, y por qué no hay nada duplicado.
---

Si solo lees un párrafo de esta página, que sea este: `config/hosts.yaml` y `config/services.yaml` son los **dos únicos ficheros donde se escribe algo a mano** — qué máquinas existen y qué servicios corren. Todo lo demás (variables de Terraform, inventario de Ansible, configuración de Prometheus, configuración de Homepage) se **genera** a partir de esos dos ficheros y se guarda en Git como cualquier otro archivo. No se genera en el momento del despliegue: se commitea, y CI falla si deja de coincidir con su fuente.

## La fuente de verdad

Antes, la IP de cada LXC estaba escrita a mano dos veces — en `config/hosts.yaml` y en `terraform.tfvars.example` — y nada avisaba si se desincronizaban. Ahora solo existe una vez:

```text
                    config/hosts.yaml
                 (dirección, cpu, memory, disk)
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
  generate-terraform-vars.sh    generate-inventory.sh
              │                           │
              ▼                           ▼
  hosts.auto.tfvars.json       ansible/inventory/hosts.yml
   (Terraform lo carga solo)      (grupo por host y por role)
              │                           │
              ▼                           ▼
       terraform apply             ansible-playbook
              │                           │
              └─────────────┬─────────────┘
                             ▼
                     misma LXC en Proxmox
              (creada por Terraform, configurada por Ansible)
```

Una sola entrada en `config/hosts.yaml` produce, sin tocar nada más, tanto la LXC vacía (Terraform) como su configuración por dentro (Ansible) — ambas apuntando a la misma IP porque vienen del mismo sitio.

:::tip[Cambiar un valor]
Para subir la RAM de un servicio o moverlo de IP, el cambio va en un único sitio:

```bash
# 1. editas config/hosts.yaml (memory: o address:)
make generate   # hosts.auto.tfvars.json y el inventario quedan al día
make plan       # revisa que Terraform solo toca lo que esperabas
```
:::

`config/services.yaml` sigue el mismo patrón para el catálogo de servicios: `generate-prometheus.sh` construye los scrape jobs de Prometheus, y `generate-homepage.sh` construye la configuración de Homepage, ambos a partir del mismo fichero.

## Pieza por pieza

Cuatro capas, cada una con una responsabilidad y nada más:

| Capa | Qué hace |
| --- | --- |
| `config/` | Qué máquinas existen (`hosts.yaml`) y qué servicios corren (`services.yaml`: dominio, tier, si aparece en Homepage, si Prometheus lo scrapea). |
| `terraform/proxmox/` | `lxc.tf` es un único `for_each` sobre el mapa de LXCs — añadir un servicio nuevo no es HCL nuevo, es una entrada en `hosts.yaml`. Crea las cajas vacías: CPU, RAM, disco, IP. No instala nada dentro. |
| `ansible/` | Un rol por servicio (`it-tools`, `n8n`, `monitoring`, `homepage`, `uptime-kuma`, `cloudflared`) que copia el `compose.yaml` real de `services/` y lo levanta. |
| `services/` | El `compose.yaml` de cada aplicación, de verdad — la única copia que existe. Ansible no lo reescribe ni lo duplica. |

El `Makefile` de la raíz ata las tres capas: `make deploy` es, literalmente, genera → `terraform apply` → `ansible-playbook playbooks/site.yaml`. Ver la [guía de despliegue](/homelab/guides/desplegar/) para el resto de comandos.

## Node Exporter no es opcional

Cada LXC/VM tiene que tener monitorización de host — no es algo que se pueda olvidar añadir a un playbook. Se garantiza estructuralmente: cada rol de servicio declara `common`, `node-exporter` y `docker` como **dependencias de rol**:

```yaml
# ansible/roles/<servicio>/meta/main.yml
dependencies:
  - role: common
  - role: node-exporter
  - role: docker
```

Por eso los playbooks solo necesitan listar el rol del servicio:

```yaml
# ansible/playbooks/n8n.yaml
- name: Deploy n8n
  hosts: n8n
  become: true
  roles:
    - n8n
```

```text
roles: [n8n]   ← lo único que escribe el playbook
        │
        ▼
   common  →  node-exporter  →  docker  →  n8n
              (obligatorio)
```

Ansible resuelve la cadena de dependencias de `n8n` primero, así que el orden real de ejecución es `common → node-exporter → docker → n8n` — siempre, tanto si se ejecuta ese playbook suelto como si forma parte de `site.yaml`. Verificado con `ansible-playbook --list-tasks`.

Al añadir un rol nuevo, se copia el mismo `meta/main.yml` de tres líneas. Está documentado como convención en [`ansible/README.md`](https://github.com/JSisques/homelab/blob/main/ansible/README.md) precisamente para que no dependa de que alguien se acuerde.

:::note[Siguiente paso]
Con el modelo mental claro, la [guía de despliegue](/homelab/guides/desplegar/) tiene la secuencia exacta de comandos, de cero a servicio corriendo.
:::
