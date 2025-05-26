# Happy wife, Happy life (hwhl)

This is my ansible setup for my homelab.

## Project Overview

This Ansible project automates the setup and management of a comprehensive homelab environment. It includes:

### Core Infrastructure
- DNS management with [PiHole](docs/pihole-setup.md)
- Reverse proxy with Traefik
- Authentication with Authelia
- Container management with Portainer
- Automated updates with Watchtower

### Media Services
- Jellyfin/Plex for media streaming
- Tautulli for media statistics
- Tdarr for media transcoding
- Tubearchivist for YouTube archiving
- Navidrome for music streaming
- Audiobookshelf for audiobook management
- Kavita for e-book management

### Productivity & Organization
- Nextcloud for file sharing and collaboration
- Paperless-ng for document management
- Photoprism for photo management
- Baserow for database management
- Docmost for documentation
- Monica for personal relationship management
- Homepage for dashboard

### Monitoring & Automation
- Prometheus for metrics collection
- Traggo for time tracking
- N8n for workflow automation
- Ofelia for task scheduling
- Syncthing for file synchronization

## Directory Structure

```
.
├── ansible.cfg          # Ansible configuration
├── site.yml            # Main playbook
├── inventory/          # Host inventory files
├── roles/             # Ansible roles
├── files/             # Configuration files
├── group_vars/        # Group variables
└── collections/       # Ansible collections
```

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
touch inventory/proxmox.yml
```

Add the following content to `inventory/proxmox.yml`:
```yaml
proxmox_control_node_by_ip:
  hosts:
    # Replace with your Proxmox server IP
    10.1.0.141:
```

4. Run the Proxmox setup playbook:
```bash
ansible-playbook proxmox-setup.yml
```

## Usage

### Common Commands

```bash
# Run the entire playbook
ansible-playbook site.yml

# Run specific services by host group
ansible-playbook site.yml --limit dns          # Run only DNS (PiHole) setup
ansible-playbook site.yml --limit edge         # Run edge services (Traefik, Authelia, etc.)
ansible-playbook site.yml --limit containers   # Run container management services
ansible-playbook site.yml --limit jellyfin     # Run Jellyfin setup
ansible-playbook site.yml --limit plex         # Run Plex setup

# Check syntax
ansible-playbook site.yml --syntax-check

# Dry run
ansible-playbook site.yml --check
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

- Use `maintenance.yml` for routine maintenance tasks
- Use `provision.yml` for initial provisioning
- Use `de-provision.yml` for cleanup

## Security Notes

- All sensitive credentials should be stored in `files/config/`
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

## Documentation

- [Services Documentation](docs/services.md) - Overview and setup guides for all services
- [Pi-hole Setup](docs/pihole-setup.md) - Detailed guide for Pi-hole deployment
- [Nebula Sync Setup](docs/nebula-sync-setup.md) - Guide for Pi-hole synchronization
