#!/usr/bin/env bash
set -eEuxo pipefail

echo "$1" | mail -s "New note" user@gmail.com