#!/usr/bin/env sh
set -eu

# xbps-cache-tool.sh -- maintain the XBPS package cache a Void Linux live stick
# carries, so a later Void_Linux_Installer run reuses CURRENT package payloads
# instead of ignoring the outdated ones.
#
# The cache is a raw XBPS download cache (the same directory mklive/mkiso use
# via -c).  XBPS keys cache lookups by exact pkgver, so a cache full of older
# versions is skipped during an install even when the filenames are present.
# This tool therefore has to download the CURRENT repository version of every
# package already in the cache -- refreshing the index alone is not enough.
#
# On the booted persistent live system the tool is /xbps-cache-tool.sh and the
# seeded cache is /xbps-cachedir-<arch>.  The same tool also runs when the
# stick is plugged into an ordinary Linux box: it auto-detects the cache in the
# current directory (./xbps-cachedir-<arch>, i.e. you cd'd into the stick), at
# the live-overlay root, at the dracut overlay mountpoints, and under /run/media
# using the same first-wins rules as the Void_Linux_Installer's
# _local_cache_detect() -- so it always targets the cache an install would
# auto-pick.  --cache is only needed to override that choice.
#
# A --seed-cache flash writes the cache into BOTH the VOID_OVL partition root
# and the dmsquash-live overlay upperdir (LiveOS/overlay-<label>-<uuid>/), so
# that it is reachable whether dracut holds the partition as the overlay or
# udisks mounts it under /run/media.  update/replace/download keep those two
# copies in sync: the resolved cache is updated, then current payloads are
# copied to its peer and superseded versions are pruned from both.
#
# Commands:
#   status            resolved cache + package count (no root, no network)
#   update|upgrade    refresh the index, download current versions of every
#                     cached package, prune superseded versions, sync peers
#   index             refresh the on-disk XBPS repository index only
#   replace           wipe *.xbps/*.sig2, refresh, then re-download the package
#                     set that was in the cache (or --pkgs)
#   download          refresh, then download --pkgs (and their dependencies)
#
# Options:
#   --cache <dir>     pin the cache directory (auto-detect otherwise)
#   --repo <url>      also use this XBPS repository for this run only (repeatable);
#                     useful when the cache holds packages from a repo that this
#                     host does not configure
#   --skip <pkg>      do not update this package (repeatable); useful while a
#                     repository publishes a broken payload
#   --pkgs '<pkg...>' space-separated package list for download / replace
#   --dry-run         show what update would change; download nothing
#   --keep-old        do not prune superseded package versions
#   -h, --help
#
# Examples:
#   sudo /xbps-cache-tool.sh status
#   sudo /xbps-cache-tool.sh update
#   sudo /xbps-cache-tool.sh update --dry-run
#   sudo /xbps-cache-tool.sh replace
#   sudo /xbps-cache-tool.sh download --pkgs 'base-system kde-plasma'
#   sudo /xbps-cache-tool.sh update --repo https://example.org/void-current
#   sudo /xbps-cache-tool.sh update --skip some-package
#
# update/replace/download/index must run as root (they refresh the rootdir's
# index and write payloads into the cache).  status works for anyone.
# On a non-Void host with podman or docker the tool re-execs itself inside
# ghcr.io/void-linux/void-glibc-full (override with XBPS_CACHE_TOOL_IMAGE), so
# the stick can be refreshed from any Linux box, not only from Void.

CACHE_DIR=
CMD=
EXTRA_REPOS=
SKIP_PKGS=
PKGS=
DRY_RUN=no
KEEP_OLD=no
ARCH=$(uname -m)
FAILED=
MEM_SYNC_USED=
REPO_INSTALL_ARGS=
REPO_QUERY_ARGS=

warn() { echo "WARN: $*" >&2; }
die()  { echo "FATAL: $*" >&2; exit 1; }

cleanup() {
    if [ -n "${WORK:-}" ]; then
        rm -rf "$WORK"
    fi
    if [ -n "${_SCRATCH:-}" ]; then
        rm -rf "$_SCRATCH"
    fi
}
trap cleanup EXIT HUP INT TERM

usage() {
    sed -n '2,/^#   -h, --help/p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# ---------------------------------------------------------------------------
# XBPS plumbing
# ---------------------------------------------------------------------------

# Prefer the real binary when a host wraps xbps-install (e.g. the snapper
# pre/post wrapper on this box); a cache update must not create system
# snapshots.  On the live system and plain Void hosts this is just xbps-install.
_xbps_install_bin() {
    if [ -x /usr/bin/xbps-install.real ]; then
        printf '%s\n' /usr/bin/xbps-install.real
    else
        command -v xbps-install
    fi
}

_have_xbps() {
    [ -x /usr/bin/xbps-install.real ] || command -v xbps-install >/dev/null 2>&1
}

_xbps_db() { printf '%s\n' "${XBPS_CACHE_TOOL_DB:-/var/db/xbps}"; }

# Re-run this tool inside a Void container when the host has no XBPS.
_container_reexec() {
    _rt=
    for _r in podman docker; do
        if command -v "$_r" >/dev/null 2>&1; then
            _rt=$_r
            break
        fi
    done
    [ -n "$_rt" ] || die "xbps-install is not available on this host and neither podman nor docker is installed.
       Boot the live stick and run this tool there, use a Void host, or install podman/docker."

    _self=$(readlink -f "$0" 2>/dev/null || printf '%s\n' "$0")
    _img=${XBPS_CACHE_TOOL_IMAGE:-ghcr.io/void-linux/void-glibc-full:latest}
    _net=${XBPS_CACHE_TOOL_NETWORK:-host}
    _cache=$(_cache_resolve)
    _mp=$(findmnt -T "$_cache" -no TARGET 2>/dev/null | head -n 1 || true)
    case "${_mp:-}" in
        ""|/) _mp=$_cache ;;
    esac
    [ -d "$_cache" ] || mkdir -p "$_cache" 2>/dev/null || true
    [ -d "$_mp" ] || _mp=$_cache

    echo "==> xbps-install not found; running in $_rt ($_img)"
    set -- run --rm -i --network "$_net" \
        -e XBPS_CACHE_TOOL_RUN_IN=native \
        -v "$_self:/xbps-cache-tool.sh:ro" \
        -v "$_mp:$_mp" \
        "$_img" /bin/sh /xbps-cache-tool.sh "$CMD" --cache "$_cache"
    if [ -n "$PKGS" ]; then set -- "$@" --pkgs "$PKGS"; fi
    if [ "$DRY_RUN" = yes ]; then set -- "$@" --dry-run; fi
    if [ "$KEEP_OLD" = yes ]; then set -- "$@" --keep-old; fi
    for _r in $EXTRA_REPOS; do set -- "$@" --repo "$_r"; done
    for _s in $SKIP_PKGS; do set -- "$@" --skip "$_s"; done
    exec "$_rt" "$@"
}

_need_xbps() {
    case "${XBPS_CACHE_TOOL_RUN_IN:-auto}" in
        container) _container_reexec ;;
        native)
            _have_xbps || die "xbps-install is not available on this host (XBPS_CACHE_TOOL_RUN_IN=native)"
            ;;
        *)
            _have_xbps && return 0
            _container_reexec
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Cache location
# ---------------------------------------------------------------------------

# newest-first candidate cache dirs: the current directory, live-overlay root,
# the dracut overlay mountpoints (a persistent VOID_OVL partition is held by
# dracut there and is often not auto-mounted by udisks), then /run/media
# depth-1 and depth-2 (the udisks /<user>/<uuid> layout)
_cache_candidates() {
    # ./xbps-cachedir-<arch> first: running the tool while cd'd into the stick
    # (or the build tree) should use that cache without --cache.
    ls -1dt "./xbps-cachedir-${ARCH}" \
        /xbps-cachedir-* \
        /run/initramfs/overlayfs/xbps-cachedir-* \
        /run/overlayfs-backing/xbps-cachedir-* \
        /run/media/*/xbps-cachedir-* \
        /run/media/*/*/xbps-cachedir-* 2>/dev/null || true
}

# Prefer a POPULATED, writable, arch-matching dir; fall back to any writable,
# arch-matching dir (an empty one can be seeded by update).
_cache_detect() {
    _fallback=
    for _cd in $(_cache_candidates); do
        [ -n "$_cd" ] || continue
        [ -d "$_cd" ] || continue
        case "$_cd" in
            *"xbps-cachedir-${ARCH}") : ;;
            *) continue ;;
        esac
        [ -w "$_cd" ] || continue
        if [ -n "$(find "$_cd" -maxdepth 1 -name '*.xbps' -print -quit 2>/dev/null)" ]; then
            printf '%s\n' "$_cd"
            unset _fallback _cd
            return 0
        fi
        [ -n "$_fallback" ] || _fallback="$_cd"
    done
    if [ -n "$_fallback" ]; then
        printf '%s\n' "$_fallback"
        unset _fallback _cd
        return 0
    fi
    unset _fallback _cd
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
            printf '%s\n' "/xbps-cachedir-${ARCH}"
        fi
        unset _d
    fi
}

# The --seed-cache flash writes the same cache to the partition root and to
# the dmsquash-live overlay upperdir.  Print the OTHER copy so update/replace/
# download can keep both fresh.  The layout is known, so do not scan unrelated
# caches on the same medium (e.g. a separate data-stick build cache).
_peer_caches() {
    _pc_primary=$(readlink -f "$1" 2>/dev/null || printf '%s\n' "$1")
    case "$_pc_primary" in
        /*/xbps-cachedir-"$ARCH")
            _pc_base=${_pc_primary%/xbps-cachedir-"$ARCH"}
            for _pc_o in "$_pc_base"/LiveOS/overlay-*/xbps-cachedir-"$ARCH"; do
                [ -d "$_pc_o" ] && printf '%s\n' "$_pc_o"
            done
            ;;
    esac
    case "$_pc_primary" in
        */LiveOS/overlay-*/xbps-cachedir-"$ARCH")
            _pc_base=${_pc_primary%/LiveOS/overlay-*/xbps-cachedir-"$ARCH"}
            [ -d "$_pc_base/xbps-cachedir-$ARCH" ] && printf '%s\n' "$_pc_base/xbps-cachedir-$ARCH"
            ;;
    esac
    case "$_pc_primary" in
        /xbps-cachedir-"$ARCH")
            for _pc_b in /run/initramfs/overlayfs /run/overlayfs-backing; do
                [ -d "$_pc_b/xbps-cachedir-$ARCH" ] && printf '%s\n' "$_pc_b/xbps-cachedir-$ARCH"
                for _pc_o in "$_pc_b"/LiveOS/overlay-*/xbps-cachedir-"$ARCH"; do
                    [ -d "$_pc_o" ] && printf '%s\n' "$_pc_o"
                done
            done
            ;;
    esac
    unset _pc_primary _pc_base _pc_o _pc_b
}

_peers() {
    _primary=$1
    _peer_caches "$_primary" | while IFS= read -r _p; do
        [ -n "$_p" ] || continue
        [ -d "$_p" ] || continue
        [ -w "$_p" ] || continue
        [ "$(readlink -f "$_p")" = "$(readlink -f "$_primary")" ] && continue
        printf '%s\n' "$_p"
    done | sort -u
    unset _primary _p
}

_ensure() {
    [ -d "$1" ] || mkdir -p "$1"
    [ -w "$1" ] || die "cache dir '$1' is not writable (run as root? medium read-only?)"
}

# ---------------------------------------------------------------------------
# Cache / repository inventory
# ---------------------------------------------------------------------------

# Print "<pkgname>\t<pkgver>" for every arch-matching *.xbps in a cache dir.
_scan_cache() {
    for _f in "$1"/*.xbps; do
        [ -e "$_f" ] || continue
        _b=${_f##*/}
        case "$_b" in
            *."$ARCH".xbps|*.noarch.xbps) : ;;
            *) continue ;;
        esac
        _b=${_b%.xbps}
        case "$_b" in
            *."$ARCH") _b=${_b%."$ARCH"} ;;
            *.noarch)  _b=${_b%.noarch} ;;
        esac
        printf '%s\n' "$_b"
    done | sort -u | awk '{v=$0; n=v; sub(/-[^-]*_[0-9][0-9]*$/, "", n); print n "\t" v}'
    unset _f _b
}

# Refresh the on-disk repository index and write "<pkgname>\t<pkgver>" for every
# package in every configured repository into $1/repomap.
_repo_snapshot() {
    _rs_work=$1
    _rs_cache=$2
    _rs_xbps=$(_xbps_install_bin)

    echo "==> refreshing repository index ..." >&2
    # shellcheck disable=SC2086
    "$_rs_xbps" $REPO_INSTALL_ARGS -S -c "$_rs_cache" >/dev/null 2>&1 \
        || warn "repository index refresh failed (network/repo?); using the existing index."

    # shellcheck disable=SC2086
    if ! xbps-query -R $REPO_QUERY_ARGS --regex -s '.*' 2>/dev/null | awk '{print $2}' > "$_rs_work/repovers"; then
        warn "could not list repository packages."
    fi
    [ -s "$_rs_work/repovers" ] || die "no repository package data available (check /etc/xbps.d, /usr/share/xbps.d and networking)."

    awk '{v=$0; n=v; sub(/-[^-]*_[0-9][0-9]*$/, "", n); print n "\t" v}' \
        "$_rs_work/repovers" | sort -u > "$_rs_work/repomap"
    cut -f1 "$_rs_work/repomap" | sort -u > "$_rs_work/reponames"
    unset _rs_work _rs_cache _rs_xbps
}

# Names that have at least one cached pkgver that is a current repo pkgver.
_satisfied_names() {
    awk -F'\t' 'FILENAME==ARGV[1]{k[$1 SUBSEP $2]=1; next} (($1 SUBSEP $2) in k){print $1}' "$1" "$2" | sort -u
}

# Cached names with no current repo version in the cache.
_missing_names() {
    awk 'FILENAME==ARGV[1]{s[$1]=1; next} !($1 in s){print $1}' "$1" "$2" | sort -u
}

# Cached names that do not exist in any configured repository.
_unknown_names() {
    awk 'FILENAME==ARGV[1]{r[$1]=1; next} !($1 in r){print $1}' "$1" "$2" | sort -u
}

# Drop entries whose cached version is NEWER than the repository candidate.
# That happens when a name comes from another repo (e.g. a desktop tree) that
# this host does not configure: the official repo would "update" it downwards.
# $1 repomap  $2 cachepairs  $3 candidate names  $4 kept output  $5 remaining output
_filter_downgrades() {
    _fg_repomap=$1
    _fg_pairs=$2
    _fg_in=$3
    : > "$4"
    : > "$5"
    while IFS= read -r _fg_name; do
        [ -n "$_fg_name" ] || continue
        _fg_repo=$(awk -F'\t' -v n="$_fg_name" '$1 == n { print $2; exit }' "$_fg_repomap")
        [ -n "$_fg_repo" ] || continue
        _fg_newer=no
        _fg_cached_list=$(awk -F'\t' -v n="$_fg_name" '$1 == n { print $2 }' "$_fg_pairs")
        for _fg_cached in $_fg_cached_list; do
            # cmpver: 0 equal, 1 first newer, 255 first older. It must not trip
            # set -e, so capture the status explicitly.
            _fg_rc=0
            xbps-uhelper cmpver "$_fg_cached" "$_fg_repo" >/dev/null 2>&1 || _fg_rc=$?
            if [ "$_fg_rc" -eq 1 ]; then
                _fg_newer=yes
                break
            fi
        done
        if [ "$_fg_newer" = yes ]; then
            printf '%s\n' "$_fg_name" >> "$4"
        else
            printf '%s\n' "$_fg_name" >> "$5"
        fi
    done < "$_fg_in"
    unset _fg_repomap _fg_pairs _fg_in _fg_name _fg_repo _fg_newer _fg_cached_list _fg_cached
}

_show_list() {
    _sl_file=$1
    _sl_max=${2:-20}
    _sl_total=$(wc -l < "$_sl_file" | tr -d ' ')
    _sl_i=0
    while IFS= read -r _sl_line; do
        [ -n "$_sl_line" ] || continue
        _sl_i=$((_sl_i + 1))
        if [ "$_sl_i" -le "$_sl_max" ]; then
            echo "    $_sl_line"
        elif [ "$_sl_i" -eq $((_sl_max + 1)) ]; then
            echo "    ... ($((_sl_total - _sl_max)) more)"
        fi
    done < "$_sl_file"
    unset _sl_file _sl_max _sl_total _sl_i _sl_line
}

# ---------------------------------------------------------------------------
# Download + prune + peer sync
# ---------------------------------------------------------------------------

# A throwaway rootdir gives xbps an empty target so every listed package is
# resolved and its payload is downloaded into the cache.  Seed it with the
# host's repository indexes, signing keys and repository configuration; callers
# refresh the index first.  Both config locations matter: stock Void keeps the
# main repo in /usr/share/xbps.d, while local/third-party repos live in
# /etc/xbps.d.  Passing -C would hide one of them.
_prepare_scratch() {
    [ -n "${_SCRATCH:-}" ] && return 0
    _ps_db=$(_xbps_db)
    _SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/xbps-cache-tool.XXXXXX")
    mkdir -p "$_SCRATCH/var/db/xbps"
    for _ps_d in "$_ps_db"/*; do
        [ -d "$_ps_d" ] || continue
        case "${_ps_d##*/}" in
            keys) continue ;;
        esac
        cp -a "$_ps_d" "$_SCRATCH/var/db/xbps/" 2>/dev/null || true
    done
    if [ -d "$_ps_db/keys" ]; then
        cp -a "$_ps_db/keys" "$_SCRATCH/var/db/xbps/" 2>/dev/null || true
    fi
    [ -d "$_SCRATCH/var/db/xbps/keys" ] || warn "no XBPS keys at $_ps_db/keys; signature verification may fail."
    if [ -d /etc/xbps.d ]; then
        mkdir -p "$_SCRATCH/etc"
        cp -a /etc/xbps.d "$_SCRATCH/etc/" 2>/dev/null || true
    fi
    if [ -d /usr/share/xbps.d ]; then
        mkdir -p "$_SCRATCH/usr/share"
        cp -a /usr/share/xbps.d "$_SCRATCH/usr/share/" 2>/dev/null || true
    fi
    unset _ps_db _ps_d
}

_xbps_dl_once() {
    # shellcheck disable=SC2086
    "$_XBPS_INSTALL" $REPO_INSTALL_ARGS -D -r "$_SCRATCH" -c "$_CACHE" -y "$@"
}

_xbps_dl() {
    # Normal path: use the index just refreshed in the host rootdir and the
    # repository configuration copied into the scratch rootdir.
    if _xbps_dl_once "$@"; then
        return 0
    fi
    # Stale index? Fetch fresh repository data into memory and retry -- once
    # per run only, and only for the bulk call (the per-package retry already
    # isolates the culprit and would just repeat the noise).
    if [ -n "$MEM_SYNC_USED" ]; then
        return 1
    fi
    MEM_SYNC_USED=yes
    warn "retrying with memory-synced repository data ..."
    # shellcheck disable=SC2086
    "$_XBPS_INSTALL" $REPO_INSTALL_ARGS -M -D -r "$_SCRATCH" -c "$_CACHE" -y "$@"
}

# $1 = file with one package name per line
# Split a name list into names requested via --skip (written to $3) and the
# rest (written to $2).  $1 is the input list.
_drop_skipped() {
    if [ -z "$SKIP_PKGS" ]; then
        cp "$1" "$2"
        : > "$3"
        return 0
    fi
    # shellcheck disable=SC2086
    printf '%s\n' $SKIP_PKGS | sort -u > "$WORK/skip.names"
    awk 'FILENAME==ARGV[1]{s[$1]=1; next} !($1 in s)' \
        "$WORK/skip.names" "$1" > "$2"
    awk 'FILENAME==ARGV[1]{s[$1]=1; next} ($1 in s)' \
        "$WORK/skip.names" "$1" > "$3"
}

# Drop names that already failed earlier in this run (the peer pass would
# otherwise try the same broken payload again): $1 input list, $2 output list.
_drop_failed() {
    if [ -n "$FAILED" ]; then
        # shellcheck disable=SC2086
        printf '%s\n' $FAILED | sort -u > "$WORK/failed.names"
        awk 'FILENAME==ARGV[1]{f[$1]=1; next} !($1 in f)' \
            "$WORK/failed.names" "$1" > "$2"
    else
        cp "$1" "$2"
    fi
}

_download_bulk() {
    # Keep the file name: `set --` below replaces the positional parameters.
    _db_file=$1
    [ -s "$_db_file" ] || return 0
    _drop_failed "$_db_file" "$WORK/dl.names"
    [ -s "$WORK/dl.names" ] || { unset _db_file; return 0; }
    # shellcheck disable=SC2046
    set -- $(cat "$WORK/dl.names")
    if _xbps_dl "$@"; then
        unset _db_file
        return 0
    fi
    # One package needs no isolation: the failure is already the culprit, and
    # re-fetching a payload that just failed verification only repeats noise.
    if [ "$#" -eq 1 ]; then
        FAILED="$FAILED $1"
        unset _db_file
        return 0
    fi
    warn "bulk download failed; retrying each package individually."
    _db_failed=
    while IFS= read -r _db_name; do
        [ -n "$_db_name" ] || continue
        if ! _xbps_dl_once "$_db_name" >/dev/null 2>&1; then
            _db_failed="$_db_failed $_db_name"
        fi
    done < "$WORK/dl.names"
    if [ -n "$_db_failed" ]; then
        FAILED="$FAILED $_db_failed"
    fi
    unset _db_failed _db_name _db_file
}

# Delete cached *.xbps/*.sig2 whose pkgver is not a current repo pkgver, but
# only for names that actually have a current version present in this cache.
# A failed download therefore never removes the old (still usable) payload.
_prune_cache() {
    _pr_dir=$1
    _pr_repomap=$2
    _pr_satisfied=$3
    _scan_cache "$_pr_dir" > "$WORK/pairs"
    awk -F'\t' 'FILENAME==ARGV[1]{s[$1]=1; next} ($1 in s)' "$_pr_satisfied" "$WORK/pairs" > "$WORK/satpairs"
    awk -F'\t' 'FILENAME==ARGV[1]{k[$1 SUBSEP $2]=1; next} !(($1 SUBSEP $2) in k){print $2}' \
        "$_pr_repomap" "$WORK/satpairs" > "$WORK/obsolete"
    _pr_n=$(wc -l < "$WORK/obsolete" | tr -d ' ')
    if [ "$_pr_n" -gt 0 ]; then
        echo "==> pruning $_pr_n superseded package version(s) from $_pr_dir"
        while IFS= read -r _pr_v; do
            [ -n "$_pr_v" ] || continue
            rm -f "$_pr_dir/$_pr_v.$ARCH.xbps" "$_pr_dir/$_pr_v.$ARCH.xbps.sig2"
        done < "$WORK/obsolete"
    fi
    unset _pr_dir _pr_repomap _pr_satisfied _pr_n _pr_v
}

_sync_peer() {
    _sp_src=$1
    _sp_dst=$2
    echo "==> syncing current payloads to peer cache: $_sp_dst"
    _sp_added=0
    for _sp_f in "$_sp_src"/*.xbps "$_sp_src"/*.xbps.sig2; do
        [ -e "$_sp_f" ] || continue
        _sp_b=${_sp_f##*/}
        if [ ! -e "$_sp_dst/$_sp_b" ]; then
            cp -a "$_sp_f" "$_sp_dst/$_sp_b" || warn "could not copy $_sp_b to $_sp_dst"
            _sp_added=$((_sp_added + 1))
        fi
    done
    echo "    $_sp_added file(s) copied"
    unset _sp_src _sp_dst _sp_added _sp_f _sp_b
}

_sync_peers() {
    _sy_cache=$1
    _sy_repomap=$2
    # A pipeline would run this loop in a subshell and lose downloads that
    # failed (FAILED), so feed it from a file instead.
    _peers "$_sy_cache" > "$WORK/peerlist"
    while IFS= read -r _sy_peer; do
        [ -n "$_sy_peer" ] || continue
        [ -d "$_sy_peer" ] || continue
        _sync_peer "$_sy_cache" "$_sy_peer"

        # Copying from the primary does not cover packages that only exist in
        # the peer (e.g. a desktop-specific set the other cache never had).
        # Download those too, otherwise the live boot still ignores them.
        _scan_cache "$_sy_peer" > "$WORK/ppairs"
        cut -f1 "$WORK/ppairs" | sort -u > "$WORK/pnames"
        _satisfied_names "$_sy_repomap" "$WORK/ppairs" > "$WORK/psat"
        _missing_names "$WORK/psat" "$WORK/pnames" > "$WORK/pmissing_all"
        _unknown_names "$WORK/reponames" "$WORK/pnames" > "$WORK/punknown"
        awk 'FILENAME==ARGV[1]{u[$1]=1; next} !($1 in u)' \
            "$WORK/punknown" "$WORK/pmissing_all" > "$WORK/pmissing_known"
        _filter_downgrades "$_sy_repomap" "$WORK/ppairs" \
            "$WORK/pmissing_known" "$WORK/pkept_newer" "$WORK/pmissing_repo"
        _drop_skipped "$WORK/pmissing_repo" "$WORK/pmissing" "$WORK/pskipped"
        # Skip names that already failed in this run before announcing them.
        _drop_failed "$WORK/pmissing" "$WORK/pmissing_dl"
        _sy_n=$(wc -l < "$WORK/pmissing_dl" | tr -d ' ')
        if [ "$_sy_n" -gt 0 ]; then
            echo "==> downloading $_sy_n current package(s) present only in $_sy_peer ..."
            _prepare_scratch
            _sy_saved_cache=$_CACHE
            _CACHE=$_sy_peer
            _download_bulk "$WORK/pmissing_dl"
            _CACHE=$_sy_saved_cache
        fi

        if [ "$KEEP_OLD" != yes ]; then
            _scan_cache "$_sy_peer" > "$WORK/ppairs"
            _satisfied_names "$_sy_repomap" "$WORK/ppairs" > "$WORK/psat"
            _prune_cache "$_sy_peer" "$_sy_repomap" "$WORK/psat"
        fi
    done < "$WORK/peerlist"
    unset _sy_cache _sy_repomap _sy_peer _sy_saved_cache _sy_n
}

_wipe() {
    echo "==> wiping *.xbps/*.sig2 from $1/"
    find "$1" -maxdepth 1 \( -name '*.xbps' -o -name '*.sig2' \) -delete 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_status() {
    _c=$(_cache_resolve)
    if [ -d "$_c" ]; then
        _n=$(find "$_c" -maxdepth 1 -name '*.xbps' 2>/dev/null | wc -l | tr -d ' ')
        _s=$(du -sh "$_c" 2>/dev/null | awk '{print $1}')
        _w=yes; [ -w "$_c" ] || _w=no
        echo "cache:    $_c"
        echo "arch:     $ARCH"
        echo "packages: $_n ($_s)"
        echo "writable: $_w"
        _peers "$_c" | while IFS= read -r _p; do
            [ -n "$_p" ] && echo "peer:     $_p"
        done
        [ "$_w" = no ] && echo "NOTE: not writable -- update/replace will fail." >&2
        echo "NOTE: 'update' refreshes the index AND the package payloads; 'index' refreshes the index only."
    else
        echo "no cache yet at $_c"
        echo "run '$0 update' to create it and refresh the repository index."
    fi
    unset _c _n _s _w _p
    return 0
}

cmd_update() {
    if [ "$DRY_RUN" = yes ]; then
        _have_xbps || _container_reexec
    else
        [ "$(id -u)" -eq 0 ] || die "update requires root (status and --dry-run work without)"
        _need_xbps
    fi
    _CACHE=$(_cache_resolve)
    if [ "$DRY_RUN" = yes ]; then
        [ -d "$_CACHE" ] || die "no cache at $_CACHE"
    else
        _ensure "$_CACHE"
    fi
    _XBPS_INSTALL=$(_xbps_install_bin)
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/xbps-cache-tool.XXXXXX")

    _repo_snapshot "$WORK" "$_CACHE"
    _scan_cache "$_CACHE" > "$WORK/cachepairs"
    cut -f1 "$WORK/cachepairs" | sort -u > "$WORK/cachenames"
    _satisfied_names "$WORK/repomap" "$WORK/cachepairs" > "$WORK/satisfied"
    _missing_names "$WORK/satisfied" "$WORK/cachenames" > "$WORK/missing_all"
    _unknown_names "$WORK/reponames" "$WORK/cachenames" > "$WORK/unknown"
    # Packages with no repo candidate cannot be downloaded; keep them untouched
    # instead of retrying them as if they were merely outdated.
    awk 'FILENAME==ARGV[1]{u[$1]=1; next} !($1 in u)' "$WORK/unknown" "$WORK/missing_all" > "$WORK/missing_known"
    _filter_downgrades "$WORK/repomap" "$WORK/cachepairs" \
        "$WORK/missing_known" "$WORK/kept_newer" "$WORK/missing_repo"
    _drop_skipped "$WORK/missing_repo" "$WORK/missing" "$WORK/skipped"

    _cached=$(wc -l < "$WORK/cachepairs" | tr -d ' ')
    _missing_n=$(wc -l < "$WORK/missing" | tr -d ' ')
    _unknown_n=$(wc -l < "$WORK/unknown" | tr -d ' ')
    _newer_n=$(wc -l < "$WORK/kept_newer" | tr -d ' ')
    _skipped_n=$(wc -l < "$WORK/skipped" | tr -d ' ')

    echo "==> cache: $_CACHE"
    echo "    cached package versions: $_cached"
    echo "    outdated:                $_missing_n"
    echo "    not in any repo (kept):  $_unknown_n"
    if [ "$_unknown_n" -gt 0 ]; then
        echo "    (configure the repo that provides them, or they stay untouched)"
        _show_list "$WORK/unknown" 10
    fi
    if [ "$_newer_n" -gt 0 ]; then
        echo "    newer than repo (kept):  $_newer_n"
        echo "    (pass --repo <url> for the repo that provides them, or they stay untouched)"
        _show_list "$WORK/kept_newer" 10
    fi
    if [ "$_skipped_n" -gt 0 ]; then
        echo "    skipped by --skip:       $_skipped_n"
        _show_list "$WORK/skipped" 10
    fi

    if [ "$DRY_RUN" = yes ]; then
        if [ "$_missing_n" -gt 0 ]; then
            echo "==> would download current versions of:"
            _show_list "$WORK/missing" 20
        else
            echo "==> all cached packages already match the repositories."
        fi
        echo "Dry run: nothing downloaded, nothing pruned."
        return 0
    fi

    if [ "$_missing_n" -gt 0 ]; then
        echo "==> downloading $_missing_n current package(s) ..."
        _prepare_scratch
        _download_bulk "$WORK/missing"
    fi

    if [ "$KEEP_OLD" != yes ]; then
        _scan_cache "$_CACHE" > "$WORK/cachepairs"
        _satisfied_names "$WORK/repomap" "$WORK/cachepairs" > "$WORK/satisfied"
        _prune_cache "$_CACHE" "$WORK/repomap" "$WORK/satisfied"
    fi

    _sync_peers "$_CACHE" "$WORK/repomap"

    if [ -n "$FAILED" ]; then
        _failed_list=$(printf '%s\n' $FAILED | sort -u | tr '\n' ' ')
        warn "these package(s) could not be downloaded: $_failed_list"
        warn "their existing cache entries were left in place."
        unset _failed_list
        return 1
    fi
    echo "update complete: $_CACHE"
}

cmd_index() {
    [ "$(id -u)" -eq 0 ] || die "index requires root (status works without)"
    _need_xbps
    _CACHE=$(_cache_resolve)
    _ensure "$_CACHE"
    _XBPS_INSTALL=$(_xbps_install_bin)
    echo "==> refreshing repository index for $_CACHE ..."
    "$_XBPS_INSTALL" -S -c "$_CACHE" >/dev/null 2>&1 \
        || die "index refresh failed (network/repo?)"
    echo "index refreshed (packages were not downloaded; run 'update' for that)."
}

cmd_replace() {
    [ "$(id -u)" -eq 0 ] || die "replace requires root (status works without)"
    _need_xbps
    _CACHE=$(_cache_resolve)
    _ensure "$_CACHE"
    _XBPS_INSTALL=$(_xbps_install_bin)
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/xbps-cache-tool.XXXXXX")

    _scan_cache "$_CACHE" > "$WORK/oldpairs"
    cut -f1 "$WORK/oldpairs" | sort -u > "$WORK/oldnames"
    _repo_snapshot "$WORK" "$_CACHE"

    if [ -n "$PKGS" ]; then
        printf '%s\n' "$PKGS" | tr ' ' '\n' | sed '/^$/d' | sort -u > "$WORK/names"
    else
        awk 'FILENAME==ARGV[1]{r[$1]=1; next} ($1 in r){print $1}' \
            "$WORK/reponames" "$WORK/oldnames" > "$WORK/names"
        _unknown_names "$WORK/reponames" "$WORK/oldnames" > "$WORK/unknown"
        _unknown_n=$(wc -l < "$WORK/unknown" | tr -d ' ')
        [ "$_unknown_n" -eq 0 ] || warn "$_unknown_n cached package(s) are not in any configured repo and will not be re-downloaded."
    fi

    _wipe "$_CACHE"
    _n=$(wc -l < "$WORK/names" | tr -d ' ')
    if [ "$_n" -eq 0 ]; then
        warn "nothing to re-download; the cache is now empty (pass --pkgs to populate it)."
        return 1
    fi
    echo "==> downloading current versions of $_n package(s) ..."
    _prepare_scratch
    _download_bulk "$WORK/names"
    _sync_peers "$_CACHE" "$WORK/repomap"

    if [ -n "$FAILED" ]; then
        _failed_list=$(printf '%s\n' $FAILED | sort -u | tr '\n' ' ')
        warn "these package(s) could not be downloaded: $_failed_list"
        unset _failed_list
        return 1
    fi
    echo "replace complete: $_CACHE"
}

cmd_download() {
    [ "$(id -u)" -eq 0 ] || die "download requires root (status works without)"
    [ -n "$PKGS" ] || die "download requires --pkgs '<pkg ...>'"
    _need_xbps
    _CACHE=$(_cache_resolve)
    _ensure "$_CACHE"
    _XBPS_INSTALL=$(_xbps_install_bin)
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/xbps-cache-tool.XXXXXX")

    _repo_snapshot "$WORK" "$_CACHE"
    printf '%s\n' "$PKGS" | tr ' ' '\n' | sed '/^$/d' | sort -u > "$WORK/names"
    echo "==> downloading $(wc -l < "$WORK/names" | tr -d ' ') requested package(s) ..."
    _prepare_scratch
    _download_bulk "$WORK/names"
    _sync_peers "$_CACHE" "$WORK/repomap"

    if [ -n "$FAILED" ]; then
        _failed_list=$(printf '%s\n' $FAILED | sort -u | tr '\n' ' ')
        warn "these package(s) could not be downloaded: $_failed_list"
        unset _failed_list
        return 1
    fi
    echo "download complete: $_CACHE"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [ "$#" -gt 0 ]; do
    case "$1" in
        status)            CMD=status; shift ;;
        update|upgrade)    CMD=update; shift ;;
        index|refresh)     CMD=index; shift ;;
        replace)           CMD=replace; shift ;;
        download)          CMD=download; shift ;;
        --cache)
            [ "$#" -ge 2 ] || die "--cache requires a directory"
            CACHE_DIR=$(readlink -f "$2" 2>/dev/null || printf '%s\n' "$2")
            shift 2
            ;;
        --cache=*) CACHE_DIR=$(readlink -f "${1#*=}" 2>/dev/null || printf '%s\n' "${1#*=}"); shift ;;
        --pkgs)
            [ "$#" -ge 2 ] || die "--pkgs requires a package list"
            PKGS=$2
            shift 2
            ;;
        --pkgs=*) PKGS=${1#*=}; shift ;;
        --repo)
            [ "$#" -ge 2 ] || die "--repo requires a URL"
            case "$2" in *[[:space:]]*) die "repository URL contains whitespace: $2" ;; esac
            EXTRA_REPOS="$EXTRA_REPOS $2"
            shift 2
            ;;
        --repo=*)
            case "${1#*=}" in *[[:space:]]*) die "repository URL contains whitespace: ${1#*=}" ;; esac
            EXTRA_REPOS="$EXTRA_REPOS ${1#*=}"
            shift
            ;;
        --skip)
            [ "$#" -ge 2 ] || die "--skip requires a package name"
            case "$2" in *[[:space:]]*) die "package name contains whitespace: $2" ;; esac
            SKIP_PKGS="$SKIP_PKGS $2"
            shift 2
            ;;
        --skip=*)
            case "${1#*=}" in *[[:space:]]*) die "package name contains whitespace: ${1#*=}" ;; esac
            SKIP_PKGS="$SKIP_PKGS ${1#*=}"
            shift
            ;;
        --dry-run|-n) DRY_RUN=yes; shift ;;
        --keep-old) KEEP_OLD=yes; shift ;;
        -h|--help) usage ;;
        *) die "unknown argument: $1 (try --help)" ;;
    esac
done

[ -n "$CMD" ] || usage

for _repo in $EXTRA_REPOS; do
    REPO_INSTALL_ARGS="$REPO_INSTALL_ARGS -R $_repo"
    REPO_QUERY_ARGS="$REPO_QUERY_ARGS --repository $_repo"
done
unset _repo

case "$CMD" in
    status)   cmd_status ;;
    update)   cmd_update ;;
    index)    cmd_index ;;
    replace)  cmd_replace ;;
    download) cmd_download ;;
esac
