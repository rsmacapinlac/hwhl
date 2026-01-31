# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible-based homelab automation project for managing a comprehensive self-hosted infrastructure. The project automates deployment and configuration of 30+ services across multiple Proxmox nodes using Docker containers.

## Core Architecture

### Infrastructure Layers
- **Proxmox Virtualization**: LXC containers and VMs managed via Proxmox API
- **DNS Management**: Pi-hole for ad-blocking and local DNS resolution
- **Edge Services**: Traefik reverse proxy with Authelia authentication 
- **Container Orchestration**: Docker with Portainer management and Watchtower updates
- **Service Discovery**: DNS-based service routing through homelab domain

### Ansible Structure
- **Main Playbook**: `ansible/site.yml` - orchestrates all service deployments
- **Inventory**: Host groups in `ansible/inventory/` (groups) and `homelab_config/ansible/inventory/` (hosts and group vars)
- **Roles**: Self-contained service deployments in `ansible/roles/` directory
- **Configuration**: Environment files and templates in `homelab_config/ansible/files/config/` and role defaults
- **Variables**: Global settings in `homelab_config/ansible/group_vars/all.yml`

### Service Organization
Services are deployed across host groups:
- `dns`: Pi-hole DNS servers
- `edge`: Traefik, Authelia, Cloudflare DDNS, WireGuard
- `containers`: Portainer, Watchtower, container management
- `arrs`: Media automation (Sonarr, Radarr, etc.)
- `jellyfin`/`plex`: Media servers
- Individual service groups: `nextcloud`, `homeassistant`, `prometheus`, etc.

## Common Commands

### Initial Setup
```bash
# Initialize Ansible environment
./bin/ansible-init.sh

# Deploy Proxmox infrastructure
cd ansible && ansible-playbook proxmox-setup.yml
# OR: ./bin/ansible-playbook.sh proxmox-setup.yml

# Deploy all services
cd ansible && ansible-playbook site.yml
# OR: ./bin/ansible-playbook.sh site.yml
```

### Service Management
```bash
# Deploy specific service groups
ansible-playbook site.yml --limit dns
ansible-playbook site.yml --limit edge
ansible-playbook site.yml --limit containers
ansible-playbook site.yml --limit jellyfin

# Syntax validation
ansible-playbook site.yml --syntax-check

# Dry run
ansible-playbook site.yml --check

# Maintenance tasks
ansible-playbook maintenance.yml
```

### Remote Host Management (Ad-Hoc Commands)
Use `ansible` ad-hoc commands to run shell commands on remote LXC hosts. This avoids SSH key/config issues by leveraging the Ansible inventory and connection settings already configured for the project.

```bash
# Run a command on a specific host
ansible <hostname> -m shell -a "<command>"

# Examples:
ansible media.int.macapinlac.network -m shell -a "docker ps -a"
ansible media.int.macapinlac.network -m shell -a "ls -la /data/containers/"
ansible media.int.macapinlac.network -m shell -a "docker exec borgbackup borgmatic list"
```

**Note:** When using `docker ps --format` with ansible ad-hoc commands, Go template braces conflict with Jinja2. Use `{% raw %}...{% endraw %}` to escape:
```bash
ansible <host> -m shell -a 'docker ps --format "table {% raw %}{{.Names}}\t{{.Status}}{% endraw %}"'
```

### Key Files
- `ansible/ansible.cfg`: Ansible configuration (inventory points to ansible + homelab_config)
- `ansible/inventory/`: Group hierarchy (e.g. groups.yml)
- `homelab_config/ansible/inventory/`: Host definitions
- `homelab_config/ansible/group_vars/all.yml`: Global variables (domain, API keys, etc.); `ansible/group_vars/all.yml` is a symlink to this file
- `homelab_config/ansible/files/config/`: Service-specific environment files

## Development Patterns

### Role Structure
Each service role follows standard Ansible patterns:
- `tasks/main.yml`: Primary deployment logic
- `templates/docker-compose.j2`: Docker Compose template
- `defaults/main.yml`: Default variables (when needed)
- `handlers/main.yml`: Service restart handlers (when needed)

### Configuration Management
- Environment variables stored in `files/config/{service}/environment`
- Sensitive data in `homelab_config/ansible/group_vars/all.yml` (should use Ansible Vault in production)
- Docker Compose templates use Jinja2 for dynamic configuration

### Host Groups and Targeting
Services can be deployed individually using `--limit` with host group names defined in inventory files. The architecture supports both single-service and full-stack deployments.