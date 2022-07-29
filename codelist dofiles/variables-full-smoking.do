/*******************************************************************************
DO FILE NAME:			variables-smoking.do

AUTHOR:					Elizabeth Adesanya
						uses code from KB smoking algorithm and KM adapted version
						that accomodates multiple index dates

VERSION:				v1
DATE VERSION CREATED: 	17/03/2021

TASK:					Aim is to identify smoking status based on the closest 
						record to the index date


MORE INFORMATION:		Will identify all smoking records for individuals in the
						eczema cohort, psoriasis cohort and sensitivity analyses
						cohorts

DATASET(S)/FILES USED:	CPRD Clinical extract files
						CPRD Additional extract files
						medcodes-smoking (smoking codelist)
						prog_getSmokingStatus
						SkinEpiExtract-paths.do
						

FILES CREATED:			variables-smoking-allrecs

*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 15
clear all
set linesize 80

* change directory to the location of the paths file and run the file	
skinepipaths_v2

* create a filename global that can be used throughout the file
global filename "variables-smoking"

*open log file
log using "${pathLogs}/${filename}", text replace 

/*******************************************************************************
#1. Extract ALL smoking status records for ALL cohorts
*******************************************************************************/
cd ${pathPrograms}
run prog_getSmokingStatus

prog_getSmokingStatus, clinicalfile(${pathIn}/Clinical_extract_ecz_extract3) ///
	clinicalfilesnum(14) ///
	additionalfile(${pathIn}/Additional_extract_ecz_extract3) ///
	additionalfilesnum(5)	/// 
	smokingcodelist(${pathCodelists}/medcodes-smoking) smokingstatusvar("smokstatus") ///
	savefile(${pathOut}/variables-smoking-allrecs)