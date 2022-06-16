#!/usr/bin/env bash

START_DATE=$1  # e.g. 2022-01-07
GIT_DIRECTORY=$2  # e.g. /home/john/Documents
E_MAIL=${3:-$(git config user.email)}  # e.g. john.doe@company.com

echo "Searching commits of $E_MAIL from $START_DATE in $GIT_DIRECTORY"

cd $GIT_DIRECTORY || exit
rm -f /tmp/gitlog

find . -type d -name .git | while read -r i; 
do
    DIR=$(dirname "$i")
    cd "$DIR" || exit
    git log --pretty=format:"%at %ai %ae %s" --since="${START_DATE}T00:00:00" | grep -i $E_MAIL | grep -Ev "Merge|Revert" >> /tmp/gitlog
    cd $GIT_DIRECTORY || exit
done

sort /tmp/gitlog | awk '{print $2" "$6}' | sort | uniq -c
