#!/bin/sh
# ct-health.sh: read-only health summary for one managed LXC.
# Run from ansible/: ansible 'managed_hosts:!raspberrypi' -b -m script -a ../sop/scripts/ct-health.sh -f 20
# Uses -m script so the Docker Go templates never pass through Jinja.
# Lines starting with "!" need attention.

root=$(df --output=pcent / | tail -1 | tr -d ' %')
echo "## $(hostname) | up $(uptime -p | sed 's/up //') | mem $(free -m | awk '/Mem/{printf "%d/%dM", $3, $2}') | root ${root}%"
[ "$root" -gt 85 ] && echo "! root filesystem ${root}% full"
failed=$(systemctl --failed --no-legend --plain | awk '{print $1}' | grep -v '^run-rpc_pipefs.mount$' | tr '\n' ' ')
[ -n "$failed" ] && echo "! failed units: $failed"
getent hosts google.com >/dev/null || echo "! DNS resolution failed"
[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" = yes ] || echo "! time not synchronized"
echo "apt upgradable: $(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l) | journal errors 7d: $(journalctl -p err --since -7d -q --no-pager | wc -l)"

# Bind mounts from the host: an empty /data/* usually means an NFS mount went missing
for m in $(findmnt -rn -o TARGET | grep -E '^/data'); do
  [ -z "$(ls -A "$m" 2>/dev/null | head -1)" ] && echo "! mount $m is empty"
done
echo "mounts: $(findmnt -rn -o TARGET | grep -E '^/data' | tr '\n' ' ')"

if command -v docker >/dev/null; then
  echo "docker: $(systemctl is-active docker) | running $(docker ps -q | wc -l)/$(docker ps -aq | wc -l)"
  docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -v -E 'Up [^(]*$|Up .*\(healthy\)' | sed 's/^/! /'
  for c in $(docker ps -q); do
    r=$(docker inspect -f '{{.RestartCount}} {{.Name}}' $c)
    [ "${r%% *}" -gt 0 ] && echo "! restarts: $r"
  done
  docker system df --format '{{.Type}} {{.Size}} ({{.Reclaimable}} reclaimable)' | grep -i images | sed 's/^/docker /'
fi
