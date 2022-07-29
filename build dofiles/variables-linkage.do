/*******************************************************************************
DO FILE NAME:			variables-linkage.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	18/11/2021

TASK:					Aim is to create linkage variables from linked data
						
DATASET(S)/FILES USED:	patient_carstairs_20_051.txt
						practice_carstairs_20_051.txt
						practice_urban_rural_20_051.txt
						smi-paths.do
						

DATASETS CREATED:		variables-patient-carstairs
						variables-practice-carstairs
						variables-practice-urban-rural
						
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
global filename "variables-linkage"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
Create carstairs variables
*******************************************************************************/
import delimited "${pathLinkage}/patient_carstairs_20_051.txt", clear

rename carstairs2011_5 patient_carstairs 
drop pracid

/*
Carstairs scores are in quintiles
1 being the least deprived and 5 the most deprived
*/

*save the dataset
compress
save "${pathIn}/variables-patient-carstairs", replace

import delimited "${pathLinkage}/practice_carstairs_20_051.txt", clear
rename carstairs2011_5 practice_carstairs
drop country

*save the dataset
compress
save "${pathIn}/variables-practice-carstairs", replace

/*******************************************************************************
Create rural/urban variable
*******************************************************************************/
import delimited "${pathLinkage}/practice_urban_rural_20_051.txt", clear

*create variable to take all rural/urban classifications in diff. countries into account
generate rural_urban=.
*northern ireland
replace rural_urban=1 if ni2015_urban_rural==1
replace rural_urban=2 if ni2015_urban_rural==2
*england
replace rural_urban=1 if e2011_urban_rural==1
replace rural_urban=2 if e2011_urban_rural==2
*wales
replace rural_urban=1 if w2011_urban_rural==1
replace rural_urban=2 if w2011_urban_rural==2
*scotland
replace rural_urban=1 if s2016_urban_rural==1
replace rural_urban=2 if s2016_urban_rural==2

drop country ni2015_urban_rural e2011_urban_rural w2011_urban_rural s2016_urban_rural

*label 
label define rural 1 "urban" 2 "rural"
label values rural_urban rural

*save the dataset
compress
save "${pathIn}/variables-practice-urban-rural", replace

log close
exit


