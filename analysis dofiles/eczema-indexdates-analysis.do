/*******************************************************************************
DO FILE NAME:			eczema-indexdates-analysis.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	12/07/22

TASK:					Identify the percetage of the exposed eczema cohort whose 
						index date is the same as the date they fulfilled eczema 
						definitions
						
DATASET(S)/FILES USED:	cohort-eczema-main
						smi-paths.do
						
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
global filename "eczema-indexdates-analysis"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
RECREATE ECZEMA COHORT AND PRESERVE MATCHING (don't time-update variables)
*******************************************************************************/
/*******************************************************************************
#1.1: DEAL WITH EXPOSED GROUP FIRST
*******************************************************************************/
*load extracted eczema patient info (contains exposed and unexposed)
use "${pathIn}/getmatchedcohort-eczema-main-mhealth.dta", clear

drop bign
label var setid "matched set id"
label var patid "patient id"
label var exposed "1: eczema exposed; 0: unexposed"
label def exposed 1"exposed" 0"unexposed"
label values exposed exposed
label var enddate "end of follow-up as exposed/unexposed"
label var indexdate "start of follow-up"

keep if exposed==1
sort patid indexdate
order patid indexdate enddate

*add in smi outcome dates
merge 1:1 patid using "${pathIn}/outcome-ecz-smi-definite.dta"
rename date smi_date

*create new enddate taking date of SMI diagnosis into account
gen enddate_incSMI=min(enddate, smi_date)
format %td enddate_incSMI

*drop individuals who aren't exposed 
drop if exposed==.

*identify those with SMI before indexdate (need to be excluded)
gen earlysmi=1 if smi_date<=indexdate 
count if earlysmi==1
*number of people = 9,231

drop if earlysmi==1

*drop variables no longer needed
drop earlysmi smi _merge smi_date

unique patid
*number of exposed individuals left = 1,023,551

*save the dataset
save "${pathCohort}/cohort-eczema-indexexposed", replace


/*******************************************************************************
#2.1: DEAL WITH UNEXPOSED GROUP 
*******************************************************************************/
*load extracted eczema patient info (contains exposed and unexposed)
use "${pathIn}/getmatchedcohort-eczema-main-mhealth.dta", clear

drop bign
label var setid "matched set id"
label var patid "patient id"
label var exposed "1: eczema exposed; 0: unexposed"
label def exposed 1"exposed" 0"unexposed"
label values exposed exposed
label var enddate "end of follow-up as exposed/unexposed"
label var indexdate "start of follow-up"

keep if exposed==0
sort patid indexdate
order patid indexdate enddate

*add in smi outcome dates
merge 1:1 patid using "${pathIn}/outcome-ecz-smi-definite.dta"
rename date smi_date

*create new enddate taking date of SMI diagnosis into account
gen enddate_incSMI=min(enddate, smi_date)
format %td enddate_incSMI

*drop individuals who aren't exposed 
drop if exposed==.

*identify those with SMI before indexdate (need to be excluded)
gen earlysmi=1 if smi_date<=indexdate 
count if earlysmi==1
*number of people = 38,105

drop if earlysmi==1

*drop variables no longer needed
drop earlysmi smi _merge smi_date

unique patid
*number of exposed individuals left = 4,952,020

*save the dataset
save "${pathCohort}/cohort-eczema-indexunexposed", replace


/*******************************************************************************
#3: Create a dataset including data for both exposed and unexposed
*******************************************************************************/
append using "${pathCohort}/cohort-eczema-indexexposed"

unique patid
*Total number of people is 5,760,850

unique patid if exposed==1
*Number of unique values of patid is  1,023,551

unique patid if exposed==0
*Number of unique values of patid is  4,952,020

/*******************************************************************************
#4: Preserve matching
*******************************************************************************/
bysort setid: egen set_exposed_mean = mean(exposed) 

*if mean of exposure var is 0 then only unexposed in set, if 1 then only exposed in set
gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1)

*==1 is valid set containing both exposed and unexposed
tab valid_set, miss
tab valid_set exposed, col
keep if valid_set==1

*43,961 unexposed individuals dropped
*319 exposed individuals dropped

unique patid
*Total number of people is 5,718,600

unique patid if exposed==1
*Number of unique values of patid is  1,023,232

unique patid if exposed==0
*Number of unique values of patid is  4,908,059

*save the dataset
save "${pathCohort}/cohort-eczema-indexmain", replace

*delete interim datasets
erase "${pathCohort}/cohort-eczema-indexexposed.dta"
erase "${pathCohort}/cohort-eczema-indexunexposed.dta"

/*******************************************************************************
KEEP ONLY EXPOSED INDIVIDUALS
*******************************************************************************/
keep if exposed==1
unique patid

/*******************************************************************************
MERGE IN DATASET THAT HAS DATES INDIVIDUALS FULFILLED ECZEMA DEFINITIONS
*******************************************************************************/
merge 1:1 patid using "${pathDatain}/eczemaExposed-eligible-mhealth.dta"
keep if _merge==3
drop _merge

count if indexdate==eczemadate
*536,457 exposed individuals indexdate is the same date they fulfilled the eczema definition

count if indexdate==eczemadateDx
*318,444 exposed individuals indexdate is the same date of the first diagnostic eczema code