# 100k Withdrawal Checker

This script checks for any new withdrawals in the relevant table in the MIS database and, if there are any, posts a message to Slack and creates a JIRA ticket.
This is the trigger for a variety of teams to process that withdrawal.

The script requires R4.0.3 and also a Slack Bot who has been invited to the relevant Slack channel.
