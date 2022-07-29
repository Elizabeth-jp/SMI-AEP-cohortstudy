/*******************************************************************************
DO FILE NAME:			main-pso-analysis-prophazards.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	24/03/2022

TASK:					Testing the proportional hazards assumption for the 
						psoriasis regression models
						
DATASET(S)/FILES USED:	cohort-psoriasis-main.dta
						


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
global filename "main-pso-analysis-prophazards"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
TESTING THE ASSUMPTION
*******************************************************************************/
*open analysis dataset
use "${pathCohort}/cohort-psoriasis-main", clear

/*----------------------------------------------------------------------------*/
* MINIMALLY ADJUSTED MODEL (adjusted for matched variables due to stratification by matched set)
stcox i.exposed, strata(setid) level(95) base

estat phtest, detail
*p value:0.0462 rounds up to 0.05 which means roportional hazards are not violated

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

estat phtest, detail
*p-value is 0.2514 - proportional hazards assumption still stands 

*exposed
estat phtest, plot(1.exposed) bwidth(0.5) recast(scatter) mcolor(black) msize(small) msymbol(point) lineopts(lwidth(thin))

graph save "${pathResults}/main-pso-prophazards.gph",replace

*unexposed 
estat phtest, plot(0b.exposed) bwidth(0.5) recast(scatter) mcolor(black) msize(small) msymbol(point) lineopts(lwidth(thin))

graph save "${pathResults}/main-pso-prophazards-unexposed.gph",replace

log close
exit