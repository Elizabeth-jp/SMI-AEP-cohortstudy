/*******************************************************************************
DO FILE NAME:			variables-full-cci.do

AUTHOR:					Elizabeth Adesanya (based on do files from Angel Wong)

VERSION:				v1

DATE VERSION CREATED: 	26/10/2021

TASK:					Extract and categorise Charlson Comorbidity Index for 
						${ABBRVexp}riasis cohort
						
DATASETS USED:			Combined_CCI_CPRD.dta
						Diabetes_CPRD.dta
						
						
DATASETS CREATED: 		variables_${ABBRVexp}_cci

*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 16
clear all
set max_memory 100g
set more off
set linesize 80
	
* change directory to the location of the paths file and run the file	
skinepipaths_v2
dib "${exposure}"

* create a filename global that can be used throughout the file
global filename "${ABBRVexp}-cci"

*open log file
log using "${pathLogs}/${filename}", text replace 

/*******************************************************************************
Extract comorbidity data from clinical and referral files
*******************************************************************************/
* Clinical files
forvalues j = 1/$totalClinicalFiles {
	foreach i in Diabetes Combined_CCI {
		use "${pathIn}/Clinical_extract_${ABBRVexp}_extract3_`j'", clear
		keep patid eventdate medcode
		preserve
		merge m:1 medcode using "${pathCodelists}/`i'_CPRD", keep(match) nogen
		save "${pathOut}/${ABBRVexp}_Clinical_`i'_`j'.dta", replace
		restore
	}
}

* Referral files 
foreach i in Diabetes Combined_CCI {
	use "${pathIn}/Referral_extract_${ABBRVexp}_extract3_1", clear
	keep patid eventdate medcode
	preserve
	merge m:1 medcode using "${pathCodelists}/`i'_CPRD", keep(match) nogen
	save "${pathOut}/${ABBRVexp}_Referral_`i'.dta", replace
	restore 
}

*Combine records for each category in CPRD Clinical and referral files 
foreach i in Diabetes Combined_CCI {
	use "${pathOut}/${ABBRVexp}_Clinical_`i'_1.dta", clear
	forvalues j = 2/$totalClinicalFiles {	
		append using "${pathOut}/${ABBRVexp}_Clinical_`i'_`j'.dta"
	}
		append using "${pathOut}/${ABBRVexp}_Referral_`i'.dta"
		save "${pathOut}/${ABBRVexp}_ClinRef_`i'.dta", replace
}

*erase interim files
forvalues j = 1/$totalClinicalFiles {
	foreach i in Diabetes Combined_CCI {
		erase "${pathOut}/${ABBRVexp}_Clinical_`i'_`j'.dta"
}
}

foreach i in Diabetes Combined_CCI {
	erase "${pathOut}/${ABBRVexp}_Referral_`i'.dta"
}

/*******************************************************************************
Extract antidiabetics prescription data from therapy file (diabetes comorbidity)
*******************************************************************************/
run ${pathPrograms}/prog_identifyTherapy.do

prog_identifyTherapy, ///
	therapyfile("${pathIn}/Therapy_extract_${ABBRVexp}_extract3") /// path and file name (minus _filenum) of extract file
	codelist("${pathCodelists}/Antidiabetics") ///	path and file name for prodcode list
	filenum($totalTherapyFiles) ///	number of extract files
	dofilename($filename) /// name of this do file to include in the saved file notes
	savefile("${pathOut}/${ABBRVexp}-therapy-antidiabetics")	/// name of file to save antabuse therapy prescription data to
	
/*******************************************************************************
Identify CCI before index date
*******************************************************************************/
*Drop if no comorbidities identified and separate the comorbidities
foreach i in 1mi 1ccf 1pad 1stroke 1dement 1resp ///
1ctd 1peptic 1liver 2hemi 2renal 2diabcomp 2cancer ///
2leuk 2lymph 3liver 6mets 6hiv {
	use "${pathOut}/${ABBRVexp}_ClinRef_Combined_CCI.dta", clear 
	preserve 
	keep if cci_`i'!=0
	save "${pathOut}/${ABBRVexp}_`i'.dta"
	restore
}

*Identify if diagnosis is before indexdate
foreach i in 1mi 1ccf 1pad 1stroke 1dement 1resp ///
1ctd 1peptic 1liver 2hemi 2renal 2diabcomp 2cancer ///
2leuk 2lymph 3liver 6mets 6hiv {
	use "${pathOut}/${ABBRVexp}_indexdates_1record.dta", clear
	merge 1:m patid using "${pathOut}/${ABBRVexp}_`i'.dta", keep(match) keepusing(patid eventdate cci_`i') nogen
	keep if eventdate!=. & eventdate<indexdate1
	sort patid eventdate
	bysort patid: keep if _n==1 /*keeps earliest diagnosis*/
	keep patid eventdate indexdate1 cci_`i'
	save "${pathOut}/${ABBRVexp}_`i'_final.dta", replace
}

/*******************************************************************************
Diabetes
*******************************************************************************/
*append antidiabetics data 
use "${pathOut}/${ABBRVexp}-therapy-antidiabetics-1"
forvalues x=2/$totalTherapyFiles {
	append using "${pathOut}/${ABBRVexp}-therapy-antidiabetics-`x'"
}
save "${pathOut}/${ABBRVexp}-therapy-antidiabetics-all", replace
 
use "${pathOut}/${ABBRVexp}_ClinRef_Diabetes.dta", clear
merge m:1 patid using "${pathOut}/${ABBRVexp}_indexdates_1record.dta", keep(match) 
keep if eventdate!=. & eventdate<indexdate1
sort patid eventdate
gen cci_1diab=1
rename eventdate diab_date
label var cci_1diab "Diabetes diagnosis before followup started"
label var diab_date "date of the first diabetes diagnosis"

drop _merge 
*merge in yob data
merge m:1 patid using "${pathOut}/variables-${ABBRVexp}-age-sex-gp.dta", keep (match)
drop if diab_date<=realyob
drop _merge

***Variable identifying if ALL Possible codes
sum patid
if r(N)!=0 { 
bysort patid: egen poss_only_temp=mean(diab_cat)
bysort patid: gen poss_only=1 if poss_only_temp==2
noi di "Patients with ALL Possible codes"
noi cap codebook patid if poss_only==1

*Create variable type from READ code
gen read_cat=diab_cat
recode read_cat 6=. 2=. 3=1 4=2
bysort patid: egen dm_read=mean(read_cat)
recode dm_read .=0 
replace dm_read=3 if dm_read>1 & dm_read<2
lab def dm_read 0 "No specified/confirmed DM" 1 "T1DM" 2 "T2DM"	3 "Conflicting codes"
lab val dm_read dm_read
tab dm_read

***AGE at diagnosis variable:
gen age_diab_diag=(diab_date-realyob)/365.25
gsort patid diab_date
by patid: keep if _n==1 /*keeps earliest DM diagnosis: create 1 record per patient*/

***TREATMENT variable
preserve
	use "${pathOut}/${ABBRVexp}-therapy-antidiabetics-all", clear
	keep patid eventdate diab_med mono_metformin
	describe
	summ diab_med
	save "${pathOut}/${ABBRVexp}-therapy-antidiabetics-all-small", replace	
restore
merge 1:m patid using "${pathOut}/${ABBRVexp}-therapy-antidiabetics-all-small", keep(match master)


*Drop diabetes meds pre-DM diagnosis and on/after 1 month before the matchedcohort partner death
bysort patid diab_med: drop if (eventdate<diab_date | eventdate>=indexdate1) & _n!=1 //drop entries where the second/ further DM meds taken pre-DM dx
replace diab_med=. if eventdate<diab_date | eventdate>=indexdate1 // after the previous step, only the first DM med either insulin/oads taken pre-DM dx remains

*Generate indicator summarises DM trt since diagnosis:
bysort patid: egen dm_trt=mean(diab_med)
recode dm_trt .=0 
replace dm_trt=3 if dm_trt>1 & dm_trt<2
lab define dm_trt  0 "No trt" 1 "Insulin only" 2 "OAD only" 3 "OAD and Insulin" 
lab val dm_trt dm_trt
tab dm_trt

*Drop patients with ONLY possible DM diagnoses and NO DM-specific Rx
drop if poss_only==1 & dm_trt==0

cap codebook patid /*Number of Patients with confirmed DM diagnosis*/
bysort patid: keep if _n==1

gen diab_type=1 if (age_diab_diag<=35 & dm_trt==1) /*exclusively insulin and first DM diagnosis <=35*/
recode diab_type .=2 if age_diab_diag>35 /*diagnosis at age > 35*/
recode diab_type 2=3 if age_diab_diag>35 & dm_trt==1 /*diagnosis at age > 35 and only ever insulin*/
recode diab_type .=3

lab def diab_type  3 "Unknown" 1 "Type 1" 2 "Type 2" 0 "No diabetes"
lab val diab_type diab_type
tab diab_type
}

save "${pathOut}/${ABBRVexp}-diab_def", replace

*************************Diabetes: with treatment only**********************
*Keep DM therapy events occur before indexdate (this also bring in indexdate) 
****Treatment only

use "${pathOut}/${ABBRVexp}-therapy-antidiabetics-all-small", clear 
merge m:1 patid using "${pathOut}/${ABBRVexp}_indexdates_1record.dta", keep(match) nogen

*date conversion of eventadte variable
tostring eventdate, replace format(%20.0f)
	gen eventdate1=date(eventdate,"YMD")
	format eventdate1 %td
	drop eventdate
	rename eventdate1 eventdate

keep if indexdate1>=eventdate 

merge m:1 patid using "${pathOut}/variables-${ABBRVexp}-age-sex-gp.dta", keep (match) nogen
drop if eventdate<=realyob
gen diab_meds=1
rename eventdate diab_meds_date
label var diab_meds "DM medications before the followup started"
label var diab_meds_date "Rx date of DM meds"
save "${pathOut}/${ABBRVexp}-diab_meds", replace

use "${pathOut}/${ABBRVexp}_ClinRef_Diabetes.dta"
merge m:1 patid using "${pathOut}/${ABBRVexp}_indexdates_1record.dta", keep(match) 
keep if eventdate!=. & eventdate<indexdate1
cap duplicates drop patid, force
drop _merge
merge 1:m patid using "${pathOut}/${ABBRVexp}-diab_meds", keep(using)
drop if diab_meds_date<=realyob
cap codebook patid 
bysort patid: drop if _N==1 /*had to have at least TWO DM meds*/

if r(N)!=0 {
cap codebook patid
gen age_diab_meds=(diab_meds_date-realyob)/365.25
*Identifies patients with only OADs over 35 years
bysort patid: egen oad_only_temp=min(diab_med) // Insulin is coded 1, so patients with min 1 have recevied insulin
by patid: gen oad_only_temp2=1 if oad_only_temp==2 & age_diab_meds>35
recode oad_only_temp2 .=0
by patid: egen oad_only=min(oad_only_temp2)
recode oad_only .=1
lab define oad_only 1 "OAD only after 35 years" 
lab val oad_only oad_only

*Women treated with metformin alone in age 20-39
*If treatment continued after age 40 they will be included 
recode mono_metformin .=0
bysort patid: egen met_only_temp=min(mono_metformin)
by patid: gen met_only_temp2=1 if met_only_temp==1 & age_diab_meds>=20 & age_diab_meds<40 & gender==2
recode met_only_temp2 .=0
by patid: egen met_only=min(met_only_temp2)
recode met_only .=1
lab define met_only 1 "PCOS" 
lab val met_only met_only
drop if met_only==1

*Codes according to type of diabetes
sort patid diab_meds_date
bysort patid: gen diab_type_temp=1 if (diab_med[1]==1 & diab_med[2]==1 & age_diab_meds[1]<=35  & age_diab_meds[2]<=35) /*patients received at least two insulin prescriptions =35 years*/
bysort patid: replace diab_type_temp=2 if (oad_only==1) /*patients received exclusively OADs >35 years*/ 
bysort patid: egen diab_type=max(diab_type_temp)
lab val diab_type diab_type
recode diab_type .=3
drop diab_type_temp
list patid diab_meds_date diab_med diab_type 
bysort patid: keep if _n==1
tab diab_type
gen cci_1diab=1
}

save "${pathOut}/${ABBRVexp}-diab_meds_only", replace
append using "${pathOut}/${ABBRVexp}-diab_def"
keep patid cci_1diab
save "${pathOut}/${ABBRVexp}_1diab_final", replace

/*******************************************************************************
Get final variable of CCI
*******************************************************************************/
use "${pathOut}/${ABBRVexp}_indexdates_1record.dta", clear
keep patid indexdate1

*Merge in variable data for CCI categories
foreach i in 1mi 1ccf 1pad 1stroke 1dement ///
1resp 1ctd 1peptic 1liver 1diab ///
2hemi 2renal 2diabcomp 2cancer 2leuk  ///
2lymph 3liver 6mets 6hiv {
joinby patid using "${pathOut}/${ABBRVexp}_`i'_final.dta", unmatched(master)
drop _merge
recode cci_`i' .=0
tab  cci_`i', mi
}

*Score for individual diseases
/*The scores for diseases have already been included. However, presence of some
diseases results in exclusion of scores for other scores. If a person has 
both mild and moderate/severe liver disease then the person should only get 
scores for the latter. The same applies to diabetes and diabetes with end organ failure
and to solid tumour and metastasic cancer. This will be accounted.
*/
replace cci_1liver=0 if cci_3liver==3
replace cci_1diab=0 if cci_2diabcomp==2
replace cci_2cancer=0 if cci_6mets==6

*Compute the total ACCI score
generate acci= cci_1mi + cci_1ccf + cci_1pad + cci_1stroke + cci_1dement ///
+ cci_1resp + cci_1ctd + cci_1peptic + cci_1liver + cci_1diab + ///
cci_2hemi + cci_2renal + cci_2diabcomp + cci_2cancer + cci_2leuk  ///
+ cci_2lymph + cci_3liver + cci_6mets + cci_6hiv
codebook acci
generate acci_grp=0 if acci==0
replace acci_grp=1 if acci>=1 & acci<=2 
replace acci_grp=2 if acci>=3
label var acci_grp "CCI group original"
label define acci_grp 0 "Low (0)" 1 "Moderate (1-2)" 2 "Severe (3 or more)"
label values acci_grp acci_grp
keep patid acci_grp cci_*
rename acci_grp cci

save "${pathOut}/variables-${ABBRVexp}-cci.dta", replace

*erase interim datasets to save space
foreach i in 1mi 1ccf 1pad 1stroke 1dement 1resp ///
1ctd 1peptic 1liver 2hemi 2renal 2diabcomp 2cancer ///
2leuk 2lymph 3liver 6mets 6hiv {
	erase "${pathOut}/${ABBRVexp}_`i'.dta"
}

foreach i in 1mi 1ccf 1pad 1stroke 1dement 1resp ///
1ctd 1peptic 1liver 2hemi 2renal 2diabcomp 2cancer ///
2leuk 2lymph 3liver 6mets 6hiv 1diab {
	erase "${pathOut}/${ABBRVexp}_`i'_final.dta"
}

erase "${pathOut}/${ABBRVexp}_ClinRef_Combined_CCI.dta"
erase "${pathOut}/${ABBRVexp}-therapy-antidiabetics-all.dta"
erase "${pathOut}/${ABBRVexp}-diab_def.dta"
erase "${pathOut}/${ABBRVexp}-diab_meds.dta"
