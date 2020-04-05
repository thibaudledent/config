#!/usr/bin/env bash
set -eEuxo pipefail

REPOSITORY_PATH="$PWD"
echo "Path to update: ${REPOSITORY_PATH}"

REPOSITORY=$(find "${REPOSITORY_PATH}" -type d -depth 1)

PARALLEL_CMD=$(command -v parallel)
if [ "x" == "x${PARALLEL_CMD}" ];
then
  echo "ERROR: Command 'parallel' not found, please install it:"
  echo "Ubuntu / Debian: sudo apt install parallel"
  echo "Mac OS X: brew install parallel"
  exit 1
fi

function updateOneRepo() {
	echo "";
	echo "Processing directory $1";
	cd "$1";
	git checkout master;
	git pull;
	git gc;
	git branch --merged | grep -v "master" | xargs git branch -d || true;
}

export -f updateOneRepo

function updateAllRepositories() {
  # Use parallel to multi-thread execution
  echo "${REPOSITORY[@]}" | "${PARALLEL_CMD}" --will-cite -P 0 updateOneRepo {} || EXIT_CODE=1
}

updateAllRepositories || EXIT_CODE=1

exit "${EXIT_CODE:-0}"
