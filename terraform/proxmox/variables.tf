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

variable "lxc_network" {
  description = "Network and resource configuration for LXC containers"

  type = map(object({
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
}