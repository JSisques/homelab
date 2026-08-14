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

1. **Usuario**: *Datacenter → Permissions → Users → Add*. Username `terraform`, realm `pve` (autenticación por token, no hace falta contraseña real).
2. **Rol**: *Datacenter → Permissions → Roles → Create*. Nombre `TerraformProvision`, marca exactamente los permisos de la tabla de arriba.
3. **Grupo**: *Datacenter → Permissions → Groups → Create*, nombre `terraform`.
4. **Asignar el rol al grupo** en la raíz: *Datacenter → Permissions → Add → Group Permission*. Path `/`, Group `terraform`, Role `TerraformProvision`, con Propagate activado.
5. **Meter el usuario en el grupo**: *Users → terraform → Edit* → Group `terraform`.
6. **Token API**: *Users → terraform → API Tokens → Add*. Token ID `terraform` (o el que prefieras) — con "Privilege Separation" desactivado, para que el token herede directamente los permisos del usuario/grupo. Copia el secret en el momento: Proxmox no lo vuelve a mostrar.

</Steps>

El resultado es el valor de `TF_VAR_proxmox_api_token`, con el formato `user@realm!tokenid=uuid` (por ejemplo `terraform@pve!terraform=xxxxxxxx-...`) — ver la [tabla de secretos de la guía de despliegue](/homelab/guides/desplegar/#secretos).

:::tip[Fuente]
Basado en el proceso descrito en ["Provisioning Proxmox Virtual Machines with Terraform" (Daniel Edwards, Medium)](https://medium.com/@DatBoyBlu3/provisioning-proxmox-virtual-machines-with-terraform-d9e9c549f947), adaptado al provider [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) que usa este repo (en vez de `Telmate/proxmox`) y al flujo de plantillas por imagen cloud en lugar de ISO instalada a mano.
:::

Con la plantilla creada y el token en la mano, sigue con [Cómo desplegarlo](/homelab/guides/desplegar/).
