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
- **Inventory**: Host groups organized by service type in `ansible/inventory/` directory
- **Roles**: Self-contained service deployments in `ansible/roles/` directory
- **Configuration**: Environment files and templates in `ansible/files/config/`
- **Variables**: Global settings in `ansible/group_vars/all.yml`

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

### Key Files
- `ansible/ansible.cfg`: Ansible configuration with optimized settings
- `ansible/inventory/`: Host definitions organized by service type
- `ansible/group_vars/all.yml`: Global variables including domain and API keys
- `ansible/files/config/`: Service-specific environment files and configurations

## Development Patterns

### Role Structure
Each service role follows standard Ansible patterns:
- `tasks/main.yml`: Primary deployment logic
- `templates/docker-compose.j2`: Docker Compose template
- `defaults/main.yml`: Default variables (when needed)
- `handlers/main.yml`: Service restart handlers (when needed)

### Configuration Management
- Environment variables stored in `files/config/{service}/environment`
- Sensitive data in `group_vars/all.yml` (should use Ansible Vault in production)
- Docker Compose templates use Jinja2 for dynamic configuration

### Host Groups and Targeting
Services can be deployed individually using `--limit` with host group names defined in inventory files. The architecture supports both single-service and full-stack deployments.