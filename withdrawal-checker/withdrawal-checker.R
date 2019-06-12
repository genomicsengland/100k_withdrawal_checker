#-- script to check for new withdrawals
rm(list = objects())
options(stringsAsFactors = FALSE,
	scipen = 200)
library(methods)
library(slackr)
library(RPostgreSQL)
library(wrangleR)

# - set working directory
setwd('/home/cdt_deploy/jenkins_builds/daily-data-checks/withdrawal-checker')

#--set up slackr info (webhook etc.)
slackr_setup(channel = "withdrawal-alert",
	     incoming_webhook_url="https://hooks.slack.com/services/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",
	     api_token ="xoxp-3407199151-80074460915-381114212677-e72d5ed2c785e26df76168b5d9bc92bf")

#-- read in the list of fully withdrawn participants
read.withdrawals <- function(){
	tryCatch(
		{drv <- dbDriver("PostgreSQL")
		mis.con <- dbConnect(drv,
			     dbname = "gel_mi",
			     host = "10.1.24.37",
			     port = 5432,
			     user = "sthompson",
			     password = "password")
		curr <- dbGetQuery(mis.con, "SELECT participant_id FROM cdm.vw_participant_level_data WHERE withdrawal_option_id='FULL_WITHDRAWAL'")
		dbdisconnectall()
		prev <- readRDS("withdrawn.rds")
		list("current" = curr[[1]], "previous" = prev)
		},
		error=function(err){
			return(err[[1]])
		}
	)
}

withdrawals <- read.withdrawals()

if(class(withdrawals) == "list" & all(names(withdrawals) == c("current", "previous"))){
	new.withdrawals <- withdrawals[["current"]][!withdrawals[["current"]] %in% withdrawals[["previous"]]]
	if(length(new.withdrawals) > 0){
		ids <- paste(new.withdrawals, collapse = "\n")
		slackr_msg(paste(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n @here *New FULL withdrawals submitted:*\n", ids))
		saveRDS(withdrawals[["current"]], "withdrawn.rds")
	} else {
		slackr_msg(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n It's a no-(full)withdrawals day")
	} 
} else {
	slackr_msg(paste(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n @here *ALERT THE WRANGLERS*, something went wrong:", withdrawals))
}
