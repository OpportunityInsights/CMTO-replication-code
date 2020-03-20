********************************************************************************
* Persistence in Opportunity Areas
* Conditional and Unconditional on Lease-Up
********************************************************************************
	
* set outcome to graph:
foreach outcome in cmto cmto_uncond {

* ------------------------------------------------------------------------------
* Load and Merge Data
* ------------------------------------------------------------------------------

	* load data:
	use "${phase1_der}/baseline_phas_dec2019" if eligible == 1 & drop_long_run!=1, clear
	keep pha oi_hh_id cmto cmto_uncond cmto_last_move cmto_uncond_last_move ///
	lease_begin_date search_success search_success_2 lease_begin_date_2 ///
	voucher_begin_date treatment
	
	*generate PHA dummy:
	gen pha_dummy=1 if pha=="KCHA"
	replace pha_dummy=0 if pha=="SHA"
	
	*time since first move:
	gen time_since_first_move =td(6feb2020) - lease_begin_date
	
	*key sample restrictions:
	if "`outcome'" == "cmto" {
	keep if lease_begin_date < td(7jan2019) & search_success==1 ///
	& voucher_begin_date < td(1sep2018)
	}
	if "`outcome'" == "cmto_uncond" { 
	keep if voucher_begin_date < td(1sep2018)
	replace `outcome' = `outcome'_last_move if lease_begin_date_2 < td(6feb2019)
	}
	
	*duplicate data: 
	expand 2, gen(as_of_2016)
	gen `outcome'_combined = `outcome' if as_of_2016==0
	replace `outcome'_combined = `outcome'_last_move if as_of_2016==1
	
	gen interact_treatment = treatment*as_of_2016
	gen interact_pha_dummy = pha_dummy*as_of_2016

	* calculate differences in treatment size and SE's
	reg `outcome'_combined treatment pha_dummy if as_of_2016==0, r
	local `outcome'_diff0 = _b[treatment]
	local `outcome'_se0 = _se[treatment]
	reg `outcome'_combined treatment pha_dummy if as_of_2016==1, r
	local `outcome'_diff1 = _b[treatment]
	local `outcome'_se1 = _se[treatment]
	reg `outcome'_combined treatment interact_treatment pha_dummy interact_pha_dummy as_of_2016, r
	local `outcome'_dd: dis %2.1fc (_b[interact_treatment])*100
	local `outcome'_ddse: dis %2.1fc (_se[interact_treatment])*100
	
	if "`scalar_mode'" == "on" {
	scalarout using "${scalars}/`file_name'.csv", id("CMTO_effect_first_move_`outcome'") num(``outcome'_diff0')
	scalarout using "${scalars}/`file_name'.csv", id("CMTO_effect_feb2020_`outcome'") num(``outcome'_diff1')
	}

	* collapse to get means for treatment v. control
	gen count = 1
	collapse (rawsum) count (mean) `outcome'_combined, by(treatment as_of_2016)

	*Given that we control for PHA, we want to plot the bar of 
	*the treatment group as control group mean plus effect:
	xtset as_of_2016 treatment
	replace `outcome'_combined =  l.`outcome'_combined + ``outcome'_diff0' ///
										if treatment==1 & as_of_2016==0
	replace `outcome'_combined =  l.`outcome'_combined + ``outcome'_diff1' ///
										if treatment==1 & as_of_2016==1		
	
	if "`scalar_mode'" == "on" {
	sum `outcome'_combined if as_of_2016==1	& treatment==1
	local treatmen_m = r(mean)
	scalarout using "${scalars}/`file_name'.csv", id("Treatment_high_opp_1yr_persist_`outcome'") num(`treatmen_m')
	sum `outcome'_combined if as_of_2016==1	& treatment==0
	local control_m = r(mean)
	scalarout using "${scalars}/`file_name'.csv", id("Control_high_opp_1yr_persist_`outcome'") num(`control_m')
	}
	
	* add percent labels
	gen  percent=`outcome'_combined*100
	gen percent_lab = "{bf:" + string(percent, "%2.1f") + "%" + "}" 
	gen count_lab = "n = " + string(count, "%2.0f")

* ------------------------------------------------------------------------------
* Graph
* ------------------------------------------------------------------------------
	
	if "`outcome'" == "cmto" {
	local ylab "0(20)70"
	local ytitle `" "Percentage of Households who Live" "in a High Opportunity Area" "'
	local d_units "pp"
	local xscale "-0.3 1.3"
	local xlab `" -0.22 "Initial Move" 0.22 "Feb 6, 2020" 0.78 "Initial Move" 1.22 "Feb 6, 2020" "'
	local note `" "Change in Treatment Effect from Initial Move to Feb 6, 2020:  {bf:``outcome'_dd' `d_units'}" "'
	local note_se `" "                                                                                SE: (``outcome'_ddse')" "'

	}
	if "`outcome'" == "cmto_uncond" {
	local ylab "0(20)70"
	local ytitle `" "Percentage of Households who Live" "in a High Opportunity Area" "'
	local d_units "pp"
	local xscale "-0.3 1.3"
	local xlab `" -0.22 "Feb 6, 2019" 0.22 "Feb 6, 2020" 0.78 "Feb 6, 2019" 1.22 "Feb 6, 2020" "'
	local note `" "Change in Treatment Effect from Feb 6, 2019 to 2020:  {bf:``outcome'_dd' `d_units'}" "'
	local note_se `" "                                                                                SE: (``outcome'_ddse')" "'
	}
	
	if "`outcome'" == "cmto" { 
	* xaxis
	gen xaxis = .
	replace xaxis = treatment - 0.22 if as_of_2016 == 0
	replace xaxis = treatment + 0.22 if as_of_2016 == 1
	
		twoway ///
			(bar percent xaxis if treatment == 0, barwidth(0.4) color(gs12)) ///
			(bar percent xaxis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
			(scatter percent xaxis, mlabel(percent_lab) ///
				mcolor(none) mlabcolor(black) mlabpos(12) mlabs(*1.1)) ///
			, ///
			legend(lab(1 "Control") lab(2 "Treatment") ///
			size(medsmall) order(1 2) col(1) pos(11) ring(0)) ///
			ylab(`ylab', nogrid) ///
			xlab(`xlab') ///
			xsc(range(-0.5 1.5)) ///
			ytitle(`ytitle') xtitle("") ${title} ///
			note("Change in Treatment Effect from Initial Move to Feb 6, 2020:  {bf:``outcome'_dd' `d_units'}" ///
			 "                                                                                           SE:  (``outcome'_ddse')", size(*1))
	}
	if "`outcome'" == "cmto_uncond" { 
	* xaxis
	gen xaxis = .
	replace xaxis = treatment - 0.22 if as_of_2016 == 0
	replace xaxis = treatment + 0.22 if as_of_2016 == 1
	
		twoway ///
			(bar percent xaxis if treatment == 0, barwidth(0.4) color(gs12)) ///
			(bar percent xaxis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
			(scatter percent xaxis, mlabel(percent_lab) ///
				mcolor(none) mlabcolor(black) mlabpos(12) mlabs(*1.1)) ///
			, ///
			legend(lab(1 "Control") lab(2 "Treatment") ///
			size(medsmall) order(1 2) col(1) pos(11) ring(0)) ///
			ylab(`ylab', nogrid) ///
			xlab(`xlab') ///
			xsc(range(-0.5 1.5)) ///
			ytitle(`ytitle') xtitle("") ${title} ///
			note("Change in Treatment Effect from Feb 6, 2019 to 2020:  {bf:``outcome'_dd' `d_units'}" ///
			"                                                                                SE:  (``outcome'_ddse')" , size(*1))
	}
	
	graph export "${figs}/bar_4bar_`outcome'_persist_dec2019.${img}", replace
}


