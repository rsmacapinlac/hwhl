# ============================================
# Proxmox Connection Variables
# ============================================

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for self-signed certificates"
  type        = bool
  default     = false
}

variable "proxmox_node_ips" {
  description = "Map of Proxmox node names to their IP addresses for SSH commands"
  type        = map(string)
  default     = {}
}

# ============================================
# Global Settings
# ============================================

variable "homelab_domain" {
  description = "Domain name for the homelab"
  type        = string
}

variable "timezone" {
  description = "Timezone for containers"
  type        = string
  default     = "America/Vancouver"
}

variable "default_gateway" {
  description = "Default gateway IP address"
  type        = string
}

variable "default_nameserver" {
  description = "Default nameservers (comma-separated)"
  type        = string
}

variable "root_password" {
  description = "Root password for LXC containers"
  type        = string
  sensitive   = true
}

# ============================================
# SSH Configuration
# ============================================

variable "ssh_public_key_file" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# ============================================
# LXC Template Configuration
# ============================================

variable "debian_template" {
  description = "Proxmox LXC template for Debian"
  type        = string
}

variable "datastore" {
  description = "Proxmox datastore for container disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# ============================================
# Container Definitions
# ============================================

variable "dns_containers" {
  description = "Map of DNS container configurations"
  type = map(object({
    vmid        = number
    node        = string
    ip_address  = string
    gateway     = string
    nameserver  = string
    mount_points = optional(list(object({
      host_path      = string
      container_path = string
    })), [])
  }))
  default = {}
}

variable "edge_containers" {
  description = "Map of Edge service container configurations"
  type = map(object({
    vmid        = number
    node        = string
    ip_address  = string
    gateway     = string
    nameserver  = string
    mount_points = optional(list(object({
      host_path      = string
      container_path = string
    })), [])
  }))
  default = {}
}

variable "monitoring_containers" {
  description = "Map of Monitoring service container configurations"
  type = map(object({
    vmid        = number
    node        = string
    ip_address  = string
    gateway     = string
    nameserver  = string
    disk_size   = optional(number, 64)  # Default 64GB, but configurable
    mount_points = optional(list(object({
      host_path      = string
      container_path = string
    })), [])
  }))
  default = {}
}

variable "services_containers" {
  description = "Map of generic service container configurations with flexible resource allocation"
  type = map(object({
    vmid           = number
    node           = string
    ip_address     = string
    gateway        = string
    nameserver     = string
    disk_size      = optional(number, 64)
    cores          = optional(number, 2)
    memory         = optional(number, 4096)
    swap           = optional(number, 8192)
    ansible_groups = optional(list(string), [])  # Groups for Ansible inventory
    extra_tags     = optional(list(string), [])  # Additional Proxmox tags
    mount_points = optional(list(object({
      host_path      = string
      container_path = string
    })), [])
  }))
  default = {}
}
