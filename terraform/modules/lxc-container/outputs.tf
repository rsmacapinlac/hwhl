# ============================================
# LXC Container Module - Outputs
# ============================================

output "vmid" {
  description = "The VM ID of the container"
  value       = proxmox_virtual_environment_container.container.vm_id
}

output "name" {
  description = "The hostname of the container"
  value       = var.name
}

output "node" {
  description = "The Proxmox node the container runs on"
  value       = proxmox_virtual_environment_container.container.node_name
}

output "ip_address" {
  description = "The IP address of the container"
  value       = var.ip_address
}
