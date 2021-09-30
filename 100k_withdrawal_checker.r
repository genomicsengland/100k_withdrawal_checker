#-- script to check for new withdrawals
rm(list = objects())
options(stringsAsFactors = FALSE,
    scipen = 200)
library(methods)
library(slackr)
library(DBI)
library(dotenv)

#--set up environment
slackr_setup(channel = Sys.getenv("SLACK_CHANNEL"),
    incoming_webhook_url = Sys.getenv("SLACK_WEBHOOK"),
    bot_user_oauth_token = Sys.getenv("BOT_TOKEN"),
    username = Sys.getenv("BOT_USERNAME")
)

jira_base_url <- Sys.getenv("JIRA_BASE_URL")

#-- function to create a service desk ticket
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
}

#-- read in the list of fully withdrawn participants
read_withdrawals <- function() {
    tryCatch(
        {
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

#-- if we've read the withdrawals ok
if(class(withdrawals) == "list" & all(names(withdrawals) == c("current", "previous"))){
    #-- get new withdrawals
    new.withdrawals <- withdrawals[["current"]][!withdrawals[["current"]] %in% withdrawals[["previous"]]]
    if(length(new.withdrawals) > 0){
        #-- post IDs to slack
        ids <- paste(new.withdrawals, collapse = "\n")
        slackr(channel = "simon-test", paste(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n @here *New FULL withdrawals submitted:*\n", ids))
        #-- generate a ticket for each one
        for(i in new.withdrawals){
            ticket_link <- create_jira_issue(i)
            slackr(channel = "simon-test", paste0(jira_base_url, '/browse/', ticket_link))
        }
        saveRDS(withdrawals[["current"]], "withdrawn.rds")
    } else {
        slackr(channel = "simon-test", ":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n It's a no-(full)withdrawals day")
    } 
} else {
    slackr(channel = "simon-test", paste(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n @here *ALERT THE WRANGLERS*, something went wrong:", withdrawals))
}
