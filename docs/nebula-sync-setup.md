# Nebula Sync Setup Guide

## Overview
Nebula Sync is a service that synchronizes Pi-hole configurations and gravity lists across multiple Pi-hole instances. This guide will help you set up and configure Nebula Sync in your homelab environment.

## Prerequisites
- Multiple Pi-hole instances running
- Docker and Docker Compose installed
- Ansible control node with access to all Pi-hole instances

## Initial Setup

### 1. Environment Configuration
The first step is to configure the environment variables for Nebula Sync. Run the setup playbook:

```bash
ansible-playbook site-setup.yml --tags nebula-sync
```

This will create a configuration directory at `{{ homelab_root }}/services/nebula-sync` with an `environment` file.

### 2. Environment File Configuration
The environment file contains several important settings that need to be configured:

#### Primary and Replica Configuration
```bash
# Primary Pi-hole instance (source)
PRIMARY="https://IP|PASSWORD"  # Replace with your primary Pi-hole details

# Secondary Pi-hole instances (destinations)
REPLICAS="https://IP|PASSWORD,https://IP|PASSWORD"  # Replace with your replica Pi-hole details
```

#### Sync Behavior Settings
```bash
# Perform a full sync on startup
FULL_SYNC=false

# Run gravity sync on startup
RUN_GRAVITY=false

# Cron schedule for sync (default: every 15 minutes)
CRON=*/15 * * * *
```

#### Security Settings
```bash
# Skip TLS verification for HTTPS connections
CLIENT_SKIP_TLS_VERIFICATION=true

# Timezone for the container
TZ=America/Vancouver
```

#### Configuration Sync Options
```bash
# What to sync from the primary to replicas
SYNC_CONFIG_DNS=true        # Sync DNS settings
SYNC_CONFIG_DHCP=false      # Sync DHCP settings
SYNC_CONFIG_NTP=false       # Sync NTP settings
SYNC_CONFIG_RESOLVER=false  # Sync resolver settings
SYNC_CONFIG_DATABASE=false  # Sync database settings
SYNC_CONFIG_MISC=false      # Sync miscellaneous settings
SYNC_CONFIG_DEBUG=false     # Sync debug settings
```

#### Gravity Sync Options
```bash
# What gravity lists to sync
SYNC_GRAVITY_DHCP_LEASES=false          # Sync DHCP leases
SYNC_GRAVITY_GROUP=false                # Sync group settings
SYNC_GRAVITY_AD_LIST=true               # Sync ad lists
SYNC_GRAVITY_AD_LIST_BY_GROUP=true      # Sync ad lists by group
SYNC_GRAVITY_DOMAIN_LIST=true           # Sync domain lists
SYNC_GRAVITY_DOMAIN_LIST_BY_GROUP=true  # Sync domain lists by group
SYNC_GRAVITY_CLIENT=false               # Sync client settings
SYNC_GRAVITY_CLIENT_BY_GROUP=false      # Sync client settings by group
```

## Deployment

### 1. Verify Configuration
Before deploying, ensure your environment file is properly configured with:
- Correct IP addresses for all Pi-hole instances
- Valid passwords for each instance
- Desired sync settings and schedules

### 2. Deploy the Service
Deploy Nebula Sync using the main playbook:

```bash
ansible-playbook site.yml --tags nebula-sync
```

This will:
- Create necessary directories
- Set up the Docker container
- Configure the service to start automatically

## Verification

### 1. Check Container Status
Verify the container is running:
```bash
docker ps | grep nebula-sync
```

### 2. Check Logs
View the container logs:
```bash
docker logs nebula-sync
```

### 3. Verify Sync
- Check the primary Pi-hole's configuration
- Wait for the sync interval (default 15 minutes)
- Verify the configuration has been replicated to the secondary Pi-holes

## Troubleshooting

### Common Issues

1. **Container Fails to Start**
   - Check the environment file for syntax errors
   - Verify all required variables are set
   - Check Docker logs for specific errors

2. **Sync Not Working**
   - Verify network connectivity between instances
   - Check Pi-hole API passwords are correct
   - Ensure TLS verification settings match your environment

3. **Permission Issues**
   - Verify directory permissions in `{{ homelab_root }}/services/nebula-sync`
   - Check Docker user permissions

### Logs and Debugging
- Container logs: `docker logs nebula-sync`
- Sync status: Check the container logs for sync operations
- Debug mode: Set `SYNC_CONFIG_DEBUG=true` for more detailed logging

## Maintenance

### Updating
To update Nebula Sync:
```bash
ansible-playbook site.yml --tags nebula-sync
```

### Backup
The configuration is stored in:
- `{{ homelab_root }}/services/nebula-sync/environment`

### Monitoring
- Monitor container health through Docker
- Check sync status in container logs
- Verify Pi-hole configurations remain synchronized

## Security Considerations

1. **API Passwords**
   - Use strong, unique passwords for each Pi-hole instance
   - Consider using environment variables or secrets management
   - Regularly rotate passwords

2. **Network Security**
   - Ensure Pi-hole instances can communicate over required ports
   - Consider using internal network segmentation
   - Use TLS for all connections when possible

3. **Access Control**
   - Limit access to the Nebula Sync configuration
   - Use appropriate file permissions
   - Consider using Docker secrets for sensitive data

## Best Practices

1. **Configuration**
   - Start with minimal sync settings and expand as needed
   - Use appropriate sync intervals for your environment
   - Document any custom configurations

2. **Monitoring**
   - Regularly check sync status
   - Monitor container health
   - Review logs for any issues

3. **Backup**
   - Regularly backup the environment file
   - Document any custom configurations
   - Keep track of changes to sync settings

## Support and Resources

- [Nebula Sync GitHub Repository](https://github.com/slyfox1186/pihole-regex)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Docker Documentation](https://docs.docker.com/)
- [TechnoTim's Pi-hole Sync Tutorial](https://www.youtube.com/watch?v=YKUYq0Yh0qY)
- [TechnoTim's Homelab Setup](https://github.com/techno-tim/techno-tim.github.io) 