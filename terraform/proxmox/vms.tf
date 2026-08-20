# Downloaded once and imported into every VM's disk below, instead of
# cloning a hand-built Proxmox template (see terraform/proxmox/README.md).
resource "proxmox_download_file" "vm_cloud_image" {
  content_type = "import"
  datastore_id = var.vm_image_datastore_id
  node_name    = var.proxmox_node
  url          = var.vm_cloud_image_url
  file_name    = var.vm_cloud_image_file_name
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vm_nodes

  name      = each.key
  node_name = each.value.proxmox_node
  vm_id     = each.value.vm_id

  cpu {
    cores = each.value.cpu
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_storage
    import_from  = proxmox_download_file.vm_cloud_image.id
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
