# Migration Plan: nextcloud

## Current State Summary
- **Compliance:** 6/35 patterns (17%)
- **Service Type:** User-facing (Traefik integration skipped - AIO manages its own reverse proxy)
- **Deployment Method:** Legacy shell command (`docker compose -f ... up -d`)
- **File Structure:** Flat (`/data/services/nextcloud.yml`)

## Migration Overview

### Files to Create
| File | Purpose |
|------|---------|
| `roles/nextcloud/templates/environment.j2` | Environment variables template |
| `roles/nextcloud/tasks/setup.yml` | One-time environment file creation |
| `roles/nextcloud/tasks/update.yml` | Update workflow for maintenance.yml |
| `roles/nextcloud/handlers/main.yml` | Service restart handler |

### Files to Modify
| File | Changes |
|------|---------|
| `roles/nextcloud/defaults/main.yml` | Add port variables |
| `roles/nextcloud/tasks/main.yml` | Refactor to docker_compose_v2, add env validation |
| `roles/nextcloud/templates/docker-compose.j2` | Add env_file, configurable ports, remove version |
| `ansible/site-setup.yml` | Add nextcloud setup integration |
| `ansible/maintenance.yml` | Add nextcloud update integration |

## Migration Phases

### Phase 1: Environment File Management
1. Create `templates/environment.j2` with:
   - `APACHE_PORT` (default 11000)
   - `NEXTCLOUD_DATADIR` path
   - `SKIP_DOMAIN_VALIDATION` setting
   - Other AIO-specific environment variables

2. Create `tasks/setup.yml` for initial config generation

### Phase 2: Defaults
1. Update `defaults/main.yml` with:
   - `nextcloud_port: 8080` (master container port)
   - `nextcloud_apache_port: 11000` (internal Apache port)
   - Keep existing `nextcloud_data_dir`

### Phase 3: Handlers
1. Create `handlers/main.yml` with restart handler using `docker_compose_v2`

### Phase 4: Refactor Deployment Tasks
1. Refactor `tasks/main.yml`:
   - Add environment file validation
   - Add container status checking
   - Change directory structure to `/data/services/nextcloud/`
   - Use `docker_compose_v2` module instead of shell
   - Add proper file permissions (755 dirs, 644 compose, 640 env)
   - Add handler notifications
   - Add `become: false` to local tasks

### Phase 5: Update Docker Compose Template
1. Update `templates/docker-compose.j2`:
   - Remove deprecated `version: "3.8"`
   - Add `env_file: .env`
   - Make ports configurable with variables
   - Change `restart: always` to `restart: unless-stopped`
   - Keep Nextcloud AIO-specific requirements (container name, volumes)

### Phase 6: Create Update Tasks
1. Create `tasks/update.yml` with:
   - Pull latest image
   - Recreate container
   - Health checking
   - Dangling image cleanup

### Phase 7: Playbook Integration
1. Add setup integration to `site-setup.yml`
2. Add update integration to `maintenance.yml`

### Phase 8: Validation
1. Run syntax checks on all playbooks
2. Verify setup workflow creates environment file

## Expected Compliance Improvement
- **Before:** 6/35 patterns (17%)
- **After:** ~30/35 patterns (86%) - excluding Traefik-specific patterns

## Special Considerations
- Nextcloud AIO container name must remain `nextcloud-aio-mastercontainer`
- Volume name must remain `nextcloud_aio_mastercontainer`
- Docker socket access required for AIO self-orchestration
- No Traefik integration (AIO manages Apache internally)
