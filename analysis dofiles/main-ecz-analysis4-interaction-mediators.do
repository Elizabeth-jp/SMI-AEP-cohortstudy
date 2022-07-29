/*******************************************************************************
DO FILE NAME:			main-ecz-analysis3-interaction.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	01/12/2021

TASK:					Repeat the main analysis looking for effect modification 
						by age, sex and calendar period
						The model that will be adjusted for in this analysis is
						Model 8 (model adjusted for confounders and mediators)
						
DATASET(S)/FILES USED:	cohort-eczema-main.dta
						

DATASETS CREATED:		main-ecz-analysis-interaction-mediators.xls
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
global filename "main-ecz-analysis-interaction-mediators"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 


/*******************************************************************************
#1. Utility program
Define a program to get the number of subjects, person years at risk, number of
failures and HR(95% CIs) out in the appropriate format as local macros from the
r(table) returned by a regression command
Called by giving:
- matrix name containing r(table) contents 
- the name of the analysis to be used in the name of global macros containing the 
output 
To call: results matrixname analysis
*******************************************************************************/
cap prog drop gethr
program define gethr
	local matrixname `1'
	local analysis `2'
	
	* pull out HR (95% CI)
	local r : display %04.2f table[1,2]
	local lc : display %04.2f table[5,2]
	local uc : display %04.2f table[6,2]
	
	global `analysis'_hr "`r' (`lc', `uc')"	
end/ /*end of gethr program*/
	
* program to pull out n's, pyars and failures
cap prog drop getNs
program define getNs
	local analysis `1'
		global `analysis'_n = string(`r(N_sub)', "%12.0gc") // number of subjects
		global `analysis'_pyar = string(`r(tr)', "%9.0fc") // total time at risk
		global `analysis'_fail = string(`r(N_fail)', "%12.0gc") // total number of failures	
end /*end of getNs program*/

/*******************************************************************************
#2. Analysis
*******************************************************************************/
*open analysis dataset
use "${pathCohort}/cohort-eczema-main", clear

/* 
Will be using model 8 adjusted for confounders and mediators
there are individuals with missing carstairs, bmi and smoking that need to be excluded
As there is missing data:
Need to drop exposed individuals with missing data and any controls no longer
matched to an included case
This means that we'll have complete cases and will preserve matching
*/

*recode smoking status >> assume current/ex smokers are current smokers
*currently 0=non smoker, 1=current 2=ex 12=current or ex
recode smokstatus 0=0 1=1 2=1 12=1 
label define smok3 0"Non-smoker" 1"Current or ex-smoker" 
label values smokstatus smok3

*recode bmi category 
recode bmi_cat 1=0 2=1 3=2 4=3 
label define bmicat4 0"Underweight (<20)" 1"Normal (20-24)" 2"Overweight (25-29)" 3"Obese (30+)" 
label values bmi_cat bmicat4

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

/*----------------------------------------------------------------------------*/
* SEX INTERACTION

* pull out N's pyar and number of events
* Men
stdescribe if sex==1
getNs sexM 
stdescribe if sex==1 & exposed==0
getNs sexMexpN 
stdescribe if sex==1 & exposed==1
getNs sexMexpY 
	
*Women
stdescribe if sex==2
getNs sexF 
stdescribe if sex==2 & exposed==0
getNs sexFexpN `
stdescribe if sex==2 & exposed==1
getNs sexFexpY 

*run analysis in men 
display in red "**************** men ********************************"
stcox i.exposed i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids if sex==1, strata(setid) level(95) base
matrix table = r(table) 
gethr table sexM

*run analysis in women
display in red "**************** women ********************************"
stcox i.exposed i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids if sex==2, strata(setid) level(95) base
matrix table = r(table) 
gethr table sexF

*run interaction analysis 
display in red "**************** sex interaction ********************************"
stcox i.exposed##i.sex i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids, strata(setid) level(95) base
matrix table = r(table) 
global sexI : display %04.2f table[4,8]


/*----------------------------------------------------------------------------*/
* AGE INTERACTION

/*
codebook age:
1:18-29; 2:30-39... until 8:90+
*/

*loop through each age group
foreach age in 1 2 3 4 {
    display in red "************************ age_grp `age' ****************************"
	stdescribe if age_grp==`age'
	getNs age`age'
	stdescribe if age_grp==`age' & exposed==0
	getNs age`age'expN
	stdescribe if age_grp==`age' & exposed==1
	getNs age`age'expY
	
	*run analysis for age group
	display in red "************************ age_grp `age' ****************************"
	stcox i.exposed i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids if age_grp==`age', strata(setid) level(95) base
	matrix table = r(table)
	gethr table age`age'
}

*run interaction analysis 
display in red "**************** current age_grp interaction ********************************"
*need to do a likelihood ratio test due to ordered categorical variables
*simple model
stcox i.exposed i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids, strata(setid) level(95) base
est store A
*interaction model
stcox i.exposed##i.age_grp i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids, strata(setid) level(95) base
est store B
lrtest A B
global ageI : display %04.2f r(p) // pull out p-value

/*----------------------------------------------------------------------------*/
* CALENDAR PERIOD INTERACTION

*loop through each calendar period
foreach period in 1997 2004 2010 2016 {
    display in red "************************ calendarperiod `period' ****************************"
	stdescribe if calendarperiod==`period'
	getNs period`period'
	stdescribe if calendarperiod==`period' & exposed==0
	getNs period`period'expN
	stdescribe if calendarperiod==`period' & exposed==1
	getNs period`period'expY
	
	*run analysis for calendar period
	display in red "************************ calendarperiod `period' ****************************"
	stcox i.exposed i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids if calendarperiod==`period', strata(setid) level(95) base
	matrix table = r(table)
	gethr table period`period'
}


*run interaction analysis 
display in red "**************** current calendarperiod interaction ********************************"
*need to do a likelihood ratio test due to ordered categorical variables
*simple model
stcox i.exposed i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids, strata(setid) level(95) base
est store A
*interaction model
stcox i.exposed##i.calendarperiod i.practice_carstairs i.cci i.sleep i.harmfulalcohol i.smokstatus i.bmi_cat i.steroids, strata(setid) level(95) base
est store B
lrtest A B
global calendarI : display %04.2f r(p) // pull out p-value

/*******************************************************************************
#3. Put results in an excel file
*******************************************************************************/
*put results for sex, age group and calendar period into separate worksheets 

/*----------------------------------------------------------------------------*/
* SEX INTERACTION

* create excel file
putexcel set "${pathResults}/main-ecz-analysis.xlsx", sheet(interaction_sex_mediators) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Adjusted hazard ratios (95% CIs) for the association between atopic eczema and severe mental illness, stratified by sex (adjusted for confounders and mediators).", bold
local ++rowcount 
putexcel A`rowcount'="Fitted to patients with complete data for all variables included in each model and from valid matched sets*"
local ++rowcount

* create table headers
putexcel A`rowcount'="Outcome", bold border(bottom, thin, black)
putexcel B`rowcount'="Number of individuals", bold border(bottom, thin, black)
putexcel C`rowcount'="PYAR", bold border(bottom, thin, black)
putexcel D`rowcount'="Number of events", bold border(bottom, thin, black)
putexcel E`rowcount'="HR (95% CI)**", bold border(bottom, thin, black)
putexcel F`rowcount'="Interaction p-value", bold border(bottom, thin, black)

local ++rowcount

* format table header cells
putexcel A3:F3, overwritefmt border(bottom, thin, black)
putexcel A4:F4, overwritefmt bold border(bottom, thin, black) txtwrap

*include interaction value in table
putexcel F`rowcount'="${sexI}"
local ++rowcount

* loop through men and women
foreach sex in M F {
	if "`sex'"=="M" putexcel A`rowcount'="Males", italic
	if "`sex'"=="F" putexcel A`rowcount'="Females", italic
	local ++rowcount
		
* exposed and unexposed
	foreach exp in N Y {
	if "`exp'"=="N" putexcel A`rowcount'="No eczema"
	if "`exp'"=="Y" putexcel A`rowcount'="Eczema"			
	putexcel B`rowcount'="${sex`sex'exp`exp'_n}" // n
	putexcel C`rowcount'="${sex`sex'exp`exp'_pyar}" // pyar
	putexcel D`rowcount'="${sex`sex'exp`exp'_fail}" // failures
			
	if "`exp'"=="N" putexcel E`rowcount'="1 (ref)"
	if "`exp'"=="Y" putexcel E`rowcount'="${sex`sex'_hr}"
		
			local ++rowcount
		} /*end foreach exp in Y N*/
	} /*end foreach sex in M F*/

* add top border
putexcel A`rowcount':F`rowcount', overwritefmt border(top, thin, black)

local ++rowcount

*Footnotes
putexcel A`rowcount'="*Matched sets including one exposed patient and at least one unexposed patient"
local ++rowcount
putexcel A`rowcount'="**Estimated hazard ratios from Cox regression with current age as underlying timescale, stratified by matched set (matched on age at cohort entry, sex, general practice, and date at cohort entry)."
local ++rowcount

/*----------------------------------------------------------------------------*/
* AGE INTERACTION

* create excel file
putexcel set "${pathResults}/main-ecz-analysis.xlsx", sheet(interaction_age_mediators) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Adjusted hazard ratios (95% CIs) for the association between atopic eczema and severe mental illness, stratified by current age (adjusted for confounders and mediators).", bold
local ++rowcount 
putexcel A`rowcount'="Fitted to patients with complete data for all variables included in each model and from valid matched sets*"
local ++rowcount

* create table headers
putexcel A`rowcount'="Outcome", bold border(bottom, thin, black)
putexcel B`rowcount'="Number of individuals", bold border(bottom, thin, black)
putexcel C`rowcount'="PYAR", bold border(bottom, thin, black)
putexcel D`rowcount'="Number of events", bold border(bottom, thin, black)
putexcel E`rowcount'="HR (95% CI)**", bold border(bottom, thin, black)
putexcel F`rowcount'="Interaction p-value", bold border(bottom, thin, black)

local ++rowcount

* format table header cells
putexcel A3:F3, overwritefmt border(bottom, thin, black)
putexcel A4:F4, overwritefmt bold border(bottom, thin, black) txtwrap

*include interaction value in table
putexcel F`rowcount'="${ageI}"
local ++rowcount

*loop through each age group
foreach age in 1 2 3 4 {
	if "`age'"=="1" putexcel A`rowcount'="18-29"
	if "`age'"=="2" putexcel A`rowcount'="30-39"
	if "`age'"=="3" putexcel A`rowcount'="40-59"
	if "`age'"=="4" putexcel A`rowcount'="60+"
	local ++rowcount
	
	*exposed and unexposed
	foreach exp in N Y {
	    if "`exp'"=="N" putexcel A`rowcount'="No eczema"
		if "`exp'"=="Y" putexcel A`rowcount'="Eczema"
		
		putexcel B`rowcount'="${age`age'exp`exp'_n}" // n
		putexcel C`rowcount'="${age`age'exp`exp'_pyar}" // pyar
		putexcel D`rowcount'="${age`age'exp`exp'_fail}" // failures
			
		if "`exp'"=="N" putexcel E`rowcount'="1 (ref)"
		if "`exp'"=="Y" putexcel E`rowcount'="${age`age'_hr}"
			
		local ++rowcount
		} /*end foreach exp in Y N*/
	} /*end foreach foreach age in age group*/
	
*add top border
putexcel A`rowcount':F`rowcount', overwritefmt border(top, thin, black)

local ++rowcount

*Footnotes
putexcel A`rowcount'="*Matched sets including one exposed patient and at least one unexposed patient"
local ++rowcount
putexcel A`rowcount'="**Estimated hazard ratios from Cox regression with current age as underlying timescale, stratified by matched set (matched on age at cohort entry, sex, general practice, and date at cohort entry)."
local ++rowcount

/*----------------------------------------------------------------------------*/
* CALENDAR PERIOD INTERACTION

* create excel file
putexcel set "${pathResults}/main-ecz-analysis.xlsx", sheet(interaction_cd_mediators) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Adjusted hazard ratios (95% CIs) for the association between atopic eczema and severe mental illness, stratified by calendar period (adjusted for confounders and mediators)."
local ++rowcount 
putexcel A`rowcount'="Fitted to patients with complete data for all variables included in each model and from valid matched sets*"
local ++rowcount

* create table headers
putexcel A`rowcount'="Outcome", bold border(bottom, thin, black)
putexcel B`rowcount'="Number of individuals", bold border(bottom, thin, black)
putexcel C`rowcount'="PYAR", bold border(bottom, thin, black)
putexcel D`rowcount'="Number of events", bold border(bottom, thin, black)
putexcel E`rowcount'="HR (95% CI)**", bold border(bottom, thin, black)
putexcel F`rowcount'="Interaction p-value", bold border(bottom, thin, black)

local ++rowcount

* format table header cells
putexcel A3:F3, overwritefmt border(bottom, thin, black)
putexcel A4:F4, overwritefmt bold border(bottom, thin, black) txtwrap

*include interaction value in table
putexcel F`rowcount'="${calendarI}"
local ++rowcount

*loop through each calendar period
foreach period in 1997 2004 2010 2016 {
	if "`period'"=="1997" putexcel A`rowcount'="1997-2003"
	if "`period'"=="2004" putexcel A`rowcount'="2004-2009"
	if "`period'"=="2010" putexcel A`rowcount'="2010-2015"
	if "`period'"=="2016" putexcel A`rowcount'="2016-2020"
	local ++rowcount
	
	*exposed and unexposed
	foreach exp in N Y {
	    if "`exp'"=="N" putexcel A`rowcount'="No eczema"
		if "`exp'"=="Y" putexcel A`rowcount'="Eczema"
		
		putexcel B`rowcount'="${period`period'exp`exp'_n}" // n
		putexcel C`rowcount'="${period`period'exp`exp'_pyar}" // pyar
		putexcel D`rowcount'="${period`period'exp`exp'_fail}" // failures
			
		if "`exp'"=="N" putexcel E`rowcount'="1 (ref)"
		if "`exp'"=="Y" putexcel E`rowcount'="${period`period'_hr}"
			
		local ++rowcount
		} /*end foreach exp in Y N*/
	} /*end foreach period in calendar period*/
	
*add top border
putexcel A`rowcount':F`rowcount', overwritefmt border(top, thin, black)

local ++rowcount

*Footnotes
putexcel A`rowcount'="*Matched sets including one exposed patient and at least one unexposed patient"
local ++rowcount
putexcel A`rowcount'="**Estimated hazard ratios from Cox regression with current age as underlying timescale, stratified by matched set (matched on age at cohort entry, sex, general practice, and date at cohort entry)."
local ++rowcount

log close
exit 

