#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

USERNAME=$(getarg live.user)
[ -z "$USERNAME" ] && USERNAME=anon

# Configure GDM autologin
if [ -d ${NEWROOT}/etc/gdm ]; then
    GDMCustomFile=${NEWROOT}/etc/gdm/custom.conf
    AutologinParameters="AutomaticLoginEnable=true\nAutomaticLogin=$USERNAME"

    # Prevent from updating if parameters already present (persistent usb key)
    if ! `grep -qs 'AutomaticLoginEnable' $GDMCustomFile` ; then
        if ! `grep -qs '\[daemon\]' $GDMCustomFile` ; then
            echo '[daemon]' >> $GDMCustomFile
        fi
        sed -i "s/\[daemon\]/\[daemon\]\n$AutologinParameters/" $GDMCustomFile
    fi
fi

# Configure sddm autologin.  KDE's plasma.desktop is the historical default,
# but the live image records the built desktop's real session at build time
# (mkiso.sh writes /etc/voidlive-sddm-session).  Without that, an LXQt
# (or any -g sddm) image hardcoded plasma.desktop, autologin failed, and the
# user was dropped at the greeter.  Fall back to plasma.desktop and validate
# the recorded session exists so a stale marker can't break the login.
if [ -x ${NEWROOT}/usr/bin/sddm ]; then
    _sddm_session=plasma.desktop
    if [ -r "${NEWROOT}/etc/voidlive-sddm-session" ]; then
        _sddm_session="$(cat "${NEWROOT}/etc/voidlive-sddm-session")"
    fi
    if [ ! -f "${NEWROOT}/usr/share/wayland-sessions/${_sddm_session}" ] && \
       [ ! -f "${NEWROOT}/usr/share/xsessions/${_sddm_session}" ]; then
        _sddm_session=plasma.desktop
    fi
    cat > ${NEWROOT}/etc/sddm.conf <<_EOF
[Autologin]
User=${USERNAME}
Session=${_sddm_session}
_EOF
    unset _sddm_session
fi

# Configure greetd / cosmic-greeter autologin.  greetd has no autologin of its
# own; its documented mechanism is an [initial_session] block, which starts the
# session directly as the live user and falls through to the greeter
# (default_session) on logout.  Without this a cosmic-greeter image stops at the
# login screen: greetd is not SDDM, so the sddm block above never fires.  The
# session command is derived from the installed cosmic session .desktop rather
# than hardcoded, mirroring how the sddm block reads the recorded session.
# Idempotent for the persistent overlay, and self-healing: a block written by
# an older image (before `head` was installed in the initrd, which made the
# Exec= derivation return empty and fall back to the bare `cosmic-session`
# path) is corrected in place to the derived command/user rather than left
# wrong.  HARDWARE-TEST REQUIRED — a greetd session launch is the same code
# path a normal cosmic-greeter login uses, so a manual login working implies
# the autologin does too; confirm on a real boot.
_greetd_conf="${NEWROOT}/etc/greetd/cosmic-greeter.toml"
if [ -x "${NEWROOT}/usr/bin/greetd" ] && [ -r "$_greetd_conf" ]; then
    _gd_session="cosmic-session"
    for _gd_desktop in "${NEWROOT}"/usr/share/wayland-sessions/cosmic*.desktop; do
        [ -r "$_gd_desktop" ] || continue
        _gd_exec="$(sed -n 's/^Exec=//p' "$_gd_desktop" | head -1)"
        _gd_exec="${_gd_exec%% *}"   # drop any field code after the command
        [ -n "$_gd_exec" ] && _gd_session="$_gd_exec"
        break
    done
    case "$_gd_session" in
        /*) ;;
        *) _gd_session="/usr/bin/$_gd_session" ;;
    esac
    if grep -q '^\[initial_session\]' "$_greetd_conf"; then
        # Self-heal a block written by an older image.  Restrict the edit to
        # the [initial_session] section so the [default_session] command is
        # never touched; the section is appended last, so an unmatched range
        # end simply runs to EOF.
        sed -i "/^\[initial_session\]/,/^\[/{
            s|^command = .*|command = \"$_gd_session\"|
            s|^user = .*|user = \"$USERNAME\"|
        }" "$_greetd_conf"
    else
        {
            echo ''
            echo '[initial_session]'
            echo "command = \"$_gd_session\""
            echo "user = \"$USERNAME\""
        } >> "$_greetd_conf"
    fi
    unset _gd_session _gd_desktop _gd_exec
fi
unset _greetd_conf

# Configure lightdm autologin.
if [ -r "${NEWROOT}/etc/lightdm/lightdm.conf" ]; then
    sed -i -e "s|^\#\(autologin-user=\).*|\1$USERNAME|" \
        "${NEWROOT}/etc/lightdm/lightdm.conf"
    sed -i -e "s|^\#\(autologin-user-timeout=\).*|\10|" \
        "${NEWROOT}/etc/lightdm/lightdm.conf"
    sed -i -e "s|^\#\(autologin-session=\).*|\1$(cat "${NEWROOT}/etc/lightdm/.session")|" \
        "${NEWROOT}/etc/lightdm/lightdm.conf"
    sed -i -e "s|^\#\(user-session=\).*|\1$(cat "${NEWROOT}/etc/lightdm/.session")|" \
        "${NEWROOT}/etc/lightdm/lightdm.conf"
fi

# Configure lxdm autologin.
if [ -r ${NEWROOT}/etc/lxdm/lxdm.conf ]; then
    sed -e "s,.*autologin.*=.*,autologin=$USERNAME," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    if [ -x ${NEWROOT}/usr/bin/enlightenment_start ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/enlightenment_start," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/startxfce4 ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/startxfce4," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/mate-session ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/mate-session," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/cinnamon-session ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/cinnamon-session," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/i3 ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/i3," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/startlxde ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/startlxde," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/startlxqt ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/startlxqt," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    elif [ -x ${NEWROOT}/usr/bin/startfluxbox ]; then
        sed -e "s,.*session.*=.*,session=/usr/bin/startfluxbox," -i ${NEWROOT}/etc/lxdm/lxdm.conf
    fi
fi
