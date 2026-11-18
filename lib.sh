#!/bin/sh

# ensure consistent styling, sorting, etc
export LANG=C.UTF-8
export LC_ALL=C

# This contains the COMPLETE list of binaries that this script needs
# to function.  The only exception is the QEMU binary since it is not
# known in advance which one wil be required.
readonly LIBTOOLS="cp echo cat printf which mountpoint mount umount modprobe"
readonly HOSTARCH=$(xbps-uhelper arch)

is_target_native() {
    # Because checking whether the target is runnable is ugly, stuff
    # it into a single function. That makes it easy to check anywhere.
    local target_arch

    target_arch="$1"
    # this will cover most
    if [ "${target_arch%-musl}" = "${HOSTARCH%-musl}" ]; then
        return 0
    fi

    case "$HOSTARCH" in
        # ppc64le has no 32-bit variant, only runs its own stuff
        ppc64le*) return 1 ;;
        # x86_64 also runs i686
        x86_64*) test -z "${target_arch##*86*}" ;;
        # aarch64 also runs armv*
        aarch64*) test -z "${target_arch##armv*}" ;;
        # bigendian ppc64 also runs ppc
        ppc64*) test "${target_arch%-musl}" = "ppc" ;;
        # anything else is just their own
        *) return 1 ;;
    esac

    return $?
}

version() (
    set +u
    [ -n "$PROGNAME" ] && printf "%s " "$PROGNAME"
    echo "$(cat ./version) ${MKLIVE_REV:-"$(git -c safe.directory="$(pwd)" rev-parse --short HEAD 2> /dev/null)"}"
)

info_msg() {
    # This function handles the printing that is bold within all
    # scripts.  This is a convenience function so that the rather ugly
    # looking ASCII escape codes live in only one place.
    printf "\033[1m%s\n\033[m" "$@"
}

die() {
    # This function is registered in all the scripts to make sure that
    # the important mounts get cleaned up and the $ROOTFS location is
    # removed.
    printf "FATAL: %s\n" "$@"
    umount_pseudofs
    [ -d "$ROOTFS" ] && rm -rf "$ROOTFS"
    exit 1
}

check_tools() {
    # All scripts within mklive declare the tools they will use in a
    # variable called "REQTOOLS".  This function checks that these
    # tools are available and prints out the path to each tool that
    # will be used.  This can be useful to figure out what is broken
    # if a different version of something is used than was expected.
    for tool in $LIBTOOLS $REQTOOLS ; do
        if ! which "$tool" > /dev/null ; then
            die "Required tool $tool is not available on this system!"
        fi
    done

    info_msg "The following tools will be used:"
    for tool in $LIBTOOLS $REQTOOLS ; do
        which "$tool"
    done
}

mount_pseudofs() {
    # This function ensures that the psuedofs mountpoints are present
    # in the chroot.  Strictly they are not necessary to have for many
    # commands, but bind-mounts are cheap and it isn't too bad to just
    # mount them all the time.
    for f in dev proc sys; do
        # In a naked chroot there is nothing to bind the mounts to, so
        # we need to create directories for these first.
        [ ! -d "$ROOTFS/$f" ] && mkdir -p "$ROOTFS/$f"
        if ! mountpoint -q "$ROOTFS/$f" ; then
            # It is VERY important that this only happen if the
            # pseudofs isn't already mounted.  If it already is then
            # this is virtually impossible to troubleshoot because it
            # looks like the subsequent umount just isn't working.
            mount -r --rbind /$f "$ROOTFS/$f" --make-rslave
        fi
    done
    if ! mountpoint -q "$ROOTFS/tmp" ; then
        mkdir -p "$ROOTFS/tmp"
        mount -o mode=0755,nosuid,nodev -t tmpfs tmpfs "$ROOTFS/tmp"
    fi
}

umount_pseudofs() {
    # This function cleans up the mounts in the chroot.  Failure to
    # clean up these mounts will prevent the tmpdir from being
    # deletable instead throwing the error "Device or Resource Busy".
    # The '-f' option is passed to umount to account for the
    # contingency where the psuedofs mounts are not present.
    if [ -d "${ROOTFS}" ]; then
        for f in dev proc sys; do
            umount -R -f "$ROOTFS/$f" >/dev/null 2>&1
        done
    fi
    umount -f "$ROOTFS/tmp" >/dev/null 2>&1
}

run_cmd_target() {
    info_msg "Running $* for target $XBPS_TARGET_ARCH ..."
    if is_target_native "$XBPS_TARGET_ARCH"; then
        # This is being run on the same architecture as the host,
        # therefore we should set XBPS_ARCH.
        if ! eval XBPS_ARCH="$XBPS_TARGET_ARCH" "$@" ; then
            die "Could not run command $*"
        fi
    else
        # This is being run on a foriegn arch, therefore we should set
        # XBPS_TARGET_ARCH.  In this case XBPS will not attempt
        # certain actions and will require reconfiguration later.
        if ! eval XBPS_TARGET_ARCH="$XBPS_TARGET_ARCH" "$@" ; then
            die "Could not run command $*"
        fi
    fi
}

run_cmd() {
    # This is a general purpose function to run commands that a user
    # may wish to see.  For example its useful to see the tar/xz
    # pipeline to not need to delve into the scripts to see what
    # options its set up with.
    info_msg "Running $*"
    eval "$@"
}

run_cmd_chroot() {
    # General purpose chroot function which makes sure the chroot is
    # prepared.  This function takes 2 arguments, the location to
    # chroot to and the command to run.

    # This is an idempotent function, it is safe to call every time
    # before entering the chroot.  This has the advantage of making
    # execution in the chroot appear as though it "Just Works(tm)".
    register_binfmt

    # Before we step into the chroot we need to make sure the
    # pseudo-filesystems are ready to go.  Not all commands will need
    # this, but its still a good idea to call it here anyway.
    mount_pseudofs

    # With assurance that things will run now we can jump into the
    # chroot and run stuff!
    chroot "$1" sh -c "$2"
}

cleanup_chroot() {
    # This function cleans up the chroot shims that are used by QEMU
    # to allow builds on alien platforms.  It takes no arguments but
    # expects the global $ROOTFS variable to be set.

    # Un-Mount the pseudofs mounts if they were mounted
    umount_pseudofs
}

register_binfmt() {
    # This function sets up everything that is needed to be able to
    # chroot into a ROOTFS and be able to run commands there.  This
    # really matters on platforms where the host architecture is
    # different from the target, and you wouldn't be able to run
    # things like xbps-reconfigure -a.  This function is idempotent
    # (You can run it multiple times without modifying state).  This
    # function takes no arguments, but does expect the global variable
    # $XBPS_TARGET_ARCH to be set.

    # This select sets up the "magic" bytes in /proc that let the
    # kernel select an alternate interpreter.  More values for this
    # map can be obtained from here:
    # https://github.com/qemu/qemu/blob/master/scripts/qemu-binfmt-conf.sh

    # If the XBPS_TARGET_ARCH is unset but the PLATFORM is known, it
    # may be possible to set the architecture from the static
    # platforms map.
    if [ -z "$XBPS_TARGET_ARCH" ] && [ ! -z "$PLATFORM" ] ; then
        set_target_arch_from_platform
    fi

    # In the special case where the build is native we can return
    # without doing anything else
    # This is only a basic check for identical archs, with more careful
    # checks below for cases like ppc64 -> ppc and x86_64 -> i686.
    _hostarch="${HOSTARCH%-musl}"
    _targetarch="${XBPS_TARGET_ARCH%-musl}"
    if [ "$_hostarch" = "$_targetarch" ] ; then
        return
    fi

    case "${_targetarch}" in
        armv*)
            # TODO: detect aarch64 hosts that run 32 bit ARM without qemu (some cannot)
            if ( [ "${_targetarch}" = "armv6l" ] && [ "${_hostarch}" = "armv7l" ] ) ; then
                return
            fi
            if [ "${_targetarch}" = "armv5tel" -a \
                \( "${_hostarch}" = "armv6l" -o "${_hostarch}" = "armv7l" \) ] ; then
                return
            fi
            _cpu=arm
            ;;
        aarch64)
            _cpu=aarch64
            ;;
        ppc64le)
            _cpu=ppc64le
            ;;
        ppc64)
            _cpu=ppc64
            ;;
        ppc)
            if [ "$_hostarch" = "ppc64" ] ; then
                return
            fi
            _cpu=ppc
            ;;
        mipsel)
            if [ "$_hostarch" = "mips64el" ] ; then
                return
            fi
            _cpu=mipsel
            ;;
        x86_64)
            _cpu=x86_64
            ;;
        i686)
            if [ "$_hostarch" = "x86_64" ] ; then
                return
            fi
            _cpu=i386
            ;;
        riscv64)
            _cpu=riscv64
            ;;
        *)
            die "Unknown target architecture!"
            ;;
    esac

    # For builds that do not match the host architecture, the correct
    # qemu binary will be required.
    QEMU_BIN="qemu-${_cpu}"
    if ! $QEMU_BIN -version >/dev/null 2>&1; then
        die "$QEMU_BIN binary is missing in your system, exiting."
    fi

    # In order to use the binfmt system the binfmt_misc mountpoint
    # must exist inside of proc
    if ! mountpoint -q /proc/sys/fs/binfmt_misc ; then
        modprobe -q binfmt_misc
        mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null
    fi

    # Only register if the map is incomplete
    if [ ! -f /proc/sys/fs/binfmt_misc/qemu-$_cpu ] ; then
        if ! command -v update-binfmts >/dev/null 2>&1; then
            die "could not add binfmt: update-binfmts binary is missing in your system"
        fi
        update-binfmts --import "qemu-$_cpu"
    fi
}

set_target_arch_from_platform() {
    # This function maintains a lookup from platform to target
    # architecture.  This is required for scripts that need to know
    # the target architecture, but don't necessarily need to know it
    # internally (i.e. only run_cmd_chroot).
    case "$PLATFORM" in
        rpi-aarch64*) XBPS_TARGET_ARCH="aarch64";;
        rpi-armv7l*) XBPS_TARGET_ARCH="armv7l";;
        rpi-armv6l*) XBPS_TARGET_ARCH="armv6l";;
        i686*) XBPS_TARGET_ARCH="i686";;
        x86_64*) XBPS_TARGET_ARCH="x86_64";;
        GCP*) XBPS_TARGET_ARCH="x86_64";;
        pinebookpro*) XBPS_TARGET_ARCH="aarch64";;
        pinephone*) XBPS_TARGET_ARCH="aarch64";;
        rock64*) XBPS_TARGET_ARCH="aarch64";;
        rockpro64*) XBPS_TARGET_ARCH="aarch64";;
        asahi*) XBPS_TARGET_ARCH="aarch64";;
        *) die "$PROGNAME: Unable to compute target architecture from platform";;
    esac

    if [ -z "${PLATFORM##*-musl}" ] ; then
        XBPS_TARGET_ARCH="${XBPS_TARGET_ARCH}-musl"
    fi
}

set_dracut_args_from_platform() {
    # In rare cases it is necessary to set platform specific dracut
    # args.  This is mostly the case on ARM platforms.
    case "$PLATFORM" in
        *) ;;
    esac
}

set_cachedir() {
    # The package artifacts are cacheable, but they need to be isolated
    # from the host cache.
    : "${XBPS_CACHEDIR:=--cachedir=$PWD/xbps-cache/${XBPS_TARGET_ARCH}}"
}

# ---------------------------------------------------------------------------
# Void_Linux_Installer: fetched from GitHub at build time.
#
# The live image (mkiso.sh) and the netboot image (mknet.sh) SHIP the
# Void_Linux_Installer as /usr/bin/void-installer.  It is deliberately NOT
# vendored in this tree: it is downloaded from the public repo at build time so
# that every build carries the CURRENT installer from `main`, with no pinned
# copy to lag behind.  This is the same default the on-stick updater uses
# (installer-update-tool.sh: `REF="${INSTALLER_REF:-main}"`), so a freshly built
# ISO and a stick refreshed by that tool resolve the same ref.
#
# `main` is a moving target — an unpinned build is intentionally NOT
# reproducible.  For a reproducible build, pin a tag or commit explicitly:
#
#     INSTALLER_REF=Version-3.2.06 ./mkiso.sh -b base
#
# IMPORTANT: a tag NAME is not version identity.  The tag `Version-3.3.00`,
# for example, ships a script that self-reports `Version-3.2.07` (its release
# export was cut from 3.2.07-era source).  Always trust the resolved
# `SCRIPT_VERSION` + sha256 below, never the ref name.
#
# The resolved version and SHA-256 are printed at build time and recorded on
# the live image (mkiso.sh include_installer → /etc/void-linux-live/installer-ref),
# so the installer a given ISO shipped can always be identified after the fact.
#
# HISTORY — why this seam used to carry a pin (do not re-introduce by reflex):
# from Version-3.1.00 through Version-3.2.06 INSTALLER_REF defaulted to a
# release tag, each bump forced by a concrete install-time defect:
#   * 3.2.01 — Discover store + its repo-order fix (3.2.00 installed the stock
#     discover, 3.1.00 no store at all);
#   * 3.2.02 — GNOME Software store (3.2.01 provisioned nothing for GNOME);
#   * 3.2.03 — elogind/GDM boot race (logind seat0 race on first boot);
#   * 3.2.04 — [PKG-SNAP-LONGOPT] GUI-update snapper pair;
#   * 3.2.06 — [SDDM-WAIT-LOGIND] boot safety: below it a KDE install boots to
#     a text login because the stock sddm run script dies at its dbus-send.
# The operator later chose to track `main` unconditionally ("always pull the
# current script"), so those boot-safety arguments now apply to keeping `main`
# current, not to a frozen tag.  Keep the default at `main` unless told
# otherwise; pinning stays available as an explicit build-time override.
INSTALLER_REPO="${INSTALLER_REPO:-bluesloth/void-linux-installer}"
INSTALLER_REF="${INSTALLER_REF:-main}"
INSTALLER_BASENAME="${INSTALLER_BASENAME:-Void_Linux_Installer.sh}"
INSTALLER_URL_BASE="${INSTALLER_URL_BASE:-https://raw.githubusercontent.com}"

installer_url() {
    printf '%s/%s/%s/%s\n' \
        "$INSTALLER_URL_BASE" "$INSTALLER_REPO" "$INSTALLER_REF" "$INSTALLER_BASENAME"
}

installer_fetch() {
    # installer_fetch <dest>
    #   Download the installer to <dest> (mode 0755), sanity-check it, and set
    #   INSTALLER_VERSION + INSTALLER_SHA256.  The build aborts on any failure —
    #   there is deliberately no bundled fallback to fall back to.
    _if_dest="$1"
    _if_url="$(installer_url)"

    if ! command -v curl >/dev/null 2>&1; then
        printf 'FATAL: curl is required to fetch the Void_Linux_Installer (%s).\n' "$_if_url" >&2
        exit 1
    fi
    # Retry transient failures: build hosts behind a flaky or USB-tethered
    # uplink stall mid-transfer, and a single-shot curl would abort the whole
    # build.  --retry covers timeouts, connection resets and 5xx;
    # --retry-all-errors (curl >= 7.71) additionally retries truncated
    # transfers (e.g. "transfer closed with N bytes remaining").  Probed
    # rather than assumed so an older curl still runs.
    _if_retry="--retry 5 --retry-delay 3 --retry-connrefused"
    if curl --retry-all-errors --version >/dev/null 2>&1; then
        _if_retry="$_if_retry --retry-all-errors"
    fi
    # shellcheck disable=SC2086  # $_if_retry is a deliberate option word-split
    if ! curl -fsSL --max-time 60 $_if_retry -o "$_if_dest" "$_if_url"; then
        printf 'FATAL: could not fetch the Void_Linux_Installer from %s (after retries).\n' "$_if_url" >&2
        printf "       Check network access. The default ref is 'main'; set INSTALLER_REF=<tag|commit> to pin a reproducible build.\n" >&2
        exit 1
    fi
    if command -v bash >/dev/null 2>&1; then
        if ! bash -n "$_if_dest" 2>/dev/null; then
            printf 'FATAL: the fetched Void_Linux_Installer failed a syntax check (%s).\n' "$_if_url" >&2
            exit 1
        fi
    fi
    chmod 0755 "$_if_dest"

    INSTALLER_VERSION="$(sed -n 's/^SCRIPT_VERSION="\(.*\)"$/\1/p' "$_if_dest" | head -n1)"
    INSTALLER_SHA256="$(sha256sum "$_if_dest" | awk '{print $1}')"
    if [ -z "$INSTALLER_VERSION" ]; then
        printf 'FATAL: could not read SCRIPT_VERSION from the fetched installer (%s).\n' "$_if_url" >&2
        exit 1
    fi

    info_msg "Void_Linux_Installer ${INSTALLER_VERSION} (${INSTALLER_REPO}@${INSTALLER_REF})"
    info_msg "  sha256 ${INSTALLER_SHA256}"
    info_msg "  ${_if_url}"
}

rk33xx_flash_uboot() {
    local dir="$1"
    local dev="$2"
    dd if="${dir}/idbloader.img" of="${dev}" seek=64 conv=notrunc,fsync >/dev/null 2>&1
    dd if="${dir}/u-boot.itb" of="${dev}" seek=16384 conv=notrunc,fsync >/dev/null 2>&1
}

# [MIRROR-AUTO] Repository mirror selection for image builds.
#
# The Installer picks its primary mirror from the chosen timezone
# (MIRROR_AUTO in Void_Linux_Installer.sh); the live build used to hardcode
# repo-default, which geo-resolves per builder (this box landed on the
# Helsinki mirror at ~0.29 MB/s while the US mirror did ~2.6 MB/s).
#
# Selection order:
#   1. VOIDLIVE_MIRROR=<base url> — explicit, no probing (reproducible builds).
#   2. cached winner from ${BUILD_ENV_DIR:-$PWD/.void-buildenv}/void-mirror
#      (TTL VOIDLIVE_MIRROR_CACHE_SECS, default 3600).
#   3. timezone -> region candidate first, then a short ranged GET of each
#      candidate's repodata; fastest reachable mirror wins, ties keep the
#      region candidate. No third-party geolocation service is contacted.
#
# Everything below is POSIX sh because lib.sh is sourced by the mklive tools.
void_mirror_timezone() {
    [ -n "${TZ:-}" ] && { printf '%s\n' "$TZ"; return 0; }
    _vtz=$(readlink -f /etc/localtime 2>/dev/null || true)
    case "$_vtz" in
        */zoneinfo/*) printf '%s\n' "${_vtz#*/zoneinfo/}" ;;
        *) printf '%s\n' "$(date +%Z 2>/dev/null || true)" ;;
    esac
}

void_mirror_region() {
    case "$1" in
        America/Sao_Paulo|America/Argentina/*|America/La_Paz|America/Bogota|America/Lima|America/Caracas|America/Santiago|America/Buenos_Aires|America/Mexico_City)
            printf '%s\n' https://void.voidbr.org ;;
        America/*|Canada/*)
            printf '%s\n' https://mirrors.summithq.com/voidlinux ;;
        Europe/*)
            printf '%s\n' https://repo-de.voidlinux.org ;;
        Asia/*|Indian/*)
            printf '%s\n' https://mirrors.tuna.tsinghua.edu.cn/voidlinux ;;
        Australia/*|Pacific/*)
            printf '%s\n' https://mirror.aarnet.edu.au/pub/voidlinux ;;
        *)
            printf '%s\n' https://repo-default.voidlinux.org ;;
    esac
}

void_mirror_candidates() {
    _vregion=$(void_mirror_region "$(void_mirror_timezone)")
    _vseen=
    for _vm in "$_vregion" \
        https://repo-fastly.voidlinux.org \
        https://repo-default.voidlinux.org \
        https://repo-de.voidlinux.org \
        https://mirrors.summithq.com/voidlinux \
        https://mirrors.tuna.tsinghua.edu.cn/voidlinux \
        https://mirror.aarnet.edu.au/pub/voidlinux \
        https://void.voidbr.org; do
        case " $_vseen " in *" $_vm "*) continue ;; esac
        _vseen="$_vseen $_vm"
        printf '%s\n' "$_vm"
    done
}

# Print the measured download speed (B/s) for one mirror, or fail.
void_mirror_probe() {
    command -v curl >/dev/null 2>&1 || return 1
    _vres=$(curl -fsS -r 0-262143 -o /dev/null \
        --max-time "${VOIDLIVE_MIRROR_PROBE_TIMEOUT:-8}" \
        -w '%{http_code} %{speed_download}' \
        "$1/current/x86_64-repodata" 2>/dev/null) || return 1
    case "$_vres" in
        "200 "*|"206 "*)
            set -- $_vres
            [ "${2:-0}" -gt 0 ] 2>/dev/null || return 1
            printf '%s\n' "$2" ;;
        *) return 1 ;;
    esac
}

void_mirror_pick() {
    [ -n "${VOIDLIVE_MIRROR_SELECTED:-}" ] && return 0
    if [ -n "${VOIDLIVE_MIRROR:-}" ]; then
        VOIDLIVE_MIRROR_SELECTED="${VOIDLIVE_MIRROR%/}"
        export VOIDLIVE_MIRROR_SELECTED
        return 0
    fi

    _vdir="${BUILD_ENV_DIR:-$PWD/.void-buildenv}"
    _vcache="$_vdir/void-mirror"
    if [ -r "$_vcache" ]; then
        read -r _vts _vurl < "$_vcache" || true
        if [ -n "${_vurl:-}" ] && [ -n "${_vts:-}" ] &&
           [ "$(date +%s)" -lt "$(( _vts + ${VOIDLIVE_MIRROR_CACHE_SECS:-3600} ))" ] 2>/dev/null; then
            VOIDLIVE_MIRROR_SELECTED="$_vurl"
            export VOIDLIVE_MIRROR_SELECTED
            return 0
        fi
    fi

    _vregion=$(void_mirror_region "$(void_mirror_timezone)")
    _vbest=; _vspeed=0
    while IFS= read -r _vm; do
        [ -n "$_vm" ] || continue
        _vs=$(void_mirror_probe "$_vm") || continue
        if [ "$_vs" -gt "$_vspeed" ] 2>/dev/null; then
            _vspeed=$_vs; _vbest=$_vm
        fi
    done <<EOF
$(void_mirror_candidates)
EOF
    [ -n "$_vbest" ] || _vbest=$_vregion
    VOIDLIVE_MIRROR_SELECTED=$_vbest
    export VOIDLIVE_MIRROR_SELECTED
    mkdir -p "$_vdir" 2>/dev/null || true
    printf '%s %s\n' "$(date +%s)" "$_vbest" > "$_vcache" 2>/dev/null || true
    printf 'void-mirror: %s (region=%s, %s B/s)\n' \
        "$_vbest" "$_vregion" "$_vspeed" >&2
}

void_repository_args() {
    void_mirror_pick
    printf -- '--repository=%s/current --repository=%s/current/aarch64\n' \
        "$VOIDLIVE_MIRROR_SELECTED" "$VOIDLIVE_MIRROR_SELECTED"
}

# [MIRROR-AUTO] all architectures resolve under the selected mirror; a musl
# image still re-adds .../current/musl explicitly (see UPSTREAM.md).
: "${XBPS_REPOSITORY:=$(void_repository_args)}"

# This library is the authoritative source of the platform map,
# because of this we may need to get this information from the command
# line.  This select allows us to get that information out.  This
# fails silently if the toolname isn't known since this script is
# sourced.
case "${1:-}" in
    platform2arch)
        PLATFORM=$2
        set_target_arch_from_platform
        echo "$XBPS_TARGET_ARCH"
        ;;
esac
