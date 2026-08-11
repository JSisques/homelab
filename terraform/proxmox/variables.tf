variable "k3s_nodes" {
  type = map(object({
    name          = string
    proxmox_node  = string
    cpu           = number
    memory        = number
    disk          = number
    ip            = string
  }))
}