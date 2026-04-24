#!/usr/bin/env bash
#
# Interactively delete Jira worklogs authored by the current user.
#
# Usage:
#   ./delete-my-worklogs.sh <date>                       [--dry-run] [--all]
#   ./delete-my-worklogs.sh <from-date> <to-date>        [--dry-run] [--all]
#
# Flags:
#   --dry-run   Show what would be deleted; make no API calls to DELETE.
#   --all       Skip per-entry selection; delete every listed worklog
#               (still requires final 'yes' confirmation).
#
# Safety:
#   * Nothing is deleted without an explicit 'yes'.
#   * --dry-run overrides everything: zero DELETE requests are issued.

set -euo pipefail

# --- Settings ---
PARENT_DIR=$(echo "$PWD" | sed 's/\/time-cheat$//')
# shellcheck disable=SC1091
source "$PARENT_DIR/load-settings.sh" "$PARENT_DIR/jira-settings.yaml"

AUTH_STRING=$(echo -n "${JIRA_EMAIL}:${JIRA_TOKEN}" | base64 -w 0)
API="${JIRA_URL}/rest/api/3"

# --- Args parsing ---
DRY_RUN=false
SELECT_ALL=false
POSITIONAL=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --all)     SELECT_ALL=true ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <date> | <from-date> <to-date> [--dry-run] [--all]" >&2
  exit 1
fi
FROM_DATE="$1"
TO_DATE="${2:-$1}"

for d in "$FROM_DATE" "$TO_DATE"; do
  if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: invalid date '$d'" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- 1. Fetch + display via sibling script ---
echo "=== Fetching worklogs between $FROM_DATE and $TO_DATE ==="
"$SCRIPT_DIR/list-my-worklogs.sh" "$FROM_DATE" "$TO_DATE"

TSV_FILE="/tmp/jira-worklogs-${FROM_DATE}_${TO_DATE}.tsv"
if [[ ! -s "$TSV_FILE" ]]; then
  echo "Nothing to delete." >&2
  exit 0
fi

mapfile -t ENTRIES < "$TSV_FILE"
TOTAL=${#ENTRIES[@]}

# --- 2. Selection phase ---
TO_DELETE=()

if $SELECT_ALL; then
  TO_DELETE=("${ENTRIES[@]}")
else
  echo
  echo "Select worklogs to delete:"
  echo "  - Enter comma-separated row numbers (e.g. 1,3,5)"
  echo "  - Enter 'all' to select everything"
  echo "  - Enter 'q' to abort"
  echo
  for i in "${!ENTRIES[@]}"; do
    printf '  [%d] %s\n' "$((i+1))" "${ENTRIES[$i]}"
  done
  echo
  read -rp "Selection: " SELECTION

  case "$SELECTION" in
    q|Q|"") echo "Aborted."; exit 0 ;;
    all|ALL) TO_DELETE=("${ENTRIES[@]}") ;;
    *)
      IFS=',' read -ra IDX_LIST <<< "$SELECTION"
      for raw in "${IDX_LIST[@]}"; do
        idx="${raw// /}"
        if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > TOTAL )); then
          echo "ERROR: invalid index '$raw' (must be 1..$TOTAL)" >&2
          exit 1
        fi
        TO_DELETE+=("${ENTRIES[$((idx-1))]}")
      done
      ;;
  esac
fi

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  echo "Nothing selected. Exiting."
  exit 0
fi

# --- 3. Confirmation ---
echo
echo "=== The following ${#TO_DELETE[@]} worklog(s) will be deleted ==="
{
  printf 'WORKLOG_ID\tISSUE\tDATE\tHOURS\tSUMMARY\n'
  printf '%s\n' "${TO_DELETE[@]}"
} | column -t -s $'\t'
echo

if $DRY_RUN; then
  echo "[DRY-RUN] No deletions will be performed. Exiting."
  exit 0
fi

read -rp "Type 'yes' to confirm deletion: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted. Nothing deleted."
  exit 0
fi

# --- 4. Deletion ---
FAILED=0
SUCCEEDED=0
for row in "${TO_DELETE[@]}"; do
  IFS=$'\t' read -r wl_id issue_key date hours summary <<< "$row"
  printf 'Deleting %s on %s (%sh) from %s ... ' "$wl_id" "$date" "$hours" "$issue_key"

  HTTP_CODE=$(curl -sS -o /tmp/jira-del-resp -w '%{http_code}' \
    -X DELETE \
    -H "Authorization: Basic ${AUTH_STRING}" \
    -H "Accept: application/json" \
    "${API}/issue/${issue_key}/worklog/${wl_id}" || echo "000")

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "OK"
    SUCCEEDED=$((SUCCEEDED+1))
  else
    echo "FAILED (HTTP $HTTP_CODE)"
    echo "  response: $(cat /tmp/jira-del-resp)" >&2
    FAILED=$((FAILED+1))
  fi
done

echo
echo "=== Summary: $SUCCEEDED deleted, $FAILED failed ==="
(( FAILED == 0 ))