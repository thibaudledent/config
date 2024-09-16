#!/usr/bin/env bash
set -Eeuxo pipefail

# Script to create symlinks for the configuration files

LN=$(which ln)
LN_OPTS="-f -s -v"

# ZSH
if [ ! -d "$HOME/.oh-my-zsh" ];
then
  sudo apt install zsh fzf terminator curl -y
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

# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/zsh/zshrc ~/.zshrc
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
if [ -e ~/.config/terminator/config ]
then
  "$LN" $LN_OPTS "${PWD}"/terminator/config ~/.config/terminator/config
fi

# SYMLINKS FOR SCRIPTS
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/scripts/sort-json.sh ~/sort-json.sh
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/scripts/find-my-commits.sh ~/find-my-commits.sh
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/scripts/generate-password.sh ~/generate-password.sh
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/scripts/create-note.sh ~/create-note.sh
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/scripts/update-all-repos.sh ~/update-all-repos.sh
# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/scripts/create-jira.py ~/create-jira.py

# MAVEN SETTINGS
# Overriding your Maven user settings in ${user.home}/.m2/settings.xml
if [ -e ~/.m2/settings.xml ]
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

  # shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
  mkdir -p ~/.m2
  "$LN" $LN_OPTS "${PWD}"/maven/settings_with_api_key.xml ~/.m2/settings.xml
fi

echo "Setup done!"
