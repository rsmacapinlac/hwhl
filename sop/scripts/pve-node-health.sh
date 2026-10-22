#!/bin/sh
# pve-node-health.sh: read-only health summary for one Proxmox node.
# Run from ansible/: ansible proxmox_control_node_by_ip -u root -m script -a ../sop/scripts/pve-node-health.sh
# Lines starting with "!" need attention.

node=$(hostname)
echo "## $node | $(pveversion | cut -d/ -f2) | kernel $(uname -r) | up $(uptime -p | sed 's/up //')"

# Proxmox services
bad=""
for s in pve-cluster corosync pvedaemon pveproxy pvestatd pvescheduler pve-firewall lxcfs chrony; do
  [ "$(systemctl is-active $s)" = active ] || bad="$bad $s"
done
[ -n "$bad" ] && echo "! services not active:$bad" || echo "services: all active"
failed=$(systemctl --failed --no-legend --plain | awk '{print $1}' | tr '\n' ' ')
[ -n "$failed" ] && echo "! failed units: $failed"

# Cluster membership as seen from this node
echo "quorate: $(pvecm status 2>/dev/null | awk '/^Quorate/{print $2}') | nodes: $(pvecm status 2>/dev/null | awk '/^Nodes:/{print $2}') | corosync links connected: $(corosync-cfgtool -s 2>/dev/null | grep -cw connected)"
echo "time synced: $(timedatectl show -p NTPSynchronized --value)"

# Memory
free -m | awk '/Mem/{m=$3"/"$2} /Swap/{s=$3; st=$2} END{printf "mem: %sM | swap: %s/%sM\n", m, s, st; if (st>0 && s/st>0.5) print "! swap over 50%"}'
arc=$(cat /sys/module/zfs/parameters/zfs_arc_max 2>/dev/null)
[ -n "$arc" ] && [ "$arc" != 0 ] && echo "zfs arc_max: $((arc / 1024 / 1024))M"

# Storage: every PVE storage this node can see, plus thin pool metadata
# "disabled" means the storage isn't enabled for this node, so skip it
pvesm status 2>/dev/null | awk 'NR>1 && $3!="disabled"{u=$7+0; flag=($3!="active" || u>85) ? "! " : ""; printf "%sstorage %s: %s %s\n", flag, $1, $3, $7}'
lvs --noheadings -o vg_name,lv_name,data_percent,metadata_percent -S segtype=thin-pool 2>/dev/null |
  awk '{flag=($3>85 || $4>75) ? "! " : ""; printf "%sthin %s/%s: data %s%% meta %s%%\n", flag, $1, $2, $3, $4}'
if [ -n "$(zpool list -H 2>/dev/null)" ]; then
  z=$(zpool status -x 2>/dev/null)
  [ "$z" = "all pools are healthy" ] && echo "zfs: $z" || echo "! zfs: $z"
fi

# Disks: SMART health plus the counters worth trending week to week
for d in $(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'); do
  h=$(smartctl -H /dev/$d 2>/dev/null | grep -oE 'PASSED|FAILED|OK' | head -1)
  # Prints the counters, then "|bad" if any of them is non-zero
  attrs=$(smartctl -A /dev/$d 2>/dev/null | awk '
    $1 ~ /^[0-9]+$/ && $2 ~ /Reallocated_Sector|Current_Pending|Offline_Uncorrect|Bad_Blk/ {
      printf "%s=%s ", $2, $10; n = split($10, v, "/"); for (i = 1; i <= n; i++) if (v[i] + 0 > 0) bad = 1 }
    /^Percentage Used|^Media and Data Integrity Errors/ {
      split($0, a, ":"); gsub(/ /, "", a[1]); gsub(/ /, "", a[2]); printf "%s=%s ", a[1], a[2]
      if (a[1] ~ /^Media/ && a[2] + 0 > 0) bad = 1 }
    END { if (bad) printf "|bad" }')
  model=$(lsblk -dno MODEL /dev/$d | tr -s ' ' | sed 's/ $//')
  flag=""
  { [ "$h" = FAILED ] || [ "${attrs%|bad}" != "$attrs" ]; } && flag="! "
  echo "${flag}disk $d ($model): ${h:-no SMART} ${attrs%|bad}"
done

# Kernel and journal
hangs=$(journalctl -k -b -q --no-pager 2>/dev/null | grep -c "Hardware Unit Hang")
[ "$hangs" -gt 0 ] && echo "! NIC hardware hangs since boot: $hangs"
echo "journal errors 24h: $(journalctl -p err --since -24h -q --no-pager | wc -l) | 7d: $(journalctl -p err --since -7d -q --no-pager | wc -l) | kernel errors since boot: $(journalctl -k -p err -b -q --no-pager | wc -l)"
echo "top error sources 7d: $(journalctl -p err --since -7d -q --no-pager -o json --output-fields=SYSLOG_IDENTIFIER,_COMM | python3 -c '
import collections, json, sys
c = collections.Counter((json.loads(l).get("SYSLOG_IDENTIFIER") or json.loads(l).get("_COMM") or "?") for l in sys.stdin)
print(" ".join("%s=%d" % kv for kv in c.most_common(4)))')"
hung=$(journalctl -k --since -7d -q --no-pager | grep -c "blocked for more than")
[ "$hung" -gt 0 ] && echo "! hung tasks 7d: $hung"
oom=$(journalctl -k --since -7d -q --no-pager | grep -ci "out of memory")
[ "$oom" -gt 0 ] && echo "! OOM kills 7d: $oom"

# Guests on this node
for id in $(pct list | awk 'NR>1{print $1}'); do
  conf=/etc/pve/lxc/$id.conf
  st=$(pct status $id | awk '{print $2}')
  grep -q '^onboot: 1' $conf && [ "$st" != running ] && echo "! CT $id onboot but $st"
  grep -q '^lock:' $conf && echo "! CT $id locked: $(awk '/^lock:/{print $2}' $conf)"
done
for id in $(qm list | awk 'NR>1{print $1}'); do
  conf=/etc/pve/qemu-server/$id.conf
  st=$(qm status $id | awk '{print $2}')
  grep -q '^onboot: 1' $conf && [ "$st" != running ] && echo "! VM $id onboot but $st"
  grep -q '^lock:' $conf && echo "! VM $id locked: $(awk '/^lock:/{print $2}' $conf)"
  if [ "$st" = running ] && grep -qE '^agent: (1|enabled=1)' $conf; then
    qm agent $id ping >/dev/null 2>&1 || echo "! VM $id guest agent not responding"
  fi
done
echo "guests: CT $(pct list | awk 'NR>1 && $2=="running"' | wc -l)/$(pct list | awk 'NR>1' | wc -l) running, VM $(qm list | awk 'NR>1 && $3=="running"' | wc -l)/$(qm list | awk 'NR>1' | wc -l) running"

# Housekeeping
end=$(openssl x509 -enddate -noout -in /etc/pve/local/pve-ssl.pem | cut -d= -f2)
openssl x509 -checkend 2592000 -noout -in /etc/pve/local/pve-ssl.pem >/dev/null || echo "! pve-ssl cert expires within 30 days"
newest=$(ls /boot/vmlinuz-* | sed 's|/boot/vmlinuz-||' | sort -V | tail -1)
[ "$newest" != "$(uname -r)" ] && echo "reboot pending: newest installed kernel is $newest"
echo "pve-ssl expires: $end | apt upgradable: $(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)"
