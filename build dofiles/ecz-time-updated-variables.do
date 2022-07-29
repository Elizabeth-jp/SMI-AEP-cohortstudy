/*******************************************************************************
DO FILE NAME:			ecz-time-updated-variables.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	06/10/2021

TASK:					Create a dataset containing all the information
						on time-updated variables
						
DATASET(S)/FILES USED:	
						variables-'ecz'-harmfulalcohol
						variables-ecz-sleep
						variables-'eczema'-severity
						smi-paths.do
						

DATASETS CREATED:		ecz-time-updated-variables
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 16
clear all
set linesize 80

*change directory to the location of the paths file and run the file
run smi_paths

* create a filename global that can be used throughout the file
global filename "ecz-time-updated-variables"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
#1:Append info on time-updated variables
*******************************************************************************/
use "${pathIn}/variables-ecz-severity", clear 
append using "${pathIn}/variables-ecz-harmfulalcohol"
append using "${pathIn}/variables-ecz-sleep-definite"
append using "${pathIn}/outcome-ecz-smi-definite"
append using "${pathIn}/variables-ecz-steroids"

sort patid date
order patid date

*collapse on patid and date so there is one record per patient
collapse (firstnm) modsevere harmfulalcohol sleep smi steroids, by(patid date)

sort patid date

bysort patid: gen obs=_n
bysort patid: gen maxobs=_N
*check a patient id with complicated variables -chose 799178

local update " "modsevere" "harmfulalcohol" "sleep" "smi" "steroids" "

foreach a in `update' {
	gen state`a'=`a'
	replace state`a' = state`a'[_n-1] if 	/// set the `var' flag to the same as the record (i.e. previous date) before 
		state`a'==.	&						/// IF the flag is missing and
		patid == patid[_n-1] 				// IF this is same patient
} /*end foreach a in `toupdate' */

drop sleep modsevere harmfulalcohol smi steroids

rename statemodsevere modsevere
rename statesleep sleep
rename stateharmfulalcohol harmfulalcohol
rename statesmi smi
rename statesteroids steroids

drop obs maxobs

*save
save "${pathCohort}/ecz-time-updated-variables", replace

log close
exit