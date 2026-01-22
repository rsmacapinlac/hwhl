# ============================================
# Local Computed Values
# ============================================

locals {
  # Read and parse SSH public key
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_file)))

  # Common tags for all resources
  common_tags = []
}
