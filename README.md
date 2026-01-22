# Happy wife, Happy life (hwhl)

This is my homelab setup. This project is built on the shoulder of giants:

- Proxmox
- Terraform
- Ansible

## Project Overview

The goal for my homelab is to simplify getting up and running. Simplify maintenance (scripts to run and some level of automation). It tries to make it easy to access self-hosted services. It attempts to make the setup of these services easy so you can get up and running quickly.

_It is definitely *not* there yet. It is a work in progress and I'm open to feedback._

## Getting Started

### Prerequisites

- A running Proxmox node (and knowledge of it's IP address), with some knowlege on how to use it.
- Your own domain that is configured with Cloudflare
- A working knowledge of your router's configuration

### Initial Setup


1. Clone the repository

```bash
git clone git@github.com:rsmacapinlac/hwhl.git
cd hwhl
```

2. Initialize your environment:
```bash
./bin/ansible-init.sh
./bin/terraform-init.sh
```

3. Generate SSH keys for your homelab:

```bash
./bin/generate-ssh-keys.sh
```

This will create two SSH key pairs:
- `~/.ssh/id_rsa_homelab_terraform` - For Terraform/Root access to LXC containers
- `~/.ssh/id_rsa_homelab_ansible` - For Ansible user access

The configuration files are already set up to use these keys. If you need to use different key names, update:
- `ansible/roles/proxmox/templates/terraform.tfvars.j2` (for Terraform keys)
- `ansible/roles/common/tasks/users.yml` (for Ansible keys)

4. Configure your Proxmox inventory:
```bash
# Create and edit your inventory file
touch ansible/inventory/proxmox.yml
```

Add the following content to `ansible/inventory/proxmox.yml`:
```yaml
proxmox_control_node_by_ip:
  hosts:
    # Replace with your Proxmox server IP
    10.1.0.141:
```

4. Run the Proxmox setup playbook:
```bash
cd ansible && ansible-playbook proxmox-setup.yml
```
*note: if you have a NFS share that you'd like to setup. Add it to group_vars/all.yml as follows:
```bash
# ============================================
# Proxmox NFS Shares Configuration
# ============================================
# NFS shares to mount on Proxmox nodes
# Configured automatically when proxmox-setup.yml is run
#
# Example configuration (uncomment and customize):
proxmox_nfs_shares:
   - source: "NAS_IP_ADDR:/nfs/ContainerBackups"
     destination: "/mnt/ContainerBackups"
     options: "defaults,noatime"
#   - source: "nas.local:/export/vm-storage"
#     destination: "/mnt/vm-storage"
#     options: "defaults,noatime,rsize=8192,wsize=8192"
#
# Options:
#   - source: NFS server and export path (required, format: "server:/export/path")
#   - destination: Local mount point (required, e.g., "/mnt/share-name")
#   - options: Mount options (optional, defaults to "defaults")
#     Common options: defaults, noatime, rsize=8192, wsize=8192, soft, timeo=30

```

5. Run the Terraform setup playbook:
```bash
cd ansible && ansible-playbook terraform-setup.yml
```


## Usage

### Common Commands

```bash
# Run the entire playbook
# Option 1: Change to ansible directory
cd ansible && ansible-playbook site.yml

# Option 2: Use wrapper script from repository root
./bin/ansible-playbook.sh site.yml

# Run specific services by host group
cd ansible && ansible-playbook site.yml --limit dns          # Run only DNS (PiHole) setup
cd ansible && ansible-playbook site.yml --limit edge         # Run edge services (Traefik, Authelia, etc.)
cd ansible && ansible-playbook site.yml --limit containers   # Run container management services
cd ansible && ansible-playbook site.yml --limit jellyfin     # Run Jellyfin setup
cd ansible && ansible-playbook site.yml --limit plex         # Run Plex setup

# Check syntax
cd ansible && ansible-playbook site.yml --syntax-check

# Dry run
cd ansible && ansible-playbook site.yml --check
```

### Maintenance

- Use `ansible/maintenance.yml` for routine maintenance tasks

## Security Notes

- All sensitive credentials should be stored in `ansible/files/config/`
- Use environment variables or Ansible vault for secrets
- Keep your Ansible control node secure
- Regularly update your systems using the maintenance playbook

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the terms of the included LICENSE file.

## TODO

### Services Using Wrong Compose Filename

These services need to be updated to use `compose.yml` instead of `docker-compose.yml`:

3. Authelia

4. **homeassistant** - smarthome host
   - Status: Running container ✅
   - Issue: Uses `docker-compose.yml` instead of `compose.yml`

5. **tdarr** - media-support host
   - Status: Running container ✅
   - Issue: Uses `docker-compose.yml` instead of `compose.yml`

7. **homepage** - family host
   - Status: Running container ✅
   - Issue: Uses `docker-compose.yml` instead of `compose.yml`

8. **linkding** - family host
   - Status: Running container ✅
   - Issue: Uses `docker-compose.yml` instead of `compose.yml`

11. **ofelia** - family host
    - Status: Running container ✅
    - Issue: Uses `docker-compose.yml` instead of `compose.yml`

12. **paperless-ng** - family host
    - Status: Running container ✅
    - Issue: Uses `docker-compose.yml` instead of `compose.yml`

13. **nextcloud** - yamaguchi host
    - Status: Running (AIO deployment) ✅
    - Issue: Uses flat `nextcloud.yml` file
    - ⚠️ Special case (AIO deployment may not need standard migration)

