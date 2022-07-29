/*******************************************************************************
DO FILE NAME:			variables-${ABBRVexp}-smi.do
AUTHOR:					Elizabeth Adesanya
VERSION:				v1
DATE VERSION CREATED: 	12/04/2021
TASK:					Aim is to extract morbidity coded data for smi and
						create a smi variable for the ${ABBRVexp}ema cohort 
DATASET(S)/FILES USED:	${ABBRVexp}-Clinical-smi//${ABBRVexp}ema smi records from clinical file
						${ABBRVexp}-Referral-smi//${ABBRVexp}ema smi records from clinical file
						SkinEpiExtract-paths.do
						
DATASETS CREATED:		${ABBRVexp}-smi-definite//definite smi (main analysis)
						${ABBRVexp}-smi-all//definite and possible smi (sensitivity analysis)
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 15
clear all
set linesize 80

* change directory to the location of the paths file and run the file	
skinepipaths_v2


* create a filename global that can be used throughout the file
global filename "variables-${ABBRVexp}-smi-all"
di "${ABBRVexp}"
*open log file
log using "${pathLogs}/${filename}", text replace 

/*******************************************************************************
#1. Extract data from files in the CPRD Clinical or Referral files
*******************************************************************************/
* run program
run ${pathPrograms}/prog_getCodeCPRD

filelist , dir(${pathOut}) pattern("${ABBRVexp}-Clinical-smi*")
if `r(N)' < 1 {
	foreach filetype in Clinical Referral {
		if "`filetype'"=="Clinical" {
			local nfiles=$totalClinicalFiles
		}
		if "`filetype'"=="Referral" {
			local nfiles=$totalReferralFiles
		} 
		prog_getCodeCPRD, clinicalfile("${pathIn}/`filetype'_extract_${ABBRVexp}_extract3") ///
			clinicalfilesnum(`nfiles') ///
			codelist("${pathCodelists}/medcodes-smi-nohistory") /// 
			diagnosis(smi) ///
			savefile("${pathOut}/${ABBRVexp}-`filetype'-smi")
	} /*end foreach file in Clinical Referral*/
}

/*******************************************************************************
#1. Append ${ABBRVexp}ema anxiety data from all sources and identify definite smi
*******************************************************************************/
* append data sources
use "${pathOut}/${ABBRVexp}-Clinical-smi", clear
append using "${pathOut}/${ABBRVexp}-Referral-smi"

*only keep CPRD records for definite anxiety 
drop if possibleSMI==1

count if eventdate==.

*deal with date variables
replace eventdate=sysdate if eventdate==. & medcode!=.

count if eventdate==.
*no variables with missing eventdate

*only keep first event for each patient
keep patid eventdate constype readcode readterm //only keep useful data
sort patid eventdate 
bysort patid: keep if _n==1

*label and save
label data "${ABBRVexp}ema - earliest definite SMI diagnosis"
notes: ${ABBRVexp}ema - earliest definite smi diagnosis
notes: ${filename} / TS		
compress
save ${pathOut}/variables-${ABBRVexp}-smi-definite, replace

/*******************************************************************************
#1. Append ${ABBRVexp}ema anxiety data from all sources and identify definite 
	and possible smi
*******************************************************************************/
* append data sources
use "${pathOut}/${ABBRVexp}-Clinical-smi", clear
append using "${pathOut}/${ABBRVexp}-Referral-smi"

count if eventdate==.

*deal with date variables
replace eventdate=sysdate if eventdate==. & medcode!=.

count if eventdate==.
*no variables with missing eventdate

*only keep first event for each patient
keep patid eventdate constype readcode readterm //only keep useful data
sort patid eventdate 
bysort patid: keep if _n==1

*label and save
label data "${ABBRVexp}ema - earliest definite or possible smi diagnosis"
notes: ${ABBRVexp}ema - earliest definite or possible smi diagnosis
notes: ${filename} / TS		
compress
save ${pathOut}/variables-${ABBRVexp}-smi-all, replace


// Clean up files that are not necessary 
cap erase "${pathOut}/${ABBRVexp}-Clinical-smi.dta"
cap erase "${pathOut}/${ABBRVexp}-Referral-smi.dta"
log close
exit

