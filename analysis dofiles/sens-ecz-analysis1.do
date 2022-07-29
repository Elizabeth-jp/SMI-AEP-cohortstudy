/*******************************************************************************
DO FILE NAME:			sens-ecz-analysis1.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	24/01/22

TASK:					Sensitivity analysis 1 - using less strict definitions of
						SMI (including symptom codes)
						
DATASET(S)/FILES USED:	getmatchedcohort-'eczema'-main-mhealth.dta
						outcome-'eczema'-smi.dta
						variables-'eczema'-age-sex-gp
						variables-'eczema'-BMI
						variables-'eczema'-smoking
						variables-'eczema'-ethnicity
						ecz-time-updated-variables
						
						smi-paths.do
						

DATASETS CREATED:		cohort-eczema-sens1
						appendix-ecz-analysis.xls
						(worksheet sens1)
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
global filename "sens-ecz-analysis1"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
CREATE TIME-UPDATED VARIABLES FOR SENS-ANALYSIS 
*******************************************************************************/
use "${pathIn}/variables-ecz-severity", clear 
append using "${pathIn}/variables-ecz-harmfulalcohol"
append using "${pathIn}/variables-ecz-sleep-definite"
append using "${pathIn}/outcome-ecz-smi-all"
append using "${pathIn}/variables-ecz-steroids"

sort patid date
order patid date

*collapse on patid and date so there is one record per patient
collapse (firstnm) modsevere harmfulalcohol sleep smi_all steroids, by(patid date)

sort patid date

bysort patid: gen obs=_n
bysort patid: gen maxobs=_N
*check a patient id with complicated variables -chose 799178

local update " "modsevere" "harmfulalcohol" "sleep" "smi_all" "steroids" "

foreach a in `update' {
	gen state`a'=`a'
	replace state`a' = state`a'[_n-1] if 	/// set the `var' flag to the same as the record (i.e. previous date) before 
		state`a'==.	&						/// IF the flag is missing and
		patid == patid[_n-1] 				// IF this is same patient
} /*end foreach a in `toupdate' */

drop sleep modsevere harmfulalcohol smi_all steroids

rename statemodsevere modsevere
rename statesleep sleep
rename stateharmfulalcohol harmfulalcohol
rename statesmi_all smi_all
rename statesteroids steroids

drop obs maxobs

*save
save "${pathCohort}/ecz-time-updated-variables-sens1", replace

/*******************************************************************************
#1: BUILD ECZEMA COHORT FOR SENSITIVITY ANALYSIS FIRST 
*******************************************************************************/
/*----------------------------------------------------------------------------*/
* Deal with exposed group first

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

*add in smi outcome dates (use smi all due to sensitivity analysis)
merge 1:1 patid using "${pathIn}/outcome-ecz-smi-all.dta"
rename date smi_date

*create new enddate taking date of SMI diagnosis into account
gen enddate_incSMI=min(enddate, smi_date)
format %td enddate_incSMI

*drop individuals who aren't exposed 
drop if exposed==.

*identify those with SMI before indexdate (need to be excluded)
gen earlysmi=1 if smi_date<=indexdate 
count if earlysmi==1


drop if earlysmi==1

*drop variables no longer needed
drop earlysmi smi_all _merge smi_date

unique patid


*save the dataset
save "${pathCohort}/cohort-eczema-sens1-exposed", replace

/*----------------------------------------------------------------------------*/
* Deal with time updated variables

*merge in time-updated variables dataset
merge 1:m patid using "${pathCohort}/ecz-time-updated-variables-sens1"

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
recode smi_all (.=0)

drop _merge

*drop records before index date and after follow-up
order patid date indexdate end*
sort patid date  

drop if date<indexdate

drop if date!=. & date>enddate_incSMI

*merge in exposed cohort 
merge m:1 patid using "${pathCohort}/cohort-eczema-sens1-exposed"

recode modsevere (.=0)

drop _merge

unique patid


*save the dataset
save "${pathCohort}/cohort-eczema-sens1-exposed", replace

/*----------------------------------------------------------------------------*/
* Deal with unexposed group

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
merge 1:1 patid using "${pathIn}/outcome-ecz-smi-all.dta"
rename date smi_date

*create new enddate taking date of SMI diagnosis into account
gen enddate_incSMI=min(enddate, smi_date)
format %td enddate_incSMI

*drop individuals who aren't exposed 
drop if exposed==.

*identify those with SMI before indexdate (need to be excluded)
gen earlysmi=1 if smi_date<=indexdate 
count if earlysmi==1


drop if earlysmi==1

*drop variables no longer needed
drop earlysmi smi_all _merge smi_date

unique patid


*save the dataset
save "${pathCohort}/cohort-eczema-sens1-unexposed", replace

/*----------------------------------------------------------------------------*/
* Deal with time updated variables

*merge in time-updated variables dataset
merge 1:m patid using "${pathCohort}/ecz-time-updated-variables-sens1"

keep if exposed==0
drop modsevere
*as this is unexposed

sort patid date

*formatting

*recode those with missing harmful alcohol, sleep and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi_all(.=0)

drop _merge

*drop records before index date and after follow-up
order patid date indexdate end*
sort patid date  

drop if date<indexdate

drop if date!=. & date>enddate_incSMI

*merge in exposed cohort 
merge m:1 patid using "${pathCohort}/cohort-eczema-sens1-unexposed"

drop _merge

unique patid

*save the dataset
save "${pathCohort}/cohort-eczema-sens1-unexposed", replace

/*----------------------------------------------------------------------------*/
* Create a dataset that includes both exposed and unexposed

append using "${pathCohort}/cohort-eczema-sens1-exposed"

*recode those with missing harmful alcohol, sleep and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi_all(.=0)

unique patid if exposed==1
*1,023,153

unique patid if exposed==0
*4,950,587

/*----------------------------------------------------------------------------*/
* Preserve matching

bysort setid: egen set_exposed_mean = mean(exposed) 

*if mean of exposure var is 0 then only unexposed in set, if 1 then only exposed in set
gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1)

*==1 is valid set containing both exposed and unexposed
tab valid_set, miss
tab valid_set exposed, col
keep if valid_set==1

unique patid if exposed==1


unique patid if exposed==0


*save the dataset
save "${pathCohort}/cohort-eczema-sens1", replace

*delete interim datasets
erase "${pathCohort}/cohort-eczema-sens1-exposed.dta"
erase "${pathCohort}/cohort-eczema-sens1-unexposed.dta"

/*----------------------------------------------------------------------------*/
* merge in other variables

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
save "${pathCohort}/cohort-eczema-sens1", replace

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
save "${pathCohort}/cohort-eczema-sens1", replace

/*----------------------------------------------------------------------------*/
* Create an end date for each record to take multiple records into account

sort patid indexdate date // make sure it's in the correct order
gen end=date[_n+1]-1 /// the end of record will be the day before the start of the next record
	if patid==patid[_n+1] & /// if it's the same person
	indexdate==indexdate[_n+1] /// and the same indexdate
	
format %td end

replace end=enddate_incSMI+1 if end==. & smi_all==1 
*will end the day after smi - prevents stata from not including multiple observations

replace end=enddate_incSMI if end==.
*will end at regular enddate

*save the dataset
save "${pathCohort}/cohort-eczema-sens1", replace

/*----------------------------------------------------------------------------*/
*stset the data with age as the underlying timescale


stset end, fail(smi_all==1) origin(realyob) enter(indexdate) id(patid) scale(365.25)

*save the dataset
save "${pathCohort}/cohort-eczema-sens1", replace

/*----------------------------------------------------------------------------*/
*stsplit the dataset

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

/*----------------------------------------------------------------------------*/
*tidy up and save the data 

*recode those with missing harmful alcohol, sleep, steroids and smi as not having them
recode harmfulalcohol (.=0)
recode sleep (.=0)
recode smi_all (.=0)
recode steroids (.=0)

label data "stset data for smi outcome - sensitivity analysis 1"
notes: stset data for smi outcome - sensitivity analysis 1

save "${pathCohort}/cohort-eczema-sens1", replace

/*******************************************************************************
#2: REGRESSION ANALYSIS
using the sensitivity analysis 1 dataset, do a minimally adjusted (minimally), confounder 
adjusted and mediator adjusted analysis
*******************************************************************************/
/*******************************************************************************
#1. Utility program
Define a program to get the number of subjects, person years at risk, number of
failures and HR(95% CIs) out in the appropriate format as local macros from the
r(table) returned by a regression command
Called by giving:
- matrix name containing r(table) contents 
- the name of the model to be used in the name of global macros containing the 
output 
To call: results matrixname modelname
*******************************************************************************/
cap prog drop results
program define results
	local matrixname `1'
	local model `2'
	
	* pull out HR (95% CI)
	local r : display %04.2f table[1,2]
	local lc : display %04.2f table[5,2]
	local uc : display %04.2f table[6,2]
	
	global `model'_hr "`r' (`lc', `uc')"	
	
	* pull out n's
	foreach grp in exp unexp {
		if "`grp'"=="exp" stdescribe if exposed==1
		if "`grp'"=="unexp" stdescribe if exposed==0
		
		global `model'_`grp'_n = string(`r(N_sub)', "%12.0gc") // number of subjects
		global `model'_`grp'_pyar = string(`r(tr)', "%9.0fc") // total time at risk
		global `model'_`grp'_fail = string(`r(N_fail)', "%12.0gc") // total number of failures	
	} /*foreach grp in all exp unexp*/

end /*end of results program*/

*open analysis dataset
use "${pathCohort}/cohort-eczema-sens1", clear

/*----------------------------------------------------------------------------*/
* MINIMALLY ADJUSTED MODEL (adjusted for matched variables due to stratification by matched set)
stcox i.exposed, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table minimally
*calls the results program and gives the matrix name and name of the model 

/*----------------------------------------------------------------------------*/
* MODEL 1 (minimal model adjusted for confounders - deprivation [carstairs] and calendar period)
/*
As there is missing carstairs data:
Need to drop exposed individuals with missing data and any controls no longer
matched to an included case
This means that we'll have complete cases and will preserve matching
*/

*look for missing values of practice_carstairs
gen exposed_nm = (exposed<.)
gen carstairs_nm = (practice_carstairs<.)
gen complete = (exposed_nm==1 & carstairs_nm==1)
tab complete
tab complete exposed, col
keep if complete==1
drop complete

* Preserve matching, keep valid sets only
bysort setid: egen set_exposed_mean = mean(exposed)
gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1) 
tab valid_set, miss
tab valid_set exposed, col
keep if valid_set==1
drop valid_set set_exposed_mean

*run analysis 
stcox i.exposed i.calendarperiod i.practice_carstairs, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model1
*calls the results program and gives the matrix name and name of the model 

/*----------------------------------------------------------------------------*/
* MODEL 2 (model 1 adjusted for all mediators)
*comorbidities, sleep problems, smoking status,high dose steroids, harmful alcohol use, BMI

*reopen analysis dataset to avoid making errors 
use "${pathCohort}/cohort-eczema-sens1", clear

*recode smoking status >> assume current/ex smokers are current smokers
*currently 0=non smoker, 1=current 2=ex 12=current or ex
recode smokstatus 0=0 1=1 2=1 12=1 
label define smok3 0"Non-smoker" 1"Current or ex-smoker" 
label values smokstatus smok3

*recode bmi category 
recode bmi_cat 1=0 2=1 3=2 4=3 
label define bmicat4 0"Underweight (<20)" 1"Normal (20-24)" 2"Overweight (25-29)" 3"Obese (30+)" 
label values bmi_cat bmicat4

/*
Need to drop exposed individuals with missing data and any controls no longer
matched to an included case
This means that we'll have complete cases and will preserve matching
*/

*look for missing values of carstairs, smoking and bmi 
gen exposed_nm = (exposed<.)
gen carstairs_nm = (practice_carstairs<.)
gen smokstatus_nm = (smokstatus<.)
gen bmi_nm = (bmi_cat<.)
gen complete = (exposed_nm==1 & carstairs_nm==1 & smokstatus_nm==1 & bmi_nm==1)
tab complete
tab complete exposed, col
keep if complete==1
drop complete

* Preserve matching, keep valid sets only
bysort setid: egen set_exposed_mean = mean(exposed)
gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1) 
tab valid_set, miss
tab valid_set exposed, col
keep if valid_set==1
drop valid_set set_exposed_mean

*run analysis 
stcox i.exposed i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model2
*calls the results program and gives the matrix name and name of the model

/*******************************************************************************
#3. Put results in an excel file
*******************************************************************************/
* create excel file
putexcel set "${pathResults}/appendix-ecz-analysis.xlsx", sheet(sens1) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Sensitivity analysis 1: Association (HR [95% CI]) between atopic eczema and severe mental illness: comparing risk of SMI in those with atopic eczema to those without. ", bold
local ++rowcount // increment row counter variable
putexcel A`rowcount'="Fitted to patients with complete data for all variables included in each model and from valid matched sets*"
local ++rowcount

* set up column headers
putexcel A`rowcount'="", border(top, thin, black)
putexcel B`rowcount'="Minimally adjusted (matching variables)", bold border(top, thin, black)
putexcel F`rowcount'="Model 1 (adjusted for confounders)**", bold border(top, thin, black)
putexcel J`rowcount'="Model 2 (Model 1 further adjusted for mediators***)", bold border(top, thin, black)
putexcel A`rowcount':M`rowcount', overwritefmt border(top, thin, black)
local ++rowcount 

* format table header cells
putexcel A3:M3, overwritefmt bold border(top, thin, black) 
putexcel A4:M4, overwritefmt bold border(top, thin, black) txtwrap

* next row of col headers - write the same four col headers for each model
putexcel A`rowcount'="", border(bottom, thin, black) bold
local minimally "B C D E"
local model1 "F G H I"
local model2 "J K L M"

foreach model in minimally model1 model2 {
	forvalues i=1/4 {
		local col`i' : word `i' of ``model''
	} /*end forvalues i=1/4*/
	putexcel `col1'`rowcount'="Number", border(bottom, thin, black)
	putexcel `col2'`rowcount'="Person years at risk", border(bottom, thin, black)
	putexcel `col3'`rowcount'="Events", border(bottom, thin, black)
	putexcel `col4'`rowcount'="Hazard ratio (95% CI)****", border(bottom, thin, black)
} /*end foreach model in minimally model1 model2 */
local ++rowcount

*put in data for each model in excel file 
foreach grp in unexp exp {
		if "`grp'"=="unexp" putexcel A`rowcount'="unexposed"
		if "`grp'"=="exp" putexcel A`rowcount'="exposed"
		foreach model in minimally model1 model2 {
			forvalues i=1/4 {
				local col`i' : word `i' of ``model''
			} /*end forvalues i=1/4*/	
			putexcel `col1'`rowcount'="${`model'_`grp'_n}"
			putexcel `col2'`rowcount'="${`model'_`grp'_pyar}"
			putexcel `col3'`rowcount'="${`model'_`grp'_fail}"
			if "`grp'"=="unexp" putexcel `col4'`rowcount'="1 (reference)"
			if "`grp'"=="exp" putexcel `col4'`rowcount'="${`model'_hr}", bold
		} /*end foreach model in minimally model1 model2 */
		local ++rowcount
	} /*end foreach grp in unexp exp*/
	
/*----------------------------------------------------------------------------*/
* FOOTNOTES
putexcel A`rowcount':M`rowcount', overwritefmt border(top, thin, black)

putexcel A`rowcount'="*Matched sets including one exposed patient and at least one unexposed patient."
local ++rowcount
putexcel A`rowcount'="**Adjusted for Carstairs deprivation index and calendar period."
local ++rowcount
putexcel A`rowcount'="***Adjusted for comorbidities, problems with sleep, smoking status, high dose glucocorticoid use, harmful alcohol use and BMI."
local ++rowcount
putexcel A`rowcount'="****Estimated hazard ratios from Cox regression with current age as underlying timescale, stratified by matched set (matched on age at cohort entry, sex, general practice, and date at cohort entry)"
local ++rowcount

log close
exit

