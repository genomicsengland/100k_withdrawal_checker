# 100k Withdrawal Checker

This script checks for any new withdrawals in the relevant table in the MIS database and, if there are any, posts a message to Slack and creates a JIRA ticket.
This is the trigger for a variety of teams to process that withdrawal.

The following environment variables need to be added to a `.env` file:

```
MIS_DB_HOST
MIS_DB_PORT
MIS_DB_USER
MIS_DB_PWD
JIRA_USER
JIRA_PWD
JIRA_BASE_URL="https://jiraservicedesk.extge.co.uk"
GENERATE_TICKETS=<0 for no, 1 for yes>
SEND_SLACK_MESSAGES=<0 for no, 1 for yes>
SLACK_CHANNEL_ID
SLACK_BOT_TOKEN

```

The specific values for some of these can be found [in the Logins section of the CDT Confluence site](https://cnfl.extge.co.uk/display/CDT/_Logins#id-_Logins-withdrawal_checkerbot).

Relevant Slack channel IDs are:

```
simon-test - GNJ36MQNR
```
