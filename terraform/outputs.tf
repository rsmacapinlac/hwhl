# ============================================
# Terraform Outputs
# ============================================

# ============================================
# DNS Container Outputs
# ============================================

output "dns_containers" {
  description = "DNS container details"
  value = {
    for name, container in module.dns_containers : name => {
      vmid       = container.vmid
      name       = container.name
      node       = container.node
      ip_address = container.ip_address
    }
  }
}

output "dns_ips" {
  description = "List of DNS container IP addresses (for nameserver configuration)"
  value       = [for name, container in module.dns_containers : split("/", container.ip_address)[0]]
}

# ============================================
# Edge Container Outputs
# ============================================

output "edge_containers" {
  description = "Edge container details"
  value = {
    for name, container in module.edge_containers : name => {
      vmid       = container.vmid
      name       = container.name
      node       = container.node
      ip_address = container.ip_address
    }
  }
}

# ============================================
# Monitoring Container Outputs
# ============================================

output "monitoring_containers" {
  description = "Monitoring container details"
  value = {
    for name, container in module.monitoring_containers : name => {
      vmid       = container.vmid
      name       = container.name
      node       = container.node
      ip_address = container.ip_address
    }
  }
}

# ============================================
# Ansible Integration Outputs
# ============================================

output "ansible_inventory_dns" {
  description = "Ansible inventory format for DNS hosts"
  value = join("\n", [
    for name, container in module.dns_containers :
    "${name} ansible_host=${split("/", container.ip_address)[0]}"
  ])
}

output "ansible_inventory_edge" {
  description = "Ansible inventory format for Edge hosts"
  value = join("\n", [
    for name, container in module.edge_containers :
    "${name} ansible_host=${split("/", container.ip_address)[0]}"
  ])
}

output "ansible_inventory_monitoring" {
  description = "Ansible inventory format for Monitoring hosts"
  value = join("\n", [
    for name, container in module.monitoring_containers :
    "${name} ansible_host=${split("/", container.ip_address)[0]}"
  ])
}
