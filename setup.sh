#!/usr/bin/env bash
set -Eeuo pipefail

source "${PWD}/scripts/log-utils.sh"

log_section "Setup"

# GNOME EXTENSIONS
log_section "GNOME Extensions"

if command -v gnome-shell &>/dev/null; then
  bash "${PWD}"/scripts/install-gnome-extensions.sh
else
  log_warn "gnome-shell not found, skipping GNOME extensions install."
fi

# DEV ENVIRONMENT
log_section "Installing base tools..."

DEV_FAILURES_FILE=$(mktemp)
export FAILURES_FILE="$DEV_FAILURES_FILE"
bash "${PWD}"/scripts/dev-setup.sh

# ZSH
if [ ! -d "$HOME/.oh-my-zsh" ];
then
  log_info "Installing Oh My Zsh and plugins..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
  sudo wget -P /usr/local/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
  sudo wget -P /usr/local/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
  sudo wget -P /usr/local/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
  sudo wget -P /usr/local/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
  # make zsh your default shell
  chsh -s "$(which zsh)"
else
  log_ok "Oh My Zsh already installed"
fi

log_section "Symlinks"

# To create symlinks for the configuration and script files
LN=$(which ln)
LN_OPTS="-f -s -v"
"$LN" $LN_OPTS "${PWD}"/zsh/zshrc ~/.zshrc
if [ -e ~/.config/terminator/config ]
then
  "$LN" $LN_OPTS "${PWD}"/terminator/config ~/.config/terminator/config
fi

# SYMLINKS FOR SCRIPTS
"$LN" $LN_OPTS "${PWD}"/scripts/sort-json.sh ~/sort-json.sh
"$LN" $LN_OPTS "${PWD}"/scripts/update-all-repos.sh ~/update-all-repos.sh
"$LN" $LN_OPTS "${PWD}"/scripts/create-jira.py ~/create-jira.py
"$LN" $LN_OPTS "${PWD}"/scripts/recursive-file-reader.sh ~/recursive-file-reader.sh
log_ok "Symlinks created"

# MAVEN SETTINGS
log_section "Maven"

# Overriding your Maven user settings in ${user.home}/.m2/settings.xml
if [ -f "/etc/wsl.conf" ];
then
  CUSTOM_HOME=$(wslpath "$(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')")
else
  CUSTOM_HOME=$HOME
fi

if [ ! -f "$CUSTOM_HOME/.m2/settings.xml" ];
then
  set +x
  echo -n "Enter your Maven settings.xml artifactory user: "
  read -r user
  echo -n "Enter your Maven settings.xml artifactory api key: "
  read -rs key
  echo -n "\nEnter your Maven settings.xml artifactory url (including 'https://' in front and '/artifactory' at the end): "
  read -r url
  echo ""

  sed -e "s/USER_LOGIN/$user/" -e "s/USER_PASSWORD/$key/"  -e "s#ARTIFACTORY_URL#$url#" "${PWD}"/maven/settings.xml > "${PWD}"/maven/settings_with_api_key.xml
  set -x

  mkdir -p ~/.m2

  "$LN" $LN_OPTS "${PWD}"/maven/settings_with_api_key.xml ~/.m2/settings.xml
  if [ -f "/etc/wsl.conf" ]; then
    cp "${PWD}/maven/settings_with_api_key.xml" "$CUSTOM_HOME/.m2/settings.xml"
  fi
  log_ok "Maven settings configured"
else
  log_ok "Maven settings already present"
fi

# EDITOR SETTINGS
log_section "Editor Settings"

# VS Code - settings.json
if [ -f "/etc/wsl.conf" ]; then
  VSCODE_DIR="$CUSTOM_HOME/AppData/Roaming/Code/User"
else
  VSCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User"
fi
if [ -d "$(dirname "$VSCODE_DIR")" ]; then
  mkdir -p "$VSCODE_DIR"
  if [ ! -f "$VSCODE_DIR/settings.json" ]; then
    echo '{ "editor.renderWhitespace": "all" }' > "$VSCODE_DIR/settings.json"
    log_ok "VS Code settings created"
  elif ! grep -q "renderWhitespace" "$VSCODE_DIR/settings.json"; then
    # Insert before the last closing brace
    sed -i '$ s/}$/,\n  "editor.renderWhitespace": "all"\n}/' "$VSCODE_DIR/settings.json"
    log_ok "VS Code settings updated"
  else
    log_ok "VS Code settings already configured"
  fi
else
  log_warn "VS Code config directory not found, skipping"
fi

# Sublime Text - Preferences.sublime-settings
if [ -f "/etc/wsl.conf" ]; then
  SUBL_DIR="$CUSTOM_HOME/AppData/Roaming/Sublime Text/Packages/User"
else
  SUBL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sublime-text/Packages/User"
fi
if [ -d "$(dirname "$SUBL_DIR")" ]; then
  mkdir -p "$SUBL_DIR"
  if [ ! -f "$SUBL_DIR/Preferences.sublime-settings" ]; then
    echo '{ "draw_white_space": "all" }' > "$SUBL_DIR/Preferences.sublime-settings"
    log_ok "Sublime Text settings created"
  elif ! grep -q "draw_white_space" "$SUBL_DIR/Preferences.sublime-settings"; then
    sed -i '$ s/}$/,\n  "draw_white_space": "all"\n}/' "$SUBL_DIR/Preferences.sublime-settings"
    log_ok "Sublime Text settings updated"
  else
    log_ok "Sublime Text settings already configured"
  fi
else
  log_warn "Sublime Text config directory not found, skipping"
fi

# SUMMARY
log_section "Summary"

# Collect and display failures from dev-setup.sh
if [ -s "$DEV_FAILURES_FILE" ]; then
    mapfile -t failures < "$DEV_FAILURES_FILE"
    log_failures "${failures[@]}"
fi
rm -f "$DEV_FAILURES_FILE"

log_ok "Setup done!"
echo ""
log_info "Log out and log back in to start using zsh."
log_info "To try it immediately, type 'zsh' in your current terminal."
