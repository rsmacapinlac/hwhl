# Post-Maintenance Service Version Audit

## Purpose

Verify that all deployed homelab services are running, healthy, covered by `ansible/maintenance.yml`, and updated to the latest expected upstream container version after maintenance is deployed.

## Scope

Use this SOP after running `ansible/maintenance.yml` against the homelab LXCs. The audit covers Docker Compose services deployed through `ansible/site.yml` and inventory groups under `homelab_config/ansible/inventory/`.

## Safety notes

- Treat `homelab_config/ansible/group_vars/all.yml`, Terraform state, tfvars, tokens, and generated inventory as sensitive.
- Use Ansible ad-hoc commands over direct SSH.
- This SOP is read-only except for running `maintenance.yml`; do not remove containers, images, volumes, state, or generated files unless explicitly approved.
- Nextcloud AIO sidecar containers may appear as unexpected. Review them, but do not remove them unless Nextcloud AIO confirms they are stale.

## Prerequisites

- Run from the repository root: `/home/ritchie/workspace/hwhl_vancouver`.
- Ansible dependencies are installed (`./bin/ansible-init.sh` if needed).
- Inventory is current. If Terraform changed LXCs, run Terraform first so `homelab_config/ansible/inventory/generated/terraform-hosts.ini` is refreshed.
- You can reach all managed hosts using the Ansible inventory.

## Procedure

### 1. Prepare a clean audit workspace

```bash
mkdir -p tmp
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
```

Optional pre-flight checks:

```bash
./bin/ansible-playbook.sh maintenance.yml --syntax-check
./bin/ansible-playbook.sh site.yml --syntax-check
```

### 2. Deploy maintenance

Run maintenance for all services:

```bash
./bin/ansible-playbook.sh maintenance.yml | tee "tmp/hwhl_vancouver.maintenance.${STAMP}.log"
```

If limiting scope, record the exact limit/tag used:

```bash
./bin/ansible-playbook.sh maintenance.yml --limit <host-or-group> --tags <tag> \
  | tee "tmp/hwhl_vancouver.maintenance.${STAMP}.log"
```

### 3. Collect actual running container state

```bash
(
  cd ansible && \
  ansible managed_hosts -b -m shell \
    -a 'docker ps -a --format "{% raw %}{{.Names}}|{{.Image}}|{{.Status}}{% endraw %}"'
) | tee tmp/hwhl_vancouver.docker_ps.txt
```

```bash
(
  cd ansible && \
  ansible managed_hosts -b -m shell \
    -a 'if [ -n "$(docker ps -aq)" ]; then docker inspect $(docker ps -aq) --format "{% raw %}{{.Name}}|{{.Config.Image}}|{{.Image}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}{{end}}|{{json .Config.Labels}}{% endraw %}"; fi'
) | tee tmp/hwhl_vancouver.docker_inspect.txt
```

### 4. Refresh expected service map

Build or refresh `tmp/hwhl_vancouver.expected_map.json` from:

- `ansible/site.yml` roles and host groups
- `ansible/maintenance.yml` update coverage
- `ansible/inventory/groups.yml`
- `homelab_config/ansible/inventory/generated/terraform-hosts.ini`
- `homelab_config/ansible/inventory/proxmox-lxc-config.yml`
- each role's Docker Compose templates/defaults that define image references

When using Pi, ask it to run the `verify-services` workflow so the expected service map is derived consistently.

### 5. Collect upstream image metadata through Diun

Diun already polls registries, so use its cached metadata before making direct registry calls:

```bash
python3 skills/verify-services/scripts/diun_collect.py \
  2>&1 | tee tmp/hwhl_vancouver.diun_collect.stdout.txt
```

### 6. Generate actual-vs-latest version report

```bash
python3 skills/verify-services/scripts/registry_version_report.py \
  2>&1 | tee tmp/hwhl_vancouver.web-expected-version-report.stdout.txt
```

Primary report files:

- `tmp/hwhl_vancouver.web-expected-version-report.md`
- `tmp/hwhl_vancouver.web_expected_versions.json`
- `tmp/hwhl_vancouver.diun_cache.json`
- `tmp/hwhl_vancouver.docker_ps.txt`
- `tmp/hwhl_vancouver.docker_inspect.txt`

### 7. Review and classify findings

For each finding, classify as one of:

- **Pass:** service is running/healthy and actual version matches expected latest version.
- **Needs update:** actual version is older than upstream latest.
- **Maintenance coverage gap:** service is deployed by `site.yml` but not updated by `maintenance.yml`.
- **Inventory drift:** `site.yml` or `maintenance.yml` references a group missing from inventory, or inventory contains unexpected service placement.
- **Health issue:** container is stopped, restarting, exited, created, or unhealthy.
- **Verification gap:** upstream lookup failed, usually due to registry rate limits, private registry restrictions, or an image tag that cannot be resolved.
- **Expected exception:** sidecar/system-managed container such as Nextcloud AIO sidecars.

### 8. Acceptance criteria

The audit passes when:

- No expected service containers are missing.
- No expected containers are stopped, restarting, or unhealthy.
- No service has an unresolved maintenance coverage gap.
- No deployed service is behind the web/Diun-resolved expected version, unless documented as an intentional pin or false positive.
- Unexpected containers are explained and either documented or remediated.
- Verification gaps are retried or documented with a reason.

### 9. Remediation loop

For each actionable issue:

1. Fix the Ansible role, inventory, image tag, or `maintenance.yml` coverage.
2. Re-run the relevant maintenance tag/limit.
3. Re-run this audit from container collection onward.
4. Save the final report in `tmp/` and summarize remaining exceptions.

## Final audit summary template

```markdown
# Post-maintenance service version audit - <date>

Maintenance command: `<command>`
Report: `tmp/hwhl_vancouver.web-expected-version-report.md`

## Result
PASS / PASS WITH EXCEPTIONS / FAIL

## Action required
- ...

## Exceptions accepted
- ...

## Follow-up
- ...
```
