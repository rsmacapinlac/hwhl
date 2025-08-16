# Ansible Role Migration Guide

## Overview
This document provides guidance for migrating legacy Ansible roles to the modern standardized pattern used in this homelab infrastructure.

## Legacy Pattern Issues

### Common Problems with Legacy Roles
1. **Hardcoded variables in templates** - No separation of configuration
2. **Shell command deployment** - Using `shell` module instead of proper Docker modules
3. **No environment file separation** - Variables embedded directly in docker-compose templates
4. **Missing validation** - No checks for required files or container status
5. **Incomplete role structure** - Missing `defaults/`, `handlers/`, or `setup.yml`
6. **No setup integration** - Not integrated with `site-setup.yml` workflow

### Example Legacy Pattern (Before Migration)
```yaml
# Legacy tasks/main.yml
- name: Setup docker compose file
  template:
    src: docker-compose.j2
    dest: /data/services/service/docker-compose.yml

- name: Run container
  shell:
    cmd: "docker compose -f /data/services/service/docker-compose.yml up -d"
```

```yaml
# Legacy docker-compose.j2 (hardcoded variables)
services:
  service:
    environment:
      SERVICE_PASSWORD: '{{ service_password }}'
      DB_PASSWORD: '{{ postgres_password }}'
      SECRET_KEY: {{ service_secret }}
```

## Migration Steps

### Step 1: Create Missing Directory Structure
```bash
# Create missing directories
mkdir -p roles/{service}/defaults
mkdir -p roles/{service}/handlers
mkdir -p roles/{service}/tasks
```

### Step 2: Extract Variables to Environment Template
```yaml
# Create templates/environment.j2
# Service Configuration
SERVICE_PASSWORD=change_this_password
DB_PASSWORD=change_this_postgres_password
SECRET_KEY=change_this_secret_key

# Additional service-specific variables...
```

### Step 3: Update Docker Compose Template
```yaml
# Update templates/docker-compose.j2
---
services:
  service:
    container_name: service
    image: service:latest
    env_file:
      - .env  # Use environment file instead of hardcoded vars
    ports:
      - {{ service_port | default(3000) }}:3000
    restart: unless-stopped
```

### Step 4: Create Setup Tasks
```yaml
# Create tasks/setup.yml
---
- name: Create config directory for {service}
  local_action:
    module: file
    path: "{{ playbook_dir }}/files/config/{service}"
    state: directory
    mode: '0755'

- name: Check if {service} environment file exists
  local_action:
    module: stat
    path: "{{ playbook_dir }}/files/config/{service}/environment"
  register: env_file_stat

- name: Create {service} environment file
  local_action:
    module: template
    src: "{{ playbook_dir }}/roles/{service}/templates/environment.j2"
    dest: "{{ playbook_dir }}/files/config/{service}/environment"
  when: not env_file_stat.stat.exists

- name: Display setup instructions
  debug:
    msg: |
      {% if env_file_stat.stat.exists %}
      Environment file already exists at {{ playbook_dir }}/files/config/{service}/environment
      {% else %}
      Environment file created at {{ playbook_dir }}/files/config/{service}/environment
      Please review and customize before running site.yml
      {% endif %}
```

### Step 5: Update Main Tasks for Modern Deployment
```yaml
# Update tasks/main.yml
- name: Check if environment file exists
  local_action:
    module: stat
    path: "{{ playbook_dir }}/files/config/{service}/environment"
  register: env_file

- name: Fail if environment file doesn't exist
  fail:
    msg: |
      Environment file not found. Please run site-setup.yml first.
  when: not env_file.stat.exists

- name: Check if {service} container exists
  community.docker.docker_container_info:
    name: {service}
  register: {service}_container
  ignore_errors: true

- name: Copy environment configuration
  copy:
    src: "{{ playbook_dir }}/files/config/{service}/environment"
    dest: /data/services/{service}/.env
    owner: ansible
    group: docker
    mode: '0640'

- name: Run {service} container
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: present
  when: 
    - not {service}_container.container.Status.Running | default(false)
  notify: restart {service}
```

### Step 6: Create Proper Handlers
```yaml
# Create handlers/main.yml
---
- name: restart {service}
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: present
    recreate: always
```

### Step 7: Add Default Variables
```yaml
# Create defaults/main.yml
---
{service}_port: 3000  # Default port, can be overridden
```

### Step 8: Add to Site-Setup Integration
```yaml
# Add to site-setup.yml
- name: "Setup {Service}"
  hosts: {service}
  connection: local
  tasks:
    - name: "Run {Service} setup if group exists"
      include_tasks: roles/{service}/tasks/setup.yml
      run_once: true
      when: groups['{service}'] is defined and groups['{service}'] | length > 0
```

## Real Migration Example: Semaphore Role

### Before Migration
```yaml
# Old tasks/main.yml (simplified)
- name: Setup docker compose file for Semaphore stack
  template:
    src: docker-compose.j2
    dest: /data/services/semaphore/docker-compose.yml

- name: Run container
  shell:
    cmd: "docker compose -f /data/services/semaphore/docker-compose.yml up -d"
```

```yaml
# Old docker-compose.j2 (hardcoded variables)
environment:
  POSTGRES_PASSWORD: '{{ postgres_password }}'
  SEMAPHORE_ADMIN_PASSWORD: '{{ semaphore_admin_password }}'
  SEMAPHORE_ACCESS_KEY_ENCRYPTION: {{ semaphore_access_key_encryption }}
```

### After Migration
```yaml
# New structure created:
roles/semaphore/
├── defaults/main.yml           # semaphore_port: 3000
├── handlers/main.yml           # restart semaphore handler
├── tasks/
│   ├── main.yml               # Modern deployment pattern
│   └── setup.yml              # Environment file creation
├── templates/
│   ├── docker-compose.j2      # Uses env_file: - .env
│   └── environment.j2         # All variables externalized
└── meta/main.yml              # Dependencies
```

```bash
# New environment.j2
POSTGRES_PASSWORD=change_this_postgres_password
SEMAPHORE_ADMIN_PASSWORD=change_this_admin_password
SEMAPHORE_ACCESS_KEY_ENCRYPTION=change_this_encryption_key
```

## Testing Migration

### 1. Test Environment File Creation
```bash
ansible-playbook site-setup.yml --limit {service}
```

### 2. Verify Environment File Contents
```bash
cat files/config/{service}/environment
```

### 3. Test Deployment
```bash
ansible-playbook site.yml --limit {service}
```

### 4. Verify Container Status
```bash
ansible {service} -m shell -a "docker ps | grep {service}"
```

## Migration Checklist

- [ ] Create missing directory structure
- [ ] Extract variables to `templates/environment.j2`
- [ ] Update `docker-compose.j2` to use `env_file`
- [ ] Create `tasks/setup.yml`
- [ ] Update `tasks/main.yml` with modern pattern
- [ ] Create `handlers/main.yml`
- [ ] Add default variables in `defaults/main.yml`
- [ ] Add to `site-setup.yml` integration
- [ ] Test environment file creation
- [ ] Test deployment
- [ ] Verify container functionality
- [ ] Update inventory if needed (add configurable variables)

## Common Migration Pitfalls

1. **Forgetting to update site-setup.yml** - Environment files won't be created
2. **Incorrect file permissions** - Use 640 for .env files, 644 for compose files
3. **Missing environment file validation** - Deployment will fail silently
4. **Not testing the migration** - Always test both setup and deployment phases
5. **Hardcoding new conflicts** - Make ports and common settings configurable
6. **Breaking existing deployments** - Test on non-production environments first