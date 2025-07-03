# Kimai Role

This role deploys Kimai time tracking application using Docker Compose.

## Overview

Kimai is a free, open source time-tracking application. This role sets up Kimai with:
- MySQL 8.3 database
- Kimai Apache container
- Persistent data storage
- Plugin support

## Prerequisites

- Docker and Docker Compose must be installed (handled by the `docker` role)
- The environment configuration file must be created first

## Setup

1. Run the setup playbook to create the configuration file:
   ```bash
   ansible-playbook site-setup.yml
   ```

2. Edit the generated configuration file at `files/config/kimai/environment` with your desired settings:
   - Database credentials
   - Admin email and password
   - Port configuration

3. Deploy the service:
   ```bash
   ansible-playbook site.yml
   ```

## Configuration

The role uses the following configuration variables (defined in `files/config/kimai/environment`):

### Database Configuration
- `MYSQL_DATABASE`: Database name (default: kimai)
- `MYSQL_USER`: Database user (default: kimaiuser)
- `MYSQL_PASSWORD`: Database password (default: kimaipassword)
- `MYSQL_ROOT_PASSWORD`: MySQL root password (default: changemeplease)

### Kimai Configuration
- `ADMINMAIL`: Admin email address (default: admin@kimai.local)
- `ADMINPASS`: Admin password (default: changemeplease)
- `DATABASE_URL`: Database connection string (auto-generated)
- `kimai_port`: Port for the web interface (default: 8001, set in playbook)

## Data Persistence

The role creates the following persistent volumes:
- `/data/containers/kimai/mysql`: MySQL database data
- `/data/containers/kimai/data`: Kimai application data
- `/data/containers/kimai/plugins`: Kimai plugins

## Access

Once deployed, Kimai will be available at:
- URL: `http://your-host:8001`
- Default admin credentials: Use the values from your environment configuration

## Updating

To update Kimai to the latest version:
```bash
ansible-playbook site.yml --tags kimai
```

## References

- [Kimai Documentation](https://www.kimai.org/documentation/)
- [Docker Compose Setup](https://www.kimai.org/documentation/docker-compose.html) 