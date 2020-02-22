#!/bin/bash
set -Eeuxo pipefail

# Script to create symlinks for the configuration files

LN=$(which ln)
LN_OPTS="-f -s -v"

# ZSH
if [ ! -d "$HOME/.oh-my-zsh" ];
then
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
fi
#"$LN" $LN_OPTS "${PWD}"/zsh/custom ~/.zsh-custom
"$LN" $LN_OPTS "${PWD}"/zsh/zshrc ~/.zshrc
#"$LN" $LN_OPTS "${PWD}"/zsh/zlogin ~/.zlogin
#"$LN" $LN_OPTS "${PWD}"/zsh/aliases.zsh ~/.aliases.zsh


# MAVEN SETTINGS
# Overriding your Maven user settings in ${user.home}/.m2/settings.xml
set +x
echo -n "Enter your Maven settings.xml artifactory user: "
read -r user
echo -n "Enter your Maven settings.xml artifactory api key: "
read -rs key
echo -n "Enter your Maven settings.xml artifactory url: "
read -r url
echo ""

sed -e "s/USER_LOGIN/$user/" -e "s/USER_PASSWORD/$key/"  -e "s/ARTIFACTORY_URL/$url/" "${PWD}"/maven/settings.xml > "${PWD}"/maven/settings_with_api_key.xml
set -x

"$LN" $LN_OPTS "${PWD}"/maven/settings_with_api_key.xml ~/.m2/settings.xml

# SUBLIME TEXT
# TODO add config for sublime text (autocomplete)

# SCRIPTS
# TODO add my scripts sort-json, update all reposs... and create aliases for them so they can be used anywhere