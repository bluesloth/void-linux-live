#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Wait for the rd.overlay=... device to become resolvable BEFORE the
# dmsquash-live mount hook attaches the persistent overlay.
#
# Why: dmsquash-live (70dmsquash-live/dmsquash-live-root.sh) mounts the
# overlay with `mount -n -t auto "$devspec" /run/initramfs/overlayfs || :`
# and never waits for that device.  The overlay partition is discovered via
# udev's by-label/by-uuid symlinks (60-persistent-storage.rules), so if the
# mount stage runs before udev surfaces that partition -- a real race on
# some USB/firmware paths (e.g. the GRUB fallback boot of a hybrid ISO,
# while the Limine removable-media path normally wins the race) -- the
# mount fails, dracut falls back to a temporary RAM overlay, and all
# persistence is silently lost for that boot.
#
# This pre-mount hook polls for the overlay device (by-label, by-uuid, or a
# plain block path) with a bounded timeout, then yields to the mount stage.
# RAM-mode boots (rd.live.ram) and boots without rd.overlay are untouched.
#
# NB: dracut sources hooks into the /init shell (`source_hook` does
# `. "$f"`), so a hook MUST use `return`, never `exit`.  A stray `exit 0`
# here terminates /init, which fires dracut's `trap ... 0` and drops straight
# to the emergency debug shell ("Signal caught!") on every boot.
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

# dmsquash-live sources this for get_rd_overlay(); mirror that so we honour
# the deprecated rd.live.overlay spelling too.
command -v get_rd_overlay >/dev/null 2>&1 || . /lib/overlayfs-lib.sh

# RAM-mode live boots intentionally skip the persistent overlay.
getargbool 0 rd.live.ram && return 0

overlay=$(get_rd_overlay) || overlay="$(getarg rd.overlay)"
case "$overlay" in
    ""|0|no|off|1) return 0 ;;
esac

# devspec is everything before an optional ':path' suffix.
spec=${overlay%%:*}
[ -n "$spec" ] || return 0

max=${OVERLAY_WAIT_SECS:-15}
n=0
while [ "$n" -lt "$max" ]; do
    found=
    case "$spec" in
        LABEL=*)
            [ -e "/dev/disk/by-label/${spec#LABEL=}" ] && found=1
            ;;
        UUID=*)
            [ -e "/dev/disk/by-uuid/${spec#UUID=}" ] && found=1
            ;;
        /dev/*)
            [ -b "$spec" ] && found=1
            ;;
    esac
    # blkid fallback catches the case where udev symlinks lag behind.
    [ -z "$found" ] && [ -x /sbin/blkid ] && blkid -l -t "$spec" >/dev/null 2>&1 && found=1

    if [ -n "$found" ]; then
        udevadm settle >/dev/null 2>&1
        info "Persistent overlay device $spec is ready."
        return 0
    fi
    udevadm settle --timeout=1 >/dev/null 2>&1 || udevadm settle >/dev/null 2>&1
    n=$((n + 1))
    [ "$n" -lt "$max" ] && sleep 1
done
warn "Persistent overlay device $spec not found after ${max}s; booting without a persistent overlay."
return 0