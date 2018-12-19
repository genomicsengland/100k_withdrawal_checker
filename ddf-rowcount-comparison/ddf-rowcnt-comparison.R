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
library(dplyr)
library(ascii)

#-- set up / establish slack channel notification
slackr_setup(channel="slackr-test", 
             incoming_webhook_url="https://hooks.slack.com/services/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",
             api_token = 'xoxp-3407199151-239224420817-256880855665-736d7287e5d7fb343361045f87ca54c5')

#Connect to db
drv <- dbDriver("PostgreSQL")
ddf.con <- dbConnect(drv, dbname = "gel_mi",
			host = "10.1.24.37",
			# host = "localhost",
			port = 5432,
			# port = 5440,
			user = "mwalker",
			password = "password")

# grab required data
gel.case <- dbGetQuery(ddf.con, "SELECT 'cdm.gel_case'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.gel_case")
participant <- dbGetQuery(ddf.con, "SELECT 'cdm.participant'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.participant")
rare.diseases.participant <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_participant'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_participant")
cancer.participant <- dbGetQuery(ddf.con, "SELECT 'cdm.cancer_participant'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.cancer_participant")
consent.form <- dbGetQuery(ddf.con, "SELECT 'cdm.consent_form'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.consent_form")
clinic.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.clinic_sample'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.clinic_sample")
lab.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.laboratory_sample'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.laboratory_sample")
plated.sample <- dbGetQuery(ddf.con, "SELECT 'cdm.plated_sample'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.plated_sample")
rd.fam.medrev <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_family_medical_review'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_family_medical_review")
rd.ped.member <- dbGetQuery(ddf.con, "SELECT 'cdm.rare_diseases_pedigree_member'::text AS tbl_name ,count(1) AS cur_tot FROM cdm.rare_diseases_pedigree_member")

# disconnect from db 
dbdisconnectall()

# rowbind results into single dataframe
cur <- rbind(gel.case, participant, rare.diseases.participant, cancer.participant, consent.form, clinic.sample, lab.sample, plated.sample, rd.fam.medrev, rd.ped.member)

# read in yesterdays row counts
old  <- readRDS('prev/prev_rowcnt.rds')

# merge and arrive at metrics
comp <-  left_join(cur, old, by='tbl_name') %>% mutate(diff = cur_tot-old_tot)
write.csv(comp, file='rowcnts_toPub.csv', row.names=F)

#export todays count for tomorrow
oldCnts <- dropnrename(cur, c('tbl_name', 'cur_tot'), c('tbl_name', 'old_tot')) # 
saveRDS(oldCnts, "prev/prev_rowcnt.rds")   

#rename columns for display
curDate <- format(Sys.time(), '%m/%d')
yesterDate <- format(Sys.time()-days(1), '%m/%d')
colnames(comp)  <- c('TABLE', paste(curDate, 'TOT'), paste(yesterDate, 'TOT'), 'DIFF')

# turn into ascii table
mis.data.checks <- ascii(comp, include.rownames = F, format=c('s', 'd', 'd'), header = F)  

slackr_msg(as_user=F,username='WranglerBot', paste('@here', 
		'\n Latest MIS data checks (todays row counts against yesterdays):\n'))
		slackr(mis.data.checks)
		slackr_msg(as_user=F, username='WranglerBot','\n\n:robot_face: _This is an automated message_ :robot_face:')
