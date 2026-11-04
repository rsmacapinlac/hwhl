#!/usr/bin/env python3
"""Two-way sync of hwhl's Git-ignored working files with a peer control machine.

Tracked files travel through Git. Everything a checkout needs that Git ignores
(homelab_config/, ignored role files, Terraform state, reports/) is synced here
with a three-way comparison against the hashes recorded at the last sync, so a
file moves only when exactly one side changed it. File contents are never
printed: output is paths, actions and reasons only.

Run from the machine that can SSH to the peer:

    hwhl_sync.py status ritchie@10.1.0.231          # dry run (default)
    hwhl_sync.py apply  ritchie@10.1.0.231          # refuses if anything is in conflict
    hwhl_sync.py apply  ritchie@10.1.0.231 --take local:homelab_config/x.yml

The remote half of this file runs on the peer through `python3 -` and must
stay compatible with Python 3.9 (macOS Command Line Tools).
"""
import argparse
import glob
import hashlib
import json
import os
import shlex
import subprocess
import sys
import time

# Paths synced when Git ignores them; tracked paths are always skipped.
WALK_ROOTS = ["homelab_config", "reports"]
GLOB_DIRS = ["ansible/roles/*/files"]
GLOB_FILES = ["terraform/terraform.tfstate", "terraform/terraform.tfstate.*", "terraform/.proxmox-token"]
SKIP_NAMES = {".DS_Store"}
TMP_SUFFIX = ".hwhl-sync-tmp"
TF_STATE = "terraform/terraform.tfstate"
TF_LOCK = "terraform/.terraform.tfstate.lock.info"
MASS_DELETE = 10
STATE_DIR = os.path.expanduser(os.environ.get("HWHL_SYNC_STATE_DIR", "~/.local/state/hwhl-sync"))


# ---------------------------------------------------------------- remote-safe

def _hash_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _candidates(repo):
    paths = set()
    roots = list(WALK_ROOTS)
    for pattern in GLOB_DIRS:
        roots += [os.path.relpath(p, repo) for p in glob.glob(os.path.join(repo, pattern)) if os.path.isdir(p)]
    for root in roots:
        top = os.path.join(repo, root)
        for dirpath, dirnames, filenames in os.walk(top):
            # os.walk does not descend into symlinked dirs; list them as links.
            for name in list(dirnames) + filenames:
                full = os.path.join(dirpath, name)
                if name in dirnames and not os.path.islink(full):
                    continue
                paths.add(os.path.relpath(full, repo))
    for pattern in GLOB_FILES:
        for p in glob.glob(os.path.join(repo, pattern)):
            paths.add(os.path.relpath(p, repo))
    return sorted(p for p in paths
                  if os.path.basename(p) not in SKIP_NAMES and not p.endswith(TMP_SUFFIX))


def list_tree(repo):
    """Describe the syncable files under *repo* (runs on either machine)."""
    repo = os.path.abspath(os.path.expanduser(repo))
    git = ["git", "-C", repo]
    tracked = set(subprocess.run(git + ["ls-files", "-z"], check=True,
                                 stdout=subprocess.PIPE).stdout.decode().split("\0"))
    head = subprocess.run(git + ["rev-parse", "HEAD"], check=True,
                          stdout=subprocess.PIPE).stdout.decode().strip()
    dirty = subprocess.run(git + ["status", "--porcelain", "--untracked-files=no"], check=True,
                           stdout=subprocess.PIPE).stdout.decode().splitlines()
    entries = {}
    for rel in _candidates(repo):
        if rel in tracked:
            continue
        full = os.path.join(repo, rel)
        st = os.lstat(full)
        if os.path.islink(full):
            entries[rel] = {"kind": "link", "hash": "link:" + os.readlink(full), "mode": 0o777,
                            "size": 0, "mtime": int(st.st_mtime)}
        elif os.path.isfile(full):
            entries[rel] = {"kind": "file", "hash": _hash_file(full), "mode": st.st_mode & 0o777,
                            "size": st.st_size, "mtime": int(st.st_mtime)}
    tf = None
    if os.path.isfile(os.path.join(repo, TF_STATE)):
        try:
            with open(os.path.join(repo, TF_STATE)) as f:
                data = json.load(f)
            tf = {"serial": data.get("serial"), "lineage": data.get("lineage")}
        except ValueError:
            tf = {"serial": None, "lineage": None}
    return {"repo": repo, "home": os.path.expanduser("~"), "head": head, "dirty_tracked": len(dirty), "entries": entries,
            "tf_state": tf, "tf_locked": os.path.exists(os.path.join(repo, TF_LOCK))}


if __name__ == "__main__" and sys.argv[1:2] == ["--list"]:
    json.dump(list_tree(sys.argv[2]), sys.stdout)
    sys.exit(0)


# ------------------------------------------------------------ initiator only

class Peer:
    def __init__(self, target, repo, python):
        self.target, self.repo, self.python = target, repo, python
        # Socket paths must stay under ~104 bytes, so not inside STATE_DIR.
        control = os.path.expanduser("~/.ssh/hwhl-sync-%C")
        self.ssh = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
                    "-o", "ForwardAgent=no", "-o", "ConnectTimeout=10",
                    "-o", "ControlMaster=auto", "-o", "ControlPath=" + control,
                    "-o", "ControlPersist=60", target]

    def run(self, command, stdin=None, capture=True):
        return subprocess.run(self.ssh + [command], input=stdin, check=True,
                              stdout=subprocess.PIPE if capture else None).stdout

    def list_tree(self):
        with open(os.path.abspath(__file__), "rb") as f:
            source = f.read()
        out = self.run("%s -I - --list %s" % (shlex.quote(self.python), shlex.quote(self.repo)), stdin=source)
        return json.loads(out)


def plan(local, remote, base, takes):
    """Decide an action per path: same, push, pull, delete-local, delete-remote, conflict."""
    actions = []
    for rel in sorted(set(local["entries"]) | set(remote["entries"]) | set(base)):
        l, r, b = local["entries"].get(rel), remote["entries"].get(rel), base.get(rel)
        lh, rh = l and l["hash"], r and r["hash"]
        if lh == rh:
            action, why = ("same", "") if lh else (None, "")
        elif rel in takes:
            side = takes[rel]
            if side == "local":
                action, why = ("push" if lh else "delete-remote"), "operator took local"
            else:
                action, why = ("pull" if rh else "delete-local"), "operator took remote"
        elif b is None:
            if lh is None:
                action, why = "pull", "new on remote"
            elif rh is None:
                action, why = "push", "new on local"
            else:
                action, why = "conflict", "differs and never synced"
        elif lh == b:
            action, why = ("pull", "changed on remote") if rh else ("delete-local", "deleted on remote")
        elif rh == b:
            action, why = ("push", "changed on local") if lh else ("delete-remote", "deleted on local")
        else:
            action, why = "conflict", "changed on both sides since last sync"
        if action:
            actions.append((action, rel, why))
    return actions


def blockers(local, remote, actions, allow_mass_delete=False):
    found = []
    # A wiped or re-cloned checkout looks like a mass deletion; never mirror it blindly.
    deletes = [a for a in actions if a[0].startswith("delete")]
    if len(deletes) > MASS_DELETE and not allow_mass_delete:
        found.append("%d deletions planned (limit %d): check a checkout was not wiped; "
                     "--allow-mass-delete only with Ritchie's approval" % (len(deletes), MASS_DELETE))
    if local["head"] != remote["head"]:
        found.append("Git HEAD differs (local %s, remote %s): sync tracked files through Git first"
                     % (local["head"][:7], remote["head"][:7]))
    for side, info in (("local", local), ("remote", remote)):
        if info["dirty_tracked"]:
            found.append("%s has %d modified tracked file(s): commit or reconcile through Git"
                         % (side, info["dirty_tracked"]))
    tf_moves = [a for a in actions if a[1].startswith("terraform/") and a[0] not in ("same",)]
    if tf_moves and (local["tf_locked"] or remote["tf_locked"]):
        found.append("Terraform state lock present; a Terraform run may be in progress")
    lt, rt = local["tf_state"], remote["tf_state"]
    for action, rel, _ in actions:
        if rel != TF_STATE or action not in ("push", "pull"):
            continue
        if lt and rt and lt["lineage"] != rt["lineage"]:
            found.append("Terraform state lineage differs between machines: unrelated states, do not overwrite")
        src, dst = (lt, rt) if action == "push" else (rt, lt)
        if src and dst and (src["serial"] or 0) < (dst["serial"] or 0):
            found.append("Terraform state would move backwards (serial %s over %s)" % (src["serial"], dst["serial"]))
    return found


def report(local, remote, actions, problems):
    counts = {}
    for action, rel, why in actions:
        counts[action] = counts.get(action, 0) + 1
        if action != "same":
            print("%-13s %s%s" % (action, rel, "  (%s)" % why if why else ""))
    print("summary: " + ", ".join("%s=%d" % kv for kv in sorted(counts.items())) if counts else "summary: nothing to sync")
    for side, info in (("local", local), ("remote", remote)):
        tf = info["tf_state"]
        print("%s: git %s, terraform serial %s" % (side, info["head"][:7], tf and tf["serial"]))
    for p in problems:
        print("BLOCKER: " + p)


def backup_cmd(path, backup_root, rel):
    dest = os.path.join(backup_root, rel)
    return "if [ -e %s ] || [ -L %s ]; then mkdir -p %s && cp -pP %s %s; fi" % (
        shlex.quote(path), shlex.quote(path), shlex.quote(os.path.dirname(dest)),
        shlex.quote(path), shlex.quote(dest))


def apply(peer, local, remote, actions, stamp):
    local_backups = os.path.join(STATE_DIR, "backups", stamp)
    remote_backups = os.path.join(remote["home"], ".local/state/hwhl-sync/backups", stamp)
    done = {"push": "pushed", "pull": "pulled", "delete-remote": "deleted-remote", "delete-local": "deleted-local"}
    for action, rel, _ in actions:
        if action == "same":
            continue
        lpath = os.path.join(local["repo"], rel)
        rpath = os.path.join(remote["repo"], rel)
        q = shlex.quote
        if action == "push":
            e = local["entries"][rel]
            if e["kind"] == "link":
                cmd = "umask 077; %s; mkdir -p %s; rm -f %s; ln -s %s %s" % (
                    backup_cmd(rpath, remote_backups, rel), q(os.path.dirname(rpath)), q(rpath),
                    q(e["hash"][5:]), q(rpath))
                peer.run(cmd)
            else:
                mode = "%o" % max(e["mode"] & 0o700, 0o600)
                tmp = rpath + TMP_SUFFIX
                cmd = "set -e; umask 077; %s; mkdir -p %s; cat > %s; chmod %s %s; mv -f %s %s" % (
                    backup_cmd(rpath, remote_backups, rel), q(os.path.dirname(rpath)), q(tmp),
                    mode, q(tmp), q(tmp), q(rpath))
                with open(lpath, "rb") as f:
                    peer.run(cmd, stdin=f.read())
        elif action == "pull":
            e = remote["entries"][rel]
            subprocess.run(["sh", "-c", "umask 077; " + backup_cmd(lpath, local_backups, rel)], check=True)
            old_umask = os.umask(0o077)
            try:
                os.makedirs(os.path.dirname(lpath), exist_ok=True)
                if e["kind"] == "link":
                    if os.path.lexists(lpath):
                        os.remove(lpath)
                    os.symlink(e["hash"][5:], lpath)
                else:
                    data = peer.run("cat %s" % q(rpath))
                    tmp = lpath + TMP_SUFFIX
                    with open(tmp, "wb") as f:
                        f.write(data)
                    os.chmod(tmp, max(e["mode"] & 0o700, 0o600))
                    os.replace(tmp, lpath)
            finally:
                os.umask(old_umask)
        elif action == "delete-remote":
            peer.run("umask 077; %s; rm -f %s" % (backup_cmd(rpath, remote_backups, rel), q(rpath)))
        elif action == "delete-local":
            subprocess.run(["sh", "-c", "umask 077; %s; rm -f %s" % (backup_cmd(lpath, local_backups, rel), q(lpath))],
                           check=True)
        print("%-15s %s" % (done[action], rel))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("mode", choices=["status", "apply"])
    ap.add_argument("peer", help="ssh target, e.g. ritchie@10.1.0.231")
    ap.add_argument("--remote-repo", default="workspace/hwhl", help="peer checkout, relative to its home")
    ap.add_argument("--remote-python", default="python3")
    ap.add_argument("--take", action="append", default=[], metavar="local|remote:PATH",
                    help="resolve one conflict by taking that side (repeatable)")
    ap.add_argument("--allow-mass-delete", action="store_true",
                    help="permit more than %d deletions in one run" % MASS_DELETE)
    args = ap.parse_args()

    takes = {}
    for t in args.take:
        side, _, rel = t.partition(":")
        if side not in ("local", "remote") or not rel:
            ap.error("--take expects local:PATH or remote:PATH")
        takes[rel] = side

    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    manifest_path = os.path.join(STATE_DIR, "%s.json" % args.peer.replace("/", "_").replace("@", "_at_"))
    base = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            base = json.load(f)["hashes"]

    local_repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    peer = Peer(args.peer, args.remote_repo, args.remote_python)
    local, remote = list_tree(local_repo), peer.list_tree()
    actions = plan(local, remote, base, takes)
    problems = blockers(local, remote, actions, args.allow_mass_delete)
    conflicts = [a for a in actions if a[0] == "conflict"]

    report(local, remote, actions, problems)
    if args.mode == "status":
        sys.exit(2 if conflicts or problems else 0)
    if conflicts or problems:
        print("apply refused: resolve conflicts/blockers first")
        sys.exit(2)

    stamp = time.strftime("%Y%m%dT%H%M%S")
    apply(peer, local, remote, actions, stamp)

    # Re-read both sides and record every path that now matches as the new base.
    local, remote = list_tree(local_repo), peer.list_tree()
    after = plan(local, remote, base, {})
    unsynced = [a for a in after if a[0] != "same"]
    hashes = dict(base)
    for rel in set(base) | set(local["entries"]) | set(remote["entries"]):
        l, r = local["entries"].get(rel), remote["entries"].get(rel)
        if l and r and l["hash"] == r["hash"]:
            hashes[rel] = l["hash"]
        elif not l and not r:
            hashes.pop(rel, None)
    old_umask = os.umask(0o077)
    try:
        with open(manifest_path + ".tmp", "w") as f:
            json.dump({"peer": args.peer, "synced_at": stamp, "hashes": hashes}, f, indent=1, sort_keys=True)
        os.replace(manifest_path + ".tmp", manifest_path)
    finally:
        os.umask(old_umask)
    print("backups (if any): ~/.local/state/hwhl-sync/backups/%s on each machine" % stamp)
    if unsynced:
        for a in unsynced:
            print("STILL DIFFERENT %s %s" % (a[0], a[1]))
        sys.exit(1)
    print("verified: both machines match for every synced path")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        # Report which step failed without echoing any transferred data.
        print("FAILED (exit %s): %s" % (exc.returncode, exc.cmd[-1] if isinstance(exc.cmd, list) else exc.cmd),
              file=sys.stderr)
        sys.exit(1)
