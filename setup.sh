#!/usr/bin/env bash
set -Eeuxo pipefail

# GNOME EXTENSIONS
if command -v gnome-shell &>/dev/null; then
  bash "${PWD}"/scripts/install-gnome-extensions.sh
else
  echo "Error: gnome-shell not found, skipping GNOME extensions install."
fi

# DEV ENVIRONMENT
bash "${PWD}"/scripts/dev-setup.sh

# ZSH
if [ ! -d "$HOME/.oh-my-zsh" ];
then
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
  # then log out and log back in
fi

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

# MAVEN SETTINGS
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
fi

echo "Setup done!"
echo "To try zsh immediately, type 'zsh' in your current terminal."
