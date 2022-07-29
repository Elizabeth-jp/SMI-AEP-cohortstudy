/*******************************************************************************
DO FILE NAME:			outcome-smi-all.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	11/01/2022

TASK:					Aim is to create an smi outcome variable containing all 
						smi codes for use in sensitivity analyses
						
DATASET(S)/FILES USED:	pso-smi-all
						ecz-smi-all
						smi-paths
						

DATASETS CREATED:		outcome-pso-smi-all
						outcome-ecz-smi-all
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
global filename "outcome-smi-all"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create outcome variable for eczema cohort
*******************************************************************************/
*load definite smi data for eczema cohort
use "${pathDatain}/variables-ecz-smi-all.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates
count if missing(eventdate) // no missing eventdates

*generate smi variable
gen smi_all=1
label variable smi_all "All smi diagnosis"
recode smi_all(.=0)

*create labels for the smi data
label define smilabel1 0 "no" 1 "yes"
label values smi_all smilabel1

*rename eventdate variable
rename eventdate date

*save the dataset
compress
save "${pathIn}/outcome-ecz-smi-all", replace

/*******************************************************************************
Create outcome variable for psoriasis cohort
*******************************************************************************/
*load definite smi data for psoriasis cohort
use "${pathDatain}/variables-pso-smi-all.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates
count if missing(eventdate) // no missing eventdates

*generate smi variable
gen smi_all=1
label variable smi_all "All smi diagnosis"
recode smi_all(.=0)

*create labels for the smi data
label define smilabel1 0 "no" 1 "yes"
label values smi_all smilabel1

*rename eventdate variable
rename eventdate date

*save the dataset
compress
save "${pathIn}/outcome-pso-smi-all", replace

log close
exit