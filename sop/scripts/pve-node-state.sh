#!/bin/sh
# pve-node-state.sh: read-only hardware and configuration facts for one Proxmox node, as markdown.
# Part of the state snapshot (see "Current-state snapshot" in sop/proxmox-cluster-health-check.md).
# Run from ansible/: ansible proxmox_control_node_by_ip -u root -m script -a ../sop/scripts/pve-node-state.sh

node=$(hostname)
ip=$(hostname -I | awk '{print $1}')
hw="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
cpu=$(awk -F: '/model name/{sub(/^ +/, "", $2); print $2; exit}' /proc/cpuinfo | tr -s ' ')
ram=$(free -m | awk '/Mem/{printf "%.0fG", $2 / 1024}')
[ -d /sys/firmware/efi ] && boot=UEFI || boot="legacy BIOS"
gpus=$(lspci | grep -Ei 'vga|3d controller' | cut -d: -f3- | sed 's/^ //; s/ (rev [0-9a-f]*)//' | paste -sd ';' | sed 's/;/; /g')
nics=""
for i in /sys/class/net/*; do
  [ -e "$i/device" ] || continue
  n=$(basename "$i"); drv=$(basename "$(readlink "$i/device/driver")")
  sp=$(cat "$i/speed" 2>/dev/null); [ -n "$sp" ] && [ "$sp" -gt 0 ] 2>/dev/null && sp="${sp}Mb/s" || sp="down"
  nics="$nics${nics:+; }$n ($drv, $sp)"
done

echo "### $node ($ip)"
echo
echo "| Item | Value |"
echo "|---|---|"
echo "| Hardware | $hw |"
echo "| CPU | $cpu ($(nproc) threads) |"
echo "| RAM | $ram |"
echo "| PVE / kernel | $(pveversion | cut -d/ -f2) / $(uname -r) |"
echo "| Boot | $boot |"
echo "| GPU | ${gpus:-none} |"
echo "| NICs | $nics |"
echo
echo "| Disk | Model | Size | Type | SMART | Used by |"
echo "|---|---|---|---|---|---|"
# Skips empty card-reader slots (size 0)
lsblk -dbno NAME,TYPE,SIZE,ROTA,TRAN | awk '$2=="disk" && $3 > 0' | while read d type bytes rota tran; do
  size=$(lsblk -dno SIZE /dev/$d | tr -d ' ')
  model=$(lsblk -dno MODEL /dev/$d | tr -s ' ' | sed 's/ $//')
  case "$tran" in nvme) kind=NVMe ;; usb) kind=USB ;; *) [ "$rota" = 1 ] && kind=HDD || kind=SSD ;; esac
  smart=$(smartctl -H /dev/$d 2>/dev/null | grep -oE 'PASSED|FAILED|OK' | head -1)
  used=$(pvs --noheadings -o pv_name,vg_name 2>/dev/null | awk -v d="/dev/$d" 'index($1, d) == 1 {print "LVM " $2}' | sort -u)
  pool=$(zpool list -v -H -L -P 2>/dev/null | awk -v d="/dev/$d" '!/^\t/{p=$1} /^\t/ && index($1, d) == 1 {print "ZFS " p}' | sort -u)
  mnts=$(lsblk -no MOUNTPOINT /dev/$d | grep -v '^$' | sed 's|^/boot/efi$|EFI|; s|^\[SWAP\]$|swap|' | sort -u)
  u=$(printf '%s\n%s\n%s\n' "$used" "$pool" "$mnts" | grep -v '^$' | paste -sd ',' | sed 's/,/, /g')
  echo "| $d | ${model:-?} | $size | $kind | ${smart:-n/a} | ${u:-unused} |"
done
echo
echo "| Storage | Type | Status | Size | Used |"
echo "|---|---|---|---|---|"
pvesm status 2>/dev/null | awk 'NR>1 && $3!="disabled"{printf "| %s | %s | %s | %.0fG | %s |\n", $1, $2, $3, $4 / 1048576, $7}'
