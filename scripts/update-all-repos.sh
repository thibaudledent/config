#!/usr/bin/env bash
set -eEuxo pipefail

# Default branch
BRANCH="master"

# Parse optional --branch argument
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      shift
      BRANCH="$1"
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--branch <branch-name>]"
      exit 1
      ;;
  esac
  shift
done

if [ -f "/etc/wsl.conf" ]; then
  GIT_CMD="$(wslpath "$(where.exe git | tr -d '\r')")"
else
  GIT_CMD="git"
fi

REPOSITORY_PATH="$PWD"
echo "Path to update: ${REPOSITORY_PATH}"

REPOSITORY=$(find "${REPOSITORY_PATH}" -type d | grep -v '_git' | grep 'git' | sed 's#.git.*##g' | sort --unique)

PARALLEL_CMD=$(command -v parallel)
if [ -z "${PARALLEL_CMD}" ]; then
  echo "ERROR: Command 'parallel' not found, please install it:"
  echo "Ubuntu / Debian: sudo apt install parallel"
  echo "Mac OS X: brew install parallel"
  exit 1
fi

function updateOneRepo() {
  echo ""
  echo "Processing directory $1"
  cd "$1"
  "$GIT_CMD" checkout "$BRANCH"
  "$GIT_CMD" pull
  "$GIT_CMD" gc
  "$GIT_CMD" branch --merged | grep -v "$BRANCH" | xargs "$GIT_CMD" branch -d || true
}

export -f updateOneRepo
export GIT_CMD BRANCH

function updateAllRepositories() {
  echo "${REPOSITORY[@]}" | "${PARALLEL_CMD}" --will-cite -P 0 updateOneRepo {} || EXIT_CODE=1
}

updateAllRepositories || EXIT_CODE=1

exit "${EXIT_CODE:-0}"
