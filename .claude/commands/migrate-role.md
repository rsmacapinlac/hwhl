---
description: "Migrate an existing Ansible role to modern patterns based on audit findings"
allowed-tools: ["Read", "Glob", "Grep", "TodoWrite", "AskUserQuestion", "Edit", "Write", "Bash", "ExitPlanMode"]
---

# Migrate Ansible Role to Modern Patterns

Migrate the **$ARGUMENTS** role to comply with modern Ansible role patterns documented in `docs/ansible-role-patterns.md`.

## Prerequisites Check

**IMPORTANT:** Before proceeding with migration:

1. **Run audit first** (highly recommended):
   ```bash
   /audit-role $ARGUMENTS
   ```
   This provides baseline understanding of current state and compliance gaps.

2. **Ask user to confirm**:
   - Have they reviewed the audit findings?
   - Do they want to proceed with migration?
   - What is the service type? (user-facing / monitoring / database / other)

If user hasn't run audit yet, offer to run it now before continuing.

## Migration Planning Process

### Step 1: Analyze Current State

Read and analyze the existing role at `roles/$ARGUMENTS/`:

**Required Analysis:**
- [ ] Read existing `tasks/main.yml` - understand current deployment method
- [ ] Read existing `templates/docker-compose.j2` - identify service type and configuration
- [ ] Check for `handlers/main.yml` - see if handlers exist
- [ ] Check for `defaults/main.yml` - see if defaults exist
- [ ] Check for `tasks/setup.yml` - see if setup tasks exist
- [ ] Check for `tasks/update.yml` - see if update tasks exist
- [ ] Check for `templates/environment.j2` - see if environment template exists
- [ ] Check `inventory/*.yml` for service configuration
- [ ] Check `site.yml` for role integration and tags
- [ ] Check `site-setup.yml` for setup integration
- [ ] Check `maintenance.yml` for update integration

### Step 2: Identify Service Type

Based on docker-compose.j2 analysis, determine:

**User-facing Service:**
- Has Traefik labels
- Connected to proxy network
- Exposed via reverse proxy
- Example: jellyfin, audiobookshelf, semaphore

**Monitoring/Backend Service:**
- No Traefik labels
- Direct port exposure
- Internal metrics/monitoring
- Example: pihole-exporter, prometheus exporters

**Database Service:**
- Named volumes for persistence
- Internal networks
- No direct external access
- Example: postgres, redis

### Step 3: Create Migration Plan

Based on analysis, create a phased migration plan:

**Phase 1: Environment File Management** (if missing)
- Create `templates/environment.j2`
- Create `tasks/setup.yml`
- Create `defaults/main.yml`
- Add environment file validation to `tasks/main.yml`

**Phase 2: Refactor Deployment Tasks** (if using shell/legacy patterns)
- Update `tasks/main.yml` to use docker_compose_v2 module
- Add container status checking
- **CRITICAL:** Directory creation and compose file deployment should NOT be conditional
- Fix file permissions (640 for .env, 644 for compose.yml)
- Add environment file deployment
- Update template deployment to use compose.yml
- Fix any deprecated Ansible facts (ansible_hostname → ansible_facts["hostname"])
- Add `become: false` to local tasks
- Fix task naming issues
- **Only the initial container start should be conditional** (when not already running)

**Phase 3: Update Templates** (if needed)
- Update `templates/docker-compose.j2`:
  - Add `env_file: .env` reference
  - Make ports configurable using variables
  - Update to use `ansible_facts["hostname"]`
  - Ensure Traefik labels are complete (if user-facing)
  - Verify network configuration

**Phase 4: Add Handlers** (if missing)
- Create `handlers/main.yml`
- Use `docker_compose_v2` with `state: present` and `recreate: always`
- Include `remove_orphans: false`

**Phase 5: Integration** (if missing)
- Ensure tags are added to role in `site.yml` (role level tags for better targeting)
- Add setup integration to `site-setup.yml`
- Add update tasks to `tasks/update.yml` (optional but recommended)
- Add maintenance integration to `maintenance.yml` (if update tasks added)

**Phase 6: Testing & Validation**
- Syntax check all playbooks
- Run setup workflow
- Test deployment with dry-run
- Verify service accessibility

### Step 4: Present Plan for Approval

Use **ExitPlanMode** to present the complete migration plan with:
- Current state summary
- List of files to create
- List of files to modify
- Step-by-step migration phases
- Expected compliance improvement (X% → 100%)
- Testing strategy

**IMPORTANT:** Do NOT proceed with any changes until user approves the plan.

## Migration Execution (After Plan Approval)

Once the user approves the plan via ExitPlanMode, proceed with execution:

### Use TodoWrite to Track Progress

Create todo items for each phase:
1. Create environment file template
2. Create setup tasks
3. Create defaults file
4. Create handlers file
5. Refactor main.yml deployment tasks
6. Update docker-compose.j2 template
7. Add tags to site.yml
8. Add setup integration to site-setup.yml
9. Create update tasks (optional)
10. Add maintenance integration (optional)
11. Test deployment

Mark each todo as in_progress → completed as you work through them.

### Execution Guidelines

**When Creating Files:**
1. **Reference existing implementations** - Read similar roles (jellyfin, semaphore, pihole-exporter) for patterns
2. **Use proper file structure** - Follow documented patterns exactly
3. **Set correct permissions** - Templates should be 644, environment files 640
4. **Use relative paths** - In setup.yml, use `../templates/environment.j2` for template source

**When Modifying Files:**
1. **Read before editing** - Always read the full file first
2. **Preserve working patterns** - Don't break existing functionality
3. **Update incrementally** - Make focused changes, one pattern at a time
4. **Test syntax** - Run ansible-playbook --syntax-check after changes
5. **CRITICAL for main.yml:** Never add conditionals to directory creation or compose file deployment
   - Only the initial container start should be conditional
   - Handlers need these files to exist or they will fail with "Cannot find Compose file"

**When Updating Templates:**
1. **Preserve dynamic patterns** - Keep Jinja2 loops for volumes, conditionals, etc.
2. **Update facts syntax** - Replace all `ansible_hostname` with `ansible_facts["hostname"]`
3. **Make ports configurable** - Replace hardcoded ports with `{{ service_port }}` variables
4. **Verify Traefik labels** - Ensure complete HTTP→HTTPS redirect pattern for user-facing services

### Common Migration Patterns

**Creating Environment Template:**
```jinja
# Service Environment Configuration

# User/Group Configuration
PUID={{ service_puid | default('1001') }}
PGID={{ service_pgid | default('1001') }}

# Timezone
TZ={{ timezone | default('America/Vancouver') }}

# Add service-specific variables as needed
```

**Creating Setup Tasks:**
```yaml
---
# Setup tasks for environment file creation
# Run via: ansible-playbook site-setup.yml

- name: Create service config directory locally
  file:
    path: "{{ playbook_dir }}/files/config/$ARGUMENTS"
    state: directory
    mode: '0755'
  delegate_to: 127.0.0.1
  become: false

- name: Check if environment file already exists
  stat:
    path: "{{ playbook_dir }}/files/config/$ARGUMENTS/environment"
  register: service_env_file
  delegate_to: 127.0.0.1
  become: false

- name: Create environment file from template
  template:
    src: ../templates/environment.j2  # Note: relative path needed!
    dest: "{{ playbook_dir }}/files/config/$ARGUMENTS/environment"
    mode: '0640'
  when: not service_env_file.stat.exists
  delegate_to: 127.0.0.1
  become: false

- name: Display setup instructions
  debug:
    msg: |
      Environment file created at: {{ playbook_dir }}/files/config/$ARGUMENTS/environment

      Please review and update configuration as needed.
      After configuration, deploy with: ansible-playbook site.yml --limit $ARGUMENTS
  when: not service_env_file.stat.exists
  delegate_to: 127.0.0.1
  become: false
```

**Creating Handlers:**
```yaml
---
- name: restart $ARGUMENTS
  community.docker.docker_compose_v2:
    project_src: /data/services/$ARGUMENTS
    files:
      - compose.yml
    state: present
    recreate: always
    remove_orphans: false
```

**Creating main.yml Deployment Tasks (CORRECT PATTERN):**
```yaml
---
# Environment file validation
- name: Check if environment file exists
  local_action:
    module: stat
    path: "{{ playbook_dir }}/files/config/$ARGUMENTS/environment"
  register: env_file

- name: Fail if environment file doesn't exist
  fail:
    msg: |
      Environment file not found at {{ playbook_dir }}/files/config/$ARGUMENTS/environment
      Please run site-setup.yml first to create the environment file.
  when: not env_file.stat.exists

# Container status check
- name: Check if $ARGUMENTS container exists
  community.docker.docker_container_info:
    name: $ARGUMENTS
  register: service_container
  ignore_errors: true

# IMPORTANT: NO CONDITIONALS on directory/compose deployment!
- name: Create services folder
  become: true
  ansible.builtin.file:
    path: /data/services/$ARGUMENTS
    state: directory
    owner: ansible
    group: docker
    mode: '0755'

# IMPORTANT: NO CONDITIONAL - must always deploy for handlers to work!
- name: Setup docker compose file for $ARGUMENTS
  template:
    src: docker-compose.j2
    dest: /data/services/$ARGUMENTS/compose.yml
    owner: ansible
    group: docker
    mode: '0644'
  notify: restart $ARGUMENTS

# Environment file - triggers handler when changed
- name: Copy environment configuration
  copy:
    src: "{{ playbook_dir }}/files/config/$ARGUMENTS/environment"
    dest: /data/services/$ARGUMENTS/.env
    owner: ansible
    group: docker
    mode: '0640'
  notify: restart $ARGUMENTS

# ONLY this task should be conditional!
- name: Run $ARGUMENTS container
  community.docker.docker_compose_v2:
    project_src: /data/services/$ARGUMENTS
    files:
      - compose.yml
    state: present
    remove_orphans: false
  when: not service_container.container.State.Running | default(false)
  notify: restart $ARGUMENTS
```

**Creating Update Tasks:**
```yaml
---
# Update tasks for service
# Pulls latest image and recreates container
# Run via: ansible-playbook maintenance.yml

- name: Update $ARGUMENTS container with latest image
  community.docker.docker_compose_v2:
    project_src: /data/services/$ARGUMENTS
    files:
      - compose.yml
    state: present
    pull: always
    recreate: always
    remove_orphans: false
  register: compose_update
  ignore_errors: true

- name: Wait for $ARGUMENTS container to be running
  community.docker.docker_container_info:
    name: $ARGUMENTS
  register: service_status
  until: service_status.container.State.Running | default(false)
  retries: 5
  delay: 2
  when: compose_update is succeeded

- name: Display update status
  debug:
    msg: "$ARGUMENTS has been updated and is running"
  when: compose_update is succeeded

- name: Display skip message when service unavailable
  debug:
    msg: "Skipped $ARGUMENTS update - service unavailable or update failed"
  when: compose_update is failed

- name: Remove dangling images
  command: docker image prune -f
  changed_when: true
  when: compose_update is succeeded
```

**Adding Tags to site.yml:**
Ensure tags are added at the role level in `site.yml` for better playbook targeting:
```yaml
- hosts: "$ARGUMENTS"
  remote_user: ansible
  roles:
    - role: $ARGUMENTS
      tags:
        - $ARGUMENTS
```

This allows running: `ansible-playbook site.yml --tags $ARGUMENTS`

### Post-Migration Validation

After all changes are complete:

1. **Syntax Validation:**
   ```bash
   ansible-playbook site.yml --syntax-check
   ansible-playbook site-setup.yml --syntax-check
   ansible-playbook maintenance.yml --syntax-check
   ```

2. **Setup Workflow Test:**
   ```bash
   ansible-playbook site-setup.yml --limit $ARGUMENTS
   ```
   Verify environment file is created correctly.

3. **Deployment Test:**
   ```bash
   # Dry run first
   ansible-playbook site.yml --limit $ARGUMENTS --check

   # Actual deployment (optional - ask user first)
   ansible-playbook site.yml --limit $ARGUMENTS
   ```

4. **Service Verification:**
   - Check container is running
   - Verify Traefik routing (if user-facing)
   - Test service accessibility

### Report Results

At the end, provide a summary:

```
# Migration Complete: $ARGUMENTS

## Files Created
- roles/$ARGUMENTS/templates/environment.j2
- roles/$ARGUMENTS/tasks/setup.yml
- roles/$ARGUMENTS/defaults/main.yml
- roles/$ARGUMENTS/handlers/main.yml
- roles/$ARGUMENTS/tasks/update.yml (optional)

## Files Modified
- roles/$ARGUMENTS/tasks/main.yml
- roles/$ARGUMENTS/templates/docker-compose.j2
- site-setup.yml
- maintenance.yml (optional)

## Compliance Improvement
Before: X/35 patterns (X%)
After: 35/35 patterns (100%)

## Validation Results
✅ Syntax checks passed
✅ Setup workflow tested
✅ Deployment successful (or ready to deploy)

## Next Steps
1. Review generated environment file: files/config/$ARGUMENTS/environment
2. Configure service-specific variables if needed
3. Deploy with: ansible-playbook site.yml --limit $ARGUMENTS
```

## Safety Guidelines

**Always:**
- ✅ Read files before editing
- ✅ Use ExitPlanMode before making changes
- ✅ Track progress with TodoWrite
- ✅ Validate syntax after changes
- ✅ Reference existing implementations
- ✅ Preserve working functionality
- ✅ Deploy directory and compose file unconditionally in main.yml

**Never:**
- ❌ Make changes without a plan
- ❌ Skip syntax validation
- ❌ Modify files without reading them first
- ❌ Remove working patterns
- ❌ Deploy without user confirmation
- ❌ Add conditionals to compose file deployment (breaks handlers!)

## Reference Implementations

When creating new files, reference these fully compliant roles:
- **jellyfin** - User-facing service (100% compliant)
- **pihole-exporter** - Monitoring service with updates
- **semaphore** - User-facing service with Traefik

Read these roles' files to ensure consistent implementation.

## Usage

```bash
/migrate-role audiobookshelf
/migrate-role pihole-exporter
/migrate-role semaphore
```

The role name should match the directory name in `roles/`.

## Troubleshooting

**Template not found errors:**
- In setup.yml, use `src: ../templates/environment.j2` (relative path)
- Ensure template file has mode 644

**Syntax errors:**
- Check YAML indentation
- Verify all Jinja2 variables are properly closed
- Ensure quotes are balanced in labels

**Permission errors:**
- Add `become: false` to all local_action and delegate_to: 127.0.0.1 tasks
- Verify file modes (640 for .env, 644 for compose.yml, 644 for templates)

**Container deployment fails:**
- Verify environment file exists and has correct permissions
- Check docker_compose_v2 module syntax
- Ensure remove_orphans: false is set

**Handler fails with "Cannot find Compose file" error:**
- **Root Cause:** Compose file deployment has a conditional that prevents it from running
- **Problem:** Environment file copy triggers handler, but compose.yml doesn't exist yet
- **Solution:** Remove conditionals from directory creation and compose file deployment
- **Rule:** Only the initial container start (`docker_compose_v2` task) should be conditional
- **Why:** Handlers need compose.yml to exist; tasks that trigger handlers must ensure files exist
