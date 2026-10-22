# Weekly Proxmox Cluster Health Check

## Purpose

Catch problems on the Proxmox cluster, its LXCs and its VMs before they become
outages: failing disks, full storage, broken backups, stopped guests, unhealthy
containers and monitoring gaps. Each run is compared with the previous one, so
slow changes (a SMART counter creeping up, a pool filling) show up as new
findings.

## Cadence

- **Weekly**, on the same day each week (so the 7-day windows don't overlap or leave gaps).
- **Also before and after any maintenance** (node reboots, upgrades, hardware
  changes, guest moves). The run before is the baseline you compare against afterwards.

## Scope

| Layer | What is checked | Script |
|---|---|---|
| Proxmox nodes (every node in `proxmox_control_node_by_ip`) | PVE services, failed units, quorum and corosync links, time sync, memory and swap, every storage enabled on the node, LVM-thin data and metadata, ZFS pools, SMART health and bad-sector counters, NIC hangs, hung tasks, OOM kills, journal errors and their top sources, `onboot` guests not running, locked guests, VM guest agents, pve-ssl expiry, pending reboot for a new kernel, apt updates | `sop/scripts/pve-node-health.sh` |
| Cluster (run once) | Quorum and votes, nodes online, HA and replication, every vzdump task in the last 7 days (status and duration), disk and memory use of **every** running guest (including ones Ansible doesn't manage), age of each guest's latest backup | `sop/scripts/pve-cluster-health.sh` |
| Monitoring (`prometheus` group) | Prometheus targets down, firing alerts | `sop/scripts/prometheus-health.sh` |
| Managed LXCs (`managed_hosts:!raspberrypi`) | Root disk, failed units, DNS, time sync, `/data/*` mounts present and not empty, Docker running/total, containers not up or unhealthy, restart counts, apt updates, journal errors | `sop/scripts/ct-health.sh` |

**Not covered automatically:** application-level behaviour (does Jellyfin play,
does Vaultwarden log in), the inside of guests Ansible doesn't manage
(Downbeat's boogienet CTs, VM 101 Hermes), and the NAS units themselves. Those are
the manual checks in step 4.

## Safety notes

- Everything is **read-only**. The playbook only writes files under `reports/` on the control machine.
- The report contains hostnames, IPs, disk models and log excerpts. `reports/` is
  gitignored; keep it that way and don't paste whole reports into issues or chats outside the homelab.
- Don't act on a finding inside this SOP. Triage it (step 3), then fix it as separate,
  deliberate work.

## Prerequisites

- Run from the repository root: `/home/ritchie/workspace/hwhl_vancouver`.
- Ansible is installed (`./bin/ansible-init.sh`) and `homelab_config/ansible/group_vars` is linked into the inventory.
- The nodes' root login only accepts `~/.ssh/id_rsa`, so load it first: `ssh-add ~/.ssh/id_rsa`.
- The generated inventory is current (run Terraform first if LXCs were added or removed).

## Procedure

### 1. Run the check

```bash
ssh-add ~/.ssh/id_rsa
./bin/ansible-playbook.sh health-check.yml
```

It takes about a minute. The last task prints two paths:
- the health report, `reports/health/<YYYY-MM-DD>/report.txt`
- the current-state snapshot, `reports/state/<YYYY-MM-DD>-<cluster>.md` (see [documenting-cluster-state.md](documenting-cluster-state.md))

Running it twice on the same day overwrites that day's files.

An unreachable host doesn't stop the run. It shows up in the report as a finding.

### 2. Read the report

`report.txt` has these sections, in order:

| Section | Meaning |
|---|---|
| **Needs attention** | Every line a script marked with `!`, minus known exceptions. This is the work list |
| **New since <date>** | Findings that weren't in the previous report. Read these first |
| **Cleared since <date>** | Findings from the previous report that are gone. Confirm each one was fixed rather than just no longer checked |
| **Known exceptions** | Findings matched by `sop/health-check-known.txt`. Skim them; they're listed, not hidden |
| **Full output** | Everything each script printed, per host |

A finding that includes a count or a value (`hung tasks 7d: 10`, a SMART counter)
shows as new whenever the value changes. That's intentional.

### 3. Triage each finding

| Finding | Threshold | First action |
|---|---|---|
| Service not active / failed unit | any | `systemctl status <unit>` and its journal on that host |
| Not quorate / node offline / corosync link down | any | Stop. Don't reboot or migrate anything until quorum is back |
| Storage inactive or over 85% | `pvesm status` | Inactive NFS storage: check the NAS and `findmnt`. Full: find the largest volumes before adding more guests |
| Thin pool data > 85% or metadata > 75% | `lvs` | Thin pools that fill up corrupt guests. Grow metadata (`lvextend --poolmetadatasize`) or move volumes off |
| ZFS pool not healthy | `zpool status -x` | `zpool status -v <pool>`; plan a disk replacement |
| SMART `FAILED`, or a bad-sector counter non-zero or changed | `Reallocated`, `Current_Pending`, `Offline_Uncorrectable`, `Bad_Blk`, NVMe media errors | Make sure every guest on that disk has a recent backup, then plan the replacement. A changed value for a known disk means it's getting worse |
| Swap over 50% | node | Check which guests are over their real need (`pvesh get /cluster/resources --type vm`). On ZFS nodes, check the ARC cap is still applied |
| NIC hardware hangs | any since boot | On e1000e: check TSO/GSO are still off (`ethtool -k`) |
| Hung tasks | any in 7d | `journalctl -k --since -7d | grep -A5 "blocked for more than"` names the process. Often a VM or backup stalled on I/O |
| OOM kills | any in 7d | `journalctl -k | grep -i "killed process"` names the guest; raise its memory or fix the leak |
| Journal errors | big jump vs. last week | The "top error sources" line says where to look |
| CT/VM `onboot` but not running | any | `pct start` / `qm start` and read why it stopped. If it should be off, set `onboot 0` |
| Guest locked | any | Usually a backup or migration that died. Confirm nothing is running for it, then `pct unlock` / `qm unlock` |
| VM guest agent not responding | `agent: 1` in config | Install or start `qemu-guest-agent` in the VM, or set `agent: 0`. Without it, backups can't freeze the filesystem |
| Reboot pending | newer kernel installed | Schedule the reboot (one node at a time) |
| pve-ssl expires within 30 days | | `pvecm updatecerts` |
| vzdump task not `OK` | any in 7d | Read the task log: `pvesh get /nodes/<node>/tasks/<upid>/log`. Also look at durations: a job that keeps getting longer will eventually run into the next morning |
| Backup missing or older than 1 day | running guest | Check it isn't excluded from the job on purpose; otherwise fix the job and run a manual backup |
| Guest disk > 85% or memory > 90% | any guest | Clean up or grow it before it fills |
| Prometheus target down / alert firing | any | Check the exporter container on that host |
| CT: root > 85%, DNS fail, time not synced, `/data` mount empty | any | Empty `/data/*` usually means the NFS share isn't mounted on the node |
| CT: container not up, unhealthy, or restarted | any | `docker logs <name>`; if it's exited by design, add it to the known exceptions |

### 4. Manual checks

These take five minutes and catch what scripts can't:

| Where | Spot-check |
|---|---|
| Ingress and DNS | A Traefik-routed URL loads; `dig @10.1.0.2 google.com` (and each other Pi-hole); a WireGuard client connects |
| Media | Jellyfin plays something; Sonarr/Radarr UIs load; transmission shows the VPN IP |
| Family | Vaultwarden login; Immich timeline loads; Paperless search works |
| Smart home | Home Assistant UI loads and a Zigbee device responds; TeslaMate shows a recent update |
| Guests outside Ansible | Downbeat's CTs: `pct exec 500 -- docker ps -a` and `pct exec 501 -- docker ps -a` on their node. VM 101: Hermes dashboard on `:9119` loads |
| NAS units | Their own UIs show no disk or volume warnings |

### 5. Record the result

Add one row per run to the log at the bottom of this file. Write down the result,
anything new, and what you're going to do about it. Fixes are tracked separately
from this SOP.

## Acceptance criteria

A run **passes** when:

- The cluster is quorate and every node is online.
- No guest that should be running is stopped, and no guest is locked.
- Every running guest has a backup from the last night, and every vzdump task in the last 7 days is `OK`.
- No storage is inactive or past its threshold, and no SMART counter has changed.
- No CT has a stopped, unhealthy or restarting container.
- No Prometheus target is down.
- Every remaining "Needs attention" line has an owner and a next step in the log.

**Pass with exceptions:** the only open findings are known exceptions or have a
recorded plan. **Fail:** anything else, especially quorum, backups or disk
health.

## Known exceptions

`sop/health-check-known.txt` holds one extended regex per line, matched against the
"Needs attention" lines (`<host>: <finding>`). Rules:

- Write a comment above each pattern with **why** and **a date**.
- Make patterns as narrow as possible. For counters, include the exact value
  (for example `Bad_Blk_Ct_Erl/Lat=0/369`), so a change comes back as a finding.
- Remove the pattern as soon as its cause is gone. Stale exceptions hide regressions.

## Changing the checks

The checks live in `sop/scripts/*.sh` and the playbook is
`ansible/health-check.yml`. Rules for changes:

- Keep the scripts POSIX `sh` and read-only. They're run with `-m script`, so Docker Go templates never pass through Jinja.
- Start a line with `!` only when it needs a human. Everything else is context.
- Keep finding lines stable from week to week (no timestamps or changing counts unless the change matters), or every run will look new.
- To try a single script: `cd ansible && ansible <host> -u root -m script -a ../sop/scripts/<script>.sh`.

## Follow-ups

- Schedule it: a weekly systemd user timer on the control machine. It needs a key the nodes accept without an interactive `ssh-add`.
- Move the most important checks (backup age, SMART counters, thin-pool metadata, swap) into Prometheus alerts, so they don't wait for the weekly run.

## Run log

| Date | Run by | Result | New findings | Actions |
|---|---|---|---|---|
| 2026-10-22 | Claude (first run, during interhigh maintenance) | Fail | First run, so everything is new. Real: izumida swap 79% and 10 hung tasks (VM 101); VM 101 has `agent: 1` but no agent answers; pihole-exporter `10.1.0.15:9617` down on all three Prometheus hosts; smarthome (CT 226) has no backup yet (created today). Historical, already fixed: vzdump errors from VM 100 (deleted 10-21), CT 217 (dropped 10-22) and izumida's reboot on 10-21. Watch: midosuji MX500 `Current_Pending_ECC_Cnt` went 0 → 1 | See the interhigh maintenance doc, Phase 1 |
