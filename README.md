# 100k Withdrawal Checker

This script checks for any new withdrawals in the relevant table in the MIS database and, if there are any, posts a message to Slack and creates a JIRA ticket.
This is the trigger for a variety of teams to process that withdrawal.

The script requires R4.0.3 and also a Slack Bot who has been invited to the relevant Slack channel.
The `slackr` package requires a `.slackr` file which contains the following:

```
bot_user_oauth_token: <bot oauth token>
channel: #simon-test
username: dq_report_bot
incoming_webhook_url: <incoming webhook url>
```

The specific values for these can be found [in the Logins section of the CDT Confluence site](https://cnfl.extge.co.uk/display/CDT/_Logins#id-_Logins-dq_report_bot).
