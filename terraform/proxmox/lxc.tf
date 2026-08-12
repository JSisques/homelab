resource "proxmox_virtual_environment_container" "lxc" {
  for_each = var.lxc_network

  node_name = var.proxmox_node

  description = "Homelab ${each.key} service"

  unprivileged = true

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = each.value.disk
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_mask}"
        gateway = var.gateway
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  features {
    # Required to run Docker inside the container.
    nesting = true
  }

  started = true
}
