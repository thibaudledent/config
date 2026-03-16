#!/usr/bin/env bash
#
# log-utils.sh — shared logging utilities
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/log-utils.sh"
#

if [[ -t 1 ]]; then
    _LOG_RED='\033[0;31m'; _LOG_GREEN='\033[0;32m'; _LOG_YELLOW='\033[1;33m'
    _LOG_BLUE='\033[0;34m'; _LOG_CYAN='\033[0;36m'; _LOG_BOLD='\033[1m'
    _LOG_DIM='\033[2m'; _LOG_RESET='\033[0m'
else
    _LOG_RED='' _LOG_GREEN='' _LOG_YELLOW='' _LOG_BLUE='' _LOG_CYAN='' _LOG_BOLD='' _LOG_DIM='' _LOG_RESET=''
fi

log_info()    { echo -e "${_LOG_BLUE}[INFO]${_LOG_RESET}  $*"; }
log_ok()      { echo -e "${_LOG_GREEN}[OK]${_LOG_RESET}    $*"; }
log_warn()    { echo -e "${_LOG_YELLOW}[WARN]${_LOG_RESET}  $*"; }
log_error()   { echo -e "${_LOG_RED}[ERR]${_LOG_RESET}   $*" >&2; }
log_section() { echo -e "\n${_LOG_BOLD}${_LOG_CYAN}── $* ──${_LOG_RESET}\n"; }

# Print a summary of failures. Pass an array of failure messages.
# Usage: log_failures "${failures[@]}"
log_failures() {
    local count=$#
    if (( count == 0 )); then return 0; fi
    echo ""
    log_error "${_LOG_BOLD}${count} failure(s):${_LOG_RESET}"
    for msg in "$@"; do
        echo -e "  ${_LOG_RED}✘${_LOG_RESET} $msg"
    done
    echo ""
}
