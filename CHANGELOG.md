# Changelog

All notable changes to **Void Linux Live** — a customized fork of
[`void-linux/void-mklive`](https://github.com/void-linux/void-mklive) — are
documented in this file.

Releases are tagged `v1.0`, `v1.1`, `v1.2`, … (minor bumps for routine updates;
a major bump is deliberate). Each tag is a full snapshot of the tracked tree —
the diff against the previous tag is that release's change set, and each release
commit lists the underlying source commits.

## Unreleased

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
