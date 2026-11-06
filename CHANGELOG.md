# Changelog

All notable changes to **Void Linux Live** — a customized fork of
[`void-linux/void-mklive`](https://github.com/void-linux/void-mklive) — are
documented in this file.

Releases are tagged `v1.0`, `v1.1`, `v1.2`, … (minor bumps for routine updates;
a major bump is deliberate). Each tag is a full snapshot of the tracked tree —
the diff against the previous tag is that release's change set, and each release
commit lists the underlying source commits.

## Unreleased

### Interop

- **[INSTALLER-REF-3.2.06]** Bump the shipped-Installer pin
  `Version-3.2.04` → `Version-3.2.06`, and this one **is** boot-safety. 3.2.03's
  `[ELOGIND-NO-DBUS-ACTIVATION]` rename of
  `/usr/share/dbus-1/system-services/org.freedesktop.login1.service` broke KDE:
  Void's stock `/etc/sv/sddm/run` (`sddm-0.21.0_2`) is `set -e` +
  `dbus-send … StartServiceByName string:org.freedesktop.login1` followed by
  `exec sddm`, and `StartServiceByName` fails with `ServiceUnknown` once the
  activation file is gone — even though the name is currently owned — so the
  script died rc=1 before `exec sddm` and runsv never started SDDM. A fresh
  `Version-3.2.05` KDE install (2026-11-05) therefore booted to a text login on
  tty1 with no graphical session at all. 3.2.06 ships `[SDDM-WAIT-LOGIND]`
  (bounded wait for `/run/systemd/seats/seat0`, then `exec sddm` regardless of
  the verdict) plus the same self-healing pattern 3.2.03 used for GDM: the
  stock script is kept at `/etc/sv/sddm/run.orig`, the canonical copy lives in
  `/root/tools/sddm.run.fixed`, and `re-fix-sddm-run.sh` is re-run from
  `rc.local` every boot so a `sddm` package update cannot silently restore the
  broken script (one more accepted `xbps-pkgdb -a` row). An image pinned below
  3.2.06 hands a KDE box a desktop-less first boot. Keep this pin at or above
  the newest installer. The 3.2.04 `[PKG-SNAP-LONGOPT]` fix rides along.
- **[INSTALLER-REF-3.2.04]** Bump the shipped-Installer pin
  `Version-3.2.03` → `Version-3.2.04`. The same fresh GNOME install showed the
  update-snapshot wrapper (`/usr/local/sbin/void-xbps-snap`, which shadows
  `xbps-install`) taking **no** snapper pair for a system update driven from
  GNOME Software: its `_should_snap` matcher only recognised the short xbps
  flags (`-S`, `-Su*`, `-u`, `-U`) while the store's xbps backend spawns
  `xbps-install --sync --update --yes`, so every argument fell through the
  `--*` branch and the wrapper took its no-snapshot fast path — the update
  happened, and nothing was rollback-able (`[PKG-SNAP-LONGOPT]`). 3.2.04 also
  accepts `--sync`, `--update` and `--upgrade`. Unlike the 3.2.03 pin this is
  not a boot-safety bump: an image below 3.2.04 still installs and boots, but
  every GUI-driven system update it provisions is unrollback-able. Keep this
  pin at or above the newest installer.
- **[INSTALLER-REF-3.2.03]** Bump the shipped-Installer pin
  `Version-3.2.02` → `Version-3.2.03`. The first fresh GNOME install made by
  3.2.02 exposed a real first-boot race: a dbus-activatable
  `org.freedesktop.login1.service` stub let elogind be started twice, and GDM
  could come up before logind had registered `seat0` — the 2026-10-30 box
  needed **three** boots to reach a login prompt. 3.2.03 fixes both
  (`[ELOGIND-NO-DBUS-ACTIVATION]` renames the activation stub out of the way so
  the runit service is the only starter; `[GDM-WAIT-LOGIND]` makes GDM wait for
  seat0), and both are self-healing: pristine copies live in `/root/tools/` and
  `rc.local` re-applies them by hash on every boot, at the cost of two accepted
  `xbps-pkgdb -a` rows. An image pinned to 3.2.02 provisions the race on any
  GDM desktop. Keep this pin at or above the newest installer.
- **[INSTALLER-REF-3.2.02]** Bump the shipped-Installer pin
  `Version-3.2.01` → `Version-3.2.02`. The GNOME Software store
  (`[GNOME-SOFTWARE-STORE]`) only ships from 3.2.02: an image pinned to 3.2.01
  provisions **nothing** for a GNOME desktop, so GNOME Software is either
  absent or Void's stock `gnome-software-50.2_1` — flatpak-only, with no
  `xbps-backend.so`, i.e. it cannot see the system's xbps packages. 3.2.02
  installs the store build (same upstream 50.2, with the native backend) via
  the same discipline Discover uses: repodata probe → `61-gnome-software.conf`
  → a dedicated key-importing sync on the installer's own pipe → a
  machine-checked trust anchor (pin `9bdf4599…0d60`) → `xbps-install -R
  <store>` → an installed-origin assertion. It also fixes that helper's
  availability fallback, which in the earlier code installed no Software app at
  all (the `gnome` metapackage carries no `gnome-software` run-depend). Keep
  this pin at or above the newest installer that carries every desktop store.
- **[INSTALLER-REF-3.2.01]** Bump the shipped-Installer pin
  `Version-3.1.00` → `Version-3.2.01`. The Discover integration
  (`[DISCOVER-STORE]`) only ships from 3.2.00, and the repo-order fix
  (`[DISCOVER-STORE-REPO-ORDER]`) only ships from 3.2.01: an image pinned to
  3.1.00 provisions **no** Discover store at all, and one pinned to 3.2.00
  installs the **stock** `discover` from the official repo — `xbps-install
  <name>` resolves against the first repository in config order
  (`00-repository-main.conf` sorts before `60-discover.conf`), so the store's
  `discover-6.7.5_7` was never seen and the result had no `xbps-backend.so`,
  i.e. Discover managed flatpaks only. 3.2.01 prepends the store repository for
  that one transaction and asserts the installed origin afterwards. Keep this
  pin at or above the newest installer that fixes both.
- **[INSTALLER-FETCH]** Stop vendoring the Installer; fetch it from the public
  repo at build time. `lib.sh` gains `installer_fetch` (repo/ref configurable via
  `INSTALLER_REPO` / `INSTALLER_REF`, default
  `bluesloth/void-linux-installer` @ `main`), and both `mkiso.sh`
  (`include_installer`) and `mknet.sh` use it — so the live ISO **and** the
  netboot image always ship the current Installer with no pinned copy to lag
  behind. The fetched script is syntax-checked and its resolved `SCRIPT_VERSION`
  + sha256 are printed and recorded at `/etc/void-linux-live/installer-ref` on
  the live image. The tracked `installer.sh` is **deleted**; a failed fetch
  aborts the build (no fallback). Pin a release for a reproducible build with
  `INSTALLER_REF=v2.9.95`. The Installer→Live seam is now a fetch declaration
  (`# INSTALLER-REF:` in `mkiso.sh`) instead of a version+SHA pin
  (`coordination/PINS.md` §3.1).
- **[INSTALLER-UPDATE-TOOL]** Refresh the Installer on an already-flashed stick
  without rebuilding the ISO — the installer's analogue of `xbps-cache-tool.sh`.
  The Installer ships inside the ISO's read-only squashfs at
  `/usr/bin/void-installer` (the single path every live entry point runs: the
  Desktop symlink and `void-installer-launch`), so an in-place update can only
  go through the `VOID_OVL` persistence overlay, where a new
  `usr/bin/void-installer` shadows the squashfs copy and survives reboots (a
  non-persistent boot uses a RAM overlay; the tool detects that and refuses
  unless `--force`). The updater ships baked into every image by `mkiso.sh`
  (`include_installer_updater` →
  `/usr/local/share/void-installer-update/installer-update-tool.sh`): `status`
  (ISO build vs in-effect copy vs overlay stamp, with the sha256 to pin on the
  next run), `update [--ref R] [--sha256 S]` (R picks what to fetch — default
  `main`, same URL seam as the build-time `installer_fetch` — and the optional
  pin is enforced; fetch → verify with `bash -n` + `SCRIPT_VERSION` → back up the
  as-built copy once → install), and `restore` (copy the as-built backup back —
  never a delete, which would whiteout the squashfs copy for good). `restore`
  also **rewrites the stamp** with a `restored_utc=` line (plus the sha of the
  copy now in effect) instead of leaving the old `installed_utc=` block behind,
  and `status` labels that block `Last restore` rather than `Overlay update` —
  so a rollback never reads as a pending update. On the host-side removal path
  (no previous copy) the stamp is deleted outright, so `status` reports
  `none (the ISO copy is in effect)`. **Shipped in `v1.11`; removed by
  `[LIVE-INSTALLER-CHECK]` (see there):** `voidlive-build-persist.sh
  flash … --update-installer` / `--installer-ref` / `--installer-sha256`
  deposited a second copy of the tool at `/installer-update-tool.sh`
  (partition root + dmsquash upperdir, same pattern as `--seed-cache`) and
  installed the fetched script into the upperdir at flash time — `build …
  --flash …` accepted the same flags (swallowed by `build()`'s parse loop so
  they never reached mklive), and a failed update never failed the flash (the
  stick kept the ISO's installer). That surface — the flags,
  `_deposit_installer_tool()` and the deposited copy — is gone from the tree
  (invoking the old flags now fails with a pointer to the desktop flow).

### Packages

- **[ALL-DE-EXTRAS]** Give the live image app parity with void-installer's
  *unconditional, all-DE* install set. Add `xdg-user-dirs xdg-utils rsync wget
  make binutils inotify-tools fastfetch cronie bridge-utils smartmontools` to the
  base package list, and `alsa-utils alsa-ucm-conf wireplumber sof-firmware
  libjack-pipewire` to the graphical audio stack. void-installer's *gated,
  opt-in* apps (browsers, `cosmic-store`, flatpak, …) are deliberately not added
  — the live image stays lean there.

### Live desktop

- **[INSTALLER-DESKTOP]** Surface the pinned Installer on the live desktop.
  `mkiso.sh` `setup_installer_desktop()` seeds `/etc/skel/Desktop` (copied into
  the live user's home by the dracut `vmklive/adduser.sh` `useradd -m` at boot)
  with `Void_Linux_Installer.sh` — a symlink to the single shipped copy,
  `/usr/bin/void-installer`, so it stays the code-only strip and there is no
  second copy of the artifact — plus an `Install Void Linux` launcher that runs
  it as root in a terminal (`Terminal=true`; a `void-installer-launch` shim
  prefers `pkexec`, falls back to `sudo`). Gated on `WANT_INSTALLER`
  (x86_64/i686); no new pinned input.
- **[LIVE-INSTALLER-CHECK]** On booting the live USB, both desktop entries — the
  `Install Void Linux.desktop` launcher *and* the `Void_Linux_Installer.sh`
  symlink, which now points at the same `void-installer-launch` wrapper instead
  of straight at the artifact — offer `Check GitHub for a newer installer
  script? [y/N]` before elevating. Bare Enter is No, so the normal case stays
  one keystroke from the installer. A *yes* runs the updater as root with
  `update --if-newer --ref main`: fetch → verify (`bash -n` + `SCRIPT_VERSION` +
  optional sha pin) → **stop before any write when the fetched sha equals the
  in-effect sha** → otherwise as-built backup + overlay install + stamp. Every
  failure mode warns and continues with the local copy — no network, a missing
  updater on the image, no privilege helper, and a RAM-only overlay (the
  persistence refusal is deferred past the up-to-date comparison, so "already
  up to date" still answers on any boot): the check can never block an
  install. To make that possible the updater is no longer flash-only —
  `mkiso.sh` bakes the tool into every image at
  `/usr/local/share/void-installer-update/` (`include_installer_updater`,
  FATAL if the source file is missing), and the tool gains a read-only `check`
  subcommand (no root, nothing written, exit 0 for either verdict). The tool
  body lives in the single shared source file `installer-update-tool.sh`,
  read by `mkiso.sh` instead of an inline heredoc — a second copy would
  silently drift. One tool location, one update path: **this change-set also
  removes `v1.11`'s flash-time surface** — `flash --update-installer` /
  `--installer-ref` / `--installer-sha256`, `_deposit_installer_tool()` and
  the deposited `/installer-update-tool.sh` copy are gone (the old flags now
  fail with a pointer to this flow), so the desktop double-click is the way
  a stick checks for a newer Installer.

### Build robustness

- **[BUILD-REPOS]** `mklive.sh` no longer appends upstream's `current/musl`
  repository to `XBPS_REPOSITORY` (upstream hard-codes main + musl + aarch64 on
  one line). Musl packages are arch-tagged `x86_64-musl` and can never be
  selected for a glibc x86_64 image, so the sync only ever fetched metadata —
  and on 2026-10-18 the mirror resolved for `repo-default.voidlinux.org` 404'd
  `current/musl/x86_64-repodata` on every host-side sync during a rebuild,
  printing an ERROR at step `[1/13]` of every run. `current` and
  `current/aarch64` are kept (the latter syncs fine and backs upstream
  cross-build support); the `Makefile`'s multi-arch `-r …/musl` is untouched —
  it serves `make`'s musl image targets, which this project does not build.
  Consequence: a musl live image built from this tree needs the entry restored
  first (recorded in `UPSTREAM.md`'s conflict table).
- **[INSTALLER-FETCH-RETRY]** `lib.sh` `installer_fetch` no longer aborts on the
  first hiccup: it retries the build-time Installer download
  (`--retry 5 --retry-delay 3 --retry-connrefused`, plus `--retry-all-errors`
  when curl ≥ 7.71 — probed, not assumed — so a truncated transfer is retried
  too). Build hosts behind a flaky or USB-tethered uplink used to lose the whole
  build at this step.
- **[BUILD-WATCH]** `voidlive-build-persist.sh build --watch` (opt-in, off by
  default) starts the shipped `builder-watch.sh` once, detached, so a stalled
  download heals itself and the build restarts from the XBPS cache. Safe to
  automate: `VLBP_WATCHED=1`, exported into the restart `BUILD_CMD`, makes a
  restarted build skip the start (no watcher spawns another watcher), and
  `builder-watch.sh` itself now holds a `.builder-watch.pid` single-instance
  lock and releases it on `TERM`/`HUP`/`EXIT` *before* exiting. `BUILD_CMD`
  pins the restart to this exact wrapper invocation (same
  desktop/greeter/cache/overlay/flash flags), which also preserves the persist
  wrapper's environment (`PERSISTENT_OVERLAY`) and its flash step — a bare
  `mkiso.sh` restart would drop both.
- **[BUILD-WATCH]** `builder-watch.sh` hardening: snapshot the running build
  command *before* killing it (previously it re-read `/proc` after the kill and
  found nothing); kill only the build's own process tree (its descendants)
  instead of a host-wide `kill -9` of every `xbps-install` on the machine; skip
  the NIC toggle in a remote (SSH) session unless forced
  (`BUILDER_WATCH_TOGGLE_NIC=auto|yes|no`, default `auto` — the tether may be
  the only way back in); append to `build.log` across heals rather than
  truncating (the truncation destroyed the failing run's evidence); honour
  `BUILDER_WATCH_STALL_SECS`; and fix a `pgrep -c` count that doubled to
  `"0\n0"` and tripped the liveness test with an "integer expression expected"
  error on every idle tick.
- **[BUILD-WATCH-DETECT]** `builder-watch.sh` now judges liveness from any of
  three signals — the newest `*.part` mtime, the XBPS **cache size**, or the
  build **tree's CPU time** — instead of `*.part` alone. Previously an xbps
  stall with **no** `*.part` on disk (cache frozen, CPU idle — e.g. a wedged
  USB tether between two downloads) went unnoticed: the build then died on its
  own and the watcher idled forever. A long CPU-bound step (unpack/configure/
  squashfs/xorriso) advances the tree's CPU time, so it still cannot
  false-stall. New knobs: `BUILDER_WATCH_RESTART_ON_DEATH=yes|no` (default
  `yes`) restarts a build that died without producing an ISO (bounded by
  `BUILDER_WATCH_MAX_HEALS`, default 12); on a completed build (ISO present,
  nothing running) the watcher exits to release its pidfile lock instead of
  blocking a later `--watch`.
- **[BUILD-WATCH-SELFKILL]** `builder-watch.sh` no longer kills **itself** when
  it heals a stalled build. With `build --watch` and no `--flash` the wrapper
  forks the watcher and then `exec`s `mkiso.sh`, so the watcher is a **child**
  of the build root; the tree kill recursed into it and `kill -9`'d the watcher
  before the heal finished. The result was the worst case: the watcher died, the
  build was left running, and only then failed on its own (observed: a real
  `--watch` run caught the stall at 10:46 but never restarted, and the build
  later died on an xbps `Failed to install`). `kill_tree` now skips `$$` (and,
  by returning before recursing, its whole subtree), so the watcher survives the
  kill, is reparented to init when the build root dies, and the heal proceeds.

## v1.1 — 2026-10-13

Pin the Installer input, single-source the shared vocabulary, and ship the
pinned Installer as the live image's installer.

### Interop

- Name the Installer artifact the per-DE gates mirror as a pinned
  **version + SHA** (`PINNED-INSTALLER` in `mkiso.sh`:
  `Void_Linux_Installer.sh` `Beta-v2.9.92` @ `83ece938…`) instead of referring
  to a sibling working tree by relative path. The seam is now an artifact, not
  a path (supervision contract §2 rule 2 / §3.2).
- Point `DESKTOP_CHOICES` / `GREETER_CHOICES` at the shared vocabulary's single
  source (`coordination/vocabulary.sh`); `coordination/check-pins.sh` now
  extracts the DE list, the per-DE recommended DM and the greeter list from
  both Live and the Installer and fails on any divergence.

### Installer

- Replace the stock upstream `installer.sh` with the pinned Installer itself:
  `installer.sh` is now the **public code-only copy** of `Void_Linux_Installer.sh`
  `Beta-v2.9.92` @ `01c6248d…` (canonical `83ece938…`), still installed as
  `/usr/bin/void-installer`. The live image now ships the curated-DE / LUKS /
  MULTI-FS installer whose Stage-2 branches the per-DE gates mirror, instead of
  the generic upstream wizard. The Installer self-provisions its outer-stage
  tooling via its live-CD package sync and reuses the seeded xbps cache, so no
  extra packages are baked into the image.

### Build and boot

- Rebuild required to pick up the new installer; verify with a fresh boot test
  (GRUB + Limine) before any publish.

## v1.0 — 2026-10-13

Initial public release.

### Persistent overlay (GRUB + Limine)

- Add the `dracut/vmklive/wait-persist-overlay.sh` pre-mount hook, which waits
  for the `rd.overlay` device before `dmsquash-live` mounts it (fixes the GRUB
  persistent-overlay race). The hook uses `return`, never `exit`, so dracut's
  `source_hook` no longer terminates `/init` and drops the boot to the
  emergency shell.
- Add `voidlive-build-persist.sh` to lay down the persistence overlay slot,
  reading the live volume label/UUID from the whole device when the ISO9660
  partition is not exposed, and numbering the slot from the on-disk partition
  table.

### COSMIC live image

- Default to `cosmic-greeter` and link PPD on the live image.
- Install `NetworkManager` so its enabled service exists on the live image.
- Fix COSMIC autologin under `greetd`.

### Build and boot

- `mklive`: make Limine the first EFI bootloader for `-B both`.

### Flash tooling

- Release an automount-held persistence partition before `mkfs`.
- Synchronise the kernel partition view and number the overlay slot from the
  on-disk table.
- Tolerate the automounter holding the target during `dd`.
- Stop a not-yet-visible partition node aborting the flash (`set -e`).
