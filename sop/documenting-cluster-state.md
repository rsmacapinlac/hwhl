# Documenting Cluster State

## Purpose

There are times when you need to understand the current Proxmox cluster's state.

## Where things go

Information is saved under `reports/` and is gitignored from this repository.

| Path | What | Written by |
|---|---|---|
| `reports/health/<YYYY-MM-DD>/` | Health check output: `report.txt` plus the raw per-host results | `ansible/health-check.yml` ([SOP](proxmox-cluster-health-check.md)) |
| `reports/state/<YYYY-MM-DD>-<cluster>.md` | **State snapshot**: generated facts about the cluster | `ansible/health-check.yml`, automatically |
| `reports/state/<YYYY-MM-DD>-<topic>.md` | **Analysis notes**: data a snapshot can't collect | A person or Claude, by hand |

## State snapshots

Every health check run writes one. Don't edit a snapshot by hand: when the cluster changes, take a new one.

```bash
ssh-add ~/.ssh/id_rsa
./bin/ansible-playbook.sh health-check.yml
```

A snapshot always has these sections, in this order, so two of them can be diffed:

1. **Header:** the as-of time and how it was generated.
2. **Nodes:** one block per node: hardware, CPU, RAM, PVE and kernel, boot mode, GPU, NICs; a disk table (model, size, type, SMART, what uses it); a storage table (type, status, size, used).
3. **Guests:** every CT and VM: VMID, name, type, node, status, onboot, cores, RAM, root disk, storage.
4. **Protected backups:** each one with its size and notes.

To change what a snapshot collects, edit `sop/scripts/pve-node-state.sh` (per node) or `sop/scripts/pve-cluster-state.py` (guests and backups). Keep them read-only, and keep the section order.

## Analysis notes

For facts a snapshot can't collect: measurements, query results, baselines,
hardware found by hand, and what was concluded from them.

Start the file with this header, then one section per topic:

```markdown
# <Topic> (<cluster>)

| | |
|---|---|
| **As of** | YYYY-MM-DD HH:MM |
| **Collected by** | who, and the commands, reports or measurements used |
| **Used by** | the process documents that rely on this |
| **Snapshot** | the state snapshot it goes with |
```

In each section:
- Put data in tables where possible, with units.
- Give the source for each fact: the command, the report, or "by hand".
- If a fact changes, add a dated line under it instead of overwriting it, so the history stays readable.
- Keep conclusions short, and label them as conclusions.
