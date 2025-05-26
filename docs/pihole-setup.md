# PiHole Setup Guide

This guide explains how to set up and configure PiHole in your homelab environment. For general project prerequisites, please refer to the [main README](../README.md).

## Setup Process

### 1. Initial Configuration

First, run the setup playbook to create the environment file:

```bash
ansible-playbook site-setup.yml --limit pihole
```

This will create a sample environment file at `files/config/pihole/environment`. You'll need to customize this file with your desired settings.

### 2. Environment Configuration

Edit the environment file (`files/config/pihole/environment`) with your preferred settings. The file contains three essential configurations:

```ini
# Web interface password
FTLCONF_webserver_api_password: 'changeme'

# DNS settings
FTLCONF_dns_listeningMode: 'all'
FTLCONF_dns_upstreams: '8.8.8.8;8.8.4.4'
```

#### Configuration Details

1. **Web Interface Password**
   - `FTLCONF_webserver_api_password`: Set this to your desired password for the PiHole web interface
   - Example: `'changeme'` (replace with your secure password)

2. **DNS Listening Mode**
   - `FTLCONF_dns_listeningMode`: Controls which interfaces PiHole listens on for DNS queries
   - Value: `'all'` (listens on all interfaces)
   - Other options: `'local'` (only localhost), `'single'` (single interface)

3. **Upstream DNS Servers**
   - `FTLCONF_dns_upstreams`: Defines the upstream DNS servers PiHole will use
   - Format: `'server1;server2'` (semicolon-separated list)
   - Example: `'8.8.8.8;8.8.4.4'` (Google DNS)
   - Common options:
     - Google DNS: `'8.8.8.8;8.8.4.4'`
     - Cloudflare: `'1.1.1.1;1.0.0.1'`
     - Quad9: `'9.9.9.9;149.112.112.112'`

### 3. Deployment

After configuring the environment file, deploy PiHole:

```bash
ansible-playbook site.yml --limit pihole
```

This will:
- Create necessary directories
- Set up the Docker container
- Configure the environment
- Start the PiHole service

## Configuration Details

### DNS Settings

- `PIHOLE_DNS_1` and `PIHOLE_DNS_2`: Upstream DNS servers
- `DNSMASQ_LISTENING`: Interface configuration for DNS queries
- `DNS_PORT`: Port for DNS queries (default: 53)

### Web Interface

- `WEBPASSWORD`: Password for the web interface
- `WEB_PORT`: Port for the web interface (default: 80)
- `ADMIN_EMAIL`: Contact email for the admin

### Privacy and Logging

- `QUERY_LOGGING`: Enable/disable query logging
- `PRIVACY_LEVEL`: Privacy settings (0-4)
  - 0: Show everything
  - 1: Hide domains
  - 2: Hide domains and clients
  - 3: Hide domains, clients, and query types
  - 4: Show only status

## Maintenance

### Updating PiHole

PiHole will be automatically updated by Watchtower. Manual updates can be triggered through Portainer or by running:

```bash
ansible-playbook maintenance.yml --limit pihole
```

### Backup and Restore

Configuration backups are stored in `/data/containers/pihole/etc-pihole/`. To restore from a backup:

1. Stop the PiHole container
2. Copy the backup files to the appropriate location
3. Restart the container

## Troubleshooting

### Common Issues

1. **DNS Not Working**
   - Check if the container is running
   - Verify DNS port (53) is not blocked
   - Check upstream DNS settings

2. **Web Interface Unreachable**
   - Verify web port configuration
   - Check if the container is running
   - Check firewall settings

3. **Container Won't Start**
   - Check environment file syntax
   - Verify directory permissions
   - Check Docker logs

### Logs

View PiHole logs:
```bash
docker logs pihole
```

## Security Considerations

1. Change the default web interface password
2. Use strong upstream DNS servers
3. Configure appropriate privacy levels
4. Keep PiHole updated
5. Monitor query logs for unusual activity

## Additional Resources

### Official PiHole Documentation
- [PiHole Main Documentation](https://docs.pi-hole.net/)
- [PiHole Docker Documentation](https://github.com/pi-hole/docker-pi-hole)
- [PiHole Configuration Guide](https://docs.pi-hole.net/guides/dns/upstream-dns-providers/)
- [PiHole Privacy Settings](https://docs.pi-hole.net/ftldns/privacy-levels/)
- [PiHole Web Interface Guide](https://docs.pi-hole.net/guides/webserver/nginx/)

### Related Documentation
- [Ansible Role Documentation](https://github.com/rsmacapinlac/hwhl/tree/main/roles/pihole)
- [Docker Documentation](https://docs.docker.com/)
- [DNS Best Practices](https://docs.pi-hole.net/guides/dns/best-practices/) 