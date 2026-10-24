# Proxmox VE 8 → 9 Upgrade Plan

| | |
|---|---|
| **Status** | Planning |
| **Target window** | Sat 2026-10-03 – Sun 2026-10-04 (prep Fri 2026-10-02) |
| **Scope** | 3-node cluster: fukutomi (.141), izumida (.143), teshima (.144). midosuji (.142) was removed from the cluster on 2026-10-24 (interhigh maintenance Phase 2); its rows below are historical |
| **Reference** | <https://pve.proxmox.com/wiki/Upgrade_from_8_to_9> |
| **Survey date** | 2026-10-01 (read-only checks + `pve8to9 --full` on every node) |

## 1. Summary

All nodes are on PVE 8.4.21 / Debian bookworm, so the upgrade path is open. The
cluster is the easy shape for this upgrade: no Ceph cluster, no HA resources,
no shared LVM, only LXCs (Debian 12/13, all systemd ≥ 252, so cgroup v1 removal
is a non-issue), and one stopped test VM.

The real risks are **not** the upgrade mechanics; they are things the survey turned up.
**Phase 0 is [homelab-health-baseline.md](homelab-health-baseline.md)**: its
§5 execution plan must be complete, and its health check must pass, before any
node is upgraded.

0. **midosuji `sda` (`local-baracuda`) is failing** (16 pending/uncorrectable
   sectors). It holds smarthome's root disk. See health baseline H1.
1. **midosuji has had no backups since 2026-01-06.** Its scheduler is wedged, so
   `smarthome`, `drive` (Nextcloud), `boogienet-*` and `monitor-midosuji` have no
   vzdump at all on the NAS. Must be fixed before anything else.
2. **midosuji fails `pve8to9`**: `/etc/hosts` resolves the node to its old
   `192.168.1.142` address.
3. **fukutomi boots UEFI without `grub-efi-amd64`**. Upgrading as-is risks an
   unbootable node — and fukutomi hosts all four Pi-holes plus `edge`.
4. **Three nodes have not rebooted in 15 weeks** and are running kernel
   6.8.12-29 with -42/-43 installed but never booted. An untested reboot path
   gets tested for the first time *during* the upgrade unless we reboot first.
5. **Every node has a single NIC with no out-of-band management** (see Open
   questions). A NIC rename on the new kernel = node offline until someone is
   physically at it.
6. **The repo's `proxmox` role hardcodes `bookworm`.** Running
   `proxmox-setup.yml` after the upgrade would inject bookworm sources into a
   trixie system.

## 2. Current state

### Nodes

| Node | IP | CPU / RAM (used) | NIC (driver) | Boot | Root free | Uptime | Notes |
|---|---|---|---|---|---|---|---|
| fukutomi | 10.1.0.141 | i5-4570, 4c / 15G (2G) | `enp2s0` (r8169, Realtek) | **UEFI** | 36G | 15 wk | PVE 7-era leftovers (5.11 kernels, py3.9) |
| midosuji | 10.1.0.142 | i7-4770, 8c / 31G (7G) | `eno1` (e1000e) | legacy | 34G | 15 wk | PVE 7-era leftovers; HubZ USB stick → smarthome |
| izumida | 10.1.0.143 | i7-4790, 8c / 31G (22G) | `eno1` (e1000e) | legacy | 73G | 15 wk | ZFS pool `Media` (3.6T); `systemd-boot` installed |
| teshima | 10.1.0.144 | Xeon X5660, 24c / 47G (9G) | `enp1s0` (tg3) | legacy | 79G | 6 wk | `data` VG (842G free); `systemd-boot` installed; unused HubZ stick |

All: PVE 8.4.21, Ceph 17 *client* packages only (no `/etc/pve/ceph.conf`, no Ceph
services), `/etc/sysctl.conf` empty, no NVIDIA, no PBS co-install,
`proxmox-archive-keyring.gpg` present, `pve-network-interface-pinning` available,
DNS resolvers are 1.1.1.1 (no dependency on the Pi-holes), `sshd_config`
unmodified, `/etc/lvm/lvm.conf` modified only by PVE's `global_filter`.

### Guests and blast radius

| Node | CT | Name | Services (Ansible groups) | Notes |
|---|---|---|---|---|
| fukutomi | 200–203 | dns0–dns3 | pihole | **All four Pi-holes on one node** |
| | 210 | edge | traefik / wg-easy / cloudflare | **All ingress** |
| | 215 | monitor-fukutomi | prometheus, pihole-exporter | |
| midosuji | 225 | smarthome | homeassistant, teslamate | **Privileged**, not in Terraform, `dev0/dev1: /dev/ttyUSB0/1` |
| | 306 | drive | nextcloud | `memory: 163840` on a 31G host (misconfig) |
| | 500, 501 | boogienet-core/utils | (not in this repo) | Debian 13, `keyctl=1` |
| | 217 | monitor-midosuji | prometheus | |
| | 103 | yamaguchi | — | Privileged, stopped, `onboot: 0` |
| izumida | 302 | vcr | *arr stack, sabnzbd, transmission-openvpn | `/dev/net` bind-mount (tun) |
| | 303 | ritchie | jellyfin, tubearchivist, obsidian, searxng, … | |
| | 304 | media | jellyfin, audiobookshelf, kavita, azuracast | |
| | 216 | monitor-izumida | prometheus | |
| teshima | 305 | family | immich, vaultwarden, paperless, outline, n8n, … | **Most important data** |
| | 300 | bot | claude/codex/litellm/hermes | |
| | 301 | media-support | tdarr | |
| | 218 | monitor-teshima | prometheus | |
| | VM 100 | arch-test | — | Stopped |

Every CT is on node-local storage (`local-lvm`, `local-baracuda`, `Media` ZFS),
so migration means a full disk copy over 1GbE and a CT restart. **The plan
accepts per-node downtime instead of migrating.**

### `pve8to9 --full` results

| Node | Result | Items |
|---|---|---|
| fukutomi | 0 FAIL / 5 WARN | `grub-efi-amd64` missing; removable EFI bootloader not managed; no `intel-microcode`; libexpat1 pending; running guests |
| midosuji | **1 FAIL** / 3 WARN | **`/etc/hosts` → 192.168.1.142**; no `intel-microcode`; libexpat1; running guests |
| izumida | 0 FAIL / 3 WARN | `systemd-boot` on legacy boot; libexpat1; running guests |
| teshima | 0 FAIL / 4 WARN | `systemd-boot` on legacy boot; no `intel-microcode`; libexpat1; running guests |

### Backups

- One cluster job: daily 01:00, all guests, snapshot mode, zstd, to NFS
  `ProxmoxBackups` (10.1.0.95, 3.1T free), **`keep-last=1`**.
- fukutomi, izumida and teshima guests all have a 2026-10-01 backup.
- **midosuji: none.** The last vzdump task there ran 2026-01-06 and errored.
  Since then `pvescheduler` has logged `could not update job state, skipping - no
  such task` every minute.
  - The 2026-01-06 failures for 225/103 were `rsync ... chown ... Operation not
    permitted`. Those CTs live on `dir` storage (`local-baracuda`), where snapshot
    mode isn't possible. vzdump falls back to suspend mode and rsyncs into a temp
    dir on the NFS target, which squashes root.
- `keep-last=1` means the upgrade-night backup would overwrite the only copy.
  Pre-upgrade backups must be taken separately and **protected**.

## 3. Must fix before the weekend (P0)

All of these happen on PVE 8, independent of the upgrade itself.

### 3.1 Restore midosuji backups

```bash
# on midosuji
ls -la /var/lib/pve-manager/jobs/          # inspect the stale vzdump job state file
journalctl -u pvescheduler -n 50
```

- [ ] Clear the stale job state (move the `vzdump-*.json` state file aside) and
  `systemctl restart pvescheduler`; confirm the log line stops.
- [ ] Add `tmpdir: /var/tmp` to `/etc/vzdump.conf` on midosuji so suspend-mode
  backups of `dir`-storage CTs stage locally instead of on root-squashed NFS.
  Check free space vs. the 31G `smarthome` rootfs.
- [ ] Run a manual backup of 217, 225, 306, 500, 501 and confirm each completes:
  `vzdump <id> --storage ProxmoxBackups --mode snapshot --compress zstd`.
- [ ] Decide on 103 (yamaguchi): back it up, or explicitly accept the loss.

### 3.2 Fix midosuji `/etc/hosts`

- [ ] Change line 2 to `10.1.0.142 midosuji.local midosuji`.
- [ ] Re-run `pve8to9 --full` → 0 FAIL.

### 3.3 Fix fukutomi UEFI bootloader

```bash
# on fukutomi
apt install grub-efi-amd64
echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections -v -u
apt install --reinstall grub-efi-amd64
```

- [ ] Re-run `pve8to9 --full` → grub warnings gone.

### 3.4 Shake out the reboot path on PVE 8 (Friday)

Reboot each node once on PVE 8 *before* the upgrade. This boots the pending
6.8.12-43 kernel, proves the boot path, the NIC and the CT autostart order, and
separates "can't reboot" from "upgrade broke it." Same node order as §6.

- [ ] `apt update && apt dist-upgrade` (clears the libexpat1 warning)
- [ ] `apt remove systemd-boot` on izumida and teshima
- [ ] Purge PVE 7-era kernels on fukutomi/midosuji (`pve-kernel-5.11*`) and
  `proxmox-kernel-6.5*` everywhere it's installed
- [ ] Reboot. Confirm `uname -r` = 6.8.12-43, all `onboot: 1` CTs running, NFS mounts present

## 4. Repo changes (before the weekend)

| # | Change | Why |
|---|---|---|
| R1 | `roles/proxmox/tasks/main.yml`: derive suite from `ansible_distribution_release`. Write deb822 `.sources` for trixie (`debian.sources`, `proxmox.sources`, `ceph.sources` pointing at `ceph-squid`). Disable `pve-enterprise.sources`. Stop touching `/etc/apt/sources.list` on trixie. | The role hardcodes bookworm and would corrupt an upgraded node's sources. |
| R2 | Make the template version a variable used by both the role and `terraform.tfvars.j2` (currently `12.12-1` is hardcoded in three places). Optionally add the Debian 13 template. | Hardcoded drift. Debian 12 CTs keep working on PVE 9, so this is not urgent. |
| R3 | `maintenance.yml` first play: add `serial: 1`. Document "do not run during the upgrade window." | Today it runs `apt upgrade full` on all four nodes in parallel. Mid-upgrade, that would dist-upgrade nodes with half-switched sources. |
| R4 | `terraform/versions.tf`: plan a `bpg/proxmox` bump from `~> 0.66.0`. Test `./bin/terraform.sh plan` after the first node is on 9. **No `terraform apply` while the cluster is mixed.** | 0.66 predates PVE 9. Compatibility unverified. |
| R5 | Check the `tun_device` local-exec in `terraform/modules/lxc-container/main.tf`. It writes `lxc.cdev.allow`, which is not a standard LXC key (`lxc.cgroup2.devices.allow` is), and CT 302's config only has the `lxc.mount.entry` line. Confirm `/dev/net/tun` works in `vcr` after the upgrade; fix the module if it doesn't. | cgroup v2–only host: the tun passthrough path is the most likely LXC config to break. |
| R6 | `homelab_config/ansible/inventory/proxmox-lxc-config.yml`: keep `ansible_ssh_private_key_file: ~/.ssh/id_rsa` for `proxmox_control_node_by_ip`. | Nodes only accept `id_rsa` for root; `ssh-add ~/.ssh/id_rsa` before any play. |

R1 and R3 are required before the weekend. R2, R4 and R5 can come after.

## 5. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| NIC renamed by new kernel → node unreachable | Low–Med (r8169 on fukutomi is the most exposed) | High (no OOB) | Run `pve-network-interface-pinning` before the upgrade reboot, or keep the old name via a `.link` file; physical access on hand |
| Node fails to boot | Low (after §3.3/§3.4) | High | §3.4 dry-run reboot; old 6.8 kernel remains in GRUB "Advanced options" as a recovery boot |
| fukutomi down → LAN DNS + all ingress down | Certain during its reboot | High (whole house) | Do it last, at a quiet hour. Temporarily add a public fallback DNS on the router's DHCP, or move one Pi-hole to another node first (see §9) |
| smarthome USB devices re-enumerate (ttyUSB0 ↔ ttyUSB1) | Low | Med (Zigbee/Z-Wave down) | Switch `dev0`/`dev1` to `/dev/serial/by-id/usb-Silicon_Labs_HubZ_…5160037E-if0{0,1}-port0` beforehand |
| Docker-in-LXC breaks under new AppArmor / LXC | Low–Med | Med | Canary node first (izumida), validate a Docker CT before touching the rest |
| ZFS `Media` pool after OpenZFS bump | Low | Med | Do **not** run `zpool upgrade` until well after the upgrade; it's a one-way door |
| Accidentally running `maintenance.yml` / `terraform apply` mid-upgrade | Med | Med | R3, plus a freeze on both during the window |
| Data loss with no restore point | — | High | §3.1 + protected pre-upgrade backups (§7) |

## 6. Node order

| Order | Node | Why this slot |
|---|---|---|
| 1 | **izumida** | Canary. Least critical services (media, *arr), but exercises the interesting bits: ZFS, legacy boot, Docker CTs, tun passthrough in `vcr`. |
| 2 | **teshima** | Rebooted recently, most headroom. Hosts `family` (vaultwarden/immich/paperless), so only after the canary is proven. |
| 3 | ~~midosuji~~ | **Skipped if it's being replaced**: see [midosuji-replacement-plan.md](midosuji-replacement-plan.md). It stays on PVE 8 until its guests move to the new PVE 9 node. Upgrade it here only if the replacement falls through. |
| 4 | **fukutomi** | Last: UEFI, Realtek NIC, and it takes DNS + ingress with it. Schedule for a low-usage time. |

Suggested split: izumida and teshima on Saturday. Let them soak overnight.
midosuji and fukutomi on Sunday morning.

Mixed-cluster rules while nodes differ (8 ↔ 9):
- No `terraform apply`, no `maintenance.yml`, no new guests, no HA config.
- Don't migrate guests from a 9 node to an 8 node.
- Expect cosmetic web UI oddities until all nodes match. Force-reload the browser after each node.

## 7. Per-node runbook

Run from a workstation with `ssh-add ~/.ssh/id_rsa` done, logged in as root on the node.
**Use `tmux`** so a dropped SSH session doesn't kill `apt`.

### 7.1 Pre-flight (immediately before)

```bash
tmux new -s pve9
pveversion                                   # 8.4.x
pve8to9 --full                               # 0 FAIL
pvecm status | grep -E 'Quorate|Nodes'       # Quorate: Yes, Nodes: 4
cp -a /etc /root/etc-pre-pve9-$(date +%F)    # local config snapshot
ip -br link; cat /etc/network/interfaces     # record NIC name + MAC
```

Fresh, protected backup of every CT on the node (doesn't count against `keep-last=1`):

```bash
for id in $(pct list | awk 'NR>1{print $1}'); do
  vzdump $id --storage ProxmoxBackups --mode snapshot --compress zstd \
    --protected 1 --notes-template "pre-pve9 {{guestname}}"
done
```

- [ ] All backups completed without error
- [ ] Pin the NIC name: `pve-network-interface-pinning generate` (review what it
  writes to `/etc/systemd/network/` and `/etc/network/interfaces` before rebooting)

### 7.2 Switch repos to trixie (deb822)

```bash
mkdir -p /root/apt-bookworm && mv /etc/apt/sources.list.d/*.list /root/apt-bookworm/
mv /etc/apt/sources.list /root/apt-bookworm/sources.list && touch /etc/apt/sources.list

cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

cat > /etc/apt/sources.list.d/proxmox.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

cat > /etc/apt/sources.list.d/ceph.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt update && apt policy | grep -E 'bookworm|trixie'   # expect trixie only
```

This also cleans up the duplicate Debian lines, the duplicate
`pve-no-subscription` (teshima) and the stray `pvetest-for-beta.list`. Once R1
lands, this step should be what `proxmox-setup.yml` produces.

### 7.3 Upgrade

```bash
apt dist-upgrade
```

Config file prompts:

| File | Answer |
|---|---|
| `/etc/issue` | Keep current (N) |
| `/etc/lvm/lvm.conf` | Maintainer's (Y), then confirm `global_filter` still excludes `/dev/zd*` and `/dev/rbd*` |
| `/etc/ssh/sshd_config` | Maintainer's (Y). Ours is unmodified. Root key login is still allowed (`prohibit-password`). |
| `/etc/default/grub` | **Keep current (N)**. It carries `intel_iommu=on iommu=pt` |
| `/etc/chrony/chrony.conf` | Maintainer's (Y) |
| anything else | Show diff (D), decide; default to keeping local changes |

```bash
pve8to9 --full                     # re-run, expect 0 FAIL
reboot
```

### 7.4 Post-reboot validation

Run the node and container health checks from
[homelab-health-baseline.md §6](homelab-health-baseline.md#6-how-to-run-the-health-check)
and diff against its §3 baseline. The commands below are the quick version.

```bash
pveversion                          # pve-manager/9.x
uname -r                            # new PVE 9 kernel
ip -br addr show vmbr0              # 10.1.0.14x/24 UP
pvecm status | grep Quorate
pct list                            # every onboot CT running
df -h | grep /mnt                   # 5 NFS mounts (ContainerBackups, SavedMedia, Documents, NextCloud, Photos)
systemctl --failed
```

From the workstation:

```bash
./bin/ansible-playbook.sh site.yml --limit <node's CTs> --check   # Ansible still reaches CTs
ansible <group> -m shell -a 'docker ps --format "{% raw %}{{.Names}} {{.Status}}{% endraw %}"'
```

Node-specific checks:

| Node | Check |
|---|---|
| izumida | `zpool status Media` healthy, `/Media` mounted, `vcr` VPN up (`ls /dev/net/tun` in CT 302, transmission container healthy), Jellyfin plays |
| teshima | `family` services via Traefik: vaultwarden login, immich loads, paperless loads |
| midosuji | Home Assistant sees Zigbee/Z-Wave devices; Nextcloud loads; the scheduler runs the next 01:00 backup |
| fukutomi | All 4 Pi-holes answer (`dig @10.1.0.x`), Traefik routes, WireGuard connects, Cloudflare DDNS updates |

## 8. Rollback and recovery

There is no supported in-place downgrade. The tiers are:

1. **`apt` fails mid-upgrade**: fix sources, `apt -f install`, `apt dist-upgrade` again.
   "Upgrade fails to remove `proxmox-ve`" means a bookworm entry is still present.
2. **Boots but the network is gone**: on the console, `ip -br link` to find the new
   name, fix `bridge-ports` in `/etc/network/interfaces`, `ifreload -a`.
3. **New kernel won't boot**: GRUB → Advanced options → the old 6.8.12 kernel.
4. **Node is unrecoverable**: fresh PVE 9 install with the same name and IP. Remove
   the dead node from the cluster (`pvecm delnode`), join the new install, and
   restore CTs from the protected pre-upgrade backups (`pct restore`). Re-run
   `proxmox-setup.yml` (after R1) for repos/NFS.

Tier 4 is why §3.1 and the §7.1 protected backups are non-negotiable.

## 9. Optional / nice-to-have (not required for the upgrade)

- **Spread the Pi-holes**: move one or two of dns0–3 to another node so a fukutomi
  reboot no longer takes out LAN DNS. Biggest resilience gain available.
- **CT 306 `drive`**: `memory: 163840` (160G) on a 31G host. Set a real limit.
- **Remove IOMMU/vfio** on nodes with no PCI passthrough (the only VM is stopped).
  `vfio_virqfd` no longer exists as a module; midosuji lists the vfio modules twice.
- **`intel-microcode`** (non-free-firmware is enabled by the new sources).
- **Clean up** stale backups of deleted guests (220–224, 323, 400, VM 600) and
  midosuji's stale `192.168.1.4` resolver.
- ~~**Teshima's HubZ stick** isn't passed to anything. Unplug or document.~~
  Done 2026-10-22: unplugged; `lsusb` shows only root hubs.

## 10. After all four nodes are done

- [ ] `pveversion -v` matches across nodes
- [ ] Force-reload the web UI
- [ ] `apt modernize-sources` not needed (already deb822) — confirm no `.list` files
- [ ] Bump/verify `bpg/proxmox` (R4); `./bin/terraform.sh plan` shows no unexpected diff
- [ ] Re-run `./bin/ansible-playbook.sh maintenance.yml`
- [ ] Post-maintenance audit per `sop/maintenance-service-version-audit.md`
- [ ] Check the next nightly backup covers **all** nodes
- [ ] Remove `protected` from pre-upgrade backups after ~2 weeks
- [ ] Update `AGENTS.md` / role defaults (template version, trixie)

## 11. Open questions

1. **Console access**: the nodes have no IPMI. Is a monitor and keyboard available
   for each node, especially fukutomi? This determines whether the NIC-rename risk is
   a 5-minute fix or a drive.
2. **CT 103 yamaguchi**: keep, back up, or delete?
3. **DNS during the fukutomi window**: accept the outage, add a temporary public
   fallback DNS on DHCP, or move a Pi-hole first?
4. **boogienet-core/utils (500/501)**: not managed by this repo. Who validates them after midosuji?

## 12. Progress log

| Date | Node | Step | Result | Notes |
|---|---|---|---|---|
| 2026-10-01 | all | Survey + `pve8to9 --full` | Done | Findings above |
| 2026-10-01 | all | Health baseline | Done | [homelab-health-baseline.md](homelab-health-baseline.md); H1 failing disk found |
| | midosuji | Phase 0 (health §5) complete | | |
| 2026-10-01 | midosuji | §3.1 backups fixed | Done | Scheduler unstuck; all 6 CTs backed up and verified; 225/103 protected. Nightly still expected to fail on 225 (see health H2). |
| | midosuji | §3.2 `/etc/hosts` | | |
| | fukutomi | §3.3 grub-efi | | |
| | all | §3.4 PVE 8 reboot | | |
| | repo | R1, R3 | | |
| | izumida | Upgrade | | |
| | teshima | Upgrade | | |
| | midosuji | Upgrade | | |
| | fukutomi | Upgrade | | |
