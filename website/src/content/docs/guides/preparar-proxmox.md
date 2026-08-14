---
title: Preparar Proxmox para Terraform
description: Cómo crear la plantilla cloud-init y la cuenta de servicio con permisos mínimos que Terraform necesita antes del primer `terraform apply`.
---

import { Steps } from '@astrojs/starlight/components';

`terraform/proxmox/` **clona** máquinas virtuales a partir de una plantilla ya existente (`vm_template_id`) y habla con la API de Proxmox usando un token (`proxmox_api_token`). Ninguna de las dos cosas la crea Terraform — son configuración de Proxmox que se hace una sola vez, a mano, antes de tocar `terraform apply` por primera vez.

Esta página cubre esos dos prerequisitos. Para el resto del flujo (generar variables, `plan`/`apply`, desplegar servicios), ver [Cómo desplegarlo](/homelab/guides/desplegar/).

## 1. Plantilla cloud-init para las VMs

`vms.tf` clona `var.vm_template_id` y configura IP, usuario y clave SSH mediante un bloque `initialization` (cloud-init):

```hcl
clone {
  vm_id = var.vm_template_id
  full  = true
}

initialization {
  ip_config { ... }
  user_account { ... }
}
```

Para que ese bloque funcione, la plantilla tiene que llevar un **disco de cloud-init** — no vale con instalar un Linux desde una ISO normal y convertir esa VM en plantilla, porque una instalación por ISO no trae integración cloud-init. Hace falta partir de una **imagen cloud** (`.qcow2`) de la distro elegida.

<Steps>

1. Descarga la imagen cloud en el propio Proxmox (ejemplo con Debian 12):

   ```bash
   wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
   ```

2. Crea la VM base que se convertirá en plantilla, con un ID libre (por ejemplo `9000`, el mismo valor que luego irá en `vm_template_id`):

   ```bash
   qm create 9000 --name debian-12-cloudinit --memory 2048 --cores 2 \
     --net0 virtio,bridge=vmbr0
   ```

3. Importa la imagen descargada como disco de esa VM y engánchala como `scsi0`:

   ```bash
   qm importdisk 9000 debian-12-generic-amd64.qcow2 local-lvm
   qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
   ```

4. Añade el disco de cloud-init y ajusta arranque/consola:

   ```bash
   qm set 9000 --ide2 local-lvm:cloudinit
   qm set 9000 --boot c --bootdisk scsi0
   qm set 9000 --serial0 socket --vga serial0
   ```

5. Conviértela en plantilla:

   ```bash
   qm template 9000
   ```

6. Usa ese mismo ID como `vm_template_id` en `terraform/proxmox/terraform.tfvars`.

</Steps>

:::note[Esto no es la plantilla de LXC]
`debian_template` (el `.tar.zst` que usan las LXC en `lxc.tf`) es un fichero distinto, descargado vía `pveam` — no tiene relación con esta plantilla de VM ni necesita cloud-init.
:::

## 2. Cuenta de servicio con permisos mínimos

Usar el usuario `root@pam` para el token de Terraform funciona, pero le da acceso total a Proxmox a cualquiera que filtre el `.tfvars` o el secret de CI. Mejor crear una cuenta de servicio dedicada con solo los permisos que Terraform necesita para clonar/gestionar VMs y LXC.

Permisos a asignar (rol personalizado, por ejemplo `TerraformProvision`):

| Permiso | Para qué |
| --- | --- |
| `Datastore.AllocateSpace` | Reservar espacio en el datastore para discos nuevos |
| `Datastore.Audit` | Leer el estado del datastore |
| `Pool.Allocate` | Gestionar pools de recursos |
| `SDN.Use` | Usar bridges/redes definidas en el nodo |
| `Sys.Audit` | Leer el estado del sistema/nodo |
| `Sys.Console` | Acceso a consola (necesario para algunas operaciones de clonado) |
| `Sys.Modify` | Modificar configuración de sistema |
| `Sys.PowerMgmt` | Arrancar/parar el nodo si aplica |
| `VM.Allocate` | Crear VMs/LXC nuevas |
| `VM.Audit` | Leer configuración/estado de VMs |
| `VM.Clone` | Clonar desde la plantilla (`clone { vm_id = ... }`) |
| `VM.Config.CDROM` | Configurar CD-ROM virtual |
| `VM.Config.CPU` | Configurar `cpu { cores = ... }` |
| `VM.Config.Cloudinit` | Configurar el bloque `initialization` (IP, usuario, clave SSH) |
| `VM.Config.Disk` | Configurar `disk { ... }` |
| `VM.Config.HWType` | Configurar tipo de hardware/máquina |
| `VM.Config.Memory` | Configurar `memory { dedicated = ... }` |
| `VM.Config.Network` | Configurar `network_device { ... }` |
| `VM.Config.Options` | Configurar el resto de opciones (`started`, etc.) |
| `VM.Migrate` | Migrar VMs entre nodos |
| `VM.Monitor` | Consultar el estado de ejecución |
| `VM.PowerMgmt` | Arrancar la VM tras clonarla (`started = true`) |

<Steps>

1. **Usuario**: *Datacenter → Permissions → Users → Add*. Username `terraform`, realm `pve` (autenticación por token, no hace falta contraseña real). Confirma que el checkbox **Enabled** queda marcado — si el usuario aparece deshabilitado, cualquier token suyo devuelve `401 Unauthorized` en la API aunque el token y sus permisos estén bien configurados (síntoma fácil de confundir con un secret o rol incorrectos).
2. **Rol**: *Datacenter → Permissions → Roles → Create*. Nombre `TerraformProvision`, marca exactamente los permisos de la tabla de arriba.
3. **Grupo**: *Datacenter → Permissions → Groups → Create*, nombre `terraform`.
4. **Asignar el rol al grupo** en la raíz: *Datacenter → Permissions → Add → Group Permission*. Path `/`, Group `terraform`, Role `TerraformProvision`, con Propagate activado.
5. **Meter el usuario en el grupo**: *Users → terraform → Edit* → Group `terraform`.
6. **Token API**: *Users → terraform → API Tokens → Add*. Token ID `terraform` (o el que prefieras). Copia el secret en el momento: Proxmox no lo vuelve a mostrar.
7. **Permiso propio del token**: *Datacenter → Permissions → Add → API Token Permission*. Path `/`, API Token `terraform@pve!<tu-token-id>`, Role `TerraformProvision`, Propagate activado — **hace falta este permiso además del que le diste al grupo en el paso 4**, incluso con "Privilege Separation" desactivada en el token. En la práctica, el token no heredó el permiso del grupo/usuario sin esta entrada explícita propia; verificalo consultando `GET /access/permissions` con el token (ver el aviso de abajo).

</Steps>

El resultado es el valor de `TF_VAR_proxmox_api_token`, con el formato `user@realm!tokenid=uuid` (por ejemplo `terraform@pve!terraform=xxxxxxxx-...`) — ver la [tabla de secretos de la guía de despliegue](/homelab/guides/desplegar/#secretos).

:::caution[401 Unauthorized contra la API de Proxmox]
Si `terraform plan`/`apply` falla con `Unable to create Proxmox VE API credentials` o un `curl` directo a `/api2/json/cluster/nextid` con el header `Authorization: PVEAPIToken=...` devuelve `401`, revisa en este orden — las tres causas más comunes:

1. **Usuario deshabilitado**: *Users → terraform* → checkbox `Enabled` sin marcar. Un usuario deshabilitado hace que cualquiera de sus tokens devuelva 401, aunque el token y sus permisos estén perfectos.
2. **Al token le falta su propio permiso**: el grant al grupo (paso 4) no alcanza — el token necesita además su propia entrada en *Permissions* (paso 7: `Path /`, el token como sujeto, rol `TerraformProvision`, Propagate activado). Esto aplica tanto si "Privilege Separation" está activada como desactivada.
3. **Secret mal copiado**: verifica que tenga exactamente 36 caracteres y ningún espacio/salto de línea de más (`echo -n "$TF_VAR_proxmox_api_token" | wc -c` como referencia, contando también `user@realm!tokenid=`). Si hay dudas, regeneralo desde *API Tokens → Regenerar secreto* y copialo directo del botón de copiar, sin retipearlo.

Para confirmar qué permisos tiene el token realmente (en vez de adivinar por la UI), consultá el endpoint que refleja lo que Proxmox aplica de verdad:

```bash
curl -sk -H "Authorization: PVEAPIToken=${TF_VAR_proxmox_api_token}" \
  "${TF_VAR_proxmox_endpoint}/api2/json/access/permissions" | jq
```

Si devuelve `{"data": {}}`, el token no tiene ningún permiso efectivo — falta el paso 7.

Si en cambio falla con **`403 Permission check failed`** (no 401) y sin generar ninguna tarea visible en *Tareas*, es lo mismo: el chequeo de permisos rechazó la petición antes de encolar el trabajo. Mismo diagnóstico, mismo fix.
:::

:::caution[Plantilla LXC no descargada]
Si `terraform apply` falla con `unable to create CT <id> - volume 'local:vztmpl/<archivo>' does not exist`, la plantilla `debian_template` que pusiste en `terraform.tfvars` no está descargada en el storage `local`. Bajala desde el nodo Proxmox (por SSH o *Shell* en la UI):

```bash
pveam update
pveam available | grep debian-12
pveam download local debian-12-standard_<version>_amd64.tar.zst
```

`debian_template` debe incluir el prefijo `vztmpl/` (`local:vztmpl/debian-12-standard_<version>_amd64.tar.zst`) — sin él, Terraform apunta a una ruta que no existe aunque la plantilla esté descargada.
:::

:::tip[Fuente]
Basado en el proceso descrito en ["Provisioning Proxmox Virtual Machines with Terraform" (Daniel Edwards, Medium)](https://medium.com/@DatBoyBlu3/provisioning-proxmox-virtual-machines-with-terraform-d9e9c549f947), adaptado al provider [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) que usa este repo (en vez de `Telmate/proxmox`) y al flujo de plantillas por imagen cloud en lugar de ISO instalada a mano.
:::

Con la plantilla creada y el token en la mano, sigue con [Cómo desplegarlo](/homelab/guides/desplegar/).
