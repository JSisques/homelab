resource "proxmox_virtual_environment_container" "lxc" {
  for_each = var.lxc_network

  node_name = var.proxmox_node
  vm_id     = each.value.vm_id

  description = "Homelab ${each.key} service"

  unprivileged = true

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
    swap      = each.value.swap
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

  tags = each.value.tags

  started = true

  lifecycle {
    # Some containers (jellyfin, obsidian, rustfs) get a NAS bind mount
    # added on the Proxmox host via `pct set -mpN ...` outside Terraform
    # (see commits 668f35f, ab87d64) — undeclared here on purpose, so
    # Terraform must not try to strip it and force-replace the container.
    #
    # jellyfin also gets its iGPU passthrough (dev0/dev1) via `pct set`
    # for the same reason: it needs root@pam, which this repo's API token
    # deliberately doesn't have. See services/jellyfin/README.md#gpu-passthrough.
    ignore_changes = [mount_point, device_passthrough]
  }
}
