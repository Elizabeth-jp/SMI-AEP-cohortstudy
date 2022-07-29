/*******************************************************************************
DO FILE NAME:			appendix-ecz-missingCharacteristics.do

AUTHOR:					Elizabeth Adesanya
						

VERSION:				v1
DATE VERSION CREATED: 	07/12/2021

TASK:					Create a table for the appendix including data for:
						1. the whole cohort (with eczema and without eczema)
						2. model 1 (adjusts for carstairs and calendar period)
						3. individuals with missing carstairs
						4. model 4 (adjusts for other mediators including 
						valid matched sets with no missing BMI or smoking status)
						5. individuals with missing BMI
						6. individuals with missing smoking status
					
						
DATASET(S)/FILES USED:	cohort-eczema-main.dta
						

DATASETS CREATED:		appendix-ecz-analysis.xls
						(worksheet missingCharacteristics)
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
global filename "apdx-ecz-missingCharacteristics"

*open log file
log using "${pathLogsbuild}/${filename}", text replace 

/*******************************************************************************
MAIN ANALYSIS
*******************************************************************************/

/*******************************************************************************
#1. Identify the different analysis samples and open the dataset
	all - whole cohort (with eczema and without eczema)
	model1 - cohort with complete cases with no missing carstairs deprivation
	noCar - missing carstairs
	model4 - cohort with complete cases with no missing BMI or smoking 
	noBMI - missing BMI
	noSmok - missing smoking status
*******************************************************************************/
foreach sample in all model1 noCar model4 noBMI noSmok {
    use "${pathCohort}/cohort-eczema-main", clear
	
	/***************************************************************************
	1.1 Identify analysis sample 
	***************************************************************************/
	*1. model adjusting for confounders
	if "`sample'"=="model1" {
	    gen exposed_nm = (exposed<.)
	    gen carstairs_nm = (practice_carstairs<.)
		gen complete = (exposed_nm==1 & carstairs_nm==1)
		keep if complete==1
		drop complete
		drop exposed_nm 
		drop carstairs_nm
		
		* Preserve matching, keep valid sets only
		bysort setid: egen set_exposed_mean = mean(exposed)
		gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1) 
		tab valid_set, miss
		tab valid_set exposed, col
		keep if valid_set==1
		drop valid_set set_exposed_mean
	}  /*end if "`sample'"=="model1"*/
	
	*2. missing carstairs
	if "`sample'"=="noCar" {
	    keep if practice_carstairs==.
	}  /*end if "`sample'"=="noCar"*/
	
	*3. model adjusting for mediators (includes complete cases inlcuding no missing carstairs)
	if "`sample'"=="model4" {
	    gen exposed_nm = (exposed<.)
		gen carstairs_nm = (practice_carstairs<.)
		gen smokstatus_nm = (smokstatus<.)
		gen bmi_nm = (bmi_cat<.)
		gen complete = (exposed_nm==1 & carstairs_nm==1 & bmi_nm==1 & smokstatus_nm==1)
		keep if complete==1
		drop complete
		
		* Preserve matching, keep valid sets only
		bysort setid: egen set_exposed_mean = mean(exposed)
		gen valid_set = (set_exposed_mean>0 & set_exposed_mean<1) 
		tab valid_set, miss
		tab valid_set exposed, col
		keep if valid_set==1
		drop valid_set set_exposed_mean
	}  /*end if "`sample'"=="model4"*/
	
	*4. missing bmi
	if "`sample'"=="noBMI" {
	    keep if bmi_cat==.
	}  /*end if "`sample'"=="noBMI"*/
	
	*5. missing smoking status
	if "`sample'"=="noSmok" {
	    keep if smokstatus==.
	}  /*end if "`sample'"=="noSmok"*/
	
	/***************************************************************************
	1.2 Total Ns
	***************************************************************************/
	foreach group in exp unexp {
	    preserve
		if "`group'"=="exp" unique patid if exposed==1
		if "`group'"=="unexp" unique patid if exposed==0
		global `sample'_`group'_n=r(unique)
		global `sample'_`group'_Nformat : display %12.0gc r(unique)
		restore
	}
	
	/***************************************************************************
	1.3 Pyars - total and median
	***************************************************************************/
	* fu for each observation
	gen fu_time=_t-_t0 

	* loop through exposed and unexposed
	foreach group in exp unexp {
		preserve
		* keep relevant patids
		if "`group'"=="exp" keep if exposed==1
		if "`group'"=="unexp" keep if exposed==0
		
		* collapse
		collapse (sum)fu_time, by(patid)
		summ fu_time, detail 
		
		* total
		global `sample'_`group'_pyar=`r(sum)'
		
		* median
		local p50=string(`r(p50)', "%4.1f")
		local p25=string(`r(p25)', "%4.1f")
		local p75=string(`r(p75)', "%4.1f")
		global `sample'_`group'_median "`p50' (`p25'-`p75')"	
		restore
	} /*end foreach group in exp unexp*/
	
	/***************************************************************************
	1.4 Recode and label variables
	***************************************************************************/
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

	* recode smoking status var >> assume current/ex smokers are current smokers
	*currently 0=non smoker, 1=current 2=ex 12=current or ex
	recode smokstatus 0=1 1=2 2=2 12=2 .=3
	label define smok2 1"Non-smoker" 2"Current or ex-smoker" 3"Missing"
	label values smokstatus smok2

	recode eth5 0=1 1=2 2=3 3=4 4=5 5=6 .=6, gen(ethnicity)
	label define ethnicity 1"White" 2"South Asian" 3"Black" 4"Other" 5"Mixed" 6"Not stated or missing"
	label values ethnicity ethnicity
	tab ethnicity eth5, miss
	
	recode sex 1=2 2=1
	label define sexlabel 1"Female" 2"Male"
	label values sex sexlabel
	
	recode sleep 1=1 0=2
	label define sleeplabel 1"Yes" 2"No"
	label values sleep sleeplabel
	
	recode harmfulalcohol 1=1 0=2
	label define alcohollabel 1"Yes" 2"No"
	label values harmfulalcohol alcohollabel
	
	recode cci 0=1 1=2 2=3
	label define ccilabel 1"Low (0)" 2"Moderate (1-2)" 3"Severe (3 or more)"
	label values cci ccilabel

	recode practice_carstairs 1=1 2=2 3=3 4=4 5=5 .=6
	label define carstairs 1"1(least deprived)" 2"2" 3"3" 4"4" 5"5(most deprived)" 6"Missing"
	label values practice_carstairs carstairs  
	
	/***************************************************************************
	1.5 Get data for all other variables that will makeup the table
	***************************************************************************/
	/*--------------------------------------------------------------------------
		1.5.1 Binary covariates
		----------------------------------------------------------------------*/
		local bincv " "harmfulalcohol" "sleep" "sex" "
		foreach group in exp unexp {
		    foreach cv in `bincv' {
			    if "`group'"=="exp" unique patid if `cv'==1 & exposed==1 
				if "`group'"=="unexp" unique patid if `cv'==1 & exposed==0
				local n=r(unique)
				local denom ${`sample'_`group'_n}
				local percent=(`n' / `denom') * 100
				local percent : display %4.1f `percent'
				local n: display %9.0fc `n'
				
				* create string for output
				global `sample'_`cv'_`group' "`n' (`percent'%)" 
			}/*end foreach cv in `bincv'*/
		}/*end foreach group in exp unexp*/
			
		/*--------------------------------------------------------------------------
		1.5.2 multilevel covariates
		--------------------------------------------------------------------------*/	
		local multicv ""practice_carstairs" "ethnicity" "smokstatus" "bmi_cat" "cci" "
		local multicv "`multicv' "age_grp" "
		foreach group in exp unexp {
		    foreach cv in `multicv' {
			    levelsof `cv', local(levels)
				foreach i of local levels {
					if "`group'"=="exp" unique patid if `cv'==`i' & exposed==1 
					if "`group'"=="unexp" unique patid if `cv'==`i' & exposed==0
					local n=r(unique)
					local denom ${`sample'_`group'_n}
					local percent=(`n' / `denom') * 100
					local percent : display %4.1f `percent'
					local n: display %9.0fc `n'
					
					* create string for output
					global `sample'_`cv'`i'_`group' "`n' (`percent'%)" 
				} /*end foreach i of local levels*/
			}/*end foreach cv in `multicv'*/	
		}/*end foreach group in exp unexp*/
		
			

} /*end foreach sample in all model1 noCar model4 noBMI noSmok*/

/*******************************************************************************
PUT RESULTS IN EXCEL FILE
*******************************************************************************/
* create excel file
putexcel set "${pathResults}/appendix-ecz-analysis.xlsx", sheet(missing_characteristics) modify

* set row count variable
local rowcount=1

* Table title
putexcel A`rowcount'="Table x. Characteristics of the study population at cohort entry, for: the overall cohort, individuals included in the model additionally adjusting for potential confounders (i.e. Model 1 - individuals with no missing Carstairs deprivation data), individuals with missing Carstairs data, individuals included in the model additionally adjusting for potential mediators (i.e. Model 4 - individuals with no missing BMI or smoking status data), and for individuals with missing BMI or smoking status." 
local ++rowcount // increment row couter variable
putexcel A`rowcount'="Values are numbers (percentages) unless stated otherwise"
local ++rowcount // increment row couter variable

* set up column headers
putexcel B`rowcount'="Overall cohort"
putexcel D`rowcount'="Sample included in model adjusting for potential confounders"
putexcel F`rowcount'="Individuals with missing Carstairs data"
putexcel H`rowcount'="Sample included in model adjusting for potential mediators"
putexcel J`rowcount'="Individuals with missing BMI status"
putexcel L`rowcount'="Individuals with missing smoking status"
putexcel A`rowcount':M`rowcount', overwritefmt bold border(top, thin, black) // format cells
local ++rowcount

* set up local macros containing columns for each sample
local all "B C"
local model1 "D E"
local noCar "F G"
local model4 "H I"
local noBMI "J K"
local noSmok "L M"

foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' // col1==exp; col2==unexp
	} /*end forvalues i=1/4*/ 
	putexcel `col1'`rowcount'="With atopic eczema"
	putexcel `col2'`rowcount'="Without atopic eczema"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
putexcel A`rowcount':M`rowcount', overwritefmt hcenter border(bottom, thin, black) txtwrap // format cells
local ++rowcount

/*******************************************************************************
Ns
*******************************************************************************/
putexcel A`rowcount'="Number"
foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' 
	} /*end forvalues i=1/2*/ 
	putexcel `col1'`rowcount'="${`pop'_exp_Nformat}"
	putexcel `col2'`rowcount'="${`pop'_unexp_Nformat}"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
local ++rowcount

/*******************************************************************************
Follow up (Pyars)
*******************************************************************************/
putexcel A`rowcount'="Follow up", bold
local ++rowcount

* total person years
putexcel A`rowcount'="Total person-years"
foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' 
	} /*end forvalues i=1/2*/ 
	putexcel `col1'`rowcount'="${`pop'_exp_pyar}"
	putexcel `col2'`rowcount'="${`pop'_unexp_pyar}"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
local ++rowcount

* median
putexcel A`rowcount'="Median (IQR) duration of follow-up (years)"
foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' 
	} /*end forvalues i=1/2*/ 
	putexcel `col1'`rowcount'="${`pop'_exp_median}"
	putexcel `col2'`rowcount'="${`pop'_unexp_median}"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
local ++rowcount

/*******************************************************************************
Sex
*******************************************************************************/
putexcel A`rowcount'="Sex", bold
local ++rowcount

putexcel A`rowcount'="Female (%)"
foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' 
	} /*end forvalues i=1/2*/ 
	putexcel `col1'`rowcount'="${`pop'_sex_exp}"
	putexcel `col2'`rowcount'="${`pop'_sex_unexp}"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
local ++rowcount

/*******************************************************************************
Age group
*******************************************************************************/
putexcel A`rowcount'="Age (years)**", bold
local ++rowcount

levelsof age_grp, local(levels)
foreach j of local levels {
	putexcel A`rowcount'="`: label (age_grp) `j''" // use variable label for row caption
	foreach pop in all model1 noCar model4 noBMI noSmok {
		forvalues i=1/2 {
			local col`i' : word `i' of ``pop''
		} /*end forvalues i=1/2*/ 
		putexcel `col1'`rowcount'="${`pop'_age_grp`j'_exp}"
		putexcel `col2'`rowcount'="${`pop'_age_grp`j'_unexp}"
	}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/	
	local ++rowcount 
} /*end foreach j of local levels*/

/*******************************************************************************
Carstairs
*******************************************************************************/
putexcel A`rowcount'="Quintiles of Carstairs deprivation index***", bold
local ++rowcount

* loop through each quintile
forvalues x=1/6 {
    putexcel A`rowcount'="`: label (practice_carstairs) `x''" // use variable label for row caption
	foreach pop in all model1 noCar model4 noBMI noSmok {
		forvalues i=1/2 {
			local col`i' : word `i' of ``pop'' 
		} /*end forvalues i=1/2*/ 
		putexcel `col1'`rowcount'="${`pop'_practice_carstairs`x'_exp}"
		putexcel `col2'`rowcount'="${`pop'_practice_carstairs`x'_unexp}"
		
		*deal with missing information
		
		if "`pop'"=="model1" & `x'==6 { // for missing carstairs in model1
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="model1" & `x'==6 */
		
		if "`pop'"=="noCar" {
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="noCar"*/
		
		if "`pop'"=="model4" & `x'==6 { // for missing carstairs in model4
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="model4" & `x'==6 */
		
	}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/		
	local ++rowcount
} /*end forvalues x=1/6*/

/*******************************************************************************
BMI
*******************************************************************************/
putexcel A`rowcount'="Body mass index (kg/m2)****", bold
local ++rowcount

* loop through each BMI cat
levelsof bmi_cat, local(levels)
foreach j of local levels {
	putexcel A`rowcount'="`: label (bmi_cat) `j''" // use variable label for row caption
	
	* put output strings in excel file
	foreach pop in all model1 noCar model4 noBMI noSmok {
		forvalues i=1/2 {
			local col`i' : word `i' of ``pop'' 
		} /*end forvalues i=1/2*/ 
		putexcel `col1'`rowcount'="${`pop'_bmi_cat`j'_exp}"
		putexcel `col2'`rowcount'="${`pop'_bmi_cat`j'_unexp}"
		
		* deal with missing information
		if "`pop'"=="noBMI" {
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="noBMI"*/
		
		if "`pop'"=="model4" & `j'==4 { // for missing status in model4
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="model4" & `j'==4 */
	}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/	
	
	
	local ++rowcount 
} /*end foreach j of local levels*/

/*******************************************************************************
Smoking
*******************************************************************************/
putexcel A`rowcount'="Smoking****", bold
local ++rowcount

* loop through each smoking cat
forvalues x=1/3 {
    putexcel A`rowcount'="`: label (smokstatus) `x''" // use variable label for row caption
	
	* put output strings in excel file
	foreach pop in all model1 noCar model4 noBMI noSmok {
		forvalues i=1/2 {
			local col`i' : word `i' of ``pop'' 
		} /*end forvalues i=1/2*/ 
		putexcel `col1'`rowcount'="${`pop'_smokstatus`x'_exp}"
		putexcel `col2'`rowcount'="${`pop'_smokstatus`x'_unexp}"
		
		* deal with missing information
		if "`pop'"=="noSmok" {
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="noSmok"*/
		
		if "`pop'"=="model4" & `x'==3 { // for missing status in model4
			putexcel `col1'`rowcount'="n/a"
			putexcel `col2'`rowcount'="n/a"
		} /*end if "`pop'"=="model4" & `x'==3 */
	}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/	
	
	
	local ++rowcount 
} 

/*******************************************************************************
Ethnicity
*******************************************************************************/
putexcel A`rowcount'="Ethnicity", bold
local ++rowcount

* loop through each ethnicity cat
forvalues x=1/6 {
	putexcel A`rowcount'="`: label (ethnicity) `x''" // use variable label for row caption
	
	foreach pop in all model1 noCar model4 noBMI noSmok {
		forvalues i=1/2 {
			local col`i' : word `i' of ``pop'' 
		} /*end forvalues i=1/2*/ 
		putexcel `col1'`rowcount'="${`pop'_ethnicity`x'_exp}"
		putexcel `col2'`rowcount'="${`pop'_ethnicity`x'_unexp}"
	}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/	
	
	local ++rowcount 
} /*end foreach x of 1/6*/

/*******************************************************************************
Charlson comorbidity
*******************************************************************************/
putexcel A`rowcount'="Charlson comorbidity index****", bold
local ++rowcount

* loop through each cci category
forvalues x=1/3 {
	putexcel A`rowcount'="`: label (cci) `x''" // use variable label for row caption
	
	foreach pop in all model1 noCar model4 noBMI noSmok {
		forvalues i=1/2 {
			local col`i' : word `i' of ``pop'' 
		} /*end forvalues i=1/2*/ 
		putexcel `col1'`rowcount'="${`pop'_cci`x'_exp}"
		putexcel `col2'`rowcount'="${`pop'_cci`x'_unexp}"
	}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/	
	
	local ++rowcount 
} /*end foreach x of 1/3*/

/*******************************************************************************
Harmful alcohol
*******************************************************************************/
putexcel A`rowcount'="Harmful alcohol use (%)****", bold

foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' 
	} /*end forvalues i=1/2*/ 
	putexcel `col1'`rowcount'="${`pop'_harmfulalcohol_exp}"
	putexcel `col2'`rowcount'="${`pop'_harmfulalcohol_unexp}"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
local ++rowcount 

/*******************************************************************************
Sleep problems
*******************************************************************************/
putexcel A`rowcount'="Problems with sleep (%)****", bold

foreach pop in all model1 noCar model4 noBMI noSmok {
	forvalues i=1/2 {
		local col`i' : word `i' of ``pop'' 
	} /*end forvalues i=1/2*/ 
	putexcel `col1'`rowcount'="${`pop'_sleep_exp}"
	putexcel `col2'`rowcount'="${`pop'_sleep_unexp}"
}/*end foreach pop in all model1 noCar model4 noBMI noSmok*/
local ++rowcount 


/*******************************************************************************
Footnotes
*******************************************************************************/
putexcel A`rowcount'="IQR: Interquartile range"
local ++rowcount

putexcel A`rowcount'="Individuals can contribute data as both eczema exposed and unexposed. Therefore, numbers of exposed/unexposed do not total the whole cohort, as individuals may be included in more than one column."
local ++rowcount

putexcel A`rowcount'="* Follow-up based on censoring at the earliest of: death, no longer registered with practice, practice no longer contributing to CPRD, or severe mental illness diagnosis"
local ++rowcount

putexcel A`rowcount'="** Age at index date"
local ++rowcount

putexcel A`rowcount'="*** Carstairs deprivation index based on practice-level data (from 2011)."
local ++rowcount

putexcel A`rowcount'="**** Based on records closest to index date."
local ++rowcount

log close
exit 