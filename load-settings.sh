#!/usr/bin/env bash

CONFIG_FILE="$1"

if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: source load-settings.sh /path/to/jira-settings.yaml"
  return 1 2>/dev/null || exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  return 1 2>/dev/null || exit 1
fi

# Read all key=value pairs, ignoring comments and empty lines
while IFS='=' read -r key value; do
  # Skip lines that aren't valid key=value
  if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    export "$key"="$value"
  fi
done < <(grep -vE '^\s*#|^\s*$' "$CONFIG_FILE")