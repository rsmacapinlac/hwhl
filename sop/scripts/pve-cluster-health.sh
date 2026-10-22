#!/bin/sh
# pve-cluster-health.sh: read-only cluster-wide checks. Run once, on any one node.
# Run from ansible/: ansible 10.1.0.144 -u root -m script -a ../sop/scripts/pve-cluster-health.sh
# Lines starting with "!" need attention.

BACKUP_DIR=${BACKUP_DIR:-/mnt/pve/ProxmoxBackups/dump}

echo "## cluster $(pvecm status | awk '/^Name:/{print $2}')"
pvecm status | awk '/^Quorate|^Expected votes|^Total votes|^Nodes:/'
pvesh get /cluster/status --output-format json | python3 -c '
import json, sys
for n in json.load(sys.stdin):
    if n.get("type") == "node":
        print(("" if n.get("online") else "! ") + "node %s: %s" % (n["name"], "online" if n.get("online") else "OFFLINE"))'
echo "ha: $(ha-manager status 2>/dev/null | grep -c '^service') resources | replication jobs: $(pvesr list 2>/dev/null | awk 'NR>1' | wc -l)"

# Backup jobs over the last 7 days: one line per vzdump task
pvesh get /cluster/tasks --output-format json | python3 -c '
import json, sys, time
week = time.time() - 7 * 86400
tasks = [t for t in json.load(sys.stdin) if t.get("type") == "vzdump" and t.get("starttime", 0) > week]
print("vzdump tasks 7d: %d" % len(tasks))
for t in sorted(tasks, key=lambda t: t["starttime"]):
    dur = (t.get("endtime", 0) - t["starttime"]) / 60 if t.get("endtime") else 0
    ok = t.get("status") == "OK"
    print("%s %s %s %4.0f min %s" % ("" if ok else "!", time.strftime("%Y-%m-%d %H:%M", time.localtime(t["starttime"])), t["node"], dur, t.get("status", "running")))'

# Every guest, including ones Ansible doesn't manage: root disk and memory use as Proxmox sees them
pvesh get /cluster/resources --type vm --output-format json | python3 -c '
import json, sys
for v in sorted(json.load(sys.stdin), key=lambda v: v["vmid"]):
    if v["status"] != "running":
        continue
    disk = 100.0 * v["disk"] / v["maxdisk"] if v.get("maxdisk") and v.get("disk") else None
    mem = 100.0 * v["mem"] / v["maxmem"] if v.get("maxmem") else 0
    flag = "! " if (disk or 0) > 85 or mem > 90 else ""
    print("%sguest %s %s (%s): disk %s mem %.0f%% up %dd" % (flag, v["vmid"], v.get("name", "?"), v["node"],
          "%.0f%%" % disk if disk is not None else "n/a", mem, v.get("uptime", 0) // 86400))'

# Latest backup per guest (expect last night for every guest the backup job covers)
pvesh get /cluster/resources --type vm --output-format json | python3 -c '
import json, sys
for v in sorted(json.load(sys.stdin), key=lambda v: v["vmid"]):
    print(v["vmid"], v["type"], v.get("name", "?"), v["node"], v["status"])' |
while read id type name node status; do
  latest=$(ls -t "$BACKUP_DIR"/vzdump-*-"$id"-*.zst 2>/dev/null | head -1 | grep -oE '[0-9]{4}_[0-9]{2}_[0-9]{2}' | tr _ -)
  age=""
  [ -n "$latest" ] && age=$(( ( $(date +%s) - $(date -d "$latest" +%s) ) / 86400 ))
  flag=""
  { [ -z "$latest" ] || [ "$age" -gt 1 ]; } && [ "$status" = running ] && flag="! "
  echo "${flag}backup $id $name ($node, $status): ${latest:-NONE}${age:+ (${age}d old)}"
done
