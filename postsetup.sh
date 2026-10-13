#!/bin/sh
set -eu

# Called by mklive.sh (-x) after packages are installed into the rootfs and
# before the initramfs/squashfs are generated. Argument $1 is the ROOTFS path.
# The live image uses nftables; keep the iptables package installed so xbps
# dependencies stay satisfied, but unlink the binaries so it lies dormant and
# only nftables is actually usable.

ROOTFS="${1:?usage: postsetup.sh <rootfs-path>}"

for f in iptables iptables-restore iptables-save ip6tables ip6tables-restore ip6tables-save; do
    rm -f "$ROOTFS/usr/sbin/$f" "$ROOTFS/usr/bin/$f"
done

echo "=> unlinked iptables binaries (nftables is active)"

# ---------------------------------------------------------------------------
# Desktop-environment extras that need the installed package files.
#
# mkiso.sh exports VOIDLIVE_DE / VOIDLIVE_DM for the variant being built and
# already drops the static DE files (the supervised udisksd service, COSMIC's
# xkb_config and its polkit/udiskie autostart guards) into the include dir.
# A few fixes operate on files that only exist once the desktop packages are
# installed, so they run here (mirrors void-installer's Stage-2 Cinnamon gate).
# No-op when VOIDLIVE_DE is unset (e.g. a bare mklive.sh invocation).
# ---------------------------------------------------------------------------
if [ -n "${VOIDLIVE_DE:-}" ]; then
    case "$VOIDLIVE_DE" in
        cinnamon)
            # [CINNAMON-DBUS] prepend dbus-run-session to every Cinnamon
            # session Exec= (X11 black-screen class; void-packages#21766).
            # Skip anything already wrapped so a future package fix isn't
            # double-wrapped.
            for _sess in "$ROOTFS"/usr/share/xsessions/*.desktop \
                         "$ROOTFS"/usr/share/wayland-sessions/*.desktop; do
                [ -f "$_sess" ] || continue
                case "$(basename "$_sess")" in
                    *cinnamon*)
                        if grep -q '^Exec=' "$_sess" && ! grep -q '^Exec=dbus-run-session' "$_sess"; then
                            sed -i -E 's|^Exec=(.*)|Exec=dbus-run-session -- \1|' "$_sess"
                        fi
                        ;;
                esac
            done

            # [CINNAMON-WALLPAPER] Cinnamon ships no backgrounds of its own and
            # its compiled-in default points at a non-existent Mint path, so a
            # fresh login is a solid black screen.  Prefer GNOME's adwaita-l and
            # record it in the system dconf db (fall back to any image).
            _bg=""
            for _name in adwaita-l.jpg adwaita-l.jxl adwaita-l.png adwaita-l.svg; do
                _bg="$(find "$ROOTFS/usr/share/backgrounds" -maxdepth 2 -type f \
                    -name "$_name" 2>/dev/null | head -1)" || true
                [ -n "$_bg" ] && break
            done
            if [ -z "$_bg" ]; then
                _bg="$(find "$ROOTFS/usr/share/backgrounds" -maxdepth 2 -type f \
                    \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
                       -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
                    2>/dev/null | head -1)" || true
            fi
            if [ -n "$_bg" ]; then
                _bg="${_bg#"$ROOTFS"}"
                mkdir -p "$ROOTFS/etc/dconf/profile" "$ROOTFS/etc/dconf/db/local.d"
                cat > "$ROOTFS/etc/dconf/profile/user" << 'EOF'
user-db:user
system-db:local
EOF
                cat > "$ROOTFS/etc/dconf/db/local.d/01-cinnamon-wallpaper" << EOF
[org/cinnamon/desktop/background]
picture-uri='file://${_bg}'
picture-options='zoom'
EOF
                if [ -x "$ROOTFS/usr/bin/dconf" ]; then
                    chroot "$ROOTFS" dconf update >/dev/null 2>&1 || \
                        echo "WARNING: dconf update failed (Cinnamon wallpaper may be unset)"
                fi
            fi

            # [GNOME-TERMINAL-FONT] the reported wide letter/number spacing is
            # fixed by "Monospace 12"; override the schema default so any
            # not-yet-customised terminal profile picks it up.
            mkdir -p "$ROOTFS/usr/share/glib-2.0/schemas"
            cat > "$ROOTFS/usr/share/glib-2.0/schemas/zz-void-installer-cinnamon.gschema.override" << 'EOF'
[org.gnome.Terminal.Legacy.Profile]
font='Monospace 12'
use-system-font=false
EOF
            if [ -x "$ROOTFS/usr/bin/glib-compile-schemas" ]; then
                chroot "$ROOTFS" glib-compile-schemas /usr/share/glib-2.0/schemas/ >/dev/null 2>&1 || \
                    echo "WARNING: glib-compile-schemas failed (terminal font override ignored)"
            fi
            echo "=> applied Cinnamon desktop extras"
            ;;
    esac

    # [LIGHTDM-GREETER-BG] Point the LightDM greeter at a real wallpaper so the
    # login screen isn't a solid black rectangle (the GTK and Slick greeters
    # read background= from /usr/share/backgrounds).  mkiso.sh pulls
    # gnome-backgrounds for every LightDM image so a source always exists;
    # mirror void-installer's search here (prefer GNOME's adwaita-l stripe,
    # then any image — mate-backgrounds ships its set at depth 3+).
    if [ "${VOIDLIVE_DM:-}" = lightdm ]; then
        _bg=""
        for _name in adwaita-l.jpg adwaita-l.jxl adwaita-l.png adwaita-l.svg; do
            _bg="$(find "$ROOTFS/usr/share/backgrounds" -maxdepth 2 -type f \
                -name "$_name" 2>/dev/null | head -1)" || true
            [ -n "$_bg" ] && break
        done
        if [ -z "$_bg" ]; then
            _bg="$(find "$ROOTFS/usr/share/backgrounds" -maxdepth 5 -type f \
                \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
                   -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
                2>/dev/null | head -1)" || true
        fi
        if [ -n "$_bg" ]; then
            _bg="${_bg#"$ROOTFS"}"
            mkdir -p "$ROOTFS/etc/lightdm"
            if [ "${VOIDLIVE_LIGHTDM:-gtk}" = slick ]; then
                # slick-greeter does NOT strip quotes from values — a quoted
                # background="path" opens the literal quoted filename, fails,
                # and falls back to #000000.  Write it UNQUOTED.
                printf '[Greeter]\nbackground=%s\n' "$_bg" \
                    > "$ROOTFS/etc/lightdm/slick-greeter.conf"
            else
                # lightdm-gtk-greeter DOES strip quotes.  Append into the
                # [greeter] section mkiso.sh already wrote (which carries the
                # keyboard-layout indicators) rather than clobbering it.
                _cfg="$ROOTFS/etc/lightdm/lightdm-gtk-greeter.conf"
                if [ -f "$_cfg" ]; then
                    grep -q '^background=' "$_cfg" || printf 'background="%s"\n' "$_bg" >> "$_cfg"
                else
                    printf '[greeter]\nbackground="%s"\n' "$_bg" > "$_cfg"
                fi
            fi
            echo "=> set LightDM greeter background to $_bg"
        fi
        unset _bg _name _cfg
    fi
fi
