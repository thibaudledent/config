#!/usr/bin/env bash

GIT_DIRECTORY=/path/to/my/folder/with/git/repositories
NAME=myname
START_DATE=2020-10-02

cd $GIT_DIRECTORY || exit
rm -f /tmp/gitlog

find . -type d -name .git | while read -r i; 
do 
    DIR=$(dirname "$i")
    cd "$DIR" || exit
    git log --pretty=format:"%at %ai %ae %s" --since="${START_DATE}T00:00:00" | grep -i $NAME | grep -Ev "Merge|Revert" >> /tmp/gitlog
    cd $GIT_DIRECTORY || exit
done

sort /tmp/gitlog | awk '{print $2" "$3" "$6}'
