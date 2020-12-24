#!/usr/bin/env bash
set -eEuxo pipefail

find . -type d -name .git | while read -r i;
do
    DIR=$(dirname "$i")
    cd "$DIR" || exit
    git remote -v
    cd .. || exit
done