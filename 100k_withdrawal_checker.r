# script to check for new_withdrawals
rm(list = objects())
options(stringsAsFactors = FALSE,
    scipen = 200)
library(methods)
library(slackr)
library(DBI)
library(dotenv)

#set up environment
slackr_setup(config_file = ".slackr")

jira_base_url <- Sys.getenv("JIRA_BASE_URL")
generate_tickets <- Sys.getenv("GENERATE_TICKETS") == 1
send_slack_messages <- Sys.getenv("SEND_SLACK_MESSAGES") == 1
slack_channel <- Sys.getenv("SLACK_CHANNEL")


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
        if(!http_status(r)$category %in% "Success"){
            stop(paste("Unsuccessful attempt for",
                    r_url, "-", http_status(r)$message))
        }

        # return the key of the created ticket
        return(fromJSON(content(r, "text"))$key)

    } else {
        return("Not generating tickets")
    }
}

# function to send a message via slackr
send_slack_message <- function(msg, channel=slack_channel) {
    if (send_slack_messages == TRUE) {
        slackr(channel = channel, msg)
    } else {
        print(paste("channel: ", channel, "msg: ", msg))
    }
}

# read in the list of fully withdrawn participants
read_withdrawals <- function() {
    tryCatch( {
            mis_con <- dbConnect(RPostgres::Postgres(),
                 dbname = "gel_mi",
                 host = Sys.getenv("MIS_DB_HOST"),
                 port = Sys.getenv("MIS_DB_PORT"),
                 user = Sys,getenv("MIS_DB_USER"),
                 password = Sys.getenv("MIS_DB_PWD")
            )
            curr <- dbGetQuery(mis_con,
                "select participant_id
                from cdm.vw_participant_level_data
                where withdrawal_option_id='full_withdrawal';"
            )
            prev <- readRDS("withdrawn.rds")
            list("current" = curr[[1]], "previous" = prev)
        },
        error=function(err){
            return(err[[1]])
        }
    )
}

withdrawals <- read.withdrawals()

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
            "_THIS IS AN AUTOMATED MESSAGE_\n
            *New FULL withdrawals submitted:*\n",
            ids)
        )

        # generate a ticket for each one
        for (i in new_withdrawals) {
            #ticket_link <- create_jira_issue(i)
            send_slack_message(paste0(jira_base_url, '/browse/', ticket_link))
        }

        # write out the current withdrawals
        saveRDS(withdrawals[["current"]], "withdrawn.rds")

    } else {

        send_slack_message("_THIS IS AN AUTOMATED MESSAGE_\n
               It's a no-(full)withdrawals day")
    }

} else {
    send_slack_message(paste("_THIS IS AN AUTOMATED MESSAGE_\n
                 *ALERT THE WRANGLERS*, something went wrong:",
                 withdrawals))
}
