# Happy wife, Happy life (hwhl)

This is my homelab setup. This project is built on the shoulder of giants:

- Proxmox
- Terraform (coming soon)
- Ansible

## Project Overview

The goal for my homelab is to simplify getting up and running as well as maintenance (scripts to run and some level of automation). It tries to make it easy to access services. It attempts to make the setup of services somewhat configurable so you can start hosting and using services as quickly as possible.

## Getting Started

### Prerequisites
- A running Proxmox node
- Your own domain that is configured with Cloudflare
- A working knowledge of your router's DHCP configuration
- Your public key (scripts assume that it can be found in $HOME/.ssh/id_rsa.pub)

### Initial Setup

1. Clone the repository:
```bash
git clone git@github.com:rsmacapinlac/hwhl.git
cd hwhl
```

2. Initialize your environment:
```bash
./bin/ansible-init.sh
```

3. Configure your Proxmox inventory:
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
# Option 1: Change to ansible directory
cd ansible && ansible-playbook proxmox-setup.yml

# Option 2: Use wrapper script from repository root
./bin/ansible-playbook.sh proxmox-setup.yml
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

### Available Host Groups

The playbook is organized into the following host groups:

- `dns`: PiHole DNS servers
- `edge`: Edge services (Traefik, Authelia, Cloudflare DDNS, WireGuard)
- `containers`: Container management (Portainer, Watchtower, Traefik)
- `arrs`: *Arr suite (Sonarr, Radarr, etc.)
- `jellyfin`: Jellyfin media server
- `plex`: Plex media server
- `nextcloud`: Nextcloud file sharing
- And many more services as defined in site.yml

### Maintenance

- Use `ansible/maintenance.yml` for routine maintenance tasks
- Use `ansible/provision.yml` for initial provisioning (if exists)
- Use `ansible/de-provision.yml` for cleanup (if exists)

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

### Legacy Pattern (Flat Files)

13. **nextcloud** - yamaguchi host
    - Status: Running (AIO deployment) ✅
    - Issue: Uses flat `nextcloud.yml` file
    - ⚠️ Special case (AIO deployment may not need standard migration)

## Documentation

- [Services Documentation](docs/services.md) - Overview and setup guides for all services
- [Pi-hole Setup](docs/pihole-setup.md) - Detailed guide for Pi-hole deployment
- [Nebula Sync Setup](docs/nebula-sync-setup.md) - Guide for Pi-hole synchronization
