/*******************************************************************************
DO FILE NAME:			variables-full-agesexGP.do

AUTHOR:					Alasdair Henderson (adapted from Elizabeth Adesanya)
						

VERSION:				v1
DATE VERSION CREATED: 	01/07/2021

TASK:					Aim is to extract age, sex and GP practice info on cohort
						
DATASET(S)/FILES USED:	Clinical_extract_ecz_extract3_`x'//CPRD clinical extract files 1 to 2
						Referral_extract_ecz_extract3_`x'//CPRD referral extract files 1 
						definite_diabetes_codes
						prog_getCodeCPRD
						skinepipaths
						

DATASETS CREATED:		variables-cluster-diabetes
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 15
clear all
set linesize 80

*find path file location and run it
skinepipaths_v2

* create a filename global that can be used throughout the file
global filename "variables-${ABBRVexp}-agesexGP"

*open log file
log using "${pathLogs}/${filename}", text replace 


/*******************************************************************************
#1. Extract data from patient file
*******************************************************************************/

use ${pathIn}/Patient_extract_${ABBRVexp}_extract3_1.dta, clear

desc

gen pracid = mod(patid,1000)

keep patid gender realyob pracid

save ${pathOut}/variables-${ABBRVexp}-age-sex-gp.dta, replace

tab pracid
summ realyob
tab gender, m