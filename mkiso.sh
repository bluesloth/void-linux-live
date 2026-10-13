#!/bin/bash

set -eu

. ./lib.sh

PROGNAME=$(basename "$0")
ARCH=$(uname -m)
IMAGES="base"
TRIPLET=
REPO=
GREETER=
DATE=$(date -u +%Y%m%d)

usage() {
	cat <<-EOH
	Usage: $PROGNAME [options ...] [-- mklive options ...]

	Wrapper script around mklive.sh for several standard flavors of live images.
	Adds void-installer and other helpful utilities to the generated images.

	OPTIONS
	 -a <arch>     Set architecture (or platform) in the image
	 -b <variant>  One of base, none, enlightenment, xfce, mate, cinnamon, gnome,
	               kde, lxde, lxqt, xfce-wayland, or cosmic (default: base). May be
	               specified multiple times to build multiple variants
	 -g <greeter>  Display manager / greeter: auto (default — the desktop's
	               recommended DM, matching void-installer), sddm, gdm, lightdm,
	               lightdm-gtk, lightdm-slick, cosmic-greeter, or none
	 -B <bootloader>
	               EFI bootloader choice: grub, limine, or both (default: both
	               on x86 -- Limine first, then grub; grub on aarch64). BIOS
	               always uses syslinux
	 -d <date>     Override the datestamp on the generated image (YYYYMMDD format)
	 -t <arch-date-variant>
	               Equivalent to setting -a, -b, and -d
	 -r <repo>     Use this XBPS repository. May be specified multiple times
	 -h            Show this help and exit
	 -V            Show version and exit

	Other options can be passed directly to mklive.sh by specifying them after the --.
	See mklive.sh -h for more details.
	EOH
}

while getopts "a:b:d:t:g:hr:B:V" opt; do
case $opt in
    a) ARCH="$OPTARG";;
    b) IMAGES="$OPTARG";;
    B) BOOTLOADER="$OPTARG";;
    d) DATE="$OPTARG";;
    g) GREETER="$OPTARG";;
    r) REPO="-r $OPTARG $REPO";;
    t) TRIPLET="$OPTARG";;
    V) version; exit 0;;
    h) usage; exit 0;;
    *) usage >&2; exit 1;;
esac
done
shift $((OPTIND - 1))

INCLUDEDIR=$(mktemp -d)
trap "cleanup" INT TERM

cleanup() {
    rm -rf "$INCLUDEDIR"
}

# installer.sh in this tree is the public code-only copy of the pinned
# Installer artifact (PINNED-INSTALLER below): Void_Linux_Installer.sh
# Beta-v2.9.92 @ 01c6248d..., shipped as /usr/bin/void-installer on the live
# image. The upstream script carries an @@MKLIVE_VERSION@@ placeholder; this
# one does not, so the sed below is a no-op kept for upstream compatibility.
include_installer() {
    if [ -x installer.sh ]; then
        MKLIVE_VERSION="$(PROGNAME='' version)"
        installer=$(mktemp)
        sed "s/@@MKLIVE_VERSION@@/${MKLIVE_VERSION}/" installer.sh > "$installer"
        install -Dm755 "$installer" "$INCLUDEDIR"/usr/bin/void-installer
        rm "$installer"
    else
        echo installer.sh not found >&2
        exit 1
    fi
}

setup_pipewire() {
    PKGS="$PKGS pipewire alsa-pipewire"
    case "$ARCH" in
        asahi*)
            PKGS="$PKGS asahi-audio"
            SERVICES="$SERVICES speakersafetyd"
            ;;
    esac
    mkdir -p "$INCLUDEDIR"/etc/xdg/autostart
    ln -sf /usr/share/applications/pipewire.desktop "$INCLUDEDIR"/etc/xdg/autostart/
    mkdir -p "$INCLUDEDIR"/etc/pipewire/pipewire.conf.d
    ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf "$INCLUDEDIR"/etc/pipewire/pipewire.conf.d/
    ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf "$INCLUDEDIR"/etc/pipewire/pipewire.conf.d/
    mkdir -p "$INCLUDEDIR"/etc/alsa/conf.d
    ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf "$INCLUDEDIR"/etc/alsa/conf.d
    ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf "$INCLUDEDIR"/etc/alsa/conf.d
}

# ---------------------------------------------------------------------------
# Desktop-environment specific extras.
#
# PINNED-INSTALLER: Beta-v2.9.92 83ece9384ef142de673fb4c098b2cdec117121dc08798d2cc157209e65d855ce
#   The per-DE gates below mirror the Installer's Stage-2 branches, and the
#   Installer artifact itself is what this fork SHIPS: `installer.sh` in this
#   tree is the public code-only copy of Void_Linux_Installer.sh Beta-v2.9.92
#   (sha256 01c6248d04a314db442dea952b9d6a8957e29c54388ca0608ea404b313c7e14c),
#   installed by include_installer() as /usr/bin/void-installer. Recorded in
#   coordination/PINS.md §3.1; coordination/check-pins.sh verifies the SHAs.
#
# void-installer (the installer shipped on the live image) applies a set of
# per-DE "gates" at install time.  Several DE metapackages omit pieces the user
# expects on a fresh desktop — most visibly a terminal/text editor/volume
# applet — and every GTK-family desktop needs a polkit privilege agent.  On a
# runit box Void's udisks2 package ships only a D-Bus activation unit, so
# udisksd is never reliably supervised and removable media does not automount;
# COSMIC has no built-in automounter at all, and cosmic-comp additionally needs
# a valid xkb_config or cosmic-greeter panics.
#
# These helpers reproduce those gates in the LIVE environment: the packages are
# added to the per-DE PKGS lists above, and the matching files/services are
# dropped into the mklive include dir (copied into the rootfs by mklive after
# packages are installed).  Keep them in sync with the pinned Installer
# Stage-2 DE branches (PINNED-INSTALLER above).
# ---------------------------------------------------------------------------

# [USB-AUTOMOUNT] supervised udisks2 service for every graphical variant.
# Mirrors void-installer's /etc/sv/udisksd + first-boot runsvdir link.
setup_udisksd() {
    mkdir -p "$INCLUDEDIR"/etc/sv/udisksd/log \
             "$INCLUDEDIR"/var/log/udisksd \
             "$INCLUDEDIR"/etc/runit/runsvdir/default
    cat > "$INCLUDEDIR"/etc/sv/udisksd/run << 'EOF'
#!/bin/sh
exec 2>&1
exec /usr/libexec/udisks2/udisksd
EOF
    chmod 0755 "$INCLUDEDIR"/etc/sv/udisksd/run
    cat > "$INCLUDEDIR"/etc/sv/udisksd/log/run << 'EOF'
#!/bin/sh
exec svlogd -tt /var/log/udisksd
EOF
    chmod 0755 "$INCLUDEDIR"/etc/sv/udisksd/log/run
    # Enable it the same way mklive does for its own services (an absolute
    # symlink in the default runsvdir); INCLUDEDIR is copied after
    # enable_services runs, so this is the only ordering that works.
    ln -sfn /etc/sv/udisksd "$INCLUDEDIR"/etc/runit/runsvdir/default/udisksd
}

# [XKB-CONFIG-CREATE] cosmic-comp needs a valid xkb_config.  The metapackage's
# own post-install hook can leave it missing (on a resumed install) or corrupt
# (`layout: ""us""` — the hook keeps the quotes from /etc/rc.conf).  Overwrite
# with the canonical form; the live console keymap defaults to "us" (mklive's
# KEYMAP default), so that is the correct layout here.
setup_cosmic_xkb_config() {
    _xkb_dir="$INCLUDEDIR"/usr/share/cosmic/com.system76.CosmicComp/v1
    mkdir -p "$_xkb_dir"
    cat > "$_xkb_dir"/xkb_config << 'EOF'
(
rules: "",
model: "",
layout: "us",
variant: "",
options: None,
repeat_delay: 600,
repeat_rate: 25,
)
EOF
}

# [COSMIC-POLKIT] + [USB-AUTOMOUNT] session autostart guards.  cosmic-desktop-full
# pulls no polkit agent and no automounter, and cosmic-session fires XDG
# autostart entries before the Wayland socket/session bus are stable, so both
# are launched behind a readiness guard (exactly like void-installer does).
setup_cosmic_autostart() {
    mkdir -p "$INCLUDEDIR"/usr/local/sbin "$INCLUDEDIR"/etc/xdg/autostart

    cat > "$INCLUDEDIR"/usr/local/sbin/cosmic-polkit-guard << 'EOF'
#!/bin/sh
set -u
# polkit-gnome installs its agent under one of these two paths depending on
# the build; detect at runtime so the guard works on any architecture.
_agent=""
for _c in /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome-authentication-agent-1; do
    [ -x "$_c" ] && { _agent="$_c"; break; }
done
[ -n "$_agent" ] || exit 0
_wl_sock="${XDG_RUNTIME_DIR:-/run/user/0}/${WAYLAND_DISPLAY:-wayland-1}"
_ready=0
while [ "$_ready" -eq 0 ]; do
    [ -S "$_wl_sock" ] || { sleep 1; continue; }
    dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
        --print-reply / org.freedesktop.DBus.ListNames >/dev/null 2>&1 || \
        { sleep 1; continue; }
    _ready=1
done
while :; do
    "$_agent" || { sleep 2; continue; }
    sleep 2
done
EOF
    chmod 0755 "$INCLUDEDIR"/usr/local/sbin/cosmic-polkit-guard

    cat > "$INCLUDEDIR"/etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop << 'EOF'
[Desktop Entry]
Name=PolicyKit Authentication Agent
Comment=PolicyKit Authentication Agent
Exec=/usr/local/sbin/cosmic-polkit-guard
Terminal=false
Type=Application
Categories=
NoDisplay=true
EOF

    cat > "$INCLUDEDIR"/usr/local/sbin/udiskie-guard << 'EOF'
#!/bin/sh
set -u
# wait for a compositor-backed session before udiskie starts
_wl_sock="${XDG_RUNTIME_DIR:-/run/user/0}/${WAYLAND_DISPLAY:-wayland-1}"
_ready=0
while [ "$_ready" -eq 0 ]; do
    [ -S "$_wl_sock" ] || { sleep 1; continue; }
    dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
        --print-reply / org.freedesktop.DBus.ListNames >/dev/null 2>&1 || \
        { sleep 1; continue; }
    _ready=1
done
while :; do
    udiskie || { sleep 2; continue; }
    sleep 2
done
EOF
    chmod 0755 "$INCLUDEDIR"/usr/local/sbin/udiskie-guard

    cat > "$INCLUDEDIR"/etc/xdg/autostart/udiskie.desktop << 'EOF'
[Desktop Entry]
Name=udiskie
Comment=Removable media automounter
Exec=/usr/local/sbin/udiskie-guard
Terminal=false
Type=Application
Categories=
NoDisplay=true
EOF
}

# [COSMIC-PPD] cosmic-settings hard-depends on power-profiles-daemon (D-Bus
# net.hadess.PowerProfiles), but nothing links its runit service, so the live
# COSMIC session's powermode picker shows "Backend not found".  Mirrors
# void-installer's Stage-2 install + first-boot link of
# /etc/sv/power-profiles-daemon (Beta-v2.9.90 [COSMIC-PPD]); the live image
# installs no tlp, so there is no PPD+tlp conflict here.  Same symlink-into-
# the-default-runsvdir pattern as setup_udisksd (INCLUDEDIR is copied after
# mklive's enable_services, so this is the only ordering that works).
setup_cosmic_ppd() {
    mkdir -p "$INCLUDEDIR"/etc/runit/runsvdir/default
    ln -sfn /etc/sv/power-profiles-daemon \
        "$INCLUDEDIR"/etc/runit/runsvdir/default/power-profiles-daemon
}

build_variant() {
    variant="$1"
    shift
    IMG=void-live-${ARCH}-${DATE}-${variant}.iso

    # el-cheapo installer is unsupported on arm because arm doesn't install a kernel by default
    # and to work around that would add too much complexity to it
    # thus everyone should just do a chroot install anyways
    WANT_INSTALLER=no
    case "$ARCH" in
        x86_64*|i686*)
            GRUB_PKGS="grub-i386-efi grub-x86_64-efi"
            GFX_PKGS="xorg-video-drivers xf86-video-intel"
            GFX_WL_PKGS="mesa-dri"
            WANT_INSTALLER=yes
            TARGET_ARCH="$ARCH"
            ;;
        aarch64*)
            GRUB_PKGS="grub-arm64-efi"
            GFX_PKGS="xorg-video-drivers"
            GFX_WL_PKGS="mesa-dri"
            TARGET_ARCH="$ARCH"
            ;;
        asahi*)
            GRUB_PKGS="asahi-base asahi-scripts grub-arm64-efi"
            GFX_PKGS="mesa-asahi-dri"
            GFX_WL_PKGS="mesa-asahi-dri"
            KERNEL_PKG="linux-asahi"
            TARGET_ARCH="aarch64${ARCH#asahi}"
            if [ "$variant" = xfce ]; then
                info_msg "xfce is not supported on asahi, switching to xfce-wayland"
                variant="xfce-wayland"
            fi
            ;;
    esac

    A11Y_PKGS="espeakup void-live-audio brltty"
    PKGS="dialog cryptsetup lvm2 mdadm void-docs-browse xtools-minimal xmirror chrony tmux vim nano git curl nftables $A11Y_PKGS $GRUB_PKGS"
    FONTS="font-misc-misc terminus-font dejavu-fonts-ttf"
    WAYLAND_PKGS="$GFX_WL_PKGS $FONTS orca"
    XORG_PKGS="$GFX_PKGS $FONTS xorg-minimal xorg-input-drivers setxkbmap xauth orca"
    SERVICES="sshd chronyd nftables"

    LIGHTDM_SESSION=''
    SDDM_SESSION=''   # SDDM session .desktop filename for the live autologin hook
    DE_DM=''          # display manager void-installer recommends for this DE
    GRAPHICAL=no

    case $variant in
        base|none)
            SERVICES="$SERVICES dhcpcd wpa_supplicant acpid"
        ;;
        enlightenment)
            PKGS="$PKGS $XORG_PKGS lightdm lightdm-gtk-greeter enlightenment terminology udisks2 firefox"
            SERVICES="$SERVICES acpid dhcpcd wpa_supplicant lightdm dbus polkitd"
            LIGHTDM_SESSION=enlightenment
            SDDM_SESSION=enlightenment.desktop
            DE_DM=lightdm
            GRAPHICAL=yes
        ;;
        xfce*)
            PKGS="$PKGS $XORG_PKGS lightdm lightdm-gtk-greeter xfce4 gnome-themes-standard gnome-keyring network-manager-applet gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox xfce4-pulseaudio-plugin lxqt-policykit"
            SERVICES="$SERVICES dbus lightdm NetworkManager polkitd"
            LIGHTDM_SESSION=xfce
            SDDM_SESSION=xfce.desktop
            DE_DM=lightdm
            GRAPHICAL=yes

            if [ "$variant" == "xfce-wayland" ]; then
                PKGS="$PKGS $WAYLAND_PKGS labwc"
                LIGHTDM_SESSION="xfce-wayland"
                SDDM_SESSION="xfce-wayland.desktop"
            fi
        ;;
        mate)
            PKGS="$PKGS $XORG_PKGS lightdm lightdm-gtk-greeter mate mate-extra mate-terminal pluma mate-media gnome-keyring network-manager-applet lxqt-policykit gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox"
            SERVICES="$SERVICES dbus lightdm NetworkManager polkitd"
            LIGHTDM_SESSION=mate
            SDDM_SESSION=mate.desktop
            DE_DM=lightdm
            GRAPHICAL=yes
        ;;
        cinnamon)
            PKGS="$PKGS $XORG_PKGS lightdm lightdm-gtk-greeter cinnamon-all gnome-keyring colord gnome-terminal gedit gnome-backgrounds blueman network-manager-applet lxqt-policykit gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox"
            SERVICES="$SERVICES dbus lightdm NetworkManager polkitd"
            LIGHTDM_SESSION=cinnamon
            SDDM_SESSION=cinnamon.desktop
            DE_DM=lightdm
            GRAPHICAL=yes
        ;;
        gnome)
            PKGS="$PKGS $XORG_PKGS gnome firefox"
            SERVICES="$SERVICES dbus gdm NetworkManager polkitd"
            SDDM_SESSION=gnome.desktop
            DE_DM=gdm
            GRAPHICAL=yes
        ;;
        kde)
            PKGS="$PKGS $XORG_PKGS kde5 konsole firefox dolphin NetworkManager kate ark kio-admin"
            SERVICES="$SERVICES dbus NetworkManager sddm"
            SDDM_SESSION=plasma.desktop
            DE_DM=sddm
            GRAPHICAL=yes
        ;;
        lxde)
            PKGS="$PKGS $XORG_PKGS lxde lightdm lightdm-gtk-greeter gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox"
            SERVICES="$SERVICES acpid dbus dhcpcd wpa_supplicant lightdm polkitd"
            LIGHTDM_SESSION=LXDE
            SDDM_SESSION=LXDE.desktop
            DE_DM=lightdm
            GRAPHICAL=yes
        ;;
        lxqt)
            PKGS="$PKGS $XORG_PKGS lxqt FeatherPad lxqt-policykit sddm gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox"
            SERVICES="$SERVICES dbus dhcpcd wpa_supplicant sddm polkitd"
            SDDM_SESSION=lxqt.desktop
            DE_DM=sddm
            GRAPHICAL=yes
        ;;
        cosmic)
            # cosmic-desktop-full is only in the third-party bluesloth repo
            # (enabled below); its pinned signing key is vendored in keys/.
            # Wayland-first, but keep XORG_PKGS for X11 apps and helpers, and
            # add mesa-dri (GFX_WL_PKGS) for the compositor.
            #
            # [COSMIC-GREETER-DEFAULT] The greeter is cosmic-greeter, matching
            # void-installer's recommended/default DM for COSMIC since
            # Beta-v2.9.91 (the installer is the authority for the per-DE
            # pairing; the live image must agree for `auto`).  greetd hosts the
            # greeter and is listed explicitly alongside its hard dependency,
            # cosmic-comp is the greeter session's compositor (also pulled by
            # cosmic-desktop-full, named here so the -g cosmic-greeter pairing
            # matches), and the run scripts need supervised dbus + elogind —
            # the same set the -g cosmic-greeter swap branch below installs.
            # SDDM is intentionally NOT installed.
            #
            # [COSMIC-PPD] power-profiles-daemon is named explicitly (it also
            # arrives transitively via cosmic-settings) so setup_cosmic_ppd can
            # link its runit service; COSMIC's powermode picker then has its
            # net.hadess.PowerProfiles backend in the live session too, exactly
            # as void-installer now guarantees for the installed target.
            #
            # [COSMIC-NET] cosmic-desktop-full does not pull the NetworkManager
            # daemon, yet SERVICES below enables /etc/sv/NetworkManager (the
            # live session's COSMIC network applet talks to it over D-Bus, as
            # on every other graphical variant; those DEs get the daemon
            # transitively via network-manager-applet, the gnome metapackage,
            # or kde5).  Name it explicitly, or mklive's enable_services dies
            # with "service NetworkManager not in /etc/sv".
            PKGS="$PKGS $XORG_PKGS $GFX_WL_PKGS cosmic-desktop-full polkit-gnome udiskie NetworkManager cosmic-greeter cosmic-comp greetd power-profiles-daemon"
            SERVICES="$SERVICES dbus elogind NetworkManager polkitd cosmic-greeter cosmic-greeter-daemon"
            DE_DM=cosmic-greeter
            GRAPHICAL=yes
        ;;
        *)
            >&2 echo "Unknown variant $variant"
            exit 1
        ;;
    esac

    # udisks2 provides the udisksd binary the supervised service (below) execs.
    # Most desktops pull it in via gvfs/udiskie, but make it explicit on every
    # graphical variant so automount is never a missing package away.
    if [ "$GRAPHICAL" = yes ]; then
        PKGS="$PKGS udisks2"
    fi

    # Record the desktop's SDDM session for the live autologin hook.  dracut's
    # display-manager-autologin.sh reads /etc/voidlive-sddm-session at boot; it
    # used to hardcode KDE's plasma.desktop, which broke autologin for every
    # non-KDE desktop whose default DM is SDDM (LXQt, or any -g sddm).
    # Written for every graphical variant so a -g sddm override also works.
    if [ "$GRAPHICAL" = yes ] && [ -n "$SDDM_SESSION" ]; then
        mkdir -p "$INCLUDEDIR"/etc
        printf '%s\n' "$SDDM_SESSION" > "$INCLUDEDIR"/etc/voidlive-sddm-session
    fi

    # ------------------------------------------------------------------
    # Display manager / greeter selection.
    #
    # Each desktop block above already carries the DM void-installer
    # recommends for it (DE_DM).  -g/$GREETER may override that with any
    # other DM/greeter; the recommended DM's packages/services are then
    # swapped out.  auto/empty keeps the recommended pairing.
    # ------------------------------------------------------------------
    strip_words() {
        local _l _w
        _l="$1"; shift
        for _w in "$@"; do
            _l=$(printf '%s\n' "$_l" | tr ' ' '\n' | grep -vx -e "$_w" | tr '\n' ' ')
        done
        printf '%s' "$_l"
    }

    REQ_LIGHTDM=gtk
    if [ -z "$GREETER" ] || [ "$GREETER" = auto ]; then
        REQ_DM="$DE_DM"
    else
        case "$GREETER" in
            sddm|gdm|cosmic-greeter|none) REQ_DM="$GREETER" ;;
            lightdm|lightdm-gtk|gtk)      REQ_DM=lightdm; REQ_LIGHTDM=gtk ;;
            lightdm-slick|slick)          REQ_DM=lightdm; REQ_LIGHTDM=slick ;;
            *) >&2 echo "Unknown greeter '$GREETER' (use: auto, sddm, gdm, lightdm, lightdm-gtk, lightdm-slick, cosmic-greeter, none)"; exit 1 ;;
        esac
    fi

    if [ "$REQ_DM" != "$DE_DM" ]; then
        # Drop the DM the desktop embedded, then add the requested one.
        case "$DE_DM" in
            sddm)    PKGS=$(strip_words "$PKGS" sddm); SERVICES=$(strip_words "$SERVICES" sddm) ;;
            gdm)     PKGS=$(strip_words "$PKGS" gdm);  SERVICES=$(strip_words "$SERVICES" gdm) ;;
            lightdm) PKGS=$(strip_words "$PKGS" lightdm lightdm-gtk-greeter); SERVICES=$(strip_words "$SERVICES" lightdm) ;;
            cosmic-greeter)
                # [COSMIC-GREETER-DEFAULT] COSMIC now embeds cosmic-greeter;
                # swap it out cleanly for the requested DM.  The supervised
                # dbus/elogind session services are left in place — they help
                # any DM, not just the greeter.
                PKGS=$(strip_words "$PKGS" cosmic-greeter cosmic-comp greetd)
                SERVICES=$(strip_words "$SERVICES" cosmic-greeter cosmic-greeter-daemon)
                ;;
        esac
        case "$REQ_DM" in
            sddm)  PKGS="$PKGS sddm"; SERVICES="$SERVICES sddm" ;;
            gdm)   PKGS="$PKGS gdm";  SERVICES="$SERVICES gdm" ;;
            lightdm)
                if [ "$REQ_LIGHTDM" = slick ]; then
                    PKGS="$PKGS lightdm lightdm-slick-greeter"
                else
                    PKGS="$PKGS lightdm lightdm-gtk-greeter"
                fi
                SERVICES="$SERVICES lightdm"
                ;;
            cosmic-greeter)
                # cosmic-greeter ships its own runit services and a greetd
                # config whose session runs "cosmic-comp cosmic-greeter"
                # (user _cosmicgreeter, created by the pkg's INSTALL script).
                # cosmic-comp comes from cosmic-desktop-full but is added here
                # so cosmic-greeter also works on non-cosmic desktops.  Its
                # run script requires supervised dbus + elogind.
                PKGS="$PKGS cosmic-greeter cosmic-comp"
                SERVICES="$SERVICES dbus elogind cosmic-greeter cosmic-greeter-daemon"
                ;;
            none|'') ;;
        esac
    elif [ "$REQ_DM" = lightdm ] && [ "$REQ_LIGHTDM" = slick ]; then
        # Same DM, non-default LightDM greeter (GTK is void-installer's default).
        PKGS=$(strip_words "$PKGS" lightdm-gtk-greeter)
        PKGS="$PKGS lightdm-slick-greeter"
    fi

    # A LightDM greeter with no wallpaper paints a solid black login screen
    # (the GTK and Slick greeters both read a background= path from
    # /usr/share/backgrounds, and most Void desktop metapackages ship no images
    # there).  Pull the standard GNOME set whenever LightDM drives the session;
    # postsetup.sh then points the greeter at one.  (Cinnamon already lists it.)
    if [ "$GRAPHICAL" = yes ] && [ "$REQ_DM" = lightdm ]; then
        PKGS="$PKGS gnome-backgrounds"
    fi

    if [ "$REQ_DM" = lightdm ]; then
        mkdir -p "$INCLUDEDIR"/etc/lightdm
        [ -n "$LIGHTDM_SESSION" ] && echo "$LIGHTDM_SESSION" > "$INCLUDEDIR"/etc/lightdm/.session
        if [ "$REQ_LIGHTDM" = slick ]; then
            # Slick's greeter .desktop is slick-greeter.desktop (NOT
            # lightdm-slick-greeter.desktop).  A full lightdm.conf is written
            # so Void's mandatory session-wrapper survives.
            {
                echo "[Seat:*]"
                echo "greeter-session=slick-greeter"
                echo "session-wrapper=/etc/lightdm/Xsession"
                [ -n "$LIGHTDM_SESSION" ] && echo "user-session=$LIGHTDM_SESSION"
            } > "$INCLUDEDIR"/etc/lightdm/lightdm.conf
        else
            # needed to show the keyboard layout menu on the login screen
            cat <<- EOF > "$INCLUDEDIR"/etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
indicators = ~host;~spacer;~clock;~spacer;~layout;~session;~a11y;~power
EOF
        fi
    fi

    # DE-specific files/services (see the helper headers above).  Ordering is
    # deliberate: INCLUDEDIR is copied into the rootfs BEFORE mklive's postsetup
    # script runs, so static files live here while the few fixes that operate on
    # installed package files are done by postsetup.sh (DE-agnostic there,
    # driven by the VOIDLIVE_DE/VOIDLIVE_DM values exported below).
    if [ "$GRAPHICAL" = yes ]; then
        setup_udisksd
    fi
    if [ "$variant" = cosmic ] || [ "$REQ_DM" = cosmic-greeter ]; then
        # cosmic-comp (the desktop compositor and the cosmic-greeter session)
        # needs a valid xkb_config regardless of which DM was chosen.
        setup_cosmic_xkb_config
    fi
    if [ "$variant" = cosmic ]; then
        setup_cosmic_autostart
        setup_cosmic_ppd
    fi

    if [ "$WANT_INSTALLER" = yes ]; then
        include_installer
    else
        mkdir -p "$INCLUDEDIR"/usr/bin
        printf "#!/bin/sh\necho 'void-installer is not supported on this live image'\n" > "$INCLUDEDIR"/usr/bin/void-installer
        chmod 755 "$INCLUDEDIR"/usr/bin/void-installer
    fi

    if [ "$GRAPHICAL" = yes ]; then
        setup_pipewire
    fi

    # Third-party COSMIC repo: needed for the cosmic desktop and/or the
    # cosmic-greeter.  Its signing key is pinned and vendored in keys/ (DER
    # SHA-256 83ffd154d1dee504ea384a0c31b12e072d5884f7f75eb950e30ace852d7d2e7b),
    # so mklive trusts it without an interactive import prompt.
    # Audit: https://github.com/bluesloth/void-linux-cosmic
    if [ "$variant" = cosmic ] || [ "$REQ_DM" = cosmic-greeter ]; then
        COSMIC_REPO="https://bluesloth.github.io/void-linux-cosmic/"
        if ! command -v curl >/dev/null 2>&1; then
            >&2 echo "FATAL: curl is required to verify the third-party COSMIC repository."
            exit 1
        fi
        if ! curl -fsSL --max-time 30 -o /dev/null "${COSMIC_REPO}x86_64-repodata" 2>/dev/null; then
            >&2 echo "FATAL: the third-party COSMIC repository (${COSMIC_REPO}) is not reachable."
            >&2 echo "       Build aborted rather than produce a broken COSMIC image."
            >&2 echo "       Audit: https://github.com/bluesloth/void-linux-cosmic"
            exit 1
        fi
        info_msg "COSMIC: using third-party repo ${COSMIC_REPO} (pinned key vendored in keys/)."
        REPO="$REPO -r ${COSMIC_REPO}"
        mkdir -p "$INCLUDEDIR"/etc/xbps.d
        echo "repository=${COSMIC_REPO}" > "$INCLUDEDIR"/etc/xbps.d/59-cosmic.conf
    fi

    # Export the resolved DE/DM so postsetup.sh can apply the DE-specific
    # fixes that need the installed package files (e.g. Cinnamon's session
    # D-Bus wrapping + wallpaper).  Inherited by mklive.sh and thus by the
    # postsetup script it runs.
    export VOIDLIVE_DE="$variant"
    export VOIDLIVE_DM="$REQ_DM"
    export VOIDLIVE_LIGHTDM="${REQ_LIGHTDM:-gtk}"

    ./mklive.sh -a "$TARGET_ARCH" -o "$IMG" -p "$PKGS" -S "$SERVICES" -I "$INCLUDEDIR" \
        ${KERNEL_PKG:+-v $KERNEL_PKG} ${BOOTLOADER:+-B $BOOTLOADER} ${REPO} "$@"

	cleanup
}

if [ ! -x mklive.sh ]; then
    echo mklive.sh not found >&2
    exit 1
fi

if [ -n "$TRIPLET" ]; then
    IFS=: read -r ARCH DATE VARIANT _ < <( echo "$TRIPLET" | sed -Ee 's/^(.+)-([0-9rc]+)-(.+)$/\1:\2:\3/' )
    build_variant "$VARIANT" "$@"
else
    for image in $IMAGES; do
        build_variant "$image" "$@"
    done
fi
