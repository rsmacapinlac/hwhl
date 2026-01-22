# ============================================
# Homelab Infrastructure - Main Configuration
# ============================================
# This file instantiates LXC containers for DNS, Edge, and Monitoring services.
# Terraform manages infrastructure; Ansible manages configuration.

# ============================================
# DNS Containers (Pi-hole)
# ============================================

module "dns_containers" {
  source   = "./modules/lxc-container"
  for_each = var.dns_containers

  name           = each.key
  vmid           = each.value.vmid
  node           = each.value.node
  template       = var.debian_template
  datastore      = var.datastore
  disk_size      = 32
  cores          = 1
  memory         = 2048
  swap           = 4096
  ip_address     = each.value.ip_address
  gateway        = each.value.gateway
  nameserver     = each.value.nameserver
  dns_domain     = var.homelab_domain
  network_bridge = var.network_bridge
  root_password  = var.root_password
  ssh_public_key = local.ssh_public_key
  proxmox_host   = lookup(var.proxmox_node_ips, each.value.node, "")
  startup_order  = 1
  tags           = concat(local.common_tags, ["dns"])
  mount_points   = each.value.mount_points
}

# ============================================
# Edge Containers (Traefik, Authelia, WireGuard)
# ============================================

module "edge_containers" {
  source   = "./modules/lxc-container"
  for_each = var.edge_containers

  name           = each.key
  vmid           = each.value.vmid
  node           = each.value.node
  template       = var.debian_template
  datastore      = var.datastore
  disk_size      = 64
  cores          = 1
  memory         = 4096
  swap           = 8192
  ip_address     = each.value.ip_address
  gateway        = each.value.gateway
  nameserver     = each.value.nameserver
  dns_domain     = var.homelab_domain
  network_bridge = var.network_bridge
  root_password  = var.root_password
  ssh_public_key = local.ssh_public_key
  proxmox_host   = lookup(var.proxmox_node_ips, each.value.node, "")
  startup_order  = 2
  tags           = concat(local.common_tags, ["edge"])
  mount_points   = each.value.mount_points
}

# ============================================
# Monitoring Containers (Prometheus, Grafana, etc.)
# ============================================

module "monitoring_containers" {
  source   = "./modules/lxc-container"
  for_each = var.monitoring_containers

  name           = each.key
  vmid           = each.value.vmid
  node           = each.value.node
  template       = var.debian_template
  datastore      = var.datastore
  disk_size      = each.value.disk_size
  cores          = 2
  memory         = 8192
  swap           = 16384
  ip_address     = each.value.ip_address
  gateway        = each.value.gateway
  nameserver     = each.value.nameserver
  dns_domain     = var.homelab_domain
  network_bridge = var.network_bridge
  root_password  = var.root_password
  ssh_public_key = local.ssh_public_key
  proxmox_host   = lookup(var.proxmox_node_ips, each.value.node, "")
  startup_order  = 3
  tags           = concat(local.common_tags, ["monitoring"])
  mount_points   = each.value.mount_points
}
