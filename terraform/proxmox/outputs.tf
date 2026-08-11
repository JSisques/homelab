output "lxc_ips" {
  description = "IP addresses of the LXC containers managed by Terraform"

  value = {
    for name, config in var.lxc_network : name => config.ip
  }
}

output "k3s_ips" {
  description = "IP addresses of the K3s virtual machines managed by Terraform"

  value = {
    for name, node in var.k3s_nodes : name => node.ip
  }
}
