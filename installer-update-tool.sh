#!/usr/bin/env sh
set -eu

# installer-update-tool.sh -- refresh the Void_Linux_Installer copy this stick
# runs (/usr/bin/void-installer), WITHOUT rebuilding the ISO.
#
# Baked into every image by mkiso.sh (include_installer_updater) at
# /usr/local/share/void-installer-update/installer-update-tool.sh -- that copy
# is what void-installer-launch's "check GitHub" prompt runs on the booted live
# system. On a host with the stick mounted, --target-dir <upperdir> lets the
# same file operate on the stick before its first boot.
#
# The installer is the single file every live entry point runs (the Desktop
# symlink and void-installer-launch both exec /usr/bin/void-installer), so
# replacing it replaces the installer everywhere. The ISO's rootfs is a
# read-only squashfs, so the update works through the persistence overlay: on
# a --persist boot dracut layers the VOID_OVL upperdir over /, the write lands
# ON the stick and survives reboots. On a NON-persistent boot the overlay is
# RAM-backed and the write would vanish at reboot -- the tool detects that and
# refuses (override with --force).
#
#   status                            ISO build vs in-effect copy vs overlay stamp
#   check [--ref R]                   fetch and COMPARE only -- no root, nothing
#                                     written; prints up to date / update available
#   update [--ref R] [--sha256 S] [--if-newer]
#                                     fetch the published code-only script at ref R
#                                     (default main, or $INSTALLER_REF), verify it,
#                                     back up the as-built copy once, install it.
#                                     --if-newer stops BEFORE any write when the
#                                     fetched bytes already match what is in
#                                     effect; this is what the live desktop
#                                     launcher's "check GitHub" prompt runs
#   restore                           put the as-built backup back
#
# Options:
#   --ref <tag|commit|main>   Git ref to fetch from the public installer repo
#   --sha256 <hex>            additionally require this exact sha256 (pin it!
#                             `status` prints the sha of whatever is in effect)
#   --target-dir <dir>        operate on <dir> instead of the running root; a
#                             host passes the mounted overlay upperdir, so a
#                             stick can be prepared before its first boot
#   --force                   allow update on a non-persistent (RAM) overlay
#
# Fetch seam mirrors the build-time installer_fetch (lib.sh):
#   $INSTALLER_URL_BASE/$INSTALLER_REPO/<ref>/$INSTALLER_BASENAME
# so a stick can be moved to any later release tag with:
#   sudo /usr/local/share/void-installer-update/installer-update-tool.sh update --ref v2.9.99 --sha256 <pin>
#
# Nothing is installed unless the download parses (bash -n), carries a
# SCRIPT_VERSION= line, and matches --sha256 when one is given -- catching
# truncated downloads and wrong-ref mistakes before anything is written.

INSTALLER_REPO="${INSTALLER_REPO:-bluesloth/void-linux-installer}"
INSTALLER_BASENAME="${INSTALLER_BASENAME:-Void_Linux_Installer.sh}"
INSTALLER_URL_BASE="${INSTALLER_URL_BASE:-https://raw.githubusercontent.com}"

TARGET_DIR="/"
CMD=
REF="${INSTALLER_REF:-main}"
SHA_PIN=
FORCE=no
IF_NEWER=no

STAMP_DIR_REL="usr/local/share/void-installer-update"
BIN_REL="usr/bin/void-installer"
ASBUILT_NAME="void-installer.asbuilt"
PREVIOUS_NAME="void-installer.previous"

die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
    cat <<'UOH'
Usage: installer-update-tool.sh <status|check|update|restore> [options]

  status                            ISO build vs in-effect installer vs overlay stamp
  check [--ref R]                   fetch and compare only (no root, nothing written)
  update [--ref R] [--sha256 S] [--if-newer]
                                    fetch, verify, install (as root); --if-newer
                                    exits without touching anything when the
                                    fetched bytes already match
  restore                           put the as-built backup back (as root)

Options:
  --ref <tag|commit|main>   Git ref to fetch (default: $INSTALLER_REF or main)
  --sha256 <hex>            require this exact sha256 of the fetched script
  --if-newer                with update: skip the install when the shas match
  --target-dir <dir>        operate on <dir> instead of / (host-side use)
  --force                   allow update on a non-persistent (RAM) overlay

On the booted persistent live system (or from the desktop: double-click the
Install shortcut, which offers this check for you):
  /usr/local/share/void-installer-update/installer-update-tool.sh check --ref main
  sudo /usr/local/share/void-installer-update/installer-update-tool.sh status
  sudo /usr/local/share/void-installer-update/installer-update-tool.sh update --ref v2.9.99 --sha256 <pin printed by status>
UOH
    exit 0
}

# Path inside the target root ($TARGET_DIR/<rel>; a bare "/" collapses cleanly).
tpath() { printf '%s/%s\n' "${TARGET_DIR%/}" "$1"; }

sha_of() { sha256sum "$1" | awk '{print $1}'; }

# First SCRIPT_VERSION="..." value in $1 (empty when absent).
ver_of() { sed -n 's/^SCRIPT_VERSION="\([^"]*\)".*$/\1/p' "$1" | head -n1; }

# Verdict about the overlay backing / on the RUNNING system:
#   persistent  a real (stick-backed) upper layer -- updates survive reboots
#   ram         dracut fell back to a RAM overlay -- updates would be LOST
#   no-overlay  / is not an overlayfs at all (a regular installed system)
# The upperdir (when there is one) is printed as the second field.
persist_verdict() {
    _fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || true)
    [ "$_fstype" = overlay ] || { printf 'no-overlay\n'; return 0; }
    _opts=$(findmnt -n -o OPTIONS / 2>/dev/null || true)
    _upper=$(printf '%s\n' "$_opts" | tr ',' '\n' | sed -n 's/^upperdir=//p' | head -n1)
    if [ -z "$_upper" ]; then printf 'no-overlay\n'; return 0; fi
    # The upperdir itself is not a mountpoint: ask findmnt which filesystem
    # holds it. A stick-backed partition answers /dev/...; dracut's RAM
    # fallback overlay answers tmpfs. That distinction is what decides whether
    # a write here survives the next reboot.
    _src=$(findmnt -n -o SOURCE --target "$_upper" 2>/dev/null || true)
    case "$_src" in
        /dev/*) printf 'persistent %s\n' "$_upper" ;;
        *)      printf 'ram %s\n' "$_upper" ;;
    esac
    unset _fstype _opts _upper _src
}

cmd_status() {
    _ref_file=$(tpath "etc/void-linux-live/installer-ref")
    _bin=$(tpath "$BIN_REL")
    _stamp=$(tpath "$STAMP_DIR_REL/stamp")
    _asbuilt=$(tpath "$STAMP_DIR_REL/$ASBUILT_NAME")

    printf 'Target root      : %s\n' "$TARGET_DIR"
    if [ -r "$_ref_file" ]; then
        printf 'ISO build (as built by mkiso):\n'
        sed 's/^/  /' "$_ref_file"
    else
        printf 'ISO build stamp  : %s (absent)\n' "$_ref_file"
    fi

    if [ -f "$_bin" ]; then
        printf 'In effect now    : version=%s sha256=%s\n' "$(ver_of "$_bin")" "$(sha_of "$_bin")"
        printf '                   (%s)\n' "$_bin"
    else
        printf 'In effect now    : %s MISSING\n' "$_bin"
    fi

    if [ -r "$_stamp" ]; then
        # A restored stamp records a rollback, not a live overlay update --
        # label it as such so `status` never reports a pending update after
        # `restore` (the sha lines below say which copy is actually in effect).
        if grep -q '^restored_utc=' "$_stamp" 2>/dev/null; then
            printf 'Last restore     :\n'
        else
            printf 'Overlay update   :\n'
        fi
        sed 's/^/  /' "$_stamp"
    else
        printf 'Overlay update   : none (the ISO copy is in effect)\n'
    fi
    if [ -f "$_asbuilt" ]; then
        printf 'As-built backup  : %s\n' "$_asbuilt"
    fi

    if [ "$TARGET_DIR" = "/" ]; then
        set -- $(persist_verdict)
        case "$1" in
            persistent)
                printf 'Persistence      : persistent overlay (%s) -- updates survive reboots\n' "$2" ;;
            ram)
                printf 'Persistence      : RAM overlay (%s)\n' "$2"
                warn "an update on this boot would be LOST at reboot -- boot the stick with persistence" ;;
            no-overlay)
                printf 'Persistence      : / is not a live overlay (a regular installed system)\n'
                warn "this tool targets the live medium; use --target-dir <upperdir> from a host" ;;
        esac
    fi
    unset _ref_file _bin _stamp _asbuilt
}

# Fetch $REF from the public repo into a temp file and verify it BEFORE
# anything on the stick is touched: shell shebang, bash -n (sh -n without
# bash), a SCRIPT_VERSION= line, and --sha256 when one is given -- catching
# truncated downloads and wrong-ref mistakes before any write.  Sets
# _url _tmp _new_ver _new_sha and installs the EXIT trap that removes $_tmp;
# the caller clears the trap once it no longer needs the temp file.
fetch_verify() {
    need_cmd curl
    need_cmd sha256sum
    [ -n "$REF" ] || die "empty --ref"

    _url="$INSTALLER_URL_BASE/$INSTALLER_REPO/$REF/$INSTALLER_BASENAME"
    _tmp=$(mktemp)
    trap 'rm -f "$_tmp"' EXIT INT TERM
    printf 'Fetching        : %s\n' "$_url"
    _retry_all=
    if curl --retry-all-errors --version >/dev/null 2>&1; then _retry_all=--retry-all-errors; fi
    # shellcheck disable=SC2086  # $_retry_all is a deliberate option word-split
    curl -fsSL --max-time 60 --retry 5 --retry-delay 3 $_retry_all -o "$_tmp" "$_url" \
        || die "could not fetch $_url (after retries) -- check the network or the ref name"

    # ---- verify BEFORE touching anything on the stick ----
    _head=$(head -n1 "$_tmp" 2>/dev/null || true)
    case "$_head" in
        '#!'*sh*|'#!'*bash*) : ;;
        *) die "fetched file does not start with a shell shebang (got: ${_head:-(empty)}) -- refusing to install" ;;
    esac
    if command -v bash >/dev/null 2>&1; then
        bash -n "$_tmp" 2>/dev/null || die "fetched script fails 'bash -n' -- refusing to install"
    else
        sh -n "$_tmp" 2>/dev/null || die "fetched script fails 'sh -n' -- refusing to install"
    fi
    _new_ver=$(ver_of "$_tmp")
    [ -n "$_new_ver" ] || die "no SCRIPT_VERSION= in the fetched file -- refusing to install"
    _new_sha=$(sha_of "$_tmp")
    if [ -n "$SHA_PIN" ] && [ "$_new_sha" != "$SHA_PIN" ]; then
        die "sha256 mismatch: got $_new_sha, expected pin $SHA_PIN -- refusing to install"
    fi
    printf 'Fetched         : version=%s sha256=%s\n' "$_new_ver" "$_new_sha"
}

# Compare what the repo serves with what is in effect -- read-only, no root,
# nothing written (no persistence check either: a read is safe on any boot).
# Exit status is 0 for EITHER verdict (up to date / update available); only a
# fetch or verification failure is an error, so a caller that must never block
# -- void-installer-launch's "check GitHub?" prompt -- can treat any failure
# as "just run the local copy".
cmd_check() {
    _bin=$(tpath "$BIN_REL")

    fetch_verify

    if [ -f "$_bin" ]; then
        _cur_ver=$(ver_of "$_bin")
        _cur_sha=$(sha_of "$_bin")
        printf 'In effect       : version=%s sha256=%s\n' "$_cur_ver" "$_cur_sha"
    else
        _cur_ver=
        _cur_sha=
        printf 'In effect       : %s MISSING\n' "$_bin"
    fi

    if [ -n "$_cur_sha" ] && [ "$_cur_sha" = "$_new_sha" ]; then
        printf 'Result          : up to date (version=%s, nothing to do)\n' "$_new_ver"
    else
        printf 'Result          : update available -- remote version=%s, in effect version=%s\n' \
            "$_new_ver" "${_cur_ver:-missing}"
    fi
    rm -f "$_tmp"
    trap - EXIT INT TERM
    unset _bin _cur_ver _cur_sha
}

cmd_update() {
    _bin=$(tpath "$BIN_REL")
    _stamp=$(tpath "$STAMP_DIR_REL/stamp")
    _asbuilt=$(tpath "$STAMP_DIR_REL/$ASBUILT_NAME")
    _prev=$(tpath "$STAMP_DIR_REL/$PREVIOUS_NAME")

    # Live-root mode: refuse where the write cannot stick (see persist_verdict).
    # A plain `update` fails FAST, before the fetch (behaviour unchanged).
    # `update --if-newer` defers the refusal until a write is actually needed,
    # so "already up to date" still answers on a RAM-only or non-overlay root.
    _persist_ok=yes
    if [ "$TARGET_DIR" = "/" ] && [ "$FORCE" != yes ]; then
        case "$(persist_verdict)" in
            persistent) : ;;
            ram)         _persist_ok=ram ;;
            no-overlay)  _persist_ok=no-overlay ;;
        esac
    fi
    if [ "$IF_NEWER" != yes ]; then
        case "$_persist_ok" in
            ram)         die "this boot runs from a RAM overlay -- the update would be lost at reboot (boot with persistence, or --force)" ;;
            no-overlay)  die "/ is not a live overlay -- use --target-dir <upperdir> for host-side use (or --force)" ;;
        esac
    fi

    fetch_verify

    # ---- --if-newer: stop here, before any write, when the bytes match ----
    if [ "$IF_NEWER" = yes ] && [ -f "$_bin" ] && [ "$(sha_of "$_bin")" = "$_new_sha" ]; then
        printf 'Already up to date: version=%s sha256=%s -- nothing written\n' "$_new_ver" "$_new_sha"
        rm -f "$_tmp"
        trap - EXIT INT TERM
        unset _bin _stamp _asbuilt _prev _url _tmp _retry_all _head _new_ver _new_sha
        return 0
    fi

    # A real install is needed (--if-newer only reaches here when it is):
    # now the persistence refusal applies.
    case "$_persist_ok" in
        ram)         die "this boot runs from a RAM overlay -- the update would be lost at reboot (boot with persistence, or --force)" ;;
        no-overlay)  die "/ is not a live overlay -- use --target-dir <upperdir> for host-side use (or --force)" ;;
    esac

    # ---- back up, then install ----
    if [ -f "$_bin" ]; then
        mkdir -p "$(dirname "$_asbuilt")"
        if [ "$TARGET_DIR" = "/" ] && [ ! -f "$_asbuilt" ]; then
            # First live update: remember exactly what the ISO shipped.
            cp -p "$_bin" "$_asbuilt"
            printf 'As-built backup : %s\n' "$_asbuilt"
        elif [ "$TARGET_DIR" != "/" ]; then
            # Host-side: whatever sits in the upperdir is a previous overlay
            # update; keep it so it can be put back.
            cp -p "$_bin" "$_prev"
        fi
    fi
    install -Dm0755 "$_tmp" "$_bin"
    mkdir -p "$(dirname "$_stamp")"
    {
        printf 'ref=%s\n'          "$REF"
        printf 'version=%s\n'      "$_new_ver"
        printf 'sha256=%s\n'       "$_new_sha"
        printf 'url=%s\n'          "$_url"
        printf 'installed_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$_stamp"
    printf 'Installed       : version=%s -> %s\n' "$_new_ver" "$_bin"
    printf 'Stamp           : %s\n' "$_stamp"
    if [ "$TARGET_DIR" = "/" ]; then
        printf 'Rollback        : sudo %s restore\n' "$0"
    fi
    rm -f "$_tmp"
    trap - EXIT INT TERM
    unset _bin _stamp _asbuilt _prev _url _tmp _retry_all _head _new_ver _new_sha
}

cmd_restore() {
    _bin=$(tpath "$BIN_REL")
    _stamp=$(tpath "$STAMP_DIR_REL/stamp")
    _asbuilt=$(tpath "$STAMP_DIR_REL/$ASBUILT_NAME")
    _prev=$(tpath "$STAMP_DIR_REL/$PREVIOUS_NAME")

    if [ "$TARGET_DIR" = "/" ]; then
        [ -f "$_asbuilt" ] || die "no as-built backup at $_asbuilt -- nothing to restore"
        install -m0755 "$_asbuilt" "$_bin"
        printf 'Restored        : as-built copy -> %s\n' "$_bin"
        printf 'Note            : the overlay file is overwritten, never deleted (a delete through\n'
        printf '                  overlayfs would whiteout the squashfs copy for good).\n'
        mkdir -p "$(dirname "$_stamp")"
        {
            printf 'restored_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            printf 'asbuilt_sha256=%s\n' "$(sha_of "$_asbuilt")"
            printf 'note=restored to as-built ISO copy\n'
        } > "$_stamp"
    else
        if [ -f "$_prev" ]; then
            install -m0755 "$_prev" "$_bin"
            printf 'Restored        : previous overlay copy -> %s\n' "$_bin"
            mkdir -p "$(dirname "$_stamp")"
            {
                printf 'restored_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                printf 'previous_sha256=%s\n' "$(sha_of "$_prev")"
                printf 'note=restored to previous overlay copy\n'
            } > "$_stamp"
        elif [ -e "$_bin" ]; then
            # Host-side this is a plain directory entry, not an overlayfs:
            # removing it makes the squashfs copy show through on next boot.
            rm -f "$_bin"
            printf 'Removed         : the overlay update; the ISO copy shows through on next boot.\n'
            rm -f "$_stamp" 2>/dev/null || :
        else
            die "no previous copy and nothing installed at $_bin"
        fi
    fi
    unset _bin _stamp _asbuilt _prev
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        status|check|update|restore) CMD="$1"; shift ;;
        --ref) [ "$#" -ge 2 ] || die "--ref requires a value"; REF="$2"; shift 2 ;;
        --ref=*) REF="${1#*=}"; shift ;;
        --sha256) [ "$#" -ge 2 ] || die "--sha256 requires a value"; SHA_PIN="$2"; shift 2 ;;
        --sha256=*) SHA_PIN="${1#*=}"; shift ;;
        --if-newer) IF_NEWER=yes; shift ;;
        --target-dir) [ "$#" -ge 2 ] || die "--target-dir requires a directory"; TARGET_DIR="$2"; shift 2 ;;
        --target-dir=*) TARGET_DIR="${1#*=}"; shift ;;
        --force) FORCE=yes; shift ;;
        -h|--help|help) usage ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done
[ -n "$CMD" ] || usage

# Live-root writes always need root; a --target-dir write only needs the
# directory to be writable (flash() runs as root, but a user-mounted stick
# partition works too).  `status` and `check` write nothing, so they never do.
if [ "$CMD" != status ] && [ "$CMD" != check ]; then
    if [ "$TARGET_DIR" = "/" ]; then
        [ "$(id -u)" -eq 0 ] || die "$CMD must run as root (it writes /$BIN_REL)"
    fi
fi
if [ "$TARGET_DIR" != "/" ] && [ ! -d "$TARGET_DIR" ]; then
    die "target dir does not exist: $TARGET_DIR"
fi

case "$CMD" in
    status)  cmd_status ;;
    check)   cmd_check ;;
    update)  cmd_update ;;
    restore) cmd_restore ;;
esac
