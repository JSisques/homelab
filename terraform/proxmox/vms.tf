resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vm_nodes

  name      = each.key
  node_name = each.value.proxmox_node

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  cpu {
    cores = each.value.cpu
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = each.value.disk
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_mask}"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }

  tags = each.value.tags

  started = true
}
