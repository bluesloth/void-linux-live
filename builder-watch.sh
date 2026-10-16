#!/bin/sh
# Background live-build watchdog: pings build.status every 60s and auto-heals
# network stalls on a USB-tethered link by toggling the NIC and restarting the
# ISO build.  Designed for use with voidlive-build-persist.sh (which wraps
# mkiso.sh -> mklive.sh).
#
# Usage (from the Void_Linux_Live folder):
#   export BUILD_CMD="./voidlive-build-persist.sh build --persist --both --cache ./xbps-cachedir-x86_64 --flash /dev/sdX"
#   sudo nohup ./builder-watch.sh >/dev/null 2>&1 &
#
#   ...or let the build start it for you:  build --watch
#   (voidlive-build-persist.sh then supplies BUILD_CMD; see its _start_watch).
#
# The restart command is taken from BUILD_CMD; if unset, builder-watch
# snapshots the running mkiso.sh argv BEFORE killing it.  Prefer BUILD_CMD for
# a wrapper-driven build: a bare mkiso restart drops the persist wrapper's
# environment (PERSISTENT_OVERLAY) and its flash step.
#
# Single instance: the watcher holds a pidfile lock, so a restarted build can
# never spawn a second watcher.
#
# Environment knobs:
#   BUILDER_WATCH_STALL_SECS   seconds with no build progress before a heal
#                              (default 180).  "Progress" is the newest *.part
#                              mtime, the cache size, or the build tree's CPU
#                              time advancing, so a stall is caught whether or
#                              not a download happens to be mid-flight, while a
#                              long CPU-bound step never false-stalls.
#   BUILDER_WATCH_RESTART_ON_DEATH  yes (default) | no
#                              restart the build when it dies without producing
#                              an ISO (e.g. xbps gave up on a dead link), rather
#                              than idling forever.  Bounded by MAX_HEALS.
#   BUILDER_WATCH_MAX_HEALS    maximum automatic heal/restart rounds (default 12)
#   BUILDER_WATCH_TOGGLE_NIC   auto (default) | yes | no
#                              'auto' declines to toggle the uplink when this is
#                              a remote (SSH) session, since the tether may be
#                              the only way back into the machine.
#   BUILD_CMD                  explicit restart command (see above)

BD="$(cd "$(dirname "$0")" && pwd -P)"
LOG="$BD/build.log"
STATUS="$BD/build.status"
LOCK="$BD/.builder-watch.pid"
STALL_SECS="${BUILDER_WATCH_STALL_SECS:-180}"
TOGGLE_MODE="${BUILDER_WATCH_TOGGLE_NIC:-auto}"
RESTART_ON_DEATH="${BUILDER_WATCH_RESTART_ON_DEATH:-yes}"
MAX_HEALS="${BUILDER_WATCH_MAX_HEALS:-12}"
MIRRORS="https://mirrors.summithq.com/voidlinux/current https://repo-fastly.voidlinux.org/current https://repo-default.voidlinux.org/current"

# Single-instance lock: a second watcher (a --watch restart, or a human
# launching it twice) must not produce duelling watchdogs.
if [ -f "$LOCK" ]; then
    _old=$(cat "$LOCK" 2>/dev/null || true)
    if [ -n "$_old" ] && kill -0 "$_old" 2>/dev/null; then
        printf 'builder-watch: already running (pid %s); exiting\n' "$_old" >&2
        exit 0
    fi
fi
printf '%s\n' "$$" > "$LOCK"
# Remove the lock AND exit: a trapped signal must not resume the loop (which
# would leave the watcher running with no lock, letting a second one start).
trap 'rm -f "$LOCK"; exit 0' EXIT INT TERM HUP
unset _old

# Resolve the tethered NIC from the default route so a USB-port change
# (enp5s0f4u1 -> enp5s0f4u2) or even another controller never breaks the toggle.
tether() {
    _tgw=$(ip route show default 2>/dev/null | awk '/via/ {print $3; exit}')
    [ -z "$_tgw" ] && return 1
    ip route get "$_tgw" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}'
    unset _tgw
}

# Is toggling the uplink acceptable right now?
toggle_allowed() {
    case "$TOGGLE_MODE" in
        no)  return 1 ;;
        yes) return 0 ;;
        auto)
            # A remote session may be riding this exact link; dropping it could
            # lock the operator out with no way back in.
            [ -z "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ] ;;
        *) return 1 ;;
    esac
}

# Snapshot the currently-running mkiso command line (full argv) so we can
# restart it with the same flags.  Returns nothing if no build is running.
detect_build_cmd() {
    _mkiso_pid=$(pgrep -f 'mk[i]so\.sh' 2>/dev/null | head -1) || true
    [ -n "$_mkiso_pid" ] || return 1
    # /proc/<pid>/cmdline is NUL-separated; convert to spaces.
    if [ "$(id -u)" = 0 ]; then
        tr '\0' ' ' < /proc/"$_mkiso_pid"/cmdline 2>/dev/null || return 1
    else
        sudo tr '\0' ' ' < /proc/"$_mkiso_pid"/cmdline 2>/dev/null || return 1
    fi
    unset _mkiso_pid
}

# kill_tree <pid>: kill <pid> and all of its descendants, depth-first.  Scoping
# the kill to the build's own tree (rather than a host-wide pgrep for every
# xbps-install) keeps a heal from touching unrelated work on the machine.
#
# Never kill $$ (this watcher): with `build --watch` and no --flash the wrapper
# forks the watcher and then `exec`s mkiso.sh, so the watcher is a CHILD of the
# mkiso root.  A naive tree kill would recurse into the watcher and kill -9 it
# before finishing the heal, leaving the build alive and unhealed.  Skipping $$
# protects the watcher and, because we return before recursing, its whole
# subtree too; when the build root is later killed the watcher is reparented to
# init and the heal proceeds.
kill_tree() {
    [ "$1" = "$$" ] && return 0
    for _kt_kid in $(pgrep -P "$1" 2>/dev/null || true); do
        kill_tree "$_kt_kid"
    done
    kill -9 "$1" 2>/dev/null || true
}

# tree_pids <pid>: <pid> plus every descendant, one per line.
tree_pids() {
    printf '%s\n' "$1"
    for _tp_kid in $(pgrep -P "$1" 2>/dev/null || true); do
        tree_pids "$_tp_kid"
    done
}

# tree_cpu <pid>: cumulative CPU jiffies (utime+stime) of <pid>'s whole tree.
# This is the phase-independent liveness signal for CPU-bound build steps
# (unpack / configure / squashfs / xorriso) that touch neither the XBPS cache
# nor a *.part file -- the exact window in which the old detector went blind.
tree_cpu() {
    _tc_sum=0
    for _tc_p in $(tree_pids "$1"); do
        _tc_v=$(awk '{ sub(/.*\) /, ""); print $12 + $13 }' "/proc/$_tc_p/stat" 2>/dev/null)
        [ -n "$_tc_v" ] && _tc_sum=$(( _tc_sum + _tc_v ))
    done
    printf '%s\n' "$_tc_sum"
    unset _tc_sum _tc_v _tc_p
}

say() { printf '%s | %s\n' "$(date +%H:%M:%S)" "$*" >> "$STATUS"; }

# ── main loop ──────────────────────────────────────────────────────────────

say "builder-watch started (bd=$BD stall=${STALL_SECS}s toggle=$TOGGLE_MODE restart_on_death=$RESTART_ON_DEATH max_heals=$MAX_HEALS pid=$$)"
ROUND=0
LAST_PM=
LAST_CKB=
LAST_CPU=
LAST_PROGRESS=
SEEN_RUNNING=0
DEAD_TICKS=0

while true; do
    sleep 60

    # NB: `pgrep -c` already prints 0 when nothing matches (and then exits 1);
    # the old `|| echo 0` appended a second "0", making $procs "0\n0" and
    # tripping the -gt test below with an "integer expression expected" error.
    procs=$(pgrep -cf 'mk[i]so\.sh|mkl[i]ve\.sh' 2>/dev/null)
    procs=${procs:-0}
    newest=$(ls -t "$BD"/xbps-cachedir-x86_64/*.part 2>/dev/null | head -1)
    dl=""
    [ -n "$newest" ] && dl=$(basename "$newest")
    cache_kb=$(du -sk "$BD"/xbps-cachedir-x86_64 2>/dev/null | cut -f1)
    cache_kb=${cache_kb:-0}
    iso=$(ls "$BD"/void-live-x86_64-*.iso 2>/dev/null | wc -l)
    now=$(date +%s)

    # Liveness: any ONE of three signals advancing means the build is still
    # making progress, in any phase --
    #   * the newest *.part mtime   (a download is actively being written),
    #   * the cache size            (downloads completing / repo sync),
    #   * the build tree's CPU time (unpack / configure / squashfs / xorriso).
    # This closes the old blind spot: xbps wedged with no *.part on disk (cache
    # frozen, CPU idle) now reads as a stall instead of being ignored, while a
    # long CPU-bound step still cannot false-stall.
    pm=""
    [ -n "$newest" ] && pm=$(stat -c %Y "$newest" 2>/dev/null)
    cpu=0
    if [ "$procs" -gt 0 ]; then
        _root=$(pgrep -f 'mk[i]so\.sh' 2>/dev/null | head -1)
        [ -n "$_root" ] || _root=$(pgrep -f 'mkl[i]ve\.sh' 2>/dev/null | head -1)
        [ -n "$_root" ] && cpu=$(tree_cpu "$_root")
    fi

    changed=0
    [ "$pm" != "$LAST_PM" ] && changed=1
    [ "$cache_kb" != "$LAST_CKB" ] && changed=1
    [ "$cpu" != "$LAST_CPU" ] && changed=1
    LAST_PM="$pm"
    LAST_CKB="$cache_kb"
    LAST_CPU="$cpu"

    say "tick: procs=$procs dl=${dl:-none} cache=$(( cache_kb / 1024 ))MB iso=$iso cpu=$cpu"

    [ "$procs" -gt 0 ] && { SEEN_RUNNING=1; DEAD_TICKS=0; }

    # A build that finished leaves an ISO behind with nothing running: stop, so
    # the pidfile lock is released instead of idling and blocking a later
    # --watch run.  Guarded by SEEN_RUNNING so a pre-existing ISO at startup
    # cannot make us exit before the build even begins.
    if [ "$SEEN_RUNNING" = "1" ] && [ "$procs" = "0" ] && [ "$iso" -gt "0" ]; then
        say "build complete (ISO present); watcher exiting"
        exit 0
    fi

    # ── decide whether to heal ───────────────────────────────────────────
    heal_reason=""
    if [ "$procs" -gt 0 ] && [ "$iso" = "0" ]; then
        if [ "$changed" = "1" ] || [ -z "$LAST_PROGRESS" ]; then
            LAST_PROGRESS=$now
        fi
        age=$(( now - LAST_PROGRESS ))
        if [ "$age" -gt "$STALL_SECS" ]; then
            heal_reason="STALL (no progress for ${age}s)"
        fi
    elif [ "$procs" = "0" ] && [ "$iso" = "0" ] && [ "$SEEN_RUNNING" = "1" ] \
         && [ "$RESTART_ON_DEATH" != "no" ]; then
        DEAD_TICKS=$(( DEAD_TICKS + 1 ))
        [ "$DEAD_TICKS" -ge 2 ] && heal_reason="BUILD DIED without an ISO"
    fi

    [ -n "$heal_reason" ] || continue

    if [ "$ROUND" -ge "$MAX_HEALS" ]; then
        say "$heal_reason -> heal limit ($MAX_HEALS) reached; watcher stopping"
        exit 0
    fi

    TETHER="$(tether)"
    say "$heal_reason -> heal (tether=${TETHER:-none})"

    # ── snapshot the build cmd BEFORE killing it ─────────────────────────
    # (after the kill, /proc/<pid>/cmdline is gone)
    _cmd=$(detect_build_cmd || true)

    # ── kill the stalled build tree ──────────────────────────────────────
    pids=$(pgrep -f 'mkl[i]ve\.sh|mk[i]so\.sh' 2>/dev/null | tr '\n' ' ')
    [ -n "$pids" ] && say "killing build tree: $pids"
    for _bp in $pids; do kill_tree "$_bp"; done
    sleep 3

    # ── toggle tether NIC ────────────────────────────────────────────────
    if toggle_allowed; then
        [ -n "$TETHER" ] && say "toggling $TETHER"
        [ -n "$TETHER" ] && sudo nmcli device disconnect "$TETHER" 2>/dev/null
        sleep 4
        [ -n "$TETHER" ] && sudo nmcli device connect "$TETHER" 2>/dev/null
    else
        say "NOTICE: NIC toggle skipped (BUILDER_WATCH_TOGGLE_NIC=$TOGGLE_MODE${SSH_CONNECTION:+; remote session})"
    fi
    ok=0
    for n in $(seq 1 15); do
        if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then ok=1; break; fi
        sleep 2
    done
    [ "$ok" = "1" ] && say "internet OK" || say "WARN: no internet after heal"

    # ── clean up stale mklive build dirs ─────────────────────────────────
    for bd in "$BD"/mklive-build.*; do
        [ -d "$bd" ] || continue
        sudo umount -R "$bd/image/rootfs/sys" "$bd/image/rootfs/dev" \
                          "$bd/image/rootfs/proc" 2>/dev/null
        sudo rm -rf "$bd"
    done
    sleep 3

    # ── restart build ────────────────────────────────────────────────────
    # Prefer BUILD_CMD (set by 'build --watch', which pins the exact wrapper
    # invocation + the VLBP_WATCHED recursion guard); fall back to the argv
    # snapshotted above.  Append to the log so a heal never destroys the
    # evidence from the run that stalled.
    ROUND=$((ROUND + 1))
    SEEN_RUNNING=0
    DEAD_TICKS=0
    LAST_PROGRESS=
    say "=== HEAL #$ROUND ==="
    _rc="${BUILD_CMD:-$_cmd}"
    if [ -n "$_rc" ]; then
        say "restarting: $_rc"
        printf '\n=== builder-watch HEAL #%s %s ===\nrestarting: %s\n' \
            "$ROUND" "$(date '+%F %T')" "$_rc" >> "$LOG"
        setsid nohup sudo bash -c "$_rc" >> "$LOG" 2>&1 < /dev/null &
    else
        say "WARN: no build command found or configured; cannot restart"
        exit 0
    fi
    unset _cmd _rc
done
