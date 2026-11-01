# Weekly Homelab Check

## Purpose

One run that answers "is the homelab healthy, and is everything up to date?"
It chains two existing SOPs, in this order:

1. [proxmox-cluster-health-check.md](proxmox-cluster-health-check.md): nodes, cluster, backups, monitoring and every managed LXC.
2. [maintenance-service-version-audit.md](maintenance-service-version-audit.md): expected vs. running services and their image versions.

The health check goes first. A stopped container or an unreachable LXC
then shows up as a known cause, not as a version-audit puzzle.

## Cadence

Manually triggered for now. In Claude Code, run `/weekly-check` from the repository root.

## Scope

- **Check only.** This SOP never runs `maintenance.yml`, `site.yml`, Terraform
  or any fix. The version audit's step 2 (deploy maintenance) and step 9
  (remediation loop) are skipped. Out-of-date services and other findings are
  reported, and the user decides what to run.
- The runner (a person or an agent) follows these steps. This file doesn't
  assume a particular agent, so it can later be handed to another one (planned:
  Hermes on the Mac mini).

## Safety notes

- Everything is read-only on the homelab. The only writes go to `reports/` and `tmp/` on the control machine, and both are gitignored.
- Reports contain hostnames, IPs and log excerpts. Don't paste them outside the homelab.
- Don't act on a finding during the run. Triage it, record it, and fix it as separate work.

## Prerequisites

- The prerequisites of both SOPs.
- `ssh-add -l` lists the RSA key (`~/.ssh/id_rsa`). Without it, every Proxmox node is unreachable. If it's missing, stop and ask the user to run `ssh-add ~/.ssh/id_rsa`. An agent can't enter the passphrase.
- No `maintenance.yml`, `site.yml` or Terraform run is in progress. A run in the middle of updating gives half-updated results.

## Procedure

Set the date once and use it for every path below:

```bash
DATE="$(date +%F)"
mkdir -p "reports/weekly/${DATE}"
```

### 1. Health check

Follow [proxmox-cluster-health-check.md](proxmox-cluster-health-check.md) steps 1–3:
run `./bin/ansible-playbook.sh health-check.yml`, read `reports/health/${DATE}/report.txt`
(**New since** first) and triage each finding.

Do its step 4 (manual checks) only when a person is running this. An agent lists the step 4 checks
in the summary as "not done".

### 2. Version audit

Follow [maintenance-service-version-audit.md](maintenance-service-version-audit.md)
steps 1 and 3–8. **Skip step 2.** Classify each finding with step 7's categories.

When the audit is done, copy its report files into the weekly folder:

```bash
cp tmp/hwhl_vancouver.web-expected-version-report.md \
   tmp/hwhl_vancouver.docker_ps.txt \
   "reports/weekly/${DATE}/"
```

### 3. Summary

Write `reports/weekly/${DATE}/summary.md`:

```markdown
# Weekly homelab check - <date>

Run by: <who>
Health report: reports/health/<date>/report.txt
Version report: reports/weekly/<date>/hwhl_vancouver.web-expected-version-report.md

## Result
Health: PASS / PASS WITH EXCEPTIONS / FAIL
Versions: PASS / PASS WITH EXCEPTIONS / FAIL

## Needs action
- <host>: <finding> -> <suggested next step>

## New since last week
- ...

## Updates available
- <host>: <service> (<actual>) -> <expected>

## Not checked
- <manual checks skipped, hosts unreachable, verification gaps>
```

Use the acceptance criteria of each SOP for its result line. A health FAIL
(quorum, backups, disk health) is the first line of "Needs action".

### 4. Record the result

- Add a row to the run log in [proxmox-cluster-health-check.md](proxmox-cluster-health-check.md), as its step 5 says.
- Give the user the summary path, the two result lines and the "Needs action" list.
  Commit the run log change only if the user asks.

## Acceptance criteria

The weekly check is **done** when both reports exist for the date, `summary.md` is
written, and each "Needs action" line has a suggested next step. It's done even
when the results are FAIL: this SOP reports problems, it doesn't fix them.
