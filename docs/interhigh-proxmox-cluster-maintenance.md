# Interhigh Proxmox One-time Cluster Maintenance (October 2026)

Objectives:
- Retire midosuji, for other use
- Utilize hardware better within services (GPU and storage space)
- Migrate to Proxmox 9
- Physical relocation of hardware downstairs (where Teshima is located)

| Objective | Done when | Phases |
|---|---|---|
| Retire midosuji, for other use | midosuji is out of `interhigh` (`pvecm status`: 3 nodes), nothing in the cluster, repo or inventory refers to it, its P400 is out, and it's labelled and off the LAN until it's wiped for reuse | 1, 2, 3 |
| Utilize hardware better (GPU and storage space) | Both Jellyfins transcode on the P400; teshima's idle Quadro 4000s and unused 500G NVMe are out. Storage: see the open question in §8.2 | 3, 4, 5, 6 |
| Migrate to Proxmox 9 | fukutomi, izumida and teshima all run PVE 9, and the health check passes | 4 |
| Relocate hardware downstairs | fukutomi and izumida run at teshima's location, and the first night's backups finish inside their window | 3 |

## Approach

This maintenance will have multiple phases and is done in partnership with Ritchie (as there are physical tasks that are required).

This plan groups physical work required so each machine is only opened once. Only one node is ever down at a time.

1. **Phase 1:** Document the current state and verify the cluster is working and stable on Proxmox 8
2. **Phase 2:** Retire midosuji in software
   - Destroy rollback CT 225 → power off midosuji → `pvecm delnode`
3. **Phase 3:** Hardware moves
   - Pull the P400 from midosuji (its disks stay in; it stays off the LAN until it's wiped)
   - Turn off izumida
   - Install the P400 in izumida
   - izumida is re-racked downstairs (at teshima's location) and powered up
   - Verify that izumida is up in its new location: cluster quorate, guests back
   - Power down fukutomi
   - fukutomi is re-racked downstairs and powered up
   - Verify that fukutomi is up in its new location
4. **Phase 4:** Upgrade the interhigh Proxmox cluster to PVE 9, one node at a time
   - izumida → teshima → fukutomi
   - After teshima's upgrade is validated: pull its 500G NVMe and both Quadro 4000s
5. **Phase 5:** NVIDIA driver on izumida
6. **Phase 6:** GPU into Jellyfin

The driver goes in *after* the upgrade, so it is only built once, for the kernel izumida keeps.

Why this order:
- **CT 225 is smarthome's only rollback, and it lives on midosuji.** midosuji can't be powered off or removed until smarthome has proved itself on teshima.
- **The P400 can only be pulled once midosuji is off for good.** After `pvecm delnode`, midosuji must never boot onto the LAN with its old install, so it's unplugged from the network in Phase 2 and stays that way until it's repurposed.
- **izumida moves before fukutomi, never at the same time.** With 3 nodes, quorum needs 2, so fukutomi only goes down once izumida is back and the cluster is quorate.

**Out of scope:** what midosuji, its disks and the M720q are used for next. That's undecided and isn't part of this plan. This plan ends for midosuji once it has left the cluster and its P400 is out; its MX500 and Barracuda stay in the chassis.

## 1. How to run this process

Each phase below has the same parts:

- **Objective:** which objective it moves forward.
- **Downtime:** what goes down, so the right people can be warned.
- **Entry criteria:** what must be true before starting. Don't start a phase until all of them are.
- **Steps:** in order. Steps marked **[Ritchie]** are physical or need a person (hands on hardware, a phone, a TV). Everything else can be run remotely.
- **Exit gate:** what must be true before the next phase starts.
- **If it goes wrong:** what to do instead of carrying on.

Record every step in the progress log (§8) as it's done, with the date and anything unexpected. A phase is finished when its exit gate is logged as passed.

**Data lives outside this document**, in `reports/` (gitignored), following
[documenting-cluster-state.md](../sop/documenting-cluster-state.md):
- Starting state: `reports/state/2026-10-22-interhigh.md` (snapshot)
- Analysis and baselines: `reports/state/2026-10-22-interhigh-analysis.md` ("analysis notes" below)

### 1.1 Rules for every phase

1. **Only one node is down at a time, ever.** With 3 nodes, quorum needs 2. Before taking a node down, `pvecm status` must show every node and `Quorate: Yes`.
2. **Health check before and after.** Run the [health check SOP](../sop/proxmox-cluster-health-check.md) before any phase that takes a node down, and again after. Anything new in the second report came from the phase. Each run also saves a state snapshot.
3. **Fresh backups before touching a node.** A protected backup of every guest on the node, made that day.
4. **Quiet windows.** Avoid 01:00–02:30 (nightly vzdump at 01:00, Downbeat's restic 01:45–02:30).
5. **Warn people first.** The household for any outage they'd notice. The Downbeat session for anything on izumida (boogienet-core 500 and boogienet-utils 501; when they're down, Downbeat's production monitoring goes blind).
6. **Stop at the first surprise.** If a step's result doesn't match what this document says, stop, log it and decide before going on.

## 2. Phase 1: Document the current state and verify the cluster on PVE 8

**Objective:** every later phase is compared against a recorded, known-good cluster. This phase also proves smarthome is stable on teshima, which is what allows midosuji to be retired.

**Downtime:** none.

**Entry criteria:** none. Earliest finish **2026-10-24 10:00**: 48 hours after smarthome came back on teshima, covering two nightly backups.

**Steps:**

1. Run the health check. It saves the state snapshot to `reports/state/`.
2. Record what the snapshot can't collect in the analysis notes, following the standard: hardware found by hand, DNS layout, network measurements, the smarthome baseline, the health check's findings.
3. Turn each health check finding into an open item in §8.1, with the phase it must be fixed before. Then fix it, or write down why it's accepted.
4. Run `pve8to9 --full` on fukutomi, izumida and teshima. Add every FAIL and WARN to §8.1. FAILs must be fixed before Phase 4, not before Phase 2.
5. After 48 hours, run the smarthome checks S1–S10 below.
6. Run the health check again. Its report and snapshot are the baseline for every later phase.

**smarthome checks** (baseline: analysis notes §4):

| # | Check | How | Pass |
|---|---|---|---|
| S1 | CT has stayed up | `pct status 226`; `pct exec 226 -- uptime -p` | Running, with no restart since 10:00 2026-10-22 |
| S2 | All containers are healthy | The health check (`ct-health.sh` on smarthome) | 11/11 Up, restart count 0 everywhere |
| S3 | Zigbee is back | `sop/scripts/zigbee-last-seen.sh` | At least 25 devices seen in the last 24h. The only ones listed as not seen are the 9 already dead, and none of the 3 slow ones |
| S4 | ZHA has no errors | `docker logs homeassistant` filtered for `zha\|zigpy\|bellows\|ezsp` | No coordinator or radio errors, no `ttyUSB` reconnects |
| S5 | Matter | `docker logs matter-server` | Node 9 subscription still alive; device responds in HA |
| S6 | TeslaMate | TeslaMate UI / `docker logs teslamate` | New drives and charges recorded since the move |
| S7 | Nightly vzdump of 226 | Health check report (backup line for 226, vzdump task status), plus the job log for the backup mode | 2 consecutive nightly successes in **snapshot** mode |
| S8 | HA's own backups | `/mnt/ContainerBackups/apps/homeassistant` on the NAS | A new HA backup since the move |
| S9 | Automations **[Ritchie]** | HA UI → Automations / Logbook | Normal daily automations fired; nothing obviously silent |
| S10 | No new noise | HA log error count | Only the known pre-existing errors (analysis notes §4) |

**Exit gate:**
- The second health check passes, or passes with exceptions that each have a note in §8.1.
- Two consecutive nightly vzdump runs with every task `OK`, and every running guest backed up last night.
- Every §8.1 item due before Phase 2 is fixed or accepted.
- S1–S10 pass.

**If it goes wrong:**

| Failure | Action |
|---|---|
| Some live Zigbee devices never return | **[Ritchie]** Check the stick's placement on teshima (distance, USB2 port, an extension cable). Wake battery devices by pressing their button. If the mesh doesn't heal: **rollback** |
| Coordinator or radio errors | `ls -l /dev/serial/by-id/` on teshima must show `5160037E` → `ttyUSB0/1`. Make sure the spare HubZ `51501419` isn't plugged into teshima |
| Backups fail on 226 | Not a rollback reason. Fix it on teshima |
| **Rollback** (last resort) | `pct shutdown 226` → **[Ritchie]** move the stick back to midosuji → `pct set 225 --onboot 1 && pct start 225` on midosuji. Same IP and MAC, so clients don't notice. Then work out why before trying again |

## 3. Phase 2: Retire midosuji in software

**Objective:** retire midosuji.

**Downtime:** none; midosuji runs nothing.

**Entry criteria:**
- Phase 1's exit gate is passed. This phase destroys smarthome's only rollback.
- Phase 3 is planned for the same day or soon after, since midosuji stays off from here on.

**Steps:**

1. **Destroy the rollback CT.** Its protected backup `vzdump-lxc-225-2026_10_22-09_38_30` stays on the NAS.
   ```bash
   # on midosuji
   pct destroy 225 --purge 1 --destroy-unreferenced-disks 1
   pct list; qm list                        # must be empty
   ```
2. **Check that nothing else depends on midosuji:**
   ```bash
   grep -n midosuji /etc/pve/storage.cfg    # local-baracuda (+ any node lists)
   grep -n midosuji /etc/pve/jobs.cfg       # expect none (backup job is "all")
   ha-manager status                        # expect no resources
   pvesr list                               # expect no replication jobs
   ```
3. **Back up the cluster config** on teshima: `tar czf /root/etc-pve-$(date +%F).tgz /etc/pve`.
4. **Power midosuji off** (`poweroff` on midosuji). **[Ritchie]** Unplug its network cable. Wait until `pvecm status` on teshima shows it offline. It stays unplugged until it's wiped for reuse.
5. **Remove it from the cluster** (on teshima):
   ```bash
   pvecm delnode midosuji
   pvecm status          # Nodes: 3, Expected votes: 3, Quorate: Yes
   ls /etc/pve/nodes/    # if midosuji/ remains, check nothing needed is in it, then: rm -r /etc/pve/nodes/midosuji
   ```
6. **Storage config:** `pvesm remove local-baracuda`. Drop `midosuji` from any `nodes` lists.
7. **This repo:**
   - `homelab_config/terraform.tfvars`: remove `"midosuji"` from `proxmox_node_ips`. Run `./bin/terraform.sh plan`; expect only the generated inventory to change (`[proxmox_control_node_by_ip]` loses .142). `-target=local_file.ansible_inventory` does **not** avoid container drift (the inventory depends on every container), so the plan must show no container changes before applying.
   - Remove midosuji's pattern from `sop/health-check-known.txt`.
   - Update the docs and memory that list nodes .141–.144.
8. **Workstation:** `ssh-keygen -R 10.1.0.142; ssh-keygen -R midosuji`. Also remove midosuji's line from `/etc/pve/priv/known_hosts`.
9. **Tell the Downbeat session** that midosuji is gone. Its node-to-IP map still lists it, though nothing uses that entry.

**Exit gate:** `pvecm status` shows 3 nodes, 3 expected votes, Quorate: Yes. The
health check runs with midosuji gone from the report and nothing new.

**If it goes wrong:**
- `delnode` fails or quorum looks wrong: don't power anything else off. Read `journalctl -u corosync -u pve-cluster` on teshima before changing anything; the step 3 backup is a last resort.
- A smarthome problem shows up later: restore `vzdump-lxc-225-2026_10_22-09_38_30` on any node.

## 4. Phase 3: Hardware moves (one visit)

**Objective:** relocate hardware downstairs; finish retiring midosuji (P400 out); get the P400 into izumida.

**Downtime, one node at a time:**

| Node | Down for | What goes down |
|---|---|---|
| izumida | ~45 min (move + P400) | vcr (the *arr apps and downloads); ritchie and media (both Jellyfins, Audiobookshelf, Kavita, AzuraCast, TubeArchivist and the rest); monitor-izumida; dns2 (containers fall back to dns1); boogienet-core and boogienet-utils; VM 101 (Hermes) |
| fukutomi | ~20 min (move only) | dns0 (household devices fall back to dns1, each lookup waiting out the timeout first); edge (Traefik, so every `*.macapinlac.network` URL; WireGuard, so no remote access; Cloudflare DDNS); monitor-fukutomi |

**Entry criteria:**
- [ ] Phase 2's exit gate is passed; midosuji is off and unplugged from the network.
- [ ] Every §8.1 item due before Phase 3 is fixed or accepted.
- [ ] The health check passes (rule 2) and today's protected backups exist for izumida's and fukutomi's guests (rule 3).
- [ ] The household and the Downbeat session have been warned, and Downbeat has confirmed the boogienet downtime is OK.
- [x] **[Ritchie]** The P400's bracket fits izumida's case. It came out low-profile; full-height bracket fitted 2026-10-24. Its dummy HDMI plug was removed and is not going into izumida (see step 7).
- [ ] **[Ritchie]** Antistatic strap or mat.
- [ ] **[Ritchie]** Downstairs network: free switch ports and a gigabit uplink
- [ ] **[Ritchie]** Enough power outlets downstairs, on a UPS if there is one (analysis notes §3 has the power estimate).
- [ ] **[Ritchie]** Room and airflow for three towers side by side.
- [ ] **[Ritchie]** Each machine and each cable is labelled before unplugging (the beep and LED identify trick helps find them).

**Steps, midosuji:**

1. **[Ritchie]** Unplug its power (the network is already unplugged).
2. **[Ritchie]** Take out the **Quadro P400** (PCIe x16; no power cable).
3. **[Ritchie]** Leave the MX500 (`sdb`) and the Barracuda (`sda`) in; what happens to them is decided later.
4. **[Ritchie]** Label midosuji: **"Old interhigh install: don't connect to the LAN."** Before it's reused, boot an installer from USB with the network unplugged and wipe the MX500, then reconnect.

**Steps, izumida:**

5. `poweroff` on izumida. Wait for it to power off.
6. **[Ritchie]** Carry it downstairs to teshima's location.
7. **[Ritchie]** Install the P400 in the **x16 slot (J6B2)**. The BIOS (F1) must have **Devices → Video Setup → Multi-Monitor Support: Enabled** (Select Active Video stays IGD), or the slot's root port is hidden and the card isn't seen. Check by eye that the slot is free; the BIOS reports every slot "In Use". Install it **without** the dummy HDMI plug: NVENC transcoding doesn't need a display, and with a "monitor" attached the BIOS may send its output to the P400 instead of izumida's onboard video. Keep the plug in case a later use needs one.
8. **[Ritchie]** Cable it up and power it on.
9. First boot checks:
   ```bash
   lspci | grep -i nvidia                       # GP107GL [Quadro P400]
   ethtool -k eno1 | grep -E "tcp-seg|generic-seg"   # both off (NIC fix persisted)
   cat /sys/module/zfs/parameters/zfs_arc_max   # 4294967296 (ARC cap persisted)
   zpool status -x Media                        # healthy
   pct list; qm list                            # every onboot guest running
   pvecm status                                 # Nodes: 3, Quorate: Yes
   journalctl -k -b 0 | grep -c "Hardware Unit Hang"   # 0
   ```
10. Service checks: `dig @10.1.0.4 google.com` answers, the *arr UIs load, Hermes on VM 101 is back, and the Downbeat session confirms 500/501 (Prometheus targets up). **[Ritchie]** Jellyfin plays something.

**Gate before fukutomi:** izumida is up, `pvecm status` shows 3 nodes and Quorate:
Yes, and every one of its guests is back. **Never have fukutomi and izumida off at
the same time.**

**Steps, fukutomi:**

11. `poweroff` fukutomi.
12. **[Ritchie]** Move it downstairs, cable it up, power it on.
13. Checks: `pvecm status` (3 nodes, quorate); `dig @10.1.0.2 google.com`, and the same for `.3` and `.4`; one Traefik-routed URL loads; the Cloudflare DDNS record is still correct. **[Ritchie]** A WireGuard client connects (from a phone off Wi-Fi).

**Steps, after the visit:**

14. Run the health check. Compare it with Phase 1's baseline: anything new came from the move.
15. After the first night downstairs, run the health check again and read the vzdump task durations.

**Exit gate:** both nodes run downstairs, the health check has nothing new, and
the first night's vzdump finished before 01:45 with every task `OK`.

**If it goes wrong:**

| Problem | Action |
|---|---|
| izumida doesn't come back after the card goes in | **[Ritchie]** Reseat the card; try booting without it; check the BIOS shows the iGPU or PEG as primary display. Don't move fukutomi until izumida is back |
| izumida's NIC hangs return | Check TSO/GSO are still off. Then `gro off`; then a cheap Intel PCIe NIC in an x1 slot |
| A node won't rejoin the cluster | `pvecm status` and `journalctl -u corosync` on that node. Check the cable and switch port. Don't take another node down meanwhile |
| Backups run past 01:45 | Split the cluster job into per-node jobs with staggered start times, or set `bwlimit` in `/etc/vzdump.conf` |
| Streaming suffers while Tdarr runs | Limit Tdarr's worker count, or schedule it overnight outside the backup window |

## 5. Phase 4: Upgrade `interhigh` to PVE 9 (in place)

**Objective:** migrate to Proxmox 9; finish the hardware cleanup on teshima.

**Downtime:** each node once for the upgrade (~30–60 min), plus a short second
shutdown on teshima. The per-node runbook is
[proxmox-8-to-9-upgrade-plan.md](proxmox-8-to-9-upgrade-plan.md) §7, and its §8 is
the rollback. This phase adds what's specific to this cluster.

**Entry criteria:**
- [ ] Phase 3's exit gate is passed. Each node has rebooted cleanly on PVE 8 at its new location.
- [ ] Every §8.1 item due before Phase 4 is fixed or accepted.
- [ ] The health check passes on the day of the first upgrade.
- [x] fukutomi's grub-efi (upgrade plan §3.3) is fixed (2026-10-24).
- [x] The `proxmox` role is trixie-aware (R1, 2026-10-24).
- [ ] `pve8to9 --full` reports 0 FAILs. Re-run it on each node right before that node's upgrade.

**Steps:** one node at a time, in this order. Before each node: today's protected
backups for its guests, and warn whoever its downtime affects. After each node:
`pvecm status` shows 3 nodes and quorate, its guests are up, and the health check
has nothing new. Only then start the next step.

| Step | Node | Downtime affects | Node-specific checks |
|---|---|---|---|
| 1 | **izumida** | vcr, ritchie, media, monitor-izumida, dns2, boogienet-core 500 / utils 501 (warn the Downbeat session), VM 101 | Before rebooting: confirm the bootloader (`systemd-boot` on legacy boot is a pve8to9 WARN). Afterwards: the NIC fix (`post-up ethtool` in `/etc/network/interfaces`) and the ARC cap (`/etc/modprobe.d/zfs.conf`) are still in place, the NIC hang count is 0, and the `Media` pool imports |
| 2 | — | — | `./bin/terraform.sh plan` runs against the PVE 9 node with no errors |
| 3 | **teshima** | family, drive, smarthome, dns1, media-support. **[Ritchie]** Tell the household: this is the longest and most visible outage | Upgrade **with the Quadros still in**: they're its only console. Afterwards: `local-wdblue` and `local-lvm` both active; the HubZ shows as `5160037E` on `ttyUSB0/1` before CT 226 starts |
| 4 | **teshima** | Same, briefly | Pull the NVMe and both Quadros (below) |
| 5 | **fukutomi** | dns0 (dns1 covers it), edge (Traefik, WireGuard, DDNS), monitor-fukutomi | Last, so DNS and ingress keep working while the other two upgrade |

**Step 4 in detail:**

1. Confirm the NVMe is still unused:
   ```bash
   lsblk /dev/nvme0n1                 # no partitions
   pvs | grep nvme || echo unused     # not an LVM PV
   grep -n nvme /etc/pve/storage.cfg  # nothing
   ```
2. `poweroff` teshima.
3. **[Ritchie]** Remove the 500G NVMe with its PCIe adapter, and both Quadro 4000s. Keep the NVMe and adapter together; where they go is decided later.
4. **[Ritchie]** Power on with no graphics card and watch the front LED and the beeps.
   - It boots and `ping 10.1.0.144` answers within a few minutes: carry on.
   - It halts with a "no video" beep code: put back the **smallest** card available (one Quadro 4000, or better a passive low-power card such as a GT 710) so it can complete POST. The Quadros still leave; plan a replacement card.
5. Checks: `lspci | grep -i vga` shows no Quadro (or only the replacement); `lsblk` shows `sda` and `sdb`; `pvesm status` shows `local-lvm` and `local-wdblue` active; CT 226 started with the HubZ on `ttyUSB0/1`; every `onboot` guest is running.
6. **[Ritchie]** Keep one card on the shelf next to teshima for future console access.

**Exit gate:** all three nodes run PVE 9 (`pveversion`), `pvecm status` shows 3
nodes and quorate, the health check has nothing new, and `./bin/terraform.sh plan`
is clean.

**If it goes wrong:** follow upgrade plan §8: boot the previous kernel, or reinstall
PVE 9 and restore from that day's protected backups. **Stop before the next node.**

## 6. Phase 5: NVIDIA driver on izumida

**Objective:** better hardware use (the GPU half).

**Downtime:** izumida's guests, during the reboot that removes nouveau.

**Entry criteria:** Phase 4's exit gate is passed.

**Steps:** use NVIDIA's `.run` installer from the **580 series**, with DKMS (why:
analysis notes §6).

1. Install the build dependencies and blacklist nouveau, then reboot:
   ```bash
   # on izumida
   apt install proxmox-default-headers dkms build-essential pkg-config libglvnd-dev
   echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nouveau.conf
   update-initramfs -u && reboot              # (or rmmod nouveau if loaded)
   ```
2. Install the driver:
   ```bash
   wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.<ver>/NVIDIA-Linux-x86_64-580.<ver>.run
   sh NVIDIA-Linux-x86_64-580.<ver>.run --dkms --no-x-check --silent
   nvidia-smi                                 # shows the Quadro P400
   nvidia-persistenced                        # (or enable its systemd unit)
   ls -l /dev/nvidia*                         # note the majors: 195 (nvidia*), and nvidia-uvm (dynamic, e.g. 509)
   ```
3. Create `/dev/nvidia-uvm` at boot with `nvidia-modprobe -u -c=0`, from a systemd unit or `/etc/rc.local`, so containers can bind it.
4. Write the exact driver version in §8. Phase 6 installs the same file in the containers.

**Exit gate:** after a reboot, `nvidia-smi` shows the P400 and `/dev/nvidia-uvm`
exists; the health check has nothing new on izumida.

**If it goes wrong:** if the driver doesn't build, check the headers match the
running kernel (`uname -r`). After every later PVE kernel update, check
`nvidia-smi` (DKMS should rebuild the module).

Codify this in the `proxmox` role once it has been done by hand.

## 7. Phase 6: GPU into Jellyfin (ritchie 303, media 304)

**Objective:** better hardware use: both Jellyfins transcode on the P400.

**Downtime:** each CT restarts once (about 2 minutes).

**Entry criteria:** Phase 5's exit gate is passed, and these repo changes are ready
on a branch (prepare them any time before):

| Change | Where | What |
|---|---|---|
| R1 | `terraform/modules/lxc-container` | Add an `nvidia_gpu` option, alongside `tun_device`. It adds `lxc.cgroup2.devices.allow: c 195:* rwm`, the same for the `nvidia-uvm` major, and `lxc.mount.entry` binds for `/dev/nvidia0`, `nvidiactl`, `nvidia-modeset`, `nvidia-uvm` and `nvidia-uvm-tools`, through a `terraform_data` + `pct set`/conf edit like `enable_tun_device`. The uvm major is dynamic, so pass it in as a variable (read it from `/proc/devices`) |
| R2 | `homelab_config/terraform.tfvars` | `nvidia_gpu = true` on `ritchie` and `media` |
| R3 | Ansible: GPU userspace in the CT | Install the **same** `.run` with `--no-kernel-module`, then `nvidia-container-toolkit`. In `/etc/nvidia-container-runtime/config.toml` set `no-cgroups = true` (required in unprivileged LXC). Then `nvidia-ctk runtime configure --runtime=docker` and restart docker |
| R4 | `ansible/roles/jellyfin` compose template | Add GPU access, controlled by a variable: `deploy.resources.reservations.devices: [{driver: nvidia, count: all, capabilities: [gpu, video, compute, utility]}]`, plus `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all` |

**Steps:**

1. `terraform apply` for ritchie, then media.
2. `site.yml --limit ritchie,media --tags jellyfin` (and the GPU userspace task).
3. Inside each CT: `nvidia-smi` works; `docker exec jellyfin nvidia-smi` works.
4. In Jellyfin → Dashboard → Playback → Transcoding, on both:
   - Hardware acceleration: **Nvidia NVENC**
   - Decoding: H.264, HEVC, HEVC 10-bit, VP9, MPEG-2, VC-1. Leave AV1 off.
   - Allow encoding in HEVC
5. **[Ritchie]** Play an HEVC 10-bit file to a client that forces a transcode. `nvidia-smi` on izumida should show an `ffmpeg` process, and CPU should stay low.
6. **[Ritchie]** Run two streams at once (one per Jellyfin) to confirm the card is shared.

**Exit gate:** both transcodes run on the GPU, and the health check has nothing new.

**If it goes wrong:** set the Jellyfin GPU variable off and rerun `site.yml`; Jellyfin
goes back to CPU transcoding. If host and container driver versions differ, reinstall
the host's `.run` file in the container.

## 8. Progress log

| Date | Phase | Step | Result | Notes |
|---|---|---|---|---|
| 2026-10-22 | 1 | Health check, first run; snapshot saved (steps 1–2) | Done | 8 findings → §8.1 |
| 2026-10-22 | 1 | Analysis notes written (step 2) | Done | `reports/state/2026-10-22-interhigh-analysis.md` |
| 2026-10-22 | 1 | S3 Zigbee | Pass | 25 seen in 24h; only the 9 already-dead missing |
| 2026-10-22 | 3 (prep) | DNS: dns1 → teshima, dns2 → izumida, dns3 retired | Done | One Pi-hole per node |
| 2026-10-23 | 1 | Nightly vzdump, night 1 of 2 | Pass | All tasks `OK`, every running guest backed up, 226 in snapshot mode (S7 half done). Analysis notes §7 |
| 2026-10-23 | 1 | Morning spot check: S1, S2, S3 | Pass | 226 up since 10:00 10-22, 11/11 containers, 0 restarts; Zigbee 25/34 |
| 2026-10-23 | 1 | izumida swap fix (§8.1) | Done | vcr memory 8G → 12G (tfvars; the apply restarted vcr); swap flushed 7G → 0. Analysis notes §7 |
| 2026-10-24 | 1 | NIC check, all nodes | Pass | izumida 0 e1000e hangs since the 10-21 fix; fukutomi/teshima clean. Analysis notes §8 |
| 2026-10-24 | 1 | izumida swap, night 1 after the fix | Fail | Swap full again (8.1G); ritchie hit 12G after Postiz. ritchie → 16G live, swap flushed. Analysis notes §8 |
| 2026-10-24 | 1 | Nightly vzdump, night 2 of 2 | Pass | All four tasks `OK`; every running guest backed up 10-24; 226 in snapshot mode again (01:04–01:20) |
| 2026-10-24 | 1 | §8.1 items fixed or accepted (step 3) | Done | Everything due before Phase 2 is done; the rest are due later or are watch items |
| 2026-10-22 | 1 | `pve8to9 --full` on all three nodes (step 4) | Pass | 0 FAILs. WARNs → §8.1. Output: `reports/health/2026-10-22/pve8to9.txt` |
| 2026-10-24 | 1 | smarthome S1–S10 (step 5), run at 06:40 (44.5h, not 48h; both backup nights done) | Partial | Pass: S1–S8, S10. S3 24/34: the one extra missing device, `…78:78:a1` (Cheryl Bedside Lamp, IKEA bulb), is switched off at the lamp; accepted by Ritchie. S9 pass (Ritchie). Analysis notes §9 |
| 2026-10-24 | 1 | Health check, second run (step 6) | Pass with exceptions | `reports/health/2026-10-24/report.txt`; the baseline for later phases |
| 2026-10-24 | 1 | **Exit gate** | **Pass** | Both backup nights clean; §8.1 items due before Phase 2 done; S1–S10 pass (S3 lamp switched off, accepted) |
| 2026-10-24 | 2 | Destroy 225 | Done | 06:44. Backups of 225 kept on the NAS (protected 10-01 and 10-22, plus 10-24). Nothing else referenced midosuji except `local-baracuda`. `/etc/pve` backup: teshima `/root/etc-pve-2026-10-24.tgz` |
| 2026-10-24 | 2 | Power off, unplug, `pvecm delnode midosuji` | Done | Powered off 06:46; Ritchie took it off the rack. `delnode`: 3 nodes, 3 expected votes, quorate. `/etc/pve/nodes/midosuji` removed (only certs, lrm_status and an empty `.osx-proxmox` marker) |
| 2026-10-24 | 2 | Storage, tfvars, known exceptions, known_hosts cleanup | Done | `local-baracuda` removed; .142 out of tfvars and the inventory; Terraform `started` option added (bot false), `plan` clean; midosuji pattern out of `health-check-known.txt`; known_hosts cleaned (workstation and `/etc/pve/priv`) |
| 2026-10-24 | 2 | Downbeat session told; **exit gate** | **Pass** | `pvecm status`: 3 nodes, 3 expected votes, quorate. Health check has no midosuji findings and nothing new (stale same-day midosuji files had to be deleted first) |
| 2026-10-24 | 1→3 | VM 101 guest agent (§8.1) | Done | Agent answers; hung tasks traced to the 10-22 08:40 I/O stall, not VM 101 |
| 2026-10-24 | 3 | Pull P400 from midosuji, label it | Done | Ritchie, ahead of the visit (midosuji already off the rack). The P400 has a **low-profile** bracket; izumida needs a full-height one Full-height bracket fitted the same day; midosuji labelled. A dummy HDMI plug was on the card; it stays off (step 7). Both drives left in |
| 2026-10-24 | 3 | Entry criteria | Pass | Swap accepted, VM 101 agent fixed, health check 06:53, protected pre-move backups of every guest on izumida and fukutomi (07:19–08:04), household asleep, Downbeat approved |
| 2026-10-24 | 3 | Relocate izumida, install P400, boot checks | Done | Powered off **without a clean shutdown** at 08:05:35 during the move (journal recovery on every CT, all clean). P400 not detected until the BIOS change: Devices → Video Setup → Multi-Monitor Support **Enabled**, Select Active Video left on IGD. Now `01:00.0` GP107GL. Two clean reboots (08:26, 08:37). Boot checks pass: TSO/GSO off, 0 hangs, ARC 4G, `Media` healthy, 3 nodes quorate, all 8 guests up, containers up, DNS, UIs, Hermes. Downbeat confirmed 500/501 healthy. CTs 500/501 carry ext4 error flags from June 10–11, not new (Downbeat's to fsck). Jellyfin playback OK (Ritchie; CPU transcode, P400 not used until Phase 6) |
| 2026-10-24 | 3 | fukutomi GRUB (upgrade plan §3.3) | Done | ESP backed up to `/root/esp-backup-2026-10-24.tgz`; `grub-pc` → `grub-efi-amd64`, removable path forced; EFI files rewritten (were from 2022). `pve8to9`: 0 FAIL, grub WARNs gone. Next boot also runs kernel 6.8.12-43 for the first time |
| 2026-10-24 | 3 | Relocate fukutomi, checks | Done | Clean shutdown 08:49–08:50, back 08:57 on the new GRUB and kernel 6.8.12-43 (first boot of both). 3 nodes quorate; dns0, edge, monitor-fukutomi up (all containers); dns0/1/2 resolve; public sites 200; DDNS `vancouver` = current public IP; wg-easy running. WireGuard from a phone off Wi-Fi and external sites OK (Ritchie) |
| 2026-10-24 | 3 | Health check after the visit (step 14) | Pass | Run at 08:58. New: fukutomi `pvescheduler` not active (it started at 08:59:08, 2 min after boot; check ran too early), dns0 `nebula-sync` 1 restart at boot (synced fine at 09:00), teshima swap (known watch item). All three nodes now on kernel 6.8.12-43 |
| 2026-10-24 | 3 | Manual backup run instead of waiting for the first night (Ritchie's call) | Pass with incident | Job settings, all nodes, 09:03. fukutomi OK in 4 min. The backup NAS (WD 10.1.0.95) was unplugged ~09:32 mid-run: izumida (media 304) and teshima (family 305) hung on the dead NFS mount until ~12:15; stopped via the task API (snapshots removed, CTs unlocked), the 5 unfinished guests re-run 12:21–12:46, all OK (izumida 22 min, teshima 25 min). Partial 304/305 archives and `.tmp` dirs deleted (~55G). Every running guest has a 10-24 backup. Guests unaffected throughout (snapshot mode). vcr transmission-openvpn restarted 8× during the outage, healthy since 11:11 |
| 2026-10-24 | 3 | Health check after the backups (step 15) | Pass with exceptions | New: the two stopped 09:03 tasks (age out 10-31), vcr transmission-openvpn 8 restarts (NAS outage), izumida/teshima swap over 50% (accepted/watch). Tonight's 01:00 run is the first real night downstairs; check its duration tomorrow |
| | 4 | Entry criteria | | |
| 2026-10-24 | 4 | Entry criteria | Pass (Phase 3 first-night check waived by Ritchie; today's manual backup run stands in) | `pve8to9` 0 FAIL on all three; PVE 8 updates applied; `/etc` snapshots; NIC names pinned with `/etc/systemd/network/10-pin-<nic>.link` (`pve-network-interface-pinning` refuses a pin to the current name); protected backups from today for every guest |
| 2026-10-24 | 4 | izumida → PVE 9 | Done | Downbeat approved via Ritchie. 500/501: auto fsck refused (orphan list), `e2fsck -fy` approved by Ritchie, both now clean. Guests stopped 13:15, sources → trixie deb822, dist-upgrade 13:17–13:21 (exit 0), kept local `lvm.conf` (the new default drops the zvol `global_filter`), grub and issue. chrony failed until reboot (new chrony vs old PID 1). Rebooted 13:22–13:24: pve-manager 9.2.21, kernel 7.0.14-25-pve; `eno1`, TSO/GSO off, 0 hangs, ARC 4G, `Media` online, quorate, all guests up, chrony synced, P400 visible. **transmission-openvpn failed**: kernel 7.0's ovpn DCO isn't allowed in an unprivileged CT, fixed with `OPENVPN_OPTS=--disable-dco`; VPN exit IP confirmed. Downbeat's checks pass |
| 2026-10-24 | 4 | Terraform plan against PVE 9 | Pass | `plan`: No changes, with izumida on PVE 9 (bpg 0.66 still works) |
| 2026-10-24 | 4 | teshima → PVE 9 (Quadros still in) | Done | Guests stopped 13:31, sources → trixie, dist-upgrade 13:33–13:41 (exit 0), same config choices as izumida. `pve8to9` then FAILed on `intel-microcode` (now installable from non-free-firmware): installed, 0 FAIL. Rebooted 13:43–13:44 on kernel 7.0.14-25-pve: `enp1s0`, quorate, `local-lvm` + `local-wdblue` active, HubZ `5160037E` on ttyUSB0/1, chrony active. All guests up (bot stays stopped), containers up, smarthome now has `nameserver 10.1.0.3 / 10.1.0.2`, Matter node 9 subscribed, Zigbee 24/34, dns1 resolves, Vaultwarden/photos/documents/nc/HA answer |
| | 4 | teshima: pull NVMe + both Quadros, headless boot check | | |
| 2026-10-24 | 4 | fukutomi → PVE 9 | Done | Downbeat warned. Guests stopped 13:48, sources → trixie, dist-upgrade + `intel-microcode` 13:49–13:55 (exit 0); grub-install rewrote the EFI files at 13:54 (thanks to the §3.3 fix). Rebooted 13:56: kernel 7.0.14-25-pve, `enp2s0`, quorate, guests up, dns0/1/2 resolve, public sites 200, DDNS correct, backup storage active |
| 2026-10-24 | 4 | Health check, all three on PVE 9 | Pass with exceptions | Only: the two stopped 09:03 backup tasks (age out 10-31), dns0 nebula-sync restart at boot, and teshima's SSD counter, which PVE 9's smartctl prints as `Lat/Erl` (known-exception pattern updated; value still 0/369) |
| | 4 | Exit gate | | Waiting on step 4 (teshima hardware) |
| | 5 | NVIDIA 580 driver (version: ___ ); exit gate | | |
| | 6 | R1–R4 repo changes | | |
| | 6 | ritchie + media GPU, NVENC test; exit gate | | |
| | — | Closing out (§9) | | |

### 8.1 Open items

Each one must be fixed, or accepted with a reason, before the phase in the second
column. Evidence: analysis notes §5.

| Item | Before | Action | Status |
|---|---|---|---|
| izumida swap 79% | Phase 3 | Check ritchie/media/vcr memory sizing. 2026-10-22: `vm.swappiness = 10` (by hand, `/etc/sysctl.d/99-swappiness.conf`). 2026-10-23: vcr raised to 12G, swap flushed (analysis notes §7). 2026-10-24: regrew to full; ritchie raised to 16G (Postiz), swap flushed again (analysis notes §8). **Accepted 2026-10-24 by Ritchie without the two-night wait**: at 07:18 swap was 1.4G and rising (idle pages), but ritchie had no new `memory.high` events after the raise, si/so 0. Keep watching after the move; if a guest hits its limit again, raise it (media 304 is next) | Accepted |
| izumida e1000e NIC hang | Phase 3 | TSO/GSO off since 2026-10-21; 0 hangs since. Re-check after izumida's move and first night downstairs | Watch |
| bot (CT 300) is started by any Terraform apply; it is kept stopped on purpose | Phase 4 (Terraform plan against PVE 9) | Fixed 2026-10-24: `services_containers` has an optional `started` (default true); bot has `started = false`. `plan` is now fully clean | Done |
| VM 101 guest agent not answering; its QEMU process causes izumida's hung-task warnings | Phase 3 | 2026-10-24: Ritchie installed and enabled `qemu-guest-agent` and rebooted VM 101; `qm agent 101 ping` answers (Ubuntu 26.04.1, 10.1.0.233). The hung tasks were **not** VM 101: all 10 are one I/O stall at 08:40:23 on 10-22 (jbd2, dockerd, Prometheus in 216, Java/Elasticsearch, .NET), before the ARC cap; none since. They leave the health check's 7-day window on 10-29 | Done |
| pihole-exporter `10.1.0.15:9617` down on all Prometheus hosts | Phase 2 | Fixed 2026-10-22: its env file only had `changeme` placeholders. Real Pi-hole passwords set, and Compose now reads the file in `raw` format | Done |
| vzdump errors 10-20 to 10-22 | Phase 2 | Confirm the next two nights are clean (causes already removed). 10-23 and 10-24 clean | Done |
| smarthome (226) has no backup yet | Phase 2 | Covered by S7. First backup 10-23, snapshot mode | Done |
| smarthome has only one resolver (10.1.0.3) | Phase 4 | 2026-10-24: `pct set 226 --nameserver "10.1.0.3 10.1.0.2" --searchdomain macapinlac.network` (searchdomain was the IP `10.1.0.4` by mistake). Pending until CT 226's next start, which teshima's upgrade provides; confirm `/etc/resolv.conf` in 226 afterwards | Done (pending restart) |
| `pve8to9` FAILs | Phase 4 | None on 2026-10-22; re-run before each node's upgrade | Done |
| fukutomi: `grub-efi-amd64` not installed on a UEFI system; removable bootloader not managed by GRUB (`pve8to9` WARN) | Phase 4 | Done 2026-10-24 (upgrade plan §3.3); booted fine on it during the move | Done |
| fukutomi and teshima: `intel-microcode` not installed (`pve8to9` WARN) | Phase 4 | Install it (needs the `non-free-firmware` component) | Open |
| izumida and teshima: `systemd-boot` installed on legacy-boot systems (`pve8to9` WARN) | Phase 4 | Removed 2026-10-24 on both (legacy boot, `proxmox-boot-tool` unused, `grub-pc` stays) | Done |
| midosuji MX500 `Current_Pending_ECC_Cnt` flipping 0 ↔ 1 | — | Watch; matters for midosuji's reuse, not this plan | Watch |
| transmission-openvpn restarted once | — | Watch | Watch |
| family 305 (teshima) at its 40G limit, so teshima swap over 50%; dns0 200 (fukutomi) at its 2G limit | — | Check what grows in each (analysis notes §8) | Watch |
| HA automation `walk_in_smart_switch_on_off` fails: `kelvin` is not a valid option (automations.yaml line 63) | — | **[Ritchie]** Replace `kelvin: 5094` with `color_temp_kelvin: 5094`. Not caused by the move: same HA 2026.9.4 image and config before and after | Open |

### 8.2 Open questions

| Question | Why it matters |
|---|---|
| What does "storage space" in the hardware objective cover? | The objective can't be checked off without it. The candidates are in analysis notes §1 |

## 9. Closing out

When Phase 6's exit gate is passed:

1. Check every row of the objectives table at the top is true, and log it in §8.
2. Run the health check one last time. Its snapshot is the final state; its report is the new weekly baseline.
3. Update `sop/health-check-known.txt` (remove anything this maintenance fixed).
4. Update the docs and memory that describe the cluster (nodes, hardware, where guests run).
5. Log this maintenance as **Complete** in §8, with the date.
