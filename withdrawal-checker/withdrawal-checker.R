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

#-- get profile
p <- getprofile(c('cdt_bot_slack_api_token', 'ldap', 'mis_con'), file = '.gel_config')

#--set up slackr info (webhook etc.), config file at ~/.slackr
slackr_setup(channel = "#withdrawal-alert")

#-- function to create a service desk ticket
jira_base_url <- 'https://jiraservicedesk.extge.co.uk'
create_jira_issue <- function(participant_id){
        require(httr)
		require(jsonlite)
        r_url = paste0(jira_base_url, '/rest/api/2/issue')
		# template structure to create ticket
		d = list('fields' = list(
			'project' = list('key' = 'GEL'),
			'summary' = 'Full Participant Withdrawal',
			'description' = paste('Full withdrawal for participant', participant_id, 'has been received'),
			'issuetype' = list('name' = 'Service Request'))
		)
        # make the request
        r = POST(r_url, authenticate(p$ldap$user, p$ldap$password, type = 'basic'), body = d, encode = 'json')
		# check whether successful
        if(!http_status(r)$category %in% 'Success'){
                    stop(paste('Unsuccessful attempt for', r_url, '-', http_status(r)$message))
        }
		# return the key of the created ticket
		return(fromJSON(content(r, 'text'))$key)
}

#-- read in the list of fully withdrawn participants
read.withdrawals <- function(){
	tryCatch(
		{drv <- dbDriver("PostgreSQL")
		mis.con <- dbConnect(drv,
			     dbname = "gel_mi",
			     host = p$mis_con$host,
			     port = p$mis_con$port,
			     user = p$mis_con$user,
			     password = p$mis_con$password)
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

#-- if we've read the withdrawals ok
if(class(withdrawals) == "list" & all(names(withdrawals) == c("current", "previous"))){
	#-- get new withdrawals
	new.withdrawals <- withdrawals[["current"]][!withdrawals[["current"]] %in% withdrawals[["previous"]]]
	if(length(new.withdrawals) > 0){
		#-- post IDs to slack
		ids <- paste(new.withdrawals, collapse = "\n")
		slackr(paste(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n @here *New FULL withdrawals submitted:*\n", ids))
		#-- generate a ticket for each one
		for(i in new.withdrawals){
			ticket_link <- create_jira_issue(i)
			slackr(paste0(jira_base_url, '/browse/', ticket_link))
		}
		saveRDS(withdrawals[["current"]], "withdrawn.rds")
	} else {
		slackr(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n It's a no-(full)withdrawals day")
	} 
} else {
	slackr(paste(":robot_face: _THIS IS AN AUTOMATED MESSAGE_ :robot_face:\n @here *ALERT THE WRANGLERS*, something went wrong:", withdrawals))
}
