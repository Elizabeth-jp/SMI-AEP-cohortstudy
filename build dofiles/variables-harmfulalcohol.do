/*******************************************************************************
DO FILE NAME:			variables-harmfulalcohol.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	04/08/2021

TASK:					Aim is to create harmful alcohol variable to create the cohorts
						
DATASET(S)/FILES USED:	pso-harmfulalcohol
						ecz-harmfulalcohol
						smi-paths.do
						

DATASETS CREATED:		variables-pso-harmfulalcohol
						variables-ecz-harmfulalcohol
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
clear all
set linesize 80

*change directory to the location of the paths file and run the file
run smi_paths

* create a filename global that can be used throughout the file
global filename "variables-harmfulalcohol"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create harmful alcohol variable for eczema cohort
*******************************************************************************/
*load definite sleep problem data for eczema cohort
use "${pathDatain}/variables-ecz-harmfulalcohol.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates

*generate harmfulalcohol variable
gen harmfulalcohol=1
label variable harmfulalcohol "Harmful alcohol use"
recode harmfulalcohol(.=0)

*create labels for the sleep data
label define harmfullabel 0 "no" 1 "yes"
label values harmfulalcohol harmfullabel

rename eventdate date

*save the dataset
compress
save "${pathIn}/variables-ecz-harmfulalcohol", replace

/*******************************************************************************
Create harmful alcohol variable for psoriasis cohort
*******************************************************************************/
*load definite sleep problem data for eczema cohort
use "${pathDatain}/variables-pso-harmfulalcohol.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates

*generate harmfulalcohol variable
gen harmfulalcohol=1
label variable harmfulalcohol "Harmful alcohol use"
recode harmfulalcohol(.=0)

*create labels for the sleep data
label define harmfullabel 0 "no" 1 "yes"
label values harmfulalcohol harmfullabel

rename eventdate date

*save the dataset
compress
save "${pathIn}/variables-pso-harmfulalcohol", replace

log close
exit
