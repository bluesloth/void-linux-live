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
  unless `--force`). `voidlive-build-persist.sh flash … --update-installer`
  deposits a new self-contained `installer-update-tool.sh` (partition root +
  overlay upperdir, same deposit pattern as the cache tool) and runs it against
  the upperdir, so the stick boots with the fetched installer on first boot.
  `--installer-ref <tag|commit|main>` picks what to fetch (default `main`; same
  URL seam as the build-time `installer_fetch`), `--installer-sha256 <sha>`
  optionally pins it. On the booted persistent live system the deposited tool is
  `/installer-update-tool.sh`: `status` (ISO build vs in-effect copy vs overlay
  stamp, with the sha256 to pin on the next run), `update [--ref R] [--sha256 S]`
  (fetch → verify with `bash -n` + `SCRIPT_VERSION` + optional pin → back up the
  as-built copy once → install), and `restore` (copy the as-built backup back —
  never a delete, which would whiteout the squashfs copy for good). Both
  `build --update-installer --flash …` and standalone `flash` accept the flags;
  a failed update never fails the flash (the stick keeps the ISO's installer).
  Also swallowed by `build`'s parse loop so the flags never leak to mklive.

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

### Build robustness

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
