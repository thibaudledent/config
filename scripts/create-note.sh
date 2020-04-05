#!/usr/bin/env bash
set -Eeuo pipefail

echo "$1" | mail -s "New note" user@gmail.com