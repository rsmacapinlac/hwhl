# Ansible Role Development Patterns

## Overview
This document outlines the standardized patterns for developing Ansible roles in this homelab infrastructure.

## Modern Role Pattern (Recommended)

### Directory Structure
```
roles/{service}/
├── defaults/main.yml         # Default variables (optional)
├── handlers/main.yml         # Service restart handlers
├── tasks/
│   ├── main.yml              # Main deployment tasks
│   ├── setup.yml             # Environment file creation tasks
│   └── update.yml            # Update tasks (optional, for services needing updates)
├── templates/
│   ├── docker-compose.j2     # Docker compose template
│   └── environment.j2        # Environment file template
└── meta/main.yml             # Role dependencies (optional)
```

**File Purposes:**
- `tasks/main.yml` - Primary deployment logic and container management
- `tasks/setup.yml` - One-time setup for environment file creation
- `tasks/update.yml` - Optional update workflow for frequent image updates
- `defaults/main.yml` - Optional default variables (mainly for configurable ports)
- `handlers/main.yml` - Service restart/recreation handlers
- `meta/main.yml` - Optional role dependencies

### Key Components

#### 1. Environment File Management
- Environment files stored in `files/config/{service}/environment`
- Template-based environment file generation using `templates/environment.j2`
- Environment file validation before deployment in `tasks/main.yml`
- Secure file permissions (640) for environment files

#### 2. Setup Integration
- Setup tasks in `tasks/setup.yml` for one-time configuration
- Integration with `site-setup.yml` playbook
- Environment file creation from templates
- Conditional creation (only if file doesn't exist)

#### 3. Deployment Tasks Pattern
```yaml
# Environment file validation
- name: Check if environment file exists
  local_action:
    module: stat
    path: "{{ playbook_dir }}/files/config/{service}/environment"
  register: env_file
  become: false

- name: Fail if environment file doesn't exist
  fail:
    msg: |
      Environment file not found at {{ playbook_dir }}/files/config/{service}/environment
      Please run site-setup.yml first to create the environment file.
  when: not env_file.stat.exists

# Container status checking
- name: Check if {service} container exists
  community.docker.docker_container_info:
    name: {service}
  register: {service}_container
  ignore_errors: true

# Directory creation with proper permissions
- name: Create services folder
  become: true
  file:
    path: /data/services/{service}
    state: directory
    owner: ansible
    group: docker
    mode: '0755'
  when: not {service}_container.container.Status.Running | default(false)

# Environment file deployment
- name: Copy environment configuration
  copy:
    src: "{{ playbook_dir }}/files/config/{service}/environment"
    dest: /data/services/{service}/.env
    owner: ansible
    group: docker
    mode: '0640'
  notify: restart {service}

# Docker Compose deployment
- name: Setup docker compose file for {service}
  template:
    src: docker-compose.j2
    dest: /data/services/{service}/compose.yml
    owner: ansible
    group: docker
    mode: '0644'
  notify: restart {service}

# Container deployment using docker_compose_v2
- name: Run {service} container
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: present
    remove_orphans: false        # Prevent removal of unmanaged containers
  when: not {service}_container.container.Status.Running | default(false)
  notify: restart {service}
```

**Important: DNS CNAME Configuration NOT Required**

The modern pattern **does not** include Pi-hole DNS CNAME configuration tasks. Service discovery is handled entirely through Traefik routing labels in the docker-compose templates.

**Why DNS CNAME tasks are excluded:**
- Traefik provides dynamic service discovery through Docker labels
- DNS routing is configured through Traefik's `Host()` rules
- Adding separate DNS CNAME tasks creates redundant configuration
- Reduces role complexity and maintenance burden

**Legacy roles may have DNS CNAME tasks** - these can be safely removed during migration without affecting service functionality.

#### 4. Configuration Management
- Default variables in `defaults/main.yml`
- Host-specific overrides in inventory files
- Template-based configuration with Jinja2
- Configurable ports and common conflict-prone settings

#### 5. Docker Compose Template Pattern
```yaml
---
services:
  {service}:
    container_name: {service}
    image: {image}
    ports:
      - {{ {service}_port }}:3000  # Configurable port
    env_file:
      - .env                        # Use environment file
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      # Traefik configuration...
    networks:
      - proxy

networks:
  proxy:
    name: proxy
    external: true
```

#### 6. Handler Pattern
```yaml
---
- name: restart {service}
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: restarted           # Use 'restarted' for explicit restarts
    remove_orphans: false      # Prevent removal of unmanaged containers
```

**Alternative Handler Pattern:**
```yaml
- name: restart {service}
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: present
    recreate: always           # Force container recreation
    remove_orphans: false
```

**When to use each:**
- `state: restarted` - Simple service restarts without recreation
- `state: present` with `recreate: always` - Force full container recreation

#### 7. Update Tasks Pattern

For services requiring regular image updates, implement dedicated update tasks in `tasks/update.yml`:

```yaml
---
- name: Update {service} container with latest image
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: present
    pull: always              # Always pull latest image
    recreate: always          # Force container recreation
    remove_orphans: false
  register: compose_update
  ignore_errors: true         # Graceful handling if service unavailable

- name: Wait for {service} container to be running
  community.docker.docker_container_info:
    name: {service}
  register: {service}_status
  until: {service}_status.container.State.Running | default(false)
  retries: 5
  delay: 2
  when: compose_update is succeeded

- name: Display update status
  debug:
    msg: "{Service} has been updated and is running"
  when: compose_update is succeeded

- name: Display skip message when service unavailable
  debug:
    msg: "Skipped {service} update - service unavailable or update failed"
  when: compose_update is failed

- name: Remove dangling {service} images
  command: docker image prune -f
  changed_when: true
  when: compose_update is succeeded
```

**Use cases for update tasks:**
- Services requiring frequent updates (exporters, monitoring tools)
- Integration with automated update playbooks (maintenance.yml)
- Services where DNS or dependencies might be temporarily unavailable

**Integration with maintenance.yml:**
When implementing update tasks, add the service to the maintenance playbook for centralized updates:

```yaml
# maintenance.yml
- name: Update {Service}
  hosts: {service}
  remote_user: ansible
  tasks:
    - name: Run {service} update tasks
      include_tasks: roles/{service}/tasks/update.yml
      when: groups['{service}'] is defined and groups['{service}'] | length > 0
```

This allows running all service updates with a single command:
```bash
ansible-playbook maintenance.yml
```

## Configuration Examples

### Making Ports Configurable
```yaml
# defaults/main.yml
---
semaphore_port: 3000

# Inventory override
semaphore:
  hosts:
    ritchie.int.macapinlac.network:
      ansible_host: 10.1.0.36
      semaphore_port: 3002  # Override for conflict resolution
```

### Environment File Template

**Basic Template Pattern:**
```bash
# templates/environment.j2
# Service Configuration
SERVICE_PORT=3000
SERVICE_PASSWORD=change_this_password

# Database Configuration
POSTGRES_USER=serviceuser
POSTGRES_PASSWORD=change_this_postgres_password
POSTGRES_DB=servicedb

# Additional service-specific variables...
```

**Advanced Template with Jinja2 Defaults:**
```bash
# templates/environment.j2
# Service Configuration with defaults
SERVICE_HOSTNAME={{ service_hostname | default('service.int.domain.local') }}
SERVICE_PORT={{ service_port | default('3000') }}

# Multi-value configuration (comma-separated)
# Useful for monitoring multiple instances
SERVICE_HOSTS={{ service_hosts | default('host1.local,host2.local,host3.local') }}
SERVICE_TOKENS={{ service_tokens | default('changeme,changeme,changeme') }}

# Boolean and conditional values
ENABLE_FEATURE={{ enable_feature | default('true') }}
LOG_LEVEL={{ log_level | default('info') }}

# Timezone from global variables
TZ={{ timezone | default('America/Vancouver') }}
```

**Benefits of Jinja2 defaults:**
- Provides sensible defaults while allowing override from inventory
- Self-documenting configuration expectations
- Enables reusable roles across different environments
- Simplifies initial setup process

## Service Type Variations

Different service types require different configuration patterns:

### User-Facing Services (with Traefik)
Services accessed by users through reverse proxy:
```yaml
# templates/docker-compose.j2
services:
  {service}:
    container_name: {service}
    image: {image}
    ports:
      - {{ {service}_port }}:3000
    env_file:
      - .env
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      # HTTP router with redirect to HTTPS
      - "traefik.http.routers.{service}.entrypoints=http"
      - "traefik.http.routers.{service}.rule=Host(`{service}.{{ ansible_facts[\"hostname\"] }}.{{ homelab_domain }}`)"
      - "traefik.http.middlewares.{service}-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.{service}.middlewares={service}-https-redirect"
      # HTTPS router
      - "traefik.http.routers.{service}-secure.entrypoints=https"
      - "traefik.http.routers.{service}-secure.rule=Host(`{service}.{{ ansible_facts[\"hostname\"] }}.{{ homelab_domain }}`)"
      - "traefik.http.routers.{service}-secure.tls=true"
      - "traefik.http.routers.{service}-secure.service={service}"
      - "traefik.http.services.{service}.loadbalancer.server.port=3000"
      - "traefik.docker.network=proxy"
    networks:
      - proxy

networks:
  proxy:
    name: proxy
    external: true
```

**Characteristics:**
- Traefik labels for routing and SSL
- HTTP to HTTPS automatic redirect
- Connected to external proxy network
- Watchtower enabled for updates
- Configurable ports for conflict resolution
- Uses modern `ansible_facts["hostname"]` syntax

### Monitoring/Backend Services (No Traefik)
Services for internal monitoring or metrics export:
```yaml
# templates/docker-compose.j2
services:
  {service}:
    container_name: {service}
    image: {image}
    ports:
      - "9617:9617"          # Direct port exposure
    env_file: .env
    environment:
      TZ: '{{ timezone }}'
    restart: unless-stopped
```

**Characteristics:**
- No Traefik labels (not user-facing)
- No network configuration (default bridge)
- Direct port exposure for scraping
- Minimal configuration for reliability

### Database Services
Services requiring persistent storage and backup:
```yaml
services:
  {service}-db:
    container_name: {service}-db
    image: postgres:latest
    volumes:
      - {service}-data:/var/lib/postgresql/data
    env_file:
      - .env
    restart: unless-stopped
    networks:
      - {service}-internal

volumes:
  {service}-data:
    driver: local
```

**Characteristics:**
- Named volumes for persistence
- Internal networks for isolation
- No direct port exposure
- Backup considerations

## Integration with Site Playbooks

### site-setup.yml Integration
```yaml
- name: "Setup {Service}"
  hosts: {service}
  connection: local
  tasks:
    - name: "Run {Service} setup if group exists"
      include_tasks: roles/{service}/tasks/setup.yml
      run_once: true
      when: groups['{service}'] is defined and groups['{service}'] | length > 0
```

### site.yml Integration
```yaml
- hosts: "{service}"
  remote_user: ansible
  roles:
    - role: {service}
```

## Common Pitfalls and Solutions

### 1. Privilege Escalation with Local Tasks

**Problem:** Tasks delegated to localhost (using `delegate_to: 127.0.0.1` or `local_action`) inherit privilege escalation from the parent play, causing sudo password prompts on your local machine.

**Symptom:**
```
[ERROR]: Task failed: Duplicate become password prompt encountered waiting for become success.
[sudo via ansible, key=...] password:
```

**Solution:** Explicitly disable privilege escalation for local tasks:
```yaml
- name: Check if environment file exists
  local_action:
    module: stat
    path: "{{ playbook_dir }}/files/config/{service}/environment"
  register: env_file
  become: false  # ← Critical for local tasks

- name: Create config directory locally
  file:
    path: "{{ playbook_dir }}/files/config/{service}"
    state: directory
  delegate_to: 127.0.0.1
  become: false  # ← Critical for delegated local tasks
```

**Why:** Local tasks creating files in your workspace don't need sudo privileges. Always add `become: false` to tasks that run on localhost.

### 2. Overly Aggressive Conditional Deployment

**Problem:** Adding conditionals to the docker-compose template deployment prevents configuration updates when containers are already running.

**Bad Pattern:**
```yaml
- name: Setup docker compose file for {service}
  template:
    src: docker-compose.j2
    dest: /data/services/{service}/compose.yml
  when: not {service}_container.container.State.Running | default(false)  # ❌ Prevents updates!
  notify: restart {service}
```

**Symptom:** Running the playbook doesn't update the compose file on the server even though the template has changed.

**Good Pattern:**
```yaml
- name: Setup docker compose file for {service}
  template:
    src: docker-compose.j2
    dest: /data/services/{service}/compose.yml
  notify: restart {service}  # ✅ Always deploys, handler only runs if changed
```

**Why:** The `template` module is idempotent and only reports `changed` if the file content actually differs. Let Ansible's change detection trigger the handler, not manual conditionals.

**When to use conditionals:**
- Directory creation (only needed for first deployment)
- Initial container deployment (to avoid unnecessary recreation)

**When NOT to use conditionals:**
- Template deployment (let Ansible detect changes)
- Environment file deployment (should always sync)

### 3. Incorrect Traefik Label Patterns

**Problem:** Using simplified Traefik patterns that don't match the infrastructure's standard configuration.

**Bad Pattern (No HTTP Support):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{service}.entrypoints=websecure"  # ❌ Only HTTPS, HTTP fails
  - "traefik.http.routers.{service}.rule=Host(`{service}.domain`)"
  - "traefik.http.routers.{service}.tls.certresolver=cloudflare"
```

**Symptom:** Service only accessible via HTTPS, HTTP requests fail or timeout.

**Good Pattern (HTTP to HTTPS Redirect):**
```yaml
labels:
  - "traefik.enable=true"
  # HTTP router with redirect
  - "traefik.http.routers.{service}.entrypoints=http"
  - "traefik.http.routers.{service}.rule=Host(`{service}.{{ ansible_facts[\"hostname\"] }}.{{ homelab_domain }}`)"
  - "traefik.http.middlewares.{service}-https-redirect.redirectscheme.scheme=https"
  - "traefik.http.routers.{service}.middlewares={service}-https-redirect"
  # HTTPS router
  - "traefik.http.routers.{service}-secure.entrypoints=https"
  - "traefik.http.routers.{service}-secure.rule=Host(`{service}.{{ ansible_facts[\"hostname\"] }}.{{ homelab_domain }}`)"
  - "traefik.http.routers.{service}-secure.tls=true"
  - "traefik.http.routers.{service}-secure.service={service}"
  - "traefik.http.services.{service}.loadbalancer.server.port=8080"
  - "traefik.docker.network=proxy"  # ✅ Important for multi-network setups
```

**Why:** This pattern creates two routers:
1. HTTP router that redirects all traffic to HTTPS
2. HTTPS router that serves the actual service

**Reference Implementation:** Compare with working roles like `kavita`, `semaphore`, or `jellyfin`.

### 4. Ansible Facts Deprecation

**Problem:** Using old-style fact variables that will be removed in Ansible 2.24+.

**Deprecated Pattern:**
```yaml
environment:
  - PUBLISHED_URL=service.{{ ansible_hostname }}.{{ homelab_domain }}  # ❌ Deprecated
```

**Deprecation Warning:**
```
[DEPRECATION WARNING]: INJECT_FACTS_AS_VARS default to `True` is deprecated,
top-level facts will not be auto injected after the change.
```

**Modern Pattern:**
```yaml
environment:
  - PUBLISHED_URL=service.{{ ansible_facts["hostname"] }}.{{ homelab_domain }}  # ✅ Future-proof
```

**Common Replacements:**
- `ansible_hostname` → `ansible_facts["hostname"]`
- `ansible_os_family` → `ansible_facts["os_family"]`
- `ansible_distribution` → `ansible_facts["distribution"]`

**Why:** Ansible is moving to namespace all facts under `ansible_facts` to avoid variable naming conflicts.

### 5. Environment Variables in Wrong Location

**Problem:** Mixing static and dynamic environment variables incorrectly.

**When to use `env_file: .env`:**
- Static configuration (API keys, passwords, user IDs)
- Shared across hosts
- Managed via `templates/environment.j2`

**When to use inline `environment:`:**
- Dynamic per-host values (hostnames, URLs)
- Values that change per deployment
- Values using Ansible variables

**Good Pattern:**
```yaml
services:
  jellyfin:
    env_file:
      - .env  # Static: PUID, PGID, TZ
    environment:
      - JELLYFIN_PublishedServerUrl=jellyfin.{{ ansible_facts["hostname"] }}.{{ homelab_domain }}  # Dynamic per host
```

## Best Practices

1. **Always validate environment files exist** before deployment
2. **Use proper file permissions** (755 for directories, 644 for compose files, 640 for .env files)
3. **Check container status** before attempting deployment
4. **Use handlers** for service restarts to avoid unnecessary recreation
5. **Make conflicting settings configurable** (especially ports)
6. **Follow consistent naming** conventions across roles
7. **Use conditional deployment sparingly** - only for directory creation and initial container deployment, not for template deployment
8. **Implement proper error handling** with meaningful error messages
9. **Include `remove_orphans: false`** in docker_compose_v2 calls to prevent accidental container removal
10. **Use Jinja2 defaults** in environment templates for better flexibility
11. **Choose appropriate service patterns** based on service type (user-facing vs monitoring vs database)
12. **Implement update tasks** for services requiring frequent updates
13. **Add container health checks** when implementing update workflows
14. **Always add `become: false`** to tasks using `local_action` or `delegate_to: 127.0.0.1`
15. **Use modern `ansible_facts["fact_name"]` syntax** instead of deprecated `ansible_fact_name` variables
16. **Compare Traefik labels** with working roles (kavita, semaphore, jellyfin) before deploying new services
17. **Do NOT include DNS CNAME configuration tasks** - Traefik handles service discovery through Docker labels

## Reference Implementations

### Fully Compliant Roles (Audited & Migrated)

- **jellyfin** - Complete modern pattern implementation (migrated Nov 2024)
  - 100% compliance (35/35 patterns)
  - User-facing media server with Traefik
  - Multi-host deployment (ritchie and media)
  - Reference: See "Migration Case Study" below

### Other Notable Implementations

These roles implement various modern patterns but have not been formally audited:

- **pihole-exporter** - Monitoring service with update tasks and Jinja2 defaults
- **semaphore** - User-facing service with Traefik integration
- **immich** - User-facing service with setup integration
- **kasm** - Environment file management example
- **kimai** - Template-based configuration
- **prometheus** - Advanced configuration with custom templates

> **Note:** To audit a role against these patterns, use `/audit-role {role-name}` slash command.

### Migration Case Study: Jellyfin

**Legacy State (Pre-Migration):**
- Shell-based deployment (`docker compose -f jellyfin.yml up -d`)
- No environment file management
- Flat file structure (`/data/services/jellyfin.yml`)
- Hardcoded configuration in compose template
- No setup or update integration
- Old Ansible facts syntax (`ansible_hostname`)
- Incomplete Traefik labels (no HTTP redirect)

**Modern State (Post-Migration):**
- `docker_compose_v2` module-based deployment
- Environment file template with Jinja2 defaults
- Service-specific directory (`/data/services/jellyfin/compose.yml`)
- Configuration separated into environment file and compose template
- Full site-setup.yml and maintenance.yml integration
- Modern facts syntax (`ansible_facts["hostname"]`)
- Complete Traefik HTTP-to-HTTPS redirect pattern
- Configurable ports via defaults

**Compliance:** 100% (35/35 patterns implemented)

**Key Lessons Learned:**
1. Don't over-use conditionals - let Ansible's change detection work
2. Always add `become: false` to local tasks
3. Match Traefik patterns with existing working roles
4. Separate static (env_file) from dynamic (environment) configuration
5. Use modern `ansible_facts` to avoid future deprecation
