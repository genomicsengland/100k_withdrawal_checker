#-- Name: Script to check consents flagged as no
#-- Purpose: to check daily for any new registered participants which have said no to consenting
#-- Author: mwalker 20181025
#--Clear R environment and set environment options
rm(list=ls(all=T))
options(scipen = 200)

#--Bring in required packages
library(methods)
library(slackr)
library(RPostgreSQL)
library(wrangleR)
library(lubridate)

#-- set up / establish slack channel notification
slackr_setup(channel="@mwalker", 
            incoming_webhook_url="https://hooks.slack.com/services/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",
            api_token = 'xoxp-3407199151-239224420817-256880855665-736d7287e5d7fb343361045f87ca54c5')

# set working directory
setwd('/home/cdt_deploy/jenkins_build/daily-data-checks/no-to-consent-checker')

#-- for during testing, to reset prev dataframe to empty 
#NOTE: REMOVE ONCE AUTOMATING
# curr = data.frame('participant_id' = character(), 'handling_gmc' = character())
# saveRDS(curr, "prev/20181100_consent-no.rds")

curDate  <- as.numeric(format(today(), '%Y%m%d%h%s'))
files  <- list.files(path='./prev/')
lastData  <- files[1] 


#-- read in required data (i.e. participant ID and GMC where participant has said no to consent)
read.consent.nos <- function(){
	tryCatch(
		{drv <- dbDriver("PostgreSQL")
		mis.con <- dbConnect(drv,
			     dbname = "gel_mi",
			     host = "10.1.24.37",
			     # host = "localhost",
			     port = 5432,
			     # port = 5440,
			     user = "mwalker",
			     password = "password")
		curr <- dbGetQuery(mis.con, "SELECT DISTINCT participant_id, handling_gmc from cdm.vw_participant WHERE consent_given = 'No'")
		dbdisconnectall()
		prev <- readRDS(paste("prev/", lastData, sep=""))
		list("current" = curr, "previous" = prev)
		},
		error=function(err){
			return(err[[1]])
		}
	)
}

consent.nos <- read.consent.nos()

if(class(consent.nos) == "list" & all(names(consent.nos) == c("current", "previous"))){
	new.consent.nos <- consent.nos[["current"]][!consent.nos[["current"]] %in% consent.nos[["previous"]]]
	if(length(new.consent.nos) > 0){
		slackr_msg(paste('@here', 
				 '\n Latest list of participants who have said \'no\' to consent:\n'))
		slackr(new.consent.nos)
		slackr_msg('\n\n:robot_face: _This is an automated message_ :robot_face:')
		saveRDS(consent.nos[["current"]], paste("prev/", curDate, "_consent-no.rds", sep=""))
		file.remove(paste("prev/", lastData, sep=""))
	} else {
		slackr_msg(paste("Today, there are no new participants saying 'No' to consent.",
		 	   '\n\n:robot_face: _This is an automated message_ :robot_face:'))
	} 
} else {
	slackr_msg(paste("@here :rotating_light:ALERT THE WRANGLERS - something has gone wrong.:rotating_light: \n",
		 	   '\n\n:robot_face: _This is an automated message_ :robot_face:'))
}
