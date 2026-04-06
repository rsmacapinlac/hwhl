# ============================================
# Terraform Outputs
# ============================================

output "services_containers" {
  description = "All service container details"
  value = {
    for name, container in module.services_containers : name => {
      vmid       = container.vmid
      name       = container.name
      node       = container.node
      ip_address = container.ip_address
    }
  }
}

output "dns_ips" {
  description = "List of DNS container IP addresses (for nameserver configuration)"
  value = [
    for name, container in module.services_containers :
    split("/", container.ip_address)[0]
    if contains(var.services_containers[name].ansible_groups, "pihole")
  ]
}
