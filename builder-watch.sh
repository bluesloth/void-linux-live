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
# The build command is rebuilt from BUILD_CMD; if unset, builder-watch detects the
# running mkiso.sh/mklive.sh process and restarts with the same flags.

BD="$(cd "$(dirname "$0")" && pwd -P)"
LOG="$BD/build.log"
STATUS="$BD/build.status"
STALL_SECS=180
MIRRORS="https://mirrors.summithq.com/voidlinux/current https://repo-fastly.voidlinux.org/current https://repo-default.voidlinux.org/current"

# Resolve the tethered NIC from the default route so a USB-port change
# (enp5s0f4u1 -> enp5s0f4u2) or even another controller never breaks the toggle.
tether() {
    _tgw=$(ip route show default 2>/dev/null | awk '/via/ {print $3; exit}')
    [ -z "$_tgw" ] && return 1
    ip route get "$_tgw" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}'
    unset _tgw
}

# Snapshot the currently-running mkiso/mklive command line (full argv) so we can
# restart it with the same flags.  Returns nothing if no build is running.
detect_build_cmd() {
    _mkiso_pid=$(pgrep -f 'mk[i]so\.sh' 2>/dev/null | head -1) || true
    [ -n "$_mkiso_pid" ] || return 1
    # /proc/<pid>/cmdline is NUL-separated; convert to spaces.
    sudo tr '\0' ' ' < /proc/"$_mkiso_pid"/cmdline 2>/dev/null || return 1
    unset _mkiso_pid
}

say() { printf '%s | %s\n' "$(date +%H:%M:%S)" "$*" >> "$STATUS"; }

# ── main loop ──────────────────────────────────────────────────────────────

say "builder-watch started (bd=$BD stall=${STALL_SECS}s)"
ROUND=0

while true; do
    sleep 60

    procs=$(pgrep -cf 'mk[i]so\.sh|mkl[i]ve\.sh' 2>/dev/null || echo 0)
    newest=$(ls -t "$BD"/xbps-cachedir-x86_64/*.part 2>/dev/null | head -1)
    dl=""
    [ -n "$newest" ] && dl=$(basename "$newest")
    cache=$(du -sm "$BD"/xbps-cachedir-x86_64 2>/dev/null | cut -f1)
    iso=$(ls "$BD"/void-live-x86_64-*.iso 2>/dev/null | wc -l)

    say "tick: procs=$procs dl=${dl:-none} cache=${cache}MB iso=$iso"

    # Only judge liveness by in-flight downloads: .part files get mtime
    # updates as writes happen.  Repo-sync / cache-only steps write nothing
    # here, so ignore them and never false-stall on those.
    if [ -n "$newest" ] && [ "$procs" -gt 0 ] && [ "$iso" = "0" ]; then
        mtime=$(stat -c %Y "$newest" 2>/dev/null) || mtime=$(date +%s)
        age=$(( $(date +%s) - mtime ))
        if [ "$age" -gt "$STALL_SECS" ]; then
            TETHER="$(tether)"
            say "STALL detected (${age}s, $dl) -> toggling $TETHER"

            # ── kill stalled build tree ──────────────────────────────────
            pids=$(pgrep -f 'mkl[i]ve\.sh|mk[i]so\.sh|xbp[s]-install' | tr '\n' ' ')
            say "killing: $pids"
            sudo kill -9 $pids 2>/dev/null
            sleep 3

            # ── toggle tether NIC ────────────────────────────────────────
            [ -n "$TETHER" ] && sudo nmcli device disconnect "$TETHER" 2>/dev/null
            sleep 4
            [ -n "$TETHER" ] && sudo nmcli device connect "$TETHER" 2>/dev/null
            ok=0
            for n in $(seq 1 15); do
                if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then ok=1; break; fi
                sleep 2
            done
            [ "$ok" = "1" ] && say "internet OK" || say "WARN: no internet after toggle"

            # ── clean up stale mklive build dirs ─────────────────────────
            for bd in "$BD"/mklive-build.*; do
                [ -d "$bd" ] || continue
                sudo umount -R "$bd/image/rootfs/sys" "$bd/image/rootfs/dev" \
                                  "$bd/image/rootfs/proc" 2>/dev/null
                sudo rm -rf "$bd"
            done
            sleep 3

            # ── restart build ────────────────────────────────────────────
            ROUND=$((ROUND + 1))
            say "=== HEAL #$ROUND ==="
            if [ -n "${BUILD_CMD:-}" ]; then
                say "restarting: $BUILD_CMD"
                setsid nohup sudo bash -c "$BUILD_CMD" > "$LOG" 2>&1 < /dev/null &
            elif _cmd=$(detect_build_cmd); then
                say "restarting (detected): $_cmd"
                setsid nohup sudo bash -c "$_cmd" > "$LOG" 2>&1 < /dev/null &
            else
                say "WARN: no build command found or configured; cannot restart"
            fi
            unset _cmd
        fi
    fi
done
