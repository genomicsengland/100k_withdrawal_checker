# script to check for new_withdrawals
rm(list = objects())
options(stringsAsFactors = FALSE,
    scipen = 200)
library(methods)
library(DBI)
library(dotenv)

#set up environment
jira_base_url <- Sys.getenv("JIRA_BASE_URL")
generate_tickets <- Sys.getenv("GENERATE_TICKETS") == 1
send_slack_messages <- Sys.getenv("SEND_SLACK_MESSAGES") == 1
slack_channel_id <- Sys.getenv("SLACK_CHANNEL_ID")

# function to create a service desk ticket
create_jira_issue <- function(participant_id) {
    require(httr)
    require(jsonlite)
    r_url <- paste0(jira_base_url, "/rest/api/2/issue")
    # template structure to create ticket
    d = list("fields" = list(
        "project" = list("key" = "GEL"),
        "summary" = "Full Participant Withdrawal",
        "description" = paste(
            "Full withdrawal for participant",
            participant_id,
            "has been received"
        ),
        "issuetype" = list("name" = "Service Request"))
    )
    # make the request
    if (generate_tickets == TRUE) {
        r <- POST(r_url,
            authenticate(
                Sys.getenv("JIRA_USER"),
                Sys.getenv("JIRA_PWD"),
                type = "basic"
            ), body = d, encode = "json")
        # check whether successful
        if (!http_status(r)$category %in% "Success") {
            stop(paste("Unsuccessful attempt for",
                    r_url, "-", http_status(r)$message))
        }
        # return the key of the created ticket
        return(fromJSON(content(r, "text"))$key)
    } else {
        return(paste("not_generating_tickets_", participant_id))
    }
}

# function to send a message via slackr
send_slack_message <- function(msg) {
    require(httr)
    require(jsonlite)
    r_url <- "https://slack.com/api/chat.postMessage"
    d = list(
             channel = slack_channel_id,
             token = Sys.getenv("SLACK_BOT_TOKEN"),
             blocks = paste0('[{"type": "section", "text":',
                             '{"type": "mrkdwn", "text": "',
                             msg, '"}}]')
    )
    if (send_slack_messages == TRUE) {
        r <- POST(r_url, body = d)
        # check whether successful
        if (!http_status(r)$category %in% "Success") {
            stop(paste("Unsuccessful attempt for",
                    r_url, "-", http_status(r)$message))
        }
        return(fromJSON(content(r, "text")))
    } else {
        print(paste("channel_id: ", slack_channel_id, "msg: ", msg))
    }
}

# read in the list of fully withdrawn participants
read_withdrawals <- function() {
    tryCatch({
            dams_con <- dbConnect(RPostgres::Postgres(),
                 dbname = "labkey",
                 host = Sys.getenv("DAMS_DB_HOST"),
                 port = Sys.getenv("DAMS_DB_PORT"),
                 user = Sys.getenv("DAMS_DB_USER"),
                 password = Sys.getenv("DAMS_DB_PWD")
            )
            curr <- dbGetQuery(dams_con,
                "select gc.participant_identifiers_id as participant_id
                from gelcancer.cancer_withdrawal gc
                where withdrawal_option_id ilike 'full_withdrawal'
                union
                select rd.participant_identifiers_id as participant_id
                from rarediseases.rare_diseases_withdrawal rd
                where withdrawal_option_id ilike 'full_withdrawal'
                ;"
            )
            prev <- readRDS("withdrawn.rds")
            list("current" = curr[[1]], "previous" = prev)
        },
        error = function(err) {
            return(paste(gsub("[\n\t\"]", " ", err[[1]]), collapse = " "))
        }
    )
}

withdrawals <- read_withdrawals()

# if we've read the withdrawals ok
if (class(withdrawals) == "list" &
   all(names(withdrawals) == c("current", "previous"))) {
    # get new_withdrawals
    new_withdrawals <- withdrawals[["current"]][!withdrawals[["current"]]
                                                %in% withdrawals[["previous"]]]
    if (length(new_withdrawals) > 0) {
        # post IDs to slack
        ids <- paste(new_withdrawals, collapse = "\n")
        send_slack_message(paste(
            ":ROBOT_FACE:_THIS IS AN AUTOMATED MESSAGE_:ROBOT_FACE:\n",
            "*New FULL withdrawals submitted:*\n")
        )
        # generate a ticket for each one
        for (i in new_withdrawals) {
            ticket_link <- paste0(jira_base_url, '/browse/', create_jira_issue(i))
            send_slack_message(paste0("<", ticket_link, "|", i, ">"))
        }
        # write out the current withdrawals
        saveRDS(withdrawals[["current"]], "withdrawn.rds")
    } else {
        send_slack_message(
            paste(":ROBOT_FACE:_THIS IS AN AUTOMATED MESSAGE_:ROBOT_FACE:\n",
                  "It's a no-(full)withdrawals day :thumbsup:"))
    }
} else {
    send_slack_message(
        paste(":ROBOT_FACE:_THIS IS AN AUTOMATED MESSAGE_:ROBOT_FACE:\n",
              ":alert:*ALERT THE WRANGLERS*, something went wrong:alert:\n",
              withdrawals))
}
