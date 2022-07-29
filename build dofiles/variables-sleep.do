/*******************************************************************************
DO FILE NAME:			variables-sleep.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	04/08/2021

TASK:					Aim is to create sleep problems variable to create the cohorts
						and for sensitivity analyses
						
DATASET(S)/FILES USED:	ecz-sleep-definite
						ecz-sleep-all
						smi-paths.do
						

DATASETS CREATED:		variables-ecz-sleep-definite
						variables-ecz-sleep-all
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
global filename "variables-sleep"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create definite sleep variable for eczema cohort
*******************************************************************************/
*load definite sleep problem data for eczema cohort
use "${pathDatain}/variables-ecz-sleep-definite.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates

*generate sleep problems variable
gen sleep=1
label variable sleep "Definite sleep problems"
recode sleep(.=0)

*create labels for the sleep data
label define sleeplabel 0 "no" 1 "yes"
label values sleep sleeplabel

rename eventdate date

*save the dataset
compress
save "${pathIn}/variables-ecz-sleep-definite", replace

/*******************************************************************************
Create sleep (all) variable for eczema cohort sensitivity analyses
*******************************************************************************/
*load definite sleep problem data for eczema cohort
use "${pathDatain}/variables-ecz-sleep-all.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates

*generate sleep problems variable
gen sleep_all=1
label variable sleep_all "All sleep problems"
recode sleep_all(.=0)

*create labels for the sleep data
label define sleeplabel1 0 "no" 1 "yes"
label values sleep_all sleeplabel1

rename eventdate date

*save the dataset
compress
save "${pathIn}/variables-ecz-sleep-all", replace


log close 
exit