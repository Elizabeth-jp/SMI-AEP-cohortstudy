/*******************************************************************************
DO FILE NAME:			variables-ecz-severity.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	06/10/2021

TASK:					Aim is to create an eczema severity variable
						
DATASET(S)/FILES USED:	variables-ecz-severity
						smi-paths.do
						

DATASETS CREATED:		variables-ecz-severity
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
global filename "variables-ecz-severity"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create eczema severity variable
*******************************************************************************/
*load data
use "${pathDatain}/variables-ecz-severity.dta", clear

*check if there are duplicates 
duplicates report patid		
*there are duplicates as people's severity changes

*generate severity variable
codebook modsevere
*1=moderate,2=severe

recode modsevere (.=0)
label define severelabel 0 "mild"
label values modsevere severelabel

*save the dataset
compress
save "${pathIn}/variables-ecz-severity", replace

log close 
exit
