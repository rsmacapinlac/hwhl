# Homelab Health Baseline and Remediation Plan

| | |
|---|---|
| **Baseline taken** | 2026-10-01, read-only, all 4 Proxmox nodes and all 19 running LXCs |
| **Purpose** | (1) Confirm everything is healthy *before* the PVE 9 upgrade. (2) Record a known-good baseline to diff against after each node is upgraded. |
| **Related** | [proxmox-8-to-9-upgrade-plan.md](proxmox-8-to-9-upgrade-plan.md) — this is its Phase 0 |

## 1. Verdict

Everything that should be running is running: every node quorate with all PVE
services up, every `onboot` CT running, every managed CT reachable by Ansible,
Docker up everywhere, DNS and time sync working inside every CT, no OOM kills, no
firing alerts.

But **two things are not healthy, and they compound**:

1. **midosuji `sda` is failing**: 16 pending + 16 offline-uncorrectable sectors,
   3 reported-uncorrectable, 38k power-on hours. That disk is `local-baracuda`,
   which holds the root disks of **smarthome (225)**, monitor-midosuji (217) and
   yamaguchi (103).
2. **midosuji has had no backups since 2026-01-06** (see upgrade plan §3.1).

So Home Assistant / TeslaMate are on a degrading disk with no backup. That is the
single most important thing in this document, and it should be fixed this week
regardless of the upgrade.

## 2. Findings, prioritized

### P0: data at risk (fix before anything else)

| # | Finding | Evidence | Action |
|---|---|---|---|
| H1 | **Failing disk on midosuji** | `sda` ST2000DM008 (Barracuda 2TB): `Current_Pending_Sector=16`, `Offline_Uncorrectable=16`, `Reported_Uncorrect=3`, 48 smartd errors/day. No SMART self-test ever run. | 1) Back up 225 and 217 now (needs H2). 2) Run `smartctl -t long /dev/sda` to see whether it's getting worse. 3) Move 225/217 off the disk (see §4). 4) Retire or replace the disk. |
| H2 | **midosuji backups broken since 2026-01-06** | `pvescheduler`: `could not update job state, skipping - no such task` every minute; no vzdump for 103/217/225/306/500/501 on the NAS | Upgrade plan §3.1: clear stale job state, `tmpdir: /var/tmp` in `/etc/vzdump.conf`, manual backup of each CT |

#### H2 resolution (2026-10-01)

- **Cause:** `/var/lib/pve-manager/jobs/vzdump-fe416…:1.json` was stuck at
  `"state":"started"` for a UPID that no longer existed, so the scheduler treated
  the job as still running and skipped every run. The file was moved to
  `/root/pve-fix-2026-10-01/stale-job-state.json` on midosuji, and `pvescheduler`
  was restarted. The state is now `created` and the log error is gone.
- **Manual backups taken.** All passed `zstd -t` and `pvesm extractconfig`:

  | CT | Mode | Archive | Size | Duration |
  |---|---|---|---|---|
  | 306 drive | snapshot | `vzdump-lxc-306-2026_10_01-17_24_06` | 6.7G | 3m |
  | 500 boogienet-core | snapshot | `vzdump-lxc-500-2026_10_01-17_27_01` | 10.4G | 10m |
  | 501 boogienet-utils | snapshot | `vzdump-lxc-501-2026_10_01-17_36_53` | 5.0G | 2m |
  | 217 monitor-midosuji | suspend, `--tmpdir /var/tmp` | `vzdump-lxc-217-2026_10_01-17_39_02` | 1.1G | 1m |
  | 103 yamaguchi | stop (already stopped) | `vzdump-lxc-103-2026_10_01-17_39_52` | 7.6G | 7m | **protected** |
  | 225 smarthome | stop | `vzdump-lxc-225-2026_10_01-21_32_08` | 11.5G | 18m (~10m of it clean shutdown) | **protected** |

  smarthome was offline 21:32–21:50. All 11 of its containers came back up. The
  30 GiB read from the failing `sda` produced no new read errors (pending is still 16).
- **Deliberately not changed:** `/etc/vzdump.conf` (no global `tmpdir`). A
  31G suspend-mode staging copy of 225 would nearly fill midosuji's root
  (34G free). The nightly job is left as is (user decision). Expect it to keep
  failing on 225 (and possibly 217, which is on the same `dir` storage) until H1
  moves them to `local-lvm`. Check the first nightly run on 2026-10-02.
- **First nightly run after the fix (2026-10-02 01:00):** midosuji ran again.
  103, 306, 500 and 501 backed up OK. **217 and 225 failed** with the expected
  rsync `chown … Operation not permitted` on the NFS temp dir (217 failed too,
  as predicted). Their 2026-10-01 manual archives are intact, and both CTs kept
  running. The job also errors on teshima VM 100 (H3). fukutomi and izumida: all OK.
- **Noted:** midosuji's thin pool is overcommitted: 576G of thin volumes on a
  232G VG, data 68%. Relevant to H1 option A.

### P1: fix before the upgrade (they hide or cause problems)

| # | Finding | Evidence | Action |
|---|---|---|---|
| H3 | **Nightly backup job always reports errors** | teshima VM 100 `arch-test` has `ide2: ProxmoxISO:iso/archlinux-2025.07.01…iso`, which no longer exists, so the job errors every night. A real failure would look the same. | `qm set 100 --ide2 none,media=cdrom` on teshima |
| H4 | **izumida memory pressure** | 23.2/32G RAM used, **6.4/8G swap** used. CT limits total 64G (216 8G + 302 8G + 303 24G + 304 24G). `ritchie` has 3.8G in swap. | Not an outage today, but a reboot/upgrade makes things worse if anything spikes. Lower 303/304 limits to what they actually use, or accept and watch it. |
| H5 | **boogienet-core (500) root at 88%** | 3.8G free of 32G | `pct resize 500 rootfs +16G` (local-lvm has room), or clean up. Not managed by this repo. |
| H6 | **Monitoring coverage is thin** | Each monitor-* Prometheus has only **2 active targets**. monitor-midosuji's `pihole` target `10.1.0.15:9617` is DOWN (`context deadline exceeded`). Nothing scrapes the Proxmox nodes themselves, and SMART isn't alerted on (that's how H1 went unnoticed). | Post-upgrade project: `pve-exporter` + node-exporter on the nodes, a SMART alert, and a backup-age alert. Fix the pihole scrape now, or note it as known. |

### P2: cleanup (not blocking)

| # | Finding | Action |
|---|---|---|
| H7 | teshima: **106 errors/day** `open database /etc/aliases.db: No such file or directory` (postfix) | `newaliases` |
| H8 | family: **`ofelia` exited 2026-02-14** (1 scheduled job, from the monica role). Monica's scheduled tasks haven't run for 7 months. | Check the job and restart via `site.yml --limit family -t ofelia` (or decide it isn't needed) |
| H9 | CTs on fukutomi/izumida/midosuji show **19–42 pending apt updates**; teshima CTs show 0 | Run `maintenance.yml` for those groups on Friday, *before* the upgrade window (and before the R3 change if you want it parallel) |
| H10 | `local-baracuda/images/109`: 30G orphan disk with no CT 109 config | Delete after H1 is handled (or leave; it goes with the disk) |
| H11 | `/mnt/pve/ProxmoxBackups` has stale dumps of deleted guests (220–224, 323, 400, VM 600) | Prune when convenient |
| H12 | `transmission-openvpn` on vcr: 5 lifetime restarts | VPN is connected now and the logs are clean, so just a baseline number. Re-check after izumida's upgrade. |

## 3. Baseline (known-good snapshot)

Compare against this after each node upgrade. Anything new is a regression.

### 3.1 Nodes

| Check | fukutomi | midosuji | izumida | teshima |
|---|---|---|---|---|
| PVE services¹ | all active | all active | all active | all active |
| `systemctl --failed` | none | none | none | none |
| Corosync links | 3/3 | 3/3 | 3/3 | 3/3 |
| RAM used / total | 2.7 / 15.9G | 7.5 / 32G | **23.2 / 32G** | 8.8 / 48G |
| Swap used | 0.5G | 2.7G | **6.4G** | 4.0G |
| `local-lvm` data / meta | 54% / 2.8% | 68% / 3.2% | 50% / 1.9% | 65% / 2.2% |
| Other storage | local-wdred 0% | local-baracuda 20% | Media (ZFS) 70%, healthy | data 10% |
| Disks (SMART) | sda KingFast SSD OK, sdb WD Red 2T OK | **sda Barracuda 2T FAILING**, sdb MX500 OK | sda ST4000 OK, sdb WD Blue SSD OK | sda generic SSD (no attrs), sdb WD SSD OK, nvme0 WD OK |
| Kernel errors (dmesg) | 3: `zstd blocked >122s` (vzdump to NFS) | 0 | 18: EXT4 orphan cleanup (vzdump snapshots) | 20: same |
| Journal errors / 24h | 0 | 96 (all smartd → H1) | 3 | 114 (106 aliases.db → H7) |
| OOM kills / 7d | 0 | 0 | 0 | 0 |
| `onboot` CTs not running | 0 | 0 | 0 | 0 |
| pve-ssl cert expires | 2028-04-19 | 2028-04-19 | 2027-12-01 | 2028-09-12 |

¹ pve-cluster, corosync, pvedaemon, pveproxy, pvestatd, pvescheduler, pve-firewall,
lxcfs, chrony. `pve-ha-lrm/crm` are active on fukutomi and midosuji and inactive on
the others. That's normal with no HA resources.

### 3.2 Containers

| CT | Node | Up | Docker running/total | Not-running containers | Root used | Pending apt |
|---|---|---|---|---|---|---|
| dns0 | fukutomi | 15w | 4/4 | — | 14% | 24 |
| dns1 | fukutomi | 15w | 3/3 | — | 9% | 24 |
| dns2 | fukutomi | 15w | 3/3 | — | 22% | 24 |
| dns3 | fukutomi | 15w | 3/3 | — | 8% | 24 |
| edge | fukutomi | 15w | 6/6 | — | 5% | 24 |
| monitor-fukutomi | fukutomi | 15w | 6/6 | — | 1% | 24 |
| smarthome | midosuji | 15w | 11/11 | — | 15% | 42 |
| drive | midosuji | 15w | 16/17 | `nextcloud-aio-watchtower` (expected for AIO) | 7% | 19 |
| monitor-midosuji | midosuji | 13w | 5/5 | — | 1% | 24 |
| boogienet-core | midosuji | — | 10/10 | — | **88%** | n/a |
| boogienet-utils | midosuji | — | 7/7 | — | 20% | n/a |
| vcr | izumida | 15w | 18/18 | — (transmission-openvpn 5 restarts) | 13% | 19 |
| ritchie | izumida | 5w | 18/19 | `mail-tribble` (run-to-completion job, exit 0, expected) | 28% | 19 |
| media | izumida | 5w | 8/8 | — | 21% | 19 |
| monitor-izumida | izumida | 15w | 5/5 | — | 1% | 24 |
| family | teshima | 6w | 27/28 | `ofelia` (H8) | 12% | 0 |
| bot | teshima | 4d | 7/7 | — | 32% | 0 |
| media-support | teshima | 6w | 5/5 | — | 5% | 0 |
| monitor-teshima | teshima | 6w | 5/5 | — | 1% | 0 |

Every managed CT: DNS resolution ok, NTP synchronized, all expected `/data/*`
mount points present, 2–4 journal errors / 24h.

Not checked from inside: **yamaguchi (103)** (stopped, privileged, `onboot: 0`)
and VM 100 `arch-test` (stopped).

### 3.3 Known-benign noise (don't chase these after the upgrade)

- `run-rpc_pipefs.mount` failed inside most unprivileged CTs. `nfs-common` can't
  mount rpc_pipefs without privileges. Present on dns0–3, edge, monitors, ritchie,
  media, media-support. Absent on vcr, drive, bot, family, smarthome, monitor-teshima.
- `EXT4-fs (dm-N): write access unavailable, skipping orphan cleanup` comes from
  vzdump mounting read-only snapshots.
- `INFO: task zstd blocked for more than 122 seconds` on fukutomi happens during a
  backup to NFS.
- `nextcloud-aio-watchtower` and `mail-tribble` exited with code 0. That's by design.

## 4. Options for H1 (the failing disk)

What's on `local-baracuda` (midosuji `sda`): 225 smarthome (224G file, 31G
used), 103 yamaguchi (110G), 109 orphan (30G), 217 monitor-midosuji (14G).

| Option | How | Trade-off |
|---|---|---|
| A. Move to midosuji `local-lvm` | `pct move-volume 225 rootfs local-lvm` (CT stopped). Same for 217. | Thin pool is 68% used. Check free space first (`lvs pve/data`). Restores live data, so it's fine with a read error on the way **only if** a backup exists first. |
| B. Move to another node | `pct migrate 225 <node> --restart --target-storage local-lvm` | smarthome is **privileged** and passes through `/dev/ttyUSB0/1` (HubZ stick on midosuji). The stick would have to move too. teshima has an identical HubZ stick. |
| C. Restore from backup onto good storage | `vzdump` → `pct restore 225 … --storage local-lvm` | Cleanest, since it also proves the backup restores. Needs H2 done. |
| D. Replace the disk | New disk, re-create `local-baracuda` | Still need A/B/C to move the data off first. |

Recommended order: **H2 → backup 225/217 → verify archive → C (restore to
`local-lvm`, which also tests the backup) → retire `sda`.** The final choice is
yours (see the questions at the end).

## 5. Execution plan

Before the upgrade weekend, roughly in this order:

| Step | What | Where | Est. | Done |
|---|---|---|---|---|
| 1 | H2: fix the midosuji scheduler | midosuji | 20m | [x] 2026-10-01 |
| 2 | Back up 225, 217, 306, 500, 501 (+103?) and confirm each archive | midosuji | 1–2h | [x] 2026-10-01 |
| 3 | `smartctl -t long /dev/sda` (runs in the background for hours; check `smartctl -l selftest`) | midosuji | — | [ ] |
| 4 | H1: move 225/217 off `local-baracuda` per §4 | midosuji | 1h | [ ] |
| 5 | H3: detach the missing ISO from VM 100 | teshima | 1m | [ ] |
| 6 | H7: `newaliases` (now in the proxmox role, tag `mail`) | teshima | 1m | [x] 2026-10-26 |
| 7 | H5: grow boogienet-core root | midosuji | 5m | [ ] |
| 8 | H9: `maintenance.yml` for CTs with pending updates | all | 30m | [ ] |
| 9 | Re-run the full health check (§6). Must match §3 except the fixed items. | all | 10m | [ ] |
| 10 | Confirm the next 01:00 backup ran **with no job errors on all four nodes** | all | — | [ ] |

Steps 4 (H1), 7 (H5), H4 and H8 can slip past the weekend only if step 2 has
produced verified backups. Without that, don't upgrade midosuji.

When to re-run the health check (§6):
- After step 9 (pre-upgrade gate)
- After each node's upgrade reboot, for that node and its CTs
- After all four nodes are done (full run)
- 24h after (catches failed nightly backups and slow leaks)

## 6. How to run the health check

All read-only. Run from the repo root with `ssh-add ~/.ssh/id_rsa` done (the
nodes only accept that key for root).

### 6.1 Nodes

```bash
cd ansible
ansible proxmox_control_node_by_ip -u root -m shell -a '
echo "## $(hostname) | $(pveversion | cut -d/ -f2) | kernel $(uname -r)"
echo "svcs: $(for s in pve-cluster corosync pvedaemon pveproxy pvestatd pvescheduler pve-firewall lxcfs chrony; do printf "%s=%s " $s $(systemctl is-active $s); done)"
echo "failed: $(systemctl --failed --no-legend --plain | awk "{print \$1}" | tr "\n" " ")"
echo "quorum: $(pvecm status | grep -E "^Quorate" | tr -s " ") | links: $(corosync-cfgtool -s | grep -cw "connected")"
echo "mem: $(free -m | awk "/Mem/{print \$3\"/\"\$2}")M swap: $(free -m | awk "/Swap/{print \$3\"/\"\$2}")M"
echo "thin: $(lvs --noheadings -o data_percent,metadata_percent pve/data | tr -s " ")"
echo "zfs: $(zpool status -x 2>/dev/null)"
echo "smart: $(for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}"); do printf "%s=%s " $d "$(smartctl -H /dev/$d 2>/dev/null | grep -oE "PASSED|FAILED|OK" | head -1)"; done)"
echo "pending-sectors: $(for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}"); do smartctl -A /dev/$d 2>/dev/null | awk -v d=$d "/Current_Pending_Sector/{printf \"%s=%s \", d, \$10}"; done)"
echo "nfs: $(findmnt -rn -t nfs,nfs4 -o TARGET | wc -l) mounts"
echo "journal-err-24h: $(journalctl -p err --since -24h -q --no-pager | wc -l) | oom-7d: $(journalctl -k --since -7d -q --no-pager | grep -ci "out of memory")"
for id in $(pct list | awk "NR>1{print \$1}"); do grep -q "^onboot: 1" /etc/pve/lxc/$id.conf && [ "$(pct status $id | cut -d" " -f2)" != running ] && echo "  NOT RUNNING: $id"; done
'
```

### 6.2 Managed containers

Save as a script (the Docker Go templates must not go through Jinja, so use
`-m script` rather than `-m shell`):

```bash
#!/bin/sh
# ct-health.sh: run with: ansible 'managed_hosts:!raspberrypi' -b -m script -a ct-health.sh -f 20
echo "## $(hostname) | up $(uptime -p | sed 's/up //') | mem $(free -m | awk '/Mem/{printf "%d/%dM", $3, $2}') | root $(df -h / --output=pcent | tail -1)"
echo "failed: $(systemctl --failed --no-legend --plain | awk '{print $1}' | tr '\n' ' ')"
echo "dns: $(getent hosts google.com >/dev/null && echo ok || echo FAIL) | ntp: $(timedatectl show -p NTPSynchronized --value) | apt: $(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)"
echo "mounts: $(findmnt -rn -o TARGET | grep -E '^/data' | tr '\n' ' ')"
echo "journal-err-24h: $(journalctl -p err --since -24h -q --no-pager | wc -l)"
if command -v docker >/dev/null; then
  echo "docker: $(systemctl is-active docker) | running $(docker ps -q | wc -l)/$(docker ps -aq | wc -l)"
  docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -v -E 'Up [^(]*$|Up .*\(healthy\)' | sed 's/^/  ! /'
  for c in $(docker ps -q); do r=$(docker inspect -f '{{.RestartCount}} {{.Name}}' $c); [ "${r%% *}" -gt 0 ] && echo "  restarts: $r"; done
fi
```

boogienet-core/utils aren't in the inventory. Check them from midosuji:
`pct exec 500 -- docker ps -a` and `pct exec 501 -- docker ps -a`.

### 6.3 Monitoring and backups

```bash
# Prometheus targets + firing alerts on every monitor host
ansible prometheus -b -m shell -a 'curl -s "localhost:9090/api/v1/targets?state=active" | python3 -c "import json,sys; d=json.load(sys.stdin)[\"data\"][\"activeTargets\"]; print(len(d), \"targets\"); [print(\"DOWN\", t[\"scrapeUrl\"]) for t in d if t[\"health\"]!=\"up\"]"'

# Latest backup per CT (expect today's date for every onboot CT)
ansible 10.1.0.144 -u root -m shell -a 'for id in $(pvesh get /cluster/resources --type vm --output-format json | python3 -c "import json,sys; print(\" \".join(str(v[\"vmid\"]) for v in json.load(sys.stdin)))"); do echo "$id $(ls -t /mnt/pve/ProxmoxBackups/dump/vzdump-*-$id-*.zst 2>/dev/null | head -1 | grep -oE "[0-9]{4}_[0-9]{2}_[0-9]{2}" || echo NONE)"; done'
```

### 6.4 Service reachability (after each node; the human part)

| Node | Spot-check |
|---|---|
| fukutomi | `dig @<each pihole IP> google.com`; any Traefik-routed URL loads; WireGuard client connects |
| midosuji | Home Assistant UI loads and Zigbee/Z-Wave devices respond; Nextcloud loads; TeslaMate shows a recent update |
| izumida | Jellyfin plays something; Sonarr/Radarr UIs load; transmission shows the VPN IP |
| teshima | Vaultwarden login; Immich timeline; Paperless search |

## 7. Follow-ups (after the upgrade)

- Turn §6.1/§6.2 into `ansible/health-check.yml` so this becomes one command
  (similar in spirit to `sop/maintenance-service-version-audit.md`).
- Monitoring (H6): node exporters on the Proxmox nodes, `prometheus-pve-exporter`,
  alerts for SMART pending sectors, backup age > 26h, swap > 75%, CT root > 85%.
- Schedule SMART long tests monthly (`smartd.conf` `-s L/../../7/03`).

## 8. Questions (answer later)

1. **H1**: which option for the failing disk (§4)? Is a replacement disk on hand?
2. **yamaguchi (103)**: 110G on the failing disk, last backup failed. Keep, back up, or let it go?
3. **H4 izumida memory**: right-size 303/304, or accept?
4. **H8 ofelia/monica**: is Monica still used? If not, retire it rather than fix ofelia.
5. **boogienet (500/501)**: who owns them? Is growing 500's disk okay?
