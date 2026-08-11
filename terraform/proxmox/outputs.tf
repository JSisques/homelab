output "lxc_ips" {
  description = "IP addresses of the LXC containers managed by Terraform"

  value = {
    for name, config in var.lxc_network : name => config.ip
  }
}

output "vm_ips" {
  description = "IP addresses of the virtual machines managed by Terraform"

  value = {
    for name, node in var.vm_nodes : name => node.ip
  }
}
