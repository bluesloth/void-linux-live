#!/bin/sh
set -eu

# Build a Void Linux live ISO (opencode-ready userland) with a selectable
# desktop environment and greeter, and/or flash it onto a USB stick with a
# persistent overlay partition.  The default is KDE Plasma + SDDM; every other
# pairing mirrors void-installer (see --desktop / --greeter below).
#
# The boot cmdline baked into the ISO contains rd.overlay=LABEL=VOID_OVL, so
# once a partition labeled VOID_OVL exists on the stick, dracut mounts it as
# the writable upper layer: anything changed while running the live system
# (installed packages, config, files) survives reboots.
#
# Usage:
#   sudo ./voidlive-build-persist.sh build [--desktop <de>] [--greeter <g>] [--persist] [--flash <device>] [--watch] [--build-env auto|container|chroot|native] [mklive-args...]
#   sudo ./voidlive-build-persist.sh flash <device> [live-iso] [--overlay-size-mib MiB]
#
#   build                 Build the ISO (no subcommand is treated as build, so
#                         old "sudo ./build.sh -B grub" invocations still work).
#                         Extra args are passed to mklive.sh, e.g. -B grub|limine|both.
#   build --persist       Add rd.overlay=LABEL=VOID_OVL to the boot cmdline so the
#                         image persists to a VOID_OVL partition. Default is off,
#                         which is right for plain USB and Ventoy sticks.
#   build --desktop <de>  Desktop-environment flavor (mkiso -b). One of kde
#                         (default), gnome, cinnamon, xfce, mate, lxqt, cosmic,
#                         none — matching void-installer — plus mkiso's own
#                         base, enlightenment, lxde and xfce-wayland. cosmic
#                         uses the third-party bluesloth repo (pinned signing
#                         key vendored in keys/).
#   build --greeter <g>   Display manager / greeter (mkiso -g). One of auto
#                         (default: the DM void-installer recommends for the
#                         chosen desktop), sddm, gdm, lightdm, lightdm-gtk,
#                         lightdm-slick, cosmic-greeter, or none.
#   build --cache <dir>   XBPS package-cache directory for the build (mklive -c).
#                         Default: ./xbps-cachedir-<arch> in THIS folder, so repeated
#                         builds reuse already-downloaded packages instead of
#                         re-fetching from the mirror each time. If that default is
#                         missing/empty, an auto-detected POPULATED cache under
#                         /run/media (arch-matched, writable, real .xbps, newest
#                         first — the installer's own [LOCAL-CACHE] detection) is
#                         used instead. An explicit --cache ALWAYS wins.
#   build --refresh-cache Update the cache before building: refresh the XBPS
#                         repository index so the build resolves current versions
#                         (xbps 0.60 keeps indexes in the rootdir's
#                         /var/db/xbps/<url>, NOT in the -c cache dir; the build
#                         then pulls the newer versions of everything the new
#                         image needs INTO the cache). Existing packages are kept.
#                         Useful before creating fresh media.
#   build --replace-cache Wipe the cache (delete all *.xbps/*.sig2) then refresh
#                         the index — the build re-downloads cleanly. Also runs
#                         the /run/media auto-detection so it can replace the
#                         populated top-level cache rather than a fresh dir.
#   build --flash <dev>   Build, then flash the freshly built ISO to <device> with
#                         a persistence partition, in one command. To persist, add
#                         --persist (see below). --overlay-size-mib is also honored.
#   build --seed-cache    After flashing, copy the XBPS package cache into the new
#                         VOID_OVL partition so a later install run can reuse the
#                         packages from disk. Cache source is --cache <dir>, the
#                         auto-detected populated cache, or the default
#                         ./xbps-cachedir-<arch> in THIS folder. The cache is placed
#                         both at the partition root and inside the dmsquash-live
#                         overlay upperdir (LiveOS/overlay-<label>-<uuid>/), so it is
#                         reachable whether dracut holds the partition as the overlay
#                         or udisks mounts it under /run/media. ALSO deposits
#                         xbps-cache-tool.sh alongside it: a self-contained updater
#                         (/xbps-cache-tool.sh on the booted persistent live system)
#                         that can status/update/replace/download the seeded cache
#                         with the same refresh/wipe semantics as
#                         --refresh-cache/--replace-cache.
#   build --watch         Wrap the build in builder-watch.sh: a background
#                         watchdog that detects a stalled download (.part files
#                         stop advancing) on a flaky/uplink-tethered host,
#                         optionally bounces the NIC, and restarts THIS build
#                         (same flags) so it resumes from the XBPS cache. It
#                         writes build.log (appended across heals) and
#                         build.status. Started once and detached (VLBP_WATCHED
#                         guard + a pidfile lock prevent watcher storms); set
#                         BUILDER_WATCH_TOGGLE_NIC=no to heal by restart only,
#                         without touching the link. Off by default.
#   flash <device>        Write an ISO to the block device and add a persistence
#                         partition. live-iso defaults to the newest
#                         void-live-*.iso in $PWD. All data on <device> is destroyed.
#                         Also initializes the LiveOS/overlay-<live-label>-<live-uuid>
#                         upper + LiveOS/ovlwork work dirs that dracut's dmsquash-live
#                         requires before it will mount the partition as the overlay
#                         (a bare ext4 LABEL=VOID_OVL gets ignored -> RAM overlay).
#                         Only images built with 'build --persist' will actually
#                         use that partition.
#
# Example:
#   sudo ./voidlive-build-persist.sh build -B grub
#   sudo ./voidlive-build-persist.sh build --persist      # persistent image
#   sudo ./voidlive-build-persist.sh flash /dev/sdb
#   sudo ./voidlive-build-persist.sh build --persist --flash /dev/sdb
#   sudo ./voidlive-build-persist.sh build --persist --seed-cache --flash /dev/sdb
#   sudo ./voidlive-build-persist.sh build --persist --seed-cache --both --flash /dev/sdb
#   sudo ./voidlive-build-persist.sh build --persist --seed-cache --both --flash /dev/sdb --refresh-cache
#   sudo ./voidlive-build-persist.sh build --persist --seed-cache --both --flash /dev/sdb --replace-cache
#   sudo ./voidlive-build-persist.sh flash /dev/sdb void-live-x86_64-20260915-kde.iso --overlay-size-mib 81920
#
# Building needs the Void XBPS toolchain that mklive.sh/lib.sh use.  On a
# non-Void host (Debian, Arch, ...) the build automatically runs in a Void
# environment instead: a podman/docker container when one is available (image
# from container/Containerfile), otherwise a Void ROOTFS chroot bootstrapped
# under ./.void-buildenv.  Force a mode with --build-env container|chroot|native
# (see `build --help`).  `flash` never needs Void and always runs on the host.

cd "$(dirname "$0")"

# Absolute path to this script + the raw argument list, captured before the
# dispatcher/`build` parser consumes them.  `build --watch` hands these to
# builder-watch.sh as BUILD_CMD so a heal restarts THIS exact invocation (same
# desktop/greeter/cache/overlay/flash flags).  Args are space-joined, which is
# fine for the space-free flags this wrapper accepts.
SELF_ABS="$PWD/$(basename "$0")"
ORIG_ARGV="$*"

OVERLAY_LABEL="VOID_OVL"
OVERLAY_SIZE_MIB="${OVERLAY_SIZE_MIB:-2048}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1 (install it first)"
}

# _start_watch: opt-in build watchdog (build --watch).
#
# Starts builder-watch.sh once, detached, so a stalled uplink heals itself and
# the build resumes.  Guards that make auto-engagement safe:
#   * VLBP_WATCHED=1 in the exported environment makes a restarted build skip
#     this function — no watcher can spawn another watcher;
#   * builder-watch.sh also holds its own pidfile lock (belt and braces);
#   * BUILD_CMD pins the restart to THIS exact invocation (same desktop /
#     greeter / cache / overlay / flash flags), because builder-watch cannot
#     re-detect a command line it is about to kill — and a bare mkiso restart
#     would drop the persist wrapper's environment (PERSISTENT_OVERLAY) and
#     its flash step.
# The NIC-toggle behaviour of the watcher is controlled by
# BUILDER_WATCH_TOGGLE_NIC (auto|yes|no); see builder-watch.sh.
_start_watch() {
    [ -x ./builder-watch.sh ] || die "--watch: ./builder-watch.sh not found"
    [ -x ./mkiso.sh ] || die "--watch: ./mkiso.sh not found"
    case "${VLBP_WATCHED:-no}" in
        1|yes)
            echo "NOTE: --watch ignored (VLBP_WATCHED set: already supervised)." >&2
            return 0 ;;
    esac
    echo "==> --watch: starting builder-watch.sh (self-healing supervisor) ..."
    export VLBP_WATCHED=1
    BUILD_CMD="VLBP_WATCHED=1 $SELF_ABS $ORIG_ARGV"
    export BUILD_CMD
    setsid nohup ./builder-watch.sh >/dev/null 2>&1 &
}

# Desktop/greeter vocabularies accepted by --desktop / --greeter.  This is the
# shared DE/greeter vocabulary: the Installer's Stage-2 DE list (the authority)
# plus mkiso's live-only variants (base/enlightenment/lxde/xfce-wayland).  The
# canonical lists live in coordination/vocabulary.sh and are cross-checked
# against both projects by coordination/check-pins.sh (SUPERVISION-CONTRACT §5);
# the gates these drive mirror the Installer fetched at build time (mkiso.sh
# INSTALLER-REF; lib.sh installer_fetch).
DESKTOP_CHOICES="kde gnome cinnamon xfce mate lxqt cosmic none base enlightenment lxde xfce-wayland"
GREETER_CHOICES="auto sddm gdm lightdm lightdm-gtk lightdm-slick cosmic-greeter none"

_is_desktop() {
    for _d in $DESKTOP_CHOICES; do [ "$1" = "$_d" ] && return 0; done
    return 1
}

_is_greeter() {
    for _g in $GREETER_CHOICES; do [ "$1" = "$_g" ] && return 0; done
    return 1
}

usage() {
    cat <<-EOH
	Usage: $0 <build|flash> [arguments]

build [--persist] [--desktop <de>] [--greeter <g>] [--cache <dir>] [--refresh-cache] [--replace-cache] [--seed-cache] [--flash <device>] [--watch] [--overlay-size-mib MiB] [--bootloader <grub|limine|both>] [--build-env auto|container|chroot|native] [mklive-args...]
    Build the live ISO (default when no subcommand is given); KDE + SDDM by default.
    --desktop <de> selects the desktop: kde (default), gnome, cinnamon, xfce, mate,
    lxqt, cosmic, none (void-installer's list), or base/enlightenment/lxde/xfce-wayland.
    cosmic pulls cosmic-desktop-full from the third-party bluesloth repo (pinned
    signing key vendored in keys/).
    --greeter <g> selects the display manager / greeter: auto (default — the DM
    void-installer recommends for the desktop), sddm, gdm, lightdm, lightdm-gtk,
    lightdm-slick, cosmic-greeter, or none.
    --persist adds the persistent-overlay kernel arg (rd.overlay=LABEL=VOID_OVL);
    default is off (plain USB / Ventoy).
    --cache <dir> sets the XBPS package-cache directory for the build
    (default: ./xbps-cachedir-<arch> in this folder, shared across rebuilds).
    --refresh-cache refreshes the XBPS repository index before building — under
    xbps 0.60 that index lives in the rootdir's /var/db/xbps/<url>, not in the
    cache dir; the build then pulls the current versions it resolves into the
    cache (existing packages are kept).
    --replace-cache wipes all *.xbps/*.sig2 from the cache and refreshes the index
    so the build re-downloads cleanly. Both operate on the resolved cache dir.
    --seed-cache also copies that cache into the VOID_OVL partition during
    flash (both at the partition root and inside the dmsquash-live overlay
    upperdir), so a later install can reuse the packages from disk, and
    deposits xbps-cache-tool.sh alongside it: /xbps-cache-tool.sh on the
    booted persistent live system (status/update/replace/download the cache).
    --flash <device> builds, then writes the result to <device> with a
    VOID_OVL persistence partition in one command; the built ISO is used
    automatically.
    --watch wraps the build in builder-watch.sh (detached): it detects a
    stalled download on a flaky/tethered uplink, optionally bounces the NIC
    (BUILDER_WATCH_TOGGLE_NIC=auto|yes|no), and restarts this exact build so
    it resumes from the XBPS cache, appending to build.log. Started once
    (VLBP_WATCHED guard + pidfile lock). Off by default.
    --bootloader <grub|limine|both> (or the shorthand --grub/--limine/--both)
    selects the EFI bootloader(s) for the image; translated to -B for
    mkiso/mklive. User -B flags after it still win (getopts keeps the last).
    When the cache default resolves to a missing/empty dir, a POPULATED
    xbps-cachedir-<arch> under /run/media is auto-detected and used instead
    (an explicit --cache always wins).
    --build-env auto|container|chroot|native selects where the build runs.
    mklive.sh needs the Void XBPS toolchain, which non-Void hosts lack; rather
    than fail, the build runs in a Void userspace. auto (default) uses a
    podman/docker container when one is present (image built from
    container/Containerfile on first use), else bootstraps a Void ROOTFS chroot
    under ./.void-buildenv. container/chroot force one; native runs mklive here
    (Void hosts only). --flash is always done on the host, after the build.
    Remaining args pass through to mklive.sh.

	flash <device> [live-iso] [--seed-cache] [--refresh-cache] [--replace-cache] [--cache <dir>] [--overlay-size-mib MiB]
	    Write an ISO to <device> and append a VOID_OVL persistence partition,
	    initializing the LiveOS/overlay-<live-label>-<live-uuid> + LiveOS/ovlwork
	    directories dracut needs to actually use it as the persistent overlay.
	    live-iso defaults to the newest void-live-*.iso in \$PWD.
	    All data on <device> is destroyed.

	Example: sudo $0 flash /dev/sdb void-live-x86_64-20260915-kde.iso --overlay-size-mib 81920
	EOH
}

# Find a populated XBPS package cache: arch-matched (uname -m), writable,
# containing real .xbps files, newest-touched first. Scans the live overlay
# root and the dracut overlay mountpoints FIRST — a persistent VOID_OVL
# partition is held by dracut at /run/initramfs/overlayfs and/or
# /run/overlayfs-backing and is often NOT auto-mounted by udisks under
# /run/media — then the Void_Linux_Installer.sh _local_cache_detect() locations
# under /run/media. This keeps build/flash able to reuse the SAME cache the
# installer would auto-pick on any boot (persistent or plain).
_cache_detect() {
    _ca="$(uname -m)"
    _list=$(ls -1dt /xbps-cachedir-* \
        /run/initramfs/overlayfs/xbps-cachedir-* \
        /run/overlayfs-backing/xbps-cachedir-* \
        /run/media/*/xbps-cachedir-* \
        /run/media/*/*/xbps-cachedir-* 2>/dev/null || true)
    for _cd in $_list; do
        [ -n "$_cd" ] || continue
        [ -d "$_cd" ] || continue
        case "$_cd" in
            *"xbps-cachedir-${_ca}") : ;;
            *) continue ;;
        esac
        [ -w "$_cd" ] || continue
        [ -n "$(find "$_cd" -maxdepth 1 -name '*.xbps' -print -quit 2>/dev/null)" ] || continue
        printf '%s\n' "$_cd"
        unset _ca _list _cd
        return 0
    done
    unset _ca _list
    return 1
}

# Resolve the cache directory: an EXPLICIT path always wins; otherwise the
# project-default ./xbps-cachedir-<arch>; if that default is missing or EMPTY,
# fall back to an auto-detected POPULATED cache under /run/media.
_cache_resolve() {
    _cr="${1:-}"
    _cr_explicit="${2:-no}"
    [ -n "$_cr" ] || _cr="$(pwd -P)/xbps-cachedir-$(uname -m)"
    if [ "$_cr_explicit" != "yes" ] && \
       { [ ! -d "$_cr" ] || [ -z "$(find "$_cr" -maxdepth 1 -name '*.xbps' -print -quit 2>/dev/null)" ]; }; then
        _det=$(_cache_detect || true)
        if [ -n "$_det" ]; then
            echo "NOTE: default cache is missing/empty; using auto-detected populated cache: $_det" >&2
            _cr="$_det"
        fi
        unset _det
    fi
    unset _cr_explicit
    printf '%s\n' "$_cr"
}

# Optionally refresh / replace the cache before a build or a --seed-cache flash:
#   --replace-cache  delete all cached *.xbps/*.sig2, then refresh the index
#   --refresh-cache  refresh the XBPS repository index only (keep packages)
# Refreshing updates the RUNNING host's index under /var/db/xbps/<url> — xbps
# 0.60 never stores indexes in the -c cache dir (verified empirically: a bare
# `xbps-install -S -c <dir>` wrote x86_64-repodata to /var/db/xbps/... and left
# the cache dir holding only .xbps/.sig2). The refreshed index is what makes the
# next build / download resolve current versions and fetch their payloads into
# the cache. Any failure here is a NOTE, never a hard error.
_cache_maintain() {
    _cm="${1:-}"
    [ -n "$_cm" ] || return 0
    if [ "${REPLACE_CACHE:-no}" = "yes" ] || [ "${REFRESH_CACHE:-no}" = "yes" ]; then
        [ -d "$_cm" ] || mkdir -p "$_cm"
        if [ "${REPLACE_CACHE:-no}" = "yes" ]; then
            echo "==> replacing cache: removing *.xbps/*.sig2 from $_cm"
            find "$_cm" -maxdepth 1 \( -name '*.xbps' -o -name '*.sig2' \) -delete 2>/dev/null || true
        fi
        if command -v xbps-install >/dev/null 2>&1; then
            echo "==> refreshing repository index (lands under /var/db/xbps, not the cache) for $_cm"
            xbps-install -S -c "$_cm" >/dev/null 2>&1 \
                || echo "NOTE: index refresh failed (network/repo?); continuing with existing data." >&2
        else
            echo "NOTE: xbps-install not found on host; index refresh skipped." >&2
        fi
    fi
}

# Deposit the self-contained cache-maintenance tool into the VOID_OVL partition
# (written via temp-file + mv so a mid-write power cut can never leave a
# truncated tool on the stick). On the booted persist live system it sits at
# /xbps-cache-tool.sh and can update / replace the seeded /xbps-cachedir-<arch>
# with the same semantics this script's --refresh-cache / --replace-cache use.
_deposit_cache_tool() {
    _dt_root="${1:?deposit root dir missing}"
    mkdir -p "$_dt_root"
    _dt_dest="$_dt_root/xbps-cache-tool.sh"
    _dt_tmp="$_dt_root/.xbps-cache-tool.sh.tmp.$$"
    cat > "$_dt_tmp" <<'XBPS_CACHE_TOOL_EOF'
#!/usr/bin/env sh
set -eu

# xbps-cache-tool.sh -- maintain the XBPS package cache this stick carries.
# Deposited by voidlive-build-persist.sh (build --persist --seed-cache --flash)
# into the root of the VOID_OVL persistence partition AND into the dmsquash-live
# overlay upperdir (LiveOS/overlay-<label>-<uuid>/); on the booted persistent
# live system it is /xbps-cache-tool.sh and the seeded cache is
# /xbps-cachedir-<arch>. On a regular Linux box (or a non-persistent boot) the
# cache (and walk) is auto-detected at the live-overlay root, the dracut overlay
# mountpoints, and under /run/media with the SAME first-wins rules the
# Void_Linux_Installer / _local_cache_detect() uses, so this tool always targets
# the cache an install would auto-pick.
#
#   status                         print the resolved cache location + package count
#   update                         refresh the repository index (keep packages)
#   replace                        wipe all *.xbps/*.sig2, refresh the index
#   replace --pkgs 'pkg ...'       wipe, refresh, then re-download the listed packages
#   download --pkgs 'pkg ...'      refresh, then download the listed packages
#
# Options:
#   --cache <dir>     pin the cache directory (auto-detect otherwise)
#   --pkgs '<pkg...>' space-separated package list for download / replace
#
# Examples:
#   /xbps-cache-tool.sh status
#   /xbps-cache-tool.sh update
#   /xbps-cache-tool.sh replace
#   /xbps-cache-tool.sh replace --pkgs 'base-system kde-plasma'
#   /xbps-cache-tool.sh download --pkgs 'base-system kde-plasma'
#
# update / replace / download must run as root (repodata refresh + downloads
# write into the cache). status works for anyone.

CACHE_DIR=
CMD=
PKGS=

warn() { echo "WARN: $*" >&2; }
die()  { echo "FATAL: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
    echo "Usage: $(basename "$0") <status|update|replace|download> [options]"
    echo "  status            print the resolved cache dir + package count"
    echo "  update            refresh the repository index (keep existing packages)"
    echo "  replace           wipe all *.xbps/.sig2, then refresh the index"
    echo "  download          refresh, then download packages (--pkgs required)"
    echo "  --cache <dir>     pin the cache directory"
    echo "  --pkgs '<pkg...>' package list for download/replace"
    exit 0
}

# newest-first candidate cache dirs: live-overlay root, the dracut overlay
# mountpoints (a persistent VOID_OVL partition is held by dracut there and is
# often not auto-mounted by udisks), then /run/media depth-1 and depth-2 (the
# udisks /<user>/<uuid> layout)
_cache_candidates() {
    ls -1dt /xbps-cachedir-* \
        /run/initramfs/overlayfs/xbps-cachedir-* \
        /run/overlayfs-backing/xbps-cachedir-* \
        /run/media/*/xbps-cachedir-* \
        /run/media/*/*/xbps-cachedir-* 2>/dev/null || true
}

# Prefer a POPULATED, writable, arch-matching dir; fall back to any writable,
# arch-matching dir (an empty one can be seeded by update).
_cache_detect() {
    _ca=$(uname -m)
    _fallback=
    for _cd in $(_cache_candidates); do
        [ -n "$_cd" ] || continue
        [ -d "$_cd" ] || continue
        case "$_cd" in
            *"xbps-cachedir-${_ca}") : ;;
            *) continue ;;
        esac
        [ -w "$_cd" ] || continue
        if [ -n "$(find "$_cd" -maxdepth 1 -name '*.xbps' -print -quit 2>/dev/null)" ]; then
            printf '%s\n' "$_cd"
            unset _ca _cd
            return 0
        fi
        [ -n "$_fallback" ] || _fallback="$_cd"
    done
    if [ -n "$_fallback" ]; then
        printf '%s\n' "$_fallback"
        unset _ca _cd _fallback
        return 0
    fi
    unset _ca _cd _fallback
    return 1
}

_cache_resolve() {
    if [ -n "$CACHE_DIR" ]; then
        printf '%s\n' "$CACHE_DIR"
    else
        _d=$(_cache_detect || true)
        if [ -n "$_d" ]; then
            printf '%s\n' "$_d"
        else
            printf '%s\n' "/xbps-cachedir-$(uname -m)"
        fi
        unset _d
    fi
}

_ensure() {
    [ -d "$1" ] || mkdir -p "$1"
    [ -w "$1" ] || die "cache dir '$1' is not writable (run as root? medium read-only?)"
}

_refresh() {
    echo "==> refreshing repository index (lands under /var/db/xbps, not the cache) for $1"
    xbps-install -S -c "$1" >/dev/null 2>&1 \
        || warn "index refresh failed (network/repo?); continuing with existing data."
    echo "    done."
}

_wipe() {
    echo "==> wiping *.xbps/*.sig2 from $1/"
    find "$1" -maxdepth 1 \( -name '*.xbps' -o -name '*.sig2' \) -delete 2>/dev/null || true
}

_download() {
    _scratch=$(mktemp -d /tmp/xbps-cache-tool.XXXXXX)
    trap 'rm -rf "$_scratch"' EXIT
    echo "==> downloading into cache: $2"
    # shellcheck disable=SC2086
    xbps-install -r "$_scratch" -c "$1" -y $PKGS || \
        warn "download failed (network/mirror?); packages already fetched stay in the cache."
}

cmd_status() {
    _c=$(_cache_resolve)
    if [ -d "$_c" ]; then
        _n=$(find "$_c" -maxdepth 1 -name '*.xbps' 2>/dev/null | wc -l)
        _s=$(du -sh "$_c" 2>/dev/null | awk '{print $1}')
        _w=yes; [ -w "$_c" ] || _w=no
        echo "cache:   $_c"
        echo "arch:    $(uname -m)"
        echo "packages: $_n ($_s)"
        echo "writable: $_w"
        [ "$_w" = "no" ] && echo "NOTE: not writable -- update/replace will fail." >&2
    else
        echo "no cache yet at $_c"
        echo "run '$0 update' to create it and refresh the repository index."
    fi
    return 0
}

cmd_update() {
    [ "$(id -u)" -eq 0 ] || die "update requires root (status works without)"
    _c=$(_cache_resolve)
    _ensure "$_c"
    _refresh "$_c"
    echo "update complete: $_c"
}

cmd_replace() {
    [ "$(id -u)" -eq 0 ] || die "replace requires root (status works without)"
    _c=$(_cache_resolve)
    _ensure "$_c"
    _wipe "$_c"
    _refresh "$_c"
    if [ -n "$PKGS" ]; then
        _download "$_c" "$PKGS"
    fi
    echo "replace complete: $_c"
}

cmd_download() {
    [ "$(id -u)" -eq 0 ] || die "download requires root (status works without)"
    [ -n "$PKGS" ] || die "download requires --pkgs '<pkg ...>'"
    _c=$(_cache_resolve)
    _ensure "$_c"
    _refresh "$_c"
    _download "$_c" "$PKGS"
    echo "download complete: $_c"
}



while [ "$#" -gt 0 ]; do
    case "$1" in
        status|update|replace|download) CMD="$1"; shift ;;
        --cache)
            [ "$#" -ge 2 ] || die "--cache requires a directory"
            CACHE_DIR=$(readlink -f "$2" 2>/dev/null || echo "$2")
            shift 2
            ;;
        --cache=*) CACHE_DIR="${1#*=}"; shift ;;
        --pkgs)
            [ "$#" -ge 2 ] || die "--pkgs requires a package list"
            PKGS="$2"
            shift 2
            ;;
        -h|--help) usage ;;
        *) die "unknown argument: $1 (try --help)" ;;
    esac
done

[ -n "$CMD" ] || usage

case "$CMD" in
    status)   cmd_status ;;
    update)   cmd_update ;;
    replace)  cmd_replace ;;
    download) cmd_download ;;
esac
XBPS_CACHE_TOOL_EOF
    chmod 0755 "$_dt_tmp"
    mv -f "$_dt_tmp" "$_dt_dest"
    echo "Deposited cache updater: $_dt_dest"
    echo "  (booted live system: /xbps-cache-tool.sh -- run it as root: /xbps-cache-tool.sh update)"
    unset _dt_root _dt_dest _dt_tmp
}

# ---------------------------------------------------------------------------
# Universal build environment
#
# mklive.sh/lib.sh are Void-native: they need the XBPS toolchain in $PATH
# (xbps-uhelper computes the host arch; xbps-install provisions the build) and
# they chroot + bind-mount.  On any other distribution `xbps-uhelper arch`
# fails, HOSTARCH comes back empty, lib.sh's register_binfmt() then misreads a
# NATIVE x86_64 build as a foreign-architecture one and aborts with the
# misleading "qemu-x86_64 binary is missing" error -- even though a native
# build needs no qemu at all.
#
# Rather than fail, run the build inside a Void userspace:
#   auto (default)  podman/docker container if available, else a Void ROOTFS
#                   chroot bootstrapped from the official tarball, else error
#   container       require and use podman/docker
#   chroot          require and use a bootstrapped Void ROOTFS chroot
#   native          never wrap; run mklive here (valid only on Void Linux)
#
# `flash` is plain host shell (dd, sfdisk, mkfs.ext4, ext4 overlay init) and is
# NOT wrapped, so it runs on any distribution.  `build --flash <dev>` builds in
# the Void environment and then flashes on the host.
# ---------------------------------------------------------------------------

BUILD_ENV_IMAGE="${BUILD_ENV_IMAGE:-void-mklive:latest}"
# Container network mode.  "host" (default) sidesteps resolver/NAT problems in
# rootful podman's bridge network -- e.g. systemd-resolved's 127.0.0.53 stub, or
# a LAN-only nameserver the bridge cannot reach -- which otherwise fail the
# build with "Transient resolver failure".  The build only needs to reach the
# Void mirrors.  Override if you need isolation (e.g. BUILD_ENV_NETWORK=none for
# an offline build, or a custom network name).
BUILD_ENV_NETWORK="${BUILD_ENV_NETWORK:-host}"
BUILD_ENV_DIR="${BUILD_ENV_DIR:-$PWD/.void-buildenv}"
BUILD_ENV_ROOTFS_BASE="${BUILD_ENV_ROOTFS_BASE:-https://repo-default.voidlinux.org/live/current}"

# True when the XBPS toolchain mklive/lib.sh require is present in $PATH.
_on_void() {
    command -v xbps-uhelper >/dev/null 2>&1 &&
    command -v xbps-install >/dev/null 2>&1 &&
    command -v xbps-reconfigure >/dev/null 2>&1
}

# Print "podman" or "docker" (podman preferred) when one is in $PATH.
_container_runtime() {
    for _rt in podman docker; do
        if command -v "$_rt" >/dev/null 2>&1; then
            printf '%s\n' "$_rt"
            unset _rt
            return 0
        fi
    done
    unset _rt
    return 1
}

# GET a URL to stdout / to a file (curl or wget).
_fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$1"
    else
        die "need curl or wget to bootstrap the Void build environment"
    fi
}

_fetch_to() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$2" "$1"
    else
        die "need curl or wget to bootstrap the Void build environment"
    fi
}

# Print the newest void-<arch>-ROOTFS-*.tar.xz URL under $BUILD_ENV_ROOTFS_BASE.
_rootfs_url() {
    _url_list=$(_fetch "$BUILD_ENV_ROOTFS_BASE/" 2>/dev/null || true)
    _file=$(printf '%s\n' "$_url_list" \
        | grep -oE "void-$1-ROOTFS-[0-9]+\.tar\.xz" | sort -u | tail -n1)
    [ -n "$_file" ] || die "no void-$1 ROOTFS tarball found at $BUILD_ENV_ROOTFS_BASE"
    printf '%s/%s\n' "$BUILD_ENV_ROOTFS_BASE" "$_file"
    unset _url_list _file
}

# Minimal Void packages a from-scratch ROOTFS needs to run mklive here: the
# tools lib.sh declares (cp/echo/cat/printf/which/mountpoint/mount/umount/
# modprobe) plus what this wrapper and mklive invoke directly (findutils, awk,
# sed, grep, tar, xz, readlink, and the ISO filesystem tools mkfs.vfat/ext3).
_chroot_pkgs() {
    printf '%s' "bash coreutils findutils gawk sed grep tar xz which util-linux kmod e2fsprogs dosfstools"
}

# Mount the pseudo-filesystems a Void ROOTFS needs (/dev /proc /sys ...) if not
# already mounted.  Errors are non-fatal: the caller still tries to run.
_env_mount_pseudo() {
    _r="$1"
    for _d in dev dev/pts dev/shm proc sys; do
        mkdir -p "$_r/$_d"
        if ! mountpoint -q "$_r/$_d"; then
            if mount --rbind "/$_d" "$_r/$_d" 2>/dev/null; then
                mount --make-rslave "$_r/$_d" 2>/dev/null || true
            fi
        fi
    done
    unset _r _d
}

_env_umount_pseudo() {
    _r="$1"
    for _d in sys proc dev/shm dev/pts dev; do
        umount -R "$_r/$_d" 2>/dev/null || umount -l "$_r/$_d" 2>/dev/null || true
    done
    unset _r _d
}

# Ensure a Void ROOTFS for the HOST arch exists (download, extract and provision
# once) and print its path to stdout; all progress goes to stderr so the path
# can be captured with $(...).
_ensure_rootfs() {
    _arch=$(uname -m)
    _root="$BUILD_ENV_DIR/rootfs-$_arch"
    if [ -x "$_root/usr/bin/xbps-uhelper" ] && [ -e "$_root/.void-buildenv-ready" ]; then
        printf '%s\n' "$_root"
        unset _arch _root
        return 0
    fi
    _url=$(_rootfs_url "$_arch")
    _tb="$BUILD_ENV_DIR/$(basename "$_url")"
    mkdir -p "$BUILD_ENV_DIR"
    if [ ! -s "$_tb" ]; then
        echo "==> downloading Void ROOTFS ($_arch): $(basename "$_url")" >&2
        _fetch_to "$_url" "$_tb"
    fi
    if [ ! -x "$_root/usr/bin/xbps-uhelper" ]; then
        echo "==> extracting Void ROOTFS to $_root" >&2
        mkdir -p "$_root"
        tar -xf "$_tb" -C "$_root"
        [ -x "$_root/usr/bin/xbps-uhelper" ] || die "ROOTFS bootstrap failed: no xbps-uhelper in $_root"
    fi
    if [ ! -e "$_root/.void-buildenv-ready" ]; then
        echo "==> provisioning build tools inside the ROOTFS (one-time)" >&2
        [ -f /etc/resolv.conf ] && cp -f /etc/resolv.conf "$_root/etc/resolv.conf" 2>/dev/null || true
        # Everything below talks to the user, not to the caller: this function's
        # stdout is captured by $(...) for the ROOTFS path, so it must stay clean.
        {
            _env_mount_pseudo "$_root"
            # The published ROOTFS can predate the current repository, whose
            # metadata the bundled xbps may refuse to process ("The 'xbps'
            # package must be updated").  Update xbps itself first, then the
            # full system upgrade.
            chroot "$_root" /usr/bin/xbps-install -Suy xbps || {
                _env_umount_pseudo "$_root"
                die "updating xbps inside the ROOTFS failed"
            }
            chroot "$_root" /usr/bin/xbps-install -Suy || {
                _env_umount_pseudo "$_root"
                die "xbps-install -Suy failed while provisioning the ROOTFS"
            }
            # shellcheck disable=SC2046
            chroot "$_root" /usr/bin/xbps-install -y $(_chroot_pkgs) || {
                _env_umount_pseudo "$_root"
                die "provisioning the ROOTFS failed"
            }
            _env_umount_pseudo "$_root"
        } 1>&2
        : > "$_root/.void-buildenv-ready"
    fi
    printf '%s\n' "$_root"
    unset _arch _root _url _tb
}

# Print the value of an option given as "--opt val" or "--opt=val".
_opt_value() {
    _want="$1"; shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            "$_want") shift; [ "$#" -gt 0 ] && { printf '%s\n' "$1"; unset _want; return 0; } ;;
            "$_want"=*) printf '%s\n' "${1#*=}"; unset _want; return 0 ;;
        esac
        shift
    done
    unset _want
    return 1
}

# True when a bare flag token is present in the argument list.
_has_flag() {
    _f="$1"; shift
    for _a in "$@"; do
        [ "$_a" = "$_f" ] && { unset _f _a; return 0; }
    done
    unset _f _a
    return 1
}

# Print the package-cache directory that must be visible inside the environment,
# when it lives OUTSIDE the project directory (otherwise it is already bound).
_env_cache_bind() {
    _carg=$(_opt_value --cache "$@" || true)
    if [ -n "$_carg" ]; then
        _cdir=$(readlink -f "$_carg" 2>/dev/null || printf '%s\n' "$_carg")
    else
        _cdir=$(_cache_resolve "" no)
    fi
    case "$_cdir" in
        ""|"$PWD"|"$PWD"/*) : ;;
        *) [ -d "$_cdir" ] || mkdir -p "$_cdir" 2>/dev/null || true
           printf '%s\n' "$_cdir" ;;
    esac
    unset _carg _cdir
}

# Run the build inside the Void container image, built from container/Containerfile
# on first use.  --privileged is required: mklive chroots and does mount --rbind.
_run_container() {
    _rt="$1"; shift
    if ! "$_rt" image inspect "$BUILD_ENV_IMAGE" >/dev/null 2>&1; then
        echo "==> building Void build-container image: $BUILD_ENV_IMAGE"
        "$_rt" build --network "$BUILD_ENV_NETWORK" -t "$BUILD_ENV_IMAGE" "$PWD/container" \
            || die "failed to build $BUILD_ENV_IMAGE from $PWD/container"
    fi
    # mklive sets up the EFI .img files with losetup.  A container's /dev is a
    # snapshot taken when the container starts, and /dev/loop* only exist once
    # the loop module is loaded on the HOST -- mklive's own `modprobe loop` runs
    # inside the container, too late to appear in that snapshot (losetup then
    # fails with 'device node /dev/loop0 (7:0) is lost').  Load it here so podman
    # exposes the loop devices to the build.
    modprobe -q loop 2>/dev/null || :
    _tty=
    if [ -t 0 ] && [ -t 1 ]; then _tty="-it"; fi
    echo "==> building inside Void container ($_rt) ..."
    # shellcheck disable=SC2086
    "$_rt" run --rm ${_tty} --privileged --network "$BUILD_ENV_NETWORK" \
        -v "$PWD:$PWD" ${_ENV_EXTRA_BINDS_V:-} \
        -w "$PWD" \
        -e VOID_ENV_ACTIVE=yes -e VOID_NO_FLASH=yes \
        "$BUILD_ENV_IMAGE" \
        ./voidlive-build-persist.sh build "$@"
    _rc=$?
    unset _rt _tty
    return "$_rc"
}

# Run the build inside a bootstrapped Void ROOTFS chroot.
_run_chroot() {
    _root=$(_ensure_rootfs)
    _proj=$PWD
    [ -f /etc/resolv.conf ] && cp -f /etc/resolv.conf "$_root/etc/resolv.conf" 2>/dev/null || true
    echo "==> building inside Void ROOTFS chroot ($_root) ..."

    # A plain chroot's / is not a mount point, but mklive builds the EFI loaders
    # via xbps-uchroot, whose `mount --make-rprivate /` needs one (it fails with
    # EINVAL: "Failed to mount / private").  Bind the ROOTFS onto itself so / is
    # a mount point inside the chroot.
    if ! mountpoint -q "$_root"; then
        mount --bind "$_root" "$_root" 2>/dev/null || die "could not bind $_root onto itself"
    fi

    _env_mount_pseudo "$_root"
    mkdir -p "$_root$_proj"
    if ! mountpoint -q "$_root$_proj"; then
        mount --bind "$_proj" "$_root$_proj" 2>/dev/null || die "could not bind $_proj into the ROOTFS"
    fi
    for _b in ${_ENV_EXTRA_BINDS:-}; do
        mkdir -p "$_root$_b"
        if ! mountpoint -q "$_root$_b"; then
            mount --bind "$_b" "$_root$_b" 2>/dev/null || true
        fi
    done

    _rc=0
    # The single-quoted program is a literal sh script executed inside the
    # chroot; $1/$@ must NOT expand here, so SC2016 is intentional.
    # shellcheck disable=SC2016
    chroot "$_root" /bin/sh -c \
        'cd "$1" || exit 1; shift; VOID_ENV_ACTIVE=yes VOID_NO_FLASH=yes; export VOID_ENV_ACTIVE VOID_NO_FLASH; exec ./voidlive-build-persist.sh build "$@"' \
        sh "$_proj" "$@" || _rc=$?

    for _b in ${_ENV_EXTRA_BINDS:-}; do
        umount -R "$_root$_b" 2>/dev/null || umount -l "$_root$_b" 2>/dev/null || true
    done
    umount -R "$_root$_proj" 2>/dev/null || umount -l "$_root$_proj" 2>/dev/null || true
    _env_umount_pseudo "$_root"
    umount "$_root" 2>/dev/null || umount -l "$_root" 2>/dev/null || true
    unset _root _proj _b
    return "$_rc"
}

# Off-Void build wrapper: choose an environment, run the build there, then do a
# requested --flash on the HOST (flash is distribution-neutral).
_build_via_env() {
    [ "$(id -u)" -eq 0 ] || die "the Void build environment must run as root (use sudo)"

    _env_flash=$(_opt_value --flash "$@" || true)
    _env_overlay=$(_opt_value --overlay-size-mib "$@" || true)
    _env_cache=$(_opt_value --cache "$@" || true)
    _env_seed=no
    _has_flag --seed-cache "$@" && _env_seed=yes

    _ENV_EXTRA_BINDS=$(_env_cache_bind "$@")
    _ENV_EXTRA_BINDS_V=
    for _b in ${_ENV_EXTRA_BINDS:-}; do
        case "$_b" in *[[:space:]]*) die "refusing to wrap: path contains whitespace ($_b)";; esac
        _ENV_EXTRA_BINDS_V="$_ENV_EXTRA_BINDS_V -v $_b:$_b"
    done
    case "$PWD" in *[[:space:]]*) die "refusing to wrap: project path contains whitespace ($PWD)";; esac

    case "$BUILD_ENV_MODE" in
        container)
            _rt=$(_container_runtime) || die "--build-env container: no podman or docker in \$PATH"
            _run_container "$_rt" "$@"
            ;;
        chroot)
            _run_chroot "$@"
            ;;
        *)
            _rt=$(_container_runtime || true)
            if [ -n "$_rt" ]; then
                _run_container "$_rt" "$@"
            else
                echo "NOTE: no podman/docker found; using a bootstrapped Void ROOTFS chroot."
                _run_chroot "$@"
            fi
            ;;
    esac
    _rc=$?
    [ "$_rc" -eq 0 ] || exit "$_rc"

    if [ -n "$_env_flash" ]; then
        _dev=$(readlink -f "$_env_flash" 2>/dev/null || printf '%s\n' "$_env_flash")
        OVERLAY_SIZE_MIB="${_env_overlay:-$OVERLAY_SIZE_MIB}"
        SEED_CACHE="$_env_seed"
        CACHE_DIR="${_env_cache:-}"
        if [ -n "$_env_cache" ]; then CACHE_EXPLICIT=yes; else CACHE_EXPLICIT=no; fi
        export OVERLAY_SIZE_MIB SEED_CACHE CACHE_DIR CACHE_EXPLICIT
        echo "==> flashing built image on the host ..."
        flash "$_dev"
    fi
    unset _env_flash _env_overlay _env_cache _env_seed _rt _b _dev _rc _ENV_EXTRA_BINDS
}

build() {
    [ -x ./mkiso.sh ] || die "mkiso.sh not found"

    # --- select the build environment (see the helpers above) ---------------
    BUILD_ENV_MODE="${VOID_BUILD_ENV:-auto}"
    _be_prev=
    for _be_a in "$@"; do
        if [ "$_be_prev" = --build-env ]; then
            BUILD_ENV_MODE="$_be_a"; _be_prev=; continue
        fi
        case "$_be_a" in
            --build-env) _be_prev=--build-env ;;
            --build-env=*) BUILD_ENV_MODE="${_be_a#*=}" ;;
        esac
    done
    unset _be_prev _be_a
    case "$BUILD_ENV_MODE" in
        auto|container|chroot|native) : ;;
        *) die "unknown --build-env mode '$BUILD_ENV_MODE' (use auto|container|chroot|native)" ;;
    esac

    # --- opt-in build watchdog (--watch) -------------------------------------
    # Parsed here (like --build-env) so it is honoured before the env wrap
    # below, i.e. it also covers container/chroot builds.  The main arg loop
    # consumes the flag again purely so it never leaks through to mklive.
    # Stop at `--`: args after it are mklive passthrough, same as the main loop.
    WATCH="${VOID_BUILD_WATCH:-no}"
    for _w_a in "$@"; do
        [ "$_w_a" = -- ] && break
        case "$_w_a" in
            --watch)    WATCH=yes ;;
            --no-watch) WATCH=no ;;
        esac
    done
    unset _w_a
    if [ "$WATCH" = yes ]; then _start_watch; fi
    if [ "${VOID_ENV_ACTIVE:-no}" != yes ]; then
        _be_wrap=yes
        case "$BUILD_ENV_MODE" in
            native) _be_wrap=no ;;
            auto) if _on_void; then _be_wrap=no; fi ;;
        esac
        if [ "$_be_wrap" = yes ]; then
            _build_via_env "$@"
            return $?
        fi
        if ! _on_void; then
            die "no Void XBPS toolchain on this host (missing xbps-uhelper/xbps-install/xbps-reconfigure).
       mklive.sh/lib.sh require it; without it a native build is misdetected as
       foreign-architecture and fails with a bogus 'qemu-x86_64 missing' error.
       Re-run without '--build-env native' to build in a container or Void chroot."
        fi
    fi
    unset _be_wrap

    PERSISTENT_OVERLAY=no
    FLASH_DEV=
    CACHE_DIR=
    SEED_CACHE=no
    BOOTLOADER=
    REFRESH_CACHE=no
    REPLACE_CACHE=no
    DESKTOP=kde
    GREETER=auto

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --persist) PERSISTENT_OVERLAY=yes; shift ;;
            --seed-cache) SEED_CACHE=yes; shift ;;
            --refresh-cache) REFRESH_CACHE=yes; shift ;;
            --replace-cache) REPLACE_CACHE=yes; shift ;;
            --desktop)
                [ "$#" -ge 2 ] || die "--desktop requires a value"
                DESKTOP="$2"
                _is_desktop "$DESKTOP" || die "unknown --desktop '$DESKTOP' (choose from: $DESKTOP_CHOICES)"
                shift 2
                ;;
            --desktop=*)
                DESKTOP="${1#*=}"
                _is_desktop "$DESKTOP" || die "unknown --desktop '$DESKTOP' (choose from: $DESKTOP_CHOICES)"
                shift
                ;;
            --greeter)
                [ "$#" -ge 2 ] || die "--greeter requires a value"
                GREETER="$2"
                _is_greeter "$GREETER" || die "unknown --greeter '$GREETER' (choose from: $GREETER_CHOICES)"
                shift 2
                ;;
            --greeter=*)
                GREETER="${1#*=}"
                _is_greeter "$GREETER" || die "unknown --greeter '$GREETER' (choose from: $GREETER_CHOICES)"
                shift
                ;;
            --cache)
                [ "$#" -ge 2 ] || die "--cache requires a directory"
                CACHE_DIR=$(readlink -f "$2")
                CACHE_EXPLICIT=yes
                shift 2
                ;;
            --cache=*) CACHE_DIR=$(readlink -f "${1#*=}"); CACHE_EXPLICIT=yes; shift ;;
            --flash)
                [ "$#" -ge 2 ] || die "--flash requires a device"
                FLASH_DEV=$(readlink -f "$2")
                shift 2
                ;;
            --flash=*) FLASH_DEV=$(readlink -f "${1#*=}"); shift ;;
            --overlay-size-mib)
                [ "$#" -ge 2 ] || die "--overlay-size-mib requires a value"
                OVERLAY_SIZE_MIB="$2"
                shift 2
                ;;
            --overlay-size-mib=*) OVERLAY_SIZE_MIB="${1#*=}"; shift ;;
            # mkiso/mklive are upstream getopts-only (-B); offer --long aliases
            # here so the persist layer reads uniformly. Prepended below so a
            # genuine user -B later in the line still wins.
            --bootloader)
                [ "$#" -ge 2 ] || die "--bootloader requires a value"
                BOOTLOADER="$2"
                shift 2
                ;;
            --bootloader=*) BOOTLOADER="${1#*=}"; shift ;;
            --grub) BOOTLOADER="grub"; shift ;;
            --limine) BOOTLOADER="limine"; shift ;;
            --both) BOOTLOADER="both"; shift ;;
            # --build-env was already validated/consumed at the top of build();
            # this case only stops it from leaking through to mklive.sh.
            --build-env)
                [ "$#" -ge 2 ] || die "--build-env requires a value"
                BUILD_ENV_MODE="$2"
                shift 2
                ;;
            --build-env=*) BUILD_ENV_MODE="${1#*=}"; shift ;;
            # --watch / --no-watch were already handled by the pre-scan above;
            # swallow them here so they do not reach mklive as positionals.
            --watch|--no-watch) shift ;;
            *) break ;;
        esac
    done
    export PERSISTENT_OVERLAY OVERLAY_SIZE_MIB

    # $DESKTOP       => desktop flavor for mkiso -b (kde by default; see
    #                   --desktop). E.g. kde pulls kde5 + sddm + konsole/dolphin.
    # $GREETER       => display manager / greeter for mkiso -g; 'auto' (default)
    #                   uses the DM void-installer recommends for $DESKTOP.
    # -x postsetup.sh => unlink dormant iptables after install (image uses nftables)
    # -I includes   => copies includes/etc/nftables.conf (hardened firewall) into the image
    # -- s          => mklive arguments after the -- are passed through
    # -c <cachedir> => explicit XBPS cache (mklive option); pinned to THIS folder's
    #                  xbps-cachedir-<arch> so the pre-seeded 2GB cache is reused and
    #                  no package is re-downloaded across rebuilds. A user-supplied
    #                  -c/--cache later on the line always wins (getopts takes the last -c).
    CACHE_DIR=$(_cache_resolve "$CACHE_DIR" "${CACHE_EXPLICIT:-no}")
    if [ ! -d "$CACHE_DIR" ]; then
        echo "NOTE: XBPS cache dir '$CACHE_DIR' does not exist yet; it will be created" >&2
    elif [ ! -w "$CACHE_DIR" ]; then
        die "XBPS cache dir '$CACHE_DIR' is not writable; download reuse would fail"
    fi
    _cache_maintain "$CACHE_DIR"
    _CACHE_MAINTAINED=yes

    # MKLIVE_EXTRA: if --bootloader was set, translate to -B for mkiso/mklive;
    # place it BEFORE "$@" so any user-provided -B still wins.
    MKLIVE_EXTRA=
    [ -z "$BOOTLOADER" ] || MKLIVE_EXTRA="-B $BOOTLOADER"

    # GREETER_ARGS: omit -g entirely for the default (auto) so mkiso keeps its
    # own per-desktop recommended DM.
    GREETER_ARGS=
    [ "$GREETER" = auto ] || GREETER_ARGS="-g $GREETER"

    if [ -n "$FLASH_DEV" ] && [ "${VOID_NO_FLASH:-no}" != yes ]; then
        echo "==> building image ($DESKTOP${GREETER:+, greeter $GREETER}) ..."
        if ./mkiso.sh -b "$DESKTOP" $GREETER_ARGS -- -x "$PWD/postsetup.sh" -I "$PWD/includes" -c "$CACHE_DIR" $MKLIVE_EXTRA "$@"; then
            :
        else
            die "build failed; not flashing $FLASH_DEV"
        fi
        ISO=$(ls -1t ./void-live-*.iso 2>/dev/null | head -n1)
        [ -n "$ISO" ] || die "build finished but no void-live-*.iso found in \$PWD"
        echo "==> flashing built image: $ISO"
        flash "$FLASH_DEV" "$ISO"
    else
        exec ./mkiso.sh -b "$DESKTOP" $GREETER_ARGS -- -x "$PWD/postsetup.sh" -I "$PWD/includes" -c "$CACHE_DIR" $MKLIVE_EXTRA "$@"
    fi
}

flash() {
    [ "$#" -ge 1 ] || die "flash requires a device, e.g. $0 flash /dev/sdb"

    DEV=$(readlink -f "$1")
    shift

    # Preserve already-set values when called from build() (--seed-cache /
    # --cache propagate through the shell scope); standalone flash defaults off.
    SEED_CACHE=${SEED_CACHE:-no}
    CACHE_DIR=${CACHE_DIR:-}
    CACHE_EXPLICIT=${CACHE_EXPLICIT:-no}
    REFRESH_CACHE=${REFRESH_CACHE:-no}
    REPLACE_CACHE=${REPLACE_CACHE:-no}

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --seed-cache) SEED_CACHE=yes; shift ;;
            --refresh-cache) REFRESH_CACHE=yes; shift ;;
            --replace-cache) REPLACE_CACHE=yes; shift ;;
            --cache)
                [ "$#" -ge 2 ] || die "--cache requires a directory"
                CACHE_DIR=$(readlink -f "$2")
                CACHE_EXPLICIT=yes
                shift 2
                ;;
            --cache=*) CACHE_DIR=$(readlink -f "${1#*=}"); CACHE_EXPLICIT=yes; shift ;;
            --overlay-size-mib)
                [ "$#" -ge 2 ] || die "--overlay-size-mib requires a value"
                OVERLAY_SIZE_MIB="$2"
                shift 2
                ;;
            --overlay-size-mib=*)
                OVERLAY_SIZE_MIB="${1#*=}"
                shift
                ;;
            *)
                ISO=$(readlink -f "$1")
                shift
                ;;
        esac
    done

    : "${ISO:=$(ls -1t ./void-live-*.iso 2>/dev/null | head -n1)}"
    [ -n "$ISO" ] || die "no live ISO found; pass one explicitly"
    [ -f "$ISO" ] || die "live ISO not found: $ISO"
    [ -b "$DEV" ] || die "not a block device: $DEV"
    [ "$(id -u)" -eq 0 ] || die "must run as root"

    need_cmd dd
    need_cmd sfdisk
    need_cmd mkfs.ext4
    need_cmd partprobe
    need_cmd blockdev
    need_cmd lsblk
    need_cmd blkid

    if [ -n "$(lsblk -nro MOUNTPOINT "$DEV" 2>/dev/null | grep -v '^$')" ]; then
        die "$DEV or one of its partitions is mounted; unmount it first"
    fi

    printf 'WARNING: %s and ALL its partitions will be erased.\n' "$DEV"
    printf 'Type the device path again to confirm: '
    read -r answer
    [ "$answer" = "$DEV" ] || die "aborted"

    iso_bytes=$(stat -c%s "$ISO")
    iso_mib=$(( (iso_bytes + 1048575) / 1048576 ))
    dev_mib=$(( $(blockdev --getsize64 "$DEV") / 1048576 ))

    [ "$dev_mib" -ge "$OVERLAY_SIZE_MIB" ] || die \
        "overlay too big: requested ${OVERLAY_SIZE_MIB}MiB but device $DEV is only ${dev_mib}MiB"
    [ "$dev_mib" -ge "$iso_mib" ] || die \
        "device too small: ISO is ${iso_mib}MiB but device $DEV is only ${dev_mib}MiB"
    [ "$(( dev_mib - iso_mib ))" -ge "$OVERLAY_SIZE_MIB" ] || die \
        "device too small: ISO (${iso_mib}MiB) + overlay (${OVERLAY_SIZE_MIB}MiB) does not fit, device is only ${dev_mib}MiB"

    # Partitions are named differently for nvme/mmc devices.
    partdev() {
        case "$DEV" in
            *[0-9]) echo "${DEV}p$1" ;;
            *)      echo "${DEV}$1" ;;
        esac
    }

    # Release every mount currently held on $1 (a whole disk or one partition).
    # A live desktop session's automounter (udisks2) grabs removable media the
    # moment udev announces it, so the target can become "in use" again between
    # our own unmount and the next write; loop briefly and lazily detach.
    _release_mounts() {
        local _target="$1" _m _n=0
        while [ -n "$(lsblk -nro MOUNTPOINT "$_target" 2>/dev/null | grep -v '^$')" ]; do
            for _m in $(lsblk -nro MOUNTPOINT "$_target" 2>/dev/null | grep -v '^$'); do
                umount "$_m" 2>/dev/null || umount -l "$_m" 2>/dev/null || true
            done
            udevadm settle >/dev/null 2>&1 || sleep 1
            _n=$(( _n + 1 ))
            if [ "$_n" -ge 5 ]; then break; fi
        done
        return 0
    }

    printf 'Writing %s to %s ...\n' "$ISO" "$DEV"
    dd if="$ISO" of="$DEV" bs=4M status=progress conv=fsync
    sync

    # The automounter re-grabs the ISO partition while dd writes, so release it
    # again before we touch the table (sfdisk's in-use check and the later mkfs
    # would otherwise fail).  --no-reread on the append below covers the race
    # where udisks wins again in the moment before sfdisk writes.
    _release_mounts "$DEV"

    # dd does not make the kernel re-read the partition table, and the kernel
    # can keep a STALE view of a PREVIOUS flash (a lingering overlay node once
    # made the old logic believe a fresh 3-entry ISO table had 4 primaries and
    # the whole flash die here).  Force a real resync before trusting any
    # partition numbering.  This can legitimately fail with EBUSY while a
    # desktop session's automounter holds the ISO partition open; the slot
    # numbering below then falls back to the authoritative on-disk table, so a
    # failed resync is not fatal by itself.
    udevadm settle >/dev/null 2>&1 || true
    blockdev --rereadpt "$DEV" 2>/dev/null \
        || partprobe "$DEV" >/dev/null 2>&1 \
        || partx -u "$DEV" >/dev/null 2>&1 || true
    udevadm settle >/dev/null 2>&1 || true

    # The on-disk table is authoritative for slot numbering: count its entries
    # directly from sfdisk rather than from lsblk, which reflects the kernel's
    # (possibly stale or only partially resynced) view.
    table_count=$(sfdisk -d "$DEV" 2>/dev/null | awk '/^\/dev\//{n++} END{print n+0}')

    # Preflight the freshly written table. The project's hybrid ISOs carry an
    # Apple Partition Map (-isohybrid-apm-hfsplus) that makes parted report the
    # disk as "Partition Table: unknown" and fail every mkpart -- which is why
    # the old parted-based flash never created VOID_OVL. sfdisk reads the DOS
    # label fine, so require it and fail loudly rather than half-repartition a
    # disk whose table we cannot parse.
    sfdisk -d "$DEV" >/dev/null 2>&1 || die \
        "cannot read the partition table on $DEV with sfdisk; refusing to repartition (sfdisk is required for the isohybrid/APM tables this project builds)"
    table_label=$(sfdisk -d "$DEV" 2>/dev/null | awk '/^label:/{print $2; exit}')
    case "$table_label" in
        dos|gpt) : ;;
        *) die "unsupported partition table on $DEV (label: ${table_label:-none}); expected the MBR/DOS isohybrid layout this project creates" ;;
    esac

    # The live volume (the ISO9660 filesystem of the hybrid image) carries the
    # label/UUID dracut uses to name the overlay directories inside the
    # persistence partition; read them from the just-written media. Prefer the
    # ISO9660 *partition* when the kernel exposes one, but fall back to the whole
    # device: xorriso's -isohybrid-mbr stamps partition 1 with system-id 0x00,
    # which the Linux partition parser deliberately skips, so no /dev/<dev>1 node
    # exists and blkid reports the filesystem directly on $DEV. Either way blkid
    # returns the same LABEL/UUID, so dracut's overlay-<label>-<uuid> name (and
    # thus the directory this function initializes) is unchanged.
    LIVE_PART=$(lsblk -nro NAME,FSTYPE,TYPE "$DEV" 2>/dev/null \
        | awk '$3 == "part" && $2 == "iso9660" { print "/dev/" $1; exit }')
    [ -n "$LIVE_PART" ] || LIVE_PART=$(partdev 1)
    [ -b "$LIVE_PART" ] || LIVE_PART=$DEV
    LIVE_LABEL=$(blkid -s LABEL -o value "$LIVE_PART" 2>/dev/null || true)
    LIVE_UUID=$(blkid -s UUID -o value "$LIVE_PART" 2>/dev/null || true)

    # The ISO's own partition table already has entries (1=ISO9660 and the EFI
    # images: 2=grub_uefi, 3=limine_uefi for -B both, GRUB first). The new
    # overlay is APPENDED after them, so its slot is table_count+1, not a
    # hardcoded 3 (hardcoding 3 used to clobber the limine EFI partition on
    # -B both images). An MBR table holds at most 4 primaries; the hybrid ISOs
    # this project builds use exactly 3, leaving slot 4 for the overlay.  If a
    # future ISO filled all 4, the overlay would have to live on the GPT side
    # of the hybrid disk instead -- fail loudly rather than try a 5th primary.
    # NB: never derive the slot from lsblk/kernel state; a stale node from a
    # previous flash would make the MBR look fuller than it really is.
    devname=$(basename "$DEV")
    [ "$table_count" -le 3 ] || die \
        "cannot add persistence partition: $DEV already has $table_count MBR primary partitions; on a 4-primary hybrid the overlay would need a GPT partition (not supported yet)"
    next_part=$(( table_count + 1 ))

    printf 'Creating persistence partition (slot %s, %sMiB, label %s) ...\n' "$next_part" "$OVERLAY_SIZE_MIB" "$OVERLAY_LABEL"
    persist_start_sec=$(( (iso_mib + 2) * 2048 ))
    persist_size_sec=$(( OVERLAY_SIZE_MIB * 2048 ))
    # Do NOT use parted here: xorriso's Apple Partition Map
    # (-isohybrid-apm-hfsplus) makes parted report "Partition Table: unknown"
    # and mkpart fails. sfdisk reads the DOS label, appends the new primary and
    # preserves the isohybrid boot code / existing entries.  --no-reread skips
    # sfdisk's "is the device in use" ioctl test: the automounter legitimately
    # holds the ISO partition and can win the race again, and we refresh the
    # kernel's view ourselves below (partprobe/partx -a + geometry lookup), so
    # we neither need nor want sfdisk's re-read.
    if ! printf 'start=%s, size=%s, type=83\n' "$persist_start_sec" "$persist_size_sec" \
        | sfdisk --no-reread --append "$DEV"; then
        die "failed to add the persistence partition to $DEV"
    fi

    # Wait for the kernel to expose the new node, choosing it by GEOMETRY (the
    # start sector we just appended) rather than an assumed number: the kernel
    # can lag the table or hold a stale node from a previous flash, and a stale
    # node with the wrong start must never be formatted.  The automounter keeps
    # the ISO partition mounted, which makes a full re-read fail EBUSY, so each
    # round first releases mounts on the device, then tries a full re-read and
    # falls back to adding the single partition.  Note the `|| true` guards:
    # this script runs under `set -eu`, and a command substitution that exits
    # non-zero (a not-yet-visible node) would otherwise abort the whole flash.
    _find_part_by_start() {
        local want="$1" d start node
        for d in /sys/block/"$devname"/"${devname}"[0-9]*/start \
                 /sys/block/"$devname"/"${devname}"p[0-9]*/start; do
            [ -e "$d" ] || continue
            start=$(cat "$d" 2>/dev/null) || continue
            if [ "$start" = "$want" ]; then
                node=${d%/start}
                echo "/dev/${node##*/}"
                return 0
            fi
        done
        return 1
    }

    PART=""
    for i in 1 2 3 4 5; do
        PART=$(_find_part_by_start "$persist_start_sec" || true)
        if [ -n "$PART" ]; then break; fi
        _release_mounts "$DEV"
        blockdev --rereadpt "$DEV" 2>/dev/null || true
        partx -a "$DEV" >/dev/null 2>&1 || true
        sleep 1
    done
    [ -n "$PART" ] || PART=$(partdev "$next_part")
    [ -b "$PART" ] || die "persistence partition $PART did not appear after appending to $DEV"

    # Geometry guard: never mkfs a node that does not start exactly where we
    # appended. A stale node from a previous flash would silently clobber data.
    _start=$(cat "/sys/block/$devname/${PART##*/}/start" 2>/dev/null || echo mismatch)
    [ "$_start" = "$persist_start_sec" ] || die \
        "partition node $PART starts at sector ${_start:-?}, expected $persist_start_sec; refusing to format (stale or mismatched kernel table view)"
    unset _start

    # An automounter (udisks2 on a live desktop session) can grab the freshly
    # created partition the moment udev announces it, so the very next mkfs.ext4
    # aborts with "is mounted; will not make a filesystem here!" and the flash
    # dies AFTER the dd + repartition already ran. Release any automount targets
    # of the new partition first; the overlay wiring below remounts it on
    # purpose.
    _release_mounts "$PART"

    printf 'Formatting %s ...\n' "$PART"
    mkfs.ext4 -q -L "$OVERLAY_LABEL" "$PART"
    sync

    # dracut's dmsquash-live only uses the labeled partition as a persistent
    # overlay if it already contains the upper/work layout it expects:
    #   LiveOS/overlay-<live-label>-<live-uuid>/   (upperdir)
    #   LiveOS/ovlwork/                            (workdir)
    # A bare mkfs is NOT enough: without these directories dracut prints
    # "Unable to find a persistent overlay; using a temporary one" and runs
    # from a RAM overlay. The overlay-<label>-<uuid> name matches the
    # "overlay-$l-$u" path dmsquash-live computes from the live volume.
    if [ -n "$LIVE_LABEL" ] && [ -n "$LIVE_UUID" ]; then
        _mnt=$(mktemp -d /tmp/void-ovl-init.XXXXXX)
        mount "$PART" "$_mnt"
        mkdir -p "$_mnt/LiveOS/ovlwork"
        mkdir -p "$_mnt/LiveOS/overlay-${LIVE_LABEL}-${LIVE_UUID}"
        sync
        umount "$_mnt"
        rmdir "$_mnt"
        unset _mnt
    else
        echo "WARNING: could not read the live volume label/UUID from $LIVE_PART;" >&2
        echo "         dracut may not detect the overlay. Is this a Void live ISO?" >&2
    fi

    # --seed-cache: copy the raw XBPS package cache into the fresh VOID_OVL
    # partition so a later Void_Linux_Installer run on this stick can reuse the
    # packages from disk instead of re-fetching them from the mirror. The cache
    # and tool are placed BOTH at the partition root (reached via /run/media
    # when udisks mounts the stick, and always at /run/initramfs/overlayfs when
    # dracut holds it) AND inside the dmsquash-live overlay upperdir
    # LiveOS/overlay-<label>-<uuid>/ — which IS / on a persistent boot, so they
    # show up as /xbps-cachedir-<arch> and /xbps-cache-tool.sh there. Cache dir
    # resolution mirrors build(): explicit --cache wins, else the default
    # ./xbps-cachedir-<arch> in THIS folder, else an auto-detected populated
    # cache under /run/media. A missing/unreadable cache is a WARN + skip, never
    # a hard failure.
    if [ "$SEED_CACHE" = "yes" ]; then
        CACHE_DIR=$(_cache_resolve "$CACHE_DIR" "$CACHE_EXPLICIT")
        if [ "${_CACHE_MAINTAINED:-no}" != "yes" ]; then
            _cache_maintain "$CACHE_DIR"
        fi
        if [ -d "$CACHE_DIR" ] && [ -r "$CACHE_DIR" ]; then
            _mnt=$(mktemp -d /tmp/void-ovl-seed.XXXXXX)
            echo "Seeding package cache into $PART ..."
            mount "$PART" "$_mnt"
            _deposit_cache_tool "$_mnt"
            cp -a "$CACHE_DIR" "$_mnt/"
            # Also seed the overlay upperdir so the cache/tool become visible at
            # / on a persistent boot. dmsquash-live uses
            # LiveOS/overlay-<live-label>-<live-uuid> as the overlay upperdir
            # (created earlier in this function); fall back gracefully when it
            # is absent (persistence never initialized).
            _ovl_upper=
            if [ -n "$LIVE_LABEL" ] && [ -n "$LIVE_UUID" ]; then
                _ovl_upper="$_mnt/LiveOS/overlay-${LIVE_LABEL}-${LIVE_UUID}"
            fi
            if [ -n "$_ovl_upper" ] && [ -d "$_ovl_upper" ]; then
                echo "Seeding package cache into overlay upperdir (visible as / on a persistent boot) ..."
                _deposit_cache_tool "$_ovl_upper"
                cp -a "$CACHE_DIR" "$_ovl_upper/"
            else
                echo "NOTE: overlay upperdir not found; seeded the partition root only." >&2
            fi
            unset _ovl_upper
            sync
            umount "$_mnt"
            rmdir "$_mnt"
            unset _mnt
            echo "Package cache seeded: $CACHE_DIR"
        else
            echo "NOTE: --seed-cache requested but no usable cache at $CACHE_DIR; skipping." >&2
        fi
    fi

    echo
    echo "Done. Persistent live USB ready:"
    echo "  device:       $DEV"
    echo "  live system:  $ISO"
    echo "  persistence:  $PART (ext4, label $OVERLAY_LABEL, ${OVERLAY_SIZE_MIB}MiB)"
    if [ -n "$LIVE_LABEL" ] && [ -n "$LIVE_UUID" ]; then
        echo "  overlay upper: LiveOS/overlay-${LIVE_LABEL}-${LIVE_UUID}"
        echo "  overlay work:  LiveOS/ovlwork"
    fi
    if [ "$SEED_CACHE" = "yes" ] && [ -d "$CACHE_DIR" ]; then
        echo "  seeded cache: $CACHE_DIR (reusable by the installer)"
        echo "  cache updater: /xbps-cache-tool.sh on the booted stick (update/replace/download)"
    fi
    echo
    echo "Changes made while running the live system (installed packages, config,"
    echo "files) are saved to $PART and survive reboots."
    echo "Note: persistence activates only if the ISO was built with 'build --persist';"
    echo "otherwise the boot cmdline lacks rd.overlay=LABEL=VOID_OVL and $PART is unused."
    echo "Boot the stick, pick the default entry, install opencode or anything else,"
    echo "reboot, and the changes are still there."
}

CMD="${1:-build}"
case "$CMD" in
    build)          shift; build "$@" ;;
    flash)          shift; flash "$@" ;;
    -h|--help|help) usage; exit 0 ;;
    -*)             build "$@";;      # old-style bare mklive args still build
    *)              usage >&2; exit 1 ;;
esac