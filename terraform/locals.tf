# ============================================
# Local Computed Values
# ============================================

locals {
  # Read and parse SSH public key
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_file)))

  # Common tags for all resources
  common_tags = []

  # All unique groups across all containers
  _all_groups = distinct(flatten([
    for name, config in var.services_containers : config.ansible_groups
  ]))

  # Minimum startup_order per group — determines group ordering in inventory
  _group_min_startup = {
    for group in local._all_groups : group => min([
      for name, config in var.services_containers :
      config.startup_order
      if contains(config.ansible_groups, group)
    ]...)
  }

  # Sort keys: "NNNN_groupname" — sorts by startup_order then alphabetically
  _group_sort_keys = sort([
    for group, min_order in local._group_min_startup :
    "${format("%04d", min_order)}_${group}"
  ])

  # Ordered list of {group, containers} for inventory generation.
  # Groups ordered by min startup_order; containers within each group
  # ordered by startup_order then name.
  services_by_group = [
    for sort_key in local._group_sort_keys : {
      group = substr(sort_key, 5, -1)
      containers = [
        for container_key in sort([
          for name, config in var.services_containers :
          "${format("%04d", config.startup_order)}_${name}"
          if contains(config.ansible_groups, substr(sort_key, 5, -1))
        ]) : substr(container_key, 5, -1)
      ]
    }
  ]
}
