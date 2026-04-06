# ============================================
# Homelab Infrastructure - Main Configuration
# ============================================
# This file instantiates LXC containers for all services.
# Terraform manages infrastructure; Ansible manages configuration.

# ============================================
# All Service Containers
# ============================================
# All containers are defined in var.services_containers with explicit
# resource allocation, startup ordering, and Ansible group membership.

module "services_containers" {
  source   = "./modules/lxc-container"
  for_each = var.services_containers

  name           = each.key
  vmid           = each.value.vmid
  node           = each.value.node
  template       = var.debian_template
  datastore      = var.datastore
  disk_size      = each.value.disk_size
  cores          = each.value.cores
  memory         = each.value.memory
  swap           = each.value.swap
  ip_address     = each.value.ip_address
  gateway        = each.value.gateway
  nameserver     = each.value.nameserver
  dns_domain     = var.homelab_domain
  network_bridge = var.network_bridge
  root_password  = var.root_password
  ssh_public_key = local.ssh_public_key
  proxmox_host   = lookup(var.proxmox_node_ips, each.value.node, "")
  startup_order  = each.value.startup_order
  tags           = concat(local.common_tags, each.value.extra_tags)
  mount_points   = each.value.mount_points
  tun_device     = each.value.tun_device
}
