#!/usr/bin/env bash
#
# install-gnome-extensions.sh
# Installs and enables a curated set of GNOME Shell extensions.
# Supports Arch Linux and Ubuntu. Safe to re-run (idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/log-utils.sh"

EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"

# ─── Extension list: UUID → numeric ID ───────────────────────────────────────
declare -A EXTENSIONS=(
    ["clipboard-indicator@tudmotu.com"]=779
    ["caffeine@patapon.info"]=517
    ["Vitals@CoreCoding.com"]=1460
    ["tiling-assistant@leleat-on-github"]=3733
    ["simpleweather@romanlefler.com"]=8261
)

# ─── Preflight checks ────────────────────────────────────────────────────────
check_gnome() {
    if ! command -v gnome-shell &>/dev/null; then
        log_error "gnome-shell not found. GNOME does not appear to be installed."
        exit 1
    fi

    local current_desktop="${XDG_CURRENT_DESKTOP:-}"
    if [[ ! "$current_desktop" =~ GNOME ]]; then
        log_error "GNOME is not the active desktop environment (XDG_CURRENT_DESKTOP=${current_desktop:-unset}). Please run this script from a GNOME session."
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|endeavouros|manjaro) echo "arch" ;;
            ubuntu|pop|linuxmint)     echo "ubuntu" ;;
            *) log_error "Unsupported distro: $ID"; exit 1 ;;
        esac
    else
        log_error "Cannot detect distribution (missing /etc/os-release)."
        exit 1
    fi
}

# ─── Ensure D-Bus session is available (needed for gnome-extensions enable) ──
ensure_dbus() {
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        local uid
        uid="$(id -u)"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus"
        log_info "Set DBUS_SESSION_BUS_ADDRESS to $DBUS_SESSION_BUS_ADDRESS"
    fi
}

# ─── Install gnome-shell-extension-installer ─────────────────────────────────
ensure_installer() {
    if command -v gnome-shell-extension-installer &>/dev/null; then
        log_ok "gnome-shell-extension-installer already available."
        return
    fi

    local distro="$1"
    log_info "Installing gnome-shell-extension-installer…"

    if [ "$distro" = "arch" ]; then
        yay -S --needed --noconfirm gnome-shell-extension-installer
    else
        local url="https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer"
        sudo curl -sL "$url" -o /usr/local/bin/gnome-shell-extension-installer
        sudo chmod +x /usr/local/bin/gnome-shell-extension-installer
    fi

    command -v gnome-shell-extension-installer &>/dev/null \
        || { log_error "Failed to install gnome-shell-extension-installer."; exit 1; }
    log_ok "gnome-shell-extension-installer installed."
}

# ─── Compile GSettings schemas for an extension ─────────────────────────────
compile_schemas() {
    local uuid="$1"
    local schemas_dir="$EXTENSIONS_DIR/$uuid/schemas"

    if [ -d "$schemas_dir" ]; then
        if [ ! -f "$schemas_dir/gschemas.compiled" ]; then
            log_info "Compiling GSettings schemas for $uuid…"
            glib-compile-schemas "$schemas_dir"
            log_ok "Schemas compiled."
        fi
    fi
}

# ─── Install & enable a single extension ─────────────────────────────────────
install_extension() {
    local uuid="$1"
    local ext_id="$2"

    log_info "Processing $uuid (ID: $ext_id)…"

    if gnome-extensions list 2>/dev/null | grep -qF "$uuid"; then
        log_ok "$uuid already installed."
    else
        gnome-shell-extension-installer "$ext_id" --yes
        log_ok "$uuid installed."
    fi

    compile_schemas "$uuid"

    if gnome-extensions enable "$uuid" 2>/dev/null; then
        log_ok "$uuid enabled."
    else
        log_warn "$uuid could not be enabled now — a session restart may be needed."
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_gnome
    ensure_dbus

    local version
    version="$(gnome-shell --version | grep -oP '[\d.]+')"
    log_info "GNOME Shell version: $version"

    local distro
    distro="$(detect_distro)"
    log_info "Detected distro family: $distro"

    ensure_installer "$distro"

    for uuid in "${!EXTENSIONS[@]}"; do
        install_extension "$uuid" "${EXTENSIONS[$uuid]}"
    done

    echo ""
    log_ok "All extensions installed and enabled."
    log_info "Restart GNOME Shell to activate everything:"
    log_info "  Wayland → Log out and back in"
    log_info "  X11     → Alt+F2 → r → Enter"
}

main "$@"
