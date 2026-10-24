# midosuji Replacement Plan

| | |
|---|---|
| **Status** | **Superseded 2026-10-24.** midosuji was retired without a replacement node: its guests moved to teshima and izumida, and it was removed from the cluster (see [interhigh-proxmox-cluster-maintenance.md](interhigh-proxmox-cluster-maintenance.md), Phase 2). Kept for history |
| **Goal** | Replace midosuji (10.1.0.142) with a new machine, move all its guests over, and remove midosuji from the cluster |
| **Placeholder names** | New node = **`NEWNODE`**, IP **`10.1.0.145`** (see §10 questions) |
| **Related** | [proxmox-8-to-9-upgrade-plan.md](proxmox-8-to-9-upgrade-plan.md), [homelab-health-baseline.md](homelab-health-baseline.md) (H1, H2) |

## 1. Why, and the key idea

midosuji is the weakest node: its `sda` (`local-baracuda`) is failing (H1), it
carries PVE 7-era leftovers, it has a stale `/etc/hosts` (`pve8to9` FAIL), and
`smarthome` can't be backed up nightly from its `dir` storage.

**Key idea: don't upgrade midosuji at all.** Install PVE 9 fresh on the new
machine, join it once the other three nodes are on PVE 9, migrate midosuji's
guests to it (PVE 8 → 9 migration is the supported direction), then remove
midosuji. That drops the riskiest node out of the upgrade weekend and fixes H1
for free.

```
Now            Upgrade weekend                Replacement window          Done
──────────────────────────────────────────────────────────────────────────────────
NEWNODE:       install PVE 9, burn-in   →     join cluster, migrate  →    4 nodes, all PVE 9
fukutomi,
izumida,
teshima:       PVE 8 ──► PVE 9
midosuji:      PVE 8 (not upgraded) ─────────► guests leave ─────────────► delnode, wipe
```

## 2. What has to move

| CT | Name | Current storage | Real usage | Configured | Special handling |
|---|---|---|---|---|---|
| 225 | smarthome | `local-baracuda` (**failing**) | 31G disk / 2.3G RAM | 220G / 28G | **Privileged**; `dev0/dev1: /dev/ttyUSB0/1` (HubZ stick, physical move); not in Terraform; IP 10.1.0.40 |
| 306 | drive (Nextcloud AIO) | `local-lvm` | 13G / 3.4G | 235G / **160G** (misconfig) | Bind mounts `/mnt/ContainerBackups`, `/mnt/NextCloud` (NFS on host); in Terraform |
| 500 | boogienet-core | `local-lvm` | 26G (88% full) / — | 32G / 2G | `keyctl=1`; not in this repo |
| 501 | boogienet-utils | `local-lvm` | 12G / — | 63G / 1G | `keyctl=1`; not in this repo |
| 217 | monitor-midosuji | `local-baracuda` (**failing**) | 2.6G / 0.3G | 860G / 8G | Per-node monitor; name is node-specific; in Terraform |
| 103 | yamaguchi | `local-baracuda` (**failing**) | 110G file | 240G / 16G | Stopped; protected backup exists; keep or drop? |
| — | `images/109` | `local-baracuda` | 30G orphan | — | No config. Drop with the disk. |

Total real usage is about **85G of disk and 10G of RAM** today, plus 103 if kept.

### 2.1 smarthome's hardware and network dependencies

Surveyed 2026-10-02 (CT config, host USB tree, every Docker container's device
mappings, HA `core.config_entries`).

| Dependency | What it is | Used by | Moves how |
|---|---|---|---|
| **HubZ stick** `10c4:8a2a` (Nortek HUSBZB-1), serial `5160037E` | One USB stick, two CP210x serial ports: `if00` → `/dev/ttyUSB0` (**Z-Wave**), `if01` → `/dev/ttyUSB1` (**Zigbee**) | **ZHA on `/dev/ttyUSB1` @ 57600: 34 Zigbee devices.** The Z-Wave port is passed through but **unused** (no `zwave_js` integration). | **Physically, the same stick.** The Zigbee network (PAN ID, network key, coordinator IEEE) lives on the stick + `/data/containers/homeassistant/zigbee.db`. A different stick would mean re-pairing all 34 devices. |
| USB passthrough chain | Host `/dev/ttyUSB0/1` → CT `dev0/dev1` → Docker `devices:` (hardcoded in `ansible/roles/homeassistant/templates/docker-compose.j2`) → ZHA path `/dev/ttyUSB1` | homeassistant container | The `ttyUSBn` names must be the same on the new host (see D4) |
| Matter | `matter-server` on **host networking** + `/run/dbus`. 3 Matter devices, IPv6 link-local on `eth0` | matter integration | Needs the CT on the **same L2 LAN** with **IPv6 enabled** on the bridge (Matter commissioning/operation uses IPv6 link-local + mDNS). Fabric data moves with the CT. Thread devices (if any) depend on an external border router, not this host. |
| LAN-discovered devices | Wemo (SSDP), Tasmota/MQTT, Roku, Reolink, OctoPrint, Roborock, Nest, Wyze (wyze-bridge) | various | IP-based. Fine as long as the CT keeps **IP 10.1.0.40 and MAC `BC:24:11:D3:63:34`** (a migration keeps both; a restore needs `--unique 0`, the default) |
| ContainerBackups NFS | Mounted **inside** the CT (not a host bind mount) at `/mnt/ContainerBackups`; HA backups go to `apps/homeassistant` | homeassistant | Moves with the CT, just needs `10.1.0.95` reachable |
| ~~Bluetooth~~ | No adapter on midosuji | — | Nothing to move |
| ~~Quadro P400~~ | NVIDIA GPU in midosuji, **not used** by any guest (no driver loaded) | — | Nothing to move. Hardware can be reused. |
| ~~Uni Class HID `10d5:6555`~~ | Keyboard/KVM receiver on the host | — | Not passed through |

**Implications for the new machine:**
- **The HubZ stick goes in the new machine.** Plug it into a USB 2.0 port or
  a short extension; USB 3 ports radiate 2.4GHz noise that hurts Zigbee range.
  **Placement matters too:** the Zigbee mesh was formed around midosuji's physical
  location. If the new machine sits somewhere else, expect some devices to take
  time (or a repeater) to re-route.
- **No other USB-serial device on the new host**, or the `ttyUSB` numbering may
  shift. (teshima's spare HubZ stick must not end up in the same box.)
- **Same LAN segment, IPv6 not disabled** on `vmbr0`, for Matter.

## 3. Hardware checklist for the new machine

| Item | Minimum | Recommended | Why |
|---|---|---|---|
| RAM | 16G | **32G+** | Guests use about 10G. Headroom lets it take load off izumida (H4) later. |
| Boot/VM disk | 500G SSD | **2× SSD (≥1TB), ZFS mirror** | We just lost trust in a single disk. A mirror survives the next one. |
| NIC | 1GbE | **Intel** (e1000e/igc/igb) | fukutomi's Realtek r8169 is the cluster's weakest NIC. Avoid adding another. |
| USB | 1 free port | Rear port, ideally on a short USB 2.0 extension | HubZ Zigbee/Z-Wave stick moves from midosuji. USB 3 ports can interfere with 2.4GHz Zigbee. |
| Firmware | UEFI | UEFI, Secure Boot off (or enrolled) | Matches the PVE 9 default and avoids the grub-efi trap fukutomi hit |
| Console | — | Monitor + keyboard reachable | No IPMI anywhere in the cluster |

## 4. Phase A: prepare the new machine (before / independent of the upgrade weekend)

Nothing here touches the cluster.

1. **Burn-in**: run memtest86+ for one full pass. Run `smartctl -t long` on every disk
   (from any live USB or after install) and confirm 0 pending/reallocated sectors.
2. **Install PVE 9** (latest ISO) with:
   - Hostname `NEWNODE.<domain>`, IP `10.1.0.145/24`, gateway `10.1.0.1`, DNS `1.1.1.1`
     (same as the other nodes; the nodes don't depend on the Pi-holes)
   - Filesystem: **ZFS RAID1** if there are two disks (creates `local-zfs`), otherwise
     ext4 + LVM-thin (creates `local-lvm`, matching the cluster). See §10 Q3.
3. **Repos**: switch to `pve-no-subscription` deb822 sources and disable enterprise
   (same as upgrade plan §7.2). Then `apt update && apt full-upgrade`, reboot.
4. **NIC naming**: `pve-network-interface-pinning generate`, so the name can't change on a kernel bump.
5. **Root SSH**: add `~/.ssh/id_rsa.pub` (Ansible access) and the terraform key to
   `/root/.ssh/authorized_keys`. After the cluster join, the shared
   `/etc/pve/priv/authorized_keys` takes over.
6. **Time**: `chronyc tracking` is synced. Corosync is sensitive to clock skew.
7. **Verify it's a clean join candidate**: no guests, no extra storage, and
   `/etc/hosts` maps `NEWNODE` to `10.1.0.145` (**not** 127.0.1.1 or an old IP. midosuji's
   `pve8to9` FAIL was exactly this).

**Do not join the cluster yet.**

## 5. Phase B: repo prep (before the join)

| # | Change | File | Notes |
|---|---|---|---|
| B1 | **Repoint the Terraform API endpoint off midosuji** | `homelab_config/terraform.tfvars`: `proxmox_host`, `proxmox_endpoint` → `10.1.0.141` (or teshima `.144`) | Today Terraform talks to midosuji, so removing midosuji would break every plan. The API token is cluster-wide, so only the URL changes. **Do this first; it can happen now.** |
| B2 | Add `"NEWNODE" = "10.1.0.145"` to `proxmox_node_ips` | `terraform.tfvars` | Regenerates `[proxmox_control_node_by_ip]` in the generated inventory |
| B3 | **Make the `proxmox` role trixie-aware** (upgrade plan R1) | `ansible/roles/proxmox/tasks/main.yml` | **Hard prerequisite.** The new node is trixie from day 1, and the role writes `bookworm` lines into `sources.list`. |
| B4 | Run `proxmox-setup.yml --limit 10.1.0.145` | — | Installs `python3-proxmoxer`, LXC templates, and the **5 NFS mounts** in `/etc/fstab` (`/mnt/ContainerBackups`, `/mnt/SavedMedia`, `/mnt/Documents`, `/mnt/NextCloud`, `/mnt/Photos`). The drive CT's bind mounts need `/mnt/NextCloud` and `/mnt/ContainerBackups` on the host **before** it migrates. |

## 6. Phase C: join the cluster (after the three other nodes are on PVE 9)

Preconditions:
- fukutomi, izumida and teshima are on PVE 9, quorate, and healthy (health check §6)
- midosuji is still on PVE 8 (fine: it's leaving)
- Phase A and B1–B4 are done

```bash
# on NEWNODE
pvecm add 10.1.0.141          # join via fukutomi; prompts for root password of fukutomi
pvecm status                  # Nodes: 5, Quorate: Yes (expected votes 5, quorum 3)
```

After the join:
- [ ] Web UI shows 5 nodes. `/etc/pve` is replicated (`ls /etc/pve/nodes/`).
- [ ] Storage on NEWNODE:
  - `ProxmoxBackups` and `ProxmoxISO` (cluster-wide NFS) show **active**
  - `local-lvm`: if NEWNODE is ZFS, restrict it to the other nodes (`pvesm set local-lvm --nodes fukutomi,izumida,teshima,midosuji`)
  - `local-zfs`: if NEWNODE is ZFS, add it as `zfspool` storage with `nodes NEWNODE`
- [ ] The backup job (`all 1`) now includes NEWNODE automatically. Nothing to change.
- [ ] Ansible reaches it: `ansible 10.1.0.145 -u root -m ping`

## 7. Phase D: migrate guests

Order: easiest first, smarthome last (it needs a person at both machines).
Every migration is a **restart migration**: the CT stops, its disk copies over
1GbE, and it starts on NEWNODE. LXC has no live migration.

Before each one: a fresh backup exists (the nightly is fine for local-lvm CTs).
After each one: run the container health check (health baseline §6.2) for that CT.

`TARGET` below is `local-lvm` or `local-zfs`, depending on §10 Q3.

### D1. boogienet-utils (501), then boogienet-core (500)

```bash
pct migrate 501 NEWNODE --restart --target-storage TARGET
pct migrate 500 NEWNODE --restart --target-storage TARGET
# while 500 is down/after: grow its root (H5)
pct resize 500 rootfs +16G
```

Validate: `pct exec 50x -- docker ps -a` shows the same containers as the baseline.
Coordinate with whoever owns boogienet (§10 Q6).

### D2. drive (306), Nextcloud

```bash
pct set 306 --memory 8192          # fix the 160G limit before it moves (H-baseline note)
pct migrate 306 NEWNODE --restart --target-storage TARGET
```

Then **Terraform state**. `node_name` isn't in `ignore_changes`, so editing
`node = "midosuji"` → `"NEWNODE"` would plan a **destroy + recreate**. Instead:

```bash
# terraform.tfvars: drive.node = "NEWNODE"
./bin/terraform.sh state rm 'module.services_containers["drive"].proxmox_virtual_environment_container.container'
./bin/terraform.sh import  'module.services_containers["drive"].proxmox_virtual_environment_container.container' NEWNODE/306
./bin/terraform.sh plan    # must show NO destroy/replace for drive
```

The `terraform_data` helpers (mount points, mount features) may plan to re-run
their `pct set … && pct reboot` local-exec. That's harmless but reboots the CT,
so either accept it or `-target` around it.

Validate: Nextcloud loads through Traefik, `/data/NextCloud` and `/data/borgbackup` are mounted inside.

### D3. monitor-midosuji (217): replace, don't move

It's a per-node monitor with a node-specific name and nothing worth keeping
(2.6G, metrics only). It lives on the failing disk.

1. Add `monitor-NEWNODE` to `services_containers` in `terraform.tfvars` (copy the
   `monitor-midosuji` block, new vmid/IP, `node = "NEWNODE"`). Copy
   `homelab_config/hosts/monitor-midosuji/` → `homelab_config/hosts/monitor-NEWNODE/`.
2. `./bin/terraform.sh apply`, then `host-setup.yml` (with the terraform key, per
   memory) and `site.yml --limit monitor-NEWNODE…`.
3. Remove the `monitor-midosuji` block from tfvars and `terraform apply` (destroys 217).
   Remove its `homelab_config/hosts/` dir.
4. While there, fix the down pihole scrape target (H6).

### D4. smarthome (225), Home Assistant + TeslaMate

Planned downtime: **~45–60 min** (about 10 min clean shutdown, copy, and a USB move).
Do it at a quiet time and tell the household.

1. **USB naming**: keep `dev0: /dev/ttyUSB0` and `dev1: /dev/ttyUSB1` as they are.
   PVE creates the device node inside the CT at the same path as on the host, and
   ZHA plus the compose file both expect `/dev/ttyUSB1`. Switching to
   `/dev/serial/by-id/…` would mean changing the compose template and ZHA's config too.
   Instead, guarantee the numbering on the new host: with the HubZ as the only
   CP210x device, `if00` → `ttyUSB0` and `if01` → `ttyUSB1` deterministically.
   (Optional hardening, later: a host udev rule plus a template change to by-id paths.)
2. Stop 225. Take a **fresh stop-mode backup** (yesterday's protected one is the fallback).
3. Migrate it, reading the failing disk one last time:
   ```bash
   pct migrate 225 NEWNODE --restart --target-storage TARGET
   ```
   **Fallback** if the copy hits a read error: restore the fresh backup onto NEWNODE
   (`pct restore 225 <archive> --storage TARGET --rootfs TARGET:64`). This also
   right-sizes the 220G disk. Remove the dead 225 from midosuji first.
4. **Move the HubZ stick** from midosuji to NEWNODE **before starting 225** (if
   `/dev/ttyUSB0/1` don't exist, the CT won't start). On NEWNODE, verify:
   ```bash
   ls -l /dev/serial/by-id/   # …5160037E-if00-port0 -> ../../ttyUSB0
                              # …5160037E-if01-port0 -> ../../ttyUSB1   (Zigbee)
   ```
5. Start 225. Validate: HA UI loads, ZHA shows the coordinator online and **34 Zigbee
   devices** reporting (give battery devices ~30 min), the 3 Matter devices respond, TeslaMate
   logs a fresh update, Mosquitto clients reconnect, and all 11 containers are up.
6. Because it's now on block storage, **snapshot-mode nightly backups work**. Confirm
   the next 01:00 run backs up 225 (closes H1/H2's remaining failure).

### D5. yamaguchi (103), per §10 Q4

- Keep: `pct restore 103 <protected 2026-10-01 archive> --storage TARGET` on NEWNODE (leave stopped).
- Drop: nothing to do. The protected archive stays on the NAS until you unprotect it.

## 8. Phase E: decommission midosuji

Only after every guest is on NEWNODE, validated, and **one clean nightly backup
cycle** has run on NEWNODE.

```bash
# on midosuji: confirm it's empty
pct list; qm list                        # nothing
# power it off for good, then from another node:
pvecm delnode midosuji
pvecm status                             # Nodes: 4, Quorate: Yes
rm -r /etc/pve/nodes/midosuji            # after confirming nothing needed is in there
```

Then:
- [ ] `storage.cfg`: remove `local-baracuda` (only used by midosuji). Drop
  `midosuji` from any `nodes` lists (`local-lvm` restriction if you added one).
- [ ] `terraform.tfvars`: remove `"midosuji"` from `proxmox_node_ips`, then `terraform apply`
  (regenerates the inventory without .142).
- [ ] `ssh-keygen -R 10.1.0.142` / `-R midosuji` on the workstation. Remove stale entries
  from `/etc/pve/priv/known_hosts`.
- [ ] **Never boot midosuji back onto the LAN with its old install.** It still thinks it's
  in the cluster. Wipe or reinstall before reusing the hardware. The good disks
  (`sdb` MX500) are reusable; the Barracuda `sda` is not.
- [ ] Update docs and memory: the node list (.141/.143/.144/.145), the
  `proxmox-root-uses-id-rsa` memory, `AGENTS.md` if it lists nodes, and the health
  baseline §3 with NEWNODE's numbers.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Join fails / corrupts cluster config | Join only with a quorate, healthy cluster. NEWNODE must be empty. Back up `/etc/pve` from a node first (`tar czf /root/etc-pve-$(date +%F).tgz /etc/pve`). |
| `terraform apply` destroys drive after the node change | `state rm` + `import` (D2) and **read the plan**. Never apply with a `-/+` on drive. |
| smarthome read error mid-migration (failing disk) | Fresh stop-mode backup immediately before. The protected 2026-10-01 archive is a second fallback. |
| Zigbee doesn't come back | Same stick (network keys live on the stick + `zigbee.db`), same `/dev/ttyUSB1` path, HA config untouched. Check the by-id → ttyUSB mapping before start. Move the stick back to midosuji as a fallback, since midosuji isn't removed until Phase E. |
| Removing midosuji before Terraform is repointed | B1 is done first, in Phase B |
| 5-node cluster temporarily | Quorum is 3 of 5, so it tolerates any 2 down. Fine. |

## 10. Questions (answer later)

1. **Hardware**: what's the machine (CPU, RAM, disks, NIC)? That decides §3/§4 choices.
2. **Name and IP**: keep the naming theme (e.g. another Yowamushi Pedal name)? `10.1.0.145` free?
3. **Filesystem**: ZFS mirror (two disks) or ext4/LVM-thin (one disk, matches the cluster)?
4. **yamaguchi (103)**: restore on NEWNODE, or let it go?
5. **Timing**: the same weekend as the upgrade (Sunday, after the three nodes), or a separate window?
6. **boogienet (500/501)**: who needs a heads-up before their restart migration?
7. **Beyond midosuji's guests**: should NEWNODE also take a Pi-hole (spreading DNS off
   fukutomi) or relieve izumida's memory pressure (H4)?

## 11. Progress log

| Date | Phase | Step | Result | Notes |
|---|---|---|---|---|
| 2026-10-02 | — | Plan written | Done | |
| | A | Hardware burn-in + PVE 9 install | | |
| | B | B1 Terraform endpoint off midosuji | | |
| | B | B3 trixie-aware `proxmox` role + B4 setup | | |
| | C | Join cluster | | |
| | D | 501, 500 | | |
| | D | 306 + Terraform state | | |
| | D | monitor-NEWNODE / retire 217 | | |
| | D | 225 smarthome + USB | | |
| | D | 103 | | |
| | E | delnode midosuji, cleanup | | |
