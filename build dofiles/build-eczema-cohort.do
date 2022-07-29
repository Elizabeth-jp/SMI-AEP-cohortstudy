/*******************************************************************************
DO FILE NAME:			build-eczema-cohort.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	06/10/2021

TASK:					Aim is to create eczema cohort
						
DATASET(S)/FILES USED:	getmatchedcohort-'eczema'-main-mhealth.dta
						outcome-'eczema'-smi.dta
						variables-'eczema'-age-sex-gp
						variables-'eczema'-BMI
						variables-'eczema'-smoking
						variables-'eczema'-ethnicity
						ecz-time-updated-variables
						
						smi-paths.do
						

DATASETS CREATED:		cohort-eczema-main
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
global filename "build-eczema-cohort"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

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
save "${pathCohort}/cohort-eczema-exposed", replace

/*******************************************************************************
#1.2: Deal with time-updated variables
*******************************************************************************/
*merge in time-updated variables dataset
merge 1:m patid using "${pathCohort}/ecz-time-updated-variables"

keep if exposed==1

sort patid date

*formatting
*recode those with severity missing as having mild severity
recode modsevere (.=0)
label define severe 0 "mild" 1"moderate" 2"severe"
label values modsevere severe
*recode those with missing harmful alcohol, sleep and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi (.=0)

drop _merge

*drop records before index date and after follow-up
order patid date indexdate end*
sort patid date  

drop if date<indexdate

drop if date!=. & date>enddate_incSMI

*merge in exposed cohort 
merge m:1 patid using "${pathCohort}/cohort-eczema-exposed"

recode modsevere (.=0)

drop _merge

unique patid
*number of exposed individuals left = 1,023,551

*save the dataset
save "${pathCohort}/cohort-eczema-exposed", replace

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
save "${pathCohort}/cohort-eczema-unexposed", replace

/*******************************************************************************
#2.2: Deal with time-updated variables
*******************************************************************************/
*merge in time-updated variables dataset
merge 1:m patid using "${pathCohort}/ecz-time-updated-variables"

keep if exposed==0
drop modsevere
*as this is unexposed

sort patid date

*formatting

*recode those with missing harmful alcohol, sleep and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi(.=0)

drop _merge

*drop records before index date and after follow-up
order patid date indexdate end*
sort patid date  

drop if date<indexdate

drop if date!=. & date>enddate_incSMI

*merge in exposed cohort 
merge m:1 patid using "${pathCohort}/cohort-eczema-unexposed"

drop _merge

unique patid
*number of exposed individuals left = 4,952,020

*save the dataset
save "${pathCohort}/cohort-eczema-unexposed", replace

/*******************************************************************************
#3: Create a dataset including data for both exposed and unexposed
*******************************************************************************/
append using "${pathCohort}/cohort-eczema-exposed"

*recode those with missing harmful alcohol, sleep and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi(.=0)

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
save "${pathCohort}/cohort-eczema-main", replace

*delete interim datasets
erase "${pathCohort}/cohort-eczema-exposed.dta"
erase "${pathCohort}/cohort-eczema-unexposed.dta"

/*******************************************************************************
#5: Merge in other variables
*******************************************************************************/
* merge in age, sex and gp data
merge m:1 patid using "${pathIn}/variables-ecz-age-sex-gp.dta"
keep if _merge==3
drop _merge

*merge in practice level carstairs
merge m:1 pracid using "${pathIn}/variables-practice-carstairs.dta"
keep if _merge==3
drop _merge

*merge in BMI 
merge m:1 patid using "${pathIn}/variables-ecz-BMI-all.dta"
keep if _merge==3
drop _merge

*merge in ethnicity
merge m:1 patid using "${pathIn}/variables-ecz-ethnicity.dta"
keep if _merge==3
drop _merge

*merge in smoking data 
merge m:1 patid using "${pathIn}/variables-ecz-smoke-all.dta"
keep if _merge==3
drop _merge

*merge in charlson comorbidity 
merge m:1 patid using "${pathIn}/variables_ecz_cci.dta"
keep if _merge==3
drop _merge

*save the dataset
save "${pathCohort}/cohort-eczema-main", replace

*get rid of variables i no longer need 
drop set_exposed_mean valid_set dobmi eth16 eventdate cci_*

*categorise BMI 
gen bmi_cat=1 if bmi<18.5
replace bmi_cat=2 if bmi>=18.5 & bmi<=24.9
replace bmi_cat=3 if bmi>=25.0 & bmi<=29.9
replace bmi_cat=4 if bmi>=30
replace bmi_cat=. if bmi==.
label var bmi_cat "BMI category"
label define bmi_cat 1"underweight" 2"normal weight" 3"overweight" 4"obese"
label values bmi_cat bmi_cat

*generate age at cohort entry
*map index date to year and subtract yob to calculate age at indexdate
gen year_index=year(indexdate)
gen age_entry=year_index-realyob
drop year_index

gen age_grp=1 if age_entry>=18 & age_entry<=29
replace age_grp=2 if age_entry>=30 & age_entry<=39
replace age_grp=3 if age_entry>=40 & age_entry<=59
replace age_grp=4 if age_entry>=60  

label var age_grp "Age group at cohort entry (index date)"
label define age_grp 1"18-29" 2"30-39" 3"40-59" 4"60+" 
label values age_grp age_grp

*re-label ethnicity 
label var eth5 "Ethnicity"
label define eth 0"White" 1"South Asian" 2"Black" 3"Other" 4"Mixed" 5"Not Stated"
label values eth5 eth

*rename variables
rename modsevere eczema_severity
rename gender sex

*label variables
label var harmfulalcohol "Harmful alcohol 0=No, 1=Yes"
label var sleep "Sleep problems 0=No, 1=Yes"

*save the dataset
save "${pathCohort}/cohort-eczema-main", replace

/*******************************************************************************
#6: Create an end date for each record to take multiple records into account
*******************************************************************************/
sort patid indexdate date // make sure it's in the correct order
gen end=date[_n+1]-1 /// the end of record will be the day before the start of the next record
	if patid==patid[_n+1] & /// if it's the same person
	indexdate==indexdate[_n+1] /// and the same indexdate
	
format %td end

replace end=enddate_incSMI+1 if end==. & smi==1 
*will end the day after smi - prevents stata from not including multiple observations

replace end=enddate_incSMI if end==.
*will end at regular enddate

*save the dataset
save "${pathCohort}/cohort-eczema-main", replace

/*******************************************************************************
#7: stset the data with age as the underlying timescale
*******************************************************************************/
stset end, fail(smi==1) origin(realyob) enter(indexdate) id(patid) scale(365.25) 
/*
32 observation end on or before enter 
- this means that one of the records for the participants ends on the index date 
*/

*save the dataset
save "${pathCohort}/cohort-eczema-main", replace
/*******************************************************************************
#7: stsplit the data
*******************************************************************************/
sort patid indexdate

/*
split on calendar time 
Study period runs from 2jan1997 to 31jan2020
1997-2003 
2004-2009 
2010-2015
2016-2020
*/

stsplit calendarperiod, after(time=d(1/1/1900)) at(97,104,110,116)
replace calendarperiod=calendarperiod+1900
label define period 1997"1997-2003" 2004"2004-2009" 2010"2010-2015" ///
	2016"2016-2020" 
label values calendarperiod period
label var calendarperiod "calendarperiod: observation interval"

/*******************************************************************************
#7: save data
*******************************************************************************/
label data "stset data for smi outcome"
notes: stset data for smi outcome

save "${pathCohort}/cohort-eczema-main", replace

/*******************************************************************************
#8: more tidying up of data
*******************************************************************************/
*recode those with missing harmful alcohol, sleep, steroids and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi (.=0)
recode steroids (.=0)

save "${pathCohort}/cohort-eczema-main", replace
log close
exit


/*
test analysis
stcox i.exposed, strata(setid) level(95) base //crude RR=1.16 (1.12, 1.21)
*/

