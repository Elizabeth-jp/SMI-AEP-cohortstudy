/*=========================================================================
DO FILE NAME:			exca-vars17-oralGCcontRx

AUTHOR:					Kate Mansfield	
						
VERSION:				v1
DATE VERSION CREATED: 	2018-Jul-23
					
DATABASE:				CPRD July 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	Identify continuous courses of therapy with glucocorticoids
						of 20mg or more, allowing 3/12 
						between consecutive prescriptions to define continuous 
						exposure
						
MORE INFORMATION:	
	
DATASETS USED:		prescriptions-oralGC-doseduration // oral GC prescriptions with dose duration and prednisolone equiv. dose

										
DATASETS CREATED: 	continuousGCRx-90days
					
DO FILES NEEDED:	exca-paths.do
					prog_cleanPrescriptions.do

ADO FILES NEEDED: 	exca.ado

*=========================================================================*/

/*******************************************************************************
>> HOUSEKEEPING
*******************************************************************************/
version 15
clear all
capture log close
macro drop _all

* find path file location and run it
skinepipaths_v2

* create a filename global that can be used throughout the file
global filename "variables-${ABBRVexp}-oralGCCcontRx"

* open log file - no need as fast tool will create log files
log using "${pathLogs}/${filename}", text replace






/*******************************************************************************
#1. Open data
 and only keep prescriptions for high doses of corticosteroids
*******************************************************************************/
use "${pathOut}/variables-${ABBRVexp}-oralGC-doseduration", clear
keep patid eventdate ped duration high
keep if high==1
keep patid eventdate duration







/*******************************************************************************
#2. Use eventdate and prescription duration to calculate enddate for prescription
*******************************************************************************/
* replace eventdate=sysdate if eventdate==. // ppi data no missing eventdates
gen startdate=eventdate
gen enddate=startdate+duration
format startdate enddate %td





/*******************************************************************************
#3. Generate courses of therapy 
*******************************************************************************/
* generate a unique number for a continuous course of medication
* to be defined as a course of therapy consecutive prescriptions can be 
* separated by up to `days'days
sort patid startdate enddate // sort into the correct order for the spelling algorithm 
gen spell = _n
replace spell = spell[_n-1] if				/// make the course number the same as the course number for the previous record if this record is:
	patid==patid[_n-1] &					/// - in the same patient
	startdate <= enddate[_n-1] + 90			//	- with startdate of current prescription within 90 days of end of previous prescription


label var spell "spell: unique id number of a continuous course of therapy"





/*******************************************************************************
#4. Collapse on patid and spellNo to create courses for particular drugs 
*******************************************************************************/
collapse (min) startdate (max) enddate, by(spell patid)

label var startdate "start of continuous course of therapy"
label var enddate "end of continuous course of therapy"

gen littlen=_n
drop spell
rename littlen spell
label var spell "spell: unique id number of a continuous course of therapy"







/*******************************************************************************
#5. Add 90 days to the end of every course of therapy to identify period that
	an individual is considered exposed (considered exposed for a further 3/12
	after the end of a continuous course of therapy)
*******************************************************************************/
replace enddate=enddate+90

drop spell

label var startdate "start exposure 20mg+ PED glucocorticoid"
label var enddate "end of exp 20mg+ PED (=end of prescription +90 days)"



/*******************************************************************************
#8. label and save dataset
*******************************************************************************/
label data "continous exposure high dose glucocorticoid - 90 days"
notes: continous exposure high dose glucocorticoid - 90 days
notes: ${filename} / TS
compress
save "${pathOut}/variables-${ABBRVexp}-continuousGCRx-90days", replace

log close

