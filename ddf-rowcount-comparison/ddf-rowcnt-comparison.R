#-- Name: Script to check integrity of important labkey tables
#-- Purpose: to check important tables in ddf by counting rows and comparing to previous days count
#-- Author: mwalker 20181212
#--Clear R environment and set environment options
rm(list=ls(all=T))
options(scipen = 200)

# set working directory (UNCOMMENT ON SERVER)
# setwd('/home/cdt_deploy/jenkins_builds/daily-data-checks/ddf-rowcnt-comparison')

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


#-- for during testing, to reset prev dataframe to empty 
#NOTE: REMOVE ONCE AUTOMATING
# curr = data.frame('participant_id' = character(), 'handling_gmc' = character())
# saveRDS(curr, "prev/20181100_consent-no.rds")

# curDate  <- as.numeric(format(Sys.time(), '%Y%m%d%H%M%S'))
# files  <- list.files(path='prev/')
# lastData  <- files[1] 

drv <- dbDriver("PostgreSQL")
ddf.con <- dbConnect(drv, dbname = "central_data_repo",
			# host = "10.1.24.37",
			host = "localhost",
			# port = 5432,
			port = 5439,
			user = "mwalker",
			password = "password")

gel.case <- dbGetQuery(ddf.con, "SELECT 'cdm.gel_case'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.gel_case")

participant <- dbGetQuery(ddf.con, "SELECT 'cdm.participant'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.participant")
rare.diseases.participant <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_participant' AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_participant")
cancer.participant <- dbGetQuery(ddf.con, "SELECT 'cdm.cancer_participant' AS tbl_name ,count(1) AS cur_tot FROM cdm.cancer_participant")
consent.form <- dbGetQuery(ddf.con, "SELECT 'cdm.consent_form' AS tbl_name ,count(1) AS cur_tot FROM cdm.consent_form")
clinic.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.clinic_sample' AS tbl_name ,count(1) AS cur_tot FROM cdm.clinic_sample")
lab.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.laboratory_sample' AS tbl_name ,count(1) AS cur_tot FROM cdm.laboratory_sample")
plated.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.plated_sample' AS tbl_name ,count(1) AS cur_tot FROM cdm.plated_sample")
rd.fam.medrev <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_family_medical_review' AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_family_medical_review")
rd.ped.member <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_pedigree_member' AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_pedigree_member")



##-- read in required data 
#read.row.counts <- function(){
#	tryCatch(
#		{drv <- dbDriver("PostgreSQL")
#		ddf.con <- dbConnect(drv,
#			     dbname = "central_data_repo",
#			     # host = "10.1.24.37",
#			     host = "localhost",
#			     # port = 5432,
#			     port = 5439,
#			     user = "mwalker",
#			     password = "password")
#		gel.case <- dbGetQuery(ddf.con, "SELECT 'cdm.gel_case'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.gel_case")
#		participant <- dbGetQuery(ddf.con, "SELECT 'cdm.participant'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.participant")
#                # rare.diseases.participant <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_participant' AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_participant")
#                # cancer.participant <- dbGetQuery(ddf.con, "SELECT 'cdm.cancer_participant' AS tbl_name ,count(1) AS cur_tot FROM cdm.cancer_participant")
#                # consent.form <- dbGetQuery(ddf.con, "SELECT 'cdm.consent_form' AS tbl_name ,count(1) AS cur_tot FROM cdm.consent_form")
#                # clinic.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.clinic_sample' AS tbl_name ,count(1) AS cur_tot FROM cdm.clinic_sample")
#                # lab.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.laboratory_sample' AS tbl_name ,count(1) AS cur_tot FROM cdm.laboratory_sample")
#                # plated.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.plated_sample' AS tbl_name ,count(1) AS cur_tot FROM cdm.plated_sample")
#                # rd.fam.medrev <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_family_medical_review' AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_family_medical_review")
#                # rd.ped.member <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_pedigree_member' AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_pedigree_member")
#		dbdisconnectall()
#		# prev <- readRDS(paste("prev/", lastData, sep=""))
#		# list("current" = curr, "previous" = prev)
#		},
#		error=function(err){
#			return(err[[1]])
#		}
#	)
#}

row.counts <- read.row.counts()

# slackr_msg(paste('@here', 
# 		'\n Latest list of participants who have said \'no\' to consent:\n'))
# 		slackr(new.consent.nos)
# 		slackr_msg('\n\n:robot_face: _This is an automated message_ :robot_face:')
# 		saveRDS(consent.nos[["current"]], paste("prev/", curDate, "_consent-no.rds", sep=""))
