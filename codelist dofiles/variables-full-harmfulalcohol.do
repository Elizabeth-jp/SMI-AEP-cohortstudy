/*******************************************************************************
DO FILE NAME:			variables-${ABBRVexp}-harmfulalcohol.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	29/04/2021

TASK:					Aim is to take extracted data for harmful alcohol and
						antabuse and identify the earliest record

DATASETS USED:			${ABBRVexp}-clinical-harmfulalcohol//records from clinical extract file
						${ABBRVexp}-referral-harmfulalcohol//records from referral extract files
						${ABBRVexp}-therapy-antabuse//records from therapy file
						skinepipaths
						
DATASETS CREATED: 		${ABBRVexp}-harmfulalcohol//definite and possible sleep records
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 15
clear all
set linesize 80

*find path file location and run it
skinepipaths_v2

* create a filename global that can be used throughout the file
global filename "variables-${ABBRVexp}-harmfulalcohol"

*open log file
log using "${pathLogs}/${filename}", text replace 


/*******************************************************************************
#1. Extract data from files in the CPRD Clinical and Referral files
*******************************************************************************/
* run programs
run ${pathPrograms}/prog_getCodeCPRD
run ${pathPrograms}/prog_identifyTherapy.do

filelist , dir(${pathOut}) pattern("${ABBRVexp}-Clinical-harmfulalcohol*")
if `r(N)' < 1 {
	foreach filetype in Clinical Referral  {
		if "`filetype'"=="Clinical" {
			local nfiles=$totalClinicalFiles
		}
		if "`filetype'"=="Referral" {
			local nfiles=$totalReferralFiles
		} 
		prog_getCodeCPRD, clinicalfile("${pathIn}/`filetype'_extract_${ABBRVexp}_extract3") ///
			clinicalfilesnum(`nfiles') ///
			codelist("${pathCodelists}/medcodes-harmfulalcohol") /// 
			diagnosis(harmfulalcohol) ///
			savefile("${pathOut}/${ABBRVexp}-`filetype'-harmfulalcohol")
	} /*end foreach file in Clinical Referral*/
}

/*******************************************************************************
#2. Extract therapy data
*******************************************************************************/
prog_identifyTherapy, ///
	therapyfile("${pathIn}/Therapy_extract_${ABBRVexp}_extract3") /// path and file name (minus _filenum) of extract file
	codelist("${pathCodelists}/prodcodes-antabuse") ///	path and file name for prodcode list
	filenum($totalTherapyFiles) ///	number of extract files
	dofilename($filename) /// name of this do file to include in the saved file notes
	savefile("${pathOut}/${ABBRVexp}-therapy-antabuse")	// name of file to save antabuse therapy prescription data to
	
	
/*******************************************************************************
#1. Append datasets for all 3 sources of harmful alcohol records
*******************************************************************************/
filelist , dir("${pathOut}") pattern("${ABBRVexp}-therapy-antabuse-*")
drop if regexm(filename, "edited-")
qui count
local filenum  = r(N)
di "`filenum'"

forvalues i = 1/`filenum'{
	di "`i'", _cont
	qui{
	use ${pathOut}/${ABBRVexp}-therapy-antabuse-`i', clear
	
	*change date formats from long to int
	*eventdate
	tostring eventdate, replace format(%20.0f)
	replace eventdate="0"+ eventdate if length(eventdate)==7
	gen eventdate2=date(eventdate,"YMD")
	format eventdate2 %td
	drop eventdate
	rename eventdate2 eventdate

	*sysdate
	tostring sysdate, replace format(%20.0f)
	replace sysdate="0"+ sysdate if length(sysdate)==7
	gen sysdate2=date(sysdate,"YMD")
	format sysdate2 %td
	drop sysdate
	rename sysdate2 sysdate

	order patid eventdate sysdate


	sort patid eventdate


	* deal with dates
	replace eventdate=sysdate if sysdate!=. & eventdate==.
	count if eventdate==.

	*identify source
	gen src=2

	*sort patid eventdate

	/*******************************************************************************
	#3. Keep first record of sleep problems from any source for each patient
	*******************************************************************************/
	keep patid eventdate prodcode ingredient bnftext src //keep only useful data
	sort patid eventdate
	}
	bysort patid: keep if _n==1

	*label and save
	compress
	save ${pathOut}/${ABBRVexp}-therapy-antabuse-edited-`i', replace
}

/*******************************************************************************
#2. Repeat for Clinical and Referral files as well
*******************************************************************************/
use ${pathOut}/${ABBRVexp}-therapy-antabuse-edited-1, clear
forvalues i = 1/`filenum'{
	append using ${pathOut}/${ABBRVexp}-therapy-antabuse-edited-`i'
}
save ${pathOut}/${ABBRVexp}-Therapy-harmfulalcohol, replace // Used to save this but no need now since we do the editing first before appending the files together. Just save definite codes a few lines later
//use ${pathOut}/${ABBRVexp}-Therapy-harmfulalcohol ,clear
append using ${pathOut}/${ABBRVexp}-Clinical-harmfulalcohol
append using ${pathOut}/${ABBRVexp}-Referral-harmfulalcohol

sort patid eventdate

* deal with dates
replace eventdate=sysdate if sysdate!=. & eventdate==.
count if eventdate==.

*identify source
recode src .=1

label define src 1"Read code" 2"prescription"
label values src src

tab src, missing

/*******************************************************************************
#2. Keep first record of alcohol problems from any source for each patient
*******************************************************************************/
keep patid eventdate src prodcode ingredient bnftext medcode readterm //keep only useful data
sort patid eventdate
bysort patid: keep if _n==1

*review the source of the first record
tab src, missing
/*
         src |      Freq.     Percent        Cum.
-------------+-----------------------------------
   Read code |    390,269       98.99       98.99
prescription |      3,973        1.01      100.00
-------------+-----------------------------------
       Total |    394,242      100.00
*/

*label and save
label data "${exposure} - earliest record of harmful alcohol use"
notes: ${exposure} - earliest record of harmful alcohol use
notes: ${filename} / TS		
compress
save ${pathOut}/variables-${ABBRVexp}-harmfulalcohol, replace

*erase datasets that are no longer useful
/*
cap erase "${pathOut}/${ABBRVexp}-Clinical-harmfulalcohol.dta"
cap erase "${pathOut}/${ABBRVexp}-Referral-harmfulalcohol.dta"
cap erase " ${pathOut}/${ABBRVexp}-Therapy-harmfulalcohol.dta"
*/
forvalues i=1/`filenum'{
di  "`i'"
cap erase "${pathOut}/${ABBRVexp}-therapy-antabuse-edited-`i'.dta"
cap erase "${pathOut}/${ABBRVexp}-therapy-antabuse-`i'.dta"
}

log close
exit