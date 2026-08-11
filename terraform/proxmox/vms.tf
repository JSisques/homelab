resource "proxmox_virtual_environment_vm" "k3s" {
  for_each = var.k3s_nodes

  name      = each.value.name
  node_name = each.value.proxmox_node

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

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }
}