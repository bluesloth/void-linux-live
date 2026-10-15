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


---

| `none` | no display manager (boots to a text console) |

```sh
# GNOME, but log in through SDDM instead of GDM
sudo ./voidlive-build-persist.sh build --desktop gnome --greeter sddm

# Xfce with the Slick greeter
sudo ./voidlive-build-persist.sh build --desktop xfce --greeter lightdm-slick

# Cinnamon, no display manager
sudo ./voidlive-build-persist.sh build --desktop cinnamon --greeter none
```

Notes:
- `cosmic-greeter` needs `cosmic-comp` (pulled from the third-party repo) and is
  intended for `--desktop cosmic`; it works on other desktops but is unusual.
- `--greeter none` leaves the desktop packages installed but no login manager —
  you land on a TTY and start the session manually (`startx`, `startplasma-x11`, ...).

Desktop-environment extras
--------------------------
Each graphical desktop also pulls in the per-desktop pieces void-installer adds
on an installed system, so the live desktop behaves like one it installs:

- a terminal / text editor / volume applet where the metapackage omits it —
  `mate-terminal` + `pluma` + `mate-media` (MATE), `FeatherPad` (LXQt),
  `gedit` (Cinnamon);
- a polkit privilege agent for the GTK-family desktops (`lxqt-policykit`, plus
  `polkit-gnome` for COSMIC);
- a supervised `udisksd` service on **every** graphical flavor, so removable
  media actually automounts under runit (Void's `udisks2` package ships only a
  D-Bus activation unit and nothing supervises the daemon).

COSMIC additionally gets a pre-seeded `xkb_config` (cosmic-comp leaves the
greeter broken without one), `udiskie` behind a session-readiness autostart
guard (COSMIC ships no built-in removable-media automounter), and a linked
`power-profiles-daemon` so the powermode picker has its backend.

## Persistence

Persistence needs **both**:
1. `--persist` at **build** time (bakes `rd.overlay=LABEL=VOID_OVL` into the ISO), and
2. a partition labeled `VOID_OVL` (**`flash`** creates it).

Without `--persist` the image boots ephemeral — which is what you want for a
plain USB stick or Ventoy.

```sh
# Persistent USB: changes survive reboots
sudo ./voidlive-build-persist.sh build --persist --flash /dev/sdX

# Ephemeral USB / Ventoy (no persistence)
sudo ./voidlive-build-persist.sh build --flash /dev/sdX
```

Overlay partition size (default `2048` MiB):

```sh
sudo ./voidlive-build-persist.sh build --persist --overlay-size-mib 8192 --flash /dev/sdX

# ...or grow it while flashing an existing ISO
sudo ./voidlive-build-persist.sh flash /dev/sdX void-live-x86_64-20260101-kde.iso --overlay-size-mib 8192
```

## Bootloader (EFI)

`--bootloader grub|limine|both`, or the shorthands `--grub` / `--limine` /
`--both`. Default is `both` (GRUB + Limine on EFI; BIOS always uses syslinux).
aarch64/asahi supports only `grub`.

```sh
sudo ./voidlive-build-persist.sh build --both
sudo ./voidlive-build-persist.sh build --bootloader limine
sudo ./voidlive-build-persist.sh build --grub
```

## XBPS cache (offline / fast rebuilds)

| Flag | Effect |
| --- | --- |
| `--cache <dir>` | Use a specific package cache. Default: `./xbps-cachedir-<arch>` in this folder. If that is missing/empty, a populated cache under `/run/media` is auto-detected. An explicit `--cache` always wins. |
| `--refresh-cache` | Refresh the repo index, then pull current versions into the cache. |
| `--replace-cache` | Wipe the cache (`*.xbps` / `*.sig2`), refresh, and re-download cleanly. |
| `--seed-cache` | During **flash**, copy the cache into the `VOID_OVL` partition (root **and** the dmsquash-live overlay upperdir, reusable by a later installer run) and drop `/xbps-cache-tool.sh` alongside it to update/replace it on the live system. |

```sh
sudo ./voidlive-build-persist.sh build --persist --refresh-cache
sudo ./voidlive-build-persist.sh build --replace-cache
sudo ./voidlive-build-persist.sh build --persist --seed-cache --both --flash /dev/sdX
sudo ./voidlive-build-persist.sh build --cache /run/media/you/STICK/xbps-cachedir-x86_64
```

`--seed-cache` is only meaningful together with `flash` (it writes into the
overlay partition). A missing cache is a warning, not a failure.

## Building from a non-Void host (Debian, Arch, ...)

`mklive.sh` needs the Void XBPS toolchain (`xbps-uhelper`, `xbps-install`,
`xbps-reconfigure`), which only exists on Void Linux — otherwise the build dies
with a misleading `qemu-x86_64 binary is missing` error. The wrapper detects a
non-Void host and runs the **build** in a Void userspace automatically:

| `--build-env` | Behaviour |
| --- | --- |
| `auto` (default) | podman/docker container if one is installed, else a Void ROOTFS chroot |
| `container` | require podman or docker (image built from `container/Containerfile` on first use) |
| `chroot` | require a Void ROOTFS bootstrapped under `./.void-buildenv` (48 MB, one-time) |
| `native` | never wrap — run `mklive.sh` here (Void hosts only) |

```sh
# Debian/Arch: auto-selects container (if present) or chroot
sudo ./voidlive-build-persist.sh build --persist --build-env auto

# force one or the other
sudo ./voidlive-build-persist.sh build --persist --build-env container
sudo ./voidlive-build-persist.sh build --persist --build-env chroot
```

`flash` is never wrapped — it is plain `dd`/`sfdisk`/`mkfs.ext4` and runs on the
host, so `build --flash /dev/sdX` builds in the Void environment and then flashes
on the host. The container runs `--privileged` (mklive chroots and bind-mounts)
with the project mounted at the same path; `--cache` and the output ISO resolve
identically inside and out. Cross-arch builds (target ≠ host) additionally need
`qemu-user-static` + binfmt on the host.

## Common one-shot combos

```sh
# Default KDE, persistent, both bootloaders, cache seeded, flashed
sudo ./voidlive-build-persist.sh build --persist --seed-cache --both --flash /dev/sdX

# Same, but refresh packages from the mirror first
sudo ./voidlive-build-persist.sh build --persist --seed-cache --both --flash /dev/sdX --refresh-cache

# Xfce, persistent, one shot
sudo ./voidlive-build-persist.sh build --desktop xfce --persist --flash /dev/sdX
```

## Advanced: pass options through to mklive

Anything the wrapper does not recognize is forwarded to `mklive.sh`. **Put
passthrough flags last** — the wrapper stops parsing at the first unrecognized
argument, so any wrapper flag placed after one is not processed.

```sh
# locale, keymap, boot title, root shell, kernel version
sudo ./voidlive-build-persist.sh build --persist \
    -l en_US.UTF-8 -k us -T "Void Rescue" -e /bin/bash -v linux6.12

# extra kernel command line
sudo ./voidlive-build-persist.sh build --persist -C "console=ttyS0,115200"

# add extra packages on top of the flavor's set
sudo ./voidlive-build-persist.sh build --desktop xfce --persist -p htop -p neovim
```

## Gotchas

- Run as root (`sudo`): the script uses xbps, `mount`, `sfdisk`, and `dd`.
- `flash` destroys everything on the target device.
- Persistence requires `--persist` **and** the `VOID_OVL` partition; a stick
  without the partition simply boots ephemeral.
- `cosmic` pulls `cosmic-desktop-full` from the third-party
  [bluesloth/void-linux-cosmic](https://github.com/bluesloth/void-linux-cosmic);
  its signing key is pinned and vendored in `keys/`. The build aborts if the
  repo is unreachable.
- The hybrid MBR/APM partition table on the stick allows at most four primary
  partitions; `flash` checks this before repartitioning.
- Keep all wrapper flags **before** any passthrough args (see previous section).
