---
name: sync-control-machines
description: Sync hwhl between two control machines (Ritchie's laptop and the Mac mini that runs the Hermes "homelab" profile) so either can run Ansible and Terraform. Use when asked to sync hwhl, push or pull homelab_config, Terraform state or other Git-ignored working files, or before and after running Terraform or editing homelab_config on either machine.
---

# Sync Control Machines

Keeps two hwhl checkouts interchangeable. This skill assumes `AGENTS.md` has already been read.

A checkout is only workable with files Git never sees. This skill syncs them two ways, and Git carries the rest:

| Synced by | Paths |
|---|---|
| Git (commit, push, pull) | every tracked file |
| `scripts/hwhl_sync.py` | `homelab_config/**` (inventory, `group_vars/all.yml`, `files/`, `hosts/`, `terraform.tfvars`), `ansible/roles/*/files/**`, `terraform/terraform.tfstate*`, `terraform/.proxmox-token`, `reports/**` |
| Not synced (machine-specific or scratch) | `terraform/.terraform/` (per-platform providers; run `terraform init` on each machine), `tmp/`, `.facts.json/`, `.claude/` |

The helper compares each path against the hashes recorded at the last sync, so a file moves only when exactly one side changed it. A file changed on both sides is a conflict and nothing is applied until it is resolved. It never prints file contents: output is paths, actions and reasons.

## Rules

- **Run it from the laptop.** The helper runs on the machine that can SSH to the other; the mini cannot reach the laptop. Matt (on the mini) does not run this skill: he reports that a sync is needed to GwenBot or Ritchie.
- **One Terraform machine at a time.** State is local, not a shared backend. Sync immediately before and after every `terraform apply`, and never run Terraform on both machines between syncs. The helper refuses to move state backwards (lower serial), to overwrite a state with a different lineage, or to touch state while `.terraform.tfstate.lock.info` exists. Never work around these: they mean the two states have diverged and Ritchie must decide.
- **Sync after editing** anything under `homelab_config/` or regenerating the inventory, so the other machine never deploys stale config.
- Never print, diff or `cat` synced files to resolve a conflict: they carry secrets. Compare by size and modification time (`ls -l`) on both sides, and ask Ritchie which side wins.
- Never pass `--take` for `terraform/terraform.tfstate` without Ritchie's explicit approval for that exact choice.
- More than 10 deletions in one run is a blocker: it usually means one checkout was wiped or re-cloned, and mirroring that would delete the good copy. Investigate; pass `--allow-mass-delete` only with Ritchie's approval. To retire a machine, delete `~/.local/state/hwhl-sync/<peer>.json` on the laptop as well.

## Process

1. **Git first.** On both machines, check the branch, `git status`, and that `HEAD` matches (`git -C ~/workspace/hwhl rev-parse HEAD` on the mini). The helper treats a different `HEAD` or modified tracked files as blockers. Reconcile through Git with the task's commit/push authority; otherwise report the blocker.
2. **Dry run** from the laptop's repository root:

   ```bash
   python3 skills/sync-control-machines/scripts/hwhl_sync.py status ritchie@10.1.0.231
   ```

   Exit 0 means it can apply, and 2 means a conflict or blocker. Show Ritchie the action list.
3. **Resolve conflicts** if any. Get Ritchie's choice per path, then pass it on the apply as `--take local:<path>` or `--take remote:<path>` (repeatable).
4. **Apply:**

   ```bash
   python3 skills/sync-control-machines/scripts/hwhl_sync.py apply ritchie@10.1.0.231 [--take ...]
   ```

   It re-reads both sides afterwards, prints `verified: both machines match for every synced path` on success, and records the new base at `~/.local/state/hwhl-sync/<peer>.json` on the laptop.
5. **Report** the counts (pushed, pulled, deleted), any blockers left, and the Terraform serial on each side.

## Details

- **Transport:** SSH with `StrictHostKeyChecking=yes`, `ForwardAgent=no`, `BatchMode=yes`. An unknown or changed host key fails; verify it out-of-band, never relax checking.
- **Permissions:** received files keep only the owner bits of the source (minimum `0600`), and new directories are `0700`. Symlinks such as `homelab_config/ansible/inventory/group_vars/all.yml` are recreated as symlinks.
- **Backups:** before any file is overwritten or deleted, the old copy goes to `~/.local/state/hwhl-sync/backups/<timestamp>/<path>` on that machine. To undo one sync, copy files back from there, then run `status` to confirm.
- **First run or lost manifest:** without a recorded base, files present on one side only are copied, and files that differ are conflicts. A deletion before the first sync looks like a new file on the other side.
- The remote half of the helper runs under the peer's `python3` (Python 3.9 on the mini, from the Command Line Tools); keep `scripts/hwhl_sync.py` 3.9-compatible.
- Checkout location on the peer defaults to `workspace/hwhl` relative to its home (`--remote-repo` to change).
