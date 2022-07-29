
/*******************************************************************************
DO FILE NAME:			variables-ecz-steroids.do

AUTHOR:					Elizabeth Adesanya					

VERSION:				v1
DATE VERSION CREATED: 	06/10/2021

TASK:					Aim is to create a steroid variable that turns on and off
						
DATASET(S)/FILES USED:	variables-ecz-continuousGCRx-90days.dta
						smi-paths.do
						

DATASETS CREATED:		variables-ecz-steroids
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
global filename "variables-ecz-steroids"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

*load data
use "${pathDatain}/variables-ecz-continuousGCRx-90days.dta", clear

generate steroids=1 if patid!=.
label define steroidlabel 0"no" 1 "yes"
label values steroids steroidlabel

*expand the dataset to create a second copy of each observation
sort patid startdate
bysort patid: generate littlen=_n

sort patid littlen
expand 2
sort patid littlen
gen date=startdate
format date %td
replace date=enddate if littlen==littlen[_n-1] & patid==patid[_n-1]

* generate and onoff variable and set it to off in the 2nd obs (i.e. where date == enddate)
gen onoff=1
replace onoff=0 if littlen == little[_n-1] & patid==patid[_n-1]
label define onoff 1"on" 0"off"
label values onoff onoff

local expClasses " "steroids" "

* generate a state var for each different thing that can happen
foreach a in `expClasses' {
	generate on_`a'=0
	generate off_`a'=0
	recode on_`a' 0=1 if `a'==1 & onoff==1
	recode off_`a' 0=1 if `a'==1 & onoff==0
}


*create one record per patient per day
collapse(max) on_steroids off_steroids, by(patid date)
duplicates tag patid date, gen(dupe)
assert dupe==0
drop dupe

sort patid date

foreach b in `expClasses' {
	gen current_`b'=0
	recode current_`b' 0=1 if on_`b'==1
}

sort patid date

* update current status for each drug based on what happened before
foreach c in `expClasses' {
	replace current_`c' = current_`c'[_n-1] if 	/// set the `drug' flag to the same as the record (i.e. previous date) before 
	patid == patid[_n-1] &						/// IF this is same patient
	current_`c'[_n-1] != 0 &					/// the record before isn't 0 - we don't update a switched on record (don't change a 1 to a 0)		
	off_`c'!=1									// 	`drug' not switched off on this date
}


drop on_* off_*
rename current_steroids steroids

save "${pathIn}/variables-ecz-steroids"
log close
exit
