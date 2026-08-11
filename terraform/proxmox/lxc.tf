resource "proxmox_virtual_environment_container" "monitoring" {
  node_name = var.proxmox_node

  description = "Homelab monitoring stack"
  hostname    = "monitoring"

  unprivileged = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 32
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "monitoring"

    ip_config {
      ipv4 {
        address = "192.168.1.20/24"
        gateway = var.gateway
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.debian_template
    type              = "debian"
  }

  features {
    nesting = true
  }

  started = true
}

resource "proxmox_virtual_environment_container" "homepage" {
  node_name = var.proxmox_node

  description = "Homelab Homepage dashboard"
  hostname    = "homepage"

  unprivileged = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "homepage"

    ip_config {
      ipv4 {
        address = "192.168.1.21/24"
        gateway = var.gateway
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.debian_template
    type              = "debian"
  }

  started = true
}

resource "proxmox_virtual_environment_container" "uptime_kuma" {
  node_name = var.proxmox_node

  description = "Homelab uptime monitoring"
  hostname    = "uptime-kuma"

  unprivileged = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "uptime-kuma"

    ip_config {
      ipv4 {
        address = "192.168.1.22/24"
        gateway = var.gateway
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.debian_template
    type              = "debian"
  }

  started = true
}
