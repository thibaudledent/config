#!/usr/bin/env bash
set -eEuxo pipefail

mydir=$1
count=0

while IFS= read -r -d '' file
do 
    (( count++ ))
    jq -S '.' "$file" > "$file"_sorted;
    mv "$file"_sorted "$file";
done < <(find "$mydir" -name '*.json' -print0)

echo "Updated $count files."
