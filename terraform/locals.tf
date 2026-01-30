# ============================================
# Local Computed Values
# ============================================

locals {
  # Read and parse SSH public key
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_file)))

  # Common tags for all resources
  common_tags = []

  # Compute inverse mapping: ansible_group -> list of container names
  # This allows dynamic Ansible inventory generation for services containers
  services_by_group = {
    for group in distinct(flatten([
      for name, config in var.services_containers : config.ansible_groups
    ])) : group => [
      for name, config in var.services_containers : name
      if contains(config.ansible_groups, group)
    ]
  }
}
