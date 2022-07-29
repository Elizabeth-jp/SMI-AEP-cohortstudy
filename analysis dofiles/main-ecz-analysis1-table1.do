/*******************************************************************************
DO FILE NAME:			main-ecz-analysis1-table1.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	19/11/2021

TASK:					Aim is to create an excel file containing figures for
						table 1 (n(%) and pyars)
						
DATASET(S)/FILES USED:	cohort-eczema-main.dta
						

DATASETS CREATED:		main-ecz-analysis.xls
						(worksheet baseline_n and baseline_pyar)
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
global filename "main-ecz-analysis-table1"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
N (%)
*******************************************************************************/

/*******************************************************************************
#1. Open eczema main analysis dataset and set up column headers in output file
*******************************************************************************/
use "${pathCohort}/cohort-eczema-main", clear

*Label variables
label var sleep "Problems with sleep"
label var steroids "High dose oral glucocorticoids"
label var sex "Sex"
label var practice_carstairs "Carstairs index quintile"
label var cci "Charlson comorbidity index"
label var smokstatus "Smoking status"

* create excel file
putexcel set "${pathResults}/main-ecz-analysis.xlsx", sheet(baseline_n) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Characteristics of the study population at cohort entry stratified by atopic eczema exposure status." 
local ++rowcount // increment row couter variable
putexcel A`rowcount'="Values are numbers (percentages) unless stated otherwise"
local ++rowcount // increment row couter variable

* set up column headers
putexcel A`rowcount'="", border(top, thin, black)
putexcel B`rowcount'="Whole cohort", bold hcenter border(top, thin, black)
putexcel C`rowcount'="With atopic eczema", bold hcenter border(top, thin, black)
putexcel D`rowcount'="Without atopic eczema", bold hcenter border(top, thin, black)

local ++rowcount

/*******************************************************************************
#2. Totals
*******************************************************************************/
* border on first cell
putexcel A`rowcount'="", border(bottom, thin, black)

* whole cohort
unique patid
global ncohort=r(unique) 
local n = string(`r(unique)',"%12.0gc")
putexcel B`rowcount'="n=`n'", hcenter border(bottom, thin, black)

* exposed
unique patid if exposed==1
global nexp=r(unique)
local n = string(`r(unique)',"%12.0gc")
putexcel C`rowcount'="n=`n'", hcenter border(bottom, thin, black)

* unexposed
unique patid if exposed==0
global nunexp=r(unique)
local n = string(`r(unique)',"%12.0gc")
putexcel D`rowcount'="n=`n'", hcenter border(bottom, thin, black)

local ++rowcount

/*******************************************************************************
#3. Person years at risk (total and median)
*******************************************************************************/
* fu for each observation
gen fu_time=_t-_t0 // fu time duration

* loop through exposed and unexposed
foreach group in cohort exp unexp {
	preserve
		* keep relevant patids
		if "`group'"=="exp" keep if exposed==1
		if "`group'"=="unexp" keep if exposed==0
		
		* collapse
		collapse (sum)fu_time, by(patid)
		summ fu_time, detail 
		
		* total
		global `group'_pyar=`r(sum)'
		
		* median
		local p50=string(`r(p50)', "%4.1f")
		local p25=string(`r(p25)', "%4.1f")
		local p75=string(`r(p75)', "%4.1f")
		global `group'_median "`p50' (`p25'-`p75')"	
	restore
} /*end foreach group in cohort exp unexp*/

* put data in excel file
putexcel A`rowcount'="Follow-up*", bold
local ++rowcount

* total person years
putexcel A`rowcount'="Total person-years"
foreach group in cohort exp unexp {
	if "`group'"=="cohort" local col "B"
	if "`group'"=="exp" local col "C"
	if "`group'"=="unexp" local col "D"

	local pyar ${`group'_pyar}
	putexcel `col'`rowcount'=`pyar', hcenter nformat(#,###0)
} /*end foreach group in cohort exp unexp*/
local ++rowcount

* median
putexcel A`rowcount'="Median (IQR) duration of follow-up (years)"
foreach group in cohort exp unexp {
	if "`group'"=="cohort" local col "B"
	if "`group'"=="exp" local col "C"
	if "`group'"=="unexp" local col "D"

	local median "${`group'_median}"
	putexcel `col'`rowcount'="`median'", hcenter
} /*end foreach group in cohort exp unexp*/
local ++rowcount

/*******************************************************************************
#4. Sex
*******************************************************************************/
putexcel A`rowcount'="Sex", bold
local ++rowcount

putexcel A`rowcount'="Female (%)"

* loop through cohort, exp and unexp
foreach group in cohort exp unexp {
	if "`group'"=="cohort" { 
		unique patid if sex==2
		local denom=$ncohort
		local col "B"
	}
	if "`group'"=="exp" { // exposed
		unique patid if sex==2 & exposed==1
		local denom=$nexp
		local col "C"
	}
	if "`group'"=="unexp" { // unexp
		unique patid if sex==2 & exposed==0
		local denom=$nunexp
		local col "D"
	}
	local n=string(`r(unique)',"%12.0gc")
	local percent=string((`r(unique)'/`denom')*100, "%4.1f")
	local female "`n' (`percent'%)"
	
	putexcel `col'`rowcount'="`female'",  hcenter
} /*end foreach group in exp unexp*/

local ++rowcount

/*******************************************************************************
#5. Age
*******************************************************************************/
* keep first record for each patid/indexdate combination
sort patid indexdate date
bysort patid indexdate: keep if _n==1

putexcel A`rowcount'="Age (years)**", bold
local ++rowcount

* loop through each age group
* so that we end up with the ageband covariates in vars: age_`group'_`agegroup'
* where group is: cohort, exp or unexp
* and where age_grp is 1-8
levelsof age_grp, local(levels)
foreach i of local levels {
	foreach group in cohort exp unexp {
		if "`group'"=="cohort" unique patid if age_grp==`i'
		if "`group'"=="exp" unique patid if age_grp==`i' & exposed==1
		if "`group'"=="unexp" unique patid if age_grp==`i' & exposed==0
		
		* use returned results
		local n=string(`r(unique)',"%12.0gc") 
		local percent=string((`r(unique)' / ${n`group'}) * 100, "%4.1f")
		
		* create string for output
		global age_`group'_`i' "`n' (`percent'%)"	
	} /*end foreach group in cohort exp unexp*/
	
	putexcel A`rowcount'="`: label (age_grp) `i''" // use variable label for row caption
	putexcel B`rowcount'="${age_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${age_exp_`i'}",  hcenter
	putexcel D`rowcount'="${age_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*******************************************************************************
#6. Carstairs
*******************************************************************************/
putexcel A`rowcount'="Qunitiles of carstairs deprivation index***", bold
local ++rowcount

*recode practice_carstairs
recode practice_carstairs 1=1 2=2 3=3 4=4 5=5 .=6
label define carstairs 1"1(least deprived)" 2"2" 3"3" 4"4" 5"5(most deprived)" 6"Missing"
label values practice_carstairs carstairs 

* loop through each quintile
forvalues x=1/6 {
	foreach group in cohort exp unexp {
		if "`group'"=="cohort" unique patid if practice_carstairs==`x' 
		if "`group'"=="exp" unique patid if practice_carstairs==`x' & exposed==1
		if "`group'"=="unexp" unique patid if practice_carstairs==`x' & exposed==0
		
		* use returned results
		local n=string(`r(unique)',"%12.0gc") 
		local percent=string((`r(unique)' / ${n`group'}) * 100, "%4.1f")
		
		* create string for output
		global carstairs_`group'_`x' "`n' (`percent'%)"	
	} /*end foreach group in exp unexp*/	
	
	* put output strings in excel file
	putexcel A`rowcount'="`: label (practice_carstairs) `x''" // use variable label for row caption
	putexcel B`rowcount'="${carstairs_cohort_`x'}",  hcenter
	putexcel C`rowcount'="${carstairs_exp_`x'}",  hcenter
	putexcel D`rowcount'="${carstairs_unexp_`x'}",  hcenter
	
	local ++rowcount
} /*end forvalues x=1/6*/

/*******************************************************************************
#7. BMI
*******************************************************************************/
putexcel A`rowcount'="Body mass index (kg/m2)****", bold
local ++rowcount

recode bmi_cat 1=0 2=1 3=2 4=3 .=4
label define bmicat3 0"Underweight (<20)" 1"Normal (20-24)" 2"Overweight (25-29)" 3"Obese (30+)" 4"Missing"
label values bmi_cat bmicat3

* loop through each BMI cat
levelsof bmi_cat, local(levels)
foreach i of local levels {
	foreach group in cohort exp unexp {
		if "`group'"=="cohort" unique patid if bmi_cat==`i'
		if "`group'"=="exp" unique patid if bmi_cat==`i' & exposed==1
		if "`group'"=="unexp" unique patid if bmi_cat==`i' & exposed==0
		
		* use returned results
		local n=string(`r(unique)',"%12.0gc") 
		local percent=string((`r(unique)' / ${n`group'}) * 100, "%4.1f")
		
		* create string for output
		global bmi_`group'_`i' "`n' (`percent'%)"	
	} /*end foreach group in exp unexp*/
	
	putexcel A`rowcount'="`: label (bmi_cat) `i''" // use variable label for row caption
	putexcel B`rowcount'="${bmi_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${bmi_exp_`i'}",  hcenter
	putexcel D`rowcount'="${bmi_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*******************************************************************************
#8. Smoking
*******************************************************************************/
putexcel A`rowcount'="Smoking status****", bold
local ++rowcount

* recode smoking status var >> assume current/ex smokers are current smokers
*currently 0=non smoker, 1=current 2=ex 12=current or ex
recode smokstatus 0=0 1=1 2=1 12=1 .=13
label define smok2 0"Non-smoker" 1"Current or ex-smoker" 13"Missing"
label values smokstatus smok2

* loop through each smoking cat
levelsof smokstatus, local(levels)
foreach i of local levels {
	foreach group in cohort exp unexp {
		if "`group'"=="cohort" unique patid if smokstatus==`i'
		if "`group'"=="exp" unique patid if smokstatus==`i' & exposed==1
		if "`group'"=="unexp" unique patid if smokstatus==`i' & exposed==0
		
		* use returned results
		local n=string(`r(unique)',"%12.0gc") 
		local percent=string((`r(unique)' / ${n`group'}) * 100, "%4.1f")
		
		* create string for output
		global smokstatus_`group'_`i' "`n' (`percent'%)"	
	} /*end foreach group in exp unexp*/
	
	putexcel A`rowcount'="`: label (smok) `i''" // use variable label for row caption
	putexcel B`rowcount'="${smokstatus_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${smokstatus_exp_`i'}",  hcenter
	putexcel D`rowcount'="${smokstatus_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*******************************************************************************
#9. Harmful alcohol
*******************************************************************************/
putexcel A`rowcount'="Harmful alcohol use (%)****", bold

* loop through exp and unexp
foreach group in cohort exp unexp {
	if "`group'"=="cohort" { 
		unique patid if harmfulalcohol==1 
		local denom=$nexp
		local col "B"
	}
	if "`group'"=="exp" { 
		unique patid if harmfulalcohol==1 & exposed==1
		local denom=$nexp
		local col "C"
	}
	if "`group'"=="unexp" { 
		unique patid if harmfulalcohol==1 & exposed==0
		local denom=$nunexp
		local col "D"
	}
	local n=string(`r(unique)',"%12.0gc")
	local percent=string((`r(unique)'/`denom')*100, "%4.1f")
	local harmfulalcohol "`n' (`percent'%)"
	
	putexcel `col'`rowcount'="`harmfulalcohol'",  hcenter
} /*end foreach group in cohort exp unexp*/

local ++rowcount

/*******************************************************************************
#10. Sleep problems
*******************************************************************************/
putexcel A`rowcount'="Problems with sleep (%)****", bold

* loop through exp and unexp
foreach group in cohort exp unexp {
	if "`group'"=="cohort" { 
		unique patid if sleep==1 
		local denom=$nexp
		local col "B"
	}
	if "`group'"=="exp" { // exposed
		unique patid if sleep==1 & exposed==1
		local denom=$nexp
		local col "C"
	}
	if "`group'"=="unexp" { // unexp
		unique patid if sleep==1 & exposed==0
		local denom=$nunexp
		local col "D"
	}
	local n=string(`r(unique)',"%12.0gc")
	local percent=string((`r(unique)'/`denom')*100, "%4.1f")
	local sleep "`n' (`percent'%)"
	
	putexcel `col'`rowcount'="`sleep'",  hcenter
} /*end foreach group in cohort exp unexp*/

local ++rowcount

/*******************************************************************************
#11. Ethnicity
*******************************************************************************/
* recode ethnicity and create new var
recode eth5 0=0 1=1 2=2 3=3 4=4 5=5 .=5, gen(ethnicity)
label define ethnicity 0"White" 1"South Asian" 2"Black" 3"Other" 4"Mixed" 5"Not stated or missing"
label values ethnicity ethnicity
tab ethnicity eth5, miss

* row caption
putexcel A`rowcount'="Ethnicity", bold
local ++rowcount

* loop through each ethnicity cat
levelsof ethnicity, local(levels)
foreach i of local levels {
	foreach group in cohort exp unexp {
		if "`group'"=="cohort" unique patid if ethnicity==`i'
		if "`group'"=="exp" unique patid if ethnicity==`i' & exposed==1
		if "`group'"=="unexp" unique patid if ethnicity==`i' & exposed==0
		
		* use returned results
		local n=string(`r(unique)',"%12.0gc") 
		local percent=string((`r(unique)' / ${n`group'}) * 100, "%4.1f")
		
		* create string for output
		global eth_`group'_`i' "`n' (`percent'%)"	
	} /*end foreach group in exp unexp*/
	
	putexcel A`rowcount'="`: label (ethnicity) `i''" // use variable label for row caption
	putexcel B`rowcount'="${eth_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${eth_exp_`i'}",  hcenter
	putexcel D`rowcount'="${eth_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*******************************************************************************
#12. Charlson comorbidity
*******************************************************************************/
putexcel A`rowcount'="Charlson comorbidity index****", bold
local ++rowcount

* loop through each cci cat
levelsof cci, local(levels)
foreach i of local levels {
	foreach group in cohort exp unexp {
		if "`group'"=="cohort" unique patid if cci==`i'
		if "`group'"=="exp" unique patid if cci==`i' & exposed==1
		if "`group'"=="unexp" unique patid if cci==`i' & exposed==0
		
		* use returned results
		local n=string(`r(unique)',"%12.0gc") 
		local percent=string((`r(unique)' / ${n`group'}) * 100, "%4.1f")
		
		* create string for output
		global cci_`group'_`i' "`n' (`percent'%)"	
	} /*end foreach group in exp unexp*/
	
	putexcel A`rowcount'="`: label (cci) `i''" // use variable label for row caption
	putexcel B`rowcount'="${cci_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${cci_exp_`i'}",  hcenter
	putexcel D`rowcount'="${cci_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/


* put top border on next row
foreach col in A B C {
	putexcel `col'`rowcount'="" , border(top, thin, black)
}

local ++rowcount

/*******************************************************************************
#13. Footnotes
*******************************************************************************/
putexcel A`rowcount'="IQR: Interquartile range"
local ++rowcount

putexcel A`rowcount'="Individuals can contribute data as both eczema exposed and unexposed. Therefore, numbers of exposed/unexposed do not total the whole cohort, as individuals may be included in more than one column."
local ++rowcount

putexcel A`rowcount'="*Follow-up based on censoring at the earliest of: death, no longer registered with practice, practice no longer contributing to CPRD, or severe mental illness diagnosis"
local ++rowcount

putexcel A`rowcount'="** Age at index date"
local ++rowcount

putexcel A`rowcount'="*** Carstairs deprivation index based on practice-level data (from 2011)."
local ++rowcount

putexcel A`rowcount'="**** Based on records closest to index date."
local ++rowcount

********************************************************************************
/*******************************************************************************
TABLE 1 PYARS
*******************************************************************************/
*open dataset
use "${pathCohort}/cohort-eczema-main", clear

/*******************************************************************************
#1. Person years at risk (total and median)
*******************************************************************************/
* fu for each observation
gen fu_time=_t-_t0 // fu time duration

* loop through exposed and unexposed
foreach group in cohort exp unexp {
	preserve
		* keep relevant patids
		if "`group'"=="exp" keep if exposed==1
		if "`group'"=="unexp" keep if exposed==0
		
		* collapse
		collapse (sum)fu_time, by(patid)
		summ fu_time, detail 
		
		* total
		global `group'_pyar=`r(sum)'
		
		* median
		local p50=string(`r(p50)', "%4.1f")
		local p25=string(`r(p25)', "%4.1f")
		local p75=string(`r(p75)', "%4.1f")
		global `group'_median "`p50' (`p25'-`p75')"	
	restore
} /*end foreach group in cohort exp unexp*/

/*******************************************************************************
#2. label and recode variables
*******************************************************************************/
*Label variables
label var sleep "Problems with sleep"
label var steroids "High dose oral glucocorticoids"
label var sex "Sex"
label var practice_carstairs "Carstairs index quintile"
label var cci "Charlson comorbidity index"
label var smokstatus "Smoking status"

recode bmi_cat 1=0 2=1 3=2 4=3 .=4
label define bmicat3 0"Underweight (<20)" 1"Normal (20-24)" 2"Overweight (25-29)" 3"Obese (30+)" 4"Missing"
label values bmi_cat bmicat3

recode smokstatus 0=0 1=1 2=1 12=1 .=13
label define smok2 0"Non-smoker" 1"Current or ex-smoker" 13"Missing"
label values smokstatus smok2

recode eth5 0=0 1=1 2=2 3=3 4=4 5=5 .=5, gen(ethnicity)
label define ethnicity 0"White" 1"South Asian" 2"Black" 3"Other" 4"Mixed" 5"Not stated or missing"
label values ethnicity ethnicity
tab ethnicity eth5, miss

recode practice_carstairs 1=1 2=2 3=3 4=4 5=5 .=6
label define carstairs 1"1(least deprived)" 2"2" 3"3" 4"4" 5"5(most deprived)" 6"Missing"
label values practice_carstairs carstairs  

/*******************************************************************************
#3. loop through exposed and unexposed and identify tect for each table cell
*******************************************************************************/
foreach group in cohort exp unexp {
	preserve
		* keep relevant patids
		if "`group'"=="exp" keep if exposed==1
		if "`group'"=="unexp" keep if exposed==0
		
	
		/*--------------------------------------------------------------------------
		#3.1 Binary covariates (except sex)
		--------------------------------------------------------------------------*/
		local bincv " "harmfulalcohol" "sleep" "steroids" "
		foreach cv in `bincv' {
			summ fu_time if `cv'==1
			local pyar=string(`r(sum)',"%9.0fc")
			local percent=string((`r(sum)' / ${`group'_pyar}) * 100, "%4.1f" )
			
			* create string for output
			global `cv'_`group' "`pyar' (`percent'%)" 
		}/*end foreach cv in `bincv'*/
		
		/*--------------------------------------------------------------------------
		#3.1.1 Sex
		--------------------------------------------------------------------------*/
		local sexcv " "sex" "
		foreach cv in `sexcv' {
			summ fu_time if `cv'==2
			local pyar=string(`r(sum)',"%9.0fc")
			local percent=string((`r(sum)' / ${`group'_pyar}) * 100, "%4.1f" )
			
			* create string for output
			global `cv'_`group' "`pyar' (`percent'%)" 
		}/*end foreach cv in `sexcv'*/
		
		
		/*--------------------------------------------------------------------------
		#3.2 multilevel covariates
		--------------------------------------------------------------------------*/	
		local multicv ""practice_carstairs" "ethnicity" "smokstatus" "bmi_cat" "cci" "
		local multicv "`multicv' "age_grp" "calendarperiod" "
		foreach cv in `multicv' {
			levelsof `cv', local(levels)
			foreach i of local levels {
				summ fu_time if `cv'==`i'
				
				* use returned results
				local pyar=string(`r(sum)',"%9.0fc") 
				local percent=string((`r(sum)' / ${`group'_pyar}) * 100, "%4.1f")
				
				* create string for output
				global `cv'_`group'_`i' "`pyar' (`percent'%)"
			} /*end foreach i of local levels*/
		}/*end foreach cv in `multicv'*/
		
/*******************************************************************************
>> end loop and restore dataset
*******************************************************************************/
	restore
} /*end foreach group in exp unexp*/

/*******************************************************************************
#4. put data in excel
*******************************************************************************/
* add sheet to existing excel file
putexcel set "${pathResults}/main-ecz-analysis.xlsx", sheet(baseline_pyar) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Person-time under follow-up broken down by individual-level characteristics and atopic eczema exposure status." 
local ++rowcount // increment row couter variable
putexcel A`rowcount'="Values are pyar (percentages) unless stated otherwise"
local ++rowcount // increment row couter variable

* set up column headers
putexcel A`rowcount'="", border(top, thin, black)
putexcel B`rowcount'="Whole cohort", bold hcenter border(top, thin, black)
putexcel C`rowcount'="With atopic eczema", bold hcenter border(top, thin, black)
putexcel D`rowcount'="Without atopic eczema", bold hcenter border(top, thin, black)

local ++rowcount

* put data in excel file
* total person years
putexcel A`rowcount'="Total person-years", border(top, thin, black)
foreach group in cohort exp unexp {
	if "`group'"=="cohort" local col "B"
	if "`group'"=="exp" local col "C"
	if "`group'"=="unexp" local col "D"

	local pyar ${`group'_pyar}
	putexcel `col'`rowcount'=`pyar', hcenter nformat(#,###0) border(top, thin, black)
} /*end foreach group in exp unexp*/
local ++rowcount

* median
putexcel A`rowcount'="Median (IQR) duration of follow-up (years)"
foreach group in cohort exp unexp {
	if "`group'"=="cohort" local col "B"
	if "`group'"=="exp" local col "C"
	if "`group'"=="unexp" local col "D"

	local median "${`group'_median}"
	putexcel `col'`rowcount'="`median'", hcenter
} /*end foreach group in exp unexp*/
local ++rowcount

/*----------------------------------------------------------------------------*/
* sex
putexcel A`rowcount'="Sex", bold
local ++rowcount

putexcel A`rowcount'="Female (%)"
putexcel B`rowcount'="${sex_cohort}",  hcenter
putexcel C`rowcount'="${sex_exp}",  hcenter
putexcel D`rowcount'="${sex_unexp}",  hcenter
local ++rowcount

/*----------------------------------------------------------------------------*/
* age group
putexcel A`rowcount'="Age (years)", bold
local ++rowcount

levelsof age_grp, local(levels)
foreach i of local levels {
	putexcel A`rowcount'="`: label (age_grp) `i''" // use variable label for row caption
	putexcel B`rowcount'="${age_grp_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${age_grp_exp_`i'}",  hcenter
	putexcel D`rowcount'="${age_grp_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*----------------------------------------------------------------------------*/
* Carstairs
putexcel A`rowcount'="Qunitiles of carstairs deprivation index**", bold
local ++rowcount

* loop through each quintile
forvalues x=1/6 {
	putexcel A`rowcount'="`: label (practice_carstairs) `x''" // use variable label for row caption
	putexcel B`rowcount'="${practice_carstairs_cohort_`x'}",  hcenter
	putexcel C`rowcount'="${practice_carstairs_exp_`x'}",  hcenter
	putexcel D`rowcount'="${practice_carstairs_unexp_`x'}",  hcenter
	
	local ++rowcount
} /*end forvalues x=1/5*/

/*----------------------------------------------------------------------------*/
* BMI
putexcel A`rowcount'="Body mass index (kg/m2)***", bold
local ++rowcount

* loop through each BMI cat
levelsof bmi_cat, local(levels)
foreach i of local levels {
	putexcel A`rowcount'="`: label (bmi_cat) `i''" // use variable label for row caption
	putexcel B`rowcount'="${bmi_cat_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${bmi_cat_exp_`i'}",  hcenter
	putexcel D`rowcount'="${bmi_cat_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*----------------------------------------------------------------------------*/
* Smoking
putexcel A`rowcount'="Smoking***", bold
local ++rowcount

* loop through each smoking cat
levelsof smokstatus, local(levels)
foreach i of local levels {
	putexcel A`rowcount'="`: label (smokstatus) `i''" // use variable label for row caption
	putexcel B`rowcount'="${smokstatus_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${smokstatus_exp_`i'}",  hcenter
	putexcel D`rowcount'="${smokstatus_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/


/*----------------------------------------------------------------------------*/
* Harmful alcohol 
putexcel A`rowcount'="Harmful alcohol use (%)", bold

putexcel B`rowcount'="${harmfulalcohol_cohort}",  hcenter
putexcel C`rowcount'="${harmfulalcohol_exp}",  hcenter
putexcel D`rowcount'="${harmfulalcohol_unexp}",  hcenter
local ++rowcount 


/*----------------------------------------------------------------------------*/
* Problems with sleep
putexcel A`rowcount'="Problems with sleep (%)", bold

putexcel B`rowcount'="${sleep_cohort}",  hcenter
putexcel C`rowcount'="${sleep_exp}",  hcenter
putexcel D`rowcount'="${sleep_unexp}",  hcenter
local ++rowcount 


/*----------------------------------------------------------------------------*/
* Ethnicity
* row caption
putexcel A`rowcount'="Ethnicity", bold
local ++rowcount

* loop through each ethnicity cat
levelsof ethnicity, local(levels)
foreach i of local levels {
	putexcel A`rowcount'="`: label (ethnicity) `i''" // use variable label for row caption
	putexcel B`rowcount'="${ethnicity_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${ethnicity_exp_`i'}",  hcenter
	putexcel D`rowcount'="${ethnicity_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/


/*----------------------------------------------------------------------------*/
* Charlson comorbidity index
* row caption
putexcel A`rowcount'="Charlson comorbidity index***", bold
local ++rowcount

* loop through each cci cat
levelsof cci, local(levels)
foreach i of local levels {
	putexcel A`rowcount'="`: label (cci) `i''" // use variable label for row caption
	putexcel B`rowcount'="${cci_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${cci_exp_`i'}",  hcenter
	putexcel D`rowcount'="${cci_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*----------------------------------------------------------------------------*/
* Calendar period
* row caption
putexcel A`rowcount'="Calendar period", bold
local ++rowcount

* loop through each Calendar period cat
levelsof calendarperiod, local(levels)
foreach i of local levels {
	putexcel A`rowcount'="`: label (calendarperiod) `i''" // use variable label for row caption
	putexcel B`rowcount'="${calendarperiod_cohort_`i'}",  hcenter
	putexcel C`rowcount'="${calendarperiod_exp_`i'}",  hcenter
	putexcel D`rowcount'="${calendarperiod_unexp_`i'}",  hcenter
	
	local ++rowcount // increment row counter so that next iteration of loop put on next row
} /*end foreach i of local levels*/

/*----------------------------------------------------------------------------*/
* Steroids 
putexcel A`rowcount'="High-dose oral glucocorticoids (20mg+ prednisolone equivalent dose)", bold

putexcel B`rowcount'="${steroids_cohort}",  hcenter
putexcel C`rowcount'="${steroids_exp}",  hcenter
putexcel D`rowcount'="${steroids_unexp}",  hcenter
local ++rowcount 

* put top border on next row
foreach col in A B C D {
	putexcel `col'`rowcount'="" , border(top, thin, black)
}

local ++rowcount

/*----------------------------------------------------------------------------*/
* Footnotes 
putexcel A`rowcount'="IQR: Interquartile range"
local ++rowcount

putexcel A`rowcount'="Individuals can contribute data as both eczema exposed and unexposed. Therefore, pyar for exposed/unexposed do not total the whole cohort, as individuals may be included in more than one column."
local ++rowcount

putexcel A`rowcount'="* Follow-up based on censoring at the earliest of: death, no longer registered with practice, practice no longer contributing to CPRD, or severe mental illness diagnosis"
local ++rowcount

putexcel A`rowcount'="** Carstairs deprivation index based on practice-level data (from 2011)"
local ++rowcount

putexcel A`rowcount'="*** Based on records closest to index date."
local ++rowcount


log close
exit


