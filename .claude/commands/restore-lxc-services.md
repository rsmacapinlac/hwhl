---
description: "Restore services for an LXC container from borgbackup"
allowed-tools:
  - Read
  - Grep
  - Glob
  - TodoWrite
  - AskUserQuestion
  - Bash(bin/terraform.sh *)
  - Bash(bin/ansible-playbook.sh *)
  - Bash(ansible * -m shell -a *)
---

# Restore LXC Services

Restore all services for LXC host: **$ARGUMENTS**

This command performs a full service restore for a Proxmox LXC container, including provisioning the container, restoring data from borgbackup, and redeploying all services.

## Process Overview

### Step 1: Provision the LXC with Terraform
1. Run `bin/terraform.sh plan` and review the output
2. Confirm the plan creates the expected LXC container with correct specs (CPU, RAM, disk, mount points)
3. Run `bin/terraform.sh apply` to provision

### Step 2: Run Host Setup
1. Run `bin/ansible-playbook.sh host-setup.yml --limit $ARGUMENTS`
2. This creates the ansible user, SSH keys, sudo access, etc.

### Step 3: Deploy BorgBackup and Verify Backups
1. Run `bin/ansible-playbook.sh site.yml --limit $ARGUMENTS --tags borgbackup`
2. Verify the latest backup is visible:
   ```
   ansible $ARGUMENTS -m shell -a "docker exec borgbackup borgmatic list"
   ```
3. Confirm the most recent archive timestamp matches expectations (typically 2:00 AM of the current day)

### Step 4: Restore /data/containers from BorgBackup
1. Stop the borgbackup container:
   ```
   ansible $ARGUMENTS -m shell -a "docker stop borgbackup"
   ```
2. Run a temporary borgmatic container with read-write mount to extract the backup:
   ```
   ansible $ARGUMENTS -m shell -a "docker run --rm --entrypoint '' \
     -e 'BORG_PASSPHRASE=<passphrase>' \
     -v /data/containers:/mnt/source \
     -v /data/borgbackup/<hostname>:/mnt/borg-repository \
     ghcr.io/borgmatic-collective/borgmatic:latest \
     bash -c 'export BORG_PASSPHRASE=<passphrase> && cd /mnt/source && \
     borg extract --strip-components 2 /mnt/borg-repository::<archive-name> mnt/source'"
   ```
   **Note:** The `--strip-components 2` is needed because borg archives store paths as `mnt/source/...`. The passphrase can be found in the borgmatic config.yaml deployed by the borgbackup role (check `roles/borgbackup/templates/` or the deployed config on the host).
3. Restart borgbackup:
   ```
   ansible $ARGUMENTS -m shell -a "docker start borgbackup"
   ```
4. Verify the restore:
   ```
   ansible $ARGUMENTS -m shell -a "ls -la /data/containers/"
   ```

### Step 5: Deploy All Services
1. Run `bin/ansible-playbook.sh site.yml --limit $ARGUMENTS`
2. Verify all plays complete with 0 failures

**Known Issues:**
- The `shares` role may fail on hosts where Terraform already configures bind mounts (e.g., NFS shares mounted at the Proxmox host level). If this occurs, confirm with the user to remove the shares role from site.yml for that host.
- The borgbackup container mounts `/data/containers` as read-only (`:ro`), which is why a temporary container with read-write access is needed for the restore step.

### Step 6: Audit Containers
1. List all running containers:
   ```
   ansible $ARGUMENTS -m shell -a 'docker ps -a --format "table {% raw %}{{.Names}}\t{{.Status}}{% endraw %}"'
   ```
2. Cross-reference with `/data/containers/` directories:
   ```
   ansible $ARGUMENTS -m shell -a 'ls -d /data/containers/*/'
   ```
3. Identify any directories that have no corresponding running container (these may be legacy/leftover data)
4. Identify any containers that are not in a "running" state

### Step 7: Report
Present a summary including:
- Terraform resources created
- Services deployed and their status
- Any containers NOT running and why
- Any issues encountered and how they were resolved
- Any legacy data directories found

## Important Notes
- Do NOT make configuration changes without user confirmation
- The borgbackup passphrase is stored in the borgmatic config template and group_vars
- Always verify the backup archive exists and is recent before proceeding with restore
- The restore extracts to `/data/containers` which contains all Docker service data (configs, databases, volumes, etc.)
