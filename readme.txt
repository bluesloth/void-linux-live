Void live ISO builder - quick examples
======================================

Run as root.  `build` builds an ISO (default subcommand); `flash` writes an
ISO to a USB stick and adds the persistent-overlay partition.  The desktop
environment and greeter are chosen at BUILD time, so rebuild (or use
`build ... --flash`) to change them.

Every example below is shown two ways:
  (a) build and flash  - one command, using --flash <device>
  (b) build then flash - build first, then a separate flash command

Notes:
  * Images built without --persist boot ephemeral; `flash` still creates the
    VOID_OVL partition, but such an image ignores it.
  * -B <bootloader> is a pass-through option, so in the combined form it must
    come AFTER --flash <device> (the wrapper stops parsing its own options at
    the first pass-through flag).  In the two-step form it belongs on the
    build command only.
  * On a flaky or tethered uplink a build can stall; `build --watch` starts
    builder-watch.sh, which detects the stall (or a build that dies with no
    ISO) and restarts the build from the cache.  Off by default.

Desktop environment (--desktop, default: kde)
---------------------------------------------
  kde           KDE Plasma
  gnome         GNOME
  cinnamon      Cinnamon
  xfce          Xfce (X11)
  xfce-wayland  Xfce on Wayland
  mate          MATE
  lxqt          LXQt
  lxde          LXDE
  enlightenment Enlightenment
  cosmic        COSMIC (third-party repo; pinned key vendored in keys/)
  none          console only, no graphical stack
  base          bare base system

Greeter / display manager (--greeter, default: auto)
----------------------------------------------------
  auto            display manager void-installer recommends for the chosen
                  desktop (see the mapping below)
  sddm            SDDM
  gdm             GDM
  lightdm         LightDM with the GTK greeter
  lightdm-gtk     LightDM with the GTK greeter (same as lightdm)
  lightdm-slick   LightDM with the Slick greeter
  cosmic-greeter  greetd + cosmic-greeter
  none            no display manager (boots to a text console)

  Default (auto) per desktop:
    kde, lxqt                                  -> sddm
    cosmic                                     -> cosmic-greeter
    gnome                                      -> gdm
    cinnamon, xfce, mate, lxde, enlightenment  -> lightdm (GTK)

  Any greeter can be paired with any desktop.

  Each graphical desktop also pulls in the per-desktop extras void-installer
  adds on an installed system (a terminal/editor for MATE/LXQt/Cinnamon, a
  polkit agent, and a supervised udisksd so removable media automounts; COSMIC
  also gets its xkb_config, udiskie, and a linked power-profiles-daemon so the
  powermode picker works).  See CHEATSHEET.md for details.


Desktop / greeter examples
==========================

Default (KDE + SDDM):
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build
  sudo ./voidlive-build-persist.sh flash /dev/sdX

Xfce desktop:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop xfce --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop xfce
  sudo ./voidlive-build-persist.sh flash /dev/sdX

GNOME desktop:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop gnome --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop gnome
  sudo ./voidlive-build-persist.sh flash /dev/sdX

Console only (no graphical stack):
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop none --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop none
  sudo ./voidlive-build-persist.sh flash /dev/sdX

GNOME with the SDDM greeter:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop gnome --greeter sddm --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop gnome --greeter sddm
  sudo ./voidlive-build-persist.sh flash /dev/sdX

Xfce with the Slick greeter:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop xfce --greeter lightdm-slick --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop xfce --greeter lightdm-slick
  sudo ./voidlive-build-persist.sh flash /dev/sdX

Cinnamon with no display manager:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop cinnamon --greeter none --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop cinnamon --greeter none
  sudo ./voidlive-build-persist.sh flash /dev/sdX

Xfce + persistence (default 2GiB overlay):
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop xfce --persist --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop xfce --persist
  sudo ./voidlive-build-persist.sh flash /dev/sdX

Mate + Slick greeter + persistence + BOTH bootloaders + 8GiB overlay:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop mate --greeter lightdm-slick \
      --persist --flash /dev/sdX --overlay-size-mib 8192 -B both
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop mate --greeter lightdm-slick \
      --persist -B both
  sudo ./voidlive-build-persist.sh flash /dev/sdX --overlay-size-mib 8192

KDE + SDDM greeter + persistence + BOTH bootloaders + 8GiB overlay:
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop kde --greeter sddm \
      --persist --flash /dev/sdX --overlay-size-mib 8192 -B both
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop kde --greeter sddm \
      --persist -B both
  sudo ./voidlive-build-persist.sh flash /dev/sdX --overlay-size-mib 8192

COSMIC desktop (third-party repo):
  (a) build and flash:
  sudo ./voidlive-build-persist.sh build --desktop cosmic --persist --flash /dev/sdX
  (b) build then flash:
  sudo ./voidlive-build-persist.sh build --desktop cosmic --persist
  sudo ./voidlive-build-persist.sh flash /dev/sdX


Bootloader examples
===================
BOTH (default, no -B needed):

1. BOTH, no persistence:
   (a) build and flash:
   sudo ./voidlive-build-persist.sh build --flash /dev/sdX
   (b) build then flash:
   sudo ./voidlive-build-persist.sh build
   sudo ./voidlive-build-persist.sh flash /dev/sdX

2. BOTH, persistent (default 2GiB):
   (a) build and flash:
   sudo ./voidlive-build-persist.sh build --persist --flash /dev/sdX
   (b) build then flash:
   sudo ./voidlive-build-persist.sh build --persist
   sudo ./voidlive-build-persist.sh flash /dev/sdX

3. BOTH, persistent, 8GiB overlay:
   (a) build and flash:
   sudo ./voidlive-build-persist.sh build --persist --flash /dev/sdX --overlay-size-mib 8192
   (b) build then flash:
   sudo ./voidlive-build-persist.sh build --persist
   sudo ./voidlive-build-persist.sh flash /dev/sdX --overlay-size-mib 8192

