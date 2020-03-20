********************************************************************************
** Differences in differences estimates of effect of SHA 2018 voucher reform **
********************************************************************************

clear all
set maxvar 25000
set scheme leap_slides

*Load data
use "${cmto_der}\historical_voucher_data", clear

*set time variable:
local time_var bimester_issued

************************************************
*** 	Exclude Phase 1 Treatment Group	HHs	 ***
************************************************
	
		preserve
		use "${phase1_der}/baseline_phas_dec2019.dta", clear
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

********************************************************
*** 	Merge Pilot Flag ad Do Sample Restrictions	 ***
********************************************************

	*Flag pilot families:
	drop _merge
	merge m:1 oi_hh_hist_id using "${cmto_der}/pilot_data"
	gen pilot_sample=(_merge==3 | _merge==2)
	
	*Define having kids indicator:
	gen has_kids = 1 if (num_kids>0 & num_kids!=.) | (experimental_sample==1 & eligible==1)
	replace has_kids = 0 if num_kids==0 & has_kids!=1
	
	*sample restrictions:
		drop if voucher_issue_date==. | has_kids==. | voucher_issue_date>td(1jul2019)
		*restrict to period where we want to show graph: 
		drop if voucher_issue_date < td(1aug2017) | voucher_issue_date >= td(1Nov2018)
		*restrict to SHA:
		keep if pha=="SHA"
		*Restrict to families with kids actually in the pilot for the period between feb-april2018
		drop if voucher_issue_date >= td(1feb2018) & voucher_issue_date < td(1may2018) & pilot_sample==0 & has_kids == 1

***********************************
*** 	Generate Some Variables ***
***********************************
		
	keep oi_hh_id pha voucher_issue_date opportunity_area ///
	experimental_sample eligible has_kids treatment ///
	forecast_2000_irs rent_twobed2015 kfr_pooled_pooled_p25 ///
	num_kids single_parent member* z_index* uncond_opportunity_area search_success ///
	kir_pooled_pooled_p25
	
	*Generate year month variable:
	gen yr_month_issued = mofd(voucher_issue_date)
	sum yr_month_issued
	
	*Generate bimester variable:
	sum yr_month_issued
	*we see Stata's internal month count goes from 660 (jan 2016) to 695 (dec 2018)
	*Identify odd numbers in month count
	gen odd = mod(yr_month_issued,2)
	*For odd numbers substract 1 (in order to form bimesters)
	*Also make it so that feb, march and april are grouped together
	gen bimester_issued = yr_month_issued
	replace bimester_issued = yr_month_issued + 1 if odd==1 & yr_month_issued < 698
	replace bimester_issued = yr_month_issued -1 if odd==1 & yr_month_issued > 698
	format bimester_issued %tm
	
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
	
******************
*** Set outcomes *
******************

global outcomes uncond_opportunity_area 

******************************************************************
*** Diff in Diff (graph + point estimate) for KCHA update 2016 ***
****************************************************************** 
	encode pha, gen(pha_code)
	
	foreach outcome of global outcomes  {
	
	format `time_var' %tmMonCCYY
	tab `time_var' has_kids if ~mi(`outcome')

	replace `outcome' = `outcome' * 100

		*point estimates:
		preserve
		drop if voucher_issue_date >= td(1feb2018) & voucher_issue_date < td(1may2018)
		reg `outcome' has_kids post_may2018 interaction_may2018, r
		local beta_FAS: dis %5.2f _b[interaction_may2018]
		local se_FAS: dis %4.2f _se[interaction_may2018]
		restore
		
		preserve
		drop if mi(`outcome')
		
		sum `outcome' if has_kids==1 & bimester_issued == mofd(td(1may2018))
		local share_high_opp_post_FAS: dis %2.1fc ceil(r(mean)/10)*10
		
		sum `outcome' if has_kids==1 & bimester_issued == 698
		local share_high_opp_pilot: dis %2.1fc r(mean)
		
		di "`share_high_opp_post_FAS'"
		if "`scalar_mode'" == "on" {
		scalarout using "${scalars}/`file_name'.csv", id("upper_share_high_opp_post_FAS") num(`share_high_opp_post_FAS')
		scalarout using "${scalars}/`file_name'.csv", id("effect_FAS") num(`beta_FAS')
		scalarout using "${scalars}/`file_name'.csv", id("se_FAS") num(`se_FAS')
		scalarout using "${scalars}/`file_name'.csv", id("share_high_opp_pilot") num(`share_high_opp_pilot')
		}

		collapse (mean) `outcome', by(has_kids `time_var')
		
		if "`outcome'"=="uncond_opportunity_area"  {
		local ytitle `" "Percent of Households Who Moved" "to High Opportunity Areas" "'
		local ylab "0(10)80"
		gen y_area = 80
		}
	
		*Line where program started
		local cut = mofd(td(1feb2018)) - 0.1
	
		*indicate the months in which pilot vouchers started and stopped being issued:
		gen x_area = mofd(td(1feb2018)) - 0.1 in 1
		replace x_area = mofd(td(1mar2018)) in 2
		replace x_area = mofd(td(1apr2018)) in 3
		replace x_area = mofd(td(1apr2018)) + 0.3 in 4

		format `time_var' %tmMonCCYY
			
		*generate label:
		gen x_axis = `time_var'
		
		gen lab_`outcome' = string(`outcome', "%2.1fc")

		*graph:
		twoway (area y_area x_area, color(navy%30)) ///
		(connected `outcome' x_axis if has_kids==1 & x_axis<698, /*mlab(lab_`outcome') mlabcolor("102 220 206") mlabpos(12)*/ color("102 220 206") lwidth(*1.3)) ///
		(connected `outcome' x_axis if has_kids==0 & x_axis<698,  color(gs11) lwidth(*1.3)) ///
		(connected `outcome' x_axis if has_kids==1 & x_axis>694 & x_axis<703, /*mlab(lab_`outcome') mlabcolor("102 220 206") mlabpos(12)*/ color("102 220 206") lwidth(*1.3)) ///
		(connected `outcome' x_axis if has_kids==0 & x_axis>694 & x_axis<703,  color(gs11) lwidth(*1.3)) ///
		(connected `outcome' x_axis if has_kids==1 & x_axis>698, /*mlab(lab_`outcome') mlabcolor("102 220 206") mlabpos(12)*/ color("102 220 206") lwidth(*1.3)) ///
		(connected `outcome' x_axis if has_kids==0 & x_axis>698,  color(gs11) lwidth(*1.3)) ///
		, ///
		legend(order(2 3) label(2 "HHs w/ Kids") label(3 "HHs w/out Kids") ring(0) pos(2) col(1) size(*0.9) symxs(*0.6) symys(*0.8)) ///
		xline(`cut', lcolor(gs8) lpattern(dash)) name(`outcome'_graph, replace) ///
		xtitle(" " "Date of Voucher Issuance") ///
		ytitle(`ytitle') ///
		xscale(range(691 705)) ylab(`ylab', nogrid angle(vertical)) ///
		yscale(range(`extend_y')) ///
		xlab(692 `" "Aug/Sep" "2017" "' 694 `" "Oct/Nov" "2017" "' 696 `" "Dec/Jan" "2017/18" "' ///
		698 `" "Feb/Mar/Apr" "2018" "' 700 `" "May/Jun" "2018" "' 702 `" "Jul/Aug" "2018" "' 704 `" "Sep/Oct" "2018" "', ///
		labsize(*0.8)) ${title} ///
		text(60 695.5 "Supplement" "Introduced", color(black) j(left)) ///
		note("Effect of Family Access Supplement: `beta_FAS' pp" ///
		     "                                                            (`se_FAS')" )
		
		graph export "${manual_edits}/DD_`outcome'_`time_var'_FAS_pilot_dec2019.wmf", replace
		
		restore
		
	}
