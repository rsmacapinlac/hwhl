# ============================================
# LXC Container Module - Input Variables
# ============================================

variable "name" {
  description = "Container name"
  type        = string
}

variable "vmid" {
  description = "Proxmox VM ID"
  type        = number
}

variable "node" {
  description = "Proxmox node to deploy on"
  type        = string
}

variable "template" {
  description = "LXC template to use"
  type        = string
}

variable "datastore" {
  description = "Datastore for container disk"
  type        = string
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "swap" {
  description = "Swap in MB"
  type        = number
}

variable "ip_address" {
  description = "IP address with CIDR (e.g., 10.1.0.2/24)"
  type        = string
}

variable "gateway" {
  description = "Gateway IP address"
  type        = string
}

variable "nameserver" {
  description = "DNS nameserver(s)"
  type        = string
}

variable "dns_domain" {
  description = "DNS search domain"
  type        = string
  default     = ""
}

variable "network_bridge" {
  description = "Network bridge name"
  type        = string
}

variable "root_password" {
  description = "Root password for the container"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for root access"
  type        = string
}

variable "startup_order" {
  description = "Container startup order (lower starts first)"
  type        = number
  default     = 99
}

variable "tags" {
  description = "Tags to apply to the container"
  type        = list(string)
  default     = []
}

variable "start_on_create" {
  description = "Start container after creation"
  type        = bool
  default     = true
}

variable "unprivileged" {
  description = "Run as unprivileged container"
  type        = bool
  default     = true
}

variable "nesting" {
  description = "Enable nesting (required for Docker)"
  type        = bool
  default     = true
}

variable "proxmox_host" {
  description = "Proxmox host IP/hostname for SSH commands"
  type        = string
  default     = ""
}

variable "mount_points" {
  description = "List of bind mount points to attach to the container"
  type = list(object({
    host_path      = string  # Path on Proxmox host (e.g., /mnt/ContainerBackups)
    container_path = string  # Path inside container (e.g., /mnt/backups)
  }))
  default = []
}

variable "tun_device" {
  description = "Enable /dev/net/tun passthrough (required for VPN containers like transmission-openvpn)"
  type        = bool
  default     = false
}
