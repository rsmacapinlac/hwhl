---
name: verify-services
description: Verify homelab services. Use when checking service updates, comparing expected services from Ansible inventory and ansible/site.yml with actual Docker containers on LXCs, monitoring maintenance playbooks, or verifying latest container image versions.
---

# Verify Services

This skill assumes `AGENTS.md` has already been read for repository layout, safety rules, and common command conventions.

## Process

1. Use Terraform configuration and Ansible inventory to create a list of expected hosts and services in `tmp/<repository-name>.txt`.
   - Derive LXC hosts from `terraform/` and `homelab_config/terraform.tfvars` when relevant.
   - Derive expected service groups from `ansible/site.yml` and Ansible inventory.
   - Resolve child groups recursively; `managed_hosts` may not list direct hosts.
2. Use Ansible ad-hoc commands to collect actual Docker containers from each host/LXC.
3. Compare expected services to actual containers.
   - Nextcloud AIO sidecar containers on the Nextcloud host can be ignored when identifying unexpected/stale containers. These are created and managed by the `nextcloud-aio-mastercontainer` rather than directly by Ansible. Examples include `nextcloud-aio-apache`, `nextcloud-aio-clamav`, `nextcloud-aio-collabora`, `nextcloud-aio-database`, `nextcloud-aio-fulltextsearch`, `nextcloud-aio-imaginary`, `nextcloud-aio-nextcloud`, `nextcloud-aio-nextcloud-exporter`, `nextcloud-aio-notify-push`, `nextcloud-aio-redis`, and `nextcloud-aio-whiteboard`.
4. Report results both to files under `tmp/` and directly in the console/chat. The report should include:
   - missing expected services
   - stopped or unhealthy containers
   - unexpected/stale containers
   - inventory drift
   - maintenance coverage gaps
   - version verification gaps
   - actual service version vs web-resolved expected version in this format: `<host>: <service> (<actual version>; <state/health>) -> <expected image tag> (<web expected version>)`
5. For version verification, run the two helper scripts in order from the repository root:
   1. `python3 .claude/skills/verify-services/scripts/diun_collect.py` — queries each host's running Diun container for cached upstream registry metadata. Avoids Docker Hub rate limits because Diun already fetches this daily. Writes `tmp/<repository-name>.diun_cache.json`.
   2. `python3 .claude/skills/verify-services/scripts/registry_version_report.py` — uses the Diun cache as the primary version source, falling back to direct registry queries only for images Diun does not watch. Writes `tmp/<repository-name>.web-expected-version-report.md` and prints the full report.

## Helper scripts

Scripts live under `scripts/` following the Agent Skills directory convention. References are relative to this skill directory.

- `scripts/diun_collect.py` — collects upstream version data from the Diun containers already running on each host via Ansible ad-hoc. Diun has already queried the registries on a daily schedule, so this avoids Docker Hub rate limits entirely. Writes `tmp/hwhl_vancouver.diun_cache.json`. Run it from the repository root **before** the version report:

  ```bash
  python3 .claude/skills/verify-services/scripts/diun_collect.py
  ```

- `scripts/registry_version_report.py` — produces the full actual-vs-expected version report. Loads `tmp/hwhl_vancouver.diun_cache.json` as the primary version source if present, then falls back to direct registry queries only for images not covered by Diun. Writes `tmp/hwhl_vancouver.web-expected-version-report.md` and prints the report to stdout. Run from the repository root after both the Diun cache and Docker inspect files have been collected:

  ```bash
  python3 .claude/skills/verify-services/scripts/registry_version_report.py
  ```

  **Recommended order:**
  ```bash
  python3 .claude/skills/verify-services/scripts/diun_collect.py
  python3 .claude/skills/verify-services/scripts/registry_version_report.py
  ```

Do not remove containers, volumes, generated inventory, Terraform state, or other infrastructure resources without explicit user approval.
