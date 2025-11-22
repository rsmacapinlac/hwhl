---
description: "Audit an existing Ansible role against documented patterns in ansible-role-patterns.md"
allowed-tools: ["Read", "Glob", "Grep", "TodoWrite", "AskUserQuestion"]
---

# Audit Ansible Role

Perform a comprehensive audit of the **$ARGUMENTS** role against the modern Ansible role patterns documented in `docs/ansible-role-patterns.md`.

## CRITICAL: This is AUDIT ONLY

**DO NOT take any actions or make any changes to files.**

This command will:
- ✅ Analyze the existing role structure
- ✅ Compare against documented patterns
- ✅ Create a detailed checklist of findings
- ✅ Present findings for user review
- ❌ NOT modify any files
- ❌ NOT create any files
- ❌ NOT fix any issues

## Audit Process:

### 1. Read Pattern Documentation
- Read `docs/ansible-role-patterns.md` to understand current standards
- Note all required patterns and best practices

### 2. Analyze Role Structure
Examine the role at `roles/$ARGUMENTS/` for:

**Directory Structure:**
- [ ] Check if role directory exists
- [ ] Verify presence of required directories (tasks/, templates/, handlers/)
- [ ] Check for optional directories (defaults/, meta/)
- [ ] Verify presence of update.yml if applicable

**Task Files:**
- [ ] Read `tasks/main.yml` - deployment tasks
- [ ] Read `tasks/setup.yml` - environment file creation
- [ ] Read `tasks/update.yml` (if present) - update workflow
- [ ] Analyze task patterns and compare to documentation

**Templates:**
- [ ] Read `templates/docker-compose.j2` - Docker compose template
- [ ] Read `templates/environment.j2` - Environment file template
- [ ] Check for Jinja2 defaults usage
- [ ] Verify service type patterns (user-facing vs monitoring vs database)

**Handlers:**
- [ ] Read `handlers/main.yml`
- [ ] Verify handler pattern (restarted vs present+recreate)
- [ ] Check for remove_orphans parameter

**Configuration:**
- [ ] Read `defaults/main.yml` (if exists)
- [ ] Check for configurable ports
- [ ] Verify environment file location

### 3. Pattern Compliance Checklist

Create a comprehensive checklist covering:

**Environment File Management:**
- [ ] Environment file validation in main.yml
- [ ] Proper error message if environment file missing
- [ ] Environment file permissions (640)
- [ ] Template uses Jinja2 defaults where appropriate
- [ ] Multi-value configuration pattern (if applicable)

**Container Management:**
- [ ] Container status checking before deployment
- [ ] Proper conditional deployment
- [ ] Directory creation with correct permissions (755)
- [ ] Correct ownership (ansible:docker)

**Docker Compose Deployment:**
- [ ] Uses docker_compose_v2 module
- [ ] Includes remove_orphans: false parameter
- [ ] Proper file permissions (644 for compose.yml)
- [ ] State parameter is appropriate

**Service Type Pattern:**
- [ ] Identify service type (user-facing/monitoring/database)
- [ ] Traefik labels present (if user-facing)
- [ ] Proxy network configuration (if user-facing)
- [ ] Watchtower labels present
- [ ] Port configuration matches service type

**Handler Implementation:**
- [ ] Handler uses appropriate state (restarted vs present+recreate)
- [ ] Includes remove_orphans: false
- [ ] Handler name follows convention

**Update Tasks (if present):**
- [ ] Uses pull: always and recreate: always
- [ ] Includes container health checking
- [ ] Implements retry logic
- [ ] Error handling with ignore_errors
- [ ] Debug messages for status
- [ ] Dangling image cleanup
- [ ] Integration with maintenance.yml verified

**Setup Tasks:**
- [ ] Creates config directory locally
- [ ] Uses template for environment file
- [ ] Provides setup instructions
- [ ] Integration with site-setup.yml verified

**Best Practices:**
- [ ] File permissions follow standards
- [ ] Proper error handling with meaningful messages
- [ ] Consistent naming conventions
- [ ] Conditional deployment to avoid unnecessary recreation
- [ ] Integration with site.yml verified

### 4. Generate Findings Report

Create a detailed report with:
1. **Compliance Summary** - What patterns are correctly implemented
2. **Deviations** - What differs from documented patterns
3. **Missing Patterns** - What documented patterns are not implemented
4. **New Patterns** - Any patterns in the role not yet documented
5. **Recommendations** - Suggested improvements (for user to implement)

### 5. Present to User

Use TodoWrite to create an interactive checklist organized by:
- ✅ Compliant patterns
- ⚠️ Deviations from patterns
- ❌ Missing required patterns
- 🆕 New undocumented patterns

**Remember:** Present findings only. Do not offer to fix or implement changes. Let the user decide what actions to take.

## Output Format:

Provide a structured audit report with:

```
# Role Audit: {service-name}

## Service Type Identified
[User-facing / Monitoring / Database / Other]

## Compliance Score
X/Y patterns correctly implemented

## ✅ Correctly Implemented Patterns
- Pattern 1: Description
- Pattern 2: Description
...

## ⚠️ Deviations from Documented Patterns
- Issue 1: What's different and why it might matter
- Issue 2: What's different and why it might matter
...

## ❌ Missing Patterns
- Missing 1: What's missing and impact
- Missing 2: What's missing and impact
...

## 🆕 New Patterns Not Yet Documented
- New pattern 1: Description
- New pattern 2: Description
...

## Recommendations
1. Recommendation with reference to pattern docs
2. Recommendation with reference to pattern docs
...
```

## Usage:

```bash
/audit-role pihole-exporter
/audit-role semaphore
/audit-role prometheus
```

The role name should match the directory name in `roles/`.
