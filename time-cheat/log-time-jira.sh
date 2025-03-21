#!/usr/bin/env bash

JIRA_TOKEN=$1  # from $JIRA_URL/secure/ViewProfile.jspa?selectedTab=com.atlassian.pats.pats-plugin:jira-user-personal-access-tokens
JIRA_ISSUE=$2
NUMBER_HOURS=$3
START_DATE=$4  # e.g. 2022-01-07
TIME_SPENT_IN_SECONDS=$(echo "scale=0;($NUMBER_HOURS * 60 * 60)/1" | bc)  # /1 to round to integer

# Documentation: Jira API to add a worklog
# https://docs.atlassian.com/software/jira/docs/api/REST/7.1.2/#api/2/issue-addWorklog
# E.g.:
# {
#     "comment": "I did some work here.",
#     "started": "2016-03-16T04:22:37.471+0000",
#     "timeSpentSeconds": 12000
# }

# curl -X GET \
#     -H "Authorization: Bearer ${JIRA_TOKEN}" \
#     -H "Content-Type: application/json" $JIRA_URL/rest/api/2/issue/$JIRA_ISSUE/worklog # | jq --arg date "2024-12-19" '.worklogs[] | select((.started[0:10]) == $date)'
# 
# curl -X DELETE \
#     -H "Authorization: Bearer ${JIRA_TOKEN}" \
#     -H "Content-Type: application/json" $JIRA_URL/rest/api/2/issue/$JIRA_ISSUE/worklog/$WORLOG_ID
# curl -X POST \
#     -d '{ "started": "'$START_DATE'T08:00:00.000+0000", "timeSpentSeconds": '$TIME_SPENT_IN_SECONDS', "comment": '$COMMENT' }' \
#     -H "Authorization: Bearer ${JIRA_TOKEN}" \
#     -H "Content-Type: application/json" $JIRA_URL/rest/api/2/issue/$JIRA_ISSUE/worklog

curl -X POST \
    -d '{ "started": "'$START_DATE'T08:00:00.000+0000", "timeSpentSeconds": '$TIME_SPENT_IN_SECONDS' }' \
    -H "Authorization: Bearer ${JIRA_TOKEN}" \
    -H "Content-Type: application/json" $JIRA_URL/rest/api/2/issue/$JIRA_ISSUE/worklog
