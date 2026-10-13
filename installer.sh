#!/usr/bin/env bash
set -eE
set -o pipefail

SCRIPT_VERSION="Beta-v2.9.92"



DEFAULT_LOGIN_SHELL="${DEFAULT_LOGIN_SHELL:-1}"
DEFAULT_DESKTOP="${DEFAULT_DESKTOP:-1}"
DEFAULT_XORG="${DEFAULT_XORG:-false}"
DEFAULT_AUDIO="${DEFAULT_AUDIO:-false}"
DEFAULT_SESSION_STACK="${DEFAULT_SESSION_STACK:-1}"
DEFAULT_BOOTLOADER="${DEFAULT_BOOTLOADER:-1}"
DEFAULT_EFI_ESP_SIZE="${DEFAULT_EFI_ESP_SIZE:-1}"
DEFAULT_KERNEL_MAINLINE="${DEFAULT_KERNEL_MAINLINE:-false}"
DEFAULT_KERNEL_LTS="${DEFAULT_KERNEL_LTS:-true}"
DEFAULT_LOCALE="${DEFAULT_LOCALE:-1}"
DEFAULT_TIMEZONE="${DEFAULT_TIMEZONE:-1}"
DEFAULT_LOCAL_CACHE="${DEFAULT_LOCAL_CACHE:-no}"
DEFAULT_SWAP_BACKEND="${DEFAULT_SWAP_BACKEND:-1}"
DEFAULT_HIBERNATION="${DEFAULT_HIBERNATION:-false}"
DEFAULT_SNAPSHOT_AUDIO="${DEFAULT_SNAPSHOT_AUDIO:-false}"
DEFAULT_OCTOXBPS="${DEFAULT_OCTOXBPS:-false}"
DEFAULT_FLATPAK="${DEFAULT_FLATPAK:-false}"
DEFAULT_COSMIC_STORE="${DEFAULT_COSMIC_STORE:-false}"
DEFAULT_COSMIC_TOUCHPAD_RCLICK="${DEFAULT_COSMIC_TOUCHPAD_RCLICK:-false}"
DEFAULT_BREW="${DEFAULT_BREW:-false}"
DEFAULT_FIREFOX="${DEFAULT_FIREFOX:-true}"
DEFAULT_CHROMIUM="${DEFAULT_CHROMIUM:-true}"
DEFAULT_THUNDERBIRD="${DEFAULT_THUNDERBIRD:-false}"
DEFAULT_STEAM="${DEFAULT_STEAM:-false}"
DEFAULT_LUTRIS="${DEFAULT_LUTRIS:-false}"
DEFAULT_HEROIC="${DEFAULT_HEROIC:-false}"
DEFAULT_BOTTLES="${DEFAULT_BOTTLES:-false}"
DEFAULT_WINE="${DEFAULT_WINE:-false}"
DEFAULT_GAMEMODE="${DEFAULT_GAMEMODE:-false}"
DEFAULT_VIRTUALBOX="${DEFAULT_VIRTUALBOX:-false}"
DEFAULT_SUBVOL_ISOLATE="${DEFAULT_SUBVOL_ISOLATE:-true}"
DEFAULT_SUBVOL_PRECREATE="${DEFAULT_SUBVOL_PRECREATE:-false}"
DEFAULT_VIVALDI="${DEFAULT_VIVALDI:-false}"
DEFAULT_FALKON="${DEFAULT_FALKON:-false}"
DEFAULT_BRAVE="${DEFAULT_BRAVE:-false}"
DEFAULT_WEB_BROWSERS="${DEFAULT_WEB_BROWSERS:-false}"
DEFAULT_PODMAN_ROOTLESS="${DEFAULT_PODMAN_ROOTLESS:-false}"
DEFAULT_PODMAN_ROOTFUL="${DEFAULT_PODMAN_ROOTFUL:-false}"
DEFAULT_DOCKER="${DEFAULT_DOCKER:-false}"
DEFAULT_DOCKER_GROUP_ADD="${DEFAULT_DOCKER_GROUP_ADD:-false}"
DEFAULT_CONTAINERS="${DEFAULT_CONTAINERS:-false}"
DEFAULT_VIRT="${DEFAULT_VIRT:-false}"
DEFAULT_DISTROBOX="${DEFAULT_DISTROBOX:-false}"
DEFAULT_DISTROBOX_TRACK="${DEFAULT_DISTROBOX_TRACK:-1}"
DEFAULT_DISTROBOX_ENGINE="${DEFAULT_DISTROBOX_ENGINE:-1}"
DEFAULT_DEVICE_PROFILE="${DEFAULT_DEVICE_PROFILE:-1}"
DEFAULT_YK_TOUCH="${DEFAULT_YK_TOUCH:-yes}"
DEFAULT_YK_FALLBACK="${DEFAULT_YK_FALLBACK:-yes}"
DEFAULT_INSTALL_SSH_SERVER="${DEFAULT_INSTALL_SSH_SERVER:-false}"
DEFAULT_SSH_PORT="${DEFAULT_SSH_PORT:-22}"
DEFAULT_SSH_PASSWORD_AUTH="${DEFAULT_SSH_PASSWORD_AUTH:-yes}"
DEFAULT_SSH_ROOT_LOGIN="${DEFAULT_SSH_ROOT_LOGIN:-prohibit-password}"
DEFAULT_IMPORT_SSH_KEY="${DEFAULT_IMPORT_SSH_KEY:-false}"
DEFAULT_GENERATE_SSH_KEY="${DEFAULT_GENERATE_SSH_KEY:-false}"
DEFAULT_SSH_KEY_PROTECTED="${DEFAULT_SSH_KEY_PROTECTED:-yes}"
DEFAULT_EXPORT_SSH_KEY="${DEFAULT_EXPORT_SSH_KEY:-false}"
DEFAULT_INSTALL_NVIDIA="${DEFAULT_INSTALL_NVIDIA:-auto}"
DEFAULT_WIFI_FW="${DEFAULT_WIFI_FW:-auto}"
DEFAULT_MICROCODE="${DEFAULT_MICROCODE:-auto}"
DEFAULT_NIC="${DEFAULT_NIC:-}"
DEFAULT_REGION_HOME_FS="${DEFAULT_REGION_HOME_FS:-btrfs}"
DEFAULT_REGION_VAR_FS="${DEFAULT_REGION_VAR_FS:-btrfs}"
DEFAULT_REGION_CACHE_FS="${DEFAULT_REGION_CACHE_FS:-btrfs}"
DEFAULT_REGION_SRV_FS="${DEFAULT_REGION_SRV_FS:-btrfs}"
DEFAULT_REGION_OPT_FS="${DEFAULT_REGION_OPT_FS:-btrfs}"
DEFAULT_REGION_GAMES="${DEFAULT_REGION_GAMES:-none}"
DEFAULT_REGION_HOME_SIZE="${DEFAULT_REGION_HOME_SIZE:-40G}"
DEFAULT_REGION_VAR_SIZE="${DEFAULT_REGION_VAR_SIZE:-20G}"
DEFAULT_REGION_CACHE_SIZE="${DEFAULT_REGION_CACHE_SIZE:-4G}"
DEFAULT_REGION_SRV_SIZE="${DEFAULT_REGION_SRV_SIZE:-4G}"
DEFAULT_REGION_OPT_SIZE="${DEFAULT_REGION_OPT_SIZE:-4G}"
DEFAULT_REGION_GAMES_SIZE="${DEFAULT_REGION_GAMES_SIZE:-60G}"
DEFAULT_QUIET_BOOT="${DEFAULT_QUIET_BOOT:-no}"
DEFAULT_TEE_BLACKLIST="${DEFAULT_TEE_BLACKLIST:-no}"


JOURNAL="/tmp/void-installer-journal.log"
jl() { echo "[$(date +%H:%M:%S)] $*" >> "$JOURNAL" 2>/dev/null; }
save_log_to_usb() {
    {
        _usb_stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
        _usb_target=""
        for _usb_m in /run/media/* /media/*; do
            [ -d "$_usb_m" ] || continue
            [ -w "$_usb_m" ]  || continue
            _usb_dev="$(findmnt -no SOURCE --target "$_usb_m" 2>/dev/null)"
            if [ -n "${DISK:-}" ]; then
                case "${_usb_dev:-}" in
                    "$DISK"*) continue ;;
                esac
            fi
            case "${_usb_dev:-}" in
                /dev/loop*) continue ;;
            esac
            _usb_target="$_usb_m"
            break
        done
        [ -n "$_usb_target" ] || { unset _usb_stamp _usb_target _usb_m _usb_dev; return 0; }
        _usb_base="${_usb_target}/void-installer-crash-${_usb_stamp}"
        {
            echo "SCRIPT_VERSION=${SCRIPT_VERSION:-<unset>}"
            echo "STAGE_CONTEXT=${STAGE_CONTEXT:-<pre-stage>}"
            echo "TARGET_DISK=${DISK:-<not yet selected>}"
            echo "BOOTLOADER=${BOOTLOADER:-<n/a>}"
            echo "DESKTOP_ENV=${DESKTOP_ENV:-<n/a>}"
            echo "DISPLAY_MANAGER=${DISPLAY_MANAGER:-<n/a>}"
            echo "ENCRYPT=${ENCRYPT:-no} (public flag only; no passphrase ever)"
            echo "RESUME_RECORD=$([ -f "$STATE_FILE" ] && echo PRESENT || echo absent)"
            echo "JOURNAL_LINES=$(wc -l < "$JOURNAL" 2>/dev/null || echo 0)"
        } > "${_usb_base}.info" 2>/dev/null
        cp -f "$JOURNAL" "${_usb_base}.log" 2>/dev/null || { unset _usb_stamp _usb_target _usb_m _usb_dev _usb_base; return 0; }
        jl "CRASH-USB-LOG: post-mortem saved to ${_usb_base}.log (+.info)"
        echo "!! Crash post-mortem saved to ${_usb_base}.log (+.info) — evidence for triage." >&2
    } || true
    unset _usb_stamp _usb_target _usb_m _usb_dev _usb_base
}

_usb_dumped=0
_save_log_on_exit() {
    local _ec=$?
    [ "$_ec" -eq 0 ] && return 0
    [ "$_usb_dumped" = "1" ] && return 0
    _usb_dumped=1
    save_log_to_usb
    return 0
}
trap _save_log_on_exit EXIT

RESUME=0
AUTO_RESUME=0
STATE_FILE="/tmp/void-installer-state.sh"
DRY_RUN=0
for _arg in "$@"; do
    case "$_arg" in
        -r|--resume) AUTO_RESUME=1 ;;
        -d|--dry-run|--dryrun|-n)
            DRY_RUN=1 ;;
        --save-log)
            save_log_to_usb ;;
        -h|--help)
            echo "Usage: $0 [-r|--resume]          (resume a previous interrupted install)" >&2
            echo "       $0 [-d|--dry-run] [args]   (walk config, print the plan, touch nothing)" >&2
            echo "       $0 [--save-log]            (dump crash journal to a mounted USB stick, then continue)" >&2
            echo "       $0                         (fresh interactive install)" >&2
            exit 0 ;;
        *)
            echo "Unknown option: $_arg" >&2
            exit 2 ;;
    esac
done
unset _arg

: > "$JOURNAL"
REBOOT_DELAY="${REBOOT_DELAY:-20}"
if [ -t 1 ]; then
    C_RED=$'\033[1;31m'
    C_GRN=$'\033[1;32m'
    C_YLW=$'\033[1;33m'
    C_BLU=$'\033[1;34m'
    C_MAG=$'\033[1;35m'
    C_CYN=$'\033[1;36m'
    C_BOLD=$'\033[1m'
    C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_MAG=""; C_CYN=""; C_BOLD=""; C_RST=""
fi

sec_banner() {
    echo ""
    echo "${C_CYN}==============================================================================${C_RST}"
    echo "${C_CYN}# ${C_BOLD}$1${C_RST}${C_CYN}${2:+: $2}${C_RST}"
    echo "${C_CYN}==============================================================================${C_RST}"
}

ask() {
    printf '%s' "${C_BOLD}${C_YLW}-- ${1}${C_RST}"
}

note() { echo "${C_GRN}==>${C_RST} $*"; }
warn() { echo "${C_YLW}!! ${C_RST}$*" >&2; }
critical() { echo "${C_RED}!!!! CRITICAL:${C_RST} $*" >&2; }

esp_size_choose() {
    _esp_default_idx="${DEFAULT_EFI_ESP_SIZE}"
    [ -z "$_esp_default_idx" ] && _esp_default_idx=1
    case "$_esp_default_idx" in
        1) _esp_default_name="4 GiB" ;;
        2) _esp_default_name="6 GiB" ;;
        3) _esp_default_name="8 GiB" ;;
        4) _esp_default_name="Custom" ;;
        *) _esp_default_name="4 GiB"; _esp_default_idx=1 ;;
    esac
    echo ""
    echo "${C_BOLD}${C_BLU}EFI ESP partition size${C_RST}  (default: ${_esp_default_name})"
    echo "  The ESP is the partition whose size caps how many kernels + snapshots"
    echo "  coexist on it (Limine mirrors every kernel/snapshot; GRUB+ENCRYPT mounts"
    echo "  the ESP AT /boot). Larger = more headroom."
    echo "  ${C_BOLD}1)${C_RST} 4 GiB (default) — ArchWiki's recommendation for bootable snapshots"
    echo "  ${C_BOLD}2)${C_RST} 6 GiB — headroom for many kernel flavors + snapshots"
    echo "  ${C_BOLD}3)${C_RST} 8 GiB — generous; large initramfses + many snapshots"
    echo "  ${C_BOLD}4)${C_RST} Custom — type any sgdisk size (512M, 3G, 10GiB, ...); enforced to a 1 GiB floor"
    while true; do
        ask "Enter choice [1-4/Custom] (default ${DEFAULT_EFI_ESP_SIZE}: ${_esp_default_name}): "
        read -r ESP_SIZE_INPUT
        case "${ESP_SIZE_INPUT:-$_esp_default_idx}" in
            1) EFI_PART_SIZE="4G"; break ;;
            2) EFI_PART_SIZE="6G"; break ;;
            3) EFI_PART_SIZE="8G"; break ;;
            4|custom) 
                ask "Custom ESP size (e.g. 512M, 3G, 10GiB): "
                read -r ESP_SIZE_CUSTOM
                _esp_custom="${ESP_SIZE_CUSTOM^^}"
                case "$_esp_custom" in
                    *[!0-9a-gKMG]*|"") echo "Please enter a size like 512M, 3G, or 1024M." >&2 ;;
                    *)
                        _esp_num="${_esp_custom%[KMG]}"
                        _esp_units="${_esp_custom##*[0-9]}"
                        _esp_bytes=0
                        case "$_esp_units" in
                            G) _esp_bytes=$(( _esp_num * 1024 )) ;;
                            M) _esp_bytes=$_esp_num ;;
                            K) _esp_bytes=$(( _esp_num / 1024 )) ;;
                        esac
                        if [ "$_esp_bytes" -lt 1024 ]; then
                            echo "  ESP too small — floor is 1 GiB (1024M). Try again." >&2
                        else
                            case "$_esp_units" in
                                G) EFI_PART_SIZE="${_esp_custom}"; EFI_PART_SIZE="${_esp_num}G" ;;
                                M|K)
                                    _esp_gb=$(( _esp_bytes / 1024 ))
                                    if [ $(( _esp_bytes % 1024 )) -eq 0 ]; then
                                        EFI_PART_SIZE="${_esp_gb}G"
                                    else
                                        EFI_PART_SIZE="${_esp_num}${_esp_units}"
                                    fi
                                    ;;
                            esac
                            break
                        fi
                        ;;
                esac
                ;;
            *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
        esac
    done
    unset _esp_default_idx _esp_default_name _esp_custom _esp_num _esp_units _esp_bytes _esp_gb
    echo "  Resolved ESP size: ${EFI_PART_SIZE}"
}

browse_pick() {
    local _bp_mode="${1:-file}" _bp_label="${2:-file}"
    local _bp_start _bp_ok=0 _bp_src="" _bp_ext="" _bp_i _bp_alias=""
    local -a _bp_items=()
    if [ -d /run/media ]; then
        _bp_start="/run/media"
    else
        _bp_start="/root"
    fi
    while [ "$_bp_ok" -eq 0 ]; do
        echo "" >&2
        echo "  Browse for ${_bp_label}: ${C_BOLD}${C_CYN}/${_bp_start#/}${C_RST}" >&2
        echo "  Enter ${C_BOLD}..${C_RST} to go up a level, an absolute/relative path to jump there," >&2
        echo "  ${C_BOLD}m${C_RST}/${C_BOLD}drives${C_RST} to jump back to the mounted-drive list at /run/media," >&2
        if [ "$_bp_mode" = "img" ]; then
            echo "  or the number of an image below. ${C_BOLD}Enter alone${C_RST} declines (no image)." >&2
        elif [ "$_bp_mode" = "dir" ]; then
            echo "  or the number of a directory below. ${C_BOLD}Enter alone${C_RST} declines;" >&2
            echo "  ${C_BOLD}!${C_RST}/${C_BOLD}ok${C_RST} accepts the CURRENT directory." >&2
        else
            echo "  or the number of an entry below. ${C_BOLD}Enter alone${C_RST} declines." >&2
        fi
        _bp_items=()
        if [ "$_bp_start" != "/" ]; then
            _bp_items+=( ".." )
        fi
        while IFS= read -r _bp_ent; do
            if [ "$_bp_mode" = "dir" ] && [ -d "$_bp_ent" ]; then
                _bp_items+=( "$_bp_ent" )
            elif [ "$_bp_mode" != "dir" ] && { [ -d "$_bp_ent" ] || \
                    { [ "$_bp_mode" = "file" ] || [[ "$_bp_ent" =~ \.(bmp|png|jpg|jpeg|qoi)$ ]]; }; }; then
                _bp_items+=( "$_bp_ent" )
            fi
        done < <(find "$_bp_start" -maxdepth 1 -mindepth 1 -printf '%p\n' 2>/dev/null | sort)
        if [ "${#_bp_items[@]}" -le 1 ]; then
            echo "  (nothing matching here)" >&2
        fi
        for _bp_i in "${!_bp_items[@]}"; do
            _bp_ent="${_bp_items[$_bp_i]}"
            if [ -d "$_bp_ent" ]; then
                echo "  ${C_BLU}${C_BOLD}$((_bp_i + 1))${C_RST}) ${_bp_ent##*/}/" >&2
            else
                echo "  ${C_BOLD}$((_bp_i + 1))${C_RST}) ${C_GRN}${_bp_ent##*/}${C_RST}" >&2
            fi
        done
        printf '\n%s' "${C_BOLD}${C_YLW}-- Select [dir | number | path ( .. = up, m = drives)]${C_RST} " >&2
        read -r _bp_src
        if [ -z "$_bp_src" ]; then
            echo "  Declined." >&2
            _bp_src=""
            break
        fi
        _bp_alias="${_bp_src#\\}"
        if [ "$_bp_alias" = ".." ]; then
            _bp_start="$(dirname "$_bp_start")"
            continue
        fi
        if [ "$_bp_alias" = "m" ] || [ "$_bp_alias" = "drives" ]; then
            if [ -d /run/media ]; then
                _bp_start="/run/media"
            else
                echo "  No /run/media on this live env — staying in ${_bp_start}." >&2
            fi
            continue
        fi
        if [ "$_bp_mode" = "dir" ] && { [ "$_bp_alias" = "!" ] || [ "$_bp_alias" = "ok" ]; }; then
            _bp_src="$_bp_start"
            _bp_ok=1
            continue
        fi
        if [[ "$_bp_src" =~ ^[0-9]+$ ]]; then
            _bp_i=$((_bp_src - 1))
            if [ "$_bp_i" -lt 0 ] || [ "$_bp_i" -ge "${#_bp_items[@]}" ]; then
                echo "  '$_bp_src' is not a valid choice." >&2
                continue
            fi
            _bp_src="${_bp_items[$_bp_i]}"
        fi
        if [ -d "$_bp_src" ]; then
            _bp_start="$_bp_src"
            continue
        fi
        if [ ! -f "$_bp_src" ]; then
            echo "  File not found: ${_bp_src:-<empty>}" >&2
            continue
        fi
        if [ "$_bp_mode" = "img" ]; then
            _bp_ext="${_bp_src##*.}"
            case "${_bp_ext,,}" in
                bmp|png|jpg|jpeg|qoi) ;;
                *) echo "  Unsupported extension '${_bp_ext}'. Use BMP/PNG/JPEG/QOI." >&2; continue ;;
            esac
        fi
        _bp_ok=1
    done
    printf '%s' "$_bp_src"
}

echo "=============================================================================="
echo " ${C_BOLD}${C_CYN}Void Linux Unified Installer${C_RST} — version ${C_BOLD}${SCRIPT_VERSION}${C_RST}"
echo " Bootloader: choose GRUB or Limine below — UEFI only, BIOS unsupported"
echo "=============================================================================="

cleanup_on_failure() {
    ec=$?

    {
        echo "############################################################"
        echo "# Void Linux Installer — FAILURE TRACE — $(date)"
        echo "############################################################"
        echo "Exit code       : ${ec}"
        echo "Failing command : ${BASH_COMMAND:-<unknown>}"
        echo "Stage context   : ${STAGE_CONTEXT:-<pre-stage>}"
        echo "Target disk     : ${DISK:-<not yet selected>}"
        echo "Partitions      : EFI=${PART_EFI:-<n/a>}  SYS=${PART_SYS:-<n/a>}"
        echo "Bootloader      : ${BOOTLOADER:-<n/a>}"
        echo "Desktop / DM    : ${DESKTOP_ENV:-<n/a>} / ${DISPLAY_MANAGER:-<n/a>}"
        echo "Resume record   : $([ -f "$STATE_FILE" ] && echo "PRESENT — resume with '-r'" || echo "absent (fresh install or pre-persist)")"
        echo "--- call stack (most recent first) ---"
        local _bs_i=0
        for ((_bs_i=0; _bs_i<${#FUNCNAME[@]}; _bs_i++)); do
            [ -n "${FUNCNAME[$_bs_i]-}" ] || continue
            printf '   %-28s at %s:%s\n' "${FUNCNAME[$_bs_i]}" "${BASH_SOURCE[$_bs_i]}" "${BASH_LINENO[$_bs_i]:-?}"
        done
        unset _bs_i
        echo "--- install timeline (most recent 30 entries) ---"
        tail -n 30 "$JOURNAL" 2>/dev/null || true
        echo "############################################################"
    } >> "$JOURNAL" 2>&1 || true
    echo "!! Install failed (exit $ec). Failure trace logged to ${JOURNAL}. Attempting best-effort unwind of /mnt..." >&2

    [ -f /mnt/etc/grub.d/41_snapshots-btrfs ] && chmod +x /mnt/etc/grub.d/41_snapshots-btrfs || true

    swapoff /mnt/var/swap/swapfile 2>/dev/null || true
    rm -f /mnt/tmp/chroot_env.sh 2>/dev/null || true
    shred -u /tmp/ssh-keygen/* /tmp/ssh-import/* 2>/dev/null || true
    rm -rf /tmp/ssh-keygen /tmp/ssh-import 2>/dev/null || true
    [ "$GRUB_ESP_BOOT" = "true" ] && umount -fl /mnt/boot 2>/dev/null || true
    umount -fl /mnt/boot/efi 2>/dev/null || true
    umount -fl /mnt/boot/grub 2>/dev/null || true
    umount -fl /mnt/dev 2>/dev/null || true
    umount -fl /mnt/proc 2>/dev/null || true
    umount -fl /mnt/sys 2>/dev/null || true
    umount -fl /mnt/run 2>/dev/null || true
    for m in var/swap var/spool var/log var/lib/libvirt var/lib/sddm var/lib/lightdm \
             var/lib/NetworkManager \
             var/cache srv opt .snapshots home; do
        umount -fl "/mnt/${m}" 2>/dev/null || true
    done
    umount -fl /mnt/tmp/xbps-cache 2>/dev/null || true
    umount -fl /mnt 2>/dev/null || true
    if [ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ]; then
        if command -v kpartx > /dev/null 2>&1; then
            kpartx -d "${CRYPT_DEV:-/dev/mapper/${CRYPT_NAME:-void-root}}" 2>/dev/null || partx -d "${CRYPT_DEV:-/dev/mapper/${CRYPT_NAME:-void-root}}" 2>/dev/null || true
        else
            partx -d "${CRYPT_DEV:-/dev/mapper/${CRYPT_NAME:-void-root}}" 2>/dev/null || true
        fi
    fi
    cryptsetup luksClose "${CRYPT_NAME:-void-root}" 2>/dev/null || true
    [ "$ENCRYPT" = "yes" ] && echo "!! Note: the LUKS mapper has been closed — the disk is now LOCKED." >&2
    echo "!! Unwind attempted. Re-check 'mount | grep /mnt' before re-running." >&2
    save_log_to_usb
    _usb_dumped=1
}
trap cleanup_on_failure ERR

sec_banner "STAGE 1" "Disk management and OS bootstrapping (outside chroot)"
STAGE_CONTEXT="STAGE1:setup"
jl "Begin Stage 1"

if ! ping -c1 -W3 xmirror.voidlinux.org >/dev/null 2>&1; then
    echo "FATAL: No network reachability (could not reach xmirror.voidlinux.org)." >&2
    echo "       Bring up networking (wpa_cli, dhcpcd, etc.) before running this script." >&2
    exit 1
fi


_local_cache_detect() {
    _lc_arch="$(uname -m)"
    while IFS= read -r _lc_dir; do
        [ -n "$_lc_dir" ] || continue
        [ -d "$_lc_dir" ] || continue
        case "$_lc_dir" in
            *"xbps-cachedir-${_lc_arch}") : ;;
            *) continue ;;
        esac
        [ -w "$_lc_dir" ] || continue
        [ -n "$(find "$_lc_dir" -maxdepth 1 -name '*.xbps' -print -quit 2>/dev/null)" ] || continue
        printf '%s\n' "$_lc_dir"
        return 0
    done < <(ls -1dt /run/media/*/xbps-cachedir-* /run/media/*/*/xbps-cachedir-* /xbps-cachedir-* 2>/dev/null || true)
    return 1
}
unset _lc_arch _lc_dir 2>/dev/null || true

if [ "$(id -u)" -ne 0 ]; then
    echo "${C_RED}!!!! CRITICAL:${C_RST} This script must be run as root (it partitions and formats a disk)." >&2
    echo "       Re-run it with sudo, or as the root user." >&2
    exit 1
fi

if [ -f "$STATE_FILE" ]; then
    echo ""
    echo "${C_YLW}!! An interrupted install was detected (state file present):${C_RST}"
    echo "   ${STATE_FILE}"
    _do_resume=0
    if [ "$AUTO_RESUME" = "1" ]; then
        _do_resume=1
    else
        ask "Resume the interrupted install using saved answers? [y/N]: "
        read -r _resume_ans
        case "$_resume_ans" in
            y|Y|yes|YES) _do_resume=1 ;;
        esac
    fi
    if [ "$_do_resume" = "1" ]; then
        . "$STATE_FILE"
        RESUME=1
        echo "==> Resuming install with saved configuration (skipping prompts & re-partition)."
    else
        echo "==> Starting a fresh install; removing the stale state file."
        rm -f "$STATE_FILE"
        RESUME=0
    fi
fi
unset _do_resume _resume_ans

if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ]; then
    if [ -n "${LOCAL_CACHE_DIR:-}" ] && [ -d "$LOCAL_CACHE_DIR" ] && [ -w "$LOCAL_CACHE_DIR" ]; then
        :
    else
        _lc_redetect=$(_local_cache_detect || true)
        if [ -n "$_lc_redetect" ]; then
            echo "==> Local package cache re-detected on resume: ${_lc_redetect}"
            LOCAL_CACHE_DIR="$_lc_redetect"
        else
            echo "!! Recorded local package cache is gone (or moved/mounted elsewhere);" >&2
            echo "   continuing with a network-only install." >&2
            LOCAL_CACHE_REUSE="no"
            LOCAL_CACHE_DIR=""
        fi
        unset _lc_redetect
    fi
fi
LOCAL_CA=""
[ "${LOCAL_CACHE_REUSE:-no}" = "yes" ] && [ -n "${LOCAL_CACHE_DIR:-}" ] && LOCAL_CA="-c $LOCAL_CACHE_DIR"
export LOCAL_CA

read_password_twice() {
    local prompt_label="$1"
    local __resultvar="$2"
    local pw1 pw2
    while true; do
        read -rsp "Enter ${prompt_label} password: " pw1; echo
        if [ "${#pw1}" -lt 8 ]; then
            echo "Password too short (minimum 8 characters)." >&2
            continue
        fi
        read -rsp "Confirm ${prompt_label} password: " pw2; echo
        if [ "$pw1" != "$pw2" ]; then
            echo "Passwords did not match, try again." >&2
            continue
        fi
        break
    done
    printf -v "$__resultvar" '%s' "$pw1"
    pw1=""; pw2=""
}

_region_carved() {
    case " ${REGION_PARTITIONED:-} " in
        *" $1 "*) return 0 ;;
        *)        return 1 ;;
    esac
}
_region_fs_of() {
    local _rfv
    if [ "$1" = "games" ]; then
        _rfv="REGION_GAMES"
    else
        _rfv="REGION_${1^^}_FS"
    fi
    printf '%s' "${!_rfv:-btrfs}"
}

detect_wired_nic() {
    local _dn_if _dn_name
    for _dn_if in /sys/class/net/*; do
        [ -e "$_dn_if/device" ] || continue
        [ -d "$_dn_if/wireless" ] && continue
        _dn_name="${_dn_if##*/}"
        case "$_dn_name" in
            lo|ww*|wl*|bn*|bt*|dm-*) continue ;;
        esac
        if [ "$(cat "$_dn_if/carrier" 2>/dev/null || echo 0)" = "1" ]; then
            printf '%s\n' "$_dn_name"
            return 0
        fi
    done
    for _dn_if in /sys/class/net/*; do
        [ -e "$_dn_if/device" ] || continue
        [ -d "$_dn_if/wireless" ] && continue
        _dn_name="${_dn_if##*/}"
        case "$_dn_name" in
            lo|ww*|wl*|bn*|bt*|dm-*) continue ;;
        esac
        case "$(readlink -f "$_dn_if/device" 2>/dev/null || :)" in
            *usb*) printf '%s\n' "$_dn_name"; return 0 ;;
        esac
    done
    return 1
}

has_wired_nic_hw() {
    local _hw_if _hw_name
    for _hw_if in /sys/class/net/*; do
        [ -e "$_hw_if/device" ] || continue
        [ -d "$_hw_if/wireless" ] && continue
        _hw_name="${_hw_if##*/}"
        case "$_hw_name" in
            lo|ww*|wl*|bn*|bt*|dm-*) continue ;;
        esac
        return 0
    done
    return 1
}

if [ "$RESUME" != "1" ]; then
echo ""
echo "${C_BOLD}${C_BLU}Account privilege model${C_RST}"
echo "  ${C_BOLD}1)${C_RST} Hybrid — root has a password AND your user gets full sudo access"
echo "  ${C_BOLD}2)${C_RST} Debian-style — root has a password; your user is NOT in sudo (su - only)"
echo "  ${C_BOLD}3)${C_RST} Ubuntu-style — root is locked; your user gets full sudo access (your own password)"
while true; do
    ask "Enter choice [1/2/3]: "
    read -r ACCOUNT_MODEL_INPUT
    case "$ACCOUNT_MODEL_INPUT" in
        1) ACCOUNT_MODEL="hybrid"; break ;;
        2) ACCOUNT_MODEL="debian"; break ;;
        3) ACCOUNT_MODEL="ubuntu"; break ;;
        *) echo "Please enter 1, 2, or 3." >&2 ;;
    esac
done
export ACCOUNT_MODEL

echo ""
echo "${C_BOLD}${C_BLU}Login shell${C_RST}"
echo "  ${C_BOLD}1)${C_RST} bash  (default; included in base-system)"
echo "  ${C_BOLD}2)${C_RST} zsh"
echo "  ${C_BOLD}3)${C_RST} fish"
echo "  ${C_BOLD}4)${C_RST} mksh"
while true; do
    ask "Enter choice [1-4, default ${DEFAULT_LOGIN_SHELL}]: "
    read -r USER_SHELL_INPUT
    USER_SHELL_INPUT="${USER_SHELL_INPUT:-$DEFAULT_LOGIN_SHELL}"
    case "$USER_SHELL_INPUT" in
        ""|1) USER_SHELL="/bin/bash";  USER_SHELL_PKG="";       break ;;
        2)    USER_SHELL="/bin/zsh";   USER_SHELL_PKG="zsh";    break ;;
        3)    USER_SHELL="/usr/bin/fish"; USER_SHELL_PKG="fish-shell"; break ;;
        4)    USER_SHELL="/bin/mksh";  USER_SHELL_PKG="mksh";   break ;;
        *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
    esac
done
export USER_SHELL USER_SHELL_PKG

if [ "$ACCOUNT_MODEL" != "ubuntu" ]; then
    read_password_twice "root" ROOT_PASSWORD
else
    ROOT_PASSWORD=""
fi

echo ""
echo "${C_BOLD}${C_BLU}System identity${C_RST}"
while true; do
    ask "Enter the username to create on the target system: "
    read -r TARGET_USER
    if [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        break
    fi
    echo "Invalid username. Use lowercase letters, digits, '_' or '-', starting with a letter or '_'." >&2
done
export TARGET_USER

echo ""
ask "Enter the full name of $TARGET_USER (e.g., 'John Doe'): "
read -r TARGET_FULL_NAME
export TARGET_FULL_NAME

read_password_twice "${TARGET_USER}" TARGET_USER_PASSWORD

while true; do
    ask "Enter target system hostname (e.g., myhostname): "
    read -r TARGET_HOSTNAME
    if [[ "$TARGET_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$ ]]; then
        break
    fi
    echo "Invalid hostname. Use letters, digits, or '-' characters only." >&2
done
export TARGET_HOSTNAME

while true; do
    while true; do
        ask "Enter network domain name (e.g., example.com) to form a FQDN (optional, press Enter to skip): "
        read -r TARGET_DOMAIN
        if [ -z "$TARGET_DOMAIN" ] || [[ "$TARGET_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
            break
        fi
        echo "Invalid domain. Use dot-separated labels of letters, digits, or '-' (e.g., example.com)." >&2
    done

    if [ -n "$TARGET_DOMAIN" ]; then
        TARGET_FQDN="${TARGET_HOSTNAME}.${TARGET_DOMAIN}"
    else
        TARGET_FQDN="${TARGET_HOSTNAME}"
    fi

    ask "This system's FQDN will be: ${C_BOLD}${C_CYN}${TARGET_FQDN}${C_RST} — is this correct? [Y/n]: "
    read -r FQDN_CONFIRM
    case "$FQDN_CONFIRM" in
        [nN]*) continue ;;
        *) break ;;
    esac
done
export TARGET_DOMAIN
export TARGET_FQDN

echo ""
echo "${C_BOLD}${C_BLU}Language / locale${C_RST} (system language; default en_US.UTF-8)"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}en_US.UTF-8 (English / US) — default${C_RST}"
echo "  ${C_BOLD}2)${C_RST} en_GB.UTF-8 (English / UK)"
echo "  ${C_BOLD}3)${C_RST} de_DE.UTF-8 (German / Germany)"
echo "  ${C_BOLD}4)${C_RST} es_ES.UTF-8 (Spanish / Spain)"
echo "  ${C_BOLD}5)${C_RST} fr_FR.UTF-8 (French / France)"
echo "  ${C_BOLD}6)${C_RST} it_IT.UTF-8 (Italian / Italy)"
echo "  ${C_BOLD}7)${C_RST} pt_PT.UTF-8 (Portuguese / Portugal)"
echo "  ${C_BOLD}8)${C_RST} nl_NL.UTF-8 (Dutch / Netherlands)"
echo "  ${C_BOLD}9)${C_RST} ru_RU.UTF-8 (Russian)"
echo "  ${C_BOLD}10)${C_RST} ja_JP.UTF-8 (Japanese)"
echo "  ${C_BOLD}11)${C_RST} zh_CN.UTF-8 (Chinese / Simplified)"
echo "  ${C_BOLD}12)${C_RST} Custom (type a POSIX locale, e.g. pl_PL.UTF-8)"
while true; do
    ask "Enter locale choice [1-12, default ${DEFAULT_LOCALE}]: "
    read -r LOCALE_INPUT
    case "${LOCALE_INPUT:-$DEFAULT_LOCALE}" in
        1)  LOCALE="en_US.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        2)  LOCALE="en_GB.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        3)  LOCALE="de_DE.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        4)  LOCALE="es_ES.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        5)  LOCALE="fr_FR.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        6)  LOCALE="it_IT.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        7)  LOCALE="pt_PT.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        8)  LOCALE="nl_NL.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        9)  LOCALE="ru_RU.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        10) LOCALE="ja_JP.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        11) LOCALE="zh_CN.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        12)
            ask "Type the locale (e.g. pl_PL.UTF-8): "
            read -r LOCALE
            if [ -z "$LOCALE" ] || ! [[ "$LOCALE" =~ ^[a-z]{2,3}_[A-Z]{2}([.@][A-Za-z0-9-]+)?$ ]]; then
                echo "Invalid locale; falling back to en_US.UTF-8." >&2
                LOCALE="en_US.UTF-8"
            fi
            case "$LOCALE" in
                *.UTF-8)        LOCALE_CODESET="UTF-8" ;;
                *ISO-8859-1)    LOCALE_CODESET="ISO-8859-1" ;;
                *)              LOCALE_CODESET="UTF-8" ;;
            esac
            break ;;
        *) echo "Please enter a number 1-12." >&2 ;;
    esac
done
export LOCALE LOCALE_CODESET

echo ""
echo "${C_BOLD}${C_BLU}Timezone${C_RST} (system time zone; default America/New_York)"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}America/New_York — default${C_RST}"
echo "  ${C_BOLD}2)${C_RST} America/Chicago"
echo "  ${C_BOLD}3)${C_RST} America/Denver"
echo "  ${C_BOLD}4)${C_RST} America/Los_Angeles"
echo "  ${C_BOLD}5)${C_RST} America/Sao_Paulo"
echo "  ${C_BOLD}6)${C_RST} Europe/London"
echo "  ${C_BOLD}7)${C_RST} Europe/Paris"
echo "  ${C_BOLD}8)${C_RST} Europe/Berlin"
echo "  ${C_BOLD}9)${C_RST} Europe/Madrid"
echo "  ${C_BOLD}10)${C_RST} Europe/Rome"
echo "  ${C_BOLD}11)${C_RST} Europe/Moscow"
echo "  ${C_BOLD}12)${C_RST} Asia/Tokyo"
echo "  ${C_BOLD}13)${C_RST} Asia/Shanghai"
echo "  ${C_BOLD}14)${C_RST} Asia/Kolkata"
echo "  ${C_BOLD}15)${C_RST} Custom (type an IANA zone, e.g. Australia/Sydney)"
while true; do
    ask "Enter timezone choice [1-15, default ${DEFAULT_TIMEZONE}]: "
    read -r TZ_INPUT
    case "${TZ_INPUT:-$DEFAULT_TIMEZONE}" in
        1)  TIMEZONE="America/New_York"; break ;;
        2)  TIMEZONE="America/Chicago"; break ;;
        3)  TIMEZONE="America/Denver"; break ;;
        4)  TIMEZONE="America/Los_Angeles"; break ;;
        5)  TIMEZONE="America/Sao_Paulo"; break ;;
        6)  TIMEZONE="Europe/London"; break ;;
        7)  TIMEZONE="Europe/Paris"; break ;;
        8)  TIMEZONE="Europe/Berlin"; break ;;
        9)  TIMEZONE="Europe/Madrid"; break ;;
        10) TIMEZONE="Europe/Rome"; break ;;
        11) TIMEZONE="Europe/Moscow"; break ;;
        12) TIMEZONE="Asia/Tokyo"; break ;;
        13) TIMEZONE="Asia/Shanghai"; break ;;
        14) TIMEZONE="Asia/Kolkata"; break ;;
        15)
            ask "Type timezone (e.g. Australia/Sydney, or UTC): "
            read -r TIMEZONE
            if [ -z "$TIMEZONE" ] || ! [[ "$TIMEZONE" =~ ^[A-Za-z_]+(/[A-Za-z_/+-]+)?$ ]]; then
                echo "Invalid timezone; falling back to America/New_York." >&2
                TIMEZONE="America/New_York"
            fi
            break ;;
        *) echo "Please enter a number 1-15." >&2 ;;
    esac
done
export TIMEZONE

case "$TIMEZONE" in
    America/Sao_Paulo|America/Argentina/*|America/La_Paz|America/Bogota|America/Lima|America/Caracas|America/Santiago|America/Buenos_Aires|America/Mexico_City)
        MIRROR_REGION="south-america"; MIRROR_AUTO="https://void.voidbr.org/voidlinux/current" ;;
    America/*|Canada/*)
        MIRROR_REGION="north-america"; MIRROR_AUTO="https://mirrors.summithq.com/voidlinux/current" ;;
    Europe/*)
        MIRROR_REGION="europe"; MIRROR_AUTO="https://repo-de.voidlinux.org/current" ;;
    Asia/*|Indian/*)
        MIRROR_REGION="asia"; MIRROR_AUTO="https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current" ;;
    Australia/*|Pacific/*)
        MIRROR_REGION="oceania"; MIRROR_AUTO="https://mirror.aarnet.edu.au/pub/voidlinux/current" ;;
    *)
        MIRROR_REGION="global"; MIRROR_AUTO="https://repo-default.voidlinux.org/current" ;;
esac
export MIRROR_REGION

echo ""
echo "${C_BOLD}${C_BLU}Official repo mirror${C_RST} (regional selection from xmirror.voidlinux.org)"
echo "  Auto-selected region for timezone '${TIMEZONE}': ${C_BOLD}${MIRROR_REGION}${C_RST}"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}Auto (region-based) — ${MIRROR_AUTO}${C_RST}"
echo "  ${C_BOLD}2)${C_RST} Global Fastly CDN — https://repo-fastly.voidlinux.org/current"
echo "  ${C_BOLD}3)${C_RST} Global default (tier-1) — https://repo-default.voidlinux.org/current"
echo "  ${C_BOLD}4)${C_RST} North America — https://mirrors.summithq.com/voidlinux/current"
echo "  ${C_BOLD}5)${C_RST} Europe (Germany) — https://repo-de.voidlinux.org/current"
echo "  ${C_BOLD}6)${C_RST} Asia (China) — https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current"
echo "  ${C_BOLD}7)${C_RST} Oceania (Australia) — https://mirror.aarnet.edu.au/pub/voidlinux/current"
echo "  ${C_BOLD}8)${C_RST} South/Central America (Brazil) — https://void.voidbr.org/voidlinux/current"
while true; do
    ask "Enter mirror choice [1-8, default 1]: "
    read -r MIRROR_INPUT
    case "${MIRROR_INPUT:-1}" in
        1)  REPO_PRIMARY="$MIRROR_AUTO"; break ;;
        2)  REPO_PRIMARY="https://repo-fastly.voidlinux.org/current"; break ;;
        3)  REPO_PRIMARY="https://repo-default.voidlinux.org/current"; break ;;
        4)  REPO_PRIMARY="https://mirrors.summithq.com/voidlinux/current"; break ;;
        5)  REPO_PRIMARY="https://repo-de.voidlinux.org/current"; break ;;
        6)  REPO_PRIMARY="https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current"; break ;;
        7)  REPO_PRIMARY="https://mirror.aarnet.edu.au/pub/voidlinux/current"; break ;;
        8)  REPO_PRIMARY="https://void.voidbr.org/voidlinux/current"; break ;;
        *) echo "Please enter a number 1-8." >&2 ;;
    esac
done
export REPO_PRIMARY
REPO_BACKUP1="https://repo-fastly.voidlinux.org/current"
REPO_BACKUP2="https://repo-default.voidlinux.org/current"
export REPO_BACKUP1 REPO_BACKUP2

AUTO_LOCAL_CACHE=$(_local_cache_detect || true)
LOCAL_CACHE_REUSE="${LOCAL_CACHE_REUSE:-no}"
LOCAL_CACHE_DIR="${LOCAL_CACHE_DIR:-}"
echo ""
echo "${C_BOLD}${C_BLU}Local package cache${C_RST} — reuse already-downloaded XBPS packages instead of re-fetching."
if [ -n "$AUTO_LOCAL_CACHE" ]; then
    echo "  Auto-detected cache on an attached medium: ${C_GRN}${AUTO_LOCAL_CACHE}${C_RST}"
else
    echo "  No mklive-style xbps-cachedir-<arch> cache detected under /run/media."
    echo "  (Place one at <mount>/xbps-cachedir-$(uname -m), or type its absolute path below.)"
fi
ask "Use a local package cache? [y/N] or type an absolute path: "
read -r LOCAL_CACHE_INPUT
case "${LOCAL_CACHE_INPUT:-$DEFAULT_LOCAL_CACHE}" in
    /* )
        if [ -d "$LOCAL_CACHE_INPUT" ] && [ -w "$LOCAL_CACHE_INPUT" ]; then
            LOCAL_CACHE_REUSE="yes"
            LOCAL_CACHE_DIR="$LOCAL_CACHE_INPUT"
        else
            echo "  Path not usable (not a directory, or not writable): ${LOCAL_CACHE_INPUT}" >&2
            LOCAL_CACHE_REUSE="no"
            LOCAL_CACHE_DIR=""
        fi
        ;;
    y|Y|yes|YES)
        LOCAL_CACHE_REUSE="yes"
        if [ -n "$AUTO_LOCAL_CACHE" ] && [ -d "$AUTO_LOCAL_CACHE" ]; then
            LOCAL_CACHE_DIR="$AUTO_LOCAL_CACHE"
        else
            echo "  No cache auto-detected. Place one at <mount>/xbps-cachedir-$(uname -m) on the" >&2
            echo "  medium, or answer with its absolute path instead." >&2
            LOCAL_CACHE_DIR=""
        fi
        ;;
    *)
        LOCAL_CACHE_REUSE="no"
        LOCAL_CACHE_DIR=""
        ;;
esac
if [ "$LOCAL_CACHE_REUSE" = "yes" ] && { [ -z "$LOCAL_CACHE_DIR" ] || [ ! -d "$LOCAL_CACHE_DIR" ] || [ ! -w "$LOCAL_CACHE_DIR" ]; }; then
    echo "!! Local package cache unusable; falling back to a network-only install." >&2
    LOCAL_CACHE_REUSE="no"
    LOCAL_CACHE_DIR=""
fi
if [ "$LOCAL_CACHE_REUSE" = "yes" ]; then
    echo "==> Package cache enabled: ${LOCAL_CACHE_DIR} (mirror fallback stays armed)."
fi
export LOCAL_CACHE_REUSE LOCAL_CACHE_DIR
LOCAL_CA=""
[ "$LOCAL_CACHE_REUSE" = "yes" ] && [ -n "$LOCAL_CACHE_DIR" ] && LOCAL_CA="-c $LOCAL_CACHE_DIR"
export LOCAL_CA
unset LOCAL_CACHE_INPUT AUTO_LOCAL_CACHE

echo ""
echo "${C_BOLD}${C_BLU}Swap configuration${C_RST} (swap backend; default swapfile)"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}swapfile (default)${C_RST} — Btrfs swapfile at /var/swap (4G basic, or RAM+25% if hibernation), supports hibernation."
echo "  ${C_BOLD}2)${C_RST} zram — compressed in-RAM swap (module zram, no disk footprint; cannot hibernate)."
echo "  ${C_BOLD}3)${C_RST} swapfile + zram — both, for extra headroom."
echo "  ${C_BOLD}4)${C_RST} none — no swap at all."
while true; do
    ask "Enter swap choice [1-4, default ${DEFAULT_SWAP_BACKEND}]: "
    read -r SWAP_INPUT
    case "${SWAP_INPUT:-$DEFAULT_SWAP_BACKEND}" in
        1) SWAP_BACKEND="swapfile"; break ;;
        2) SWAP_BACKEND="zram"; break ;;
        3) SWAP_BACKEND="both"; break ;;
        4) SWAP_BACKEND="none"; break ;;
        *) echo "Please enter a number 1-4." >&2 ;;
    esac
done
export SWAP_BACKEND
if [ "$SWAP_BACKEND" = "swapfile" ] || [ "$SWAP_BACKEND" = "both" ]; then
    SWAPFILE_MODE="true"
else
    SWAPFILE_MODE="false"
fi

if [ "$SWAPFILE_MODE" = "true" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Hibernation${C_RST} (resume-from-disk; needs the swapfile to hold RAM; default No)"
    ask "Enable hibernation (suspend-to-disk)? [y/N]: "
    read -r HIB_INPUT
    case "$HIB_INPUT" in
        "")     ENABLE_HIBERNATION="$DEFAULT_HIBERNATION" ;;
        [yY]*) ENABLE_HIBERNATION="true" ;;
        *)     ENABLE_HIBERNATION="false" ;;
    esac
else
    ENABLE_HIBERNATION="false"
fi
export ENABLE_HIBERNATION

if [ "$ENABLE_HIBERNATION" = "true" ]; then
    _RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    _RAM_MB=${_RAM_MB:-8192}
    if [ "${_RAM_MB}" -le 0 ] 2>/dev/null || ! [[ "${_RAM_MB}" =~ ^[0-9]+$ ]]; then
        _RAM_MB=8192
    fi
    _RAM_GB=$(( (_RAM_MB + 1023) / 1024 ))
    _SWAP_GB=$(( (_RAM_GB * 5 + 3) / 4 ))
    SWAPFILE_SIZE="${_SWAP_GB}g"
    unset _RAM_MB _RAM_GB _SWAP_GB
elif [ "$SWAPFILE_MODE" = "true" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Swapfile size${C_RST} (no hibernation; default 4G)"
    echo "  ${C_BOLD}1)${C_RST} ${C_GRN}4G (default)${C_RST}"
    echo "  ${C_BOLD}2)${C_RST} 2G"
    while true; do
        ask "Enter swapfile size choice [1-2, default 1]: "
        read -r SZ_INPUT
        case "${SZ_INPUT:-1}" in
            1) SWAPFILE_SIZE="4g"; break ;;
            2) SWAPFILE_SIZE="2g"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
else
    SWAPFILE_SIZE=""
fi
export SWAPFILE_SIZE

if [ ! -d /sys/firmware/efi ]; then
    echo "FATAL: this machine does not appear to be booted in UEFI mode." >&2
    echo "       This installer only supports UEFI boot (GRUB and Limine" >&2
    echo "       are both installed via their UEFI paths) — BIOS is not" >&2
    echo "       implemented." >&2
    exit 1
fi

 echo ""
 echo "${C_BOLD}${C_BLU}Choose bootloader${C_RST}  (default: Limine)"
 echo "  ${C_BOLD}1)${C_RST} ${C_GRN}Limine${C_RST} — newer, simpler, single-file UEFI bootloader with no"
 echo "     efibootmgr/NVRAM dependency. Snapshot-boot menu support is a"
 echo "     static config this script writes itself (with the snapper plugin"
 echo "     auto-regenerating it on every snapshot create/delete). Requires"
 echo "     a 4GiB+ EFI partition (ArchWiki's own recommendation for"
 echo "     bootable snapshots, kernel versions, and large early-boot"
 echo "     modules)."
echo "  ${C_BOLD}2)${C_RST} ${C_YLW}GRUB${C_RST} — mature, battle-tested snapshot-boot support via"
  echo "     grub-btrfs. Extensively real-hardware tested on this script's"
  echo "     3.0.x line, including snapshot boot. 1GiB EFI partition."
  echo "     ${C_RED}NOTE: if you then enable full-disk encryption (next prompt), GRUB's"
 echo "     LUKS cryptodisk is bypassed entirely — the ESP is mounted AT /boot so"
 echo "     grub.cfg + kernels stay unencrypted and GRUB never unlocks the disk"
 echo "     (dracut prompts once, after handoff). The ESP grows to 4GiB in that"
 echo "     combo to hold every kernel/initramfs. YubiKey-only unlock still"
 echo "     clamps to passphrase-fallback on GRUB per [YUBIKEY].${C_RST}"
 while true; do
     _boot_default="Limine"
     [ "$DEFAULT_BOOTLOADER" = "2" ] && _boot_default="GRUB"
     ask "Enter choice [1/2] (default ${DEFAULT_BOOTLOADER}: ${_boot_default}): "
     read -r BOOTLOADER_INPUT
     case "${BOOTLOADER_INPUT:-$DEFAULT_BOOTLOADER}" in
         1) BOOTLOADER="limine"
            esp_size_choose
            break ;;
         2) BOOTLOADER="grub"
            EFI_PART_SIZE="1G"
            break ;;
         *) echo "Please enter 1 or 2." >&2 ;;
     esac
 done
export BOOTLOADER
export EFI_PART_SIZE

INSTALL_KERNEL_MAINLINE="${DEFAULT_KERNEL_MAINLINE}"
INSTALL_KERNEL_LTS="${DEFAULT_KERNEL_LTS}"
echo ""
echo "${C_BOLD}${C_BLU}Kernel packages${C_RST}"
echo "  The base rolling kernel (linux) is always installed. You can add:"
echo "  ${C_BOLD}linux-mainline${C_RST} — newest features, shortest support window (Void: \"for experts only\")."
echo "  ${C_BOLD}linux-lts${C_RST}      — Long Term Support; most conservative, longest window; best for servers."
while true; do
    ask "${C_GRN}Also install linux-mainline?${C_RST} [y/N]: "
    read -r K_MAINLINE
    case "${K_MAINLINE,,}" in
        y|yes) INSTALL_KERNEL_MAINLINE=true; break ;;
        ""|n|no) INSTALL_KERNEL_MAINLINE=false; break ;;
        *) echo "Please enter y or n." >&2 ;;
    esac
done
while true; do
    ask "${C_GRN}Also install linux-lts?${C_RST} [Y/n]: "
    read -r K_LTS
    case "${K_LTS,,}" in
        ""|y|yes) INSTALL_KERNEL_LTS=true; break ;;
        n|no) INSTALL_KERNEL_LTS=false; break ;;
        *) echo "Please enter y or n." >&2 ;;
    esac
done
KERNEL_PKGS="linux"
[ "$INSTALL_KERNEL_MAINLINE" = "true" ] && KERNEL_PKGS="$KERNEL_PKGS linux-mainline"
[ "$INSTALL_KERNEL_LTS" = "true" ] && KERNEL_PKGS="$KERNEL_PKGS linux-lts"
export INSTALL_KERNEL_MAINLINE INSTALL_KERNEL_LTS KERNEL_PKGS
echo "  Resolved kernel set: ${KERNEL_PKGS}"

DEVICE_PROFILE=""
PROFILE_TLP="false"
PROFILE_BT="false"
PROFILE_PRELOAD="false"
echo ""
echo "${C_BOLD}${C_BLU}Device profile${C_RST}"
echo "  What kind of machine is this? Gates tlp (battery power management),"
echo "  the bluetooth stack, and preload (adaptive readahead cache):"
echo "  ${C_BOLD}1)${C_RST} Automatic (default) — probe chassis + bluetooth hardware, then confirm/override"
echo "  ${C_BOLD}2)${C_RST} Laptop with Bluetooth"
echo "  ${C_BOLD}3)${C_RST} Laptop, no Bluetooth"
echo "  ${C_BOLD}4)${C_RST} Desktop/server with Bluetooth"
echo "  ${C_BOLD}5)${C_RST} Desktop/server, no Bluetooth"
_bt_hw="no"
for _m in /sys/bus/usb/devices/*/modalias /sys/bus/usb/devices/*/*/modalias; do
    [ -r "$_m" ] || continue
    if grep -qi 'icE0isc01ip01' "$_m"; then _bt_hw="yes"; break; fi
done
if [ "$_bt_hw" = "yes" ]; then
    echo "  Bluetooth hardware probe: controller detected"
else
    echo "  Bluetooth hardware probe: no Bluetooth controller found"
fi
_cc="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)"
_auto_device_profile=""
while true; do
    ask "Enter choice [1/2/3/4/5] (default ${DEFAULT_DEVICE_PROFILE}: Automatic): "
    read -r DP_INPUT
    case "${DP_INPUT:-$DEFAULT_DEVICE_PROFILE}" in
        1)
            case "$_cc" in
                8|9|10|11|14|30|31|32) DEVICE_PROFILE="laptop-bt" ;;
                3|4|5|6|7|13|15) DEVICE_PROFILE="desktop-bt" ;;
                *) DEVICE_PROFILE="laptop-bt" ;;
            esac
            [ "$_bt_hw" = "yes" ] && case "$DEVICE_PROFILE" in
                desktop*) DEVICE_PROFILE="desktop-bt" ;;
                *) DEVICE_PROFILE="laptop-bt" ;;
            esac
            case "$_bt_hw" in
                no) case "$DEVICE_PROFILE" in
                        desktop*) DEVICE_PROFILE="desktop" ;;
                        *) DEVICE_PROFILE="laptop" ;;
                    esac ;;
            esac
            show_profile() {
                case "$DEVICE_PROFILE" in
                    laptop-bt)  _dp_desc="Laptop with Bluetooth" ;;
                    laptop)     _dp_desc="Laptop, no Bluetooth" ;;
                    desktop-bt) _dp_desc="Desktop/server with Bluetooth" ;;
                    desktop)    _dp_desc="Desktop/server, no Bluetooth" ;;
                esac
                echo "  Detected profile: ${DEVICE_PROFILE} (${_dp_desc})"
            }
            show_profile
            while true; do
                ask "   Keep this profile? [Y/n] or pick 2-5 to override: "
                read -r DP_CONFIRM
                case "${DP_CONFIRM:-y}" in
                    y|Y|yes|YES) break ;;
                    n|N|no|NO)
                        echo "  Overriding — pick an explicit profile from the menu (2-5)." >&2 ;;
                    2) DEVICE_PROFILE="laptop-bt"; show_profile; break ;;
                    3) DEVICE_PROFILE="laptop"; show_profile; break ;;
                    4) DEVICE_PROFILE="desktop-bt"; show_profile; break ;;
                    5) DEVICE_PROFILE="desktop"; show_profile; break ;;
                    *) echo "  Please enter y to keep, or 2-5 to override." >&2 ;;
                esac
            done
            unset DP_CONFIRM _dp_desc
            unset -f show_profile
            break ;;
        2) DEVICE_PROFILE="laptop-bt"; break ;;
        3) DEVICE_PROFILE="laptop"; break ;;
        4) DEVICE_PROFILE="desktop-bt"; break ;;
        5) DEVICE_PROFILE="desktop"; break ;;
        *) echo "Please enter 1-5." >&2 ;;
    esac
done
case "$DEVICE_PROFILE" in
    laptop-bt) PROFILE_TLP=true;  PROFILE_BT=true;  PROFILE_PRELOAD=false ;;
    laptop)    PROFILE_TLP=true;  PROFILE_BT=false; PROFILE_PRELOAD=false ;;
    desktop-bt)PROFILE_TLP=false; PROFILE_BT=true;  PROFILE_PRELOAD=true ;;
    desktop)   PROFILE_TLP=false; PROFILE_BT=false; PROFILE_PRELOAD=true ;;
esac
unset _bt_hw _cc
export DEVICE_PROFILE PROFILE_TLP PROFILE_BT PROFILE_PRELOAD
echo "  Resolved profile: ${DEVICE_PROFILE} (tlp=${PROFILE_TLP} bluetooth=${PROFILE_BT} preload=${PROFILE_PRELOAD})"

GPU_FAMILIES=""
HAS_NVIDIA_GPU="no"
HAS_AMD_GPU="no"
HAS_INTEL_GPU="no"
for _pci in /sys/bus/pci/devices/*/class; do
    [ -r "$_pci" ] || continue
    _class="$(cat "$_pci" 2>/dev/null || true)"
    case "$_class" in
        0x03*) ;;
        *) continue ;;
    esac
    _dev="${_pci%/class}"
    _vid="$(cat "$_dev/vendor" 2>/dev/null || true)"
    case "$_vid" in
        0x10de) _fam="NVIDIA" ;;
        0x1002) _fam="AMD" ;;
        0x8086) _fam="Intel" ;;
        0x1a03) _fam="ASPEED (BMC)" ;;
        0x15ad) _fam="VMware" ;;
        0x1234) _fam="QEMU" ;;
        *) _fam="Other" ;;
    esac
    case " $GPU_FAMILIES " in
        *" $_fam "*) : ;;
        *) GPU_FAMILIES="${GPU_FAMILIES:+${GPU_FAMILIES} }${_fam}" ;;
    esac
    case "$_vid" in
        0x10de) HAS_NVIDIA_GPU="yes" ;;
        0x1002) HAS_AMD_GPU="yes" ;;
        0x8086) HAS_INTEL_GPU="yes" ;;
    esac
done
unset _pci _class _dev _vid _fam
WIFI_HW="no"
if ls /sys/class/ieee80211/ >/dev/null 2>&1 && [ -n "$(ls -A /sys/class/ieee80211/ 2>/dev/null)" ]; then
    WIFI_HW="yes"
fi
echo "  Hardware probe: GPU='${GPU_FAMILIES:-<none detected>}'  wireless=${WIFI_HW}"

if [ "$DEFAULT_INSTALL_NVIDIA" = "auto" ]; then
    if [ "$HAS_NVIDIA_GPU" = "yes" ]; then
        _nvidia_default="y"
        _nvidia_prompt="[Y/n]"
    else
        _nvidia_default="n"
        _nvidia_prompt="[y/N]"
    fi
else
    _nvidia_default="$(printf '%s' "$DEFAULT_INSTALL_NVIDIA" | tr '[:upper:]' '[:lower:]')"
    _nvidia_prompt="[${_nvidia_default}?]"
fi
INSTALL_NVIDIA="false"
while true; do
    ask "Install the NVIDIA proprietary driver? ${_nvidia_prompt}: "
    read -r INSTALL_NVIDIA_INPUT
    case "${INSTALL_NVIDIA_INPUT:-$_nvidia_default}" in
        y|Y|yes|YES) INSTALL_NVIDIA="true"; break ;;
        n|N|no|NO) INSTALL_NVIDIA="false"; break ;;
        *) echo "Please answer y or n." >&2 ;;
    esac
done
unset _nvidia_default _nvidia_prompt INSTALL_NVIDIA_INPUT
if [ "$INSTALL_NVIDIA" = "true" ] && [ "$HAS_NVIDIA_GPU" != "yes" ]; then
    echo "  WARNING: no NVIDIA GPU detected on this machine — the proprietary"
    echo "  driver will be installed anyway (ignored by the Intel/AMD GPU)." >&2
fi
echo "  NVIDIA driver: ${INSTALL_NVIDIA} (GPU: ${GPU_FAMILIES:-<none detected>})"
export INSTALL_NVIDIA GPU_FAMILIES HAS_NVIDIA_GPU HAS_AMD_GPU HAS_INTEL_GPU WIFI_HW

MICROCODE_PKG=""
MICROCODE_DECIDED="yes"
if [ "$DEFAULT_MICROCODE" = "no" ]; then
    _cpu_line="SKIPPED (DEFAULT_MICROCODE=no)"
else
    _cpu_vendor="$(awk -F: '/^vendor_id/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | tr -d '[:space:]' || true)"
    case "$_cpu_vendor" in
        GenuineIntel)
            MICROCODE_PKG="intel-ucode"
            _cpu_line="GenuineIntel"
            ;;
        AuthenticAMD)
            MICROCODE_PKG="linux-firmware-amd"
            _cpu_line="AuthenticAMD"
            ;;
        *)
            _cpu_line="$_cpu_vendor"
            ;;
    esac
    unset _cpu_vendor
    if [ -n "$MICROCODE_PKG" ]; then
        _cpu_line="$_cpu_line — microcode: ${MICROCODE_PKG} (auto-installed)"
    else
        if [ -n "$_cpu_line" ]; then
            _cpu_line="$_cpu_line — no vendor microcode package (in-kernel defaults)"
        else
            _cpu_line="<vendor unreadable> — no vendor microcode package (in-kernel defaults)"
        fi
    fi
fi
echo "  Detected CPU : ${_cpu_line}"
unset _cpu_line

_NIC_NAME=""
if [ -n "$DEFAULT_NIC" ]; then
    _NIC_NAME="$DEFAULT_NIC"
else
    _NIC_NAME="$(detect_wired_nic || true)"
fi
if [ -n "$_NIC_NAME" ]; then
    echo "  Detected wired NIC : $_NIC_NAME (feeds the bridged VM network if you choose virtualization)"
    while true; do
        ask "Keep this interface? [Y/n] or type another name: "
        read -r _nic_input
        case "${_nic_input:-y}" in
            y|Y|yes|YES) break ;;
            n|N|no|NO) _NIC_NAME=""; break ;;
            *) _NIC_NAME="$_nic_input"; break ;;
        esac
    done
else
    echo "  Detected wired NIC : (none detected — late re-probe will decide if you choose virtualization)"
fi
BR0_NIC="$_NIC_NAME"
unset _NIC_NAME _nic_input
echo "  Bridged-VM NIC : ${BR0_NIC:-<not set>}"
export BR0_NIC

WIFI_IDS=""
WIFI_CHIPS=""
WIFI_FW_PKG=""
INSTALL_WIFI_FW="false"
for _phy in /sys/class/ieee80211/phy*/device; do
    [ -e "$_phy" ] || continue
    _vendor="$(cat "$_phy/vendor" 2>/dev/null || cat "$_phy/../../idVendor" 2>/dev/null || true)"
    _device="$(cat "$_phy/device" 2>/dev/null || cat "$_phy/../../idProduct" 2>/dev/null || true)"
    _wid="${_vendor:-??}:${_device:-??}"
    case " $WIFI_IDS " in
        *" $_wid "*) : ;;
        *) WIFI_IDS="${WIFI_IDS:+${WIFI_IDS} }${_wid}" ;;
    esac
    case "$_vendor" in
        0x14c3) _chip="MediaTek (mt76)" ;;
        0x10ec) _chip="Realtek (rtw88/rtw89)" ;;
        0x8086) _chip="Intel (iwlwifi)" ;;
        0x168c) _chip="Qualcomm/Atheros (ath9k/10k/11k)" ;;
        0x14e4) _chip="Broadcom (brcmfmac/b43)" ;;
        0x17cb) _chip="Qualcomm (qca)" ;;
        0x1a3b) _chip="NVIDIA (uefi wifi — driverless)" ;;
        *) _chip="unknown vendor (${_vendor:-??})" ;;
    esac
    case " $WIFI_CHIPS " in
        *" $_chip "*) : ;;
        *) WIFI_CHIPS="${WIFI_CHIPS:+${WIFI_CHIPS} }${_chip}" ;;
    esac
done
if [ -z "$WIFI_IDS" ]; then
    for _pci in /sys/bus/pci/devices/*/class; do
        [ -r "$_pci" ] || continue
        case "$(cat "$_pci" 2>/dev/null || true)" in
            0x0280*) ;;
            *) continue ;;
        esac
        _dev="${_pci%/class}"
        _vendor="$(cat "$_dev/vendor" 2>/dev/null || true)"
        _device="$(cat "$_dev/device" 2>/dev/null || true)"
        _wid="${_vendor:-??}:${_device:-??}"
        case " $WIFI_IDS " in
            *" $_wid "*) : ;;
            *) WIFI_IDS="${WIFI_IDS:+${WIFI_IDS} }${_wid}" ;;
        esac
        _chip="unbound PCI wireless (vendor ${_vendor:-??})"
        case " $WIFI_CHIPS " in
            *" $_chip "*) : ;;
            *) WIFI_CHIPS="${WIFI_CHIPS:+${WIFI_CHIPS} }${_chip}" ;;
        esac
    done
fi
unset _phy _vendor _device _wid _chip _pci _dev

if [ -n "$WIFI_IDS" ]; then
    echo "  WiFi: ${WIFI_IDS} (${WIFI_CHIPS})"
    case "$WIFI_IDS" in
        *0x14e4:*) echo "  Firmware coverage: Broadcom radio detected — NOT covered by Void defaults (linux-firmware-broadcom split)." ;;
        *) echo "  Firmware coverage: covered by default linux-firmware (+ wifi-firmware) — no extra download needed." ;;
    esac
else
    echo "  WiFi: no wireless radio detected (${WIFI_HW:-none})"
fi

case "$WIFI_IDS" in
    *0x14e4:*)
        if [ "$DEFAULT_WIFI_FW" = "auto" ]; then
            _wifi_fw_default="y"
            _wifi_fw_prompt="[Y/n]"
        else
            _wifi_fw_default="$(printf '%s' "$DEFAULT_WIFI_FW" | tr '[:upper:]' '[:lower:]')"
            _wifi_fw_prompt="[${_wifi_fw_default}?]"
        fi
        while true; do
            ask "Install linux-firmware-broadcom (firmware for the detected Broadcom radio)? ${_wifi_fw_prompt}: "
            read -r INSTALL_WIFI_FW_INPUT
            case "${INSTALL_WIFI_FW_INPUT:-$_wifi_fw_default}" in
                y|Y|yes|YES) INSTALL_WIFI_FW="true"; WIFI_FW_PKG="linux-firmware-broadcom"; break ;;
                n|N|no|NO)
                    INSTALL_WIFI_FW="false"; WIFI_FW_PKG=""
                    echo "  WARNING: declining Broadcom firmware — the detected radio will NOT work."
                    echo "  Reinstall with linux-firmware-broadcom, or xbps-install it post-install." >&2
                    break ;;
                *) echo "Please answer y or n." >&2 ;;
            esac
        done
        unset _wifi_fw_default _wifi_fw_prompt INSTALL_WIFI_FW_INPUT ;;
esac
[ -n "$WIFI_IDS" ] && echo "  Broadcom firmware decision: ${INSTALL_WIFI_FW}${WIFI_FW_PKG:+ (${WIFI_FW_PKG})}"
export INSTALL_WIFI_FW WIFI_IDS WIFI_CHIPS WIFI_FW_PKG

LIMINE_WALLPAPER="none"
LIMINE_WALLPAPER_STYLE="stretched"
if [ "$BOOTLOADER" = "limine" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Limine boot-screen background${C_RST}"
    echo "  Add a wallpaper to the Limine boot menu? (BMP/PNG/JPEG/QOI)"
    echo "  Decline for the plain default look. If enabled, point the next"
    echo "  prompt at an image file on this live system (e.g. copied onto"
    echo "  the mounted USB stick) — the installer copies it onto the ESP."
    while true; do
        ask "${C_GRN}Enable Limine wallpaper?${C_RST} [y/N]: "
        read -r WP_YN
        case "${WP_YN,,}" in
            y|yes)
                LIMINE_WALLPAPER="yes"
                break ;;
            ""|n|no)
                LIMINE_WALLPAPER="none"
                break ;;
            *) echo "Please enter y or n." >&2 ;;
        esac
    done
    if [ "$LIMINE_WALLPAPER" = "yes" ]; then
        WP_SRC="$(browse_pick img "wallpaper image (BMP/PNG/JPEG/QOI)")" || WP_SRC=""
        if [ -n "$WP_SRC" ]; then
            WP_EXT="${WP_SRC##*.}"
        fi
        echo "  Selected wallpaper: ${WP_SRC:-<none>}"
        if [ -z "$WP_SRC" ]; then
            LIMINE_WALLPAPER="none"
            echo "  No image selected — proceeding without a wallpaper." >&2
        else
        while true; do
            ask "Wallpaper style [1=stretched/2=tiled/3=centered] [1]: "
            read -r WP_STYLE_INPUT
            case "${WP_STYLE_INPUT:-1}" in
                1) LIMINE_WALLPAPER_STYLE="stretched"; break ;;
                2) LIMINE_WALLPAPER_STYLE="tiled"; break ;;
                3) LIMINE_WALLPAPER_STYLE="centered"; break ;;
                *) echo "Please enter 1, 2, or 3." >&2 ;;
            esac
        done
        WP_STAGED="/mnt/tmp/limine-splash.${WP_EXT,,}"
        mkdir -p /mnt/tmp
        cp -f "$WP_SRC" "$WP_STAGED"
        echo "  Wallpaper staged → ${WP_STAGED}"
        fi
    fi
fi
export LIMINE_WALLPAPER
export LIMINE_WALLPAPER_STYLE

ENCRYPT="no"
ENCRYPT_PASSPHRASE=""
echo ""
echo "${C_BOLD}${C_BLU}Encrypt disk?${C_RST}"
echo ""
echo "  Encrypt partition 2 (the root filesystem) with LUKS2. Every subvolume"
echo "  (root, home, snapshots, swap, ...) lives inside the encrypted volume."
echo "  Unlock is with a passphrase and/or an optional YubiKey (asked later);"
echo "  the ESP/bootloader stays unencrypted so it can find the system before"
echo "  the volume is unlocked."
echo ""
ask "Enable full-disk encryption (LUKS2)? [y/N]: "
read -r ENCRYPT_INPUT
case "$ENCRYPT_INPUT" in
    [yY]*) ENCRYPT="yes" ;;
    *)     ENCRYPT="no" ;;
esac
if [ "$BOOTLOADER" = "grub" ] && [ "$ENCRYPT" = "yes" ]; then
    echo "  GRUB + full-disk encryption: the ESP is mounted AT /boot and will hold"
    echo "  the whole boot tree (grub + every kernel/initramfs) — pick a size."
    esp_size_choose
fi
export ENCRYPT

YK_MODE="off"
YK_FALLBACK="yes"
YK_SLOT="1"
YK_TOUCH="no"
if [ "$ENCRYPT" = "yes" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}YubiKey hmac-sha1 unlock?${C_RST}"
    echo ""
    echo "  Optionally bind a YubiKey hmac-sha1 challenge-response slot so the disk"
    echo "  unlocks by tapping the key at boot instead of (or in addition to) typing"
    echo "  the passphrase. The YubiKey MUST be plugged in now: enrollment programs"
    echo "  a real slot and stamps the HMAC response as a LUKS key slot. Slot 1 is"
    echo "  used by default (also the OTP default); use slot 2 if slot 1 is in use."
    echo "  ${C_YLW}Note:${C_RST} this boot-unlock path has ${C_BOLD}not been verified on real"
    echo "  hardware${C_RST} by the author — validate on the target medium before"
    echo "  trusting a possession-only install (see [YK-KEYSCRIPT-BAKE])."
    echo ""
    ask "Set up YubiKey hmac-sha1 unlock? [y/N]: "
    read -r YK_INPUT
    case "$YK_INPUT" in
        [yY]*)
            YK_MODE="hmac-sha1"
            while :; do
                ask "Which OTP slot to program (1 or 2)? [1]: "
                read -r YK_SLOT_INPUT
                case "${YK_SLOT_INPUT:-1}" in
                    1|2) YK_SLOT="$YK_SLOT_INPUT"; break ;;
                    *) echo "Please enter 1 or 2." >&2 ;;
                esac
            done
            ask "Require a physical touch on the YubiKey to unlock at boot? [Y/n]: "
            read -r YK_TOUCH_INPUT
            case "$YK_TOUCH_INPUT" in
                "")     YK_TOUCH="$DEFAULT_YK_TOUCH" ;;
                [nN]*) YK_TOUCH="no" ;;
                *)     YK_TOUCH="yes" ;;
            esac
            echo ""
            echo "  Passphrase fallback: with 'yes' (default) the typed passphrase slot is"
            echo "  kept too, so YubiKey absent/wrong still boots by typing the passphrase."
            echo "  With 'no' the passphrase slot is removed and the YubiKey is the ONLY"
            echo "  unlock — possession-required, nothing to type. NOTE: YubiKey-only is"
            echo "  only ever proven with the Limine bootloader — with GRUB the fallback"
            echo "  is kept regardless ([YUBIKEY] clamp)."
            ask "Keep the typed-passphrase fallback (YubiKey OR passphrase)? [Y/n]: "
            read -r YK_FALLBACK_INPUT
            case "$YK_FALLBACK_INPUT" in
                "")     YK_FALLBACK="$DEFAULT_YK_FALLBACK" ;;
                [nN]*) YK_FALLBACK="no" ;;
                *)     YK_FALLBACK="yes" ;;
            esac
            ;;
    esac
fi
export YK_MODE YK_FALLBACK YK_SLOT YK_TOUCH
unset YK_INPUT YK_SLOT_INPUT YK_TOUCH_INPUT YK_FALLBACK_INPUT

if [ "$BOOTLOADER" = "grub" ] && [ "$YK_MODE" = "hmac-sha1" ] && [ "$YK_FALLBACK" = "no" ]; then
    echo "==> [YUBIKEY] YubiKey-only unlock is only ever proven on Limine — keeping the"
    echo "       typed-passphrase fallback slot (YK_FALLBACK=yes) for this GRUB install."
    YK_FALLBACK="yes"
fi

if [ "$ENCRYPT" = "yes" ]; then
    while :; do
        echo ""
        if [ "$YK_MODE" = "hmac-sha1" ] && [ "$YK_FALLBACK" = "no" ]; then
            echo "  YubiKey-only unlock selected — this passphrase is a ONE-TIME provisioning"
            echo "  secret: it creates the LUKS2 container and is used to bind the YubiKey"
            echo "  slot, then the passphrase slot is removed. It will NOT unlock at boot;"
            echo "  you do not need to remember it (a throwaway value is fine)."
        elif [ "$YK_MODE" = "hmac-sha1" ]; then
            echo "  Passphrase fallback selected — this passphrase unlocks at boot when the"
            echo "  YubiKey is absent or fails, and seats the container at install."
        else
            echo "  This passphrase is required at every boot to unlock the disk."
        fi
        echo "Enter a passphrase for the encrypted disk (hidden input):"
        echo "  (type it under the CURRENT console keymap; it is what boot will expect)"
        read -r -s ENCRYPT_PASSPHRASE
        echo
        if [ -z "$ENCRYPT_PASSPHRASE" ]; then
            echo "Passphrase cannot be empty. Try again." >&2
            continue
        fi
        echo "Enter the passphrase again to confirm:"
        read -r -s ENCRYPT_PASSPHRASE_CONFIRM
        echo
        if [ "$ENCRYPT_PASSPHRASE" != "$ENCRYPT_PASSPHRASE_CONFIRM" ]; then
            echo "Passphrases do not match. Try again." >&2
            continue
        fi
        break
    done
    unset ENCRYPT_PASSPHRASE_CONFIRM
    printf '%s\n' ""
    printf '%s\n' "${C_BOLD}${C_BLU}LUKS mapper name?${C_RST}"
    printf '%s\n' ""
    printf '%s\n' "  Name of the decrypted device that appears under /dev/mapper/."
    printf '%s\n' "  Press ENTER for the default: void-root"
    ask "Mapper name [void-root]: "
    read -r CRYPT_NAME
    [ -n "$CRYPT_NAME" ] || CRYPT_NAME="void-root"
    case "$CRYPT_NAME" in
        */*) echo "${C_RED}!! Mapper name must be a plain name (no '/'). Using default 'void-root'.${C_RST}" >&2
             CRYPT_NAME="void-root" ;;
    esac
    export CRYPT_NAME
fi


ask "Allow audio (PipeWire) to autostart during read-only snapshot boots? [y/N]: "
read -r ENABLE_SNAPSHOT_AUDIO_INPUT
case "$ENABLE_SNAPSHOT_AUDIO_INPUT" in
    "") ENABLE_SNAPSHOT_AUDIO="$DEFAULT_SNAPSHOT_AUDIO" ;;
    [yY]*) ENABLE_SNAPSHOT_AUDIO="true" ;;
    *) ENABLE_SNAPSHOT_AUDIO="false" ;;
esac
export ENABLE_SNAPSHOT_AUDIO

if [ "$RESUME" != "1" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Data region filesystems${C_RST}"
    echo "  ${C_GRN}btrfs${C_RST}=stays a root-Btrfs subvolume   ${C_GRN}ext4${C_RST}=own dedicated partition"
    echo "  The root filesystem is ALWAYS Btrfs; these choices only slice DATA regions."
    echo "  (Enter on every line = all-Btrfs default: no extra partitions, no size prompts.)"
    ask "/home region — btrfs (subvol) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_HOME_FS="$DEFAULT_REGION_HOME_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_HOME_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_HOME_FS="btrfs"
    else echo "  (default) btrfs"; REGION_HOME_FS="$DEFAULT_REGION_HOME_FS"; fi
    ask "/var region — btrfs (subvols) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_VAR_FS="$DEFAULT_REGION_VAR_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_VAR_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_VAR_FS="btrfs"
    else echo "  (default) btrfs"; REGION_VAR_FS="$DEFAULT_REGION_VAR_FS"; fi
    ask "/var/cache region — btrfs (subvol @cache) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_CACHE_FS="$DEFAULT_REGION_CACHE_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_CACHE_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_CACHE_FS="btrfs"
    else echo "  (default) btrfs"; REGION_CACHE_FS="$DEFAULT_REGION_CACHE_FS"; fi
    ask "/srv region — btrfs (subvol @srv) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_SRV_FS="$DEFAULT_REGION_SRV_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_SRV_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_SRV_FS="btrfs"
    else echo "  (default) btrfs"; REGION_SRV_FS="$DEFAULT_REGION_SRV_FS"; fi
    ask "/opt region — btrfs (subvol @opt) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_OPT_FS="$DEFAULT_REGION_OPT_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_OPT_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_OPT_FS="btrfs"
    else echo "  (default) btrfs"; REGION_OPT_FS="$DEFAULT_REGION_OPT_FS"; fi
    ask "~/<user>/Games — none, ext4 partition, or btrfs partition? [n/e/b]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_GAMES="$DEFAULT_REGION_GAMES"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_GAMES="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_GAMES="btrfs"
    else echo "  (default) none"; REGION_GAMES="$DEFAULT_REGION_GAMES"; fi
    unset _rh
    echo "  Carved region size prompts:"
    if [ "$REGION_HOME_FS" = "ext4" ]; then
        ask "  /home partition size [$DEFAULT_REGION_HOME_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_HOME_SIZE"
        REGION_HOME_SIZE="$_rs"
    fi
    if [ "$REGION_VAR_FS" = "ext4" ]; then
        ask "  /var partition size [$DEFAULT_REGION_VAR_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_VAR_SIZE"
        REGION_VAR_SIZE="$_rs"
    fi
    if [ "$REGION_CACHE_FS" = "ext4" ]; then
        ask "  /var/cache partition size [$DEFAULT_REGION_CACHE_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_CACHE_SIZE"
        REGION_CACHE_SIZE="$_rs"
    fi
    if [ "$REGION_SRV_FS" = "ext4" ]; then
        ask "  /srv partition size [$DEFAULT_REGION_SRV_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_SRV_SIZE"
        REGION_SRV_SIZE="$_rs"
    fi
    if [ "$REGION_OPT_FS" = "ext4" ]; then
        ask "  /opt partition size [$DEFAULT_REGION_OPT_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_OPT_SIZE"
        REGION_OPT_SIZE="$_rs"
    fi
    if [ "$REGION_GAMES" != "none" ]; then
        ask "  Games partition size [$DEFAULT_REGION_GAMES_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_GAMES_SIZE"
        REGION_GAMES_SIZE="$_rs"
    fi
    unset _rs
    REGION_PARTITIONED=""
    [ "$REGION_HOME_FS"  = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED home"
    [ "$REGION_VAR_FS"   = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED var"
    [ "$REGION_CACHE_FS" = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED cache"
    [ "$REGION_SRV_FS"   = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED srv"
    [ "$REGION_OPT_FS"   = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED opt"
    [ "$REGION_GAMES"    != "none" ] && REGION_PARTITIONED="$REGION_PARTITIONED games"
    [ "$REGION_HOME_FS"  != "ext4" ]  && unset REGION_HOME_SIZE
    [ "$REGION_VAR_FS"   != "ext4" ]  && unset REGION_VAR_SIZE
    [ "$REGION_CACHE_FS" != "ext4" ]  && unset REGION_CACHE_SIZE
    [ "$REGION_SRV_FS"   != "ext4" ]  && unset REGION_SRV_SIZE
    [ "$REGION_OPT_FS"   != "ext4" ]  && unset REGION_OPT_SIZE
    [ "$REGION_GAMES"    = "none" ]  && unset REGION_GAMES_SIZE
    [ -n "$REGION_PARTITIONED" ] && echo "  → Carved partitions:${REGION_PARTITIONED}"
    jl "MULTI-FS: carved=${REGION_PARTITIONED:-<none>} home=${REGION_HOME_FS} var=${REGION_VAR_FS} cache=${REGION_CACHE_FS} srv=${REGION_SRV_FS} opt=${REGION_OPT_FS} games=${REGION_GAMES}"
else
    :
fi
export REGION_HOME_FS REGION_VAR_FS REGION_CACHE_FS REGION_SRV_FS REGION_OPT_FS REGION_GAMES
export REGION_HOME_SIZE REGION_VAR_SIZE REGION_CACHE_SIZE REGION_SRV_SIZE REGION_OPT_SIZE REGION_GAMES_SIZE
export REGION_PARTITIONED

if [ "$BOOTLOADER" = "limine" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Limine kernel access${C_RST}"
    echo "  ${C_GRN}esp-copy${C_RST} (the only mode) — kernel/initramfs for every installed"
    echo "     kernel are copied onto the ESP by a post-install kernel hook; Limine"
    echo "     reads them straight off the FAT32 ESP, as Limine's own docs require."
    echo "     (The former btrfs-direct mode was removed — it read the kernel direct"
    echo "     off Btrfs, which Limine does not support, so it could never boot.)"
    KERNEL_MODE="esp-copy"
else
    KERNEL_MODE="n/a"
fi
export KERNEL_MODE

echo ""
echo "${C_BOLD}${C_BLU}Choose desktop environment${C_RST}"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}KDE Plasma (default)${C_RST} — Wayland session, this script's"
echo "     primary tested path."
echo "  ${C_BOLD}2)${C_RST} GNOME — Wayland session, confirmed available on Void."
echo "  ${C_BOLD}3)${C_RST} Cinnamon (X11) — Wayland session not yet packaged by Void."
echo "  ${C_BOLD}4)${C_RST} Xfce (X11) — lightweight GTK desktop, ships as Void's default"
echo "     graphical live-medium flavor."
echo "  ${C_BOLD}5)${C_RST} MATE (X11) — classic GNOME 2-style GTK desktop."
echo "  ${C_BOLD}6)${C_RST} LXQt (X11) — lightweight Qt desktop."
echo "  ${C_BOLD}7)${C_RST} ${C_RED}COSMIC (third-party repo)${C_RST} — the System76 desktop. NOT in the"
echo "     official Void repositories: installed from the community repo at"
echo "     https://bluesloth.github.io/void-linux-cosmic/ (audit:"
echo "     https://github.com/bluesloth/void-linux-cosmic), whose COSMIC 1.10"
echo "     templates are built from scratch, tracking System76 / Pop!_OS COSMIC."
echo "     Its signing key is PINNED in this installer"
echo "     and machine-verified after every sync. It is a third-party"
echo "     signing-trust choice made at your own risk — audit the repo before"
echo "     installing. The repo URL is verified reachable at runtime; if it is"
echo "     unavailable the install aborts cleanly rather than failing mid-way."
echo "  ${C_BOLD}8)${C_RST} ${C_GRN}none (console login only)${C_RST} — no desktop environment; a headless/"
echo "     server base that boots to a console. Pairs naturally with the"
echo "     display-manager '${C_BOLD}none${C_RST}' option below; the Xorg/Wayland base and"
echo "     the audio stack then become explicit opt-ins."
while true; do
    ask "Enter choice [1/2/3/4/5/6/7/8, default ${DEFAULT_DESKTOP}]: "
    read -r DESKTOP_ENV_INPUT
    DESKTOP_ENV_INPUT="${DESKTOP_ENV_INPUT:-$DEFAULT_DESKTOP}"
    case "$DESKTOP_ENV_INPUT" in
        ""|1) DESKTOP_ENV="kde"; break ;;
        2) DESKTOP_ENV="gnome"; break ;;
        3) DESKTOP_ENV="cinnamon"; break ;;
        4) DESKTOP_ENV="xfce"; break ;;
        5) DESKTOP_ENV="mate"; break ;;
        6) DESKTOP_ENV="lxqt"; break ;;
        7) DESKTOP_ENV="cosmic"; break ;;
        8) DESKTOP_ENV="none"; break ;;
        *) echo "Please enter 1, 2, 3, 4, 5, 6, 7, or 8." >&2 ;;
    esac
done
export DESKTOP_ENV

case "$DESKTOP_ENV" in
    kde|lxqt) RECOMMENDED_DM="sddm" ;;
    gnome)    RECOMMENDED_DM="gdm" ;;
    cinnamon|mate) RECOMMENDED_DM="lightdm" ;;
    xfce)     RECOMMENDED_DM="lightdm" ;;
    cosmic)   RECOMMENDED_DM="cosmic-greeter" ;;
    none)     RECOMMENDED_DM="none" ;;
    *)        RECOMMENDED_DM="sddm" ;;
esac

echo ""
echo "${C_BOLD}${C_BLU}Choose display manager${C_RST} (works with any desktop environment — this"
echo "just picks which is typically paired with which; the recommended pairing"
echo "for your selected DE (${C_BOLD}${DESKTOP_ENV}${C_RST}) is ${C_GRN}${RECOMMENDED_DM}${C_RST}):"
echo "  ${C_YLW}Note:${C_RST} the recommended pairing for your DE is tested on real hardware;"
echo "     choosing a different (non-default) DM for it has ${C_BOLD}not been tested${C_RST}."
echo "  ${C_BOLD}1)${C_RST} SDDM — Qt-based; typically paired with KDE Plasma and LXQt; this"
echo "     script's primary tested login manager."
echo "  ${C_BOLD}2)${C_RST} LightDM — lightweight, greeter-based; typically paired with"
echo "     Cinnamon/Xfce/MATE/GTK desktops."
echo "  ${C_BOLD}3)${C_RST} GDM — GNOME Display Manager; typically paired with GNOME."
if [ "$DESKTOP_ENV" = "cosmic" ]; then
    echo "  ${C_BOLD}4)${C_RST} cosmic-greeter — COSMIC's own greeter (from the third-party COSMIC repo)."
    echo "     The recommended/default pairing for COSMIC, tested on real hardware."
fi
echo "  ${C_BOLD}$([ "$DESKTOP_ENV" = "cosmic" ] && echo 5 || echo 4)${C_RST} ${C_GRN}none${C_RST} — no display manager; boot straight to a console login."
while true; do
    if [ "$DESKTOP_ENV" = "cosmic" ]; then
        ask "Enter choice [1/2/3/4/5] (default: ${RECOMMENDED_DM}): "
        read -r DISPLAY_MANAGER_INPUT
        case "$DISPLAY_MANAGER_INPUT" in
            "")  note "Using recommended display manager: ${C_BOLD}${RECOMMENDED_DM}${C_RST}"; DISPLAY_MANAGER="$RECOMMENDED_DM"; break ;;
            1) DISPLAY_MANAGER="sddm"; break ;;
            2) DISPLAY_MANAGER="lightdm"; break ;;
            3) DISPLAY_MANAGER="gdm"; break ;;
            4) DISPLAY_MANAGER="cosmic-greeter"; break ;;
            5) DISPLAY_MANAGER="none"; break ;;
            *) echo "Please enter 1, 2, 3, 4, or 5." >&2 ;;
        esac
    else
        ask "Enter choice [1/2/3/4] (default: ${RECOMMENDED_DM}): "
        read -r DISPLAY_MANAGER_INPUT
        case "$DISPLAY_MANAGER_INPUT" in
            "")  note "Using recommended display manager: ${C_BOLD}${RECOMMENDED_DM}${C_RST}"; DISPLAY_MANAGER="$RECOMMENDED_DM"; break ;;
            1) DISPLAY_MANAGER="sddm"; break ;;
            2) DISPLAY_MANAGER="lightdm"; break ;;
            3) DISPLAY_MANAGER="gdm"; break ;;
            4) DISPLAY_MANAGER="none"; break ;;
            *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
        esac
    fi
done
export DISPLAY_MANAGER

if [ "$DESKTOP_ENV" = "none" ] && [ "$DISPLAY_MANAGER" = "none" ]; then
    HAS_GRAPHICAL="no"
else
    HAS_GRAPHICAL="yes"
fi
export HAS_GRAPHICAL

if [ "$HAS_GRAPHICAL" = "no" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Headless options${C_RST} (DESKTOP_ENV=none + DISPLAY_MANAGER=none)"
    while true; do
        ask "Keep the Xorg/Wayland base for a later startx / remote-X? [y/N]: "
        read -r _xg
        case "${_xg:-$DEFAULT_XORG}" in
            y|yes) INSTALL_XORG="true"; break ;;
            n|no) INSTALL_XORG="false"; break ;;
            *) echo "Please enter y or n." >&2 ;;
        esac
    done
    unset _xg
    echo ""
    while true; do
        ask "Install the audio stack (PipeWire + ALSA) on this server? [y/N]: "
        read -r _au
        case "${_au:-$DEFAULT_AUDIO}" in
            y|yes) INSTALL_AUDIO="true"; break ;;
            n|no) INSTALL_AUDIO="false"; break ;;
            *) echo "Please enter y or n." >&2 ;;
        esac
    done
    unset _au
else
    INSTALL_XORG="false"
    INSTALL_AUDIO="true"
fi
export INSTALL_XORG INSTALL_AUDIO

if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Choose a LightDM greeter${C_RST}"
    echo "  ${C_BOLD}1)${C_RST} ${C_GRN}GTK Greeter (lightdm-gtk-greeter)${C_RST} — the default, plain and"
    echo "     reliable, minimal dependencies."
    echo "  ${C_BOLD}2)${C_RST} Slick Greeter (lightdm-slick-greeter) — Linux Mint style,"
    echo "     more polished appearance (GTK-based)."
    while true; do
        ask "Enter choice [1/2] (default 1: GTK): "
        read -r LIGHTDM_GREETER_INPUT
        case "$LIGHTDM_GREETER_INPUT" in
            ""|1) LIGHTDM_GREETER="gtk"; break ;;
            2) LIGHTDM_GREETER="slick"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
    if [ "$LIGHTDM_GREETER" = "slick" ]; then
        LIGHTDM_GREETER_PKG="lightdm-slick-greeter"
        LIGHTDM_GREETER_SESSION="slick-greeter"
    else
        LIGHTDM_GREETER_PKG="lightdm-gtk-greeter"
        LIGHTDM_GREETER_SESSION="lightdm-gtk-greeter"
    fi
    export LIGHTDM_GREETER_PKG
    export LIGHTDM_GREETER_SESSION
fi

echo ""
echo "${C_BOLD}${C_BLU}Choose session/seat management (logind)${C_RST}"
echo "  ${C_YLW}Note:${C_RST} ${C_GRN}elogind${C_RST} is the only option tested on real hardware;"
echo "     turnstile + seatd + acpid has ${C_BOLD}not been tested${C_RST} and may need"
echo "     manual fixes for some software."
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}elogind (Default)${C_RST} — the well-tested fork of systemd-logind;"
echo "     broadly required/compatible with GNOME, KDE, polkit auth."
echo "  ${C_BOLD}2)${C_RST} turnstile + seatd + acpid — the leaner alternative: turnstile for"
echo "     user sessions, seatd for graphical seat/input, acpid for ACPI"
echo "     power events. Avoids the logind runtime entirely; some software"
echo "     that hard-requires logind may not work."
while true; do
    _session_default="elogind"
    [ "$DEFAULT_SESSION_STACK" = "2" ] && _session_default="turnstile"
    ask "Enter choice [1/2] (default ${DEFAULT_SESSION_STACK}: ${_session_default}): "
    read -r LOGIND_INPUT
    LOGIND_INPUT="${LOGIND_INPUT:-$DEFAULT_SESSION_STACK}"
    case "$LOGIND_INPUT" in
        ""|1) SESSION_STACK="elogind"; break ;;
        2) SESSION_STACK="turnstile"; break ;;
        *) echo "Please enter 1 or 2." >&2 ;;
    esac
done
export SESSION_STACK

echo ""
echo "The following are independent yes/no choices — answer each on its own,"
echo "any combination is fine."

ask "Install OctoXBPS (graphical package manager + update notifier)? [y/N]: "
read -r INSTALL_OCTOXBPS_INPUT
case "$INSTALL_OCTOXBPS_INPUT" in
    "") INSTALL_OCTOXBPS="$DEFAULT_OCTOXBPS" ;;
    [nN]*) INSTALL_OCTOXBPS="false" ;;
    *) INSTALL_OCTOXBPS="true" ;;
esac
export INSTALL_OCTOXBPS

ask "Install Flatpak (+ Flathub)? [y/N]: "
read -r INSTALL_FLATPAK_INPUT
case "$INSTALL_FLATPAK_INPUT" in
    "") INSTALL_FLATPAK="$DEFAULT_FLATPAK" ;;
    [nN]*) INSTALL_FLATPAK="false" ;;
    *) INSTALL_FLATPAK="true" ;;
esac
export INSTALL_FLATPAK

echo ""
echo "${C_BOLD}${C_BLU}THIRD-PARTY APP CHANNELS${C_RST} — Flatpak (sandboxed GUI apps) and"
echo "  Homebrew / Linuxbrew (unsandboxed CLI & dev tools) are independent"
echo "  choices — enable either, both, or neither."
ask "Install Homebrew (Linuxbrew CLI/dev channel, opt-in; ~/.linuxbrew)? [y/N]: "
read -r INSTALL_BREW_INPUT
case "$INSTALL_BREW_INPUT" in
    "") INSTALL_BREW="$DEFAULT_BREW" ;;
    [yY]*) INSTALL_BREW="true" ;;
    *) INSTALL_BREW="false" ;;
esac
export INSTALL_BREW

INSTALL_COSMIC_STORE="false"
if [ "$INSTALL_FLATPAK" = "true" ]; then
    ask "Install cosmic-store (COSMIC app store; Flatpak-only)? [y/N]: "
    read -r INSTALL_COSMIC_STORE_INPUT
    case "$INSTALL_COSMIC_STORE_INPUT" in
        "") INSTALL_COSMIC_STORE="$DEFAULT_COSMIC_STORE" ;;
        [yY]*) INSTALL_COSMIC_STORE="true" ;;
        *) INSTALL_COSMIC_STORE="false" ;;
    esac
fi
export INSTALL_COSMIC_STORE

INSTALL_COSMIC_TOUCHPAD_RCLICK="false"
if [ "$DESKTOP_ENV" = "cosmic" ]; then
    ask "Configure COSMIC touchpad right-click (two-finger tap + corner-click)? [y/N]: "
    read -r INSTALL_COSMIC_TOUCHPAD_RCLICK_INPUT
    case "$INSTALL_COSMIC_TOUCHPAD_RCLICK_INPUT" in
        "") INSTALL_COSMIC_TOUCHPAD_RCLICK="$DEFAULT_COSMIC_TOUCHPAD_RCLICK" ;;
        [yY]*) INSTALL_COSMIC_TOUCHPAD_RCLICK="true" ;;
        *) INSTALL_COSMIC_TOUCHPAD_RCLICK="false" ;;
    esac
fi
export INSTALL_COSMIC_TOUCHPAD_RCLICK

ask "Install Thunderbird (email client)? [y/N]: "
read -r INSTALL_THUNDERBIRD_INPUT
case "$INSTALL_THUNDERBIRD_INPUT" in
    "") INSTALL_THUNDERBIRD="$DEFAULT_THUNDERBIRD" ;;
    [yY]*) INSTALL_THUNDERBIRD="true" ;;
    *) INSTALL_THUNDERBIRD="false" ;;
esac
export INSTALL_THUNDERBIRD

echo ""
echo "${C_BOLD}${C_BLU}GAME LAUNCHERS & RUNTIMES${C_RST}"
if [ -n "${GPU_FAMILIES}" ]; then
    echo "  Detected graphics: ${GPU_FAMILIES} (advisory only)"
else
    echo "  Detected graphics: none (headless / no discrete GPU seen)"
fi
echo "  Each item below is independent and off by default; a launcher never"
echo "  auto-pulls Wine — configure each launcher's own Wine as needed."

ask "Install Lutris (game library/installer for Wine + native games)? [y/N]: "
read -r INSTALL_LUTRIS_INPUT
case "$INSTALL_LUTRIS_INPUT" in
    "") INSTALL_LUTRIS="$DEFAULT_LUTRIS" ;;
    [yY]*) INSTALL_LUTRIS="true" ;;
    *) INSTALL_LUTRIS="false" ;;
esac
export INSTALL_LUTRIS

if [ "$INSTALL_FLATPAK" = "true" ]; then
    ask "Install Heroic (Epic/GOG launcher; Flatpak)? [y/N]: "
    read -r INSTALL_HEROIC_INPUT
    case "$INSTALL_HEROIC_INPUT" in
        "") INSTALL_HEROIC="$DEFAULT_HEROIC" ;;
        [yY]*) INSTALL_HEROIC="true" ;;
        *) INSTALL_HEROIC="false" ;;
    esac
    export INSTALL_HEROIC
    ask "Install Bottles (per-game Wine prefix manager; Flatpak)? [y/N]: "
    read -r INSTALL_BOTTLES_INPUT
    case "$INSTALL_BOTTLES_INPUT" in
        "") INSTALL_BOTTLES="$DEFAULT_BOTTLES" ;;
        [yY]*) INSTALL_BOTTLES="true" ;;
        *) INSTALL_BOTTLES="false" ;;
    esac
    export INSTALL_BOTTLES
else
    INSTALL_HEROIC="false"
    INSTALL_BOTTLES="false"
    export INSTALL_HEROIC INSTALL_BOTTLES
    echo "NOTICE: Heroic and Bottles are only offered when Flatpak is selected"
    echo "(no official Void package — Flatpak-only delivery). Flatpak was not"
    echo "selected — Heroic and Bottles skipped."
fi

ask "Install Wine (system, multilib)? [y/N]: "
read -r INSTALL_WINE_INPUT
case "$INSTALL_WINE_INPUT" in
    "") INSTALL_WINE="$DEFAULT_WINE" ;;
    [yY]*) INSTALL_WINE="true" ;;
    *) INSTALL_WINE="false" ;;
esac
export INSTALL_WINE

ask "Install gamemode (+ libgamemode-32bit)? [y/N]: "
read -r INSTALL_GAMEMODE_INPUT
case "$INSTALL_GAMEMODE_INPUT" in
    "") INSTALL_GAMEMODE="$DEFAULT_GAMEMODE" ;;
    [yY]*) INSTALL_GAMEMODE="true" ;;
    *) INSTALL_GAMEMODE="false" ;;
esac
export INSTALL_GAMEMODE

ask "Install Steam (gaming client)? [y/N]: "
read -r INSTALL_STEAM_INPUT
case "$INSTALL_STEAM_INPUT" in
    "") INSTALL_STEAM="$DEFAULT_STEAM" ;;
    [yY]*) INSTALL_STEAM="true" ;;
    *) INSTALL_STEAM="false" ;;
esac
export INSTALL_STEAM

if [ "$INSTALL_STEAM" = "true" ] || [ "$INSTALL_LUTRIS" = "true" ] || \
   [ "$INSTALL_HEROIC" = "true" ] || [ "$INSTALL_BOTTLES" = "true" ]; then
    INSTALL_ANY_GAME="true"
else
    INSTALL_ANY_GAME="false"
fi
export INSTALL_ANY_GAME

ask "Install VirtualBox (full virtualizer, QEMU/KVM alternative)? [y/N]: "
read -r INSTALL_VIRTUALBOX_INPUT
case "$INSTALL_VIRTUALBOX_INPUT" in
    "") INSTALL_VIRTUALBOX="$DEFAULT_VIRTUALBOX" ;;
    [yY]*) INSTALL_VIRTUALBOX="true" ;;
    *) INSTALL_VIRTUALBOX="false" ;;
esac
export INSTALL_VIRTUALBOX

echo ""
ask "Set up web browsers now? (choose each one next) [y/N]: "
read -r _setup_web_input
case "$_setup_web_input" in
    "")    SETUP_WEB_BROWSERS="$DEFAULT_WEB_BROWSERS" ;;
    [nN]*) SETUP_WEB_BROWSERS="false" ;;
    *)     SETUP_WEB_BROWSERS="true" ;;
esac
export SETUP_WEB_BROWSERS

if [ "$SETUP_WEB_BROWSERS" = "true" ]; then
    echo "Choose web browsers to install (each is independent — pick any"
    echo "combination, or none at all):"
    ask "Install Firefox? [Y/n]: "
    read -r INSTALL_FIREFOX_INPUT
    case "$INSTALL_FIREFOX_INPUT" in
        "") INSTALL_FIREFOX="$DEFAULT_FIREFOX" ;;
        [nN]*) INSTALL_FIREFOX="false" ;;
        *) INSTALL_FIREFOX="true" ;;
    esac
    export INSTALL_FIREFOX

    ask "Install Chromium? [Y/n]: "
    read -r INSTALL_CHROMIUM_INPUT
    case "$INSTALL_CHROMIUM_INPUT" in
        "") INSTALL_CHROMIUM="$DEFAULT_CHROMIUM" ;;
        [nN]*) INSTALL_CHROMIUM="false" ;;
        *) INSTALL_CHROMIUM="true" ;;
    esac
    export INSTALL_CHROMIUM

    ask "Install Vivaldi (proprietary, nonfree repo)? [y/N]: "
    read -r INSTALL_VIVALDI_INPUT
    case "$INSTALL_VIVALDI_INPUT" in
        "") INSTALL_VIVALDI="$DEFAULT_VIVALDI" ;;
        [yY]*) INSTALL_VIVALDI="true" ;;
        *) INSTALL_VIVALDI="false" ;;
    esac
    export INSTALL_VIVALDI

    if [ "$DESKTOP_ENV" != "kde" ]; then
        if [ "$DESKTOP_ENV" = "lxqt" ]; then
            echo "NOTICE: Falkon shares LXQt's Qt5 but still pulls in the Qt"
            echo "WebEngine stack on top (it does not install KDE)."
        elif [ "$DESKTOP_ENV" = "none" ]; then
            echo "NOTICE: Falkon runs standalone but pulls in the Qt + QtWebEngine"
            echo "stack onto your console-only base (it does not install a desktop)."
        else
            echo "NOTICE: Falkon runs standalone but pulls in the Qt + QtWebEngine"
            echo "stack on top of your ${DESKTOP_ENV} desktop (it does not install KDE)."
        fi
    fi
    ask "Install Falkon (KDE's browser, works fine standalone too)? [y/N]: "
    read -r INSTALL_FALKON_INPUT
    case "$INSTALL_FALKON_INPUT" in
        "") INSTALL_FALKON="$DEFAULT_FALKON" ;;
        [yY]*) INSTALL_FALKON="true" ;;
        *) INSTALL_FALKON="false" ;;
    esac
    export INSTALL_FALKON

    if [ "$INSTALL_FLATPAK" != "true" ]; then
        INSTALL_BRAVE="false"
        echo "NOTICE: Brave is only offered when Flatpak is selected (it has no"
        echo "official Void package). Flatpak was not selected — Brave skipped."
    else
        echo "NOTICE: Brave has no official Void package. If selected, it will only"
        echo "be installed via Flatpak — and only if Flatpak was selected above. If"
        echo "Flatpak wasn't selected, Brave will be skipped rather than reaching"
        echo "for an unofficial third-party package repository."
        ask "Install Brave? [y/N]: "
        read -r INSTALL_BRAVE_INPUT
        case "$INSTALL_BRAVE_INPUT" in
            "") INSTALL_BRAVE="$DEFAULT_BRAVE" ;;
            [yY]*) INSTALL_BRAVE="true" ;;
            *) INSTALL_BRAVE="false" ;;
        esac
        export INSTALL_BRAVE
    fi
else
    INSTALL_FIREFOX="false"
    INSTALL_CHROMIUM="false"
    INSTALL_VIVALDI="false"
    INSTALL_FALKON="false"
    INSTALL_BRAVE="false"
    export INSTALL_FIREFOX INSTALL_CHROMIUM INSTALL_VIVALDI INSTALL_FALKON INSTALL_BRAVE
fi



echo ""
ask "Set up containers (Podman / Docker) now? (choose each backend next) [y/N]: "
read -r _setup_containers_input
case "$_setup_containers_input" in
    "")    SETUP_CONTAINERS="$DEFAULT_CONTAINERS" ;;
    [yY]*) SETUP_CONTAINERS="true" ;;
    *)     SETUP_CONTAINERS="false" ;;
esac
export SETUP_CONTAINERS

if [ "$SETUP_CONTAINERS" = "true" ]; then
    echo "Container backends — Podman rootless, Podman rootful, and Docker are"
    echo "three independent choices below (any combination is fine, including"
    echo "all three or none)."
    ask "Install Podman rootless? [y/N]: "
    read -r INSTALL_PODMAN_ROOTLESS_INPUT
    case "$INSTALL_PODMAN_ROOTLESS_INPUT" in
        "") INSTALL_PODMAN_ROOTLESS="$DEFAULT_PODMAN_ROOTLESS" ;;
        [yY]*) INSTALL_PODMAN_ROOTLESS="true" ;;
        *) INSTALL_PODMAN_ROOTLESS="false" ;;
    esac
    export INSTALL_PODMAN_ROOTLESS

    ask "Install Podman rootful capability? [y/N]: "
    read -r INSTALL_PODMAN_ROOTFUL_INPUT
    case "$INSTALL_PODMAN_ROOTFUL_INPUT" in
        "") INSTALL_PODMAN_ROOTFUL="$DEFAULT_PODMAN_ROOTFUL" ;;
        [yY]*) INSTALL_PODMAN_ROOTFUL="true" ;;
        *) INSTALL_PODMAN_ROOTFUL="false" ;;
    esac
    export INSTALL_PODMAN_ROOTFUL

    if [ "$INSTALL_PODMAN_ROOTLESS" = "true" ] || [ "$INSTALL_PODMAN_ROOTFUL" = "true" ]; then
        INSTALL_PODMAN="true"
    else
        INSTALL_PODMAN="false"
    fi
    export INSTALL_PODMAN

ask "Install Docker? [y/N]: "
read -r INSTALL_DOCKER_INPUT
case "$INSTALL_DOCKER_INPUT" in
    "") INSTALL_DOCKER="$DEFAULT_DOCKER" ;;
    [yY]*) INSTALL_DOCKER="true" ;;
    *) INSTALL_DOCKER="false" ;;
esac
if [ "$INSTALL_DOCKER" = "true" ]; then
    ask "Add your user to the docker group (root-equivalent access, run docker without sudo)? [y/N]: "
    read -r DOCKER_GROUP_ADD_INPUT
    case "$DOCKER_GROUP_ADD_INPUT" in
        "") DOCKER_GROUP_ADD="$DEFAULT_DOCKER_GROUP_ADD" ;;
        [yY]*) DOCKER_GROUP_ADD="true" ;;
        *) DOCKER_GROUP_ADD="false" ;;
    esac
else
    DOCKER_GROUP_ADD="false"
fi
export INSTALL_DOCKER
export DOCKER_GROUP_ADD

if [ "$INSTALL_PODMAN_ROOTLESS" = "true" ] || [ "$INSTALL_PODMAN_ROOTFUL" = "true" ] || [ "$INSTALL_DOCKER" = "true" ]; then
    echo "NOTICE: distrobox has no xbps package on Void. If installed, it will be"
    echo "built from upstream's official install script (fetched and run directly"
    echo "from GitHub), not a package from a verified repository index."
    ask "Also install distrobox? [y/N]: "
    read -r INSTALL_DISTROBOX_INPUT
    case "$INSTALL_DISTROBOX_INPUT" in
        "") INSTALL_DISTROBOX="$DEFAULT_DISTROBOX" ;;
        [yY]*) INSTALL_DISTROBOX="true" ;;
        *) INSTALL_DISTROBOX="false" ;;
    esac
else
    INSTALL_DISTROBOX="false"
fi
export INSTALL_DISTROBOX

if [ "$INSTALL_DISTROBOX" = "true" ]; then
    echo "Which distrobox release track do you want?"
    echo "  1) Stable  — pinned to version 1.8.2.5 (legacy/bash codebase)"
    echo "  2) Current — always fetches the latest legacy-branch release"
    echo "  3) Next    — upstream's v2 Go rewrite (release-candidate branch,"
    echo "     built from source, ~200MB of golang fetched to build it)."
    echo "     Known rough edges: stop/rm can report a false timeout (use"
    echo "     'podman kill'/'podman rm -f' as a workaround), an interrupted"
    echo "     'enter' can require recreating that one container, and image"
    echo "     pulls need an unqualified-search-registries entry (handled"
    echo "     automatically by this script)."
    while true; do
        ask "Enter choice [1/2/3, default ${DEFAULT_DISTROBOX_TRACK}]: "
        read -r DISTROBOX_TRACK_INPUT
        case "${DISTROBOX_TRACK_INPUT:-$DEFAULT_DISTROBOX_TRACK}" in
            1) DISTROBOX_TRACK="stable"; break ;;
            2) DISTROBOX_TRACK="current"; break ;;
            3) DISTROBOX_TRACK="next"; break ;;
            *) echo "Please enter 1, 2, or 3." >&2 ;;
        esac
    done
else
    DISTROBOX_TRACK="stable"
fi
export DISTROBOX_TRACK

if [ "$INSTALL_DISTROBOX" = "true" ] && [ "$INSTALL_PODMAN" = "true" ] && [ "$INSTALL_DOCKER" = "true" ]; then
    echo ""
    echo "Both a Podman backend and Docker are being installed, and so is"
    echo "distrobox. Which should distrobox use by default when creating new"
    echo "containers? (You can still override this per-container later with"
    echo "the DBX_CONTAINER_MANAGER environment variable.)"
    echo "  1) Podman (default) — distrobox's own upstream default"
    echo "  2) Docker"
    while true; do
        ask "Enter choice [1/2] (default ${DEFAULT_DISTROBOX_ENGINE}): "
        read -r DISTROBOX_ENGINE_INPUT
        case "${DISTROBOX_ENGINE_INPUT:-$DEFAULT_DISTROBOX_ENGINE}" in
            ""|1) DISTROBOX_DEFAULT_ENGINE="podman"; break ;;
            2) DISTROBOX_DEFAULT_ENGINE="docker"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
else
    DISTROBOX_DEFAULT_ENGINE=""
fi
export DISTROBOX_DEFAULT_ENGINE

else
    INSTALL_PODMAN_ROOTLESS="false"
    INSTALL_PODMAN_ROOTFUL="false"
    INSTALL_PODMAN="false"
    INSTALL_DOCKER="false"
    DOCKER_GROUP_ADD="false"
    INSTALL_DISTROBOX="false"
    DISTROBOX_TRACK="stable"
    DISTROBOX_DEFAULT_ENGINE=""
    export INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL INSTALL_PODMAN \
           INSTALL_DOCKER DOCKER_GROUP_ADD INSTALL_DISTROBOX DISTROBOX_TRACK \
           DISTROBOX_DEFAULT_ENGINE
fi

ask "Install virtualization (qemu/libvirt/virt-manager + br0 bridge)? [y/N]: "
read -r INSTALL_VIRT_INPUT
case "$INSTALL_VIRT_INPUT" in
    "") INSTALL_VIRT="$DEFAULT_VIRT" ;;
    [yY]*) INSTALL_VIRT="true" ;;
    *) INSTALL_VIRT="false" ;;
esac
export INSTALL_VIRT

INSTALL_SSH_SERVER="false"
SSH_PORT="22"
SSH_PASSWORD_AUTH="yes"
SSH_ROOT_LOGIN="prohibit-password"
ask "Install and enable the OpenSSH server (sshd)? [y/N]: "
read -r INSTALL_SSH_SERVER_INPUT
case "$INSTALL_SSH_SERVER_INPUT" in
    "") INSTALL_SSH_SERVER="$DEFAULT_INSTALL_SSH_SERVER" ;;
    [yY]*) INSTALL_SSH_SERVER="true" ;;
    *) INSTALL_SSH_SERVER="false" ;;
esac
if [ "$INSTALL_SSH_SERVER" = "true" ]; then
    while true; do
        ask "OpenSSH server port (default ${DEFAULT_SSH_PORT}): "
        read -r SSH_PORT_INPUT
        SSH_PORT="${SSH_PORT_INPUT:-$DEFAULT_SSH_PORT}"
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
            break
        fi
        echo "  Please enter a valid port number (1-65535)." >&2
    done
    ask "Allow password authentication over SSH? [Y/n]: "
    read -r SSH_PASSWORD_AUTH_INPUT
    case "${SSH_PASSWORD_AUTH_INPUT:-$DEFAULT_SSH_PASSWORD_AUTH}" in
        ""|"$DEFAULT_SSH_PASSWORD_AUTH") SSH_PASSWORD_AUTH="$DEFAULT_SSH_PASSWORD_AUTH" ;;
        [yY]*) SSH_PASSWORD_AUTH="yes" ;;
        *) SSH_PASSWORD_AUTH="no" ;;
    esac
    ask "Allow root to log in over SSH (public-key only)? [Y/n]: "
    read -r SSH_ROOT_LOGIN_INPUT
    case "${SSH_ROOT_LOGIN_INPUT:-$DEFAULT_SSH_ROOT_LOGIN}" in
        ""|"$DEFAULT_SSH_ROOT_LOGIN") SSH_ROOT_LOGIN="$DEFAULT_SSH_ROOT_LOGIN" ;;
        [yY]*) SSH_ROOT_LOGIN="prohibit-password" ;;
        *) SSH_ROOT_LOGIN="no" ;;
    esac
fi
export INSTALL_SSH_SERVER SSH_PORT SSH_PASSWORD_AUTH SSH_ROOT_LOGIN

IMPORT_SSH_KEY="false"
GENERATE_SSH_KEY="false"
EXPORT_SSH_KEY="false"
SSH_KEY_COMMENT="${TARGET_USER}@${TARGET_HOSTNAME}"
SSH_KEY_PROTECTED="yes"
SSH_IMPORT_DIR="/tmp/ssh-import"
SSH_KEYGEN_DIR="/tmp/ssh-keygen"
ask "Import an existing SSH private key from removable media? [y/N]: "
read -r IMPORT_SSH_KEY_INPUT
case "$IMPORT_SSH_KEY_INPUT" in
    "") IMPORT_SSH_KEY="$DEFAULT_IMPORT_SSH_KEY" ;;
    [yY]*) IMPORT_SSH_KEY="true" ;;
    *) IMPORT_SSH_KEY="false" ;;
esac
if [ "$IMPORT_SSH_KEY" = "true" ]; then
    mkdir -p "$SSH_IMPORT_DIR"
    _imported_key="$(browse_pick "file" "private key to import")"
    if [ -n "$_imported_key" ]; then
        if [[ "$_imported_key" =~ \.pub$ ]]; then
            echo "  NOTICE: '${_imported_key##*/}' looks like a PUBLIC key (.pub)."
            echo "  Skipping import — feed me the private key file instead." >&2
            IMPORT_SSH_KEY="false"
        else
            if ! command -v ssh-keygen >/dev/null 2>&1; then
                echo "  WARNING: ssh-keygen is unavailable on this live medium — an imported key" >&2
                echo "  can only be accepted when it can be verified. Skipping import." >&2
                IMPORT_SSH_KEY="false"
            else
                cp -f "$_imported_key" "${SSH_IMPORT_DIR}/imported"
                chmod 0600 "${SSH_IMPORT_DIR}/imported"
                _imported_key_ok="no"
                if ssh-keygen -y -P "" -f "${SSH_IMPORT_DIR}/imported" \
                        > "${SSH_IMPORT_DIR}/imported.pub" 2>/dev/null; then
                    _imported_key_ok="yes"
                else
                    if grep -q -- "-----BEGIN .*PRIVATE KEY-----" "${SSH_IMPORT_DIR}/imported"; then
                        _imp_key_pass=""
                        read -r -s -p "  Enter the passphrase for this imported key: " _imp_key_pass
                        echo "" >&2
                        if [ -n "$_imp_key_pass" ] && ssh-keygen -y -P "$_imp_key_pass" -f "${SSH_IMPORT_DIR}/imported" \
                                > "${SSH_IMPORT_DIR}/imported.pub" 2>/dev/null; then
                            _imported_key_ok="yes"
                            echo "  (this key is passphrase-protected; it was verified with the passphrase you" >&2
                            echo "   just entered — SSH will still prompt for it on first use, and the passphrase" >&2
                            echo "   is never stored.)" >&2
                        else
                            echo "  ERROR: could not unlock '${_imported_key##*/}' with that passphrase — import skipped." >&2
                        fi
                    else
                        echo "  ERROR: '${_imported_key##*/}' is not a usable SSH private key (ssh-keygen could not read it) — import skipped." >&2
                    fi
                    _imp_key_pass=""
                fi
                if [ "$_imported_key_ok" = "yes" ]; then
                    chmod 0644 "${SSH_IMPORT_DIR}/imported.pub"
                    echo "  Imported private key staged → ${SSH_IMPORT_DIR}/imported"
                    echo "  Imported public key derived → ${SSH_IMPORT_DIR}/imported.pub"
                    _imp_fp="$(ssh-keygen -lf "${SSH_IMPORT_DIR}/imported.pub" 2>/dev/null | sed 's/^[[:space:]]*//' || true)"
                    echo "  Fingerprint: ${_imp_fp:-<unavailable>}"
                    echo "  (compare with 'ssh-keygen -lf' on the source machine to confirm this is your key)"
                else
                    rm -f "${SSH_IMPORT_DIR}/imported" "${SSH_IMPORT_DIR}/imported.pub"
                    IMPORT_SSH_KEY="false"
                fi
                unset _imported_key_ok _imp_fp
            fi
        fi
    else
        IMPORT_SSH_KEY="false"
    fi
fi
ask "Generate a fresh ed25519 SSH keypair? [y/N]: "
read -r GENERATE_SSH_KEY_INPUT
case "$GENERATE_SSH_KEY_INPUT" in
    "") GENERATE_SSH_KEY="$DEFAULT_GENERATE_SSH_KEY" ;;
    [yY]*) GENERATE_SSH_KEY="true" ;;
    *) GENERATE_SSH_KEY="false" ;;
esac
if [ "$GENERATE_SSH_KEY" = "true" ]; then
    echo "${C_BOLD}SSH key comment${C_RST} (a public identifier embedded in the .pub;"
    echo "  default ${C_BOLD}${SSH_KEY_COMMENT}${C_RST} — Enter to keep, type to override):"
    read -r SSH_KEY_COMMENT_INPUT
    [ -n "$SSH_KEY_COMMENT_INPUT" ] && SSH_KEY_COMMENT="$SSH_KEY_COMMENT_INPUT"
    ask "Protect the key with a passphrase? [Y/n]: "
    read -r SSH_KEY_PROTECTED_INPUT
    case "${SSH_KEY_PROTECTED_INPUT:-$DEFAULT_SSH_KEY_PROTECTED}" in
        ""|"$DEFAULT_SSH_KEY_PROTECTED") SSH_KEY_PROTECTED="$DEFAULT_SSH_KEY_PROTECTED" ;;
        [yY]*) SSH_KEY_PROTECTED="yes" ;;
        *) SSH_KEY_PROTECTED="no" ;;
    esac
    mkdir -p "$SSH_KEYGEN_DIR"
    rm -f "$SSH_KEYGEN_DIR"/id_ed25519 "$SSH_KEYGEN_DIR"/id_ed25519.pub 2>/dev/null || true
    if [ "$SSH_KEY_PROTECTED" = "yes" ]; then
        while true; do
            read -r -s -p "  Enter passphrase for the new key: " _ssh_key_pass_1; echo ""
            read -r -s -p "  Re-enter passphrase: " _ssh_key_pass_2; echo ""
            if [ -n "$_ssh_key_pass_1" ] && [ "$_ssh_key_pass_1" = "$_ssh_key_pass_2" ]; then
                break
            fi
            echo "  Passphrases empty or do not match — try again." >&2
        done
        SSH_KEY_PASSPHRASE="$_ssh_key_pass_1"
    else
        SSH_KEY_PASSPHRASE=""
    fi
    unset _ssh_key_pass_1 _ssh_key_pass_2
    ssh-keygen -q -t ed25519 -C "$SSH_KEY_COMMENT" -N "${SSH_KEY_PASSPHRASE}" \
        -f "$SSH_KEYGEN_DIR/id_ed25519"
    SSH_KEY_PASSPHRASE=""
    unset SSH_KEY_PASSPHRASE _ssh_key_input
    echo "  Generated keypair → ${SSH_KEYGEN_DIR}/id_ed25519{,.pub} (comment '${SSH_KEY_COMMENT}')"
fi
ask "Export a backup copy of the SSH keypair to removable media? [y/N]: "
read -r EXPORT_SSH_KEY_INPUT
case "$EXPORT_SSH_KEY_INPUT" in
    "") EXPORT_SSH_KEY="$DEFAULT_EXPORT_SSH_KEY" ;;
    [yY]*) EXPORT_SSH_KEY="true" ;;
    *) EXPORT_SSH_KEY="false" ;;
esac
if [ "$EXPORT_SSH_KEY" = "true" ]; then
    _export_src=""
    [ -f "$SSH_KEYGEN_DIR/id_ed25519" ] && _export_src="$SSH_KEYGEN_DIR/id_ed25519"
    [ -z "$_export_src" ] && [ -f "$SSH_IMPORT_DIR/imported" ] && _export_src="$SSH_IMPORT_DIR/imported"
    if [ -z "$_export_src" ]; then
        echo "  No key present to export (import+generate were both declined)." >&2
        EXPORT_SSH_KEY="false"
    else
        _export_dst="$(browse_pick "dir" "backup destination directory")"
        if [ -d "$_export_dst" ]; then
            cp -f "$_export_src" "${_export_dst}/id_ed25519-backup"
            cp -f "${_export_src}.pub" "${_export_dst}/id_ed25519-backup.pub" 2>/dev/null || true
            chmod 600 "${_export_dst}/id_ed25519-backup"
            echo "  Key exported → ${_export_dst}/id_ed25519-backup{,.pub}"
        else
            echo "  No destination chosen; skipping export." >&2
            EXPORT_SSH_KEY="false"
        fi
    fi
fi
unset _imported_key _export_src _export_dst _imp_key_pass
export IMPORT_SSH_KEY GENERATE_SSH_KEY EXPORT_SSH_KEY SSH_KEY_COMMENT SSH_KEY_PROTECTED


echo ""
echo "Subvolume isolation: all of the optional software you selected above"
echo "with the exception of OctoXBPS and Flatpak (browsers, mail, Steam,"
echo "VirtualBox, Homebrew, Docker, Podman rootful/rootless, virtualization) can be"
echo "given its own isolated Btrfs subvolume, so a Snapper rollback of @"
echo "or @home does not rewind that software's data. OctoXBPS and Flatpak"
echo "are excluded — OctoXBPS is a lightweight GUI package-manager frontend"
echo "with no dedicated data directory to isolate; Flatpak's system-wide"
echo "store lives under /var/lib/flatpak which is part of the @ root"
echo ""
echo "Two master choices follow:"
echo "  1) Software you ARE installing now — isolate its data subvolume?"
echo "  2) Software you did NOT install — pre-create an EMPTY isolated subvolume"
echo "     now, so that if you install it manually later, its data lands on the"
echo "     isolated subvolume from day one (no mixing back into @ / @home, and"
echo "     no migration needed)."
echo "  Answer 'i' to decide per app instead of one bulk answer."
_subvol_master() {
    local _a _def_out
    case "$2" in
        true|yes) _def_out="yes" ;;
        *)        _def_out="no" ;;
    esac
    while true; do
        ask "$1" >&2
        read -r _a
        case "$_a" in
            "") echo "$_def_out"; return ;;
            [yY]) echo "yes"; return ;;
            [nN]) echo "no"; return ;;
            [iI]) echo "individual"; return ;;
            *) echo "  Unrecognized answer '${_a}' — Enter for the default, y/n = all/none, i = per-app." >&2 ;;
        esac
    done
}
SUBVOL_ISOLATE_INSTALLED="$(_subvol_master "For software you ARE installing, give each its own isolated subvolume? [Y/n/i]: " "$DEFAULT_SUBVOL_ISOLATE")"
export SUBVOL_ISOLATE_INSTALLED

SUBVOL_PRECREATE="$(_subvol_master "For software you did NOT install, pre-create an empty isolated subvolume for later manual use? [y/N/i]: " "$DEFAULT_SUBVOL_PRECREATE")"
export SUBVOL_PRECREATE

_subvol_ask() {
    local _a
    while true; do
        ask "$1" >&2
        read -r _a
        case "$_a" in
            [yY]*) echo "true"; return ;;
            "")    echo "$2"; return ;;
            [nN]*) echo "false"; return ;;
            *)     echo "  Unrecognized answer — Enter for the default, y = yes, n = no." >&2 ;;
        esac
    done
}

SUBVOL_ROWS="
INSTALL_FIREFOX|PROVISION_FIREFOX_SUBVOL|Firefox
INSTALL_CHROMIUM|PROVISION_CHROMIUM_SUBVOL|Chromium
INSTALL_VIVALDI|PROVISION_VIVALDI_SUBVOL|Vivaldi
INSTALL_FALKON|PROVISION_FALKON_SUBVOL|Falkon
INSTALL_BRAVE|PROVISION_BRAVE_SUBVOL|Brave
INSTALL_THUNDERBIRD|PROVISION_THUNDERBIRD_SUBVOL|Thunderbird
INSTALL_ANY_GAME|PROVISION_GAME_SUBVOL|Game data
INSTALL_VIRTUALBOX|PROVISION_VIRTUALBOX_SUBVOL|VirtualBox
INSTALL_FLATPAK|PROVISION_FLATPAK_SUBVOL|Flatpak
INSTALL_BREW|PROVISION_LINUXBREW_SUBVOL|Homebrew (Linuxbrew)
INSTALL_DOCKER|PROVISION_DOCKER_SUBVOL|Docker
INSTALL_PODMAN_ROOTFUL|PROVISION_PODMAN_SUBVOL|Podman (rootful)
INSTALL_PODMAN_ROOTLESS|PROVISION_PODMAN_ROOTLESS_SUBVOL|Podman (rootless)
INSTALL_VIRT|PROVISION_VIRT_SUBVOL|Virtualization
"

echo ""
echo "Subvolume isolation per app:"
while IFS='|' read -r _iv _pv _label; do
    [ -z "$_iv" ] && continue
    case "$_iv" in
        \#*) continue ;;
    esac
    eval "INSTALL_X=\${${_iv}:-false}"
    if [ "$INSTALL_X" = "true" ]; then
        if   [ "$SUBVOL_ISOLATE_INSTALLED" = "yes" ]; then
            _dec="true"
        elif [ "$SUBVOL_ISOLATE_INSTALLED" = "no" ]; then
            _dec="false"
        else
            _dec="$(_subvol_ask "  $_label — Isolate this installed app? [Y/n]: " true)"
        fi
    else
        if   [ "$SUBVOL_PRECREATE" = "yes" ]; then
            _dec="true"
        elif [ "$SUBVOL_PRECREATE" = "no" ]; then
            _dec="false"
        else
            _dec="$(_subvol_ask "  $_label — Pre-create empty subvol for later? [y/N]: " false)"
        fi
    fi
    eval "${_pv}=\$_dec"
    export "$_pv"
    echo "  -> ${_pv}=$_dec"
done <<EOF
$SUBVOL_ROWS
EOF

if [ -n "${REGION_PARTITIONED:-}" ]; then
    for _rg in $REGION_PARTITIONED; do
        case "$_rg" in
            home )
                PROVISION_FIREFOX_SUBVOL=false;       PROVISION_CHROMIUM_SUBVOL=false
                PROVISION_VIVALDI_SUBVOL=false;       PROVISION_FALKON_SUBVOL=false
                PROVISION_BRAVE_SUBVOL=false;         PROVISION_THUNDERBIRD_SUBVOL=false
                PROVISION_GAME_SUBVOL=false;          PROVISION_PODMAN_ROOTLESS_SUBVOL=false
                PROVISION_LINUXBREW_SUBVOL=false;     PROVISION_VIRTUALBOX_SUBVOL=false
                jl "MULTI-FS-FOLD: home region carved — home-owned subvol flags forced off (browsers/thunderbird/game/containers-user/linuxbrew/virtualbox)"
                ;;
            var )
                PROVISION_VIRT_SUBVOL=false;          PROVISION_FLATPAK_SUBVOL=false
                PROVISION_DOCKER_SUBVOL=false;        PROVISION_PODMAN_SUBVOL=false
                jl "MULTI-FS-FOLD: var region carved — var-owned subvol flags forced off (libvirt/flatpak/docker/containers)"
                ;;
            cache ) jl "MULTI-FS-FOLD: cache region carved (@cache stays on the region partition)" ;;
            srv )   jl "MULTI-FS-FOLD: srv region carved (@srv stays on the region partition)" ;;
            opt )   jl "MULTI-FS-FOLD: opt region carved (@opt stays on the region partition)" ;;
            games ) jl "MULTI-FS-FOLD: games region carved (~/Games on its own partition; @home/@game unaffected)" ;;
            * ) echo "FATAL: unknown region '$_rg'." >&2; exit 1 ;;
        esac
    done
    unset _rg
fi

if [ "$INSTALL_VIRT" = "true" ]; then

echo ""
echo "NOTICE: br0 bridge networking needs a real, dedicated network"
echo "interface. This installer looks for one automatically:"
echo "  1) A wired Ethernet port with an active cable connected — used"
echo "     if found."
echo "  2) If no wired port has an active link, a USB Ethernet adapter or"
echo "     USB-tethered phone that's physically present (cable optional)."
echo ""
echo "If this machine has no built-in wired Ethernet port, make sure a USB"
echo "Ethernet adapter is plugged in now before continuing."
echo ""
echo "IMPORTANT: whichever USB Ethernet device gets detected needs to stay"
echo "in the SAME USB port going forward. Many USB Ethernet adapters are"
echo "named based on which physical USB port they're plugged into (not"
echo "just the device itself) — moving it to a different port later can"
echo "change its detected name, and the bridge configuration written by"
echo "this installer won't automatically follow that change."
echo ""
echo "If NO wired interface is found at all, the br0 bridge will be"
echo "skipped entirely and libvirt's default NAT network (virbr0) left"
echo "enabled instead — so your VMs still get working networking."
echo ""
echo "${C_YLW}${C_BOLD}  When ready, press Enter to continue.${C_RST}"
read -r -p "Press Enter once ready to continue: " _
fi

if [ "$RESUME" != "1" ]; then
DETECTED_NIC="$(detect_wired_nic || true)"

if [ -n "$DETECTED_NIC" ]; then
    export NET_INTERFACE_MATCH="$DETECTED_NIC"
elif has_wired_nic_hw; then
    echo "WARNING: a wired ethernet port is present but has no active link — falling back to role-matched 'enp*' so plugging a cable in later still binds the br0 slave." >&2
    export NET_INTERFACE_MATCH="enp*"
else
    export NET_INTERFACE_MATCH=""
    if [ "$INSTALL_VIRT" = "true" ]; then
        echo "NOTICE: no wired network interface found on this machine."
        echo "        The br0 bridge will be SKIPPED; libvirt's default NAT"
        echo "        network (virbr0) stays enabled so your VMs still get"
        echo "        working networking out of the box."
    fi
fi

fi


echo ""
echo "${C_BOLD}${C_CYN}DISK SELECTION${C_RST}"
note "Scanning for available disks..."
mapfile -t DISK_CANDIDATE_NAMES < <(lsblk -d -n -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')

if [ "${#DISK_CANDIDATE_NAMES[@]}" -eq 0 ]; then
    echo "FATAL: lsblk found no block devices of type 'disk' at all." >&2
    exit 1
fi

DISK_LIST=()
for _cand in "${DISK_CANDIDATE_NAMES[@]}"; do
    _dev="/dev/${_cand}"
    if lsblk -n -o MOUNTPOINT "$_dev" 2>/dev/null | grep -q '[^[:space:]]'; then
        continue
    fi
    DISK_LIST+=("$_dev")
done

if [ "${#DISK_LIST[@]}" -eq 0 ]; then
    echo "FATAL: no unmounted physical disks found to install onto (the live" >&2
    echo "       medium and/or any other mounted disks were filtered out)." >&2
    exit 1
fi

echo ""
echo "${C_BOLD}Available disks${C_RST} (the live install medium and any currently-mounted"
echo "disks are hidden from this list; ${C_YLW}red${C_RST} = data present, ${C_GRN}green${C_RST} = empty):"
echo ""
declare -A DISK_BY_INDEX
declare -A DISK_PART_COUNT
_i=1
for _dev in "${DISK_LIST[@]}"; do
    _size="$(lsblk -dn -o SIZE "$_dev" 2>/dev/null)"
    _model="$(lsblk -dn -o MODEL "$_dev" 2>/dev/null | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')"
    _tran="$(lsblk -dn -o TRAN "$_dev" 2>/dev/null)"
    [ -z "$_model" ] && _model="(unknown model)"
    [ -z "$_tran" ] && _tran="?"
    _part_count="$(lsblk -n -o TYPE "$_dev" 2>/dev/null | grep -c '^part$' || true)"
    if [ "$_part_count" -gt 0 ]; then
        _status="${C_RED}HAS EXISTING PARTITIONS/DATA${C_RST}"
    else
        _status="${C_GRN}appears empty${C_RST}"
    fi
    printf "  %d) %-14s %8s  %-9s %-28s [%s]\n" "$_i" "$_dev" "$_size" "($_tran)" "$_model" "$_status"
    DISK_BY_INDEX[$_i]="$_dev"
    DISK_PART_COUNT[$_i]="$_part_count"
    _i=$((_i + 1))
done
_disk_count=$((_i - 1))

echo ""
while true; do
    ask "Select disk to partition and install to [1-${_disk_count}]: "
    read -r DISK_CHOICE
    if [[ "$DISK_CHOICE" =~ ^[0-9]+$ ]] && [ "$DISK_CHOICE" -ge 1 ] && [ "$DISK_CHOICE" -le "$_disk_count" ]; then
        break
    fi
    echo "Please enter a number between 1 and ${_disk_count}." >&2
done
export DISK="${DISK_BY_INDEX[$DISK_CHOICE]}"

DISK_BYTES="$(lsblk -bdn -o SIZE "$DISK" 2>/dev/null | tr -d '[:space:]' || true)"

disk_has_void_install() {
    local _tgt="$1"
    local _probe_dir="" _dev _fstype _found=0 _kid
    while IFS= read -r _kid; do
        [ -n "$_kid" ] || continue
        _dev="/dev/${_kid}"
        _fstype=$(lsblk -rno FSTYPE "$_dev" 2>/dev/null || true)
        [ "$_fstype" = "btrfs" ] || continue
        _probe_dir="$(mktemp -d /tmp/void-probe.XXXXXX 2>/dev/null || true)"
        [ -n "$_probe_dir" ] || continue
        if mount -o ro,nosuid,nodev "$_dev" "$_probe_dir" 2>/dev/null; then
            if [ -f "$_probe_dir/etc/os-release" ] && grep -qiE '^(ID|ID_LIKE)=["'\'']?void' "$_probe_dir/etc/os-release"; then
                _found=1
            elif { [ -d "$_probe_dir/@" ] || [ -d "$_probe_dir/@root" ] || [ -d "$_probe_dir/@home" ]; } \
                 && [ -e "$_probe_dir/etc/void-installer/limine-env" ]; then
                _found=1
            fi
            umount -l "$_probe_dir" 2>/dev/null || true
        fi
        rmdir "$_probe_dir" 2>/dev/null || true
        [ "$_found" -eq 1 ] && break
    done < <(lsblk -rno NAME "$_tgt" 2>/dev/null | tail -n +2)
    [ "$_found" -eq 1 ]
}

_TARGET_HAS_VOID="false"
if disk_has_void_install "$DISK"; then
    _TARGET_HAS_VOID="true"
fi

echo ""
echo "${C_RED}==============================================================================${C_RST}"
echo "${C_RED}${C_BOLD}  WARNING — DESTRUCTIVE OPERATION${C_RST}"
echo "${C_RED}==============================================================================${C_RST}"
echo "${C_BOLD}  You selected: ${C_RED}${DISK}${C_RST}"
echo ""
echo "${C_RED}${C_BOLD}  This installer will COMPLETELY WIPE this disk. Every partition and every${C_RST}"
echo "${C_RED}${C_BOLD}  byte of existing data on it will be PERMANENTLY DESTROYED, with no way to${C_RST}"
echo "${C_RED}${C_BOLD}  undo it once partitioning begins.${C_RST}"
if [ "${DISK_PART_COUNT[$DISK_CHOICE]}" -gt 0 ]; then
    echo ""
    echo "${C_YLW}${C_BOLD}  NOTE: this disk currently HAS existing partitions/data on it.${C_RST}"
fi
if [ "$_TARGET_HAS_VOID" = "true" ]; then
    echo ""
    echo "${C_YLW}${C_BOLD}  NOTE: this disk appears to ALREADY contain a Void Linux installation.${C_RST}"
    echo "${C_YLW}${C_BOLD}  Re-running will permanently destroy it with no way to recover.${C_RST}"
fi
echo "${C_RED}==============================================================================${C_RST}"
echo ""
if [ "$_TARGET_HAS_VOID" = "true" ]; then
    echo "${C_RED}${C_BOLD}  >>> This appears to be an existing Void install. To proceed, type:${C_RST}"
    echo "${C_RED}${C_BOLD}          ERASE ${DISK}${C_RST}"
    echo ""
    ask "Type 'ERASE ${DISK}' (with the exact device path) to confirm, or anything else to abort: "
    read -r ERASE_CONFIRM
    if [ "$ERASE_CONFIRM" != "ERASE ${DISK}" ]; then
        echo "${C_RED}!! Confirmation with exact device path not received — aborting before touching any disk.${C_RST}" >&2
        exit 1
    fi
else
    echo "${C_RED}${C_BOLD}  >>> To proceed, type ERASE! below (all caps, with the exclamation mark). <<<${C_RST}"
    echo ""
    ask "Confirm wiping ${DISK}: type 'ERASE!' (or anything else to abort): "
    read -r ERASE_CONFIRM
    if [ "$ERASE_CONFIRM" != "ERASE!" ]; then
        echo "${C_RED}!! Confirmation 'ERASE!' not received — aborting before touching any disk.${C_RST}" >&2
        exit 1
    fi
fi

_rev_de=$(case "$DESKTOP_ENV" in kde) echo KDE Plasma;; cinnamon) echo Cinnamon;; gnome) echo GNOME;; xfce) echo Xfce;; mate) echo MATE;; lxqt) echo LXQt;; cosmic) echo COSMIC;; *) echo "$DESKTOP_ENV";; esac)
_rev_dm="$DISPLAY_MANAGER"
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    case "$LIGHTDM_GREETER_PKG" in
        lightdm-slick-greeter) _rev_dm="LightDM (Slick greeter)" ;;
        lightdm-gtk-greeter)   _rev_dm="LightDM (GTK greeter)" ;;
    esac
fi
_rev_shell="$USER_SHELL"
_rev_swapfmt="$SWAPFILE_SIZE"
_rev_swap="none"
case "$SWAP_BACKEND" in
    swapfile) _rev_swap="swapfile (${_rev_swapfmt})" ;;
    zram)     _rev_swap="zram" ;;
    both)     _rev_swap="swapfile (${_rev_swapfmt}) + zram" ;;
esac
echo ""
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_CYN}${C_BOLD}  REVIEW — please confirm these settings BEFORE anything is written to disk${C_RST}"
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_BOLD}  Target disk      :${C_RST} ${DISK}"
echo "${C_BOLD}  Hostname         :${C_RST} ${TARGET_FQDN:-$TARGET_HOSTNAME}"
echo "${C_BOLD}  Primary user     :${C_RST} ${TARGET_USER}${TARGET_FULL_NAME:+  (${TARGET_FULL_NAME})}  (login shell: ${_rev_shell})"
echo "${C_BOLD}  Desktop / DM     :${C_RST} ${_rev_de} / ${_rev_dm}"
echo "${C_BOLD}  Session stack    :${C_RST} ${SESSION_STACK}"
echo "${C_BOLD}  Bootloader       :${C_RST} ${BOOTLOADER}"
if [ "$BOOTLOADER" = "limine" ]; then
    echo "${C_BOLD}  Kernel access    :${C_RST} ${KERNEL_MODE} (Limine)"
    if [ "$LIMINE_WALLPAPER" = "yes" ]; then
        echo "${C_BOLD}  Boot wallpaper   :${C_RST} enabled (${LIMINE_WALLPAPER_STYLE})"
    fi
fi
echo "${C_BOLD}  Locale / Zone    :${C_RST} ${LOCALE} / ${TIMEZONE}"
echo "${C_BOLD}  Repo (primary)   :${C_RST} ${REPO_PRIMARY}"
echo "${C_BOLD}  Swap             :${C_RST} ${_rev_swap}${ENABLE_HIBERNATION:+  (hibernation: ${ENABLE_HIBERNATION})}"
echo "${C_BOLD}  Encryption       :${C_RST} $([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo "LUKS2 full-disk + YubiKey hmac-sha1 (fallback: $YK_FALLBACK)" || echo "LUKS2 full-disk (passphrase at boot)"; } || echo "none")"
if [ "$ACCOUNT_MODEL" = "hybrid" ]; then
    _rev_acct="hybrid (root password + user sudo)"
elif [ "$ACCOUNT_MODEL" = "debian" ]; then
    _rev_acct="debian (root password, user has no sudo)"
else
    _rev_acct="$ACCOUNT_MODEL (root locked, user sudo)"
fi
echo "${C_BOLD}  Account model    :${C_RST} ${_rev_acct}"
if [ -n "${GPU_FAMILIES:-}" ]; then
    echo "${C_BOLD}  Hardware         :${C_RST} GPU=${GPU_FAMILIES}  wireless=${WIFI_HW:-unknown}"
    echo "${C_BOLD}  NVIDIA driver    :${C_RST} ${INSTALL_NVIDIA}"
fi
echo "${C_CYN}==============================================================================${C_RST}"
echo ""
echo "  ${C_GRN}Press Enter${C_RST} to proceed with the install, or ${C_YLW}type R${C_RST} to re-run the entire"
echo "  configuration from the top and revise your choices (no disk has been touched yet)."
ask "Proceed with these settings? [Enter=continue, R=restart config]: "
read -r _rev_ans
case "$_rev_ans" in
    [rR])
        echo ""
        echo "!! Configuration review declined — restarting the installer so you can revise your choices." >&2
        rm -f "$STATE_FILE" 2>/dev/null || true
        exec "$0" "$@"
        ;;
    *)
        echo "==> Settings confirmed — proceeding to partition ${DISK}."
        ;;
esac
unset _rev_de _rev_dm _rev_shell _rev_swapfmt _rev_swap _rev_acct _rev_ans
fi

if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
    export PART_EFI="${DISK}p1"
    export PART_SYS="${DISK}p2"
else
    export PART_EFI="${DISK}1"
    export PART_SYS="${DISK}2"
fi

for _rr in $REGION_PARTITIONED; do
    case "$_rr" in
        home|var|cache|srv|opt|games) ;;
        *) echo "FATAL: unknown carved region '$_rr' in REGION_PARTITIONED." >&2; exit 1 ;;
    esac
done
NREG=0
for _rr in $REGION_PARTITIONED; do NREG=$((NREG + 1)); done
unset _rr
if [ -n "${REGION_PARTITIONED:-}" ] && [ "$ENCRYPT" != "yes" ]; then
    if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
        export PART_SYS="${DISK}p$((NREG + 2))"
    else
        export PART_SYS="${DISK}$((NREG + 2))"
    fi
    _rr_i=1
    for _rr in $REGION_PARTITIONED; do
        _rr_pn=$((_rr_i + 1))
        if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
            eval "REGION_PART_${_rr}=\"\${DISK}p\${_rr_pn}\""
        else
            eval "REGION_PART_${_rr}=\"\${DISK}\${_rr_pn}\""
        fi
        _rr_i=$((_rr_i + 1))
    done
    unset _rr_i _rr_pn _rr
    jl "MULTI-FS geometry: nreg=${NREG} carved='${REGION_PARTITIONED}' PART_SYS=${PART_SYS} (outer carve)"
elif [ "${REGION_PARTITIONED:-}" = "" ]; then
    jl "MULTI-FS: no carved regions (all-Btrfs layout; PART_SYS=${PART_SYS})"
else
    jl "MULTI-FS geometry: ENCRYPT+regions nreg=${NREG} carved='${REGION_PARTITIONED}' LUKS container=${PART_SYS} (inner GPT on mapper)"
fi
export NREG

_region_inner_partscan() {
    local _ps_dev="${1:-$CRYPT_DEV}"
    if command -v kpartx > /dev/null 2>&1; then
        kpartx -a "$_ps_dev" 2> /dev/null || partprobe "$_ps_dev" 2> /dev/null || partx -a "$_ps_dev" 2> /dev/null || true
    elif command -v partprobe > /dev/null 2>&1; then
        partprobe "$_ps_dev" 2> /dev/null || partx -a "$_ps_dev" 2> /dev/null || true
    else
        partx -a "$_ps_dev" 2> /dev/null || true
    fi
    sleep 2
}

_region_inner_dev() {
    local _sep=""
    case "${CRYPT_DEV##*/}" in *[0-9]) _sep="p";; esac
    _rr_i=1
    for _rr in $REGION_PARTITIONED; do
        eval "REGION_PART_${_rr}=\"\${CRYPT_DEV}${_sep}\${_rr_i}\""
        _rr_i=$((_rr_i + 1))
    done
    unset _rr_i _rr
    BTRFS_DEV="${CRYPT_DEV}${_sep}$((NREG + 1))"
}

DISK_BUDGET_MIN_SYS=$((1024 * 1024 * 1024))

_size_to_bytes() {
    local _sz="${1:-}" _num _unit _mult
    _sz="${_sz//[[:space:]]/}"
    [ -z "$_sz" ] && return 1
    _sz="${_sz#+}"
    if [[ "$_sz" =~ ^([0-9]+)([KMGTP]i?B)$ ]]; then
        _num="${BASH_REMATCH[1]}"
        _unit="${BASH_REMATCH[2]}"
        case "$_unit" in
            KB)  _mult=$((1000)) ;;
            KiB) _mult=$((1024)) ;;
            MB)  _mult=$((1000 ** 2)) ;;
            MiB) _mult=$((1024 ** 2)) ;;
            GB)  _mult=$((1000 ** 3)) ;;
            GiB) _mult=$((1024 ** 3)) ;;
            TB)  _mult=$((1000 ** 4)) ;;
            TiB) _mult=$((1024 ** 4)) ;;
            PB)  _mult=$((1000 ** 5)) ;;
            PiB) _mult=$((1024 ** 5)) ;;
            *)   _mult=1 ;;
        esac
    elif [[ "$_sz" =~ ^([0-9]+)([KMGTPB])$ ]]; then
        _num="${BASH_REMATCH[1]}"
        _unit="${BASH_REMATCH[2]}"
        case "$_unit" in
            K) _mult=$((1024)) ;;
            M) _mult=$((1024 ** 2)) ;;
            G) _mult=$((1024 ** 3)) ;;
            T) _mult=$((1024 ** 4)) ;;
            P) _mult=$((1024 ** 5)) ;;
            B) _mult=$((1)) ;;
        esac
    elif [[ "$_sz" =~ ^[0-9]+$ ]]; then
        _num="$_sz"
        _mult=1
    else
        return 1
    fi
    printf '%s' "$(( _num * _mult ))"
}

_region_sizes_sum() {
    local _sum=0 _rv _rvs _rb
    for _rv in $REGION_PARTITIONED; do
        eval "_rvs=\${REGION_${_rv^^}_SIZE:-}"
        [ -z "$_rvs" ] && continue
        _rb="$(_size_to_bytes "$_rvs")" || continue
        _sum=$(( _sum + _rb ))
    done
    unset _rv _rvs _rb
    printf '%s' "$_sum"
}

_disk_budget_check() {
    local _disk_b="${DISK_BYTES:-}" _esp_b _reg_b _need _lin_b
    if [ -z "$_disk_b" ] || ! [[ "$_disk_b" =~ ^[0-9]+$ ]]; then
        echo "WARN [DISK-BUDGET]: disk size for ${DISK:-<unset>} unreadable — skipping pre-write fit check."
        return 0
    fi
    _esp_b="$(_size_to_bytes "${EFI_PART_SIZE:-}")"
    if [ -z "$_esp_b" ]; then
        echo "FATAL [DISK-BUDGET]: could not parse ESP size '${EFI_PART_SIZE:-<unset>}' for the fit check." >&2
        return 1
    fi
    _reg_b="$(_region_sizes_sum)"
    _need=$(( _esp_b + _reg_b + DISK_BUDGET_MIN_SYS ))
    _lin_b=$(( _disk_b - _need ))
    if [ "$_lin_b" -lt 0 ]; then
        echo "${C_RED}!! FATAL [DISK-BUDGET]: layout does NOT fit on ${DISK} (${_disk_b} bytes)." >&2
        echo "     ESP(+${EFI_PART_SIZE}) + carved regions (${_reg_b} bytes) + >=1 GiB system" >&2
        echo "     remainder would need ${_need} bytes total — ${_lin_b} bytes short. Nothing" >&2
        echo "     was written. Reduce the ESP and/or carved-region sizes and re-run.${C_RST}" >&2
        return 1
    fi
    echo "OK [DISK-BUDGET]: ESP(+${EFI_PART_SIZE}) + regions (${_reg_b} B) + LINUX remainder (${_lin_b} B >= 1 GiB) fit inside ${_disk_b} B."
    return 0
}

REPO_PRIMARY="${REPO_PRIMARY:-https://mirrors.summithq.com/voidlinux/current}"
REPO_BACKUP1="${REPO_BACKUP1:-https://repo-fastly.voidlinux.org/current}"
REPO_BACKUP2="${REPO_BACKUP2:-https://repo-default.voidlinux.org/current}"
REPO_EXTRA1="${REPO_EXTRA1:-https://repo-de.voidlinux.org/current}"
REPO_EXTRA2="${REPO_EXTRA2:-https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current}"

LIVECD_SYNC_OK=0
YK_LIVE_PKGS=""
[ "$YK_MODE" = "hmac-sha1" ] && YK_LIVE_PKGS=" ykpers"
if [ "$DRY_RUN" = "1" ]; then
    echo "==> [DRY-RUN] Skipping live-CD package sync (would install gptfdisk/parted/kpartx/btrfs-progs/openssl${YK_LIVE_PKGS} into the live env)."
    LIVECD_SYNC_OK=1
else
for REPO_ATTEMPT in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
    echo "==> Attempting live-CD package sync against repository: ${REPO_ATTEMPT}"
    if xbps-install -Syu -R "$REPO_ATTEMPT" ${LOCAL_CA} xbps -y && xbps-install -R "$REPO_ATTEMPT" ${LOCAL_CA} gptfdisk parted kpartx btrfs-progs openssl${YK_LIVE_PKGS} -y; then
        LIVECD_SYNC_OK=1
        echo "==> Live-CD package sync succeeded using: ${REPO_ATTEMPT}"
        break
    fi
    echo "==> Live-CD package sync attempt against ${REPO_ATTEMPT} failed — trying next repository, if any." >&2
done
fi

if [ "$LIVECD_SYNC_OK" -ne 1 ]; then
    echo "FATAL: live-CD package sync failed against all configured repositories (primary + both backups + region extras)." >&2
    exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "==> [DRY-RUN] Skipping [PREREQ] outer-tool check (a plan run never partitions; sgdisk/parted/btrfs are not required on the medium)."
else
for _prereq in sgdisk mkfs.fat mkfs.btrfs btrfs parted openssl mount umount \
               chroot lsblk blkid xbps-install${YK_LIVE_PKGS:+ ykpersonalize ykchalresp}; do
    if ! command -v "$_prereq" >/dev/null 2>&1; then
        echo "FATAL: required live-CD command not found: '${_prereq}'." >&2
        echo "       The live-CD package sync reported success, but this tool is missing." >&2
        exit 1
    fi
done
unset _prereq
fi

if [ "$RESUME" != "1" ] && [ "$YK_MODE" = "hmac-sha1" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}YubiKey hmac-sha1 enrollment${C_RST}"
    echo ""
    echo "  The installer is about to PROGRAM OTP slot ${YK_SLOT} on the attached"
    echo "  YubiKey with a freshly generated random secret. This OVERWRITES whatever"
    echo "  currently lives in that slot (e.g. any OTP/static-password config)."
    echo "  The unlocked volume will expect HMAC-SHA1(slot_secret, challenge) as a"
    echo "  LUKS key at every boot."
    echo ""
    ask "Program slot ${YK_SLOT} now — confirm the key is plugged in? [y/N]: "
    read -r YK_ENROLL_CONFIRM
    if ! { [ "$YK_ENROLL_CONFIRM" = "y" ] || [ "$YK_ENROLL_CONFIRM" = "Y" ]; }; then
        echo ">>> YubiKey enrollment aborted; installing without YubiKey unlock (passphrase only)." >&2
        YK_MODE="off"
        YK_FALLBACK="yes"
        YK_SLOT="1"
        YK_TOUCH="no"
        YK_LIVE_PKGS=""
    else
        YK_TOUCH_OPT=""
        [ "$YK_TOUCH" = "yes" ] && YK_TOUCH_OPT=" -ochal-btn-trig"
        if ! ykpersonalize "-${YK_SLOT}" -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible${YK_TOUCH_OPT} -y 2>&1; then
            echo "FATAL: ykpersonalize failed to program slot ${YK_SLOT}. Check the YubiKey is plugged in (no hub pass-through) and not read-only." >&2
            exit 1
        fi
        YK_CHALLENGE=$(head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 40)
        [ -z "$YK_CHALLENGE" ] && { echo "FATAL: could not generate the 40-hex YubiKey challenge." >&2; exit 1; }
        YK_KEY=$(ykchalresp "-${YK_SLOT}" "$YK_CHALLENGE" 2>&1)
        [ -z "$YK_KEY" ] && { echo "FATAL: ykchalresp failed to compute the HMAC response. Enrollment incomplete." >&2; exit 1; }
        echo "==> Slot ${YK_SLOT} programmed and LUKS key envelope computed (key held in memory only)."
        unset YK_TOUCH_OPT YK_ENROLL_CONFIRM
    fi
fi

if [ "$RESUME" != "1" ]; then
    if [ "$ACCOUNT_MODEL" != "ubuntu" ]; then
        ROOT_PASS_HASH=$(openssl passwd -6 -stdin <<< "$ROOT_PASSWORD")
    else
        ROOT_PASS_HASH=""
    fi
    TARGET_PASS_HASH=$(openssl passwd -6 -stdin <<< "$TARGET_USER_PASSWORD")
    ROOT_PASSWORD=""
    TARGET_USER_PASSWORD=""
    unset ROOT_PASSWORD TARGET_USER_PASSWORD
fi

{
    printf 'export RESUME_TYPE="coarse"\n'
    for _sv in ACCOUNT_MODEL ROOT_PASS_HASH TARGET_PASS_HASH TARGET_USER TARGET_HOSTNAME \
               TARGET_DOMAIN TARGET_FQDN NET_INTERFACE_MATCH BOOTLOADER \
               EFI_PART_SIZE KERNEL_MODE DESKTOP_ENV DISPLAY_MANAGER \
               HAS_GRAPHICAL INSTALL_XORG INSTALL_AUDIO \
               USER_SHELL USER_SHELL_PKG \
               LIGHTDM_GREETER LIGHTDM_GREETER_PKG LIGHTDM_GREETER_SESSION \
               LIMINE_WALLPAPER LIMINE_WALLPAPER_STYLE \
               SESSION_STACK ENABLE_SNAPSHOT_AUDIO \
               LOCALE LOCALE_CODESET TIMEZONE SWAP_BACKEND SWAPFILE_MODE ENABLE_HIBERNATION SWAPFILE_SIZE \
               INSTALL_KERNEL_MAINLINE INSTALL_KERNEL_LTS KERNEL_PKGS \
DEVICE_PROFILE PROFILE_TLP PROFILE_BT PROFILE_PRELOAD \
                INSTALL_SSH_SERVER SSH_PORT SSH_PASSWORD_AUTH SSH_ROOT_LOGIN \
                IMPORT_SSH_KEY GENERATE_SSH_KEY EXPORT_SSH_KEY \
                INSTALL_NVIDIA GPU_FAMILIES HAS_NVIDIA_GPU HAS_AMD_GPU HAS_INTEL_GPU WIFI_HW \
                ENCRYPT \
               CRYPT_NAME \
               YK_MODE YK_FALLBACK YK_SLOT YK_CHALLENGE YK_TOUCH \
               REGION_HOME_FS REGION_VAR_FS REGION_CACHE_FS REGION_SRV_FS REGION_OPT_FS REGION_GAMES \
               REGION_HOME_SIZE REGION_VAR_SIZE REGION_CACHE_SIZE REGION_SRV_SIZE REGION_OPT_SIZE REGION_GAMES_SIZE \
               REGION_PARTITIONED \
               REPO_PRIMARY REPO_BACKUP1 REPO_BACKUP2 REPO_EXTRA1 REPO_EXTRA2 \
               LOCAL_CACHE_REUSE LOCAL_CACHE_DIR \
DISTROBOX_TRACK DISTROBOX_DEFAULT_ENGINE INSTALL_OCTOXBPS \
INSTALL_FLATPAK INSTALL_COSMIC_STORE INSTALL_BREW INSTALL_FIREFOX INSTALL_CHROMIUM \
                 INSTALL_VIVALDI INSTALL_FALKON INSTALL_BRAVE \
                 INSTALL_THUNDERBIRD INSTALL_STEAM INSTALL_VIRTUALBOX \
                 INSTALL_LUTRIS INSTALL_HEROIC INSTALL_BOTTLES INSTALL_WINE INSTALL_GAMEMODE INSTALL_ANY_GAME \
                SETUP_WEB_BROWSERS SETUP_CONTAINERS \
                 SUBVOL_ISOLATE_INSTALLED SUBVOL_PRECREATE \
                INSTALL_PODMAN INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL \
               INSTALL_PODMAN INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL \
               INSTALL_DOCKER DOCKER_GROUP_ADD INSTALL_DISTROBOX INSTALL_VIRT \
               PROVISION_FIREFOX_SUBVOL PROVISION_CHROMIUM_SUBVOL \
               PROVISION_VIVALDI_SUBVOL PROVISION_FALKON_SUBVOL \
               PROVISION_BRAVE_SUBVOL \
                PROVISION_THUNDERBIRD_SUBVOL PROVISION_GAME_SUBVOL \
                PROVISION_VIRTUALBOX_SUBVOL PROVISION_LINUXBREW_SUBVOL \
                 PROVISION_FLATPAK_SUBVOL PROVISION_DOCKER_SUBVOL \
                 PROVISION_PODMAN_SUBVOL PROVISION_PODMAN_ROOTLESS_SUBVOL \
                 PROVISION_VIRT_SUBVOL \
                DISK PART_EFI PART_SYS DISK_BYTES; do
        printf 'export %s=%q\n' "$_sv" "${!_sv}"
    done
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"
echo "==> Install state saved to ${STATE_FILE} (resumable later with '$0 -r')."
STAGE_CONTEXT="STAGE1:partition"
jl "Config persisted to $STATE_FILE (DISK=${DISK}, bootloader=${BOOTLOADER})"
unset _sv

if [ "$DRY_RUN" = "1" ]; then
    if ! _disk_budget_check; then
        echo "  Dry-run aborted by the pre-write fit check (above)." >&2
        exit 1
    fi
    echo ""
    echo "${C_MAG}========================= DRY-RUN PLAN =========================${C_RST}"
    echo "  Mode                  : --dry-run — no disk changes performed."
    echo "  Target disk           : ${DISK:-<not selected>} (${DISK_BYTES:-<size unreadable>} bytes)"
    echo "  Destructive steps     : sgdisk -Z + -og, ESP(+${EFI_PART_SIZE}) + LINUX parts,"
    echo "                          mkfs.fat -F32 EFI, mkfs.btrfs -f, subvolume layout."
    echo "  Headroom              : >= 1 GiB LINUX system remainder required (DISK-BUDGET pass)"
    echo "  Bootloader            : ${BOOTLOADER:-<unset>}"
    if [ "$BOOTLOADER" = "limine" ]; then
        echo "  Kernel access         : ${KERNEL_MODE:-<unset>} (Limine)"
        echo "  Wallpaper             : ${LIMINE_WALLPAPER:-none}${LIMINE_WALLPAPER_STYLE:+ (style=${LIMINE_WALLPAPER_STYLE})}"
    fi
    if [ "$HAS_GRAPHICAL" = "yes" ]; then
        echo "  Desktop / DM          : ${DESKTOP_ENV:-<unset>} / ${DISPLAY_MANAGER:-<unset>} (graphical)"
    else
        echo "  Desktop / DM          : ${DESKTOP_ENV:-<unset>} / ${DISPLAY_MANAGER:-<unset>} (headless)"
    fi
    echo "  Session stack         : ${SESSION_STACK:-<unset>}"
    echo "  Login shell           : ${USER_SHELL:-<unset>}"
    echo "  User / full name      : ${TARGET_USER:-<unset>}${TARGET_FULL_NAME:+ (${TARGET_FULL_NAME})}"
    echo "  Locale / Timezone     : ${LOCALE:-<unset>} / ${TIMEZONE:-<unset>}"
    echo "  Repo (primary)        : ${REPO_PRIMARY:-<unset>}"
    echo "  Swap / Hibernation    : ${SWAP_BACKEND:-<unset>} / ${ENABLE_HIBERNATION:-<unset>}"
    echo "  Encryption            : ${ENCRYPT:-no}${ENCRYPT:+$([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo " (LUKS2 full-disk + YubiKey hmac-sha1, fallback=$YK_FALLBACK)" || echo " (LUKS2 full-disk, passphrase at boot)"; } || true)}"
    echo "  Data regions (MULTI-FS): carved=['${REGION_PARTITIONED:-}'] home=${REGION_HOME_FS:-btrfs} var=${REGION_VAR_FS:-btrfs} cache=${REGION_CACHE_FS:-btrfs} srv=${REGION_SRV_FS:-btrfs} opt=${REGION_OPT_FS:-btrfs} games=${REGION_GAMES:-none}"
    echo "  Accounts model        : ${ACCOUNT_MODEL:-<unset>}"
    echo "  App channels          : Flatpak=${INSTALL_FLATPAK:-no} cosmic-store=${INSTALL_COSMIC_STORE:-no} Homebrew=${INSTALL_BREW:-no}"
    echo "  Game launchers        : steam=${INSTALL_STEAM:-no} lutris=${INSTALL_LUTRIS:-no} heroic=${INSTALL_HEROIC:-no} bottles=${INSTALL_BOTTLES:-no} wine=${INSTALL_WINE:-no} gamemode=${INSTALL_GAMEMODE:-no}"
    echo "  Hardware              : GPU=${GPU_FAMILIES:-<none detected>} wireless=${WIFI_HW:-unknown}"
    echo "  NVIDIA driver         : ${INSTALL_NVIDIA:-auto}"
    echo "=============================================================="
    echo "  Nothing was written to disk. Re-run WITHOUT --dry-run to install for real."
    echo ""
    rm -f "$STATE_FILE" 2>/dev/null || true
    if [ -d /tmp/ssh-keygen ] || [ -d /tmp/ssh-import ]; then
        shred -u /tmp/ssh-keygen/* /tmp/ssh-import/* 2>/dev/null || true
        rm -rf /tmp/ssh-keygen /tmp/ssh-import 2>/dev/null || true
        echo "  SSH key stage shredded from live environment (dry-run exit)."
    fi
    exit 0
fi

PKG_PREFLIGHT="
accountsservice
acpid
alsa-pipewire
alsa-plugins-pulseaudio-32bit
alsa-ucm-conf
alsa-utils
ark
base-system
bash
bash-completion
binutils
blueman
bluez
bridge-utils
btrfs-progs
catatonit
chromium
chrony
cinnamon-all
cronie
crun
cryptsetup
curl
dbus
docker
dracut
efibootmgr
elogind
falkon
fastfetch
FeatherPad
file
firefox
fish-shell
flatpak
fontconfig-32bit
freetype-32bit
fuse
fuse3
fuse-overlayfs
gamemode
gdm
gedit
git
glibc-locales
gnome
gnome-backgrounds
gnome-terminal
go
greetd
grub-btrfs
grub-btrfs-runit
grub-x86_64-efi
udiskie
udisks2
gvfs
inotify-tools
intel-ucode
iptables
kde-baseapps
kde-plasma
kio-admin
kpartx
libdrm-32bit
libgamemode-32bit
libgcc-32bit
libglvnd-32bit
libjack-pipewire
libpulseaudio-32bit
libspa-bluetooth
libstdc++-32bit
libvirt
libX11-32bit
libxcb-32bit
libXcursor-32bit
libXext-32bit
libXfixes-32bit
libXi-32bit
libXinerama-32bit
libXrandr-32bit
libXrender-32bit
libXss-32bit
libXxf86vm-32bit
lightdm
lightdm-gtk-greeter
lightdm-slick-greeter
limine
linux
linux-firmware
linux-firmware-amd
linux-firmware-broadcom
linux-headers
linux-lts
linux-lts-headers
linux-mainline
linux-mainline-headers
lutris
lxqt
lxqt-policykit
make
mesa-dri-32bit
mesa-vulkan-intel
mesa-vulkan-intel-32bit
mesa-vulkan-nouveau
mesa-vulkan-nouveau-32bit
mesa-vulkan-radeon
mesa-vulkan-radeon-32bit
mate
mate-media
mate-terminal
mksh
nano
NetworkManager
network-manager-applet
nftables
nvidia
octoxbps
openssh
parted
pipewire
plasma-pa
pluma
podman
polkit
polkit-gnome
power-profiles-daemon
preload
procps-ng
qemu
rsync
runit-nftables
sddm
seatd
slirp4netns
smartmontools
snapper
sof-firmware
steam
sudo
thunderbird
tlp
tlp-rdw
turnstile
vim
virt-manager
virtualbox-ose
virtualbox-ose-dkms
vivaldi
void-repo-multilib
void-repo-multilib-nonfree
void-repo-nonfree
wayland
wayland-protocols
wget
wine
wireplumber
xbps
xdg-user-dirs
xdg-utils
xfce4
xfce4-pulseaudio-plugin
xorg
xtools
ykpers
zramen
zsh
"
echo ""
echo "Stage-1 package preflight [PKG-PREFLIGHT]: verifying package names against the live union pool..."
jl "PKG-PREFLIGHT: begin — checking $(echo "$PKG_PREFLIGHT" | grep -c .) candidate packages"

xbps-install -y void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree >/dev/null 2>&1 || true

if ! xbps-install -Sy >/dev/null 2>&1; then
    echo "  WARN: live -Sy refresh failed (network/repo hiccup); preflight DEGRADED — skipping package-name gate." >&2
    jl "PKG-PREFLIGHT: DEGRADED — xbps-install -Sy failed (network/repo hiccup); gate skipped"
else
    if ! xbps-query -Rs "^base-system$" >/dev/null 2>&1; then
        echo "  WARN: base-system is not resolvable after -Sy — repo config issue; preflight DEGRADED — skipping." >&2
        jl "PKG-PREFLIGHT: DEGRADED — base-system not in pool; gate skipped"
    else
        _pre_missing=""
        _pre_total=0
        for _pre_pkg in $PKG_PREFLIGHT; do
            _pre_total=$((_pre_total + 1))
            if ! xbps-query -Rs "^${_pre_pkg}$" >/dev/null 2>&1; then
                _pre_missing="${_pre_missing:+${_pre_missing} }${_pre_pkg}"
            fi
        done
        if [ -n "$_pre_missing" ]; then
            echo "" >&2
            echo "${C_RED}==============================================================================${C_RST}" >&2
            echo "${C_RED}  FATAL: [PKG-PREFLIGHT] — the following packages are NOT resolvable in the${C_RST}" >&2
            echo "${C_RED}  official Void Linux union pool:${C_RST}" >&2
            echo "" >&2
            for _pre_pkg in $_pre_missing; do
                echo "    - ${_pre_pkg}" >&2
            done
            echo "" >&2
            echo "  This is crash #005 (a doomed install would write the disk, then die" >&2
            echo "  in the chroot when xbps-install fails). The disk is still untouched." >&2
            echo "  Add the package(s) to Void's official repos or remove the option." >&2
            echo "${C_RED}==============================================================================${C_RST}" >&2
            echo "" >&2
            jl "PKG-PREFLIGHT: ABORT — unresolvable packages: ${_pre_missing}"
            exit 1
        fi
        echo "  ALL ${_pre_total} preflight packages resolve in the live union pool."
        jl "PKG-PREFLIGHT: ALL COVERED (${_pre_total} packages)"
    fi
fi

if command -v curl >/dev/null 2>&1; then
    _pre_probe="base-system"
    [ "$INSTALL_PODMAN" = "true" ] && _pre_probe="$_pre_probe runc podman"
    [ "$INSTALL_DOCKER" = "true" ] && _pre_probe="$_pre_probe docker"
    _pre_pick=""
    for _pre_m in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
        case " $_pre_pick " in *" $_pre_m "*) continue ;; esac
        _pre_torn=""
        for _pre_p in $_pre_probe; do
            _pre_v=$(xbps-query -M -R --repository="$_pre_m" --property=pkgver "$_pre_p" 2>/dev/null | tail -1)
            if [ -z "$_pre_v" ]; then
                _pre_torn="${_pre_torn}${_pre_torn:+ }unresolvable:$_pre_p"
                continue
            fi
            _pre_code=$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 15 "$_pre_m/${_pre_v}.x86_64.xbps.sig")
            if [ "$_pre_code" != "200" ]; then
                _pre_torn="${_pre_torn}${_pre_torn:+ }${_pre_p}(sig ${_pre_code})"
            fi
        done
        if [ -z "$_pre_torn" ]; then
            _pre_pick="$_pre_m"
            break
        fi
        echo "  WARN [MIRROR-SKEW-PREFLIGHT]: mirror ${_pre_m} is mid-rotation for: ${_pre_torn} — skipping it." >&2
        jl "MIRROR-SKEW-PREFLIGHT: torn mirror: ${_pre_m} (${_pre_torn})"
    done
    if [ -n "$_pre_pick" ] && [ "$_pre_pick" != "$REPO_PRIMARY" ]; then
        echo "==> [MIRROR-SKEW-PREFLIGHT] promoting consistent mirror to REPO_PRIMARY: ${_pre_pick}"
        REPO_PRIMARY="$_pre_pick"
        jl "MIRROR-SKEW-PREFLIGHT: promoted REPO_PRIMARY -> ${_pre_pick}"
    elif [ -z "$_pre_pick" ]; then
        echo "  WARN [MIRROR-SKEW-PREFLIGHT]: every configured mirror is torn for probe set '${_pre_probe}' — continuing; the bounded skew-retry will ride out the rotation inside install_pkgs." >&2
        jl "MIRROR-SKEW-PREFLIGHT: all mirrors torn (probe: ${_pre_probe}); continuing"
    fi
    unset _pre_probe _pre_pick _pre_m _pre_torn _pre_p _pre_v _pre_code
fi

BTRFS_DEV="$PART_SYS"
CRYPT_NAME="${CRYPT_NAME:-void-root}"
CRYPT_DEV="/dev/mapper/${CRYPT_NAME}"

if [ "$RESUME" != "1" ]; then
    _disk_budget_check || exit 1
    sgdisk -Z "$DISK" && sgdisk -og "$DISK"
    sgdisk -n "1::+${EFI_PART_SIZE}" -t 1:ef00 -c 1:'ESP' "$DISK"
    if [ -n "${REGION_PARTITIONED:-}" ] && [ "$ENCRYPT" != "yes" ]; then
        _rr_pn=2
        for _rr in $REGION_PARTITIONED; do
            eval "_rr_n=\${REGION_${_rr^^}_SIZE:-}"
            if [ -z "$_rr_n" ]; then
                echo "FATAL: region '$_rr' carved but REGION_${_rr^^}_SIZE is unset." >&2
                exit 1
            fi
            _rr_posn="${_rr_n#+}"
            sgdisk -n "${_rr_pn}::+${_rr_posn}" -t "${_rr_pn}":8300 -c "${_rr_pn}":"LINUX-${_rr}" "$DISK"
            _rr_pn=$((_rr_pn + 1))
        done
        sgdisk -n "${_rr_pn}::" -t "${_rr_pn}":8300 -c "${_rr_pn}":'LINUX' "$DISK"
        unset _rr_pn _rr_posn _rr _rr_n
    else
        sgdisk -n 2:: -t 2:8300 -c 2:'LINUX' "$DISK"
    fi
    jl "MULTI-FS-RUNLOG: outer carve on ${DISK} complete (regions: ${REGION_PARTITIONED:-none})"
    partprobe "$DISK"
    sleep 2

    if [ "$ENCRYPT" = "yes" ]; then
        if [ -e "$CRYPT_DEV" ]; then
            echo "==> Closing leftover open mapper ${CRYPT_DEV} from an interrupted run"
            cryptsetup luksClose "$CRYPT_NAME" 2>/dev/null || true
        fi
        echo ""
        echo "==> Formatting partition 2 as a LUKS2 container (cryptsetup)"
        printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksFormat --type luks2 -q --key-file=- "$PART_SYS"
        echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV}"
        printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"
        echo "==> Verifying the passphrase can re-unlock ${PART_SYS} (close + re-open)..."
        cryptsetup luksClose "$CRYPT_NAME"
        if ! printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"; then
            echo "${C_RED}!! FATAL: the passphrase that created the container does not PARSE as"
            echo "     the passphrase needed to unlock it. The disk would be UNBOOTABLE.${C_RST}" >&2
            echo "     This is a keymap/typing mismatch between the two entries (or a cryptsetup" >&2
            echo "     keyfile/stdin quirk). Power-cycle, re-run with a simpler passphrase, and" >&2
            echo "     if it recurs, capture this screen for the installer maintainers." >&2
            exit 1
        fi
        echo "   OK: passphrase verified (luksFormat key == unlock key)."
        BTRFS_DEV="$CRYPT_DEV"
        if [ -n "${REGION_PARTITIONED:-}" ]; then
            echo "==> Carving inner GPT inside ${BTRFS_DEV} (MULTI-FS + ENCRYPT)..."
            sgdisk -Z "$BTRFS_DEV" && sgdisk -og "$BTRFS_DEV"
            _rr_pn=1
            for _rr in $REGION_PARTITIONED; do
                eval "_rr_n=\${REGION_${_rr^^}_SIZE:-}"
                [ -n "$_rr_n" ] || { echo "FATAL: region '$_rr' carved but REGION_${_rr^^}_SIZE unset." >&2; exit 1; }
                _rr_posn="${_rr_n#+}"
                sgdisk -n "${_rr_pn}::+${_rr_posn}" -t "${_rr_pn}":8300 -c "${_rr_pn}":"LINUX-${_rr}" "$BTRFS_DEV"
                _rr_pn=$((_rr_pn + 1))
            done
            sgdisk -n "${_rr_pn}::" -t "${_rr_pn}":8300 -c "${_rr_pn}":'LINUX' "$BTRFS_DEV"
            unset _rr_pn _rr_posn _rr
            cryptsetup luksClose "$CRYPT_NAME"
            printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"
            _region_inner_partscan
            _region_inner_dev
            jl "MULTI-FS inner GPT carved inside LUKS2; BTRFS_DEV=${BTRFS_DEV} PART_SYS=${PART_SYS}"
        fi
        if [ "$YK_MODE" = "hmac-sha1" ]; then
            YK_KEY_FILE="/tmp/void-yubikey-key"
            printf '%s' "$YK_KEY" > "$YK_KEY_FILE"
            chmod 600 "$YK_KEY_FILE"
            echo "==> Binding YubiKey hmac-sha1 response as a LUKS key slot"
            printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksAddKey "$PART_SYS" --key-file=- --new-keyfile="$YK_KEY_FILE"
            if [ "$YK_FALLBACK" = "no" ]; then
                echo "==> Removing the typed-passphrase slot (YubiKey-only unlock)"
                cryptsetup luksRemoveKey "$PART_SYS" --key-file="$YK_KEY_FILE" --key-slot 0 || true
            fi
            shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
            unset YK_KEY YK_KEY_FILE
            echo "   YubiKey unlock enabled; passphrase fallback=${YK_FALLBACK}."
        fi
        unset ENCRYPT_PASSPHRASE
        jl "LUKS2 container created+opened for $PART_SYS -> $BTRFS_DEV"
    fi

    mkfs.fat -F32 -n EFI "$PART_EFI"
    if [ -n "${REGION_PARTITIONED:-}" ]; then
        for _rr in $REGION_PARTITIONED; do
            eval "_rr_dev=\${REGION_PART_${_rr}:-}"
            _rr_fs="$(_region_fs_of "$_rr")"
            [ -n "$_rr_dev" ] || { echo "FATAL: REGION_PART_${_rr} unset — region device was never resolved." >&2; exit 1; }
            [ -e "$_rr_dev" ] || { echo "FATAL: region device ${_rr_dev} for '${_rr}' does not exist (partscan?)." >&2; exit 1; }
            echo "==> Formatting region '${_rr}' (${_rr_fs}) on ${_rr_dev}"
            jl "MULTI-FS-RUNLOG: mkfs '${_rr}' (${_rr_fs}) on ${_rr_dev}"
            case "$_rr_fs" in
                ext4) mkfs.ext4 -F -L "VOID-${_rr}" "$_rr_dev" ;;
                btrfs) mkfs.btrfs -f -L "VOID-${_rr}" "$_rr_dev" ;;
                *) echo "FATAL: unsupported region filesystem '$_rr_fs' for '$_rr'." >&2; exit 1 ;;
            esac
        done
        unset _rr _rr_dev _rr_fs
    fi
    mkfs.btrfs -f -L VOID "$BTRFS_DEV"
    mount -v "$BTRFS_DEV" /mnt
else
    umount -l /mnt 2>/dev/null || true

    if [ "$ENCRYPT" = "yes" ]; then
        if [ -e "$CRYPT_DEV" ]; then
            echo "==> ${CRYPT_DEV} is already active — checking it maps ${PART_SYS}"
            if cryptsetup status "$CRYPT_NAME" 2>/dev/null | grep -q "device:.*${PART_SYS}"; then
                echo "   OK: reusing existing mapper (no re-unlock needed)."
                BTRFS_DEV="$CRYPT_DEV"
                jl "LUKS2 mapper already open on resume: $PART_SYS -> $BTRFS_DEV"
            else
                echo "${C_RED}!! FATAL: ${CRYPT_DEV} is active but does NOT map ${PART_SYS}.${C_RST}" >&2
                echo "     Close it first, e.g. 'cryptsetup luksClose ${CRYPT_NAME}', then re-run." >&2
                exit 1
            fi
        else
            if [ "$YK_MODE" = "hmac-sha1" ]; then
                YK_KEY_FILE="/tmp/void-yubikey-key"
                YK_KEY=$(ykchalresp "-${YK_SLOT}" "$YK_CHALLENGE" 2>&1)
                [ -n "$YK_KEY" ] || { echo "FATAL: YubiKey unlock failed (ykchalresp did not return a response)." >&2; exit 1; }
                printf '%s' "$YK_KEY" > "$YK_KEY_FILE"
                chmod 600 "$YK_KEY_FILE"
                echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV} (YubiKey)"
                if ! cryptsetup luksOpen --key-file="$YK_KEY_FILE" "$PART_SYS" "$CRYPT_NAME"; then
                    shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
                    unset YK_KEY YK_KEY_FILE
                    if [ "$YK_FALLBACK" = "yes" ]; then
                        echo "   YubiKey unlock failed (absent/wrong?). Falling back to typed passphrase." >&2
                        echo ""
                        echo "Enter the passphrase to unlock ${PART_SYS} (LUKS2):"
                        read -r -s ENCRYPT_PASSPHRASE
                        echo
                        [ -n "$ENCRYPT_PASSPHRASE" ] || { echo "FATAL: empty passphrase." >&2; exit 1; }
                        echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV} (passphrase fallback)"
                        if ! printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"; then
                            echo "${C_RED}!! FATAL: could not unlock ${PART_SYS} with the passphrase given." >&2
                            echo "     The volume exists but the passphrase does not open it.${C_RST}" >&2
                            exit 1
                        fi
                        unset ENCRYPT_PASSPHRASE
                    else
                        echo "FATAL: YubiKey unlock failed and no passphrase fallback exists (possession-only)." >&2
                        exit 1
                    fi
                else
                    shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
                    unset YK_KEY YK_KEY_FILE
                fi
            else
                echo ""
                echo "Enter the passphrase to unlock ${PART_SYS} (LUKS2):"
                read -r -s ENCRYPT_PASSPHRASE
                echo
                [ -n "$ENCRYPT_PASSPHRASE" ] || { echo "FATAL: empty passphrase." >&2; exit 1; }
                echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV}"
                if ! printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"; then
                    echo "${C_RED}!! FATAL: could not unlock ${PART_SYS} with the passphrase given." >&2
                    echo "     The volume exists but the passphrase does not open it.${C_RST}" >&2
                    exit 1
                fi
                unset ENCRYPT_PASSPHRASE
            fi
            BTRFS_DEV="$CRYPT_DEV"
            jl "LUKS2 mapper re-opened for resume: $PART_SYS -> $BTRFS_DEV"
        fi
    fi

    if [ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ]; then
        _region_inner_partscan
        _region_inner_dev
        jl "MULTI-FS resume: inner region devices resolved; BTRFS_DEV=${BTRFS_DEV}"
    fi

    mount -v -o subvolid=5 "$BTRFS_DEV" /mnt
fi
BASE_LAYOUT="@ @home @opt @srv @snapshots @cache @log @spool @usercache @root"
for _fld in @home @opt @srv @cache @log @spool @usercache; do
    case "$_fld" in
        @home)      _fldr="home" ;;
        @opt)       _fldr="opt" ;;
        @srv)       _fldr="srv" ;;
        @cache)     _fldr="cache" ;;
        @log|@spool)    _fldr="var" ;;
        @usercache) _fldr="home" ;;
    esac
    if _region_carved "$_fldr"; then
        BASE_LAYOUT="${BASE_LAYOUT/ $_fld / }"
        jl "MULTI-FS-FOLD: pruned ${_fld} from BASE_LAYOUT (${_fldr} region carved)"
    fi
done
unset _fld _fldr
GRUB_ESP_BOOT="false"
[ "$BOOTLOADER" = "grub" ] && [ "$ENCRYPT" = "yes" ] && GRUB_ESP_BOOT="true"
export GRUB_ESP_BOOT
SUBVOL_LIST="$BASE_LAYOUT"
if ! _region_carved var; then
    SUBVOL_LIST="$SUBVOL_LIST @network"
fi
[ "$PROVISION_VIRT_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @libvirt"
[ "$PROVISION_FLATPAK_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @flatpak"
[ "$PROVISION_DOCKER_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @docker"
[ "$PROVISION_PODMAN_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @containers"
[ "$PROVISION_PODMAN_ROOTLESS_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @containers-user"
[ "$DISPLAY_MANAGER" = "sddm" ] && ! _region_carved var && SUBVOL_LIST="$SUBVOL_LIST @sddm"
[ "$DISPLAY_MANAGER" = "lightdm" ] && ! _region_carved var && SUBVOL_LIST="$SUBVOL_LIST @lightdm"
[ "$BOOTLOADER" = "grub" ] && [ "$GRUB_ESP_BOOT" != "true" ] && SUBVOL_LIST="$SUBVOL_LIST @grub"
[ "$SWAPFILE_MODE" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @swap"
if [ "$PROVISION_FIREFOX_SUBVOL" = "true" ]; then
    SUBVOL_LIST="$SUBVOL_LIST @mozilla @mozilla-cache"
fi
[ "$PROVISION_CHROMIUM_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @chromium"
[ "$PROVISION_VIVALDI_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @vivaldi"
[ "$PROVISION_FALKON_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @falkon"
[ "$PROVISION_BRAVE_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @brave"

[ "$PROVISION_THUNDERBIRD_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @thunderbird"
[ "$PROVISION_GAME_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @game"
[ "$PROVISION_VIRTUALBOX_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @virtualbox"
[ "$PROVISION_LINUXBREW_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @linuxbrew"

if [ "$RESUME" = "1" ]; then
    echo "==> Resuming: resetting target Btrfs contents to a clean slate..."
    while IFS= read -r _svc; do
        [ -n "$_svc" ] || continue
        btrfs subvolume delete "/mnt/$_svc" >/dev/null 2>&1 || true
    done < <(btrfs subvolume list -o "/mnt" 2>/dev/null | sed -n 's/.*path \([^ ]*\)$/\1/p')
    unset _svc
    echo "==> Clean slate ready; recreating subvolume layout."
fi

for subv in $SUBVOL_LIST; do
    btrfs subvolume create /mnt/"$subv"
done
umount -v /mnt

BTRFS_OPTS="noatime,compress=zstd:1"
mount -vo $BTRFS_OPTS,subvol=@ "$BTRFS_DEV" /mnt

if [ "$LIMINE_WALLPAPER" = "yes" ] && [ -f "${WP_SRC:-}" ]; then
    mkdir -p /mnt/tmp
    cp -f "$WP_SRC" "/mnt/tmp/limine-splash.${WP_EXT,,}"
    echo "  Wallpaper re-staged into target → /mnt/tmp/limine-splash.${WP_EXT,,}"
fi

if [ -d /tmp/ssh-keygen ] || [ -d /tmp/ssh-import ]; then
    mkdir -p /mnt/tmp/ssh-keygen /mnt/tmp/ssh-import
    cp -f /tmp/ssh-keygen/* /mnt/tmp/ssh-keygen/ 2>/dev/null || true
    cp -f /tmp/ssh-import/* /mnt/tmp/ssh-import/ 2>/dev/null || true
    chmod -R go-rwx /mnt/tmp/ssh-keygen /mnt/tmp/ssh-import 2>/dev/null || true
fi

if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ] && [ -n "${LOCAL_CACHE_DIR:-}" ] && [ -d "$LOCAL_CACHE_DIR" ]; then
    mkdir -p /mnt/tmp/xbps-cache
    if ! mount -v --bind "$LOCAL_CACHE_DIR" /mnt/tmp/xbps-cache; then
        echo "!! Cache bind mount failed; continuing with a network-only install." >&2
        LOCAL_CACHE_REUSE="no"
        LOCAL_CACHE_DIR=""
    else
        echo "==> Media package cache bind-mounted → /mnt/tmp/xbps-cache (=/tmp/xbps-cache in the chroot)."
    fi
fi

mkdir -vp /mnt/home /mnt/.snapshots /mnt/opt /mnt/srv
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    mkdir -vp /mnt/boot
else
    [ "$BOOTLOADER" = "grub" ] && mkdir -vp /mnt/boot/grub
    mkdir -vp /mnt/boot/efi
fi
mkdir -vp /mnt/var/cache /mnt/var/log /mnt/var/spool /mnt/var/tmp
[ "$SWAPFILE_MODE" = "true" ] && mkdir -vp /mnt/var/swap
[ "$DISPLAY_MANAGER" = "sddm" ] && mkdir -vp /mnt/var/lib/sddm
[ "$DISPLAY_MANAGER" = "lightdm" ] && mkdir -vp /mnt/var/lib/lightdm
mkdir -vp /mnt/root
[ "$PROVISION_VIRT_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/libvirt
[ "$PROVISION_FLATPAK_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/flatpak
[ "$PROVISION_DOCKER_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/docker
[ "$PROVISION_PODMAN_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/containers
mkdir -vp /mnt/var/lib/NetworkManager



if ! _region_carved home; then
    mount -vo $BTRFS_OPTS,subvol=@home "$BTRFS_DEV" /mnt/home
fi
if ! _region_carved opt; then
    mount -vo $BTRFS_OPTS,subvol=@opt "$BTRFS_DEV" /mnt/opt
fi
if ! _region_carved srv; then
    mount -vo noatime,nodatacow,compress=none,subvol=@srv "$BTRFS_DEV" /mnt/srv
fi
mount -vo $BTRFS_OPTS,subvol=@snapshots "$BTRFS_DEV" /mnt/.snapshots
if ! _region_carved cache; then
    mount -vo noatime,nodatacow,compress=none,subvol=@cache "$BTRFS_DEV" /mnt/var/cache
fi
if [ "$DISPLAY_MANAGER" = "sddm" ] && ! _region_carved var; then
    mount -vo $BTRFS_OPTS,subvol=@sddm "$BTRFS_DEV" /mnt/var/lib/sddm
elif [ "$DISPLAY_MANAGER" = "lightdm" ] && ! _region_carved var; then
    mount -vo $BTRFS_OPTS,subvol=@lightdm "$BTRFS_DEV" /mnt/var/lib/lightdm
fi
if [ "$PROVISION_VIRT_SUBVOL" = "true" ]; then
    mount -vo noatime,nodatacow,compress=none,subvol=@libvirt "$BTRFS_DEV" /mnt/var/lib/libvirt
fi
if ! _region_carved var; then
    mount -vo noatime,nodatacow,compress=none,subvol=@log "$BTRFS_DEV" /mnt/var/log
    mount -vo noatime,nodatacow,compress=none,subvol=@spool "$BTRFS_DEV" /mnt/var/spool
fi
[ "$BOOTLOADER" = "grub" ] && [ "$GRUB_ESP_BOOT" != "true" ] && mount -vo $BTRFS_OPTS,subvol=@grub "$BTRFS_DEV" /mnt/boot/grub

[ "$PROVISION_FLATPAK_SUBVOL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@flatpak "$BTRFS_DEV" /mnt/var/lib/flatpak
[ "$PROVISION_DOCKER_SUBVOL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@docker "$BTRFS_DEV" /mnt/var/lib/docker
[ "$PROVISION_PODMAN_SUBVOL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@containers "$BTRFS_DEV" /mnt/var/lib/containers
if ! _region_carved var; then
    mount -vo $BTRFS_OPTS,subvol=@network "$BTRFS_DEV" /mnt/var/lib/NetworkManager
fi
mount -vo $BTRFS_OPTS,subvol=@root "$BTRFS_DEV" /mnt/root

if [ "$SWAPFILE_MODE" = "true" ]; then
    mount -vo defaults,noatime,nodatacow,compress=none,subvol=@swap "$BTRFS_DEV" /mnt/var/swap
fi
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    mount -v "$PART_EFI" /mnt/boot
else
    mount -v "$PART_EFI" /mnt/boot/efi
fi

if [ -n "${REGION_PARTITIONED:-}" ]; then
    for _rr in $REGION_PARTITIONED; do
        eval "_rr_dev=\${REGION_PART_${_rr}:-}"
        _rr_fs="$(_region_fs_of "$_rr")"
        [ -n "$_rr_dev" ] || { echo "FATAL: REGION_PART_${_rr} unset at region-mount time." >&2; exit 1; }
        case "$_rr" in
            home)  _rr_mp="/mnt/home" ; _rr_leaf="home" ;;
            var)   _rr_mp="/mnt/var" ; _rr_leaf="var" ;;
            cache) _rr_mp="/mnt/var/cache" ; _rr_leaf="var" ;;
            srv)   _rr_mp="/mnt/srv" ; _rr_leaf="srv" ;;
            opt)   _rr_mp="/mnt/opt" ; _rr_leaf="opt" ;;
            games) _rr_mp="/mnt/home/${TARGET_USER}/Games" ; _rr_leaf="home" ;;
            *) echo "FATAL: unknown region '$_rr'." >&2; exit 1 ;;
        esac
        mkdir -vp "$_rr_mp"
        if [ "$_rr_fs" = "ext4" ]; then
            mount -vo defaults,noatime "$_rr_dev" "$_rr_mp"
        else
            if [ "$_rr_leaf" = "var" ] || [ "$_rr_leaf" = "srv" ]; then
                mount -vo defaults,noatime,nodatacow,compress=none "$_rr_dev" "$_rr_mp"
            else
                mount -vo defaults,noatime,compress=zstd:1 "$_rr_dev" "$_rr_mp"
            fi
        fi
        echo "  Region '${_rr}' mounted ($_rr_fs) → ${_rr_mp}"
        jl "MULTI-FS-RUNLOG: region '${_rr}' mounted (${_rr_fs}) ${_rr_dev} -> ${_rr_mp}"
    done
    unset _rr _rr_dev _rr_fs _rr_mp _rr_leaf
fi

ARCH="x86_64"

mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

BOOTSTRAP_OK=0
for REPO_ATTEMPT in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
    echo "==> Attempting base-system bootstrap against repository: ${REPO_ATTEMPT}"
    if XBPS_ARCH=$ARCH xbps-install -Suv -R "$REPO_ATTEMPT" -r /mnt ${LOCAL_CA} base-system btrfs-progs $KERNEL_PKGS glibc-locales -y; then
        BOOTSTRAP_OK=1
        echo "==> Bootstrap succeeded using: ${REPO_ATTEMPT}"
        break
    fi
    echo "==> Bootstrap attempt against ${REPO_ATTEMPT} failed — trying next repository, if any." >&2
done

if [ "$BOOTSTRAP_OK" -ne 1 ]; then
    echo "FATAL: base-system bootstrap failed against all configured repositories (primary + both backups + region extras)." >&2
    exit 1
fi

for dir in dev proc sys run; do
    mount -v --rbind "/${dir}" "/mnt/${dir}"
    mount -v --make-rslave "/mnt/${dir}"
done
mount -v -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars
cp /etc/resolv.conf /mnt/etc/

BTRFS_UUID=$(blkid -s UUID -o value "$BTRFS_DEV")
EFI_UUID=$(blkid -s UUID -o value "$PART_EFI")

ESP_PARTUUID=$(lsblk -no PARTUUID --nodeps "$PART_EFI")
BTRFS_PARTUUID=$(lsblk -no PARTUUID --nodeps "$PART_SYS")
SYSPREFIX_ESP="guid(${ESP_PARTUUID})"
SYSPREFIX_BTRFS="guid(${BTRFS_PARTUUID})"

if [ "$SWAPFILE_MODE" = "true" ]; then
    rm -f /mnt/var/swap/swapfile
    btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE}" /mnt/var/swap/swapfile
    mkswap -L SWAP /mnt/var/swap/swapfile
fi

cat > /mnt/etc/fstab << EOF
UUID=$BTRFS_UUID /                btrfs noatime,compress=zstd:1,subvol=@ 0 0
UUID=$BTRFS_UUID /.snapshots      btrfs noatime,compress=zstd:1,subvol=@snapshots 0 0
tmpfs            /tmp             tmpfs defaults,noatime,mode=1777 0 0
tmpfs            /var/tmp         tmpfs defaults,noatime,mode=1777 0 0
EOF

if ! _region_carved home; then
    echo "UUID=$BTRFS_UUID /home            btrfs noatime,compress=zstd:1,subvol=@home 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved opt; then
    echo "UUID=$BTRFS_UUID /opt             btrfs noatime,compress=zstd:1,subvol=@opt 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved srv; then
    echo "UUID=$BTRFS_UUID /srv             btrfs noatime,nodatacow,compress=none,subvol=@srv 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved cache; then
    echo "UUID=$BTRFS_UUID /var/cache       btrfs noatime,nodatacow,compress=none,subvol=@cache 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/log         btrfs noatime,nodatacow,compress=none,subvol=@log 0 0" >> /mnt/etc/fstab
    echo "UUID=$BTRFS_UUID /var/spool       btrfs noatime,nodatacow,compress=none,subvol=@spool 0 0" >> /mnt/etc/fstab
fi

if [ -n "${REGION_PARTITIONED:-}" ]; then
    for _rr in $REGION_PARTITIONED; do
        eval "_rr_dev=\${REGION_PART_${_rr}:-}"
        _rr_fs="$(_region_fs_of "$_rr")"
        eval "_rr_uuid=\${REGION_UUID_${_rr}:-}"
        if [ -z "$_rr_uuid" ]; then
            _rr_uuid=$(blkid -s UUID -o value "$_rr_dev")
            eval "REGION_UUID_${_rr}=\"\${_rr_uuid}\""
        fi
        [ -n "$_rr_uuid" ] || { echo "FATAL: could not read UUID for region '$_rr' device $_rr_dev." >&2; exit 1; }
        case "$_rr" in
            home)  _rr_mp="/home" ; _rr_leaf="home" ;;
            var)   _rr_mp="/var" ; _rr_leaf="var" ;;
            cache) _rr_mp="/var/cache" ; _rr_leaf="var" ;;
            srv)   _rr_mp="/srv" ; _rr_leaf="srv" ;;
            opt)   _rr_mp="/opt" ; _rr_leaf="opt" ;;
            games) _rr_mp="/home/${TARGET_USER}/Games" ; _rr_leaf="home" ;;
            *) echo "FATAL: unknown region '$_rr'." >&2; exit 1 ;;
        esac
        if [ "$_rr_fs" = "ext4" ]; then
            echo "UUID=$_rr_uuid $_rr_mp ext4 defaults,noatime 0 2" >> /mnt/etc/fstab
        elif [ "$_rr_leaf" = "var" ] || [ "$_rr_leaf" = "srv" ]; then
            echo "UUID=$_rr_uuid $_rr_mp btrfs defaults,noatime,nodatacow,compress=none 0 0" >> /mnt/etc/fstab
        else
            echo "UUID=$_rr_uuid $_rr_mp btrfs defaults,noatime,compress=zstd:1 0 0" >> /mnt/etc/fstab
        fi
        jl "MULTI-FS-RUNLOG: fstab row UUID=$_rr_uuid $_rr_mp $_rr_fs"
    done
    unset _rr _rr_dev _rr_fs _rr_uuid _rr_mp _rr_leaf
fi

if [ "$GRUB_ESP_BOOT" = "true" ]; then
    echo "UUID=$EFI_UUID /boot vfat defaults,noatime 0 2" >> /mnt/etc/fstab
else
    echo "UUID=$EFI_UUID /boot/efi vfat defaults,noatime 0 2" >> /mnt/etc/fstab
fi

if [ "$ENCRYPT" = "yes" ]; then
    LUKS_UUID=$(blkid -s UUID -o value "$PART_SYS")
    if [ "$YK_MODE" = "hmac-sha1" ]; then
        echo "${CRYPT_NAME} UUID=$LUKS_UUID none luks,keyscript=/usr/local/sbin/void-reveal-yubikey-key" > /mnt/etc/crypttab
    else
        echo "${CRYPT_NAME} UUID=$LUKS_UUID none luks" > /mnt/etc/crypttab
    fi
fi

if [ "$SWAPFILE_MODE" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/swap        btrfs noatime,nodatacow,subvol=@swap 0 0" >> /mnt/etc/fstab
    echo "/var/swap/swapfile               none  swap  defaults                  0 0" >> /mnt/etc/fstab
fi

if [ "$PROVISION_VIRT_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/libvirt btrfs noatime,nodatacow,subvol=@libvirt 0 0" >> /mnt/etc/fstab
fi
if [ "$PROVISION_FLATPAK_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/flatpak    btrfs noatime,compress=zstd:1,subvol=@flatpak 0 0" >> /mnt/etc/fstab
fi
if [ "$PROVISION_DOCKER_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/docker     btrfs noatime,compress=zstd:1,subvol=@docker 0 0" >> /mnt/etc/fstab
fi
if [ "$PROVISION_PODMAN_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/containers btrfs noatime,compress=zstd:1,subvol=@containers 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/lib/NetworkManager btrfs noatime,compress=zstd:1,subvol=@network 0 0" >> /mnt/etc/fstab
fi
if [ "$DISPLAY_MANAGER" = "sddm" ] && ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/lib/sddm btrfs noatime,compress=zstd:1,subvol=@sddm 0 0" >> /mnt/etc/fstab
elif [ "$DISPLAY_MANAGER" = "lightdm" ] && ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/lib/lightdm btrfs noatime,compress=zstd:1,subvol=@lightdm 0 0" >> /mnt/etc/fstab
fi
[ "$BOOTLOADER" = "grub" ] && \
    [ "$GRUB_ESP_BOOT" != "true" ] && \
    echo "UUID=$BTRFS_UUID /boot/grub       btrfs noatime,compress=zstd:1,subvol=@grub 0 0" >> /mnt/etc/fstab
echo "UUID=$BTRFS_UUID /root               btrfs noatime,compress=zstd:1,subvol=@root 0 0" >> /mnt/etc/fstab

: > /mnt/tmp/chroot_env.sh
chmod 600 /mnt/tmp/chroot_env.sh
KEYMAP_LIVE=$(sed -n 's/^[[:space:]]*KEYMAP="\([^"]*\)".*/\1/p' /etc/rc.conf 2>/dev/null | tail -1)
[ -z "${KEYMAP_LIVE:-}" ] && KEYMAP_LIVE="us"
export KEYMAP_LIVE
POWER_PPD="false"
if [ "$DESKTOP_ENV" = "cosmic" ]; then
    POWER_PPD="true"
    [ "$PROFILE_TLP" = "true" ] && PROFILE_TLP="false"
fi
export POWER_PPD
[ "$POWER_PPD" = "true" ] && echo "  NOTE: COSMIC uses power-profiles-daemon; tlp skipped (PPD+tlp conflict)."
echo "export BTRFS_UUID=\"$BTRFS_UUID\"" >> /mnt/tmp/chroot_env.sh
echo "export KERNEL_PKGS=\"$KERNEL_PKGS\"" >> /mnt/tmp/chroot_env.sh
echo "export DEVICE_PROFILE=\"$DEVICE_PROFILE\"" >> /mnt/tmp/chroot_env.sh
echo "export PROFILE_TLP=\"$PROFILE_TLP\"" >> /mnt/tmp/chroot_env.sh
echo "export PROFILE_BT=\"$PROFILE_BT\"" >> /mnt/tmp/chroot_env.sh
echo "export PROFILE_PRELOAD=\"$PROFILE_PRELOAD\"" >> /mnt/tmp/chroot_env.sh
echo "export POWER_PPD=\"$POWER_PPD\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_COSMIC_TOUCHPAD_RCLICK=\"$INSTALL_COSMIC_TOUCHPAD_RCLICK\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_USER=\"$TARGET_USER\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_FULL_NAME=\"$TARGET_FULL_NAME\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_HOSTNAME=\"$TARGET_HOSTNAME\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_DOMAIN=\"$TARGET_DOMAIN\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_FQDN=\"$TARGET_FQDN\"" >> /mnt/tmp/chroot_env.sh
echo "export NET_INTERFACE_MATCH=\"$NET_INTERFACE_MATCH\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_PRIMARY=\"$REPO_PRIMARY\"" >> /mnt/tmp/chroot_env.sh
echo "export KEYMAP_LIVE=\"$KEYMAP_LIVE\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_BACKUP1=\"$REPO_BACKUP1\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_BACKUP2=\"$REPO_BACKUP2\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_EXTRA1=\"$REPO_EXTRA1\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_EXTRA2=\"$REPO_EXTRA2\"" >> /mnt/tmp/chroot_env.sh
echo "export LOCAL_CACHE_REUSE=\"${LOCAL_CACHE_REUSE:-no}\"" >> /mnt/tmp/chroot_env.sh
if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ]; then
    echo "export LOCAL_CACHE_DIR=\"/tmp/xbps-cache\"" >> /mnt/tmp/chroot_env.sh
fi
echo "export ENABLE_SNAPSHOT_AUDIO=\"$ENABLE_SNAPSHOT_AUDIO\"" >> /mnt/tmp/chroot_env.sh
echo "export ACCOUNT_MODEL=\"$ACCOUNT_MODEL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FLATPAK=\"$INSTALL_FLATPAK\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_COSMIC_STORE=\"$INSTALL_COSMIC_STORE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BREW=\"$INSTALL_BREW\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FIREFOX=\"$INSTALL_FIREFOX\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_CHROMIUM=\"$INSTALL_CHROMIUM\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_VIVALDI=\"$INSTALL_VIVALDI\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FALKON=\"$INSTALL_FALKON\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BRAVE=\"$INSTALL_BRAVE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_THUNDERBIRD=\"$INSTALL_THUNDERBIRD\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_STEAM=\"$INSTALL_STEAM\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_LUTRIS=\"$INSTALL_LUTRIS\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_HEROIC=\"$INSTALL_HEROIC\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BOTTLES=\"$INSTALL_BOTTLES\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_WINE=\"$INSTALL_WINE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_GAMEMODE=\"$INSTALL_GAMEMODE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_ANY_GAME=\"$INSTALL_ANY_GAME\"" >> /mnt/tmp/chroot_env.sh
 echo "export INSTALL_VIRTUALBOX=\"$INSTALL_VIRTUALBOX\"" >> /mnt/tmp/chroot_env.sh
 echo "export SUBVOL_ISOLATE_INSTALLED=\"$SUBVOL_ISOLATE_INSTALLED\"" >> /mnt/tmp/chroot_env.sh
 echo "export SUBVOL_PRECREATE=\"$SUBVOL_PRECREATE\"" >> /mnt/tmp/chroot_env.sh
 echo "export PROVISION_FIREFOX_SUBVOL=\"$PROVISION_FIREFOX_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_CHROMIUM_SUBVOL=\"$PROVISION_CHROMIUM_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_VIVALDI_SUBVOL=\"$PROVISION_VIVALDI_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_FALKON_SUBVOL=\"$PROVISION_FALKON_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_BRAVE_SUBVOL=\"$PROVISION_BRAVE_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_THUNDERBIRD_SUBVOL=\"$PROVISION_THUNDERBIRD_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_GAME_SUBVOL=\"$PROVISION_GAME_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_VIRTUALBOX_SUBVOL=\"$PROVISION_VIRTUALBOX_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_PARTITIONED=\"$REGION_PARTITIONED\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_HOME_FS=\"$REGION_HOME_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_VAR_FS=\"$REGION_VAR_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_CACHE_FS=\"$REGION_CACHE_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_SRV_FS=\"$REGION_SRV_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_OPT_FS=\"$REGION_OPT_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_GAMES=\"$REGION_GAMES\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_LINUXBREW_SUBVOL=\"$PROVISION_LINUXBREW_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN_ROOTLESS=\"$INSTALL_PODMAN_ROOTLESS\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_PODMAN_ROOTLESS_SUBVOL=\"$PROVISION_PODMAN_ROOTLESS_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_DISTROBOX=\"$INSTALL_DISTROBOX\"" >> /mnt/tmp/chroot_env.sh
echo "export DISTROBOX_TRACK=\"$DISTROBOX_TRACK\"" >> /mnt/tmp/chroot_env.sh
echo "export DISTROBOX_DEFAULT_ENGINE=\"$DISTROBOX_DEFAULT_ENGINE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN_ROOTFUL=\"$INSTALL_PODMAN_ROOTFUL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN=\"$INSTALL_PODMAN\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_DOCKER=\"$INSTALL_DOCKER\"" >> /mnt/tmp/chroot_env.sh
echo "export DOCKER_GROUP_ADD=\"$DOCKER_GROUP_ADD\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_VIRT=\"$INSTALL_VIRT\"" >> /mnt/tmp/chroot_env.sh
echo "export DESKTOP_ENV=\"$DESKTOP_ENV\"" >> /mnt/tmp/chroot_env.sh
echo "export DISPLAY_MANAGER=\"$DISPLAY_MANAGER\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_GRAPHICAL=\"$HAS_GRAPHICAL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_XORG=\"$INSTALL_XORG\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_AUDIO=\"$INSTALL_AUDIO\"" >> /mnt/tmp/chroot_env.sh
echo "export LIGHTDM_GREETER_PKG=\"$LIGHTDM_GREETER_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export LIGHTDM_GREETER_SESSION=\"$LIGHTDM_GREETER_SESSION\"" >> /mnt/tmp/chroot_env.sh
echo "export LIGHTDM_GREETER=\"$LIGHTDM_GREETER\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_SSH_SERVER=\"$INSTALL_SSH_SERVER\"" >> /mnt/tmp/chroot_env.sh
echo "export SSH_PORT=\"$SSH_PORT\"" >> /mnt/tmp/chroot_env.sh
echo "export SSH_PASSWORD_AUTH=\"$SSH_PASSWORD_AUTH\"" >> /mnt/tmp/chroot_env.sh
echo "export SSH_ROOT_LOGIN=\"$SSH_ROOT_LOGIN\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_NVIDIA=\"$INSTALL_NVIDIA\"" >> /mnt/tmp/chroot_env.sh
echo "export GPU_FAMILIES=\"$GPU_FAMILIES\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_NVIDIA_GPU=\"$HAS_NVIDIA_GPU\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_AMD_GPU=\"$HAS_AMD_GPU\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_INTEL_GPU=\"$HAS_INTEL_GPU\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_HW=\"$WIFI_HW\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_WIFI_FW=\"$INSTALL_WIFI_FW\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_IDS=\"$WIFI_IDS\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_CHIPS=\"$WIFI_CHIPS\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_FW_PKG=\"$WIFI_FW_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export MICROCODE_PKG=\"$MICROCODE_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export MICROCODE_DECIDED=\"$MICROCODE_DECIDED\"" >> /mnt/tmp/chroot_env.sh
echo "export BR0_NIC=\"$BR0_NIC\"" >> /mnt/tmp/chroot_env.sh
echo "export LOCALE=\"$LOCALE\"" >> /mnt/tmp/chroot_env.sh
echo "export LOCALE_CODESET=\"$LOCALE_CODESET\"" >> /mnt/tmp/chroot_env.sh
echo "export TIMEZONE=\"$TIMEZONE\"" >> /mnt/tmp/chroot_env.sh
echo "export SWAP_BACKEND=\"$SWAP_BACKEND\"" >> /mnt/tmp/chroot_env.sh
echo "export ENABLE_HIBERNATION=\"$ENABLE_HIBERNATION\"" >> /mnt/tmp/chroot_env.sh
echo "export SWAPFILE_SIZE=\"$SWAPFILE_SIZE\"" >> /mnt/tmp/chroot_env.sh
echo "export ENCRYPT=\"$ENCRYPT\"" >> /mnt/tmp/chroot_env.sh
echo "export CRYPT_NAME=\"${CRYPT_NAME:-void-root}\"" >> /mnt/tmp/chroot_env.sh
if [ "$ENCRYPT" = "yes" ]; then
    echo "export LUKS_UUID=\"$LUKS_UUID\"" >> /mnt/tmp/chroot_env.sh
fi
if [ "$YK_MODE" = "hmac-sha1" ]; then
    echo "export YK_MODE=\"$YK_MODE\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_SLOT=\"$YK_SLOT\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_CHALLENGE=\"$YK_CHALLENGE\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_FALLBACK=\"$YK_FALLBACK\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_TOUCH=\"$YK_TOUCH\"" >> /mnt/tmp/chroot_env.sh
fi
echo "export SESSION_STACK=\"$SESSION_STACK\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_OCTOXBPS=\"$INSTALL_OCTOXBPS\"" >> /mnt/tmp/chroot_env.sh
echo "export BOOTLOADER=\"$BOOTLOADER\"" >> /mnt/tmp/chroot_env.sh
echo "export GRUB_ESP_BOOT=\"$GRUB_ESP_BOOT\"" >> /mnt/tmp/chroot_env.sh
echo "export KERNEL_MODE=\"$KERNEL_MODE\"" >> /mnt/tmp/chroot_env.sh
echo "export LIMINE_WALLPAPER=\"$LIMINE_WALLPAPER\"" >> /mnt/tmp/chroot_env.sh
echo "export LIMINE_WALLPAPER_STYLE=\"$LIMINE_WALLPAPER_STYLE\"" >> /mnt/tmp/chroot_env.sh
echo "export DEFAULT_QUIET_BOOT=\"$DEFAULT_QUIET_BOOT\"" >> /mnt/tmp/chroot_env.sh
echo "export DEFAULT_TEE_BLACKLIST=\"$DEFAULT_TEE_BLACKLIST\"" >> /mnt/tmp/chroot_env.sh
echo "export SCRIPT_VERSION=\"$SCRIPT_VERSION\"" >> /mnt/tmp/chroot_env.sh
echo "export USER_SHELL=\"$USER_SHELL\"" >> /mnt/tmp/chroot_env.sh
echo "export USER_SHELL_PKG=\"$USER_SHELL_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export SYSPREFIX_ESP=\"$SYSPREFIX_ESP\"" >> /mnt/tmp/chroot_env.sh
echo "export SYSPREFIX_BTRFS=\"$SYSPREFIX_BTRFS\"" >> /mnt/tmp/chroot_env.sh
echo "export ROOT_PASS_HASH='$ROOT_PASS_HASH'" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_PASS_HASH='$TARGET_PASS_HASH'" >> /mnt/tmp/chroot_env.sh
ROOT_PASS_HASH=""
TARGET_PASS_HASH=""
unset ROOT_PASS_HASH TARGET_PASS_HASH

echo ""
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_CYN}${C_BOLD} STAGE 2: Internal target-system provisioning (inside chroot)${C_RST}"
STAGE_CONTEXT="STAGE2:chroot"
jl "Begin Stage 2 (chroot provisioning)"
echo "${C_CYN}==============================================================================${C_RST}"
echo "Crossing the chroot boundary envelope..."

chroot /mnt /bin/bash << 'CHROOT_EOF'
source /etc/profile
set -eEo pipefail
if [ -f /tmp/chroot_env.sh ]; then
    source /tmp/chroot_env.sh
    rm -f /tmp/chroot_env.sh
else
    echo "CRITICAL: BTRFS_UUID/TARGET_USER/password-hash parameters missing inside target environment. Aborting."
    exit 1
fi
_xbps_cache=()
if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ] && [ -n "${LOCAL_CACHE_DIR:-}" ] && [ -d "$LOCAL_CACHE_DIR" ]; then
    _xbps_cache=(-c "$LOCAL_CACHE_DIR")
fi
if [ -z "${TARGET_USER:-}" ] || [ -z "${TARGET_PASS_HASH:-}" ] || [ -z "${TARGET_HOSTNAME:-}" ] || [ -z "${ACCOUNT_MODEL:-}" ]; then
    echo "CRITICAL: Essential target account metadata parameters are empty. Aborting." >&2
    exit 1
fi
if [ "$ACCOUNT_MODEL" != "ubuntu" ] && [ -z "${ROOT_PASS_HASH:-}" ]; then
    echo "CRITICAL: Essential target account metadata parameters are empty. Aborting." >&2
    exit 1
fi
if [ -z "${BOOTLOADER:-}" ] || { [ "$BOOTLOADER" != "grub" ] && [ "$BOOTLOADER" != "limine" ]; }; then
    echo "CRITICAL: BOOTLOADER is missing or invalid ('${BOOTLOADER:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ -z "${DESKTOP_ENV:-}" ] || { [ "$DESKTOP_ENV" != "kde" ] && [ "$DESKTOP_ENV" != "cinnamon" ] && [ "$DESKTOP_ENV" != "gnome" ] && [ "$DESKTOP_ENV" != "xfce" ] && [ "$DESKTOP_ENV" != "mate" ] && [ "$DESKTOP_ENV" != "lxqt" ] && [ "$DESKTOP_ENV" != "cosmic" ] && [ "$DESKTOP_ENV" != "none" ]; }; then
    echo "CRITICAL: DESKTOP_ENV is missing or invalid ('${DESKTOP_ENV:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ -z "${DISPLAY_MANAGER:-}" ] || { [ "$DISPLAY_MANAGER" != "sddm" ] && [ "$DISPLAY_MANAGER" != "lightdm" ] && [ "$DISPLAY_MANAGER" != "gdm" ] && [ "$DISPLAY_MANAGER" != "cosmic-greeter" ] && [ "$DISPLAY_MANAGER" != "none" ]; }; then
    echo "CRITICAL: DISPLAY_MANAGER is missing or invalid ('${DISPLAY_MANAGER:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    if [ -z "${LIGHTDM_GREETER_PKG:-}" ] || [ -z "${LIGHTDM_GREETER_SESSION:-}" ]; then
        echo "CRITICAL: LIGHTDM greeter choice missing inside target environment for DISPLAY_MANAGER=lightdm. Aborting." >&2
        exit 1
    fi
fi
if [ -z "${SESSION_STACK:-}" ] || { [ "$SESSION_STACK" != "elogind" ] && [ "$SESSION_STACK" != "turnstile" ]; }; then
    echo "CRITICAL: SESSION_STACK is missing or invalid ('${SESSION_STACK:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ "$BOOTLOADER" = "limine" ]; then
    if [ "$KERNEL_MODE" != "esp-copy" ]; then
        echo "CRITICAL: KERNEL_MODE must be 'esp-copy' ('${KERNEL_MODE:-<unset>}') for BOOTLOADER=limine inside target environment. Aborting." >&2
        exit 1
    fi
fi
if [ -z "${KERNEL_PKGS:-}" ]; then
    echo "CRITICAL: KERNEL_PKGS is empty ('${KERNEL_PKGS:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
for _kp in $KERNEL_PKGS; do
    case "$_kp" in
        linux|linux-lts|linux-mainline) : ;;
        *)
            echo "CRITICAL: KERNEL_PKGS contains unknown flavor '$_kp' inside target environment. Aborting." >&2
            exit 1 ;;
    esac
done
unset _kp
case "$DEVICE_PROFILE" in
    laptop-bt|laptop|desktop-bt|desktop) : ;;
    *)
        echo "CRITICAL: DEVICE_PROFILE is missing or invalid ('${DEVICE_PROFILE:-<unset>}') inside target environment. Aborting." >&2
        exit 1 ;;
esac
for _dpb in PROFILE_TLP PROFILE_BT PROFILE_PRELOAD POWER_PPD; do
    v="${!_dpb:-}"
    [ "$v" = "true" ] || [ "$v" = "false" ] || {
        echo "CRITICAL: ${_dpb} is missing or invalid ('${v:-<unset>}') inside target environment. Aborting." >&2
        exit 1
    }
done
unset _dpb
if [ -z "${USER_SHELL:-}" ]; then
    echo "CRITICAL: USER_SHELL is missing ('${USER_SHELL:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi

install_pkgs() {
    _ipkgs_ok=0
    _ipkgs_err=$(mktemp /tmp/ipkgs-transcript.XXXXXX)
    _ipkgs_skew_round=0
    while [ "$_ipkgs_ok" -ne 1 ] && [ "$_ipkgs_skew_round" -le 3 ]; do
    for _ipkgs_repo in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
        if xbps-install -Suy -R "$_ipkgs_repo" "${_xbps_cache[@]}" "$@" 2>&1 | tee "$_ipkgs_err"; then
            _ipkgs_ok=1
            break
        fi
        echo "==> Package install attempt against ${_ipkgs_repo} failed for: $* — trying next repository, if any." >&2
        xbps-install -Sy -R "$_ipkgs_repo" "${_xbps_cache[@]}" >/dev/null 2>&1 || true
        xbps-pkgdb -a >/dev/null 2>&1 || true
    done
    if [ "$_ipkgs_ok" -eq 1 ]; then
        break
    fi
    if grep -q "failed to download .*' signature from" "$_ipkgs_err"; then
        _ipkgs_skew_round=$((_ipkgs_skew_round + 1))
        if [ "$_ipkgs_skew_round" -le 3 ]; then
            echo "==> [MIRROR-SKEW-GUARD] index-vs-pool rotation desync (signature 404 while the index resolves a version) — waiting $((_ipkgs_skew_round * 15))s for the mirror to heal, then retrying the full rotation (round ${_ipkgs_skew_round}/3)." >&2
            sleep $((_ipkgs_skew_round * 15))
        fi
    else
        break
    fi
    done
    rm -f "$_ipkgs_err"
    unset _ipkgs_err _ipkgs_skew_round
    if [ "$_ipkgs_ok" -ne 1 ]; then
        echo "FATAL: package install failed against all configured repositories for: $*" >&2
        exit 1
    fi
}

cosmic_key_fingerprint() {
    local _b
    _b=$(sed -n '/<key>public-key<\/key>/,/<\/data>/p' "$1" 2>/dev/null \
         | tail -n +2 \
         | sed -e 's/.*<data>//' -e 's|</data>||' -e 's/[[:space:]]//g')
    [ -n "$_b" ] || return 1
    printf '%s' "$_b" | base64 -d 2>/dev/null | openssl rsa -pubin -noout 2>/dev/null || return 1
    printf '%s' "$_b" | base64 -d 2>/dev/null \
        | openssl rsa -pubin -outform DER 2>/dev/null \
        | openssl dgst -sha256 2>/dev/null | sed 's/.*= *//'
}

install_cosmic() {
    _cosmic_repo="https://bluesloth.github.io/void-linux-cosmic/"
    _cosmic_repodata="https://bluesloth.github.io/void-linux-cosmic/x86_64-repodata"
    _cosmic_audit="https://github.com/bluesloth/void-linux-cosmic"
    _cosmic_keyring="/var/db/xbps/keys"
    _cosmic_key_expected="83ffd154d1dee504ea384a0c31b12e072d5884f7f75eb950e30ace852d7d2e7b"
    _cosmic_key_stock="05473705de6456ebfdda5bd4f18155cba80bd83fca1b120cf41099693c69187b
f0da25a2877ccd5cba89e27fc744867914fd26031368a88f746f0f8096450d4d"

    if ! curl -fsSL --max-time 30 -o /dev/null "$_cosmic_repodata" 2>/dev/null; then
        echo "FATAL: the third-party COSMIC repository (${_cosmic_repo}) is not reachable right now." >&2
        echo "       Install aborted cleanly because COSMIC is a third-party repo and cannot be" >&2
        echo "       installed without it. You can still install the other desktops, or add the" >&2
        echo "       repo manually later and run:  xbps-install -S cosmic-desktop-full" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi

    mkdir -p /etc/xbps.d
    if ! grep -q 'bluesloth.github.io' /etc/xbps.d/59-cosmic.conf 2>/dev/null; then
        echo "repository=${_cosmic_repo}" > /etc/xbps.d/59-cosmic.conf
    fi

    echo "==> Importing the COSMIC repository signing key (auto-answered; verified against the pin right after)."
    echo "    Expected fingerprint:"
    echo "      SHA256 ${_cosmic_key_expected}"
    if ! printf 'y\n' | xbps-install "${_xbps_cache[@]}" -Sy; then
        echo "FATAL: could not sync/trust the third-party COSMIC repository (${_cosmic_repo})." >&2
        echo "       xbps refused the repository signing key, so the install aborted" >&2
        echo "       cleanly and nothing was changed." >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi

    _cosmic_fp_ok=0
    _cosmic_fp_bad=""
    _cosmic_fp_seen=""
    if [ -d "$_cosmic_keyring" ]; then
        for _cosmic_k in "$_cosmic_keyring"/*.plist; do
            [ -e "$_cosmic_k" ] || continue
            _cosmic_fp="$(cosmic_key_fingerprint "$_cosmic_k")"
            if [ -z "$_cosmic_fp" ]; then
                _cosmic_fp_bad="${_cosmic_fp_bad} UNREADABLE(${_cosmic_k##*/})"
                _cosmic_fp_seen="${_cosmic_fp_seen} UNREADABLE(${_cosmic_k##*/})"
                continue
            fi
            if [ "$_cosmic_fp" = "$_cosmic_key_expected" ]; then
                _cosmic_fp_ok=1
                _cosmic_fp_seen="${_cosmic_fp_seen} ${_cosmic_fp}(pinned)"
            elif printf '%s\n' "$_cosmic_key_stock" | grep -qx "$_cosmic_fp"; then
                _cosmic_fp_seen="${_cosmic_fp_seen} ${_cosmic_fp}(stock-void)"
            else
                _cosmic_fp_bad="${_cosmic_fp_bad} ${_cosmic_fp}"
                _cosmic_fp_seen="${_cosmic_fp_seen} ${_cosmic_fp}(UNEXPECTED)"
            fi
        done
    fi

    if [ "$_cosmic_fp_ok" -ne 1 ] || [ -n "$_cosmic_fp_bad" ]; then
        echo "FATAL: COSMIC repository trust anchor does not match this installer." >&2
        if [ "$_cosmic_fp_ok" -ne 1 ]; then
            echo "       Pinned key ABSENT from ${_cosmic_keyring}:" >&2
            echo "         expected SHA256 ${_cosmic_key_expected}" >&2
            echo "       Either the sync did not import it, or the repo is presenting a" >&2
            echo "       DIFFERENT key. If you are offline or mid-key-rotation, say so" >&2
            echo "       before overriding this." >&2
        fi
        if [ -n "$_cosmic_fp_bad" ]; then
            echo "       UNEXPECTED key(s) present in ${_cosmic_keyring}:" >&2
            for _cosmic_b in $_cosmic_fp_bad; do
                echo "         ${_cosmic_b}" >&2
            done
            echo "       Refusing to continue: a key you did not expect is trusted for" >&2
            echo "       these packages. Remove it and re-run, or investigate before" >&2
            echo "       trusting anything from this repo." >&2
        fi
        echo "       Keys seen:${_cosmic_fp_seen:- (none)}" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi
    echo "==> COSMIC trust anchor verified: SHA256 ${_cosmic_key_expected}"

    if ! xbps-install "${_xbps_cache[@]}" -y "$@"; then
        echo "FATAL: xbps-install failed for COSMIC package(s): $*" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi
}

install_pkgs xbps
update-ca-certificates --fresh
install_pkgs void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
install_pkgs

install_pkgs nftables runit-nftables iptables polkit

NFT_FWD_RULES=""
if [ "$INSTALL_VIRT" = "true" ]; then
    NFT_FWD_RULES=$(cat << 'NFT_FWD_EOF'
        iifname "br0" accept
        oifname "br0" accept
        iifname "virbr*" accept
        oifname "virbr*" accept
NFT_FWD_EOF
    )
fi
SSH_PORT_RULE=""
if [ "$INSTALL_SSH_SERVER" = "true" ]; then
    SSH_PORT_RULE=$(cat << SSH_PORT_EOF
        tcp dport "${SSH_PORT}" ct state new accept
SSH_PORT_EOF
    )
fi
cat > /etc/nftables.conf << INNER_EOF
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        iif != "lo" ip daddr 127.0.0.0/8 drop
        iif != "lo" ip6 daddr ::1 drop
        ct state established,related accept
        ct state invalid drop
        ip protocol icmp icmp type echo-request counter limit rate 1/second burst 5 packets accept
        meta l4proto ipv6-icmp accept
${SSH_PORT_RULE}
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
${NFT_FWD_RULES}
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
INNER_EOF

if [ "$INSTALL_VIRT" = "true" ]; then
    echo ""
    echo "--- /etc/nftables.conf (virtualization build: br0/virbr* forwards present) ---"
    cat /etc/nftables.conf
    echo "--- end nftables.conf ---"
fi

if [ "$INSTALL_SSH_SERVER" = "true" ]; then
    install_pkgs openssh
    SSH_DROP="/etc/ssh/sshd_config.d/10-void-installer.conf"
    mkdir -p /etc/ssh/sshd_config.d
    if ! grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config 2>/dev/null; then
        echo "" >> /etc/ssh/sshd_config
        echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    fi
    cat > "$SSH_DROP" << INNER_EOF
Port ${SSH_PORT}
PasswordAuthentication ${SSH_PASSWORD_AUTH}
PermitRootLogin ${SSH_ROOT_LOGIN}
INNER_EOF
    chmod 0644 "$SSH_DROP"
    echo "==> OpenSSH configured (port ${SSH_PORT}) → ${SSH_DROP}"
fi

if [ -n "$(find /tmp/ssh-keygen -maxdepth 1 -type f 2>/dev/null -print -quit)" ] || \
   [ -n "$(find /tmp/ssh-import -maxdepth 1 -type f 2>/dev/null -print -quit)" ]; then
    if [ -n "$TARGET_USER" ] && id -u "$TARGET_USER" >/dev/null 2>&1; then
        _ssh_dir="/home/${TARGET_USER}/.ssh"
        mkdir -p "$_ssh_dir"
        chmod 0700 "$_ssh_dir"
        if [ -f /tmp/ssh-keygen/id_ed25519 ]; then
            cp -f /tmp/ssh-keygen/id_ed25519 "$_ssh_dir/id_ed25519"
            cp -f /tmp/ssh-keygen/id_ed25519.pub "$_ssh_dir/id_ed25519.pub"
            chmod 0600 "$_ssh_dir/id_ed25519"
            chmod 0644 "$_ssh_dir/id_ed25519.pub"
            echo "==> Generated key deposited → ${TARGET_USER}/.ssh/id_ed25519"
        fi
        if [ -f /tmp/ssh-import/imported ]; then
            cp -f /tmp/ssh-import/imported "$_ssh_dir/imported"
            chmod 0600 "$_ssh_dir/imported"
            [ -f /tmp/ssh-import/imported.pub ] && cp -f /tmp/ssh-import/imported.pub "$_ssh_dir/imported.pub" && chmod 0644 "$_ssh_dir/imported.pub"
            echo "==> Imported key deposited → ${TARGET_USER}/.ssh/imported"
        fi
        _ssh_cfg_written="no"
        if [ -f "$_ssh_dir/id_ed25519" ] || [ -f "$_ssh_dir/imported" ]; then
            [ -f "$_ssh_dir/config" ] || : > "$_ssh_dir/config"
            chmod 0600 "$_ssh_dir/config"
            for _kname in id_ed25519 imported; do
                [ -f "$_ssh_dir/$_kname" ] || continue
                if ! grep -qE "^[[:space:]]*IdentityFile[[:space:]]+.*${_kname}([[:space:]]|$)" "$_ssh_dir/config"; then
                    printf 'IdentityFile ~/.ssh/%s\n' "$_kname" >> "$_ssh_dir/config"
                    _ssh_cfg_written="yes"
                fi
            done
        fi
        [ "$_ssh_cfg_written" = "yes" ] && echo "==> ~/.ssh/config IdentityFile(s) written for the installed key(s)"
        if [ -f "$_ssh_dir/imported.pub" ]; then
            touch "$_ssh_dir/authorized_keys"
            chmod 0600 "$_ssh_dir/authorized_keys" 2>/dev/null || true
            _imp_ak_line="$(cat "$_ssh_dir/imported.pub")"
            if ! grep -qF -- "$_imp_ak_line" "$_ssh_dir/authorized_keys"; then
                printf '%s\n' "$_imp_ak_line" >> "$_ssh_dir/authorized_keys"
                echo "==> Imported public key added to ${TARGET_USER}/.ssh/authorized_keys (key login enabled)"
            fi
            unset _imp_ak_line
        fi
        chown -R "${TARGET_USER}:${TARGET_USER}" "$_ssh_dir"
        unset _ssh_cfg_written _kname
    else
        echo "WARNING: SSH keys staged but target account '${TARGET_USER:-<unset>}' missing — keys NOT deposited." >&2
    fi
    shred -u /tmp/ssh-keygen/id_ed25519* /tmp/ssh-import/imported* 2>/dev/null || true
    rm -rf /tmp/ssh-keygen /tmp/ssh-import
fi

echo "${TARGET_HOSTNAME}" > /etc/hostname

if [ "$TARGET_FQDN" != "$TARGET_HOSTNAME" ]; then
    HOSTS_LINE="127.0.1.1       ${TARGET_FQDN} ${TARGET_HOSTNAME}"
else
    HOSTS_LINE="127.0.1.1       ${TARGET_HOSTNAME}"
fi

cat > /etc/hosts << INNER_EOF
127.0.0.1       localhost
${HOSTS_LINE}
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
INNER_EOF

if [ -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
else
    echo "WARNING: timezone '${TIMEZONE}' not found in tzdata; leaving /etc/localtime unset (UTC)." >&2
fi
LOCALE_ENTRY="${LOCALE} ${LOCALE_CODESET}"
LOCALE_ESC="$(printf '%s' "${LOCALE}" | sed 's/[.[\*^$]/\\&/g')"
sed -i "/^[#[:space:]]*${LOCALE_ESC}[[:space:]]/d" /etc/default/libc-locales 2>/dev/null || true
echo "${LOCALE_ENTRY}" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
echo "LANG=${LOCALE}" > /etc/locale.conf
[ -n "${KEYMAP_LIVE:-}" ] || KEYMAP_LIVE="us"
sed -i "s/^[[:space:]]*#\?[[:space:]]*KEYMAP=.*/KEYMAP=\"${KEYMAP_LIVE}\"/" /etc/rc.conf 2>/dev/null || true
if ! grep -q '^KEYMAP=' /etc/rc.conf 2>/dev/null; then
    printf 'KEYMAP="%s"\n' "${KEYMAP_LIVE}" >> /etc/rc.conf
fi

[ "$INSTALL_VIRT" = "true" ] && install_pkgs qemu libvirt virt-manager

[ -n "$USER_SHELL_PKG" ] && install_pkgs "$USER_SHELL_PKG"

USER_GROUPS="adm,video,audio"
[ "$ACCOUNT_MODEL" != "debian" ] && USER_GROUPS="wheel,${USER_GROUPS}"
[ "$INSTALL_VIRT" = "true" ] && USER_GROUPS="${USER_GROUPS},kvm,libvirt"
useradd -m -G "$USER_GROUPS" -s "$USER_SHELL" -c "${TARGET_FULL_NAME:-$TARGET_USER}" "$TARGET_USER"

chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}"

case " ${REGION_PARTITIONED:-} " in
    *" games "*)
        mkdir -p "/home/${TARGET_USER}/Games"
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/Games"
        ;;
esac

if [ -n "${TARGET_USER:-}" ]; then
    _acct_icon_src="/usr/share/icons/Adwaita/scalable/status/avatar-default.svg"
    [ -f "$_acct_icon_src" ] || _acct_icon_src="/usr/share/icons/Pop/scalable/status/avatar-default-symbolic.svg"
    if [ -f "$_acct_icon_src" ]; then
        mkdir -p /var/lib/AccountsService/icons 2>/dev/null || true
        cp "$_acct_icon_src" "/var/lib/AccountsService/icons/${TARGET_USER}"
        chmod 0644 "/var/lib/AccountsService/icons/${TARGET_USER}"
    fi
    unset _acct_icon_src
fi

if [ "$USER_SHELL" = "/bin/zsh" ]; then
    cat > "/home/${TARGET_USER}/.zshrc" << INNER_EOF
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
autoload -Uz compinit
compinit
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -lh'
INNER_EOF
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.zshrc"
fi
if [ "$USER_SHELL" = "/usr/bin/fish" ]; then
    mkdir -p "/home/${TARGET_USER}/.config/fish"
    cat > "/home/${TARGET_USER}/.config/fish/config.fish" << INNER_EOF
set fish_greeting
abbr -a ll 'ls -lah'
abbr -a la 'ls -A'
abbr -a l 'ls -lh'
INNER_EOF
    chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/fish"
fi

if [ "$ACCOUNT_MODEL" = "ubuntu" ]; then
    passwd -l root
else
    echo "root:${ROOT_PASS_HASH}" | chpasswd -e
fi
echo "${TARGET_USER}:${TARGET_PASS_HASH}" | chpasswd -e
ROOT_PASS_HASH=""
TARGET_PASS_HASH=""
unset ROOT_PASS_HASH TARGET_PASS_HASH

if [ "$ACCOUNT_MODEL" != "debian" ]; then
    mkdir -p /etc/sudoers.d
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
fi

if [ "$INSTALL_VIRT" = "true" ] && [ -n "${NET_INTERFACE_MATCH:-}" ]; then
mkdir -p /etc/qemu
cat > /etc/qemu/bridge.conf << 'INNER_EOF'
allow br0
INNER_EOF
chmod 0640 /etc/qemu/bridge.conf
[ -f /usr/libexec/qemu-bridge-helper ] && chmod 4755 /usr/libexec/qemu-bridge-helper
fi


if [ "$INSTALL_VIRT" = "true" ]; then
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-libvirt.rules << 'INNER_EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.libvirt.unix.manage") === 0 &&
        subject.isInGroup("libvirt")) {
        return polkit.Result.YES;
    }
});
INNER_EOF
chmod 644 /etc/polkit-1/rules.d/50-libvirt.rules
fi

if [ -z "${MICROCODE_DECIDED:-}" ]; then
    CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
    case "$CPU_VENDOR" in
        GenuineIntel) MICROCODE_PKG="intel-ucode" ;;
        AuthenticAMD) MICROCODE_PKG="linux-firmware-amd" ;;
        *) echo "WARNING: unrecognized CPU vendor '${CPU_VENDOR}', skipping microcode package." >&2
           MICROCODE_PKG="" ;;
    esac
fi
install_pkgs ${MICROCODE_PKG} linux-firmware dracut sudo vim nano bash bash-completion curl
[ "$ENCRYPT" = "yes" ] && install_pkgs cryptsetup
[ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ] && install_pkgs kpartx parted
[ "$YK_MODE" = "hmac-sha1" ] && install_pkgs ykpers

if [ "$INSTALL_NVIDIA" = "true" ]; then
    install_pkgs nvidia
    case "$KERNEL_PKGS" in
        *linux-mainline*) install_pkgs linux-mainline-headers ;;
        *linux-lts*) install_pkgs linux-lts-headers ;;
        *linux*) install_pkgs linux-headers ;;
    esac
    cat > /etc/modprobe.d/50-nvidia.conf << 'INNER_EOF'
blacklist nouveau
options nouveau modeset=0
INNER_EOF
    chmod 0644 /etc/modprobe.d/50-nvidia.conf
fi

[ "$INSTALL_WIFI_FW" = "true" ] && [ -n "$WIFI_FW_PKG" ] && install_pkgs "$WIFI_FW_PKG"

if [ -z "${HAS_GRAPHICAL:-}" ]; then
    if { [ "${DESKTOP_ENV:-none}" = "none" ] && [ "${DISPLAY_MANAGER:-none}" = "none" ]; }; then
        HAS_GRAPHICAL="no"
    else
        HAS_GRAPHICAL="yes"
    fi
fi
INSTALL_XORG="${INSTALL_XORG:-false}"
INSTALL_AUDIO="${INSTALL_AUDIO:-true}"
export HAS_GRAPHICAL INSTALL_XORG INSTALL_AUDIO
if [ "$HAS_GRAPHICAL" = "yes" ] || [ "${INSTALL_XORG:-false}" = "true" ]; then
    if [ "$SESSION_STACK" = "elogind" ]; then
        install_pkgs wayland wayland-protocols NetworkManager dbus elogind xorg
    else
        install_pkgs wayland wayland-protocols NetworkManager dbus turnstile seatd acpid xorg
    fi
else
    if [ "$SESSION_STACK" = "elogind" ]; then
        install_pkgs NetworkManager dbus elogind
    else
        install_pkgs NetworkManager dbus turnstile seatd acpid
    fi
fi

if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    install_pkgs lightdm accountsservice "$LIGHTDM_GREETER_PKG"

    mkdir -p /etc/lightdm
    case "$DESKTOP_ENV" in
        cinnamon) _lightdm_user_session="cinnamon" ;;
        gnome)    _lightdm_user_session="gnome" ;;
        xfce)     _lightdm_user_session="xfce" ;;
        mate)     _lightdm_user_session="mate" ;;
        lxqt)     _lightdm_user_session="lxqt" ;;
        *)        _lightdm_user_session="" ;;
    esac
    {
        echo "[Seat:*]"
        echo "greeter-session=${LIGHTDM_GREETER_SESSION}"
        [ -n "$_lightdm_user_session" ] && echo "user-session=${_lightdm_user_session}"
        echo "session-wrapper=/etc/lightdm/Xsession"
    } > /etc/lightdm/lightdm.conf.tmp
    mv -f /etc/lightdm/lightdm.conf.tmp /etc/lightdm/lightdm.conf
    chown lightdm:lightdm /var/lib/lightdm 2>/dev/null || \
        echo "WARNING: could not chown /var/lib/lightdm to lightdm:lightdm — greeter may misbehave." >&2

    _accd_bin=""
    for _accd_cand in /usr/libexec/accounts-daemon /usr/lib/accounts-daemon; do
        [ -x "$_accd_cand" ] && { _accd_bin="$_accd_cand"; break; }
    done
    if [ -n "$_accd_bin" ]; then
        mkdir -p /etc/sv/accounts-daemon
        cat > /etc/sv/accounts-daemon/run << 'ACCD_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
exec __ACCD_BIN__
ACCD_EOF
        sed -i "s|__ACCD_BIN__|${_accd_bin}|" /etc/sv/accounts-daemon/run
        chmod 0755 /etc/sv/accounts-daemon/run
    else
        echo "WARNING: accounts-daemon binary not found — LightDM greeters will rely on D-Bus activation (boot race may resurface)." >&2
    fi
    unset _accd_bin _accd_cand
    DM_SERVICE_NAME="lightdm"
elif [ "$DISPLAY_MANAGER" = "gdm" ]; then
    install_pkgs gdm
    DM_SERVICE_NAME="gdm"
elif [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    install_cosmic cosmic-greeter
    install_pkgs greetd
    if ! grep -q '^cosmic-greeter:' /etc/passwd 2>/dev/null; then
        _cg_group_opt=""
        grep -q '^cosmic-greeter:' /etc/group 2>/dev/null && _cg_group_opt="-g cosmic-greeter -G video,input"
        useradd -r -M -s /sbin/nologin -d /var/lib/cosmic-greeter -c 'Cosmic Greeter Account' $_cg_group_opt cosmic-greeter 2>/dev/null || \
            echo "WARNING: could not create the cosmic-greeter system user — the greeter may not start." >&2
        unset _cg_group_opt
    fi
    mkdir -p /var/lib/cosmic-greeter
    chown -f cosmic-greeter:cosmic-greeter /var/lib/cosmic-greeter 2>/dev/null || true
    _accd_bin=""
    for _accd_cand in /usr/libexec/accounts-daemon /usr/lib/accounts-daemon; do
        [ -x "$_accd_cand" ] && { _accd_bin="$_accd_cand"; break; }
    done
    if [ -n "$_accd_bin" ]; then
        mkdir -p /etc/sv/accounts-daemon
        cat > /etc/sv/accounts-daemon/run << 'ACCD_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
exec __ACCD_BIN__
ACCD_EOF
        sed -i "s|__ACCD_BIN__|${_accd_bin}|" /etc/sv/accounts-daemon/run
        chmod 0755 /etc/sv/accounts-daemon/run
    else
        echo "WARNING: accounts-daemon binary not found — the greeter will rely on D-Bus activation (boot race may resurface)." >&2
    fi
    unset _accd_bin _accd_cand
    mkdir -p /etc/dbus-1/system.d
    cat > /etc/dbus-1/system.d/com.system76.CosmicGreeter.conf << 'PDBUS_EOF'
<?xml version="1.0"?>
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy group="cosmic-greeter">
    <allow send_destination="com.system76.CosmicGreeter"/>
    <allow receive_sender="com.system76.CosmicGreeter"/>
  </policy>
  <policy user="root">
    <allow own="com.system76.CosmicGreeter"/>
    <allow send_destination="com.system76.CosmicGreeter"/>
    <allow receive_sender="com.system76.CosmicGreeter"/>
  </policy>
</busconfig>
PDBUS_EOF
    chmod 0644 /etc/dbus-1/system.d/com.system76.CosmicGreeter.conf
    DM_SERVICE_NAME="cosmic-greeter"
elif [ "$DISPLAY_MANAGER" = "none" ]; then
    DM_SERVICE_NAME="none"
else
    install_pkgs sddm
    DM_SERVICE_NAME="sddm"
fi

if [ "$DESKTOP_ENV" = "cinnamon" ]; then
    install_pkgs cinnamon-all

    install_pkgs gnome-terminal

    install_pkgs gedit gnome-backgrounds blueman network-manager-applet

    _cinnamon_wallpaper="$(find /usr/share/backgrounds -maxdepth 2 -type f \
        \( -name 'adwaita-l.jpg' -o -name 'adwaita-l.jxl' \
           -o -name 'adwaita-l.png' -o -name 'adwaita-l.svg' \) \
        2>/dev/null | head -1)" || true
    if [[ -z "$_cinnamon_wallpaper" ]]; then
        _cinnamon_wallpaper="$(find /usr/share/backgrounds -maxdepth 2 -type f \
            \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
               -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
            2>/dev/null | head -1)" || true
    fi
    if [[ -n "$_cinnamon_wallpaper" ]]; then
        mkdir -p /etc/dconf/profile
        cat > /etc/dconf/profile/user << 'INNER_EOF'
user-db:user
system-db:local
INNER_EOF
        mkdir -p /etc/dconf/db/local.d
        cat > /etc/dconf/db/local.d/01-cinnamon-wallpaper << INNER_EOF
[org/cinnamon/desktop/background]
picture-uri='file://${_cinnamon_wallpaper}'
picture-options='zoom'
INNER_EOF
        dconf update
    fi
    unset _cinnamon_wallpaper

    mkdir -p /usr/share/glib-2.0/schemas
    cat > /usr/share/glib-2.0/schemas/zz-void-installer-cinnamon.gschema.override << 'INNER_EOF'
[org.gnome.Terminal.Legacy.Profile]
font='Monospace 12'
use-system-font=false
INNER_EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/

    for _sess_file in /usr/share/xsessions/*.desktop /usr/share/wayland-sessions/*.desktop; do
        [ -f "$_sess_file" ] || continue
        case "$(basename "$_sess_file")" in
            *cinnamon*)
                if grep -q '^Exec=' "$_sess_file" && ! grep -q '^Exec=dbus-run-session' "$_sess_file"; then
                    sed -i -E 's|^Exec=(.*)|Exec=dbus-run-session -- \1|' "$_sess_file"
                fi
                ;;
        esac
    done

    if [ "$DISPLAY_MANAGER" = "sddm" ]; then
        _cinnamon_x11_session=""
        for _cs_file in /usr/share/xsessions/*cinnamon*.desktop; do
            [ -f "$_cs_file" ] || continue
            case "$(basename "$_cs_file")" in
                *2d*|*software*|*Software*) continue ;;
                *) _cinnamon_x11_session="$(basename "$_cs_file" .desktop)"; break ;;
            esac
        done
        if [ -n "$_cinnamon_x11_session" ]; then
            mkdir -p /var/lib/sddm
            cat > /var/lib/sddm/state.conf << INNER_EOF
[Last]
Session=${_cinnamon_x11_session}.desktop
User=${TARGET_USER}
INNER_EOF
        else
            echo "WARNING: could not detect a plain-X11 Cinnamon xsessions file — SDDM's default session was left unchanged (still whatever Void's package set as default, likely the Wayland experimental one)." >&2
        fi
    fi
elif [ "$DESKTOP_ENV" = "gnome" ]; then
    install_pkgs gnome
elif [ "$DESKTOP_ENV" = "xfce" ]; then
    install_pkgs xfce4 network-manager-applet gvfs xfce4-pulseaudio-plugin
elif [ "$DESKTOP_ENV" = "mate" ]; then
    install_pkgs mate mate-terminal pluma mate-media network-manager-applet
elif [ "$DESKTOP_ENV" = "lxqt" ]; then
    install_pkgs lxqt gvfs FeatherPad
elif [ "$DESKTOP_ENV" = "cosmic" ]; then
    install_cosmic cosmic-desktop-full
    _xkb_layout="$(sed -n 's/^[[:space:]]*KEYMAP=["]*\([^"[:space:]]*\)["]*[[:space:]]*\(#.*\)\{0,1\}$/\1/p' /etc/rc.conf 2>/dev/null | tail -1)"
    case "${_xkb_layout:-}" in
        ''|*[!a-zA-Z0-9_-]*) _xkb_layout="us" ;;
    esac
    _xkb_conf="/usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config"
    if [ ! -f "$_xkb_conf" ] || ! grep -q "^layout: \"${_xkb_layout}\",\$" "$_xkb_conf" 2>/dev/null; then
        echo "==> Ensuring cosmic xkb_config (layout: ${_xkb_layout})"
        mkdir -p "$(dirname "$_xkb_conf")"
        cat > "$_xkb_conf" << XKB_EOF
(
rules: "",
model: "",
layout: "${_xkb_layout}",
variant: "",
options: None,
repeat_delay: 600,
repeat_rate: 25,
)
XKB_EOF
    fi
    unset _xkb_layout _xkb_conf
    if [ "$INSTALL_COSMIC_TOUCHPAD_RCLICK" = "true" ]; then
        if [ -n "$TARGET_USER" ] && id -u "$TARGET_USER" >/dev/null 2>&1; then
            _tp_src="/usr/share/cosmic/com.system76.CosmicComp/v1/input_touchpad"
            _tp_dir="/home/${TARGET_USER}/.config/cosmic/com.system76.CosmicComp/v1"
            _tp_dst="${_tp_dir}/input_touchpad"
            mkdir -p "$_tp_dir"
            if [ -f "$_tp_src" ] && grep -q "click_method:Some(Clickfinger)" "$_tp_src"; then
                sed 's/click_method:Some(Clickfinger)/click_method:Some(ButtonAreas)/' \
                    "$_tp_src" > "$_tp_dst"
            else
                cat > "$_tp_dst" << 'TP_EOF'
(state:Enabled,click_method:Some(ButtonAreas),scroll_config:Some((method:Some(TwoFinger),natural_scroll:None,scroll_button:None,scroll_factor:None)),tap_config:Some((enabled:true,button_map:Some(LeftRightMiddle),drag:true,drag_lock:false)))
TP_EOF
            fi
            chmod 0644 "$_tp_dst"
            chown "${TARGET_USER}:${TARGET_USER}" "$_tp_dst"
            echo "==> COSMIC touchpad right-click override written for ${TARGET_USER}"
        else
            echo "  WARNING: touchpad right-click requested, but target account does not exist yet — skipping." >&2
        fi
        unset _tp_src _tp_dir _tp_dst
    fi
elif [ "$DESKTOP_ENV" = "kde" ]; then
    install_pkgs kde-plasma kde-baseapps ark kio-admin
fi

if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    _greeter_bg=""
    for _greeter_bg_name in adwaita-l.jpg adwaita-l.jxl adwaita-l.png adwaita-l.svg; do
        _greeter_bg_candidate="$(find /usr/share/backgrounds -maxdepth 2 -type f \
            -name "$_greeter_bg_name" 2>/dev/null | head -1)" || true
        if [[ -n "$_greeter_bg_candidate" ]]; then
            _greeter_bg="$_greeter_bg_candidate"
            break
        fi
    done
    if [[ -z "$_greeter_bg" ]]; then
        _greeter_bg="$(find /usr/share/backgrounds -maxdepth 5 -type f \
            \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
               -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
            2>/dev/null | head -1)" || true
    fi
    if [[ -z "$_greeter_bg" ]]; then
        echo "==> No wallpapers found; installing gnome-backgrounds for the greeter"
        install_pkgs gnome-backgrounds
        for _greeter_bg_name in adwaita-l.jpg adwaita-l.jxl adwaita-l.png adwaita-l.svg; do
            _greeter_bg_candidate="$(find /usr/share/backgrounds -maxdepth 2 -type f \
                -name "$_greeter_bg_name" 2>/dev/null | head -1)" || true
            [[ -n "$_greeter_bg_candidate" ]] && { _greeter_bg="$_greeter_bg_candidate"; break; }
        done
        if [[ -z "$_greeter_bg" ]]; then
            _greeter_bg="$(find /usr/share/backgrounds -maxdepth 5 -type f \
                \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
                   -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
                2>/dev/null | head -1)" || true
        fi
    fi
    if [[ -n "$_greeter_bg" ]]; then
        case "$LIGHTDM_GREETER" in
            gtk)
                cat > /etc/lightdm/lightdm-gtk-greeter.conf << INNER_EOF
[greeter]
background="${_greeter_bg}"
INNER_EOF
                ;;
            slick)
                cat > /etc/lightdm/slick-greeter.conf << INNER_EOF
[Greeter]
background=${_greeter_bg}
INNER_EOF
                ;;
        esac
    fi
    unset _greeter_bg _greeter_bg_candidate _greeter_bg_name
fi

case "$DESKTOP_ENV" in
    cinnamon|xfce|mate|lxqt)
        install_pkgs lxqt-policykit
        ;;
    cosmic)
        install_pkgs polkit-gnome
        _pg_auth_bin=""
        for _pg_cand in /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome-authentication-agent-1; do
            [ -x "$_pg_cand" ] && { _pg_auth_bin="$_pg_cand"; break; }
        done
        if [ -n "$_pg_auth_bin" ]; then
            mkdir -p /usr/local/sbin /etc/xdg/autostart
            cat > /usr/local/sbin/cosmic-polkit-guard << 'GUARD_EOF'
#!/bin/sh
set -u
_agent="__PG_AUTH_BIN__"
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
GUARD_EOF
            sed -i "s|__PG_AUTH_BIN__|${_pg_auth_bin}|" /usr/local/sbin/cosmic-polkit-guard
            chmod 0755 /usr/local/sbin/cosmic-polkit-guard
            cat > /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop << 'INNER_EOF'
[Desktop Entry]
Name=PolicyKit Authentication Agent
Comment=PolicyKit Authentication Agent
Exec=/usr/local/sbin/cosmic-polkit-guard
Terminal=false
Type=Application
Categories=
NoDisplay=true
INNER_EOF
        else
            echo "WARNING: polkit-gnome agent binary not found — COSMIC privilege prompts will hang." >&2
        fi
        unset _pg_auth_bin _pg_cand
        install_pkgs udiskie
        cat > /usr/local/sbin/udiskie-guard << 'UDG_EOF'
#!/bin/sh
set -u
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
UDG_EOF
        chmod 0755 /usr/local/sbin/udiskie-guard
        cat > /etc/xdg/autostart/udiskie.desktop << 'INNER_EOF'
[Desktop Entry]
Name=udiskie
Comment=Removable media automounter
Exec=/usr/local/sbin/udiskie-guard
Terminal=false
Type=Application
Categories=
NoDisplay=true
INNER_EOF
        ;;
esac
install_pkgs xdg-user-dirs xdg-utils xtools rsync git curl wget make binutils inotify-tools fastfetch chrony cronie bridge-utils smartmontools
[ "$PROFILE_TLP" = "true" ] && install_pkgs tlp tlp-rdw
[ "$POWER_PPD" = "true" ] && install_pkgs power-profiles-daemon
[ "$PROFILE_BT" = "true" ] && install_pkgs bluez
[ "$PROFILE_PRELOAD" = "true" ] && install_pkgs preload
[ "$INSTALL_OCTOXBPS" = "true" ] && install_pkgs octoxbps

if [ "$INSTALL_FLATPAK" = "true" ]; then
    install_pkgs flatpak fuse fuse3
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || \
        echo "WARNING: could not add flathub remote at install time. It will be re-attempted, non-blocking, at first boot (see [FLATHUB-RCL])." >&2
fi

if [ "$INSTALL_BREW" = "true" ]; then
    install_pkgs git curl file procps-ng
    echo "==> Homebrew runtime deps installed (git curl file procps-ng) — the ~/.linuxbrew prefix is created on first login via Homebrew's official installer (see NEWS step / HOMEBREW=yes in ~/Documents/Void_Install.txt)."
fi

[ "$INSTALL_FIREFOX" = "true" ] && install_pkgs firefox
[ "$INSTALL_CHROMIUM" = "true" ] && install_pkgs chromium
[ "$INSTALL_VIVALDI" = "true" ] && install_pkgs vivaldi
[ "$INSTALL_FALKON" = "true" ] && install_pkgs falkon
[ "$INSTALL_THUNDERBIRD" = "true" ] && install_pkgs thunderbird
[ "$INSTALL_STEAM" = "true" ] && install_pkgs steam libgcc-32bit libstdc++-32bit libglvnd-32bit mesa-dri-32bit libdrm-32bit libX11-32bit libXext-32bit libXfixes-32bit libXrandr-32bit libXcursor-32bit libXi-32bit libXrender-32bit libXinerama-32bit libXxf86vm-32bit libxcb-32bit freetype-32bit fontconfig-32bit libpulseaudio-32bit alsa-plugins-pulseaudio-32bit
[ "$INSTALL_LUTRIS" = "true" ] && install_pkgs lutris
[ "$INSTALL_WINE" = "true" ] && install_pkgs wine
[ "$INSTALL_GAMEMODE" = "true" ] && install_pkgs gamemode libgamemode-32bit
if [ "$INSTALL_ANY_GAME" = "true" ]; then
    [ "$HAS_AMD_GPU" = "yes" ] && install_pkgs mesa-vulkan-radeon mesa-vulkan-radeon-32bit
    [ "$HAS_INTEL_GPU" = "yes" ] && install_pkgs mesa-vulkan-intel mesa-vulkan-intel-32bit
    if [ "$HAS_NVIDIA_GPU" = "yes" ] && [ "$INSTALL_NVIDIA" != "true" ]; then
        install_pkgs mesa-vulkan-nouveau mesa-vulkan-nouveau-32bit
    fi
fi
if [ "$INSTALL_VIRTUALBOX" = "true" ]; then
    install_pkgs virtualbox-ose virtualbox-ose-dkms
    usermod -aG vboxusers "$TARGET_USER"
fi
if [ "$INSTALL_BRAVE" = "true" ]; then
    if [ "$INSTALL_FLATPAK" = "true" ]; then
        echo "==> Brave has no official Void package — will be installed via Flatpak on first boot (flathub remote added at install time; the app itself installs after first-boot network is up)."
        mkdir -p "/home/${TARGET_USER}/.config/void-installer"
        echo "com.brave.Browser" >> "/home/${TARGET_USER}/.config/void-installer/flatpak-install-on-first-boot.txt"
        chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/void-installer"
    else
        echo "WARNING: Brave was selected but Flatpak was not — Brave has no official Void package, so it will NOT be installed. Install Flatpak later and run 'flatpak install flathub com.brave.Browser', or use another method of your choosing." >&2
    fi
fi

if [ "$INSTALL_COSMIC_STORE" = "true" ]; then
    if [ "$INSTALL_FLATPAK" = "true" ]; then
        echo "==> cosmic-store has no official Void package — installed from the bluesloth COSMIC repo (Flatpak is already on per the channel choice)."
        install_cosmic cosmic-store
    else
        echo "WARNING: cosmic-store was selected but Flatpak was not — the store hard run-depends on flatpak, so it will NOT be installed." >&2
    fi
fi

if [ "$INSTALL_HEROIC" = "true" ] && [ "$INSTALL_FLATPAK" = "true" ]; then
    mkdir -p "/home/${TARGET_USER}/.config/void-installer"
    echo "com.heroicgameslauncher.hgl" >> "/home/${TARGET_USER}/.config/void-installer/flatpak-install-on-first-boot.txt"
    chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/void-installer"
fi
if [ "$INSTALL_BOTTLES" = "true" ] && [ "$INSTALL_FLATPAK" = "true" ]; then
    mkdir -p "/home/${TARGET_USER}/.config/void-installer"
    echo "com.usebottles.bottles" >> "/home/${TARGET_USER}/.config/void-installer/flatpak-install-on-first-boot.txt"
    chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/void-installer"
fi

if [ "$INSTALL_FLATPAK" = "true" ]; then
    mkdir -p /etc/NetworkManager/dispatcher.d
    cat > /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot << 'DIS_EOF'
#!/bin/sh
case "$2" in
    up|vpn-up|connectivity-change) ;;
    *) exit 0 ;;
esac
command -v flatpak >/dev/null 2>&1 || exit 0
[ -f /var/log/flatpak-firstboot.done ] && exit 0
exec 9>/var/lock/flatpak-firstboot.lock
flock -n 9 || exit 0
ip route show default >/dev/null 2>&1 || exit 0
_fp_queue="/home/__TARGET_USER__/.config/void-installer/flatpak-install-on-first-boot.txt"
[ -f "$_fp_queue" ] || exit 0
echo "=== flatpak-firstboot: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
: > /var/log/flatpak-firstboot.log
_fp_fail=0
while IFS= read -r _fp_app_id; do
    [ -n "$_fp_app_id" ] || continue
    echo "==> Installing queued Flatpak app: ${_fp_app_id}"
    if ! flatpak install -y --noninteractive flathub "$_fp_app_id" >> /var/log/flatpak-firstboot.log 2>&1; then
        echo "WARNING: failed to install queued Flatpak app '${_fp_app_id}' — will retry on next up event." >&2
        _fp_fail=1
    fi
done < "$_fp_queue"
if [ "$_fp_fail" -eq 0 ]; then
    touch /var/log/flatpak-firstboot.done
else
    echo "WARNING: one or more queued Flatpak installs failed — queue is still live." >&2
fi
DIS_EOF
    chmod 0755 /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot
    sed -i "s/__TARGET_USER__/${TARGET_USER}/g" /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot
    echo "==> NetworkManager flatpak-firstboot dispatcher installed → /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot"
fi

[ "$INSTALL_PODMAN" = "true" ] && install_pkgs podman
[ "$INSTALL_PODMAN_ROOTLESS" = "true" ] && install_pkgs fuse-overlayfs slirp4netns crun catatonit
[ "$INSTALL_DOCKER" = "true" ] && install_pkgs docker
if [ "$INSTALL_DOCKER" = "true" ] && [ "$DOCKER_GROUP_ADD" = "true" ]; then
    usermod -aG docker "$TARGET_USER"
fi

if [ "$INSTALL_PODMAN" = "true" ]; then
    mkdir -p /etc/containers
    if ! grep -q '^unqualified-search-registries' /etc/containers/registries.conf 2>/dev/null; then
        echo 'unqualified-search-registries = ["docker.io", "registry.fedoraproject.org"]' >> /etc/containers/registries.conf
    fi
fi

DISTROBOX_VERSION="1.8.2.5"
if [ "$INSTALL_DISTROBOX" = "true" ]; then
    if [ "$DISTROBOX_TRACK" = "next" ]; then
        if command -v curl >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
            install_pkgs go
            DBX_CLONE_DIR="/tmp/distrobox-next-build"
            rm -rf "$DBX_CLONE_DIR"
            DBX_CLONE_OK=0
            for _dbx_attempt in 1 2 3; do
                echo "==> Cloning distrobox (next track), attempt ${_dbx_attempt}/3..."
                if git clone --quiet https://github.com/89luca89/distrobox.git "$DBX_CLONE_DIR"; then
                    DBX_CLONE_OK=1
                    break
                fi
                echo "==> distrobox clone attempt ${_dbx_attempt} failed, retrying in 5s..." >&2
                sleep 5
            done
            if [ "$DBX_CLONE_OK" -ne 1 ]; then
                echo "WARNING: distrobox 'next' track clone failed after 3 attempts — skipping distrobox install." >&2
            else
                (
                    cd "$DBX_CLONE_DIR"
                    git checkout --quiet next
                    make build
                    make install PREFIX=/usr/local
                )
                rm -f /usr/local/bin/distrobox-legacy-wrapper 2>/dev/null || true
            fi
        else
            echo "WARNING: curl/git not found — skipping distrobox 'next' track install." >&2
        fi
    else
        if command -v curl >/dev/null 2>&1; then
            if [ "$DISTROBOX_TRACK" = "current" ]; then
                curl -fsSL "https://raw.githubusercontent.com/89luca89/distrobox/legacy/install" | sh
            else
                curl -fsSL "https://raw.githubusercontent.com/89luca89/distrobox/legacy/install" \
                    | sh -s -- --version "$DISTROBOX_VERSION"
            fi
        else
            echo "WARNING: curl not found — skipping distrobox install." >&2
        fi
    fi

    if [ -n "$DISTROBOX_DEFAULT_ENGINE" ]; then
        mkdir -p "/home/${TARGET_USER}/.config/distrobox"
        cat > "/home/${TARGET_USER}/.config/distrobox/distrobox.conf" << INNER_EOF
container_manager="${DISTROBOX_DEFAULT_ENGINE}"
INNER_EOF
        chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/distrobox"
    fi
fi

mkdir -p /etc/profile.d
cat > /etc/profile.d/flatpak-xdg-fix.sh << 'INNER_EOF'
#!/bin/sh
FLATPAK_SYSTEM_DIR="/var/lib/flatpak/exports/share"
FLATPAK_USER_DIR="${HOME}/.local/share/flatpak/exports/share"
if [ -z "${XDG_DATA_DIRS}" ]; then
    XDG_DATA_DIRS="/usr/local/share:/usr/share"
fi
case ":${XDG_DATA_DIRS}:" in
    *:"${FLATPAK_SYSTEM_DIR}":*) ;;
    *) XDG_DATA_DIRS="${FLATPAK_SYSTEM_DIR}:${XDG_DATA_DIRS}" ;;
esac
case ":${XDG_DATA_DIRS}:" in
    *:"${FLATPAK_USER_DIR}":*) ;;
    *) XDG_DATA_DIRS="${FLATPAK_USER_DIR}:${XDG_DATA_DIRS}" ;;
esac
export XDG_DATA_DIRS
INNER_EOF
chmod +x /etc/profile.d/flatpak-xdg-fix.sh

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/30-mac-randomization.conf << 'INNER_EOF'
[device-mac-randomization]
wifi.scan-rand-mac-address=yes
[connection-mac-randomization]
ethernet.cloned-mac-address=stable
wifi.cloned-mac-address=stable
connection.stable-id=${CONNECTION}/${BOOT}
ipv4.dhcp-client-id=mac
ipv4.dhcp-iaid=mac
ipv6.dhcp-duid=ll
INNER_EOF

if [ "$INSTALL_VIRT" = "true" ] && [ -n "${NET_INTERFACE_MATCH:-}" ]; then
mkdir -p /etc/NetworkManager/system-connections

cat > /etc/NetworkManager/system-connections/br0.nmconnection << 'INNER_EOF'
[connection]
id=br0
uuid=a6b8c9d0-1234-4567-abcd-ef0123456789
type=bridge
interface-name=br0

[bridge]
stp=false

[ipv4]
method=auto

[ipv6]
method=auto
INNER_EOF
chmod 600 /etc/NetworkManager/system-connections/br0.nmconnection

if case "$NET_INTERFACE_MATCH" in *"*"*) true ;; *) false ;; esac; then
    _SLV_IFACE_LINE=""
else
    _SLV_IFACE_LINE="interface-name=${NET_INTERFACE_MATCH}"
fi
cat > /etc/NetworkManager/system-connections/br0-slave.nmconnection << INNER_EOF
[connection]
id=br0-slave
uuid=b7c9d0e1-5678-9012-bcde-f0123456789a
type=ethernet
${_SLV_IFACE_LINE}
master=br0
slave-type=bridge
INNER_EOF
unset _SLV_IFACE_LINE
chmod 600 /etc/NetworkManager/system-connections/br0-slave.nmconnection
elif [ "$INSTALL_VIRT" = "true" ]; then
    echo "NOTICE: [BR0-SKIP] no wired NIC — br0/br0-slave profiles skipped; virbr0 stays enabled as the VM-networking fallback."
fi

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-kvm-routing.conf << 'INNER_EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
INNER_EOF


if [ "${INSTALL_AUDIO:-true}" = "true" ]; then
    install_pkgs alsa-utils alsa-ucm-conf alsa-pipewire pipewire wireplumber sof-firmware libjack-pipewire
    [ "$PROFILE_BT" = "true" ] && install_pkgs libspa-bluetooth
    [ "$DESKTOP_ENV" = "kde" ] && install_pkgs plasma-pa
fi

if [ "${INSTALL_AUDIO:-true}" = "true" ]; then
    mkdir -p /etc/alsa/conf.d
    ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
    ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/

    echo "/usr/lib/pipewire-0.3/jack" > /etc/ld.so.conf.d/pipewire-jack.conf
    ldconfig

    mkdir -p /etc/security/limits.d
    cat > /etc/security/limits.d/95-pipewire-realtime.conf << 'INNER_EOF'
@audio   -   rtprio   95
@audio   -   memlock  unlimited
INNER_EOF

    mkdir -p /etc/pipewire/pipewire.conf.d
    [ -f /usr/share/examples/wireplumber/10-wireplumber.conf ] && \
        ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
    [ -f /usr/share/examples/wireplumber/20-pipewire-pulse.conf ] && \
        ln -sf /usr/share/examples/wireplumber/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
fi

mkdir -p /usr/local/bin
cat > /usr/local/bin/live-overlay-skip << 'INNER_EOF'
#!/bin/sh
if grep -q 'rd.live.overlay.overlayfs=1' /proc/cmdline 2>/dev/null; then
    exit 0
fi
exec "$@"
INNER_EOF
chmod +x /usr/local/bin/live-overlay-skip

mkdir -p "/home/${TARGET_USER}/.config/autostart"
strip_desktop_restrictions() {
    sed -i -E '/^(OnlyShowIn|NotShowIn)=/d' "$1"
}

[ -f /usr/share/applications/octoxbps-notifier.desktop ] && \
    cp -f /usr/share/applications/octoxbps-notifier.desktop "/home/${TARGET_USER}/.config/autostart/"
[ -f "/home/${TARGET_USER}/.config/autostart/octoxbps-notifier.desktop" ] && \
    strip_desktop_restrictions "/home/${TARGET_USER}/.config/autostart/octoxbps-notifier.desktop"

for pw_desktop in pipewire pipewire-pulse; do
    if [ -f "/usr/share/applications/${pw_desktop}.desktop" ]; then
        cp -f "/usr/share/applications/${pw_desktop}.desktop" "/home/${TARGET_USER}/.config/autostart/"
        strip_desktop_restrictions "/home/${TARGET_USER}/.config/autostart/${pw_desktop}.desktop"
        if [ "${ENABLE_SNAPSHOT_AUDIO}" != "true" ]; then
            sed -i -E "s|^Exec=(.*)|Exec=/usr/local/bin/live-overlay-skip \1|" \
                "/home/${TARGET_USER}/.config/autostart/${pw_desktop}.desktop"
        fi
    fi
done
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config"


mkdir -p "/home/${TARGET_USER}/.cache"

provision_browser_subvol() {
    _pbs_subvol="$1"
    _pbs_relpath="$2"
    _pbs_fullpath="/home/${TARGET_USER}/${_pbs_relpath}"

    case "$_pbs_relpath" in
        */*)
            _pbs_walk="/home/${TARGET_USER}"
            _pbs_parent_chain="${_pbs_relpath%/*}"
            _pbs_old_ifs="$IFS"
            IFS='/'
            for _pbs_seg in $_pbs_parent_chain; do
                _pbs_walk="${_pbs_walk}/${_pbs_seg}"
                mkdir -p "$_pbs_walk"
                chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_walk"
            done
            IFS="$_pbs_old_ifs"
            ;;
    esac

    mkdir -p "$_pbs_fullpath"
    chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_fullpath"
    local _pbs_fstab="/home/${TARGET_USER}/${_pbs_relpath// /\\040}"
    echo "UUID=${BTRFS_UUID} ${_pbs_fstab} btrfs noatime,nodatacow,subvol=${_pbs_subvol} 0 0" >> /etc/fstab
    mount "$_pbs_fullpath"
    chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_fullpath"
    chmod 700 "$_pbs_fullpath"
}

provision_firefox_subvols() {
    provision_browser_subvol "@mozilla" ".config/mozilla"
    provision_browser_subvol "@mozilla-cache" ".cache/mozilla"
}

[ "$PROVISION_FIREFOX_SUBVOL" = "true" ] && provision_firefox_subvols
[ "$PROVISION_CHROMIUM_SUBVOL" = "true" ] && provision_browser_subvol "@chromium" ".config/chromium"
[ "$PROVISION_VIVALDI_SUBVOL" = "true" ] && provision_browser_subvol "@vivaldi" ".config/vivaldi"
[ "$PROVISION_FALKON_SUBVOL" = "true" ] && provision_browser_subvol "@falkon" ".config/falkon"
[ "$PROVISION_BRAVE_SUBVOL" = "true" ] && provision_browser_subvol "@brave" ".config/BraveSoftware/Brave-Browser"
[ "$PROVISION_THUNDERBIRD_SUBVOL" = "true" ] && provision_browser_subvol "@thunderbird" ".thunderbird"
if [ "$PROVISION_GAME_SUBVOL" = "true" ]; then
    [ "$INSTALL_STEAM"  = "true" ] && provision_browser_subvol "@game" ".local/share/Steam"
    [ "$INSTALL_LUTRIS" = "true" ] && provision_browser_subvol "@game" ".local/share/lutris"
fi
[ "$PROVISION_VIRTUALBOX_SUBVOL" = "true" ] && provision_browser_subvol "@virtualbox" "VirtualBox VMs"
[ "$PROVISION_LINUXBREW_SUBVOL" = "true" ] && provision_browser_subvol "@linuxbrew" ".linuxbrew"

if [ "$INSTALL_PODMAN_ROOTLESS" = "true" ]; then
mkdir -p "/home/${TARGET_USER}/.local" "/home/${TARGET_USER}/.local/share"
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local" "/home/${TARGET_USER}/.local/share"
mkdir -p "/home/${TARGET_USER}/.local/share/containers"
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local"
if [ "$PROVISION_PODMAN_ROOTLESS_SUBVOL" = "true" ]; then
    echo "UUID=${BTRFS_UUID} /home/${TARGET_USER}/.local/share/containers btrfs noatime,compress=zstd:1,subvol=@containers-user 0 0" >> /etc/fstab
    mount "/home/${TARGET_USER}/.local/share/containers"
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local/share/containers"
    chmod 700 "/home/${TARGET_USER}/.local/share/containers"
fi

if ! grep -q "^${TARGET_USER}:" /etc/subuid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subuid
fi
if ! grep -q "^${TARGET_USER}:" /etc/subgid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subgid
fi

mkdir -p "/home/${TARGET_USER}/.config/containers"
cat > "/home/${TARGET_USER}/.config/containers/containers.conf" << INNER_EOF
[engine]
cgroup_manager = "cgroupfs"
INNER_EOF
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/containers"
fi

case " ${REGION_PARTITIONED:-} " in
    *" home "*)
        echo "MULTI-FS: home region carved — skipping @usercache fstab/mount (~/.cache lives on the home partition)."
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        chmod 700 "/home/${TARGET_USER}/.cache"
        ;;
    *)
        echo "UUID=${BTRFS_UUID} /home/${TARGET_USER}/.cache btrfs noatime,compress=zstd:1,subvol=@usercache,noauto 0 0" >> /etc/fstab
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        mount "/home/${TARGET_USER}/.cache"
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        chmod 700 "/home/${TARGET_USER}/.cache"
        ;;
esac

if [ "$SWAP_BACKEND" = "swapfile" ] || [ "$SWAP_BACKEND" = "both" ]; then
    swapon /var/swap/swapfile
fi
if [ "$SWAP_BACKEND" = "zram" ] || [ "$SWAP_BACKEND" = "both" ]; then
    install_pkgs zramen
    cat > /etc/sv/zramen/conf << 'ZRAM_CONF'
export ZRAM_COMP_ALGORITHM=zstd
export ZRAM_PRIORITY=100
export ZRAM_SIZE=50
ZRAM_CONF
fi

install_pkgs snapper

if [ "$BOOTLOADER" = "grub" ]; then

install_pkgs grub-x86_64-efi efibootmgr
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="Void_GRUB" --recheck
else
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void_GRUB" --recheck
fi

if [ "$ENCRYPT" = "yes" ]; then
    LUKS_RD="rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=${CRYPT_NAME:-void-root}"
else
    LUKS_RD=""
fi
if [ "$ENABLE_HIBERNATION" = "true" ] && [ -f /var/swap/swapfile ]; then
    TARGET_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile)
    GRUB_CMD="loglevel=3 ${LUKS_RD} resume=UUID=${BTRFS_UUID} resume_offset=${TARGET_OFFSET}"
else
    GRUB_CMD="loglevel=3 ${LUKS_RD}"
fi
TEE_QB_FRAG=""
if [ "${DEFAULT_QUIET_BOOT:-no}" = "yes" ]; then
    TEE_QB_FRAG=" quiet"
fi
if [ "${DEFAULT_TEE_BLACKLIST:-no}" = "yes" ]; then
    TEE_QB_FRAG="${TEE_QB_FRAG} modprobe.blacklist=tee"
fi
GRUB_CMD="${GRUB_CMD}${TEE_QB_FRAG}"
unset TEE_QB_FRAG
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/d' /etc/default/grub
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMD\"" >> /etc/default/grub

install_pkgs grub-btrfs grub-btrfs-runit
mkdir -p /etc/default/grub-btrfs
if [ -f /usr/share/doc/grub-btrfs/examples/config ]; then
    cp /usr/share/doc/grub-btrfs/examples/config /etc/default/grub-btrfs/config
fi
echo 'GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"' >> /etc/default/grub-btrfs/config

grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p /etc/kernel.d/post-install /etc/kernel.d/post-remove
cat > /etc/kernel.d/post-install/99-grub-btrfs << 'INNER_EOF'
#!/bin/sh
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"

if [ -f /var/swap/swapfile ]; then
    echo "==> Recomputing hibernation resume_offset..."
    NEW_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile 2>/dev/null || echo "")
    if [ -n "$NEW_OFFSET" ]; then
        sed -i -E "s/resume_offset=[0-9]+/resume_offset=${NEW_OFFSET}/" /etc/default/grub
    else
        echo "WARNING: could not recompute resume_offset; leaving existing value in /etc/default/grub." >&2
    fi
fi

echo "==> XBPS Trigger: Regenerating GRUB menu with Btrfs snapshots..."
if command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "ERROR: grub-mkconfig binary not found." >&2
    exit 1
fi
INNER_EOF
chmod +x /etc/kernel.d/post-install/99-grub-btrfs
cp /etc/kernel.d/post-install/99-grub-btrfs /etc/kernel.d/post-remove/99-grub-btrfs

else
install_pkgs limine

LIMINE_EFI_SRC=""
for _limine_efi_candidate in /usr/share/limine/BOOTX64.EFI /usr/share/limine/BOOTX64.efi; do
    [ -f "$_limine_efi_candidate" ] && LIMINE_EFI_SRC="$_limine_efi_candidate" && break
done
if [ -z "$LIMINE_EFI_SRC" ]; then
    echo "FATAL: could not find Limine's BOOTX64.EFI under /usr/share/limine — Limine install incomplete." >&2
    exit 1
fi
mkdir -p /boot/efi/EFI/BOOT
cp -f "$LIMINE_EFI_SRC" /boot/efi/EFI/BOOT/BOOTX64.EFI

if [ "$KERNEL_MODE" = "esp-copy" ]; then
    mkdir -p /boot/efi/void-kernel
fi

mkdir -p /etc/void-installer
cat > /etc/void-installer/limine-env << INNER_EOF
KERNEL_MODE="${KERNEL_MODE}"
BTRFS_UUID="${BTRFS_UUID}"
SYSPREFIX_ESP="${SYSPREFIX_ESP}"
SYSPREFIX_BTRFS="${SYSPREFIX_BTRFS}"
HIBERNATION_ENABLED="${ENABLE_HIBERNATION}"
LIMINE_WALLPAPER="${LIMINE_WALLPAPER}"
LIMINE_WALLPAPER_STYLE="${LIMINE_WALLPAPER_STYLE}"
DEFAULT_QUIET_BOOT="${DEFAULT_QUIET_BOOT:-no}"
DEFAULT_TEE_BLACKLIST="${DEFAULT_TEE_BLACKLIST:-no}"
ENCRYPT="${ENCRYPT}"
LUKS_UUID="${LUKS_UUID}"
CRYPT_NAME="${CRYPT_NAME:-void-root}"
YK_MODE="${YK_MODE}"
YK_SLOT="${YK_SLOT}"
YK_CHALLENGE="${YK_CHALLENGE}"
YK_FALLBACK="${YK_FALLBACK}"
YK_TOUCH="${YK_TOUCH}"
INNER_EOF
chmod 644 /etc/void-installer/limine-env

mkdir -p /etc/void-installer
_ssh_key_present="no"
if [ -f "/home/${TARGET_USER}/.ssh/id_ed25519" ] || [ -f "/home/${TARGET_USER}/.ssh/imported" ]; then
    _ssh_key_present="yes"
fi
if [ "$_ssh_key_present" = "yes" ]; then
    _ssh_key_rows="SSH_KEY_COMMENT=\"${SSH_KEY_COMMENT:-<unset>}\"
SSH_KEY_PROTECTED=\"${SSH_KEY_PROTECTED:-<unset>}\""
else
    _ssh_key_rows="# (no SSH key imported or generated — comment/protection rows omitted)"
fi

FLATPAK_PULLED_BY=""
if [ "$INSTALL_FLATPAK" != "true" ] && xbps-query -p pkgver flatpak >/dev/null 2>&1; then
    FLATPAK_PULLED_BY="$(xbps-query -X flatpak 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
    echo "WARNING: [FLATPAK-PULL-DETECT] Flatpak was declined at the prompt (INSTALL_FLATPAK=false) but IS installed on this system." >&2
    echo "         Reverse dependencies (who pulled it): ${FLATPAK_PULLED_BY:-unknown}" >&2
    echo "         This is recorded in /etc/void-installer/install-config as FLATPAK_PULLED_BY." >&2
fi

VIRT_BR0="n/a"
if [ "$INSTALL_VIRT" = "true" ]; then
    if [ -n "${NET_INTERFACE_MATCH:-}" ]; then
        VIRT_BR0="created"
    else
        VIRT_BR0="skipped (no wired NIC; virbr0 kept)"
    fi
fi

cat > /etc/void-installer/install-config << INNER_EOF
SCRIPT_VERSION="${SCRIPT_VERSION:-<unknown>}"
HOSTNAME="${TARGET_HOSTNAME:-<unset>}"
USER="${TARGET_USER:-<unset>}"
USER_FULL_NAME="${TARGET_FULL_NAME:-<unset>}"
USER_SHELL="${USER_SHELL:-<unset>}"
DESKTOP_ENV="${DESKTOP_ENV:-<unset>}"
DISPLAY_MANAGER="${DISPLAY_MANAGER:-<unset>}"
HAS_GRAPHICAL="${HAS_GRAPHICAL:-yes}"
INSTALL_XORG="${INSTALL_XORG:-false}"
INSTALL_AUDIO="${INSTALL_AUDIO:-true}"
BOOTLOADER="${BOOTLOADER:-<unset>}"
KERNEL_MODE="${KERNEL_MODE:-<unset>}"
KERNEL_PKGS="${KERNEL_PKGS:-<unset>}"
DEVICE_PROFILE="${DEVICE_PROFILE:-<unset>}"
PROFILE_TLP="${PROFILE_TLP:-<unset>}"
PROFILE_BT="${PROFILE_BT:-<unset>}"
PROFILE_PRELOAD="${PROFILE_PRELOAD:-<unset>}"
POWER_PPD="${POWER_PPD:-false}"  # [COSMIC-PPD] true = COSMIC build carries PPD (tlp skipped)
ENCRYPT="${ENCRYPT:-no}"
CRYPT_NAME="${CRYPT_NAME:-void-root}"
SESSION_STACK="${SESSION_STACK:-<unset>}"
LOCALE="${LOCALE:-<unset>}"
TIMEZONE="${TIMEZONE:-<unset>}"
REPO_PRIMARY="${REPO_PRIMARY:-<unset>}"
LOCAL_CACHE_REUSE="${LOCAL_CACHE_REUSE:-no}"
SWAP_BACKEND="${SWAP_BACKEND:-<unset>}"
ENABLE_HIBERNATION="${ENABLE_HIBERNATION:-<unset>}"
SWAPFILE_SIZE="${SWAPFILE_SIZE:-<unset>}"
LIMINE_WALLPAPER="${LIMINE_WALLPAPER:-<unset>}"
LIMINE_WALLPAPER_STYLE="${LIMINE_WALLPAPER_STYLE:-<unset>}"
INSTALL_SSH_SERVER="${INSTALL_SSH_SERVER:-false}"
SSH_PORT="${SSH_PORT:-<unset>}"
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-<unset>}"
SSH_ROOT_LOGIN="${SSH_ROOT_LOGIN:-<unset>}"
SSH_KEY_PRESENT="${_ssh_key_present}"
${_ssh_key_rows}
GPU_FAMILIES="${GPU_FAMILIES:-<unset>}"
WIFI_HW="${WIFI_HW:-<unset>}"
HAS_NVIDIA_GPU="${HAS_NVIDIA_GPU:-<unset>}"
HAS_AMD_GPU="${HAS_AMD_GPU:-<unset>}"
HAS_INTEL_GPU="${HAS_INTEL_GPU:-<unset>}"
INSTALL_NVIDIA="${INSTALL_NVIDIA:-<unset>}"
BR0_NIC="${BR0_NIC:-<unset>}"
VIRT_BR0="${VIRT_BR0:-n/a}"
MICROCODE_PKG="${MICROCODE_PKG:-<unset>}"
MICROCODE_DECIDED="${MICROCODE_DECIDED:-<unset>}"
INSTALL_FLATPAK="${INSTALL_FLATPAK:-false}"
INSTALL_COSMIC_STORE="${INSTALL_COSMIC_STORE:-false}"
FLATPAK_PULLED_BY="${FLATPAK_PULLED_BY:-}"
INSTALL_BRAVE="${INSTALL_BRAVE:-false}"
INSTALL_BREW="${INSTALL_BREW:-false}"
PROVISION_LINUXBREW_SUBVOL="${PROVISION_LINUXBREW_SUBVOL:-false}"
INSTALL_LUTRIS="${INSTALL_LUTRIS:-false}"
INSTALL_HEROIC="${INSTALL_HEROIC:-false}"
INSTALL_BOTTLES="${INSTALL_BOTTLES:-false}"
INSTALL_WINE="${INSTALL_WINE:-false}"
INSTALL_GAMEMODE="${INSTALL_GAMEMODE:-false}"
INSTALL_ANY_GAME="${INSTALL_ANY_GAME:-false}"
PROVISION_GAME_SUBVOL="${PROVISION_GAME_SUBVOL:-false}"
INSTALL_STEAM="${INSTALL_STEAM:-false}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
INSTALL_PODMAN_ROOTLESS="${INSTALL_PODMAN_ROOTLESS:-false}"
INSTALL_PODMAN_ROOTFUL="${INSTALL_PODMAN_ROOTFUL:-false}"
PROVISION_DOCKER_SUBVOL="${PROVISION_DOCKER_SUBVOL:-false}"
PROVISION_PODMAN_SUBVOL="${PROVISION_PODMAN_SUBVOL:-false}"
PROVISION_PODMAN_ROOTLESS_SUBVOL="${PROVISION_PODMAN_ROOTLESS_SUBVOL:-false}"
REGION_HOME_FS="${REGION_HOME_FS:-btrfs}"
REGION_VAR_FS="${REGION_VAR_FS:-btrfs}"
REGION_CACHE_FS="${REGION_CACHE_FS:-btrfs}"
REGION_SRV_FS="${REGION_SRV_FS:-btrfs}"
REGION_OPT_FS="${REGION_OPT_FS:-btrfs}"
REGION_GAMES="${REGION_GAMES:-none}"
REGION_PARTITIONED="${REGION_PARTITIONED:-}"
REGION_HOME_SIZE="${REGION_HOME_SIZE:-}"
REGION_VAR_SIZE="${REGION_VAR_SIZE:-}"
REGION_CACHE_SIZE="${REGION_CACHE_SIZE:-}"
REGION_SRV_SIZE="${REGION_SRV_SIZE:-}"
REGION_OPT_SIZE="${REGION_OPT_SIZE:-}"
REGION_GAMES_SIZE="${REGION_GAMES_SIZE:-}"
INNER_EOF
chmod 644 /etc/void-installer/install-config

if [ -n "${TARGET_USER}" ] && [ -d "/home/${TARGET_USER}" ]; then
    mkdir -p "/home/${TARGET_USER}/Documents"
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/Documents"
    {
        echo "# ========================================================================="
        echo "# VOID LINUX install record for THIS machine"
        echo "# Written to ~/Documents by Void_Linux_Installer.sh v${SCRIPT_VERSION} at install time."
        echo "# Secret-free 'as-built' tracking. Full install-time CHOICES + installer"
        echo "# version live in /etc/void-installer/install-config; the installer itself"
        echo "# is archived at /etc/void-installer/Void_Linux_Installer.sh."
        echo "# ========================================================================="
        echo "SCRIPT_VERSION=${SCRIPT_VERSION:-<unknown>}"
        echo "INSTALLED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "HOSTNAME=${TARGET_HOSTNAME:-<unset>}"
        echo "USER=${TARGET_USER:-<unset>}"
        echo "BOOTLOADER=${BOOTLOADER:-<unset>}"
        if [ "${GRUB_ESP_BOOT}" = "true" ]; then
            echo "ESP_MOUNTED_AT=/boot (GRUB+ENCRYPT combo: boot tree unencrypted, on the ESP)"
        else
            echo "ESP_MOUNTED_AT=/boot/efi"
        fi
        echo "ENCRYPT=${ENCRYPT:-no}"
        echo "LUKS_MAPPER=${CRYPT_NAME:-void-root}"
        echo "YUBIKEY_UNLOCK=${YK_MODE:-off}"
        echo "SESSION_STACK=${SESSION_STACK:-<unset>}"
        echo "DESKTOP_ENV=${DESKTOP_ENV:-<unset>}"
        echo "SSH_SERVER=${INSTALL_SSH_SERVER:-no} (port ${SSH_PORT:-22}; policy: /etc/void-installer/install-config)"
        echo "NVIDIA_DRIVER=${INSTALL_NVIDIA:-no} (GPU: ${GPU_FAMILIES:-<none detected>}, wifi: ${WIFI_HW:-no})"
        echo "WIFI_HARDWARE=${WIFI_IDS:-<none>}"
        _doc_cpu="$(grep -m1 vendor_id /proc/cpuinfo 2>/dev/null | awk '{print $3}')"
        echo "CPU=${_doc_cpu:-<unknown>} (microcode: ${MICROCODE_PKG:-none})"
        unset _doc_cpu
        echo "HOMEBREW=${INSTALL_BREW:-no} (deps: git/curl/file via xbps; install the prefix yourself: ~/.linuxbrew — see NEWS; isolation: ${PROVISION_LINUXBREW_SUBVOL:-false})"
        _doc_g=""
        [ "$INSTALL_STEAM" = "true" ] && _doc_g="$_doc_g steam"
        [ "$INSTALL_LUTRIS" = "true" ] && _doc_g="$_doc_g lutris"
        [ "$INSTALL_HEROIC" = "true" ] && _doc_g="$_doc_g heroic(flatpak)"
        [ "$INSTALL_BOTTLES" = "true" ] && _doc_g="$_doc_g bottles(flatpak)"
        [ "$INSTALL_WINE" = "true" ] && _doc_g="$_doc_g wine"
        [ "$INSTALL_GAMEMODE" = "true" ] && _doc_g="$_doc_g gamemode"
        if [ -n "$_doc_g" ]; then
            echo "GAMING=${_doc_g# } (@game isolation: ${PROVISION_GAME_SUBVOL:-false})"
        else
            echo "GAMING=no"
        fi
        unset _doc_g
        _doc_regions="home:${REGION_HOME_FS:-btrfs},var:${REGION_VAR_FS:-btrfs},cache:${REGION_CACHE_FS:-btrfs},srv:${REGION_SRV_FS:-btrfs},opt:${REGION_OPT_FS:-btrfs}"
        [ "${REGION_GAMES:-none}" != "none" ] && _doc_regions="${_doc_regions},games:${REGION_GAMES}"
        echo "DATA_REGIONS=${_doc_regions}"
        unset _doc_regions
        echo ""
        echo "# -------- INSTALLED PACKAGES (full xbps-query -l inventory) --------"
        if command -v xbps-query >/dev/null 2>&1; then
            xbps-query -l 2>/dev/null | sed -E 's/^\[installed\] //' | sort
        else
            echo "# xbps-query unavailable in chroot — package inventory omitted"
        fi
    } > "/home/${TARGET_USER}/Documents/Void_Install.txt"
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/Documents/Void_Install.txt"
    chmod 644 "/home/${TARGET_USER}/Documents/Void_Install.txt"
fi

if [ "${LIMINE_WALLPAPER}" = "yes" ]; then
    for _wp in /tmp/limine-splash.*; do
        [ -f "$_wp" ] || continue
        if cp -f "$_wp" "/boot/efi/limine-splash.${_wp##*.}" 2>/dev/null; then
            echo "Limine wallpaper installed → /boot/efi/limine-splash.${_wp##*.}"
            LIMINE_WALLPAPER="yes"
        else
            echo "WARNING: could not copy Limine wallpaper to ESP — wallpaper omitted." >&2
            LIMINE_WALLPAPER="none"
        fi
        break
    done
    if ! ls /boot/efi/limine-splash.* >/dev/null 2>&1; then
        LIMINE_WALLPAPER="none"
    fi
fi

mkdir -p /usr/local/sbin
cat > /usr/local/sbin/void-limine-env.inc << 'INNER_EOF'
load_limine_env() {
    local _env=/etc/void-installer/limine-env
    if [ ! -f "$_env" ]; then
        echo "FATAL: ${_env} missing — was this system installed with BOOTLOADER=limine?" >&2
        exit 1
    fi
    . "$_env"
}
INNER_EOF
chmod 0644 /usr/local/sbin/void-limine-env.inc

cat > /usr/local/sbin/void-limine-write-conf << 'INNER_EOF'
#!/bin/bash
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"

. /usr/local/sbin/void-limine-env.inc
load_limine_env

if [ "${ENCRYPT}" = "yes" ]; then
    LUKS_RD="rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=${CRYPT_NAME:-void-root}"
else
    LUKS_RD=""
fi
if [ "${HIBERNATION_ENABLED}" = "true" ] && [ -f /var/swap/swapfile ]; then
    TARGET_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile 2>/dev/null || echo 0)
    BASE_CMD="loglevel=3 ${LUKS_RD} resume=UUID=${BTRFS_UUID} resume_offset=${TARGET_OFFSET} root=UUID=${BTRFS_UUID} rootflags=subvol=@"
else
    BASE_CMD="loglevel=3 ${LUKS_RD} root=UUID=${BTRFS_UUID} rootflags=subvol=@"
fi
TEE_QB_FRAG=""
if [ "${DEFAULT_QUIET_BOOT:-no}" = "yes" ]; then
    TEE_QB_FRAG=" quiet"
fi
if [ "${DEFAULT_TEE_BLACKLIST:-no}" = "yes" ]; then
    TEE_QB_FRAG="${TEE_QB_FRAG} modprobe.blacklist=tee"
fi
BASE_CMD="${BASE_CMD}${TEE_QB_FRAG}"
unset TEE_QB_FRAG

kernel_path_for() {
    echo "${SYSPREFIX_ESP}:/void-kernel/vmlinuz-$1"
}
module_path_for() {
    echo "${SYSPREFIX_ESP}:/void-kernel/initramfs-$1.img"
}

NEWEST_KVER=""
KERNEL_ENTRIES=""
for _kf in $(ls /boot/efi/void-kernel/vmlinuz-* 2>/dev/null | sort -V -r); do
    _kver="${_kf#/boot/efi/void-kernel/vmlinuz-}"
    [ -f "/boot/efi/void-kernel/initramfs-${_kver}.img" ] || continue
    [ -z "$NEWEST_KVER" ] && NEWEST_KVER="$_kver"
    KERNEL_ENTRIES="${KERNEL_ENTRIES} ${_kver}"
done

if [ -z "$NEWEST_KVER" ]; then
    echo "WARNING: no bootable kernel found under /boot/efi/void-kernel — limine.conf will have no /Void Linux entries. Run void-limine-sync-kernels first." >&2
fi

TMP_CONF="$(mktemp /boot/efi/EFI/BOOT/limine.conf.XXXXXX)"
{
    echo "timeout: 5"
    if [ -n "$NEWEST_KVER" ]; then
        echo "default_entry: Void Linux/Void Linux (${NEWEST_KVER})"
    else
        echo "default_entry: 1"
    fi
    echo "remember_last_entry: yes"

    if [ "${LIMINE_WALLPAPER}" = "yes" ]; then
        for _wpfile in /boot/efi/limine-splash.*; do
            [ -f "$_wpfile" ] || continue
            echo "wallpaper: boot():/limine-splash.${_wpfile##*.}"
            echo "wallpaper_style: ${LIMINE_WALLPAPER_STYLE:-stretched}"
            break
        done
    else
        echo "# Boot wallpaper disabled at install. To enable, set"
        echo "#   LIMINE_WALLPAPER=yes  (and optionally LIMINE_WALLPAPER_STYLE="
        echo "#     stretched | tiled | centered)"
        echo "# in /etc/void-installer/limine-env and place an image on the ESP as"
        echo "#   boot():/limine-splash.<ext>  (BMP/PNG/JPEG/QOI)"
        echo "# void-limine-write-conf re-emits the live wallpaper:/wallpaper_style"
        echo "# lines here on the next kernel sync or snapshot create/delete."
        echo "# wallpaper: boot():/limine-splash.png"
        echo "# wallpaper_style: ${LIMINE_WALLPAPER_STYLE:-stretched}"
    fi
    echo ""
    echo "# Paths below use guid(<PARTUUID>) addressing — no disk-enumeration-"
    echo "# order assumption, unlike the earlier hdd(N):<GUID> form this script"
    echo "# generated before Beta-v2.3.0 (which was invalid Limine URI syntax"
    echo "# and caused every kernel-mode boot attempt to PANIC with 'Failed to"
    echo "# open kernel with path... Is the path correct?')."
    echo "# Regenerated by void-limine-write-conf — do not hand-edit, it"
    echo "# will be overwritten on the next kernel update or snapshot"
    echo "# create/delete."

    echo ""
    echo "/+Void Linux"
    for _kver in $KERNEL_ENTRIES; do
        echo "    //Void Linux (${_kver})"
        echo "    protocol: linux"
        echo "    kernel_path: $(kernel_path_for "$_kver")"
        echo "    kernel_cmdline: ${BASE_CMD}"
        echo "    module_path: $(module_path_for "$_kver")"
    done

    if [ -d /.snapshots ] && [ -n "$NEWEST_KVER" ]; then
        echo ""
        echo "/+Snapshots"
        for snap_dir in /.snapshots/*/; do
            [ -d "$snap_dir" ] || continue
            snap_id="$(basename "$snap_dir")"
            [ -f "${snap_dir}info.xml" ] || continue
            snap_date="$(sed -n 's:.*<date>\(.*\)</date>.*:\1:p' "${snap_dir}info.xml" | head -n1)"
            snap_desc="$(sed -n 's:.*<description>\(.*\)</description>.*:\1:p' "${snap_dir}info.xml" | head -n1)"
            if [ -n "$snap_date" ]; then
                snap_fmt="$(date -d "$snap_date" '+%b %-d, %Y %H:%M' 2>/dev/null || echo "$snap_date")"
            else
                snap_fmt=""
            fi
            if [ -n "$snap_fmt" ]; then
                if [ -n "$snap_desc" ]; then
                    echo "    //${snap_desc} · ${snap_fmt} (#${snap_id})"
                else
                    echo "    //${snap_fmt} (#${snap_id})"
                fi
            else
                [ -n "$snap_desc" ] || snap_desc="snapshot ${snap_id}"
                echo "    //${snap_desc} (#${snap_id})"
            fi
            echo "    protocol: linux"
            echo "    kernel_path: $(kernel_path_for "$NEWEST_KVER")"
            echo "    kernel_cmdline: ${BASE_CMD/rootflags=subvol=@/rootflags=subvol=@snapshots\/${snap_id}\/snapshot} rd.live.overlay.overlayfs=1"
            echo "    module_path: $(module_path_for "$NEWEST_KVER")"
        done
    fi

    echo ""
    echo "/Reboot Into Firmware"
    echo "    protocol: efi_firmware_update_request"
} > "$TMP_CONF"
mv -f "$TMP_CONF" /boot/efi/EFI/BOOT/limine.conf
INNER_EOF
chmod 0755 /usr/local/sbin/void-limine-write-conf

if [ "$YK_MODE" = "hmac-sha1" ]; then
    mkdir -p /usr/local/sbin
    cat > /usr/local/sbin/void-reveal-yubikey-key << INNER_EOF
#!/bin/sh
set -u
exec ykchalresp -${YK_SLOT} "${YK_CHALLENGE}"
INNER_EOF
    chmod 0755 /usr/local/sbin/void-reveal-yubikey-key
fi

mkdir -p /usr/local/sbin
cat > /usr/local/sbin/void-limine-sync-kernels << 'INNER_EOF'
#!/bin/bash
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

. /usr/local/sbin/void-limine-env.inc
load_limine_env

mkdir -p /boot/efi/void-kernel

INSTALLED_KVERS=""
for _kdir in /lib/modules/*/; do
    [ -d "$_kdir" ] || continue
    _kver="$(basename "$_kdir")"
    [ -f "/boot/vmlinuz-${_kver}" ] || continue
    [ -f "/boot/initramfs-${_kver}.img" ] || continue
    INSTALLED_KVERS="${INSTALLED_KVERS} ${_kver}"
done

if [ -z "$INSTALLED_KVERS" ]; then
    echo "WARNING: no installed kernel with both vmlinuz and initramfs found under /boot — ESP kernel sync skipped." >&2
    exit 0
fi

for _kver in $INSTALLED_KVERS; do
    _img_ok=1
    if command -v lsinitrd >/dev/null 2>&1; then
        if [ "${ENCRYPT:-}" = "yes" ]; then
            lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'bin/cryptsetup' >/dev/null || _img_ok=0
            if [ -d /usr/lib/dracut/modules.d/98void-inner-partscan ]; then
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'kpartx' >/dev/null || _img_ok=0
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'partprobe' >/dev/null || _img_ok=0
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'void-inner-partscan.sh' >/dev/null || _img_ok=0
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c '10-void-inner-partscan.rules' >/dev/null || _img_ok=0
            fi
        fi
    else
        _img_ok=0
    fi
    if [ "$_img_ok" != "1" ]; then
        echo "WARNING: /boot/initramfs-${_kver}.img fails boot-content verification (missing cryptsetup and/or kpartx/partprobe/void-inner-partscan bits) — NOT copying it to the ESP; the previous ESP initramfs stays. Re-run 'dracut --force /boot/initramfs-${_kver}.img ${_kver}' once the required packages (cryptsetup, kpartx, parted) are installed." >&2
        continue
    fi
    cp -f "/boot/vmlinuz-${_kver}" "/boot/efi/void-kernel/vmlinuz-${_kver}"
    cp -f "/boot/initramfs-${_kver}.img" "/boot/efi/void-kernel/initramfs-${_kver}.img"
done
unset _img_ok
echo "==> Limine ESP kernels synced (${INSTALLED_KVERS# })"

for _esp_kfile in /boot/efi/void-kernel/vmlinuz-*; do
    [ -f "$_esp_kfile" ] || continue
    _esp_kver="${_esp_kfile#/boot/efi/void-kernel/vmlinuz-}"
    case " ${INSTALLED_KVERS} " in
        *" ${_esp_kver} "*) : ;;
        *)
            echo "==> Removing stale ESP kernel copy: ${_esp_kver}"
            rm -f "$_esp_kfile" "/boot/efi/void-kernel/initramfs-${_esp_kver}.img"
            ;;
    esac
done
INNER_EOF
chmod 0755 /usr/local/sbin/void-limine-sync-kernels

mkdir -p /etc/kernel.d/post-install
cat > /etc/kernel.d/post-install/50-sync-limine-kernels.sh << 'INNER_EOF'
#!/bin/sh
set -eu
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf
INNER_EOF
chmod +x /etc/kernel.d/post-install/50-sync-limine-kernels.sh
cp /etc/kernel.d/post-install/50-sync-limine-kernels.sh /etc/kernel.d/post-remove/50-sync-limine-kernels.sh 2>/dev/null || \
    { mkdir -p /etc/kernel.d/post-remove; cp /etc/kernel.d/post-install/50-sync-limine-kernels.sh /etc/kernel.d/post-remove/50-sync-limine-kernels.sh; }

mkdir -p /usr/lib/snapper/plugins
cat > /usr/lib/snapper/plugins/00-void-limine-snapper-sync << 'INNER_EOF'
#!/bin/bash
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

case "${1:-}" in
    create-snapshot-post|delete-snapshot-post)
        /usr/local/sbin/void-limine-write-conf >/dev/null 2>&1
        ;;
esac
exit 0
INNER_EOF
chmod 0755 /usr/lib/snapper/plugins/00-void-limine-snapper-sync
echo "Snapper event-driven Limine menu sync installed (/usr/lib/snapper/plugins/00-void-limine-snapper-sync)"

/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf

fi

if ! command -v snapper >/dev/null 2>&1; then
    echo "CRITICAL: snapper is not installed in the target (install_pkgs reported the package install succeeded, but 'snapper' is absent — likely a mid-transaction network drop during the package sync)." >&2
    echo "          Re-running the installer after re-establishing a stable network connection is the recommended recovery." >&2
    exit 1
fi
umount -fl /.snapshots || true
rmdir /.snapshots || true
snapper --no-dbus -c root create-config /
rmdir /.snapshots || true
mkdir -p /.snapshots
mount /.snapshots
chmod 750 /.snapshots

sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="3"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="10"/TIMELINE_LIMIT_WEEKLY="2"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/g' /etc/snapper/configs/root
sed -i 's/EMPTY_PRE_POST_CLEANUP="false"/EMPTY_PRE_POST_CLEANUP="true"/g' /etc/snapper/configs/root
mkdir -p /etc/snapper/filters
echo "var/service/*" >> /etc/snapper/filters/void-runit.txt

mkdir -p /usr/local/sbin
cat > /usr/local/sbin/void-xbps-snap << 'INNER_EOF'
#!/bin/bash
set -euo pipefail

SNAP_CONFIG="root"
SNAP_TIMELINE="/.snapshots"
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

_self="$(readlink -f "${0:-/nonexistent}")"
REAL_XBPS=""
if [ -x /usr/bin/xbps-install.real ]; then
    REAL_XBPS="/usr/bin/xbps-install.real"
else
    _cand="$(command -v xbps-install 2>/dev/null || true)"
    if [ -n "$_cand" ] && [ "$(readlink -f "$_cand" 2>/dev/null || printf '%s' "$_cand")" != "$_self" ]; then
        REAL_XBPS="$_cand"
    fi
fi
if [ -z "$REAL_XBPS" ]; then
    echo "ERROR: could not resolve the real xbps-install binary (shadowed without a .real companion?)." >&2
    exit 1
fi

_snap_enabled() {
    [ -f "/etc/snapper/configs/$SNAP_CONFIG" ] || return 1
    [ -d "$SNAP_TIMELINE" ] || return 1
    findmnt -no FSTYPE / 2>/dev/null | grep -q '^btrfs$'
}

_should_snap() {
    local _a
    for _a in "$@"; do
        case "$_a" in
            -S) return 0 ;;
            -Su|-us|-Su*|-S*) return 0 ;;
            -u) return 0 ;;
            -U) return 0 ;;
            --) break ;;
        esac
    done
    return 1
}

_main() {
    if ! _should_snap "$@" || ! _snap_enabled; then
        exec "$REAL_XBPS" "$@"
    fi

    desc="${DESC:-xbps system update ($(date '+%Y-%m-%d %H:%M:%S'))}"
    echo "==> [void-xbps-snap] before-update snapshot: $desc"

    pre_snap="$(
        snapper --no-dbus -c "$SNAP_CONFIG" create --type pre \
            --description "$desc" --cleanup number --print-number 2>/dev/null
    )" || {
        echo "WARNING: could not take pre snapshot; running xbps-install without snapshots." >&2
        pre_snap=""
    }

    set +e
    "$REAL_XBPS" "$@"
    _rc=$?
    set -e

    if [ -n "$pre_snap" ]; then
        echo "==> [void-xbps-snap] after-update snapshot (pre #$pre_snap): $desc"
        snapper --no-dbus -c "$SNAP_CONFIG" create --type post \
            --pre-number "$pre_snap" --description "$desc" --cleanup number \
            >/dev/null 2>&1 || \
            echo "WARNING: could not take post snapshot." >&2
    fi

    exit "$_rc"
}

_main "$@"
INNER_EOF
chmod 0755 /usr/local/sbin/void-xbps-snap
echo "void-xbps-snap package-update snapshot wrapper installed (/usr/local/sbin/void-xbps-snap)"

if [ -f /usr/bin/xbps-install ] && [ -x /usr/local/sbin/void-xbps-snap ]; then
    [ -e /usr/bin/xbps-install.real ] || mv -n /usr/bin/xbps-install /usr/bin/xbps-install.real
    ln -sf /usr/local/sbin/void-xbps-snap /usr/bin/xbps-install
    echo "xbps-install shadowed -> void-xbps-snap (real binary kept at /usr/bin/xbps-install.real)"
fi

mkdir -p /root/tools

cp -f /usr/local/sbin/void-xbps-snap /root/tools/void-xbps-snap
chmod 0755 /root/tools/void-xbps-snap

if [ "$BOOTLOADER" = "limine" ]; then
    cp -f /usr/local/sbin/void-limine-env.inc /root/tools/void-limine-env.inc
    cp -f /usr/local/sbin/void-limine-sync-kernels /root/tools/void-limine-sync-kernels
    cp -f /usr/local/sbin/void-limine-write-conf /root/tools/void-limine-write-conf
    chmod 0644 /root/tools/void-limine-env.inc
    chmod 0755 /root/tools/void-limine-sync-kernels
    chmod 0755 /root/tools/void-limine-write-conf
fi

cat > /root/tools/re-shadow-xbps.sh << 'INNER_EOF'
#!/bin/bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER=/usr/local/sbin/void-xbps-snap
BACKUP="$SELF_DIR/void-xbps-snap"
REAL=/usr/bin/xbps-install.real

if [ -x "$BACKUP" ]; then
    install -m 0755 "$BACKUP" "$WRAPPER"
    echo "==> wrapper restored to $WRAPPER (from $BACKUP)"
elif [ ! -x "$WRAPPER" ]; then
    echo "ERROR: no wrapper available (neither $BACKUP nor $WRAPPER). Reinstall or restore manually." >&2
    exit 1
fi

case "$(readlink /usr/bin/xbps-install 2>/dev/null || true)" in
    "$WRAPPER")
        echo "==> /usr/bin/xbps-install already -> void-xbps-snap; nothing to do."
        ;;
    "")
        if [ -f /usr/bin/xbps-install ] && [ ! -e "$REAL" ]; then
            mv -n /usr/bin/xbps-install "$REAL"
            echo "==> moved real binary to $REAL"
        fi
        ln -sf "$WRAPPER" /usr/bin/xbps-install
        echo "==> re-linked /usr/bin/xbps-install -> void-xbps-snap"
        ;;
    *)
        rm -f /usr/bin/xbps-install
        ln -sf "$WRAPPER" /usr/bin/xbps-install
        echo "==> re-pointed /usr/bin/xbps-install -> void-xbps-snap"
        ;;
esac

echo "==> state:"
ls -la /usr/bin/xbps-install "$REAL" 2>/dev/null || true
echo "==> done. A normal 'sudo xbps-install -Su' now auto-snapshots again."
INNER_EOF
chmod 0755 /root/tools/re-shadow-xbps.sh

cat > /root/tools/elogind.run.fixed << 'INNER_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
if _pid=$(cat /run/elogind.pid 2>/dev/null) && [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
    while kill -0 "$_pid" 2>/dev/null; do
        sleep 10
    done
    exit 0
fi
exec /usr/libexec/elogind/elogind.wrapper
INNER_EOF
chmod 0755 /root/tools/elogind.run.fixed

cat > /root/tools/re-fix-elogind-run.sh << 'INNER_EOF'
#!/bin/sh
set -eu
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"

FIXED="/root/tools/elogind.run.fixed"
TARGET="/etc/sv/elogind/run"

[ -f "$FIXED" ] || { echo "ERROR: $FIXED missing" >&2; exit 1; }
[ -f "$TARGET" ] || { echo "ERROR: $TARGET missing" >&2; exit 1; }

if cmp -s "$FIXED" "$TARGET"; then
    exit 0
fi

install -m 0755 "$FIXED" "$TARGET"
echo "elogind run script restored to fixed copy (was reverted, likely by upgrade)."
INNER_EOF
chmod 0755 /root/tools/re-fix-elogind-run.sh

if [ "${SESSION_STACK:-}" = "elogind" ] && [ -f /etc/sv/elogind/run ]; then
    [ -e /etc/sv/elogind/run.orig ] || cp /etc/sv/elogind/run /etc/sv/elogind/run.orig
    install -m 0755 /root/tools/elogind.run.fixed /etc/sv/elogind/run
    echo "elogind run script replaced with fixed copy (stock kept at /etc/sv/elogind/run.orig)"
fi

cat > /root/tools/limine-sync.sh << 'INNER_EOF'
#!/bin/bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RESTORE_LIST="void-limine-env.inc:root:0644
void-limine-sync-kernels:root:0755
void-limine-write-conf:root:0755"

for entry in $RESTORE_LIST; do
    src_name="${entry%%:*}"
    rest="${entry#*:}"
    owner="${rest%%:*}"
    mode="${rest##*:}"
    src="$SELF_DIR/$src_name"
    dst="/usr/local/sbin/$src_name"
    if [ ! -e "$dst" ]; then
        if [ -f "$src" ]; then
            install -o "$owner" -g "0" -m "$mode" "$src" "$dst"
            echo "==> restored $dst from backup ($src)"
        else
            echo "ERROR: $dst missing and no backup at $src." >&2
            exit 1
        fi
    fi
done

if [ ! -x /usr/local/sbin/void-limine-sync-kernels ] || \
   [ ! -x /usr/local/sbin/void-limine-write-conf ]; then
    echo "This is not a Limine install (limine helpers still absent); nothing to sync." >&2
    exit 0
fi
[ -d /boot/efi ] || { echo "No /boot/efi mount — aborting limine sync." >&2; exit 1; }

echo "==> [void-limine-sync-kernels]"
/usr/local/sbin/void-limine-sync-kernels
echo "==> [void-limine-write-conf]"
/usr/local/sbin/void-limine-write-conf
echo "==> Limine boot menu regenerated."
INNER_EOF
chmod 0755 /root/tools/limine-sync.sh

cat > /root/tools/re-provision-snapper.sh << 'INNER_EOF'
#!/bin/bash
set -euo pipefail

if ! command -v snapper >/dev/null 2>&1; then
    echo "ERROR: snapper not installed." >&2
    exit 1
fi

if [ ! -f /etc/snapper/configs/root ]; then
    echo "==> creating missing snapper 'root' config..."
    snapper --no-dbus -c root create-config / || \
        { echo "ERROR: could not create snapper root config." >&2; exit 1; }
    mkdir -p /.snapshots
    mount /.snapshots 2>/dev/null || true
    chmod 750 /.snapshots
fi

CFG=/etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="3"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_WEEKLY="10"/TIMELINE_LIMIT_WEEKLY="2"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/g' "$CFG"
sed -i 's/EMPTY_PRE_POST_CLEANUP="false"/EMPTY_PRE_POST_CLEANUP="true"/g' "$CFG"

mkdir -p /etc/snapper/filters
grep -qx 'var/service/*' /etc/snapper/filters/void-runit.txt 2>/dev/null || \
    echo "var/service/*" >> /etc/snapper/filters/void-runit.txt

if [ -x /usr/local/sbin/void-limine-write-conf ] && [ -d /boot/efi ]; then
    mkdir -p /usr/lib/snapper/plugins
    cat > /usr/lib/snapper/plugins/00-void-limine-snapper-sync << 'PLUGIN_EOF'
#!/bin/bash
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
case "${1:-}" in
    create-snapshot-post|delete-snapshot-post)
        /usr/local/sbin/void-limine-write-conf >/dev/null 2>&1
        ;;
esac
exit 0
PLUGIN_EOF
    chmod 0755 /usr/lib/snapper/plugins/00-void-limine-snapper-sync
    echo "==> Limine snapper plugin re-installed."
fi

echo "==> Snapper provisioning OK. Existing snapshots untouched."
INNER_EOF
chmod 0755 /root/tools/re-provision-snapper.sh

cat > /root/tools/void-subvol-tool.sh << 'INNER_EOF'
#!/bin/bash
set -euo pipefail

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

DEVDIR=""     # btrfs filesystem device path (e.g. /dev/mapper/void-root or raw)
FSUUID=""     # btrfs filesystem UUID (for the fstab line)
TOPMNT=""     # temp mountpoint for the top-level tree (subvolid=5)

resolve_dev() {
    local src
    src="$(findmnt -no SOURCE / 2>/dev/null)" || die "cannot resolve mounted root device."
    DEVDIR="${src%%\[*}"
    FSUUID="$(blkid -s UUID -o value "$DEVDIR" 2>/dev/null || \
              findmnt -no UUID / 2>/dev/null || true)"
    [ -n "$DEVDIR" ] || die "empty root device."
    [ -n "$FSUUID" ] || die "cannot resolve btrfs filesystem UUID for $DEVDIR."
}

mount_top() {
    TOPMNT="$(mktemp -d)"
    mount -o noatime,subvolid=5 "$DEVDIR" "$TOPMNT" || {
        rmdir "$TOPMNT"; TOPMNT=""; die "cannot mount top-level tree (subvolid=5) from $DEVDIR."
    }
}
unmount_top() {
    [ -n "$TOPMNT" ] || return 0
    umount "$TOPMNT" 2>/dev/null || true
    rmdir "$TOPMNT" 2>/dev/null || true
    TOPMNT=""
}
trap unmount_top EXIT

norm_subvol() {
    local name="$1"
    name="${name#/}"
    case "$name" in
        @*) ;;
        *)  name="@$name" ;;
    esac
    if [ "$name" = "@steam" ]; then
        echo "@game"
    else
        echo "$name"
    fi
}

declare -A USER_PROFILE_PATH=(
    [@mozilla]="/.config/mozilla"
    [@mozilla-cache]="/.cache/mozilla"
    [@chromium]="/.config/chromium"
    [@vivaldi]="/.config/vivaldi"
    [@falkon]="/.config/falkon"
    [@brave]="/.config/BraveSoftware/Brave-Browser"
    [@thunderbird]="/.thunderbird"
    [@steam]="/.local/share/Steam"
    [@game]="/.local/share/Steam /.local/share/lutris"
    [@containers-user]="/.local/share/containers"
    [@usercache]="/.cache"
    [@virtualbox]="/VirtualBox VMs"
    [@linuxbrew]="/.linuxbrew"
)

declare -A SYS_MOUNT=(
    [@docker]="/var/lib/docker"
    [@containers]="/var/lib/containers"
    [@postgresql]="/var/lib/postgresql"
    [@mariadb]="/var/lib/mysql"
    [@libvirt]="/var/lib/libvirt"
    [@flatpak]="/var/lib/flatpak"
)
declare -A SYS_NODATACOW=(
    [@postgresql]=1
    [@mariadb]=1
    [@libvirt]=1
)
declare -A CLASS_SUBVOLS=(
    [containers]="@docker @containers @containers-user"
    [databases]="@postgresql @mariadb"
    [web]="@mozilla @mozilla-cache @chromium @vivaldi @falkon @brave"
    [mail]="@thunderbird"
    [game]="@game"
    [gaming]="@game"
    [dev]="@linuxbrew"
    [virtualization]="@libvirt @virtualbox"
    [flatpak]="@flatpak"
)
CLASS_LIST="containers databases web mail game dev virtualization flatpak"

declare -A PKG_MAP=(
    [@docker]="docker"
    [@containers]="podman fuse-overlayfs slirp4netns crun catatonit"
    [@containers-user]="podman fuse-overlayfs slirp4netns crun catatonit"
    [@libvirt]="qemu libvirt virt-manager"
    [@virtualbox]="virtualbox-ose virtualbox-ose-dkms"
    [@mozilla]="firefox"
    [@chromium]="chromium"
    [@vivaldi]="vivaldi"
    [@falkon]="falkon"
    [@thunderbird]="thunderbird"
    [@steam]="steam"
    [@game]="steam lutris"
    [@flatpak]="flatpak"
)

install_packages() {
    [ $# -ge 1 ] || return 0
    info "installing package(s): $*"
    xbps-install -Sy "$@" || die "xbps-install failed for: $*"
}

class_packages() {
    local cls="$1" sv pkgs=""
    for sv in ${CLASS_SUBVOLS[$cls]:-}; do
        pkgs="$pkgs ${PKG_MAP[$sv]:-}"
    done
    echo "${pkgs# }"
}

siblings() { btrfs subvolume list -o "$TOPMNT" 2>/dev/null | sed -n 's/.*path \([^ ]*\)$/\1/p'; }

sibling_path() { echo "$TOPMNT/$1"; }

fstab_line() { grep -E "(^|[[:space:]])subvol=$1([[:space:]]|,)" /etc/fstab || true; }
is_mounted() { findmnt -n "$1" >/dev/null 2>&1; }

cmd_list() {
    mount_top
    local found=0
    while IFS= read -r sv; do
        [ -n "$sv" ] || continue
        found=1
        local mnt
        mnt="$(awk -v svpat="subvol=$sv" '$1 ~ /^UUID=/ && $0 ~ svpat {print $2; exit}' /etc/fstab)"
        printf '  %-20s fstab=%s\n' "$sv" "${mnt:-<no fstab>}"
    done < <(siblings)
    [ "$found" = "1" ] || echo "  (no flat siblings found)"
}

cmd_check() {
    [ $# -eq 1 ] || die "usage: void-subvol-tool.sh check <subvol>"
    local sv fst
    sv="$(norm_subvol "$1")"
    mount_top
    if [ -e "$(sibling_path "$sv" )" ]; then
        echo "subvol $sv: PRESENT (top-level sibling; outside Snapper rollback scope)."
    else
        echo "subvol $sv: absent."
    fi
    fst="$(fstab_line "$sv")"
    if [ -n "$fst" ]; then
        echo "fstab: mounted at $(awk '$1 ~ /^UUID=/ && $0 ~ "subvol='"$sv"'([[:space:],])" {print $2}' /etc/fstab | tr '\n' ' ')"
    else
        echo "fstab: no mount entry."
    fi
    mnt="$(awk '{print $2}' <<<"$fst")"
    if [ -n "$mnt" ] && is_mounted "$mnt"; then
        echo "mounted: yes (at $mnt)"
    else
        echo "mounted: no"
    fi
}

region_fs() { # $1=region name -> the fs it was carved to (default btrfs)
    local _v _rfv
    if [ "$1" = "games" ]; then
        _rfv="REGION_GAMES"
    else
        _rfv="REGION_${1^^}_FS"
    fi
    _v=$(sed -n "s/^${_rfv}=//p" /etc/void-installer/install-config 2>/dev/null | tail -1 | tr -d '"')
    [ -n "$_v" ] || _v="btrfs"
    echo "$_v"
}

guard_region_subvol() { # $1=subvol name; dies if its region was carved
    local sv="$1" reg=""
    case "$sv" in
        @home|@usercache|@mozilla|@mozilla-cache|@chromium|@vivaldi|@falkon|@brave|@thunderbird|@game|@containers-user|@linuxbrew|@virtualbox) reg="home" ;;
        @log|@spool|@network|@sddm|@lightdm|@libvirt|@flatpak|@docker|@containers) reg="var" ;;
        @cache) reg="cache" ;;
        @srv)  reg="srv" ;;
        @opt)  reg="opt" ;;
    esac
    if [ -n "$reg" ] && [ "$(region_fs "$reg")" != "btrfs" ]; then
        unmount_top
        die "subvolume '$sv' is owned by the '$reg' data region, which is carved onto its own partition on this machine (REGION_${reg}_FS != btrfs). It cannot be created as a root-Btrfs subvolume — its mountpoint is provided by the region partition. (MULTI-FS-GUARD)"
    fi
}

add_subvol() {
    local sv="$1" mnt="$2" nodatacow="$3" src="$4" install="$5" mode sp pkgs
    pkgs="${PKG_MAP[$sv]:-}"
    guard_region_subvol "$sv"
    mount_top
    sp="$(sibling_path "$sv")"
    [ -e "$sp" ] && { unmount_top; die "sibling '$sv' already exists (delete it first if you mean to recreate)."; }
    if [ "${ADD_MOUNT:-0}" = "1" ]; then
        if [ -e "$sp" ]; then
            info "sibling '$sv' exists — adding another mountpoint (multi-mount)."
        else
            unmount_top; die "sibling '$sv' does not exist yet — create it with a plain 'add' first."
        fi
    else
        [ -e "$sp" ] && { unmount_top; die "sibling '$sv' already exists (delete it first if you mean to recreate)."; }
        [ -z "$(fstab_line "$sv")" ] || { unmount_top; die "subvolume '$sv' already has an fstab entry."; }
    fi
    is_mounted "$mnt" && { unmount_top; die "'$mnt' is already a mountpoint in use."; }

    if [ -z "$src" ] && [ -d "$mnt" ] && [ -n "$(ls -A "$mnt" 2>/dev/null)" ]; then
        unmount_top
        die "target '$mnt' already contains data, but no source-dir was given to migrate it (add $sv $mnt $mnt). Mounting an empty sibling over it would HIDE that data inside @. Provide the source-dir, or empty the target first."
    fi

    mnt="$(readlink -f "$mnt")"

    if [ "${ADD_MOUNT:-0}" != "1" ]; then
        info "creating flat sibling $sv (top-level tree) for $mnt..."
        btrfs subvolume create "$sp" || { unmount_top; die "btrfs subvolume create failed."; }

        if [ -n "$src" ]; then
            [ -d "$src" ] || {
                echo "ERROR: source '$src' not a dir (removing partially-created sibling)." >&2
                btrfs subvolume delete "$sp"
                unmount_top
                exit 1
            }
            info "migrating contents of $src into new sibling..."
            cp -a -- "$src"/. "$sp"/ 2>/dev/null || true
        fi
        unmount_top
    fi

    if [ "$nodatacow" = "1" ]; then
        mode="noatime,nodatacow,compress=none"
        info "mount options: $mode (nodatacow via fstab, per installer [NODATACOW])"
    else
        mode="noatime,compress=zstd:1"
        info "mount options: $mode"
    fi

    local fstab_path="${mnt// /\\040}"
    echo "UUID=$FSUUID $fstab_path btrfs $mode,subvol=$sv 0 0" >> /etc/fstab
    mount "$mnt"
    info "done: $sv mounted at $mnt (flat sibling; outside Snapper rollback scope)."

    if [ "$install" = "1" ] && [ "${ADD_MOUNT:-0}" != "1" ]; then
        if [ -n "$pkgs" ]; then
            install_packages $pkgs
            info "installed package(s) for $sv: $pkgs"
        else
            echo "NOTE: $sv has no xbps package mapping — subvol created/isolated but nothing installed." >&2
            info "if you install its software manually, its data will land on $mnt (isolated)."
        fi
    fi
}

cmd_add() {
    local sv mnt src nodatacow=0 opt sp user="" install=0
    local -a positional=()
    for opt in "$@"; do
        case "$opt" in
            --nodatacow) nodatacow=1 ;;
            --install)   install=1 ;;
            --user)      user="unset-next" ;;
            --user=*)    user="${opt#--user=}" ;;
            --*)         die "unknown option '$opt' (--nodatacow | --install | --user <name>)" ;;
            *)
                if [ "$user" = "unset-next" ]; then
                    user="$opt"
                else
                    positional+=("$opt")
                fi
                ;;
        esac
    done
    [ "$user" = "unset-next" ] && die "--user requires a username (e.g. --user alice)."

    [ "${#positional[@]}" -ge 1 ] || die "usage: void-subvol-tool.sh add <subvol> <mountpoint> [source-dir] [--nodatacow] [--install] [--user <name>]"
    sv="$(norm_subvol "${positional[0]}")"
    mnt="${positional[1]:-}"
    src="${positional[2]:-}"
    [ "${#positional[@]}" -le 3 ] || die "too many positional args (subvol mountpoint [source-dir], plus --user/--nodatacow/--install flags)."

    if [ -z "$mnt" ] && [ -n "$user" ]; then
        local rel="${USER_PROFILE_PATH[$sv]:-}"
        [ -n "$rel" ] || die "no known per-user path for '$sv' — supply an explicit <mountpoint>."
        if [[ "$rel" != *" "* ]]; then
            mnt="/home/$user$rel"
            echo "Derived per-user mountpoint: $mnt"
            read -r -p "Use this mountpoint? [Y/n]: " ans
            case "$ans" in [nN]*) die "aborted." ;; esac
        fi
    fi

    if [ -z "$mnt" ] && [ -z "$user" ]; then
        local rel="${USER_PROFILE_PATH[$sv]:-}"
        if [ -n "$rel" ]; then
            read -r -p "Per-user profile $sv — enter the username to target (e.g. alice): " user
            [ -n "$user" ] || die "no username given."
            if [[ "$rel" != *" "* ]]; then
                mnt="/home/$user$rel"
                echo "Derived per-user mountpoint: $mnt"
                read -r -p "Use this mountpoint? [Y/n]: " ans
                case "$ans" in [nN]*) die "aborted." ;; esac
            fi
        fi
    fi

    [ -n "$mnt" ] || die "no mountpoint — pass one explicitly, or --user <name> (or just the subvol name for a per-user prompt)."
    if [ -d "$mnt" ]; then :; else
        if [ -n "$user" ]; then
            die "mountpoint '$mnt' does not exist — create and chown it to $user first."
        else
            die "mountpoint '$mnt' does not exist."
        fi
    fi

    if [ -n "$user" ] && [ -n "${positional[1]:-}" ]; then
        echo "Note: --user $user given with explicit mountpoint — using '$mnt' as typed."
    fi

    local _sv_relset="${USER_PROFILE_PATH[$sv]:-}"
    if [ -z "${positional[1]:-}" ] && [ -n "$user" ] && [[ "$_sv_relset" == *" "* ]]; then
        local _sv_mnt_rel _sv_first=1
        for _sv_mnt_rel in $_sv_relset; do
            _sv_mnt="/home/$user$_sv_mnt_rel"
            [ -d "$_sv_mnt" ] || die "mountpoint '$_sv_mnt' does not exist — create and chown it to $user first."
            if [ "$_sv_first" = "1" ]; then
                ADD_MOUNT=0 add_subvol "$sv" "$_sv_mnt" "$nodatacow" "$src" "$install"
                _sv_first=0
            else
                ADD_MOUNT=1 add_subvol "$sv" "$_sv_mnt" "$nodatacow" "" "$install"
            fi
        done
        return 0
    fi

    add_subvol "$sv" "$mnt" "$nodatacow" "$src" "$install"
}

cmd_add_class() {
    local cls="" user="" opt install=0
    local -a cls_args=()
    for opt in "$@"; do
        case "$opt" in
            --user)      user="unset-next" ;;
            --user=*)    user="${opt#--user=}" ;;
            --install)   install=1 ;;
            --*)         die "unknown option '$opt' (--user <name> | --install)" ;;
            *)           if [ "$user" = "unset-next" ]; then user="$opt"; else cls_args+=("$opt"); fi ;;
        esac
    done
    [ "$user" = "unset-next" ] && die "--user requires a username (e.g. --user alice)."
    [ "${#cls_args[@]}" -eq 1 ] || die "usage: void-subvol-tool.sh add --class <name> [--user <name>] [--install]  (classes: $CLASS_LIST)"
    cls="${cls_args[0]}"
    local members="${CLASS_SUBVOLS[$cls]:-}"
    [ -n "$members" ] || die "unknown class '$cls' (classes: $CLASS_LIST)."

    info "class '$cls' -> creating: $members"
    if [ "$install" = "1" ]; then
        local cpkgs
        cpkgs="$(class_packages "$cls")"
        if [ -n "$cpkgs" ]; then
            info "class '$cls' --install -> packages: $cpkgs"
        else
            echo "NOTE: class '$cls' has no xbps package mapping — creating subvols only, nothing installed." >&2
        fi
    fi

    local sv has_user=0
    for sv in $members; do
        [ -n "${USER_PROFILE_PATH[$sv]:-}" ] && has_user=1
    done
    if [ "$has_user" = "1" ] && [ -z "$user" ]; then
        read -r -p "Class '$cls' has per-user profile subvol(s) — enter the username to target (e.g. alice): " user
        [ -n "$user" ] || die "no username given for per-user members of class '$cls'."
    fi

    for sv in $members; do
        local mnt ndc
        if [ -n "${USER_PROFILE_PATH[$sv]:-}" ]; then
            [ -n "$user" ] || die "internal: class member '$sv' is per-user but no username resolved."
            for _pbs_rel in ${USER_PROFILE_PATH[$sv]}; do
                mnt="/home/$user$_pbs_rel"
                [ -d "$mnt" ] || die "mountpoint '$mnt' does not exist — create (and for per-user paths chown to $user) first."
                if [ "$_pbs_rel" = "${USER_PROFILE_PATH[$sv]%% *}" ]; then
                    ADD_MOUNT=0 add_subvol "$sv" "$mnt" 0 "" "$install"
                else
                    ADD_MOUNT=1 add_subvol "$sv" "$mnt" 0 "" "$install"
                fi
            done
            unset _pbs_rel
        else
            mnt="${SYS_MOUNT[$sv]:-}"
            [ -n "$mnt" ] || die "internal: no mountpoint mapping for class member '$sv'."
            ndc="${SYS_NODATACOW[$sv]:-0}"
            [ -d "$mnt" ] || die "mountpoint '$mnt' does not exist — create (and for per-user paths chown to $user) first."
            ADD_MOUNT=0 add_subvol "$sv" "$mnt" "$ndc" "" "$install"
        fi
    done
    info "class '$cls' complete."
}

cmd_detach() {
    [ $# -eq 1 ] || die "usage: void-subvol-tool.sh detach <subvol>"
    local sv fst mnt
    sv="$(norm_subvol "$1")"
    fst="$(fstab_line "$sv")"
    [ -n "$fst" ] || die "no fstab entry for '$sv' (nothing to detach)."
    for mnt in $(awk '$1 ~ /^UUID=/ && $0 ~ "subvol='"$sv"'([[:space:],])" {print $2}' /etc/fstab); do
        info "unmounting $mnt..."
        umount "$mnt" 2>/dev/null || true
    done
    sed -i "\~subvol=$sv\([[:space:],]\)~d" /etc/fstab
    info "detached $sv. Subvolume and data remain on disk. Re-attach with:"
    echo "  sudo /root/tools/void-subvol-tool.sh add $sv $mnt"
}

cmd_destroy() {
    [ $# -eq 1 ] || die "usage: void-subvol-tool.sh destroy <subvol>"
    local sv fst mnt sp
    sv="$(norm_subvol "$1")"
    fst="$(fstab_line "$sv")"
    if [ -n "$fst" ]; then
        for mnt in $(awk '$1 ~ /^UUID=/ && $0 ~ "subvol='"$sv"'([[:space:],])" {print $2}' /etc/fstab); do
            info "unmounting $mnt..."
            umount "$mnt" 2>/dev/null || true
        done
        sed -i "\~subvol=$sv\([[:space:],]\)~d" /etc/fstab
    fi
    echo "WARNING: this DELETES subvolume $sv and ALL data it holds. Cannot be undone."
    read -r -p "Type YES to confirm: " ans
    [ "$ans" = "YES" ] || die "aborted."
    mount_top
    sp="$(sibling_path "$sv")"
    [ -e "$sp" ] || die "sibling '$sv' not found in top-level tree."
    btrfs subvolume delete "$sp" >/dev/null
    info "destroyed $sv."
}

[ $# -ge 1 ] || { echo "usage: $0 <verb> [args]  (list|check|add|detach|destroy)" >&2; exit 1; }
verb="$1"; shift
resolve_dev
case "$verb" in
    list)    cmd_list "$@" ;;
    check)   cmd_check "$@" ;;
    add)     if [ "$1" = "--class" ]; then shift; cmd_add_class "$@"; else cmd_add "$@"; fi ;;
    detach)  cmd_detach "$@" ;;
    destroy) cmd_destroy "$@" ;;
    *) die "unknown verb '$verb' (list|check|add|detach|destroy)." ;;
esac
INNER_EOF
chmod 0755 /root/tools/void-subvol-tool.sh

cat > /root/tools/README.md << 'INNER_EOF'

This folder is shipped by the Void Linux Installer (the same project that built
this box) and holds the re-runnable maintenance/recovery scripts. They are
**idempotent** (safe to run more than once). Most are **run-on-demand** — not on
`PATH`, because you invoke them deliberately rather than as background helpers.
One exception: `re-shadow-xbps.sh` is auto-invoked at every boot by
`/etc/rc.local` (the "void-reshadow" boot self-heal), so it is both a boot-time
fixup **and** a tool you can still run by hand to force a recovery without
rebooting.

Run every tool with **`sudo`** (they write to system-owned paths).

---


**What it does:** repairs the "shadow" that makes every `xbps-install` take an
automatic snapper pre/post snapshot pair. The real `/usr/bin/xbps-install` lives
at `/usr/bin/xbps-install.real`, and `/usr/bin/xbps-install` is a symlink to the
wrapper `void-xbps-snap`.

**When to run it yourself:** normally you **don't need to**. Every boot,
`/etc/rc.local` runs this script automatically (see `void-reshadow`), so if an
**`xbps` package self-update** re-places a *real* binary over the symlink —
silently disabling automatic snapshots, a known caveat of binary shadowing —
the shadow is repaired on the next boot before any later update can run
unsnapshotted. Run it manually only if you want to restore the shadow *without
rebooting*, or to confirm updates are still snapshotting (e.g. after a
`sudo xbps-install -Su` no longer prints "before-update snapshot").

**How:**
```bash
sudo /root/tools/re-shadow-xbps.sh
```
It restores the wrapper, re-establishes `/usr/bin/xbps-install.real`, and
re-links `/usr/bin/xbps-install -> void-xbps-snap`. Idempotent — safe to run at
every boot or by hand.

---

**What it does:** re-runs the kernel copy + `void-limine-write-conf` to
regenerate the Limine boot menu (including the `+Snapshots` submenu). If a
live Limine helper under `/usr/local/sbin` is missing, it **first restores it
from the canonical backup kept in this folder**, so this one script can
rebuild the whole menu pipeline even after `/usr/local/sbin` was wiped.

**When to use it:** the kernel hook and the snapper plugin normally do this
automatically. Reach for this if you manually changed `/boot/efi/void-kernel/`
or `/.snapshots/`, or if the snapshot menu looks stale and you want to force a
rebuild without waiting for a kernel/snapshot event — **or** if the
`/usr/local/sbin/void-limine-*` helpers were lost and you need to regenerate
them from backup.

**How:**
```bash
sudo /root/tools/limine-sync.sh
```
On a GRUB install it is a harmless no-op (prints a notice). It needs `/boot/efi`
mounted.

---

Canonical pristine copies of the live Limine menu engines that `/usr/local/sbin`
uses. They are not meant to be run from here (their live home is
`/usr/local/sbin`, on `PATH`/sourced by the generator); they are the fallback
that `limine-sync.sh` restores from if the live copies are lost or damaged.
Without these, a broken `/usr/local/sbin` Limine stack was only fixable by a
full reinstall — now `sudo /root/tools/limine-sync.sh` can rebuild it.

---

**What it does:** recreates a *missing* snapper `root` config, re-applies the
installer's retention/timeline tuning and the runit filter, and (on Limine)
re-installs the `00-void-limine-snapper-sync` plugin that keeps the snapshot
boot menu fresh.

**When to use it:** if `/etc/snapper/configs/root` was deleted or corrupted, if
the snapshot menu plugin stopped firing, or if you want to re-apply tuning after
editing it by hand.

**How:**
```bash
sudo /root/tools/re-provision-snapper.sh
```
It is **deliberately non-destructive**: it will only *create* a missing config
and *tune* an existing one. It will **never** delete or touch your existing
snapshots. It does not run the destructive "reconcile" step from the original
install (which would have wiped snapshots).

---

Not a separate tool; this is a pristine copy of the `/usr/local/sbin/void-xbps-snap`
wrapper that `re-shadow-xbps.sh` restores from. You normally never run it
directly here — it lives on `PATH` via `/usr/local/sbin` already. Its job: when
run as `xbps-install`, it snapshots the root filesystem (snapper pre, then post)
around a mutating package operation so every update is rollback-able.

**When to use it:** only manually if you want an explicit, single-shot
snapshotted operation (it is the same engine the shadow uses):
```bash
sudo /root/tools/void-xbps-snap -S <pkg>
```

---

**What it does:** manages the installer's *flat* Btrfs subvolume topology after
the fact. It creates, checks, detaches, or destroys a **top-level sibling**
subvolume (never nested inside `@`), so anything you add is automatically
outside Snapper rollback scope — the same property as `@home`, `@opt`, etc.
It is **purely structural**: it never installs software, so you can create
`@steam`, `@postgresql`, `@containers`, etc. ahead of installing that software
manually, or wall off an existing directory.

**When to use it:** you want the profile/data of an app on its own
rollback-excluded subvolume but don't want (or already have) the app — e.g.
creating `@postgresql` before installing PostgreSQL, or turning an existing
`/var/lib/app` into its own subvol later. It mirrors the installer's own
flat-topology and nodatacow-via-fstab conventions.

**How:**
```bash
sudo /root/tools/void-subvol-tool.sh list
sudo /root/tools/void-subvol-tool.sh add @steam /home/USER/.local/share/Steam
sudo /root/tools/void-subvol-tool.sh add @postgresql /var/lib/postgresql --nodatacow
sudo /root/tools/void-subvol-tool.sh add @app /var/lib/app /var/lib/app   # migrate existing data + wall it off
sudo /root/tools/void-subvol-tool.sh check @app
sudo /root/tools/void-subvol-tool.sh detach @app        # umount + drop fstab (data preserved)
sudo /root/tools/void-subvol-tool.sh destroy @app       # full delete, asks for confirmation
```
Per-user profile subvolumes (browser profiles, `@game`, `@thunderbird`,
`@containers-user`, `@usercache`, ...) live under `/home/<user>`, so the tool
can derive the exact mountpoint from the username instead of you typing the
whole path. Use `--user <name>`, or just the subvol name and it will **prompt**
for the username:
```bash
sudo /root/tools/void-subvol-tool.sh add @chromium --user alice      # -> /home/alice/.config/chromium
sudo /root/tools/void-subvol-tool.sh add @containers-user --user alice   # -> /home/alice/.local/share/containers
sudo /root/tools/void-subvol-tool.sh add @steam                     # prompts "enter the username..."
sudo /root/tools/void-subvol-tool.sh add @game --user alice         # mounts at the FULL derived set (.local/share/Steam, .local/share/lutris)
```
Important: as at install (`[PERSONAL-DATA]`/`provision_browser_subvol`), the
per-user parents must already exist and be owned by the target user. Create and
`chown` the chain **before** the tool call, or run the migrate form
(`add @x /home/user/... /home/user/...`) so any pre-existing data is copied in
with ownership preserved. The tool creates the sibling and fstab line only — it
never chowns/remakes your home.

It refuses to double-create or double-mount. The one exception is `@game`,
whose `--add-mount` path intentionally relaxes the fstab-guard so a second
launcher's datadir can be added to the same sibling (`--add-mount` skips the
"already has an fstab entry" die; without it the tool refuses, so a plain
`add @game` on an already-mounted @game still refuses). `destroy` requires
typing `YES`. `nodatacow` is applied via the fstab mount option (never
`chattr +C`), matching the installer's `[NODATACOW]` rule that `chattr` on a
subvolume root is shadowed by the mount.

**Data-safety guard (`[SUBVOL-DATA-GUARD]`):** if the target mountpoint is
already non-empty (e.g. the software was installed *before* you built its
subvol, so its data sits inside `@`), the tool **refuses to proceed** unless you
supply the migrate form — `add <sv> <mnt> <mnt>` copies that existing data onto
the fresh sibling *before* it is mounted, so nothing is lost. Mounting an empty
sibling over a populated directory would HIDE the pre-existing data (it stays on
disk inside `@` but becomes inaccessible behind the mount). Provide the
source-dir to migrate, or empty the target first.

**Create every subvol for an optional-software family in one pass** with
`add --class <name>`. The tool resolves each member's mountpoint (system paths
from an internal map, per-user profiles under `/home/<user>`) and creates them
all — idempotently (already-created siblings are skipped by the existing-sibling
guard). By default it never installs or checks for the software, so the siblings
get created even on a lean system with none of it installed:
```bash
sudo /root/tools/void-subvol-tool.sh add --class containers --user alice
sudo /root/tools/void-subvol-tool.sh add --class databases          # @postgresql + @mariadb (nodatacow)
sudo /root/tools/void-subvol-tool.sh add --class web --user alice   # all browser profiles
sudo /root/tools/void-subvol-tool.sh add --class mail --user alice  # @thunderbird
sudo /root/tools/void-subvol-tool.sh add --class gaming --user alice# @game (multi-mount: Steam + lutris datadirs)
sudo /root/tools/void-subvol-tool.sh add --class dev --user alice    # @linuxbrew (Homebrew CLI/dev prefix)
sudo /root/tools/void-subvol-tool.sh add --class virtualization --user alice  # @libvirt + @virtualbox
sudo /root/tools/void-subvol-tool.sh add --class flatpak            # @flatpak
```

**Install the software at the same time** with `--install` (on a single `add` or
an `add --class`). After the subvol is created and mounted at its runtime path,
the tool runs `xbps-install -Sy` for the owning package(s) (see `PKG_MAP`), so
the software's data lands on the isolated subvolume from the very first run —
mirroring the installer's own provisioning:
```bash
sudo /root/tools/void-subvol-tool.sh add @steam --user alice --install   # create + install steam
sudo /root/tools/void-subvol-tool.sh add --class game --user alice --install
sudo /root/tools/void-subvol-tool.sh add --class virtualization --install # @libvirt + @virtualbox + their packages
```
Only subvols with an xbps package mapping install something. Subvols with no
Void package are still created/isolated but nothing is installed: `@postgresql`
and `@mariadb` (manual/pre-create targets, never auto-installed),
`@mozilla-cache` (installs with `@mozilla`), `@usercache` (cache dir only),
`@linuxbrew` (Homebrew's ~/.linuxbrew prefix, created on first login by the
vendor's own installer — structural-only, its runtime deps git/curl/file/procps-ng
are installed at install time), and
`@brave` (no official Void package — it is Flatpak-only, and this tool is
xbps-based by design). `@docker`/`@containers`/`@containers-user`/`@libvirt`/
`@virtualbox`/`@mozilla`/`@chromium`/`@vivaldi`/`@falkon`/`@thunderbird`/
`@steam`/`@flatpak` all map to their real packages. `--install` needs network
access and root, like any `xbps-install`.

Classes and their subvolumes:

| class | subvolumes |
|---|---|
| `containers` | `@docker`, `@containers`, `@containers-user` |
| `databases` | `@postgresql`, `@mariadb` (both nodatacow) |
| `web` | `@mozilla`, `@mozilla-cache`, `@chromium`, `@vivaldi`, `@falkon`, `@brave` |
| `mail` | `@thunderbird` |
| `game` | `@game` (multi-mount: `.local/share/Steam`, `.local/share/lutris`; `gaming` is a back-compat alias) |
| `virtualization` | `@libvirt` (nodatacow), `@virtualbox` |
| `flatpak` | `@flatpak` |

Class members are per-user profiles (every subvol whose name is `@`-prefixed
under a `/home` root — browser profiles, `@game`, `@thunderbird`,
`@containers-user`, `@virtualbox`) only when they use a per-user mountpoint.
Pass `--user <name>` to target all per-user members at once; if the class has
per-user members and you omit `--user`, the tool prompts once for the shared
username. System-path members (`@postgresql`, `@mariadb`, `@libvirt`,
`@flatpak`, `@docker`, `@containers`) need no username. `@grub` and `@swap` are
excluded — they are bootloader/swapfile-context-dependent and the tool cannot
infer them from a class name.

---

- All tools assume the installer-provisioned layout (btrfs root, a snapper
  `root` config, and — for the Limine tools — Limine as the bootloader).
- The authoritative, up-to-date copy of these tools + this README lives in the
  installer itself; this folder is the deployable/on-box copy for later reuse.
INNER_EOF
chmod 0644 /root/tools/README.md
echo "/root/tools maintenance folder complete (void-xbps-snap backup, 3 limine-engine backups, re-shadow-xbps.sh, limine-sync.sh, re-provision-snapper.sh, void-subvol-tool.sh, README.md)"


mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/fstrim-discard << 'INNER_EOF'
#!/bin/sh
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"
if command -v fstrim >/dev/null 2>&1; then
    exec fstrim -A --quiet
else
    echo "ERROR: fstrim binary missing from the system path." >&2
    exit 1
fi
INNER_EOF
chmod +x /etc/cron.weekly/fstrim-discard

mkdir -p /etc/cron.monthly
cat > /etc/cron.monthly/btrfs-scrub << 'INNER_EOF'
#!/bin/sh
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LOG="/var/log/btrfs-scrub.log"

if ! command -v btrfs >/dev/null 2>&1; then
    echo "ERROR: btrfs binary missing from the system path." >&2
    exit 1
fi

_fslist="$(
    awk '
        { for (i = 1; i <= NF; i++) if ($i == "-") { sep = i; break } }
        $(sep+1) == "btrfs" { print $3 " " $5 }
    ' /proc/self/mountinfo 2>/dev/null | sort -k1,1 -u
)"
[ -n "$_fslist" ] || exit 0

{
    echo "=== btrfs scrub run: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
    printf '%s\n' "$_fslist" | while read -r _devno _mnt; do
        btrfs scrub start -B -d "$_mnt" 2>&1
        _rc=$?
        echo "scrub $_mnt (dev $_devno): exit $_rc"
    done
} >> "$LOG" 2>&1

exit 0
INNER_EOF
chmod +x /etc/cron.monthly/btrfs-scrub

mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/90-system.conf << INNER_EOF
add_dracutmodules+=" btrfs resume snapshot-overlay udev-rules "
filesystems+=" btrfs "
install_items+=" /usr/bin/btrfs /usr/sbin/blkid "
INNER_EOF
if [ "$ENCRYPT" = "yes" ]; then
    echo 'add_dracutmodules+=" crypt "' >> /etc/dracut.conf.d/90-system.conf
    echo 'add_dracutmodules+=" i18n "' >> /etc/dracut.conf.d/90-system.conf
    echo "kernel_cmdline=\"rd.vconsole.keymap=${KEYMAP_LIVE:-us}\"" >> /etc/dracut.conf.d/90-system.conf
fi

if [ "$YK_MODE" = "hmac-sha1" ]; then
    mkdir -p /usr/lib/dracut/modules.d/99void-yubikey
    cat > /usr/lib/dracut/modules.d/99void-yubikey/module-setup.sh << 'INNER_EOF'
#!/bin/bash

check() {
    require_binaries ykchalresp || return 1
    return 0
}

depends() {
    echo base
    return 0
}

install() {
    inst /usr/local/sbin/void-reveal-yubikey-key /usr/local/sbin/void-reveal-yubikey-key
    inst_binary ykchalresp /usr/bin/ykchalresp
    inst_libdir_file "libusb-*.so*" "libusb-*.so.*"
    inst_script "$moddir/cryptroot-ask.sh" /sbin/cryptroot-ask
}
INNER_EOF
    cat > /usr/lib/dracut/modules.d/99void-yubikey/cryptroot-ask.sh << 'INNER_EOF'
#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
NEWROOT=${NEWROOT:-"/sysroot"}

[ -f "$NEWROOT"/proc ] && exit 0

. /lib/dracut-lib.sh

[ -d /run/cryptsetup ] || mkdir -m 0700 /run/cryptsetup

if [ "${1##/dev/dm-}" != "$1" ]; then
    device="/dev/mapper/$(dmsetup info -c --noheadings -o name "$1")"
else
    device="$1"
fi

luksname=$2

is_keysource=${3:-0}

numtries=${4:-10}

if [ -f /etc/crypttab ] && getargbool 1 rd.luks.crypttab -d -n rd_NO_CRYPTTAB; then
    while read -r name dev luksfile luksoptions || [ -n "$name" ]; do
        if [ -z "$name" ] || [ "${name#\#}" != "$name" ]; then
            continue
        fi

        if [ "${dev%%=*}" = "PARTUUID" ]; then
            if [ "luks-${dev##PARTUUID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi
        elif [ "${dev%%=*}" = "UUID" ]; then
            if [ "luks-${dev##UUID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi
        elif [ "${dev%%=*}" = "ID" ]; then
            if [ "luks-${dev##ID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi
        else
            cdev=$(readlink -f "$dev")
            mdev=$(readlink -f "$device")
            if [ "$cdev" = "$mdev" ]; then
                luksname="$name"
                break
            fi
        fi
    done < /etc/crypttab
    unset name dev
fi

[ -b /dev/mapper/"$luksname" ] && exit 0
asked_file=/tmp/cryptroot-asked-$luksname
[ -f "$asked_file" ] && exit 0

[ -d /sys/module/dm_crypt ] || modprobe dm_crypt

. /lib/dracut-crypt-lib.sh

info "luksOpen $device $luksname $luksfile $luksoptions"

OLD_IFS="$IFS"
IFS=,
set -- $luksoptions
IFS="$OLD_IFS"

cryptsetupopts=""
allowdiscards=""
keyscript=""

while [ $# -gt 0 ]; do
    case $1 in
        noauto)
            exit 0
            ;;
        swap)
            exit 0
            ;;
        tmp)
            exit 0
            ;;
        allow-discards)
            allowdiscards="--allow-discards"
            ;;
        header=*)
            cryptsetupopts="${cryptsetupopts} --${1}"
            ;;
        keyscript=*)
            keyscript="${1#keyscript=}"
            ;;
    esac
    shift
done

if strstr "$(cryptsetup --help)" "allow-discards"; then
    if discarduuids=$(getargs "rd.luks.allow-discards"); then
        discarduuids=$(str_replace "$discarduuids" 'luks-' '')
        if strstr " $discarduuids " " ${luksdev##luks-}"; then
            allowdiscards="--allow-discards"
        fi
    elif getargbool 0 rd.luks.allow-discards; then
        allowdiscards="--allow-discards"
    fi
fi

if strstr "$(cryptsetup --help)" "allow-discards"; then
    cryptsetupopts="$cryptsetupopts $allowdiscards"
fi

unset allowdiscards

ask_passphrase=1

if [ -n "$keyscript" ] && [ -x "$keyscript" ]; then
    _keyscript_tries=${YTries:-10}
    while [ "$_keyscript_tries" -gt 0 ]; do
        if "$keyscript" | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname"; then
            ask_passphrase=0
            break
        fi
        _keyscript_tries=$((_keyscript_tries - 1))
        [ -b /dev/mapper/"$luksname" ] && break
        sleep 1
    done
    unset _keyscript_tries
elif [ -n "$luksfile" ] && [ "$luksfile" != "none" ] && [ -e "$luksfile" ]; then
    if readkey "$luksfile" / "$device" \
        | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname"; then
        ask_passphrase=0
    fi
elif [ "$is_keysource" -ne 0 ]; then
    info "Asking for passphrase because $device is a keysource."
else
    while [ -n "$(getarg rd.luks.key)" ]; do
        if tmp=$(getkey /tmp/luks.keys "$device"); then
            keydev="${tmp%%:*}"
            keypath="${tmp#*:}"
        else
            if [ "$numtries" -eq 0 ]; then
                warn "No key found for $device.  Fallback to passphrase mode."
                break
            fi
            sleep 1
            info "No key found for $device.  Will try $numtries time(s) more later."
            initqueue --unique --onetime --settled \
                --name cryptroot-ask-"$luksname" \
                "$(command -v cryptroot-ask)" "$device" "$luksname" "$is_keysource" "$((numtries - 1))"
            exit 0
        fi
        unset tmp

        info "Using '$keypath' on '$keydev'"
        readkey "$keypath" "$keydev" "$device" \
            | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname" \
            && ask_passphrase=0
        unset keypath keydev
        break
    done
fi

if [ $ask_passphrase -ne 0 ]; then
    luks_open="$(command -v cryptsetup) $cryptsetupopts luksOpen"
    _timeout=$(getargs "rd.luks.timeout")
    _timeout=${_timeout:-0}
    ask_for_password --ply-tries 5 \
        --ply-cmd "$luks_open -T1 $device $luksname" \
        --ply-prompt "Password ($device)" \
        --tty-tries 1 \
        --tty-cmd "$luks_open -T5 -t $_timeout $device $luksname"
    unset luks_open
    unset _timeout
fi

if [ "$is_keysource" -ne 0 ] && [ "${luksname##luks-}" != "$luksname" ]; then
    luks_close="$(command -v cryptsetup) close"
    {
        printf -- '[ -e /dev/mapper/%s ] && ' "$luksname"
        printf -- '%s "%s"\n' "$luks_close" "$luksname"
    } >> "$hookdir/cleanup/31-crypt-keysource.sh"
    unset luks_close
fi

unset device luksname luksfile

: >> "$asked_file"

need_shutdown
udevsettle

exit 0
INNER_EOF
    chmod 0755 /usr/lib/dracut/modules.d/99void-yubikey/cryptroot-ask.sh
    chmod 0755 /usr/lib/dracut/modules.d/99void-yubikey/module-setup.sh
    echo 'add_dracutmodules+=" void-yubikey "' >> /etc/dracut.conf.d/90-system.conf
fi

mkdir -p /usr/lib/dracut/modules.d/95snapshot-overlay
cat > /usr/lib/dracut/modules.d/95snapshot-overlay/module-setup.sh << 'INNER_EOF'
#!/bin/bash

check() {
    require_binaries btrfs || return 1
    return 0
}

depends() {
    echo base btrfs
    return 0
}

installkernel() {
    hostonly="" instmods overlay
}

install() {
    inst_hook pre-pivot 20 "$moddir/mount-snapshot-overlay.sh"
}
INNER_EOF

cat > /usr/lib/dracut/modules.d/95snapshot-overlay/mount-snapshot-overlay.sh << 'INNER_EOF'
#!/bin/sh

command -v getarg > /dev/null || . /lib/dracut-lib.sh

if getargbool 0 rd.live.overlay.overlayfs; then
    if command -v btrfs > /dev/null 2>&1; then
        ro_state=$(btrfs property get "$NEWROOT" ro 2>/dev/null)
        if [ "$ro_state" = "ro=true" ]; then
            info "snapshot-overlay: read-only snapshot detected at $NEWROOT, building RAM overlay"
            mkdir -m 0755 /run/rootfsbase
            if mount --bind "$NEWROOT" /run/rootfsbase; then
                mkdir -m 0755 /run/overlayfs /run/ovlwork
                if ! mount -t overlay overlay \
                    -o lowerdir=/run/rootfsbase,upperdir=/run/overlayfs,workdir=/run/ovlwork \
                    "$NEWROOT"; then
                    warn "snapshot-overlay: overlay mount failed, booting read-only"
                    umount /run/rootfsbase
                fi
            else
                warn "snapshot-overlay: failed to bind-mount $NEWROOT, booting read-only"
            fi
        fi
    else
        warn "snapshot-overlay: btrfs binary not found in initramfs, skipping overlay"
    fi
fi
INNER_EOF
chmod 0755 /usr/lib/dracut/modules.d/95snapshot-overlay/module-setup.sh
chmod 0755 /usr/lib/dracut/modules.d/95snapshot-overlay/mount-snapshot-overlay.sh

if [ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ]; then
    mkdir -p /usr/lib/dracut/modules.d/98void-inner-partscan

    cat > /usr/lib/dracut/modules.d/98void-inner-partscan/module-setup.sh << 'INNER_EOF'
#!/bin/bash

check() {
    require_binaries kpartx || return 1
    require_binaries partprobe || return 1
    return 0
}

depends() {
    echo crypt udev-rules
    return 0
}

install() {
    inst_binary kpartx
    inst_binary partprobe
    inst_binary partx
    inst_script "$moddir/void-inner-partscan.sh" /usr/bin/void-inner-partscan.sh
    inst_rules "$moddir/10-void-inner-partscan.rules"
}
INNER_EOF

    cat > /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh << 'INNER_EOF'
#!/bin/sh
_dev="${1:-${DEVNAME:-/dev/mapper/__CRYPT_NAME__}}"

[ -b "$_dev" ] || exit 0

if command -v kpartx > /dev/null 2>&1; then
    kpartx -a "$_dev" 2> /dev/null || partprobe "$_dev" 2> /dev/null || partx -a "$_dev" 2> /dev/null || true
elif command -v partprobe > /dev/null 2>&1; then
    partprobe "$_dev" 2> /dev/null || partx -a "$_dev" 2> /dev/null || true
else
    partx -a "$_dev" 2> /dev/null || true
fi
unset _dev
exit 0
INNER_EOF

    cat > /usr/lib/dracut/modules.d/98void-inner-partscan/10-void-inner-partscan.rules << 'INNER_EOF'
ACTION=="add", SUBSYSTEM=="block", KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__", RUN+="/usr/bin/void-inner-partscan.sh"
INNER_EOF

    chmod 0755 /usr/lib/dracut/modules.d/98void-inner-partscan/module-setup.sh
    chmod 0755 /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh

    cp -f /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh /usr/bin/void-inner-partscan.sh
    chmod 0755 /usr/bin/void-inner-partscan.sh

    _cn_esc=$(printf '%s' "$CRYPT_NAME" | sed 's/[&/\\]/\\&/g')
    sed -i "s/__CRYPT_NAME__/$_cn_esc/g" \
        /usr/lib/dracut/modules.d/98void-inner-partscan/10-void-inner-partscan.rules
    unset _cn_esc

    echo 'add_dracutmodules+=" void-inner-partscan "' >> /etc/dracut.conf.d/90-system.conf
fi

if [ "$DISPLAY_MANAGER" = "sddm" ]; then
cat > /etc/sv/sddm/conf << 'INNER_EOF'
for i in $(seq 1 10); do
    if [ -d /run/initramfs ] || [ -f /var/log/firstboot.log ]; then
        break
    fi
    sleep 1
done
INNER_EOF
fi

if [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    mkdir -p /etc/greetd
    cat > /etc/greetd/cosmic-greeter.start << 'INNER_EOF'
#!/bin/sh
exec dbus-run-session -- cosmic-comp cosmic-greeter >> /var/log/cosmic-greeter-session.log 2>&1
INNER_EOF
    chmod 0755 /etc/greetd/cosmic-greeter.start
    install -o cosmic-greeter -g cosmic-greeter -m 0644 /dev/null /var/log/cosmic-greeter-session.log
    cat > /etc/greetd/cosmic-greeter.toml << 'INNER_EOF'
[terminal]
vt = "1"

[general]
service = "cosmic-greeter"

[default_session]
command = "/etc/greetd/cosmic-greeter.start"
user = "cosmic-greeter"
INNER_EOF
    chmod 0644 /etc/greetd/cosmic-greeter.toml
    mkdir -p /etc/sv/cosmic-greeter/log
    cat > /etc/sv/cosmic-greeter/run << 'INNER_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
sv check cosmic-greeter-daemon >/dev/null || exit 1
sv check elogind >/dev/null || exit 1
exec greetd -c /etc/greetd/cosmic-greeter.toml
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter/run
    install -d -m0750 -o root -g root /var/log/cosmic-greeter
    cat > /etc/sv/cosmic-greeter/log/run << 'INNER_EOF'
#!/bin/sh
exec svlogd -tt /var/log/cosmic-greeter
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter/log/run
    mkdir -p /etc/sv/cosmic-greeter-daemon/log
    cat > /etc/sv/cosmic-greeter-daemon/run << 'INNER_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
install -d -m0755 -o cosmic-greeter -g cosmic-greeter /run/cosmic-greeter
exec cosmic-greeter-daemon
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter-daemon/run
    install -d -m0750 -o root -g root /var/log/cosmic-greeter-daemon
    cat > /etc/sv/cosmic-greeter-daemon/log/run << 'INNER_EOF'
#!/bin/sh
exec svlogd -tt /var/log/cosmic-greeter-daemon
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter-daemon/log/run
    echo "WARNING: cosmic-greeter was chosen as the display manager. Selecting it is your" >&2
    echo "         explicit at-own-risk choice of a third-party-repo greeter; rc.local links" >&2
    echo "         both the greetd-hosted cosmic-greeter and cosmic-greeter-daemon services." >&2
fi

mkdir -p /etc/sv/udisksd/log /var/log/udisksd
cat > /etc/sv/udisksd/run << 'INNER_EOF'
#!/bin/sh
exec 2>&1
exec /usr/libexec/udisks2/udisksd
INNER_EOF
chmod 0755 /etc/sv/udisksd/run
cat > /etc/sv/udisksd/log/run << 'INNER_EOF'
#!/bin/sh
exec svlogd -tt /var/log/udisksd
INNER_EOF
chmod 0755 /etc/sv/udisksd/log/run

cat > /etc/rc.local << 'INNER_EOF'
#!/bin/sh
if command -v vkpurge >/dev/null 2>&1; then
    echo "==> Runtime Maintenance: Sweeping unreferenced kernel artifacts..."
    vkpurge rm all >/dev/null 2>&1
fi

if ! grep -q 'rd.live.overlay.overlayfs=1' /proc/cmdline 2>/dev/null; then
    case " __REGION_PARTITIONED__ " in
        *" home "*) : ;;
        *) mountpoint -q "/home/__TARGET_USER__/.cache" || mount "/home/__TARGET_USER__/.cache" 2>/dev/null || true ;;
    esac
fi

if [ -x /root/tools/re-shadow-xbps.sh ]; then
    { echo "=== void-reshadow: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
      /root/tools/re-shadow-xbps.sh || echo "WARNING: re-shadow failed."
    } >> /var/log/void-reshadow.log 2>&1
fi

if [ "__SESSION_STACK__" = "elogind" ] && [ -x /root/tools/re-fix-elogind-run.sh ]; then
    { echo "=== void-elogind-selfheal: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
      /root/tools/re-fix-elogind-run.sh || echo "WARNING: elogind run self-heal failed."
    } >> /var/log/void-elogind-selfheal.log 2>&1
fi

if [ ! -f /var/log/firstboot.log ]; then
    mkdir -p /etc/runit/runsvdir/default
    ln -sfn /etc/sv/dbus /etc/runit/runsvdir/default/dbus
    ln -sfn /etc/sv/nftables /etc/runit/runsvdir/default/nftables
    [ "__INSTALL_SSH_SERVER__" = "true" ] && ln -sfn /etc/sv/sshd /etc/runit/runsvdir/default/sshd
    [ "__DISPLAY_MANAGER__" != "none" ] && ln -sfn /etc/sv/__DISPLAY_MANAGER__ /etc/runit/runsvdir/default/__DISPLAY_MANAGER__
    [ "__DISPLAY_MANAGER__" = "cosmic-greeter" ] && \
        ln -sfn /etc/sv/cosmic-greeter-daemon /etc/runit/runsvdir/default/cosmic-greeter-daemon
    [ "__DISPLAY_MANAGER__" = "cosmic-greeter" ] && \
        rm -f /etc/runit/runsvdir/default/agetty-tty1
    ln -sfn /etc/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager
    ln -sfn /etc/sv/chronyd /etc/runit/runsvdir/default/chronyd
    ln -sfn /etc/sv/cronie /etc/runit/runsvdir/default/cronie
    ln -sfn /etc/sv/snapperd /etc/runit/runsvdir/default/snapperd
    [ "__BOOTLOADER__" = "grub" ] && ln -sfn /etc/sv/grub-btrfs /etc/runit/runsvdir/default/grub-btrfs
    if [ "__INSTALL_VIRT__" = "true" ]; then
        ln -sfn /etc/sv/libvirtd /etc/runit/runsvdir/default/libvirtd
        ln -sfn /etc/sv/virtlogd /etc/runit/runsvdir/default/virtlogd
    fi
    [ "__INSTALL_DOCKER__" = "true" ] && ln -sfn /etc/sv/docker /etc/runit/runsvdir/default/docker
    [ "__INSTALL_VIRTUALBOX__" = "true" ] && [ -d /etc/sv/vboxdrv ] && \
        ln -sfn /etc/sv/vboxdrv /etc/runit/runsvdir/default/vboxdrv
    [ "__PROFILE_BT__" = "true" ] && ln -sfn /etc/sv/bluetoothd /etc/runit/runsvdir/default/bluetoothd
    [ "__PROFILE_TLP__" = "true" ] && ln -sfn /etc/sv/tlp /etc/runit/runsvdir/default/tlp
    [ "__POWER_PPD__" = "true" ] && ln -sfn /etc/sv/power-profiles-daemon /etc/runit/runsvdir/default/power-profiles-daemon
    [ "__PROFILE_PRELOAD__" = "true" ] && ln -sfn /etc/sv/preload /etc/runit/runsvdir/default/preload
    if [ "__SESSION_STACK__" = "turnstile" ]; then
        ln -sfn /etc/sv/turnstiled /etc/runit/runsvdir/default/turnstiled
        ln -sfn /etc/sv/seatd /etc/runit/runsvdir/default/seatd
        ln -sfn /etc/sv/acpid /etc/runit/runsvdir/default/acpid
    fi
    [ "__DISPLAY_MANAGER__" = "lightdm" ] || [ "__DISPLAY_MANAGER__" = "cosmic-greeter" ] && \
        [ -d /etc/sv/accounts-daemon ] && \
        ln -sfn /etc/sv/accounts-daemon /etc/runit/runsvdir/default/accounts-daemon
    [ "__SESSION_STACK__" = "elogind" ] && \
        ln -sfn /etc/sv/elogind /etc/runit/runsvdir/default/elogind
    ln -sfn /etc/sv/polkitd /etc/runit/runsvdir/default/polkitd
    ln -sfn /etc/sv/udisksd /etc/runit/runsvdir/default/udisksd
    [ "__SWAP_BACKEND__" = "zram" ] || [ "__SWAP_BACKEND__" = "both" ] && \
        ln -sfn /etc/sv/zramen /etc/runit/runsvdir/default/zramen
    for i in $(seq 1 15); do
        if [ -S /run/dbus/system_bus_socket ]; then
            break
        fi
        sleep 1
    done

    if [ "__INSTALL_VIRT__" = "true" ] && [ -f /etc/NetworkManager/system-connections/br0.nmconnection ]; then
        for i in $(seq 1 15); do
            if [ -S /run/libvirt/libvirt-sock ]; then
                break
            fi
            sleep 1
        done
        if command -v virsh >/dev/null 2>&1; then
            virsh net-destroy default >/dev/null 2>&1 || true
            virsh net-autostart default --disable >/dev/null 2>&1 || true
        fi
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
        flatpak remote-modify --enable flathub 2>/dev/null || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q
    fi
    mkdir -p /var/log
    touch /var/log/firstboot.log
fi
INNER_EOF

sed -i \
    -e "s/__TARGET_USER__/${TARGET_USER}/g" \
    -e "s/__BOOTLOADER__/${BOOTLOADER}/g" \
    -e "s/__INSTALL_VIRT__/${INSTALL_VIRT}/g" \
    -e "s/__INSTALL_DOCKER__/${INSTALL_DOCKER}/g" \
    -e "s/__INSTALL_VIRTUALBOX__/${INSTALL_VIRTUALBOX}/g" \
    -e "s/__INSTALL_SSH_SERVER__/${INSTALL_SSH_SERVER}/g" \
    -e "s/__DISPLAY_MANAGER__/${DM_SERVICE_NAME}/g" \
    -e "s/__SESSION_STACK__/${SESSION_STACK}/g" \
    -e "s/__SWAP_BACKEND__/${SWAP_BACKEND}/g" \
    -e "s/__REGION_PARTITIONED__/${REGION_PARTITIONED}/g" \
    -e "s/__PROFILE_BT__/${PROFILE_BT}/g" \
    -e "s/__PROFILE_TLP__/${PROFILE_TLP}/g" \
    -e "s/__POWER_PPD__/${POWER_PPD}/g" \
    -e "s/__PROFILE_PRELOAD__/${PROFILE_PRELOAD}/g" \
    /etc/rc.local
chmod +x /etc/rc.local

xbps-reconfigure -f $KERNEL_PKGS

for kver_dir in /lib/modules/*; do
    kver="$(basename "$kver_dir")"
    dracut --force "/boot/initramfs-${kver}.img" "$kver"
done

if [ "$ENCRYPT" = "yes" ]; then
    _gate_fail=0
    for kver_gate in /boot/*.img; do
        [ -f "$kver_gate" ] || continue
        _img="$kver_gate"
        if command -v lsinitrd > /dev/null 2>&1; then
            lsinitrd "$_img" 2> /dev/null | grep -c 'bin/cryptsetup' > /dev/null || _gate_fail=1
            if [ -d /usr/lib/dracut/modules.d/98void-inner-partscan ]; then
                lsinitrd "$_img" 2> /dev/null | grep -c 'kpartx' > /dev/null || _gate_fail=1
                lsinitrd "$_img" 2> /dev/null | grep -c 'partprobe' > /dev/null || _gate_fail=1
                lsinitrd "$_img" 2> /dev/null | grep -c 'void-inner-partscan.sh' > /dev/null || _gate_fail=1
                lsinitrd "$_img" 2> /dev/null | grep -c '10-void-inner-partscan.rules' > /dev/null || _gate_fail=1
            fi
        else
            echo "FATAL: lsinitrd not available in chroot; cannot verify initramfs content." >&2
            _gate_fail=1
        fi
        [ "$_gate_fail" -eq 1 ] && break
    done
    if [ "$_gate_fail" -eq 1 ]; then
        echo "FATAL: initramfs ${_img} is missing required boot content (cryptsetup and/or kpartx/partprobe/void-inner-partscan bits)." >&2
        echo "       Aborting before the ESP sync — do not boot this disk. Install cryptsetup/kpartx/parted, rebuild with dracut --force, and re-run." >&2
        exit 1
    fi
    unset _gate_fail
fi

newest_kver="$(ls -1 /lib/modules/ 2>/dev/null | sort -V | tail -n1)"
for _wid in $WIFI_IDS; do
    case "$_wid" in
        0x14e4:*) _fw_dir="brcm" ;;
        0x14c3:*) _fw_dir="mediatek" ;;
        0x10ec:*) _fw_dir="rtw88 rtw89 rtlwifi" ;;
        0x8086:*) _fw_dir="iwlwifi" ;;
        0x168c:*) _fw_dir="ath9k ath10k ath11k" ;;
        0x17cb:*) _fw_dir="qca" ;;
        *) _fw_dir="" ;;
    esac
    _fw_ok="no"
    for _d in $_fw_dir; do
        [ -d "/usr/lib/firmware/${_d}" ] && _fw_ok="yes" && break
    done
    _mod_ok="no"
    if [ -n "$newest_kver" ]; then
        for _g in grep; do :; done
        if grep -qiE 'wireless|wifi|mac80211|mt76|iwl|rtw|ath|brcmfmac' "/lib/modules/${newest_kver}/modules.dep" 2>/dev/null; then
            _mod_ok="yes"
        elif grep -qiE 'wireless|wifi|mac80211|mt76|iwl|rtw|ath|brcmfmac' "/lib/modules/${newest_kver}/modules.builtin" 2>/dev/null; then
            _mod_ok="yes"
        fi
    fi
    if [ "$_fw_ok" = "yes" ] && [ "$_mod_ok" = "yes" ]; then
        echo "[wifi] verified: ${_wid} — driver + firmware present in target (kernel ${newest_kver:-<none>})"
    else
        echo "WARNING [wifi]: ${_wid} — $([ "$_fw_ok" = "yes" ] && echo "firmware present" || echo "firmware MISSING (install the matching linux-firmware-* split)") / $([ "$_mod_ok" = "yes" ] && echo "module present" || echo "module NOT FOUND (out-of-tree/dkms driver — firmware alone can't fix it)")" >&2
    fi
done
unset _wid _fw_dir _d _fw_ok _mod_ok newest_kver

FW_AUDIT_TEXT=""
fw_audit_line() { FW_AUDIT_TEXT="${FW_AUDIT_TEXT}${1}"$'\n'; }

fw_audit_line "[fw] Firmware accounting (report-only):"

if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-network-'; then
    fw_audit_line "  linux-firmware-network : present — always-kept bulk (every LAN/WLAN/Bluetooth vendor wholesale; never prunable)."
else
    fw_audit_line "  linux-firmware-network : ABSENT (unexpected — linux-base should pull it)."
fi

if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-amd-'; then
    if [ "${HAS_AMD_GPU:-no}" = "yes" ]; then
        fw_audit_line "  linux-firmware-amd      : present — matches this box's probe (AMD GPU present)."
    else
        fw_audit_line "  linux-firmware-amd      : present — kept ONLY by the linux-base dependency wall (no AMD GPU detected)."
    fi
else
    fw_audit_line "  linux-firmware-amd      : absent."
fi

if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-intel-'; then
    if [ "${HAS_INTEL_GPU:-no}" = "yes" ]; then
        fw_audit_line "  linux-firmware-intel    : present — matches this box's probe (Intel GPU present)."
    else
        fw_audit_line "  linux-firmware-intel    : present — kept ONLY by the linux-base dependency wall (no Intel GPU detected)."
    fi
else
    fw_audit_line "  linux-firmware-intel    : absent."
fi

if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-nvidia-'; then
    if [ "${HAS_NVIDIA_GPU:-no}" = "yes" ]; then
        fw_audit_line "  linux-firmware-nvidia   : present — matches this box's probe (NVIDIA GPU present)."
    else
        fw_audit_line "  linux-firmware-nvidia   : present — kept ONLY by the linux-base dependency wall (no NVIDIA GPU detected)."
    fi
else
    fw_audit_line "  linux-firmware-nvidia   : absent."
fi

if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-broadcom-'; then
    fw_audit_line "  linux-firmware-broadcom : present — the ONE closed gap (installed for the detected Broadcom radio)."
else
    case " ${WIFI_IDS:-} " in
        *" 0x14e4:"*)
            fw_audit_line "  linux-firmware-broadcom : ABSENT but a Broadcom radio was detected — the detected radio has no firmware (declined, or the [WIFI-FW] install failed)."
            ;;
        *)
            fw_audit_line "  linux-firmware-broadcom : absent (no Broadcom radio detected — nothing to close)."
            ;;
    esac
fi

if xbps-query -l 2>/dev/null | grep -q '^intel-ucode-'; then
    fw_audit_line "  intel-ucode             : present — the one genuinely pruned package (Intel microcode, installed per live CPU-detect)."
elif xbps-query -l 2>/dev/null | grep -q '^linux-firmware-amd-'; then
    :
else
    fw_audit_line "  intel-ucode             : absent (microcode: ${MICROCODE_PKG:-<none>} per live CPU-detect / opt-out)."
fi

_fw_audio=""
xbps-query -l 2>/dev/null | grep -q '^alsa-firmware-' && _fw_audio="alsa-firmware "
xbps-query -l 2>/dev/null | grep -q '^sof-firmware-' && _fw_audio="${_fw_audio}sof-firmware"
if [ -n "$_fw_audio" ]; then
    fw_audit_line "  ${_fw_audio% } : present (audio firmware)."
fi
unset _fw_audio

echo "$FW_AUDIT_TEXT"

if [ "$BOOTLOADER" = "limine" ]; then
/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf
fi

if [ "$BOOTLOADER" = "grub" ]; then
    [ -f /etc/grub.d/41_snapshots-btrfs ] && chmod -x /etc/grub.d/41_snapshots-btrfs
fi
snapper --no-dbus -c root create --description "Baseline Automated System Installation"
if [ "$BOOTLOADER" = "grub" ]; then
    [ -f /etc/grub.d/41_snapshots-btrfs ] && chmod +x /etc/grub.d/41_snapshots-btrfs
    grub-mkconfig -o /boot/grub/grub.cfg
else
    /usr/local/sbin/void-limine-write-conf
fi
CHROOT_EOF

if [ -d /tmp/ssh-keygen ] || [ -d /tmp/ssh-import ]; then
    shred -u /tmp/ssh-keygen/* /tmp/ssh-import/* 2>/dev/null || true
    rm -rf /tmp/ssh-keygen /tmp/ssh-import
    echo "  SSH key stage shredded from live environment."
fi

echo ""
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_CYN}${C_BOLD} STAGE 3: Clean post-chroot recovery teardown${C_RST}"
STAGE_CONTEXT="STAGE3:teardown"
jl "Begin Stage 3 (post-chroot teardown)"
echo "${C_CYN}==============================================================================${C_RST}"
echo "Tearing down system targets cleanly..."
sync

swapoff /mnt/var/swap/swapfile || true

[ "$GRUB_ESP_BOOT" = "true" ] && umount -v /mnt/boot || true
umount -v /mnt/boot/efi || true
umount -v /mnt/boot/grub || true
umount -fl /mnt/dev || true
umount -fl /mnt/proc || true
umount -fl /mnt/sys || true
umount -fl /mnt/run || true

umount -v /mnt/var/swap || true
umount -v /mnt/var/spool || true
umount -v /mnt/var/log || true
umount -v /mnt/var/lib/libvirt || true
umount -v /mnt/var/lib/NetworkManager || true
umount -v /mnt/var/lib/flatpak || true
umount -v /mnt/var/lib/docker || true
umount -v /mnt/var/lib/containers || true
umount -v /mnt/var/lib/sddm || true
umount -v /mnt/var/lib/lightdm || true
umount -v /mnt/var/cache || true
umount -v /mnt/srv || true
umount -v /mnt/opt || true
umount -v /mnt/.snapshots || true
umount -v /mnt/home || true
umount -v /mnt/tmp/xbps-cache || true
umount -v /mnt || true

case "$DESKTOP_ENV" in
    kde)      _DE_FRIENDLY="KDE Plasma";;
    cinnamon) _DE_FRIENDLY="Cinnamon";;
    gnome)    _DE_FRIENDLY="GNOME";;
    xfce)     _DE_FRIENDLY="Xfce";;
    mate)     _DE_FRIENDLY="MATE";;
    lxqt)     _DE_FRIENDLY="LXQt";;
    cosmic)   _DE_FRIENDLY="COSMIC";;
    *)        _DE_FRIENDLY="$DESKTOP_ENV";;
esac
_DE_FRIENDLY="${_DE_FRIENDLY:-$DESKTOP_ENV}"

echo ""
echo "${C_GRN}==============================================================================${C_RST}"
echo "${C_GRN}${C_BOLD}  INSTALL SUCCESSFUL — Void Linux ${SCRIPT_VERSION}${C_RST}"
echo "${C_GRN}==============================================================================${C_RST}"
echo ""
echo "${C_BOLD}  Target disk:${C_RST}   ${DISK}"
echo "${C_BOLD}  Hostname:${C_RST}     ${TARGET_FQDN:-$TARGET_HOSTNAME}"
echo "${C_BOLD}  Primary user:${C_RST}  ${TARGET_USER}"
echo "${C_BOLD}  Login shell:${C_RST}  ${USER_SHELL}"
echo "${C_BOLD}  Desktop:${C_RST}      ${_DE_FRIENDLY} (${DESKTOP_ENV})"
echo "${C_BOLD}  Display manager:${C_RST} ${DISPLAY_MANAGER}"
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    case "$LIGHTDM_GREETER_PKG" in
        lightdm-slick-greeter) _GREETER_FRIENDLY="Slick (lightdm-slick-greeter)" ;;
        lightdm-gtk-greeter)   _GREETER_FRIENDLY="GTK (lightdm-gtk-greeter)" ;;
        *)                     _GREETER_FRIENDLY="${LIGHTDM_GREETER_PKG:-<not selected>}" ;;
    esac
    echo "${C_BOLD}  Greeter:${C_RST}       ${_GREETER_FRIENDLY}"
    unset _GREETER_FRIENDLY
fi
echo "${C_BOLD}  Bootloader:${C_RST}   ${BOOTLOADER}"
echo "${C_BOLD}  Locale:${C_RST}        ${LOCALE}"
echo "${C_BOLD}  Timezone:${C_RST}     ${TIMEZONE}"
_SWAP_DISPLAY_SIZE=$(printf '%s' "$SWAPFILE_SIZE" | tr '[:lower:]' '[:upper:]')
case "$SWAP_BACKEND" in
    swapfile) _SWAP_FRIENDLY="swapfile (${_SWAP_DISPLAY_SIZE})" ;;
    zram)     _SWAP_FRIENDLY="zram" ;;
    both)     _SWAP_FRIENDLY="swapfile (${_SWAP_DISPLAY_SIZE}) + zram" ;;
    none)     _SWAP_FRIENDLY="none" ;;
    *)        _SWAP_FRIENDLY="$SWAP_BACKEND" ;;
esac
unset _SWAP_DISPLAY_SIZE
echo "${C_BOLD}  Swap:${C_RST}         ${_SWAP_FRIENDLY}"
echo "${C_BOLD}  Hibernation:${C_RST}  ${ENABLE_HIBERNATION}"
echo "${C_BOLD}  Encryption:${C_RST}   $([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo "LUKS2 full-disk + YubiKey hmac-sha1 (fallback: $YK_FALLBACK)" || echo "LUKS2 full-disk (passphrase required at boot)"; } || echo "none")"
echo ""
echo "${C_BOLD}  NEXT STEPS${C_RST}"
echo "${C_GRN}  1.${C_RST} Remove the live USB, then this system will reboot into your install automatically."
echo "${C_GRN}  2.${C_RST} First boot is a clean initial-boot state. If no graphical login appears, log in"
if [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    echo "     at the console and run:  ${C_BOLD}ln -sf /etc/sv/cosmic-greeter /etc/runit/runsvdir/default/ && ln -sf /etc/sv/cosmic-greeter-daemon /etc/runit/runsvdir/default/${C_RST}"
else
    echo "     at the console and run:  ${C_BOLD}ln -sf /etc/sv/${DISPLAY_MANAGER} /etc/runit/runsvdir/default/${C_RST}  (or your chosen DM)."
fi
if [ "$BOOTLOADER" = "limine" ]; then
    echo "${C_GRN}  3.${C_RST} Limine boots automatically (no NVRAM entry needed on UEFI)."
    echo "     To snapshot a running system later:  ${C_BOLD}sudo snapper create -d 'manual'${C_RST}"
else
    echo "${C_GRN}  3.${C_RST} GRUB is installed (with grub-btrfs snapshots). To update the menu:"
    echo "     ${C_BOLD}grub-mkconfig -o /boot/grub/grub.cfg${C_RST}"
fi
echo "${C_GRN}  4.${C_RST} A baseline snapper snapshot has already been created for the clean install."
echo "${C_GRN}  5.${C_RST} The exact choices + installer version that built this box are archived on it:"
echo "     ${C_BOLD}/etc/void-installer/install-config${C_RST}  and  ${C_BOLD}/etc/void-installer/Void_Linux_Installer.sh${C_RST}"
echo "     Quick record: ${C_BOLD}~/Documents/Void_Install.txt${C_RST} (installed user)"
echo "${C_GRN}  6.${C_RST} System updates now auto-take a snapper pre/post rollback pair:"
echo "     xbps-install is shadowed through void-xbps-snap, so your normal"
echo "     ${C_BOLD}sudo xbps-install -Su${C_RST} is unchanged. If an 'xbps' package"
echo "     self-update un-shadows the wrapper, the next boot repairs it"
echo "     automatically (see /root/tools/README.md, re-shadow-xbps.sh)."
echo "${C_GRN}  7.${C_RST} Re-runnable maintenance tools shipped in ${C_BOLD}/root/tools${C_RST}:"
echo "     ${C_BOLD}re-shadow-xbps.sh${C_RST}  restore auto-update snapshots after an xbps update"
echo "     ${C_BOLD}limine-sync.sh${C_RST}      force a manual Limine boot-menu resync"
echo "     ${C_BOLD}re-provision-snapper.sh${C_RST}  safely restore snapshots/plugin (no data loss)"
echo ""
echo "${C_GRN}======================================================================${C_RST}"
STAGE_CONTEXT="DONE"
jl "Install COMPLETED successfully (bootloader=${BOOTLOADER}, DE=${DESKTOP_ENV})"
[ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
mkdir -p /mnt/etc/void-installer
if [ -n "$0" ] && [ -f "$0" ]; then
    cp -f "$0" /mnt/etc/void-installer/Void_Linux_Installer.sh 2>/dev/null \
        && jl "Installer script archived to /etc/void-installer/Void_Linux_Installer.sh" \
        || echo "WARNING: could not archive installer script into target." >&2
fi
cp -f "$JOURNAL" /mnt/etc/void-installer/installer-run.log 2>/dev/null \
    && jl "Journal archived to /etc/void-installer/installer-run.log" \
    || echo "WARNING: could not archive installer journal into target." >&2
echo ""
echo "  Rebooting in ${C_BOLD}${REBOOT_DELAY}${C_RST} second(s) — press ${C_BOLD}R${C_RST}/${C_BOLD}Enter${C_RST} to reboot now,"
echo "  ${C_BOLD}P${C_RST} to pause, ${C_BOLD}C${C_RST} to continue, ${C_BOLD}S${C_RST} to stop and stay at the live shell."
sync
_do_reboot=1
_now_paused=0
_tl="$REBOOT_DELAY"
_tty_avail=0
{ [ -r /dev/tty ] && [ -w /dev/tty ]; } && _tty_avail=1
while [ "$_tl" -gt 0 ]; do
    if [ "$_now_paused" -eq 1 ]; then
        printf "\r  [%s]  PAUSED — R/Enter=reboot now, C=continue, S=stop:             " "$_tl"
    else
        printf "\r  Reboot in %s second(s)...  R/Enter=now, P=pause, S=stop:       " "$_tl"
    fi
    _break_key=""
    _tick=0
    if [ "$_tty_avail" -eq 1 ] && read -r -s -n 1 -t 1 _break_key < /dev/tty 2>/dev/null; then
        case "$_break_key" in
            R|r|$'\r'|$'\n') _do_reboot=1; break ;;
            P|p)             _now_paused=1 ;;
            C|c)             _now_paused=0 ;;
            S|s)             _do_reboot=0; break ;;
        esac
    elif [ "$_tty_avail" -eq 1 ]; then
        _tick=1
    else
        sleep 1
        _tick=1
    fi
    if [ "$_now_paused" -eq 0 ] && [ "$_tick" -eq 1 ]; then
        _tl=$((_tl - 1))
    fi
done
printf "\r\033[K"
if [ "$_do_reboot" -eq 1 ]; then
    echo "Rebooting now..."
    reboot
else
    echo "Reboot skipped — staying at the live shell. When ready, reboot with: ${C_BOLD}reboot${C_RST}"
fi
