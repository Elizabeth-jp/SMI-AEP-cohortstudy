/*******************************************************************************
DO FILE NAME:			outcome-smi-definite.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	04/08/2021

TASK:					Aim is to create an smi outcome variable to be used to 
						create the cohort
						
DATASET(S)/FILES USED:	pso-smi-definite
						ecz-smi-definite
						smi-paths
						

DATASETS CREATED:		outcome-pso-smi
						outcome-ecz-smi
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
global filename "outcome-smi"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create outcome variable for eczema cohort
*******************************************************************************/
*load definite smi data for eczema cohort
use "${pathDatain}/variables-ecz-smi-definite.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates
count if missing(eventdate) // no missing eventdates

*generate smi variable
gen smi=1
label variable smi "Definite smi diagnosis"
recode smi(.=0)

*create labels for the smi data
label define smilabel 0 "no" 1 "yes"
label values smi smilabel

*rename eventdate variable
rename eventdate date

*save the dataset
compress
save "${pathIn}/outcome-ecz-smi-definite", replace

/*******************************************************************************
Create outcome variable for psoriasis cohort
*******************************************************************************/
*load definite smi data for psoriasis cohort
use "${pathDatain}/variables-pso-smi-definite.dta", clear

*check if there are duplicates 
duplicates report patid		// no duplicates
count if missing(eventdate) // no missing eventdates

*generate smi variable
gen smi=1
label variable smi "Definite smi diagnosis"
recode smi(.=0)

*create labels for the smi data
label define smilabel 0 "no" 1 "yes"
label values smi smilabel

*rename eventdate variable
rename eventdate date

*save the dataset
compress
save "${pathIn}/outcome-pso-smi-definite", replace

log close
exit





