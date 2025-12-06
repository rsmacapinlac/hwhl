---
description: "Create and onboard a new service role using the modern Ansible role pattern"
allowed-tools: ["Write", "Edit", "Read", "LS", "Bash", "Grep", "TodoWrite"]
---

# Onboard New Service

Create a new Ansible role for service: **$ARGUMENTS**

You will create a complete Ansible role following the modern pattern documented in `docs/ansible-role-patterns.md`.

## Prerequisites Check:

**BEFORE starting any implementation, you MUST:**

1. **Read the Pattern Documentation**
   - Always read `docs/ansible-role-patterns.md` to understand current patterns
   - Ensure you follow the exact modern pattern structure

2. **Verify Official Docker Compose Support**
   - Search for official documentation of the service
   - Verify the service provides official docker-compose examples/documentation
   - Check the official project repository for docker-compose.yml files
   - **STOP and refuse to proceed if:**
     - No official docker-compose documentation exists
     - Only community/unofficial docker-compose examples are available
     - The service doesn't officially support docker-compose deployment

3. **Document Verification Sources**
   - Provide links to official docker-compose documentation found
   - Note the official image name and supported tags

## Tasks to Complete:

1. **Create Role Directory Structure**
   - Create `roles/$ARGUMENTS/` with all required subdirectories
   - `defaults/`, `handlers/`, `tasks/`, `templates/`, `meta/`

2. **Create Core Files**
   - `defaults/main.yml` - Default variables (include configurable port)
   - `meta/main.yml` - Role dependencies (docker, cname if needed)
   - `handlers/main.yml` - Restart handler using docker_compose_v2
   - `tasks/main.yml` - Main deployment tasks following modern pattern
   - `tasks/setup.yml` - Environment file creation tasks
   - `tasks/update.yml` - Update tasks for maintenance playbook integration

3. **Create Templates**
   - `templates/docker-compose.j2` - Docker compose template using env_file
   - `templates/environment.j2` - Environment variables template with placeholders

4. **Integration**
   - Add service setup to `site-setup.yml`
   - Add service deployment to `site.yml`
   - Add service update to `maintenance.yml`
   - Create inventory entry example

5. **Documentation**
   - Create basic README or service-specific documentation if needed

## Requirements:
- **ALWAYS start by reading `docs/ansible-role-patterns.md`**
- **MUST verify official docker-compose support before proceeding**
- Follow the exact pattern from `docs/ansible-role-patterns.md`
- Include environment file validation
- Use docker_compose_v2 module for deployment
- Make ports configurable to avoid conflicts
- Include proper file permissions (755 for dirs, 644 for compose, 640 for .env)
- Use handlers for service restarts
- Include update tasks following the standard pattern (with pull: always, recreate: always)
- Add service to maintenance.yml for centralized updates
- Include container status checking before deployment

## Implementation Process:

1. **Start with Prerequisites**
   - Read `docs/ansible-role-patterns.md`
   - Verify official docker-compose support
   - Document findings and links

2. **If Prerequisites Pass, Ask for:**
   - Docker image and version to use (must be official)
   - Default port number
   - Any special environment variables needed
   - Any volume mounts or special configuration
   - Which inventory file/host should run this service

3. **Then proceed with implementation following the modern pattern exactly**

**CRITICAL:** If no official docker-compose support is found, stop immediately and explain why the service cannot be onboarded using this pattern.