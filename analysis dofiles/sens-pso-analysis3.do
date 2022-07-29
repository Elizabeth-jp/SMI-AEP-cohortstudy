/*******************************************************************************
DO FILE NAME:			sens-pso-analysis3.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	24/01/22

TASK:					Sensitivity analysis 3 - Repeat the main analysis restricting
						to individuals entering from 2006 and additionally adjusting
						for ethnicity as a confounder
						
DATASET(S)/FILES USED:	cohort-psoriasis-main.dta
						smi-paths.do
						

DATASETS CREATED:		appendix-pso-analysis.xls
						(worksheet sens3)
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
global filename "sens-pso-analysis3"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

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

/*******************************************************************************
#2. Analysis
*******************************************************************************/
*open analysis dataset
use "${pathCohort}/cohort-psoriasis-main", clear

/*
Identify those joining the cohort from 2006 onwards with complete ethnicity data 
preserve matching
*/

keep if indexdate>=(d(01jan2006))

*recode ethnicity and create a new variable
recode eth5 0=0 1=1 2=2 3=3 4=4 5=., gen(ethnicity)
label define ethnicity 0"White" 1"South Asian" 2"Black" 3"Other" 4"Mixed"
label values ethnicity ethnicity
tab ethnicity eth5, miss
keep if ethnicity<.

* Preserve matching, keep valid sets only
bysort setid: egen set_exposed_mean = mean(exposed)
gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1) 
tab valid_set, miss
tab valid_set exposed, col
keep if valid_set==1
drop valid_set set_exposed_mean

/*----------------------------------------------------------------------------*/
* MINIMALLY ADJUSTED MODEL (adjusted for matched variables due to stratification by matched set)
stcox i.exposed, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table minimally
*calls the results program and gives the matrix name and name of the model 

/*----------------------------------------------------------------------------*/
* MODEL 1 (minimal model adjusted for confounders - deprivation [carstairs], calendar period AND ETHNICITY)
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
stcox i.exposed i.calendarperiod i.practice_carstairs i.ethnicity, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model1
*calls the results program and gives the matrix name and name of the model 

/*----------------------------------------------------------------------------*/
* MODEL 2 (model 1 adjusted for all mediators)
*comorbidities,smoking status, harmful alcohol use, BMI

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

*look for missing values of smoking and bmi 
gen smokstatus_nm = (smokstatus<.)
gen bmi_nm = (bmi_cat<.)
gen complete = (exposed_nm==1 & smokstatus_nm==1 & bmi_nm==1)
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
stcox i.exposed i.calendarperiod i.practice_carstairs i.ethnicity i.cci i.harmfulalcohol i.smokstatus i.bmi_cat, strata(setid) level(95) base
matrix table = r(table) 
*puts results in the matrix so I can pull the numbers out
results table model2

/*******************************************************************************
#3. Put results in an excel file
*******************************************************************************/
* create excel file
putexcel set "${pathResults}/appendix-pso-analysis.xlsx", sheet(sens3) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Sensitivity analysis 3: Association (HR [95% CI]) between psoriasis and severe mental illness: comparing risk of SMI in those with psoriasis to those without. ", bold
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
putexcel A`rowcount'="**Adjusted for Carstairs deprivation index, calendar period and ethnicity."
local ++rowcount
putexcel A`rowcount'="***Adjusted for comorbidities, smoking status, harmful alcohol use and BMI."
local ++rowcount
putexcel A`rowcount'="****Estimated hazard ratios from Cox regression with current age as underlying timescale, stratified by matched set (matched on age at cohort entry, sex, general practice, and date at cohort entry)"
local ++rowcount

log close
exit





*calls the results program and gives the matrix name and name of the model