/*******************************************************************************
DO FILE NAME:			main-pso-analysis3-regression-severity.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	01/12/2021

TASK:					Aim is to run the analysis stratified 
						by severity for the smi outcome and 
						put the results into an excel file
						
DATASET(S)/FILES USED:	cohort-psoriasis-main.dta
						

DATASETS CREATED:		main-pso-analysis.xls 
						(worksheet regression_severity)
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
global filename "main-pso-analysis-regression-severity"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
MAIN ANALYSIS STRATIFIED BY SEVERITY
*******************************************************************************/
*create program to get the results like above
cap prog drop results
program define results
	local matrixname `1'
	local model `2'
	
	* pull out HRs (95% CI)
	local x=2
	foreach severity in mild modsev {
		local r : display %04.2f table[1,`x']
		local lc : display %04.2f table[5,`x']
		local uc : display %04.2f table[6,`x']
		global `model'_`severity'_hr "`r' (`lc', `uc')"
		local ++x // increment counter
	} /*end foreach severity in mild moderate/severe */
		
	
	* pull out n's
	foreach severity in unexposed mild modsev {
		if "`severity'"=="unexposed" stdescribe if severity==0
		if "`severity'"=="mild" stdescribe if severity==1
		if "`severity'"=="modsev" stdescribe if severity==2
		
		global `model'_`severity'_n = string(`r(N_sub)', "%12.0gc") // number of subjects
		global `model'_`severity'_pyar = string(`r(tr)', "%9.0fc") // total time at risk
		global `model'_`severity'_fail = string(`r(N_fail)', "%12.0gc") // total number of failures	
	} /*foreach severity in mild modsev*/	
end /*end of results program*/

/*******************************************************************************
#1. Analysis
*******************************************************************************/
*open analysis dataset
use "${pathCohort}/cohort-psoriasis-main", clear

/*----------------------------------------------------------------------------*/
*Deal with severity variable 
*set to 0 for unexposed and 1-2 for exposed
*create our new exposure variable which is severity
recode psoriasis_severity 0=1 1=2, gen(severity)
tab psoriasis_severity severity, missing
replace severity=0 if exposed==0 
label define severity 0"Unexposed" 1"Exposed – mild" 2"Exposed – moderate/severe" 
label values severity severity
tab severity exposed, missing 

/*----------------------------------------------------------------------------*/
* MINIMALLY ADJUSTED MODEL (adjusted for matched variables due to stratification by matched set)
stcox i.severity, strata(setid) level(95) base
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
stcox i.severity i.calendarperiod i.practice_carstairs, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model1
*calls the results program and gives the matrix name and name of the model 

/*----------------------------------------------------------------------------*/
* MODEL 2 (model 1 further adjusted for mediating effect of comorbidities)
*check if there is missing comorbidities data 
assert cci !=.

*run analysis 
stcox i.severity i.calendarperiod i.practice_carstairs i.cci, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model2
*calls the results program and gives the matrix name and name of the model 

*----------------------------------------------------------------------------*/
* MODEL 3 (model 1 further adjusted for mediating effect of harmful alcohol use)
*recode those with missing harmful alcohol as not being a harmful alcohol user
recode harmfulalcohol (.=0)

*run analysis
stcox i.severity i.calendarperiod i.practice_carstairs i.harmfulalcohol, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model3
*calls the results program and gives the matrix name and name of the model

/*----------------------------------------------------------------------------*/
* MODEL 4 (model 1 further adjusted for mediating effect of smoking)

/*
As there are people with missing smoking status, open an unedited version
of the dataset to avoid making any errors
*/

*open analysis dataset
use "${pathCohort}/cohort-psoriasis-main", clear

*Deal with severity variable 
*set to 0 for unexposed and 1-2 for exposed
*create our new exposure variable which is severity
recode psoriasis_severity 0=1 1=2, gen(severity)
tab psoriasis_severity severity, missing
replace severity=0 if exposed==0 
label define severity 0"Unexposed" 1"Exposed – mild" 2"Exposed – moderate/severe" 
label values severity severity
tab severity exposed, missing 

*recode smoking status >> assume current/ex smokers are current smokers
*currently 0=non smoker, 1=current 2=ex 12=current or ex
recode smokstatus 0=0 1=1 2=1 12=1 
label define smok3 0"Non-smoker" 1"Current or ex-smoker" 
label values smokstatus smok3

/*
Need to drop exposed individuals with missing data and any controls no longer
matched to an included case
This means that we'll have complete cases and will preserve matching
*/

*look for missing values of carstairs and smoking status
gen exposed_nm = (exposed<.)
gen carstairs_nm = (practice_carstairs<.)
gen smokstatus_nm = (smokstatus<.)
gen complete = (exposed_nm==1 & carstairs_nm==1 & smokstatus_nm==1)
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
stcox i.severity i.calendarperiod i.practice_carstairs i.smokstatus, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model4
*calls the results program and gives the matrix name and name of the model

/*----------------------------------------------------------------------------*/
* MODEL 5 (model 1 further adjusted for mediating effect of BMI)

/*
People that have missing smoking may still have BMI recorded, so using the previously 
defined variables may mean i lose some people
would be best to reopen a clear version of the main eczema dataset to avoid this
*/

*open analysis dataset
use "${pathCohort}/cohort-psoriasis-main", clear

*Deal with severity variable 
*set to 0 for unexposed and 1-2 for exposed
*create our new exposure variable which is severity
recode psoriasis_severity 0=1 1=2, gen(severity)
tab psoriasis_severity severity, missing
replace severity=0 if exposed==0 
label define severity 0"Unexposed" 1"Exposed – mild" 2"Exposed – moderate/severe" 
label values severity severity
tab severity exposed, missing 

*recode bmi category 
recode bmi_cat 1=0 2=1 3=2 4=3 
label define bmicat4 0"Underweight (<20)" 1"Normal (20-24)" 2"Overweight (25-29)" 3"Obese (30+)" 
label values bmi_cat bmicat4

/*
Need to drop exposed individuals with missing data and any controls no longer
matched to an included case
This means that we'll have complete cases and will preserve matching
*/

*look for missing values of carstairs and bmi 
gen exposed_nm = (exposed<.)
gen carstairs_nm = (practice_carstairs<.)
gen bmi_nm = (bmi_cat<.)
gen complete = (exposed_nm==1 & carstairs_nm==1 & bmi_nm==1)
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
stcox i.severity i.calendarperiod i.practice_carstairs i.bmi_cat, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model5
*calls the results program and gives the matrix name and name of the model

/*----------------------------------------------------------------------------*/
* MODEL 6 (model 1 adjusted for all mediators)
*comorbidities, smoking status, harmful alcohol use, BMI

*reopen analysis dataset to avoid making errors 
use "${pathCohort}/cohort-psoriasis-main", clear

*Deal with severity variable 
*set to 0 for unexposed and 1-2 for exposed
*create our new exposure variable which is severity
recode psoriasis_severity 0=1 1=2, gen(severity)
tab psoriasis_severity severity, missing
replace severity=0 if exposed==0 
label define severity 0"Unexposed" 1"Exposed – mild" 2"Exposed – moderate/severe" 
label values severity severity
tab severity exposed, missing 

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
stcox i.severity i.calendarperiod i.practice_carstairs i.cci i.harmfulalcohol i.smokstatus i.bmi_cat, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model6
*calls the results program and gives the matrix name and name of the model

/*******************************************************************************
#3. Put results in an excel file
*******************************************************************************/
* add sheet to existing excel file
putexcel set "${pathResults}/main-pso-analysis.xlsx", sheet(regression_severity) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Association (HR [95% CI]) between severity of psoriasis and severe mental illness. ", bold
local ++rowcount 
putexcel A`rowcount'="Fitted to patients with complete data for all variables included in each model and from valid matched sets*"
local ++rowcount

* set up column headers
putexcel A`rowcount'="", border(top, thin, black)
putexcel B`rowcount'="Minimally adjusted (matching variables)", bold border(top, thin, black)
putexcel F`rowcount'="Model 1 (adjusted for confounders)**", bold border(top, thin, black)
putexcel J`rowcount'="Model 2 (Model 1 further adjusted for comorbidities***)", bold border(top, thin, black)
putexcel N`rowcount'="Model 3 (Model 1 further adjusted for harmful alcohol use)", bold border(top, thin, black)
putexcel R`rowcount'="Model 4 (Model 1 further adjusted for smoking status)", bold border(top, thin, black)
putexcel V`rowcount'="Model 5 (Model 1 further adjusted for BMI)", bold border(top, thin, black)
putexcel Z`rowcount'="Model 6 (Model 1 further adjusted for all mediators****)", bold border(top, thin, black)
putexcel A`rowcount':AC`rowcount', overwritefmt border(top, thin, black)
local ++rowcount 

* format table header cells
putexcel A3:AC3, overwritefmt bold border(top, thin, black) 
putexcel A4:AC4, overwritefmt bold border(top, thin, black) txtwrap

* next row of col headers - write the same four col headers for each model
putexcel A`rowcount'="", border(bottom, thin, black) bold
local minimally "B C D E"
local model1 "F G H I"
local model2 "J K L M"
local model3 "N O P Q"
local model4 "R S T U"
local model5 "V W X Y"
local model6 "Z AA AB AC"

foreach model in minimally model1 model2 model3 model4 model5 model6 {
	forvalues i=1/4 {
		local col`i' : word `i' of ``model''
	} /*end forvalues i=1/4*/
	putexcel `col1'`rowcount'="Number", border(bottom, thin, black)
	putexcel `col2'`rowcount'="Person years at risk", border(bottom, thin, black)
	putexcel `col3'`rowcount'="Events", border(bottom, thin, black)
	putexcel `col4'`rowcount'="Hazard ratio (95% CI)**", border(bottom, thin, black)
} /*end foreach model in minimally model1 model2 model3 model4 model5 model6 */
local ++rowcount

*put in data for each model in excel file 
foreach severity in unexposed mild modsev {
		if "`severity'"=="unexposed" putexcel A`rowcount'="Unexposed"
		if "`severity'"=="mild" putexcel A`rowcount'="Mild psoriasis"
		if "`severity'"=="modsev" putexcel A`rowcount'="Moderate-to-severe psoriasis"
		
		local minimally "B C D E"
		local model1 "F G H I"
		local model2 "J K L M"
		local model3 "N O P Q"
		local model4 "R S T U"
		local model5 "V W X Y"
		local model6 "Z AA AB AC"
		
		foreach model in minimally model1 model2 model3 model4 model5 model6 {
			forvalues i=1/4 {
				local col`i' : word `i' of ``model''
			} /*end forvalues i=1/4*/
			putexcel `col1'`rowcount'="${`model'_`severity'_n}", hcenter
			putexcel `col2'`rowcount'="${`model'_`severity'_pyar}", hcenter
			putexcel `col3'`rowcount'="${`model'_`severity'_fail}", hcenter
			if "`severity'"=="unexposed" putexcel `col4'`rowcount'="1 (reference)", hcenter
			else putexcel `col4'`rowcount'="${`model'_`severity'_hr}", hcenter
			} /*end foreach model in minimally model1 model2 model3 model4 model5 model6*/	
		
		local ++rowcount
	} /*end foreach severity in un mi modsev*/

/*----------------------------------------------------------------------------*/
* FOOTNOTES
putexcel A`rowcount':AC`rowcount', overwritefmt border(top, thin, black)

putexcel A`rowcount'="*Matched sets including one exposed patient and at least one unexposed patient."
local ++rowcount
putexcel A`rowcount'="**Adjusted for Carstairs deprivation index and calendar period."
local ++rowcount
putexcel A`rowcount'="***Comorbidities adjusted for using the Charlson Comorbidity Index."
local ++rowcount
putexcel A`rowcount'="****Adjusted for comorbidities, smoking status, harmful alcohol use and BMI."
local ++rowcount
putexcel A`rowcount'="*****Estimated hazard ratios from Cox regression with current age as underlying timescale, stratified by matched set (matched on age at cohort entry, sex, general practice, and date at cohort entry)"
local ++rowcount

log close
exit











