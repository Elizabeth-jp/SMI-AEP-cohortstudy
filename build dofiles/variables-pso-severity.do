/*******************************************************************************
DO FILE NAME:			variables-pso-severity.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	06/10/2021

TASK:					Aim is to create an psoriasis severity variable
						
DATASET(S)/FILES USED:	variables-pso-severity
						smi-paths.do
						

DATASETS CREATED:		variables-pso-severity
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
global filename "variables-pso-severity"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create psoriasis severity variable
*******************************************************************************/
*load data
use "${pathDatain}/variables-pso-severity.dta", clear

/* 
Patients were classified as having severe psoriasis once they had
received a systemic treatment (acitretin, etretinate, ciclosporin,
hydroxycarbamide, methotrexate,fumaric acid and apremilast), phototherapy, or
a biologic therapy (etanercept, adalimumab, infliximab, ustekinumab, brodalumab,
guselkumab, ixekizumab, secukinumab and efalizumab)
*/

count if date_severe!=.

keep if date_severe!=.

keep patid date_severe

*generate severity variable
generate severe=1 if date_severe!=.
rename severe psoriasis_severity

label define severelabel1 0"mild" 1 "moderate/severe"
label values psoriasis_severity severelabel1

rename date_severe date

*save the dataset
compress
save "${pathIn}/variables-pso-severity", replace

log close 
exit
