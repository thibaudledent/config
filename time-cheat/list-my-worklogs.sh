#!/usr/bin/env bash
#
# List all Jira worklogs authored by the current user for a date or date range.
#
# Usage:
#   ./list-my-worklogs.sh <date>                    # single day, e.g. 2025-04-24
#   ./list-my-worklogs.sh <from-date> <to-date>     # inclusive range
#
# Output: tab-separated table with WorklogID, IssueKey, Date, Hours, Summary
# (designed to be both human-readable and pipe-friendly for delete-my-worklogs.sh)

set -euo pipefail

# --- Settings (reuse existing convention) ---
PARENT_DIR=$(echo "$PWD" | sed 's/\/time-cheat$//')
# shellcheck disable=SC1091
source "$PARENT_DIR/load-settings.sh" "$PARENT_DIR/jira-settings.yaml"

AUTH_STRING=$(echo -n "${JIRA_EMAIL}:${JIRA_TOKEN}" | base64 -w 0)
API="${JIRA_URL}/rest/api/3"

# --- Args ---
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <date> | <from-date> <to-date>   (YYYY-MM-DD)" >&2
  exit 1
fi
FROM_DATE="$1"
TO_DATE="${2:-$1}"

for d in "$FROM_DATE" "$TO_DATE"; do
  if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: invalid date '$d' (expected YYYY-MM-DD)" >&2
    exit 1
  fi
done

# --- Helpers ---
jira_curl() {
  # $1 = METHOD, $2 = PATH (relative to $API), optional $3 = JSON body
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method"
    -H "Authorization: Basic ${AUTH_STRING}"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
    -w "\n%{http_code}")
  [[ -n "$body" ]] && args+=(-d "$body")
  curl "${args[@]}" "${API}${path}"
}

check_http() {
  # Reads combined "body\nHTTP_CODE", splits them, exits on non-2xx.
  local response="$1" context="$2"
  local http_code="${response##*$'\n'}"
  local body="${response%$'\n'*}"
  if [[ ! "$http_code" =~ ^2 ]]; then
    echo "ERROR ($context): HTTP $http_code" >&2
    echo "$body" >&2
    return 1
  fi
  printf '%s' "$body"
}

# --- 1. Resolve current user's accountId (cached per run) ---
MYSELF=$(jira_curl GET "/myself")
MYSELF_BODY=$(check_http "$MYSELF" "fetching /myself")
ACCOUNT_ID=$(echo "$MYSELF_BODY" | jq -r '.accountId')
if [[ -z "$ACCOUNT_ID" || "$ACCOUNT_ID" == "null" ]]; then
  echo "ERROR: could not resolve current user accountId" >&2
  exit 1
fi

# --- 2. Find all issues where I logged work in [FROM_DATE, TO_DATE] ---
JQL="worklogAuthor = currentUser() AND worklogDate >= \"${FROM_DATE}\" AND worklogDate <= \"${TO_DATE}\""

declare -A SUMMARIES=()
NEXT_TOKEN=""

while : ; do
  if [[ -z "$NEXT_TOKEN" ]]; then
    SEARCH_PAYLOAD=$(jq -n --arg jql "$JQL" \
      '{jql: $jql, fields: ["summary"], maxResults: 100}')
  else
    SEARCH_PAYLOAD=$(jq -n --arg jql "$JQL" --arg tok "$NEXT_TOKEN" \
      '{jql: $jql, fields: ["summary"], maxResults: 100, nextPageToken: $tok}')
  fi

  SEARCH_RESP=$(jira_curl POST "/search/jql" "$SEARCH_PAYLOAD")
  SEARCH_BODY=$(check_http "$SEARCH_RESP" "JQL search")

  while IFS=$'\t' read -r key summary; do
    [[ -n "$key" ]] && SUMMARIES["$key"]="$summary"
  done < <(echo "$SEARCH_BODY" | jq -r '.issues[]? | [.key, .fields.summary] | @tsv')

  NEXT_TOKEN=$(echo "$SEARCH_BODY" | jq -r '.nextPageToken // empty')
  IS_LAST=$(echo "$SEARCH_BODY" | jq -r '.isLast // true')
  [[ -z "$NEXT_TOKEN" || "$IS_LAST" == "true" ]] && break
done

if [[ ${#SUMMARIES[@]} -eq 0 ]]; then
  echo "No issues found with worklogs by you between $FROM_DATE and $TO_DATE." >&2
  exit 0
fi

# --- 3. For each issue, fetch worklogs and filter by author + date range ---
# Emit TSV: worklog_id<TAB>issue_key<TAB>date<TAB>hours<TAB>summary
TSV_OUTPUT=""
for key in "${!SUMMARIES[@]}"; do
  WL_RESP=$(jira_curl GET "/issue/${key}/worklog")
  WL_BODY=$(check_http "$WL_RESP" "worklogs for $key") || continue

  FILTERED=$(echo "$WL_BODY" | jq -r \
    --arg aid "$ACCOUNT_ID" \
    --arg from "$FROM_DATE" \
    --arg to   "$TO_DATE" \
    --arg key  "$key" \
    --arg summary "${SUMMARIES[$key]}" '
      .worklogs[]
      | select(.author.accountId == $aid)
      | (.started[0:10]) as $d
      | select($d >= $from and $d <= $to)
      | [.id, $key, $d, ((.timeSpentSeconds / 3600) | tostring), $summary]
      | @tsv
    ')
  [[ -n "$FILTERED" ]] && TSV_OUTPUT+="${FILTERED}"$'\n'
done

if [[ -z "$TSV_OUTPUT" ]]; then
  echo "No matching worklogs found." >&2
  exit 0
fi

# --- 4. Display ---
# Sort by date, then issue key. Print header, then rows aligned with column(1).
{
  printf 'WORKLOG_ID\tISSUE\tDATE\tHOURS\tSUMMARY\n'
  printf '%s' "$TSV_OUTPUT" | sort -t$'\t' -k3,3 -k2,2
} | column -t -s $'\t'

# Also emit a machine-readable copy for the delete script to consume.
OUT_FILE="/tmp/jira-worklogs-${FROM_DATE}_${TO_DATE}.tsv"
printf '%s' "$TSV_OUTPUT" | sort -t$'\t' -k3,3 -k2,2 > "$OUT_FILE"
echo >&2
echo "Machine-readable output saved to: $OUT_FILE" >&2