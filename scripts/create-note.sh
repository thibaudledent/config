#!/usr/bin/env bash
set -Eeuo pipefail

echo "$1" | mail -s subject user@gmail.com