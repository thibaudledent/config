#!/usr/bin/env bash

#  Extract variables from jira-settings.yaml file
PARENT_DIR=$(echo "$PWD" | sed 's/\/time-cheat$//')
source "$PARENT_DIR/load-settings.sh" "$PARENT_DIR/jira-settings.yaml"

START_DATE=$1  # e.g. 2022-01-07
GIT_DIRECTORY=$2  # e.g. /home/john/Documents
E_MAIL=${4:-$(git config user.email)}  # e.g. john.doe@company.com

cd "$(dirname "$0")" || exit

./find-my-commits.sh "$START_DATE" "$GIT_DIRECTORY" "$E_MAIL" > /dev/null 2>&1

SEPARATOR=','

for dates in $(sort /tmp/gitlog | awk '{print $2}' | uniq -c | awk '{print $2 "'${SEPARATOR}'" $1}'); do
  IFS="$SEPARATOR" read -ra date_with_nb_commits < <(printf '%s' "$dates")
  CURRENT_DATE=${date_with_nb_commits[0]}
  TOTAL_NUMBER_OF_COMMITS_FOR_CURRENT_DATE=${date_with_nb_commits[1]}

  for commits in $(sort /tmp/gitlog | awk '{print $2" "$6}' | sort | uniq -c | grep "$CURRENT_DATE" | awk '{print $1 "'${SEPARATOR}'" $3}'); do
    IFS="$SEPARATOR" read -ra jira_issue_with_number_of_commits < <(printf '%s' "$commits")
    NUMBER_OF_COMMITS_FOR_CURRENT_DATE_AND_JIRA_ISSUE=${jira_issue_with_number_of_commits[0]}
    JIRA_ISSUE=${jira_issue_with_number_of_commits[1]}
    TIME_TO_LOG=$(echo "scale=5;8 * $NUMBER_OF_COMMITS_FOR_CURRENT_DATE_AND_JIRA_ISSUE/$TOTAL_NUMBER_OF_COMMITS_FOR_CURRENT_DATE" | bc | awk '{printf "%.2f", $0}')
    echo "$PWD/log-time-jira.sh ${JIRA_ISSUE//[^A-Z-0-9]/} $TIME_TO_LOG $CURRENT_DATE"
  done
done
