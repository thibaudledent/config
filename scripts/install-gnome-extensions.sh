#!/usr/bin/env bash
#
# install-gnome-extensions.sh
# Installs and enables a curated set of GNOME Shell extensions.
# Supports Arch Linux and Ubuntu. Safe to re-run (idempotent).

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

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
        error "gnome-shell not found. GNOME does not appear to be installed."
    fi

    local current_desktop="${XDG_CURRENT_DESKTOP:-}"
    if [[ ! "$current_desktop" =~ GNOME ]]; then
        error "GNOME is not the active desktop environment (XDG_CURRENT_DESKTOP=${current_desktop:-unset}). Please run this script from a GNOME session."
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|endeavouros|manjaro) echo "arch" ;;
            ubuntu|pop|linuxmint)     echo "ubuntu" ;;
            *) error "Unsupported distro: $ID" ;;
        esac
    else
        error "Cannot detect distribution (missing /etc/os-release)."
    fi
}

# ─── Ensure D-Bus session is available (needed for gnome-extensions enable) ──
ensure_dbus() {
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        local uid
        uid="$(id -u)"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus"
        info "Set DBUS_SESSION_BUS_ADDRESS to $DBUS_SESSION_BUS_ADDRESS"
    fi
}

# ─── Install gnome-shell-extension-installer ─────────────────────────────────
ensure_installer() {
    if command -v gnome-shell-extension-installer &>/dev/null; then
        success "gnome-shell-extension-installer already available."
        return
    fi

    local distro="$1"
    info "Installing gnome-shell-extension-installer…"

    if [ "$distro" = "arch" ]; then
        yay -S --needed --noconfirm gnome-shell-extension-installer
    else
        local url="https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer"
        sudo curl -sL "$url" -o /usr/local/bin/gnome-shell-extension-installer
        sudo chmod +x /usr/local/bin/gnome-shell-extension-installer
    fi

    command -v gnome-shell-extension-installer &>/dev/null \
        || error "Failed to install gnome-shell-extension-installer."
    success "gnome-shell-extension-installer installed."
}

# ─── Compile GSettings schemas for an extension ─────────────────────────────
compile_schemas() {
    local uuid="$1"
    local schemas_dir="$EXTENSIONS_DIR/$uuid/schemas"

    if [ -d "$schemas_dir" ]; then
        if [ ! -f "$schemas_dir/gschemas.compiled" ]; then
            info "Compiling GSettings schemas for $uuid…"
            glib-compile-schemas "$schemas_dir"
            success "Schemas compiled."
        fi
    fi
}

# ─── Install & enable a single extension ─────────────────────────────────────
install_extension() {
    local uuid="$1"
    local ext_id="$2"

    info "Processing $uuid (ID: $ext_id)…"

    if gnome-extensions list 2>/dev/null | grep -qF "$uuid"; then
        success "$uuid already installed."
    else
        gnome-shell-extension-installer "$ext_id" --yes
        success "$uuid installed."
    fi

    compile_schemas "$uuid"

    if gnome-extensions enable "$uuid" 2>/dev/null; then
        success "$uuid enabled."
    else
        warn "$uuid could not be enabled now — a session restart may be needed."
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_gnome
    ensure_dbus

    local version
    version="$(gnome-shell --version | grep -oP '[\d.]+')"
    info "GNOME Shell version: $version"

    local distro
    distro="$(detect_distro)"
    info "Detected distro family: $distro"

    ensure_installer "$distro"

    for uuid in "${!EXTENSIONS[@]}"; do
        install_extension "$uuid" "${EXTENSIONS[$uuid]}"
    done

    echo ""
    success "All extensions installed and enabled."
    info "Restart GNOME Shell to activate everything:"
    info "  Wayland → Log out and back in"
    info "  X11     → Alt+F2 → r → Enter"
}

main "$@"
