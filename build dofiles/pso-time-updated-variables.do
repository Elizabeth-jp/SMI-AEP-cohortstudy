/*******************************************************************************
DO FILE NAME:			pso-time-updated-variables.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	06/10/2021

TASK:					Create a dataset containing all the information
						on time-updated variables
						
DATASET(S)/FILES USED:	
						variables-'pso'-harmfulalcohol
						variables-'pso'-severity
						outcome-pso-smi-definite
						smi-paths.do
						

DATASETS CREATED:		pso-time-updated-variables
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
global filename "pso-time-updated-variables"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
#1:Append info on time-updated variables - exposed individuals
*******************************************************************************/
use "${pathIn}/variables-pso-severity", clear 
append using "${pathIn}/variables-pso-harmfulalcohol"
append using "${pathIn}/outcome-pso-smi-definite"

sort patid date
order patid date

*collapse on patid and date so there is one record per patient
collapse (firstnm) psoriasis_severity harmfulalcohol smi, by(patid date)

sort patid date

bysort patid: gen obs=_n
bysort patid: gen maxobs=_N

local update " "psoriasis_severity" "harmfulalcohol" "smi" "

foreach a in `update' {
	gen state`a'=`a'
	replace state`a' = state`a'[_n-1] if 	/// set the `var' flag to the same as the record (i.e. previous date) before 
		state`a'==.	&						/// IF the flag is missing and
		patid == patid[_n-1] 				// IF this is same patient
} /*end foreach a in `toupdate' */

drop psoriasis_severity harmfulalcohol smi 

rename statepsoriasis_severity psoriasis_severity
rename stateharmfulalcohol harmfulalcohol
rename statesmi smi

drop obs maxobs

*save
save "${pathCohort}/pso-time-updated-variables", replace

log close
exit