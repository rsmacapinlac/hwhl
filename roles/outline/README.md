# Outline Ansible Role

This role deploys [Outline](https://github.com/outline/outline), a fast, collaborative knowledge base for teams, using Docker Compose.

## Overview

Outline is a modern team knowledge base with features including:
- Real-time collaborative editing
- Rich markdown editor
- Organized collections and documents
- Team permissions and sharing
- Full-text search
- Multiple authentication providers

This role deploys Outline with its required dependencies (PostgreSQL and Redis) as a complete containerized stack.

## Prerequisites

- Docker and Docker Compose installed on target host
- Traefik reverse proxy configured (for web access)
- At least one authentication provider configured (Google, OIDC, SMTP, etc.)

## Quick Start

### 1. Add to Inventory

Create or update your inventory file (e.g., `inventory/outline.yml`):

```yaml
outline:
  hosts:
    your-host.int.yourdomain.local:
      ansible_host: 10.1.0.X
      # Optional: Override default ports if needed
      # outline_port: 3005
```

### 2. Generate Environment File

Run the setup playbook to create the environment configuration file:

```bash
ansible-playbook site-setup.yml --limit outline
```

This creates `files/config/outline/environment` with all required variables.

### 3. Configure Environment Variables

Edit `files/config/outline/environment` and configure at minimum:

**Required:**
- `SECRET_KEY` - Generate with: `openssl rand -hex 32`
- `UTILS_SECRET` - Generate with: `openssl rand -hex 32`
- `URL` - Your public URL (e.g., `https://outline.yourhost.yourdomain.com`)

**Authentication (at least one):**
- Google OAuth: `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`
- OIDC/Authelia: `OIDC_*` variables
- Email/SMTP: `SMTP_*` variables for magic link authentication

### 4. Deploy

```bash
ansible-playbook site.yml --limit outline
```

### 5. Access

Visit `https://outline.yourhost.yourdomain.com` (replace with your configured hostname)

## Configuration

### Default Variables

Defined in `defaults/main.yml`:

```yaml
outline_port: 3000          # Outline web interface port
outline_postgres_port: 5432 # PostgreSQL port
outline_redis_port: 6379    # Redis port
```

Override these in your inventory or group_vars if needed.

### Environment Variables

Key configuration options in `files/config/outline/environment`:

#### Required
- `SECRET_KEY` - Application secret key
- `UTILS_SECRET` - Utility secret key
- `DATABASE_URL` - PostgreSQL connection (auto-configured)
- `REDIS_URL` - Redis connection (auto-configured)
- `URL` - Public-facing URL

#### File Storage
- `FILE_STORAGE=local` - Use local storage (default)
- `FILE_STORAGE=s3` - Use S3-compatible storage (requires AWS_* variables)

#### Authentication Providers
- **Google OAuth**: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
- **OIDC/Authelia**: `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_AUTH_URI`, etc.
- **Email/SMTP**: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- **Slack**: `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET`

See the [official Outline documentation](https://docs.getoutline.com/s/hosting/doc/docker-7pfeLP5a8t) for complete configuration reference.

## Authentication Setup

### Google OAuth

1. Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/)
2. Add authorized redirect URI: `https://outline.yourhost.yourdomain.com/auth/google.callback`
3. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in environment file

### OIDC (Authelia)

```bash
OIDC_CLIENT_ID=outline
OIDC_CLIENT_SECRET=your_secret_here
OIDC_AUTH_URI=https://authelia.yourdomain.com/api/oidc/authorization
OIDC_TOKEN_URI=https://authelia.yourdomain.com/api/oidc/token
OIDC_USERINFO_URI=https://authelia.yourdomain.com/api/oidc/userinfo
OIDC_DISPLAY_NAME=Authelia
OIDC_USERNAME_CLAIM=preferred_username
OIDC_SCOPES=openid profile email
```

### Email/Magic Link

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM_EMAIL=outline@yourdomain.com
SMTP_SECURE=true
```

## Data Persistence

The role creates three Docker volumes for data persistence:
- `outline-data` - File uploads and attachments
- `outline-postgres-data` - Database storage
- `outline-redis-data` - Cache storage

Volumes are managed by Docker and persist across container updates.

## Maintenance

### Update Outline

Update the Outline container and dependencies:

```bash
ansible-playbook maintenance.yml --limit outline
```

This pulls the latest images and recreates containers with zero-downtime.

### Backup

Back up the PostgreSQL database:

```bash
docker exec outline-postgres pg_dump -U outline outline > outline-backup.sql
```

Restore from backup:

```bash
docker exec -i outline-postgres psql -U outline outline < outline-backup.sql
```

### View Logs

```bash
# All services
docker compose -f /data/services/outline/compose.yml logs -f

# Outline only
docker logs -f outline

# PostgreSQL
docker logs -f outline-postgres

# Redis
docker logs -f outline-redis
```

## Architecture

### Services

The deployment includes three containers:

1. **outline** - Main application (Node.js/React)
2. **outline-postgres** - PostgreSQL 16 database
3. **outline-redis** - Redis 7 cache

### Networks

- `proxy` - External network for Traefik reverse proxy
- `outline-internal` - Internal network for database/cache communication

### Traefik Integration

The role configures Traefik labels for:
- HTTP to HTTPS redirect
- SSL/TLS termination
- WebSocket support (for real-time collaboration)

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs outline
```

Common issues:
- Missing required environment variables (SECRET_KEY, UTILS_SECRET, URL)
- No authentication provider configured
- Database connection issues

### Can't authenticate

Verify:
- At least one auth provider is properly configured
- Redirect URIs match your Outline URL
- OAuth credentials are valid

### Database errors

Check PostgreSQL status:
```bash
docker logs outline-postgres
docker exec outline-postgres pg_isready -U outline
```

## File Structure

```
roles/outline/
├── defaults/main.yml              # Default port configuration
├── handlers/main.yml              # Service restart handler
├── meta/main.yml                  # Role dependencies (docker)
├── tasks/
│   ├── main.yml                   # Main deployment tasks
│   ├── setup.yml                  # Environment file creation
│   └── update.yml                 # Update tasks for maintenance
├── templates/
│   ├── docker-compose.j2          # Docker Compose template
│   └── environment.j2             # Environment variables template
└── README.md                      # This file
```

## References

- [Outline GitHub Repository](https://github.com/outline/outline)
- [Official Docker Documentation](https://docs.getoutline.com/s/hosting/doc/docker-7pfeLP5a8t)
- [Official Docker Hub Image](https://hub.docker.com/r/outlinewiki/outline)
- [Outline Documentation](https://docs.getoutline.com/)

## License

This role follows the same license as the Outline project (BSD-3-Clause).
