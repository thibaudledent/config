#!/usr/bin/env bash
#
# Developer Environment Setup
#
# Supports: Ubuntu/Debian • Arch • macOS • WSL (+Chocolatey)
# Usage:    chmod +x dev-setup.sh && ./dev-setup.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFS_FILE="$SCRIPT_DIR/.dev-setup-prefs"
FAILURES_FILE="${FAILURES_FILE:-$(mktemp)}"

# ─────────────────────────────────────────────────────────────────
# Shared logging
# ─────────────────────────────────────────────────────────────────
source "$SCRIPT_DIR/log-utils.sh"

# ─────────────────────────────────────────────────────────────────
# Packages — just names. Add or remove, nothing else to touch.
# ─────────────────────────────────────────────────────────────────

PACKAGES=(
    git curl wget unzip zip jq tree make build-essential
    tldr zsh fzf fd-find terminator
    vscode sublime-text neovim intellij-idea-ce antigravity
    python3 pip nodejs npm temurin-17 temurin-21 temurin-25 go rust
    docker docker-compose tmux htop ripgrep bat shellcheck lazygit
    xclip xsel
    flameshot firefox meld
)

# ─────────────────────────────────────────────────────────────────
# Aliases — when a package name differs per OS, add it here.
#
#   declare -A ALIAS_<os>   maps "friendly name" → "real package"
#   declare -A APT_REPOS    maps "friendly name" → "gpg_url|repo_url"
#                           (repo is added to apt before installing)
#
# If a package isn't in an alias table, it's used as-is.
# ─────────────────────────────────────────────────────────────────

declare -A ALIAS_APT=(
    [build-essential]="build-essential"
    [pip]="python3-pip"
    [docker]="docker.io"
    [intellij-idea-ce]="intellij-idea-community"
    [temurin-17]="temurin-17-jdk"
    [temurin-21]="temurin-21-jdk"
    [temurin-25]="temurin-25-jdk"
)

declare -A ALIAS_PACMAN=(
    [build-essential]="base-devel"
    [pip]="python-pip"
    [python3]="python"
    [fd-find]="fd"
    [intellij-idea-ce]="intellij-idea-community-edition"
    [temurin-17]="jdk17-temurin"
    [temurin-21]="jdk21-temurin"
    [temurin-25]="jdk-temurin"
)

declare -A ALIAS_BREW=(
    [nodejs]="node"
    [fd-find]="fd"
    [temurin-17]="temurin@17"
    [temurin-21]="temurin@21"
    [temurin-25]="temurin@25"
)

# APT repos needed before installing certain packages.
# Format: "gpg_key_url|deb_line"
# The codename placeholder __CODENAME__ is replaced at runtime.
declare -A APT_REPOS=(
    [adoptium]="https://packages.adoptium.net/artifactory/api/gpg/key/public|https://packages.adoptium.net/artifactory/deb __CODENAME__ main"
)

# ─────────────────────────────────────────────────────────────────
# OS Detection
# ─────────────────────────────────────────────────────────────────

OS=""

detect_os() {
    local is_wsl=false
    grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null && is_wsl=true

    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "$ID" in
            ubuntu|debian|linuxmint|pop) OS="ubuntu" ;;
            arch|manjaro|endeavouros)    OS="arch" ;;
            *) log_error "Unsupported: $ID"; exit 1 ;;
        esac
    else
        log_error "Cannot detect OS"; exit 1
    fi

    if $is_wsl; then OS="wsl"; fi
    log_info "Detected: ${_LOG_BOLD}$OS${_LOG_RESET}"
}

# ─────────────────────────────────────────────────────────────────
# Package Managers
# ─────────────────────────────────────────────────────────────────

command_exists() { command -v "$1" &>/dev/null; }

_updated=false
ensure_updated() {
    if $_updated; then return 0; fi
    log_info "Updating package lists..."
    case "$OS" in
        ubuntu|wsl) sudo apt-get update -y ;;
        arch)       sudo pacman -Sy --noconfirm ;;
        macos)      brew update ;;
    esac
    _updated=true
}

# Generic: add an apt repo if not already present.
# Uses the repo name as the keyring/list filename.
declare -A _apt_repos_added=()
add_apt_repo() {
    local name="$1" gpg_url="$2" deb_line="$3"
    if [[ -v "_apt_repos_added[$name]" ]]; then return 0; fi
    if [[ -f "/etc/apt/sources.list.d/${name}.list" ]]; then _apt_repos_added[$name]=1; return 0; fi

    log_info "Adding apt repository: $name"
    local codename; codename=$(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release)
    deb_line="${deb_line//__CODENAME__/$codename}"

    sudo mkdir -p /etc/apt/keyrings
    wget -qO- "$gpg_url" | gpg --dearmor | sudo tee "/etc/apt/keyrings/${name}.gpg" >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/${name}.gpg] $deb_line" \
        | sudo tee "/etc/apt/sources.list.d/${name}.list" >/dev/null
    sudo apt-get update -y
    _apt_repos_added[$name]=1
}

ensure_homebrew() {
    command_exists brew && return 0
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
}

ensure_chocolatey() {
    powershell.exe -Command "Get-Command choco" &>/dev/null 2>&1 && return 0
    log_info "Installing Chocolatey..."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
        "Set-ExecutionPolicy Bypass -Scope Process -Force; \
         [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
         iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
}

ensure_yay() {
    command_exists yay && return 0
    log_info "Installing yay (and build dependencies)..."
    sudo pacman -S --noconfirm --needed base-devel git debugedit fakeroot
    local tmp; tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

mgr_apt()    { sudo apt-get install -y "$1"; }
mgr_pacman() { sudo pacman -S --noconfirm --needed "$1"; }
mgr_brew()   { brew install "$1"; }
mgr_cask()   { brew install --cask "$1"; }
mgr_snap()   { command_exists snap && sudo snap install "$1"; }
mgr_yay()    { ensure_yay && yay -S --noconfirm "$1"; }
mgr_choco()  { ensure_chocolatey; powershell.exe -Command "choco install $1 -y"; }

# ─────────────────────────────────────────────────────────────────
# resolve() — look up the real package name for this OS
# ─────────────────────────────────────────────────────────────────

resolve() {
    local pkg="$1"
    case "$OS" in
        ubuntu|wsl) if [[ -v "ALIAS_APT[$pkg]" ]];    then echo "${ALIAS_APT[$pkg]}";    return; fi ;;
        arch)       if [[ -v "ALIAS_PACMAN[$pkg]" ]];  then echo "${ALIAS_PACMAN[$pkg]}";  return; fi ;;
        macos)      if [[ -v "ALIAS_BREW[$pkg]" ]];    then echo "${ALIAS_BREW[$pkg]}";    return; fi ;;
    esac
    echo "$pkg"
}

# ─────────────────────────────────────────────────────────────────
# is_installed() — check if a package is already installed
# ─────────────────────────────────────────────────────────────────

is_installed() {
    local friendly="$1"
    local pkg; pkg=$(resolve "$friendly")

    case "$OS" in
        ubuntu|wsl)
            dpkg -s "$pkg" &>/dev/null && return 0
            ;;
        arch)
            pacman -Qi "$pkg" &>/dev/null && return 0
            ;;
        macos)
            brew list "$pkg" &>/dev/null && return 0
            brew list --cask "$pkg" &>/dev/null && return 0
            ;;
    esac

    # Fallback: check if a command with the friendly name exists
    command_exists "$friendly" && return 0

    return 1
}

# ─────────────────────────────────────────────────────────────────
# install()
#
# Fallback chains:
#   ubuntu/wsl → apt → snap → choco (wsl only)
#   arch       → pacman → yay
#   macos      → brew → cask
# ─────────────────────────────────────────────────────────────────

install() {
    local friendly="$1"
    local pkg; pkg=$(resolve "$friendly")

    # Add apt repo if needed (only on apt-based systems)
    if [[ "$OS" == "ubuntu" || "$OS" == "wsl" ]] && [[ "$friendly" == temurin-* ]]; then
        local gpg_url deb_line
        IFS='|' read -r gpg_url deb_line <<< "${APT_REPOS[adoptium]}"
        add_apt_repo "adoptium" "$gpg_url" "$deb_line"
    fi

    case "$OS" in
        ubuntu|wsl)
            mgr_apt "$pkg" && return 0
            mgr_snap "$pkg" && return 0
            if [[ "$OS" == "wsl" ]]; then mgr_choco "$pkg" && return 0; fi
            ;;
        arch)
            mgr_pacman "$pkg" && return 0
            mgr_yay "$pkg" && return 0
            ;;
        macos)
            mgr_brew "$pkg" && return 0
            mgr_cask "$pkg" && return 0
            ;;
    esac

    return 1
}

# ─────────────────────────────────────────────────────────────────
# TUI Package Selector
# ─────────────────────────────────────────────────────────────────

declare -a SELECTED=()

load_prefs() {
    [[ -f "$PREFS_FILE" ]] || return 1
    SELECTED=()
    for ((i = 0; i < ${#PACKAGES[@]}; i++)); do
        if grep -qx "${PACKAGES[$i]}" "$PREFS_FILE" 2>/dev/null; then
            SELECTED[$i]=1
        else
            SELECTED[$i]=0
        fi
    done
}

save_prefs() {
    : > "$PREFS_FILE"
    for ((i = 0; i < ${#PACKAGES[@]}; i++)); do
        if [[ "${SELECTED[$i]}" == "1" ]]; then echo "${PACKAGES[$i]}" >> "$PREFS_FILE"; fi
    done
}

select_packages() {
    local total=${#PACKAGES[@]}

    if ! load_prefs; then
        for ((i = 0; i < total; i++)); do SELECTED[$i]=1; done
    else
        echo -e "\n  ${_LOG_DIM}Loaded saved preferences. Edit or ENTER to keep.${_LOG_RESET}"
    fi

    local cursor=0 scroll=0
    local lines; lines=$(tput lines 2>/dev/null || echo 24)
    local visible=$((lines - 6))
    if (( visible < 5 )); then visible=5; fi
    if (( visible > total )); then visible=$total; fi

    tput civis 2>/dev/null || true
    tput smcup 2>/dev/null || true
    cleanup_tui() { tput rmcup 2>/dev/null || true; tput cnorm 2>/dev/null || true; }
    trap cleanup_tui EXIT

    while true; do
        tput clear 2>/dev/null || clear
        echo ""
        echo -e "  ${_LOG_BOLD}${_LOG_CYAN}Select packages to install${_LOG_RESET}"
        echo -e "  ${_LOG_DIM}↑/↓ Navigate   SPACE Toggle   A All   N None   ENTER Confirm${_LOG_RESET}"
        echo ""

        for ((i = scroll; i < total && i < scroll + visible; i++)); do
            local mark=" "
            if [[ "${SELECTED[$i]}" == "1" ]]; then mark="${_LOG_GREEN}✔${_LOG_RESET}"; fi
            if (( i == cursor )); then
                printf "  ${_LOG_BOLD}${_LOG_CYAN}>${_LOG_RESET} [%b] ${_LOG_BOLD}%-22s${_LOG_RESET}\n" "$mark" "${PACKAGES[$i]}"
            else
                printf "    [%b] %-22s\n" "$mark" "${PACKAGES[$i]}"
            fi
        done

        local count=0
        for ((i = 0; i < total; i++)); do
            if [[ "${SELECTED[$i]}" == "1" ]]; then count=$((count + 1)); fi
        done
        echo -e "\n  ${_LOG_DIM}${count}/${total} selected${_LOG_RESET}"

        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 seq || true
                case "$seq" in
                    '[A') if (( cursor > 0 )); then cursor=$((cursor - 1)); fi
                          if (( cursor < scroll )); then scroll=$cursor; fi ;;
                    '[B') if (( cursor < total - 1 )); then cursor=$((cursor + 1)); fi
                          if (( cursor >= scroll + visible )); then scroll=$((cursor - visible + 1)); fi ;;
                esac ;;
            ' ') if [[ "${SELECTED[$cursor]}" == "1" ]]; then SELECTED[$cursor]=0; else SELECTED[$cursor]=1; fi ;;
            a|A) for ((i = 0; i < total; i++)); do SELECTED[$i]=1; done ;;
            n|N) for ((i = 0; i < total; i++)); do SELECTED[$i]=0; done ;;
            '')  break ;;
        esac
    done

    cleanup_tui; trap - EXIT
    save_prefs
    log_ok "Preferences saved"
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────

main() {
    echo -e "\n  ${_LOG_BOLD}${_LOG_CYAN}Developer Environment Setup${_LOG_RESET}\n"

    detect_os
    select_packages

    log_section "Preparing"
    ensure_updated
    if [[ "$OS" == "macos" ]]; then ensure_homebrew; fi
    if [[ "$OS" == "wsl" ]]; then ensure_chocolatey; fi

    log_section "Installing"
    local ok=0 fail=0 skip=0 already=0

    for ((i = 0; i < ${#PACKAGES[@]}; i++)); do
        if [[ "${SELECTED[$i]}" != "1" ]]; then skip=$((skip + 1)); continue; fi
        local pkg="${PACKAGES[$i]}"

        if is_installed "$pkg"; then
            log_ok "$pkg (already installed)"
            already=$((already + 1))
            continue
        fi

        printf "  ${_LOG_BLUE}▸${_LOG_RESET} %s\n" "$pkg"
        if install "$pkg"; then
            log_ok "$pkg"; ok=$((ok + 1))
        else
            log_error "Failed: $pkg"; fail=$((fail + 1))
            echo "$pkg" >> "$FAILURES_FILE"
        fi
    done

    echo ""
    echo -e "  ${_LOG_GREEN}${_LOG_BOLD}Done!${_LOG_RESET}  ✔ $ok  ● $already already installed  ○ $skip skipped  ✘ $fail failed"
    echo -e "  ${_LOG_DIM}Prefs: $PREFS_FILE${_LOG_RESET}\n"
}

main "$@"
