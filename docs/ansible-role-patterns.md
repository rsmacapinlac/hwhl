# Ansible Role Development Patterns

## Overview
This document outlines the standardized patterns for developing Ansible roles in this homelab infrastructure.

## Modern Role Pattern (Recommended)

### Directory Structure
```
roles/{service}/
├── defaults/main.yml         # Default variables
├── handlers/main.yml         # Service restart handlers
├── tasks/
│   ├── main.yml              # Main deployment tasks
│   └── setup.yml             # Environment file creation tasks
├── templates/
│   ├── docker-compose.j2     # Docker compose template
│   └── environment.j2        # Environment file template
└── meta/main.yml             # Role dependencies
```

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

# Docker Compose deployment
- name: Setup docker compose file for {service}
  template:
    src: docker-compose.j2
    dest: /data/services/{service}/compose.yml
    owner: ansible
    group: docker
    mode: '0644'

# Container deployment using docker_compose_v2
- name: Run {service} container
  community.docker.docker_compose_v2:
    project_src: /data/services/{service}
    files:
      - compose.yml
    state: present
  when: 
    - not {service}_container.container.Status.Running | default(false)
    - compose_file.stat.exists
  notify: restart {service}
```

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
    state: present
    recreate: always
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

## Best Practices

1. **Always validate environment files exist** before deployment
2. **Use proper file permissions** (755 for directories, 644 for compose files, 640 for .env files)
3. **Check container status** before attempting deployment
4. **Use handlers** for service restarts to avoid unnecessary recreation
5. **Make conflicting settings configurable** (especially ports)
6. **Follow consistent naming** conventions across roles
7. **Use conditional deployment** to avoid unnecessary container recreation
8. **Implement proper error handling** with meaningful error messages

## Examples of Modern Pattern Implementation

- **semaphore**: Recently upgraded role demonstrating full modern pattern
- **kasm**: Environment file management and configurable deployment
- **immich**: Complete modern pattern with setup integration
- **kimai**: Template-based configuration with validation
- **prometheus**: Advanced configuration with custom templates
