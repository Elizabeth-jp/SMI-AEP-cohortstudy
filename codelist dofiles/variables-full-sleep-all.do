/*******************************************************************************
DO FILE NAME:			variables-${ABBRVexp}-sleep-all.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	14/04/2021

TASK:					Aim is to take extracted data for sleep problems and 
						identify the earliest record

DATASETS USED:			${ABBRVexp}-clinical-sleep//records from clinical extract file
						${ABBRVexp}-referral-sleep//records from referral extract files
						${ABBRVexp}-therapy-sleep//records from therapy file
						SkinEpiExtract-paths.do
						
DATASETS CREATED: 		${ABBRVexp}-sleep-all//definite and possible sleep records
*******************************************************************************/
/*******************************************************************************
HOUSEKEEPING
*******************************************************************************/
capture log close
version 15
clear all
set linesize 80

* change directory to the location of the paths file and run the file	
skinepipaths_v2

* create a filename global that can be used throughout the file
global filename "variables-${ABBRVexp}-sleep-all"

*open log file
log using "${pathLogs}/${filename}", text replace 

dib "${exposure}", stars

/*******************************************************************************
#1. Extract data from files in the CPRD Clinical and Referral files
*******************************************************************************/
* run programs
run ${pathPrograms}/prog_getCodeCPRD
run ${pathPrograms}/prog_identifyTherapy.do

filelist , dir(${pathOut}) pattern("${ABBRVexp}-Clinical-sleep*")
if `r(N)' < 1 {
	foreach filetype in Clinical Referral {
		if "`filetype'"=="Clinical" {
			local nfiles=$totalClinicalFiles
		}
		if "`filetype'"=="Referral" {
			local nfiles=$totalReferralFiles
		} 
		prog_getCodeCPRD, clinicalfile("${pathIn}/`filetype'_extract_${ABBRVexp}_extract3") ///
			clinicalfilesnum(`nfiles') ///
			codelist("${pathCodelists}/medcodes-sleep") /// 
			diagnosis(sleepproblems) ///
			savefile("${pathOut}/${ABBRVexp}-`filetype'-sleep")
	} /*end foreach file in Clinical Referral*/
}
/*******************************************************************************
#2. Extract therapy data
*******************************************************************************/
prog_identifyTherapy, ///
	therapyfile("${pathIn}/Therapy_extract_${ABBRVexp}_extract3") /// path and file name (minus _filenum) of extract file
	codelist("${pathCodelists}/prodcodes-sleep") ///	path and file name for prodcode list
	filenum($totalTherapyFiles) ///	number of extract files
	dofilename($filename) /// name of this do file to include in the saved file notes
	savefile("${pathOut}/${ABBRVexp}-therapy-sleep")	// name of file to save sleep problem therapy prescription data to
	
/*******************************************************************************
#1. Append datasets for all 3 sources of sleep problem records
*******************************************************************************/

filelist , dir("${pathOut}") pattern("${ABBRVexp}-therapy-sleep-*.dta")
drop if regexm(filename , "edited")
qui count
local filenum  = r(N)
di "`filenum'"

forvalues i = 1/`filenum'{
	di "`i'", _cont
	qui{
	use ${pathOut}/${ABBRVexp}-therapy-sleep-`i', clear
	
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

	//save ${pathOut}/${ABBRVexp}-therapy-sleep, replace

	sort patid eventdate

	/* Save deifinite sleep codes in a separate file*/
	}
	preserve
		*only keep definite sleep records
		drop if Possibledrugs==1

		* deal with dates
		replace eventdate=sysdate if sysdate!=. & eventdate==.
		count if eventdate==.

		*identify source
		gen src=2

		*sort patid eventdate

		/*******************************************************************************
		#3. Keep first record of sleep problems from any source for each patient
		*******************************************************************************/
		keep patid eventdate src //keep only useful data
		sort patid eventdate
		bysort patid: keep if _n==1

		*label and save
		compress
		save ${pathOut}/${ABBRVexp}-therapy-sleep-definite-edited-`i', replace
	restore
	
	* deal with dates
	replace eventdate=sysdate if sysdate!=. & eventdate==.
	count if eventdate==.

	*identify source
	gen src=2

	*sort patid eventdate

	/*******************************************************************************
	#3. Keep first record of sleep problems from any source for each patient
	*******************************************************************************/
	keep patid eventdate src Possibledrugs  prodcode ingredient bnftext //keep only useful data
	sort patid eventdate
	
	*keep all sleep records 
	tab Possibledrugs

	bysort patid: keep if _n==1

	*label and save
	compress
	save ${pathOut}/${ABBRVexp}-therapy-sleep-edited-`i', replace
}


/*******************************************************************************
#2. Repeat for Clinical and Referral files as well
*******************************************************************************/
use ${pathOut}/${ABBRVexp}-therapy-sleep-edited-1, clear
forvalues i = 1/`filenum'{
	append using ${pathOut}/${ABBRVexp}-therapy-sleep-edited-`i'
}
save ${pathOut}/${ABBRVexp}-Therapy-sleep-all, replace // Used to save this but no need now since we do the editing first before appending the files together. JUst save definite codes a few lines later
//use ${pathOut}/${ABBRVexp}-Therapy-sleep-all, clear
append using ${pathOut}/${ABBRVexp}-Clinical-sleep
append using ${pathOut}/${ABBRVexp}-Referral-sleep
//append using ${pathOut}/${ABBRVexp}-therapy-sleep

sort patid eventdate

* deal with dates
replace eventdate=sysdate if sysdate!=. & eventdate==.
count if eventdate==.

*identify source
recode src .=1

label define src 1"Read code" 2"prescription"
label values src src

tab src, missing


sort patid eventdate

/*******************************************************************************
#2. Keep first record of sleep problems from any source for each patient
*******************************************************************************/
keep patid eventdate src prodcode ingredient bnftext medcode readterm //keep only useful data
sort patid eventdate
bysort patid: keep if _n==1

*review the source of the first record
tab src, missing
/*

         src |      Freq.     Percent        Cum.
-------------+-----------------------------------
   Read code |    123,825       17.23       17.23
prescription |    595,011       82.77      100.00
-------------+-----------------------------------
       Total |    718,836      100.00


*/

*label and save
label data "${exposure} - earliest record of sleep problems - definite and possible"
notes: ${exposure} - earliest record of sleep problems - definite and possible
notes: ${filename} / TS		
compress
save ${pathOut}/variables-${ABBRVexp}-sleep-all, replace


/*******************************************************************************
#2. DEFINITE SLEEP
*******************************************************************************/
use ${pathOut}/${ABBRVexp}-Therapy-sleep-all, clear
drop if Possibledrugs==1

append using ${pathOut}/${ABBRVexp}-Clinical-sleep
append using ${pathOut}/${ABBRVexp}-Referral-sleep
//append using ${pathOut}/${ABBRVexp}-therapy-sleep


sort patid eventdate

* deal with dates
replace eventdate=sysdate if sysdate!=. & eventdate==.
count if eventdate==.

*identify source
replace src=1 if src==.

label define src 1"Read code" 2"prescription"
label values src src

tab src, missing

/*

         src |      Freq.     Percent        Cum.
-------------+-----------------------------------
   Read code |    144,407       13.99       13.99
prescription |    887,642       86.01      100.00
-------------+-----------------------------------
       Total |  1,032,049      100.00

*/

sort patid eventdate

/*******************************************************************************
#3. Keep first record of sleep problems from any source for each patient
*******************************************************************************/
keep patid eventdate src prodcode ingredient bnftext medcode readterm //keep only useful data
sort patid eventdate
bysort patid: keep if _n==1

*review the source of the first record
tab src, missing

/*  

         src |      Freq.     Percent        Cum.
-------------+-----------------------------------
   Read code |    123,825       17.23       17.23
prescription |    595,011       82.77      100.00
-------------+-----------------------------------
       Total |    718,836      100.00
	   
	   
	   Psoriasis
	   
         src |      Freq.     Percent        Cum.
-------------+-----------------------------------
   Read code |    105,582       53.01       53.01
prescription |     93,577       46.99      100.00
-------------+-----------------------------------
       Total |    199,159      100.00




*/


*label and save
label data "${exposure} - earliest definite record of sleep problems"
notes: ${exposure} - earliest definite record of sleep problems
notes: ${filename} / TS		
compress
save ${pathOut}/variables-${ABBRVexp}-sleep-definite, replace

*erase datasets that are no longer useful
/*
cap erase "${pathOut}/${ABBRVexp}-Clinical-sleep.dta"
cap erase "${pathOut}/${ABBRVexp}-Referral-sleep.dta"
cap erase " ${pathOut}/${ABBRVexp}-Therapy-sleep-all.dta"
cap erase " ${pathOut}/${ABBRVexp}-Therapy-definite-sleep-all.dta"
*/

log close
exit