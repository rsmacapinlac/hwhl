#!/usr/bin/env python3
# pve-cluster-state.py: read-only snapshot of every guest and protected backup, as markdown.
# Part of the state snapshot (see "Current-state snapshot" in sop/proxmox-cluster-health-check.md).
# Run once, on any node. From ansible/: ansible 10.1.0.144 -u root -m script -a ../sop/scripts/pve-cluster-state.py
import json
import re
import subprocess
import time

BACKUP_STORAGE = "ProxmoxBackups"


def pvesh(path, *args):
    out = subprocess.run(["pvesh", "get", path, "--output-format", "json", *args],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def gib(n):
    return "%.0fG" % (n / 2**30) if n else "-"


name = next(x["name"] for x in pvesh("/cluster/status") if x["type"] == "cluster")
nodes = [x["name"] for x in pvesh("/cluster/status") if x["type"] == "node" and x.get("online")]
print("## Guests (cluster %s)\n" % name)
print("| VMID | Name | Type | Node | Status | Onboot | Cores | RAM | Root disk | Storage |")
print("|---|---|---|---|---|---|---|---|---|---|")
for g in sorted(pvesh("/cluster/resources", "--type", "vm"), key=lambda g: g["vmid"]):
    kind = "CT" if g["type"] == "lxc" else "VM"
    try:
        conf = pvesh("/nodes/%s/%s/%d/config" % (g["node"], g["type"], g["vmid"]))
    except subprocess.CalledProcessError:
        conf = {}
    if kind == "CT":
        root = conf.get("rootfs", "")
    else:
        root = next((conf[k] for k in sorted(conf) if re.fullmatch(r"(scsi|virtio|sata|ide)\d+", k)
                     and "media=cdrom" not in conf[k]), "")
    storage = root.split(":")[0] if root else "-"
    size = re.search(r"size=([0-9.]+[KMGT])", root)
    print("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
        g["vmid"], g.get("name", "?"), kind, g["node"], g["status"],
        "yes" if str(conf.get("onboot", 0)) == "1" else "no",
        conf.get("cores", "-"), gib(g.get("maxmem")), size.group(1) if size else gib(g.get("maxdisk")), storage))

print("\n## Protected backups (%s)\n" % BACKUP_STORAGE)
print("| VMID | Backup | Size | Notes |")
print("|---|---|---|---|")
rows = []
for b in pvesh("/nodes/%s/storage/%s/content" % (nodes[0], BACKUP_STORAGE), "--content", "backup"):
    if b.get("protected"):
        rows.append((b.get("vmid", 0), b["volid"].split("/")[-1], gib(b.get("size")),
                     (b.get("notes") or "").replace("\n", " ").replace("|", "/")))
for r in sorted(rows):
    print("| %s | `%s` | %s | %s |" % r)
