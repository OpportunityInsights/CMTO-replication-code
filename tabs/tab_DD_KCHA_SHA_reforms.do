***********************************************************
** Differences in Differences Table of                   **
** Effects of Voucher Reforms (KCHA 5 Tier and SHA FAS)  **
***********************************************************

clear all
set maxvar 25000
ssc install outreg2

*Load data
use "${cmto_der}\historical_voucher_data", clear

********************************************************************************
** Differences in differences estimates of effect of KCHA 2016 voucher reform **
********************************************************************************

*************************************************
*** Generate treatment and pre-post indicators  **
*************************************************

	gen treated_KCHA = 1 if pha=="KCHA"
	replace treated_KCHA = 0 if pha=="SHA"
	
	*dates of all updates:
	global update_dates july2015 march2016  july2016 sep2017 april2018 july2018 sep2018
	*                     SHA      KCHA       SHA      SHA      SHA      KCHA     SHA   
	
	foreach date of global update_dates {
	* Generate pre, post indicator KCHA update 1: 
	gen post_`date' = ( voucher_issue_date >= td(1`date') )
	*Interactions
	gen interaction_`date' = treated_KCHA*post_`date'
	}
	
***************************************************************
***  Set outcome to be plotted and time/sample restrictions
***************************************************************
	
	global outcomes forecast_2000_irs 

	*restrict to period where we want to show graph: 
	drop if voucher_issue_date < td(1july2015) | voucher_issue_date >= td(1nov2016)
	
	*restrict to families with kids
	keep if num_kids>0
	
	replace uncond_opportunity_area = uncond_opportunity_area*100
	
******************************************************************
*** Diff in Diff (graph + point estimate) for KCHA update 2016 ***
****************************************************************** 

		*point estimates:	
		reg uncond_opportunity_area treated_KCHA interaction_march2016 post_march2016, r
		outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel replace keep(interaction_march2016) ctitle("KCHA MTO No Controls")  nocons
		
		reg uncond_opportunity_area treated_KCHA interaction_march2016 num_kids i.yr_month_issued, r
		outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append keep(interaction_march2016) ctitle("KCHA MTO Num Kids & month FEs") nocons
		
		reg rent_twobed2015 treated_KCHA interaction_march2016 post_march2016, r
		outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append keep(interaction_march2016) ctitle("KCHA Rent No Controls") nocons
		
		reg rent_twobed2015 treated_KCHA interaction_march2016 i.num_kids i.yr_month_issued, r
		outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append keep(interaction_march2016) ctitle("KCHA Rent Num Kids & month FEs") nocons
		
********************************************************************************
** Differences in differences estimates of effect of SHA 2018 voucher reform **
********************************************************************************

*Load data
use "${cmto_der}\historical_voucher_data", clear

************************************************
*** 	Exclude Phase 1 Treatment Group		 ***
************************************************
	
		preserve
		use "${cmto}/data/derived/baseline_pha_june2019/baseline_phas_june2019.dta", clear
		cap drop _merge
		keep oi_hh_id cmto treatment cmto_uncond voucher_begin_date eligible
		drop if oi_hh_id==.
		tempfile experimental_data
		save `experimental_data'
		restore
		*merge
		cap drop _merge
		merge m:1 oi_hh_id using `experimental_data'
		*flag experimental sample
		gen experimental_sample=(_merge==3 | _merge==2)
		*drop treatment group families:
		drop if experimental_sample==1 & treatment==1
		
	*sample restrictions:
	*Define indicator for whether the participant has children:
	gen has_kids = 1 if (num_kids>0 & num_kids!=.) | (experimental_sample==1 & eligible==1)
	replace has_kids = 0 if num_kids==0 & has_kids!=1
		drop if voucher_issue_date==. | has_kids==. | voucher_issue_date>td(1jul2019)
		*restrict to period where we want to show graph: 
		drop if voucher_issue_date < td(1aug2017) | voucher_issue_date >= td(1Nov2018)
		*drop pilot period
		drop if voucher_issue_date >= td(1feb2018) & voucher_issue_date < td(1may2018)
		*restrict to SHA:
		keep if pha=="SHA"

*************************************************
*** Generate treatment and pre-post indicators  **
*************************************************
	
	*generate treatment indicator:
	gen treated_SHA =1 if has_kids==1
	replace treated_SHA = 0 if has_kids==0
	
	*dates of all updates:
	global update_dates feb2018 mar2018 may2018
	              
	foreach date of global update_dates {
	* Generate pre, post indicator KCHA update 1: 
	gen post_`date' = ( voucher_issue_date >= td(1`date') )
	*Interactions
	gen interaction_`date' = treated_SHA*post_`date'
	}
	
	replace uncond_opportunity_area = uncond_opportunity_area*100

******************************************************************
*** Diff in Diff (graph + point estimate) for SHA update 2016 ***
****************************************************************** 

	*point estimates:
	reg uncond_opportunity_area has_kids post_may2018 interaction_may2018, r
	outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append keep(interaction_may2018) ctitle("SHA MTO No Controls") nocons
	
	reg uncond_opportunity_area has_kids post_may2018 interaction_may2018 i.num_kids i.yr_month_issued, r
	outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append  keep(interaction_may2018) ctitle("SHA MTO Num Kids & month FEs") nocons
	
	reg rent_twobed2015 has_kids post_may2018 interaction_may2018, r
	outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append keep(interaction_may2018) ctitle("SHA Rent No Controls") nocons
	
	reg rent_twobed2015 has_kids post_may2018 interaction_may2018 i.num_kids i.yr_month_issued, r
	outreg2 using "${tabs}/tab_DD_KCHA_SHA.xls",  excel append  keep(interaction_may2018) ctitle("SHA Rent Num Kids & month FEs") nocons
	
	