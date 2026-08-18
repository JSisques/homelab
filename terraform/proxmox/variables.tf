variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://proxmox.home.arpa:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!tokenid=uuid'"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification against the Proxmox API (common for self-signed homelab certificates)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Name of the target Proxmox node"
  type        = string
}

variable "lxc_storage" {
  description = "Proxmox datastore used for LXC container disks"
  type        = string
}

variable "vm_storage" {
  description = "Proxmox datastore used for virtual machine disks"
  type        = string
}

variable "network_bridge" {
  description = "Proxmox network bridge attached to provisioned resources"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "LAN gateway address used for static IP configuration"
  type        = string
}

variable "network_mask" {
  description = "CIDR prefix length applied to every LXC/VM static IP"
  type        = number
  default     = 24
}

variable "ssh_public_key" {
  description = "SSH public key installed on provisioned LXC containers and VMs"
  type        = string
}

variable "debian_template" {
  description = "Template file ID used to provision Debian LXC containers, e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  type        = string
}

variable "vm_user" {
  description = "Default user account created on provisioned virtual machines"
  type        = string
  default     = "ansible"
}

variable "vm_template_id" {
  description = "Proxmox VM ID of the cloud-init-ready template that every managed VM is cloned from"
  type        = number
}

variable "vm_nodes" {
  description = "Virtual machines to provision (K3s nodes, Proxmox Backup Server, ...), keyed by hostname. Empty by default."

  type = map(object({
    proxmox_node = string
    vm_id        = number
    cpu          = number
    memory       = number
    disk         = number
    ip           = string
    tags         = optional(list(string), [])
  }))

  default = {}
}

variable "lxc_network" {
  description = "Network and resource configuration for LXC containers, keyed by hostname"

  type = map(object({
    ip     = string
    vm_id  = number
    cores  = number
    memory = number
    disk   = number
    tags   = optional(list(string), [])
  }))
}
