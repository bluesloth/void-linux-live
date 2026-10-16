# Tracking upstream (void-mklive)

This tree is a customized copy of
[void-linux/void-mklive](https://github.com/void-linux/void-mklive). Most shared
files (the `dracut/`, `grub/`, `container/` trees, …) are byte-for-byte
upstream; the differences are this project's own files plus a handful of patched
upstream files — and one deleted (`installer.sh`).

## Status / base

- Upstream is wired in as the `upstream` git remote.
- The vendored snapshot is **grafted** onto upstream commit `3aa194b`
  ("mklive: use non-deprecated kcl arg for overlayfs") by a merge commit that
  changed no files. `git merge-base main upstream/master` therefore resolves to
  that commit, and normal 3-way merges work.
- Nothing tracks upstream automatically — updates are explicit (below).

## Updating

```sh
git fetch upstream
git merge upstream/master
```

- **Stock files merge automatically** (no action needed).
- **Conflicts occur only in the locally customized files below.** Resolve them
  keeping this project's intent, then `git add` + `git commit`.

### Locally customized upstream files (the only conflict candidates)

| File | Local change |
| --- | --- |
| `mklive.sh` | Limine EFI boot, opt-in persistent overlay (`-R`), DE/greeter plumbing |
| `mkiso.sh` | per-DE flavors, greeter selection, DE extras |
| `lib.sh` | `installer_fetch` — fetch the `Void_Linux_Installer` at build time |
| `mknet.sh` | fetch the installer (build-time) instead of copying `installer.sh` |
| `dracut/netmenu/module-setup.sh` | comment only |
| `dracut/vmklive/display-manager-autologin.sh` | SDDM session marker |
| `installer.sh` | **deleted** — Live fetches the Installer at build time; do **not** restore upstream's el-cheapo installer |
| `README.md`, `README.md.in` | project docs |
| `.gitignore` | ignores `build.log*` / `build.status` |

### Local-only files (never conflict)

`postsetup.sh`, `voidlive-build-persist.sh`, `builder-watch.sh`,
`CHEATSHEET.md`, `readme.txt`, `LICENSING.md`, `includes/etc/nftables.conf`,
extra `keys/*`.

## After any merge

```sh
# -O extglob: mklive.sh uses extglob patterns (e.g. linux+([0-9.])), which a
# plain `bash -n` reports as a syntax error even though the script runs fine.
bash -O extglob -n mkiso.sh mklive.sh lib.sh
sh -n postsetup.sh
# upstream re-adds installer.sh on merge: keep it deleted (Live fetches the
# Installer at build time — see lib.sh installer_fetch):
git rm --ignore-unmatch installer.sh
# then rebuild an ISO and boot it (the real test)
```

## Verify the current base

```sh
git merge-base main upstream/master
git rev-list --left-right --count main...upstream/master   # left=ours, right=upstream-only
```

## Keeping future conflicts small

- Prefer adding your own files; every line patched inside an upstream file
  becomes a future conflict site.
- `mklive.sh` is the main hotspot. If desired, move the Limine function and the
  persistent-overlay logic into a separate sourced file so only a few hook lines
  stay forked.
- Record the base: the graft commit and `git merge-base` are the source of truth.
