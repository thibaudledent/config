#!/usr/bin/env bash
set -Eeuxo pipefail

# Script to create symlinks for the configuration files

LN=$(which ln)
LN_OPTS="-f -s -v"

# ZSH
if [ ! -d "$HOME/.oh-my-zsh" ];
then
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  # make zsh your default shell
  chsh -s $(which zsh)
  # then log out and log back in
fi

# shellcheck disable=SC2086 # ignore "Double quote to prevent globbing and word splitting" for $LN_OPTS
"$LN" $LN_OPTS "${PWD}"/zsh/zshrc ~/.zshrc

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
"$LN" $LN_OPTS "${PWD}"/scripts/get-remote.sh ~/get-remote.sh

# SUBLIME TEXT
# TODO add config for sublime text (autocomplete)

# TERMINATOR
# TODO font size, home directory

# MAVEN SETTINGS
# Overriding your Maven user settings in ${user.home}/.m2/settings.xml
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

