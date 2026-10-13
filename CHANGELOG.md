# Changelog

All notable changes to **Void Linux Live** — a customized fork of
[`void-linux/void-mklive`](https://github.com/void-linux/void-mklive) — are
documented in this file.

Releases are tagged `v1.0`, `v1.1`, `v1.2`, … (minor bumps for routine updates;
a major bump is deliberate). Each tag is a full snapshot of the tracked tree —
the diff against the previous tag is that release's change set, and each release
commit lists the underlying source commits.

## Unreleased

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
