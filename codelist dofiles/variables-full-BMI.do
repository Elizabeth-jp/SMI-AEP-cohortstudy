/*******************************************************************************
DO FILE NAME:			variables-${ABBRVexp}-BMI.do

AUTHOR:					Elizabeth Adesanya
						uses code from KB BMI algorithm and adapted from KM
						version that accomodates multiple index dates

VERSION:				v1
DATE VERSION CREATED: 	07/04/2021

TASK:					Aim is to identify BMI status based on the closest 
						record to the index date

DATASET(S)/FILES USED:	Clinical_extract_${ABBRVexp}_extract3_ALL// appended CPRD clinical extract files 1 to 7
						Clinical_extract_${ABBRVexp}_extract3_ALL // appended CPRD additional extract files 1 to 3
						Patient_extract_${ABBRVexp}_extract3_1
						${ABBRVexp}_indexdates
						SkinEpiExtract-paths.do
						

DATASETS CREATED:		${ABBRVexp}-BMI-all/ BMI data for all patid and indexdate combinations
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 15
clear all
set linesize 80
 
* find path file location and run it
skinepipaths_v2

* create a filename global that can be used throughout the file
global filename "variables-${ABBRVexp}-BMI"

*open log file
log using "${pathLogs}/${filename}", text replace 
adopath + "${pathShareAdo}"
adopath + "${pathPrograms}"
/*******************************************************************************
#1. Loop through each patient/indexdate combination and extract BMI data 
	using KB ado file - then create one large file containing data for each 
	indexdate for each patient
*******************************************************************************/
set varabbrev off

forvalues n=1/1 { // removed 1/3 forvalues - only one indexdate in ecz_indexdates
	use ${pathOut}/${ABBRVexp}_indexdates, clear
	keep patid indexdate // only keep indexdates for this iteration
	rename indexdate indexdate
	keep if indexdate!=.
	sort patid indexdate
	bysort patid: keep if _n == 1

	* run program
	pr_getbmistatus, index(indexdate) ///
		patientfile(${pathIn}/Patient_extract_${ABBRVexp}_extract3_1) ///
		clinicalfile(${pathIn}/ClinicalALL_extract_${ABBRVexp}_extract3) ///
		additionalfile(${pathIn}/AdditionalALL_extract_${ABBRVexp}_extract3)
	order patid indexdate

	* save resulting file first time through the loop
	if `n'==1 {
		save ${pathOut}/${ABBRVexp}-BMI-all, replace
	} /*end if `n'==1 */
	
	* if not first time through the loop: append and then save
	if `n'>1 {
		append using ${pathOut}/${ABBRVexp}-BMI-all
		sort patid indexdate
		save ${pathOut}/${ABBRVexp}-BMI-all, replace
	} /*end if `n'>1 */
} /*end forvalues n=1/3*/

*label and save
sort patid indexdate
label data "${exposure}ema BMI status - all patid/indexdate combinations"
notes: eczema BMI status - all patid/indexdate combinations
notes: ${filename} / TS		
compress
save ${pathOut}/variables-${ABBRVexp}-BMI-all, replace

log close
exit
