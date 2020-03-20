********************************************************************************
* Bar Graphs Showing Treatment Effects
********************************************************************************

* set outcomes of interest

local outcomes  cmto_uncond cmto search_success kfr_pooled_pooled_p25_uc ///
				very_satisfied very_sure_stay persist_unit rent_total ///
				teenbrth_p25_uc jail_pooled_pooled_p25_uc kfr_pooled_pooled_p25 square_feet ///
				distance_moved kfr_p25_shrunk_constant_uc

* loop through outcomes
foreach outcome in `outcomes' {

* ------------------------------------------------------------------------------
* Load and Merge Data
* ------------------------------------------------------------------------------

* load data
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1, clear
	
*Make restrictions for plot showing persistence in unit
if "`outcome'"=="persist_unit" {
keep if drop_long_run!=1 //drop hhs who attrited in the long run
assert cmto_last_move==cmto_2 if ~mi(cmto_2) //use latest indicator of area
keep if lease_begin_date < td(7jan2019) & search_success==1 ///
& voucher_begin_date < td(1sep2018) //restrict to relevant sample
gen persist_unit = (search_success_2==0 & search_success==1) //persistence variable
sum persist_unit
}

* load amenity data for square feet bar graph:
if inlist("`outcome'", "square_feet") {
cap drop _merge
merge 1:1 oi_hh_id using "${cmto_der}/amenity_data.dta", nogen keep(master match)
rename sq_ft_ square_feet
}

* make distance moved unconditional
replace distance_moved = 0 if search_success == 0
* Winsorize distance moved
replace distance_moved = 50 if distance_moved > 50 & distance_moved != .
	
*generate PHA dummy
gen pha_dummy=1 if pha=="KCHA"
replace pha_dummy=0 if pha=="SHA"

*make days searching conditional on lease-up
replace days_searching = . if search_success == 0

* scale variable by 100
if ~inlist("`outcome'", "rent_hap_total", "rent_total", "rent_utilities", ///
			"distance_moved", "square_feet", "days_searching") {
	replace `outcome' = 100 * `outcome'
}

* ------------------------------------------------------------------------------
* Save Historical MTO Rate
* ------------------------------------------------------------------------------

preserve 

	* merge 
	cap drop _merge
	merge 1:m oi_hh_id using "${cmto_der}/historical_voucher_data"
	keep if inrange(voucher_cohort, 2015, 2017)
	keep if num_kids > 0 & ~mi(num_kids)
	
	* flag cmto indicator for HH's in experiment
	gen experimental_sample = (_merge == 3 | _merge == 1)

	* scale up
	replace uncond_opportunity_area = 100*uncond_opportunity_area
	replace search_success = 100*search_success
	replace opportunity_area = 100*opportunity_area
	
	* calculate mean for HH's outside of experiment
	summ uncond_opportunity_area if experimental_sample == 0
	local mean_historical_cmto_uncond = `r(mean)'
	
	sum search_success if experimental_sample == 0
	local mean_historical_search_success = `r(mean)'
	di "`r(mean)'"
	
	sum opportunity_area if experimental_sample == 0
	local mean_historical_cmto = `r(mean)'
	di "`mean_historical_cmto'"

restore

* ------------------------------------------------------------------------------
* Calculate Effects & Collapse Data to Treatment / Control Means & SE's
* ------------------------------------------------------------------------------

* calculate differences in treatment size and SE's
reg `outcome' treatment pha_dummy, r
local `outcome'_diff: dis %2.1fc _b[treatment]
local `outcome'_se: dis %2.1fc _se[treatment]
local  p_val: dis %10.5f (2 * ttail(e(df_r), abs(_b[treatment]/_se[treatment])))

if inlist("`outcome'", "rent_total", "rent_hap_total", "rent_utilities") {
	local `outcome'_diff: dis %3.2fc _b[treatment]
}

if inlist("`outcome'", "distance_moved") {
	local `outcome'_diff: dis %2.1fc abs(_b[treatment])
}

* collapse to get means for treatment v. control
gen count = 1
collapse (rawsum) count (mean) `outcome', by(treatment)

*Given that we control for PHA, we want to plot the bar of 
*the treatment group as control group mean plus effect:
tsset treatment
replace `outcome' =  l.`outcome' + ``outcome'_diff' if treatment==1

*export scalars: 
sum `outcome' if treatment==0
local control_mean: dis %2.1fc r(mean)
sum `outcome' if treatment==1
local treatment_mean: dis %2.1fc r(mean)

di "`control_mean'" " " "`treatment_mean'" " " "``outcome'_diff'" " " "``outcome'_se'" " " "`p_val'"
if "`scalar_mode'" == "on" {
scalarout using "${scalars}/`file_name'.csv", id("`outcome'_control") num(`control_mean')
scalarout using "${scalars}/`file_name'.csv", id("`outcome'_treatment") num(`treatment_mean')
scalarout using "${scalars}/`file_name'.csv", id("`outcome'_effect") num(``outcome'_diff')
scalarout using "${scalars}/`file_name'.csv", id("`outcome'_se") num(``outcome'_se')
scalarout using "${scalars}/`file_name'.csv", id("`outcome'_pval") num(`p_val')
if "`outcome'" == "cmto_uncond" {
local hist_export: dis %4.2f `mean_historical_cmto_uncond'
scalarout using "${scalars}/`file_name'.csv", id("`outcome'_hist") num(`hist_export')
}
}

* create labels for bar chart (add % sign to some variables)
gen lab_`outcome' = "{bf:" + string(`outcome', "%2.1fc") + "}" 

if inlist("`outcome'", "persist_unit", "search_success",   ///
		  "jail_pooled_pooled_p25", "jail_pooled_pooled_p25_uc", "teenbrth_p25", ///
		  "teenbrth_p25_uc", "very_satisfied", "very_sure_stay")==1 | ///
		  regexm("`outcome'", "cmto")==1  {
	replace lab_`outcome' = "{bf:" + lab_`outcome' + "%" + "}" 
}

* add % sign (inlist only accepts 10 strings so we have to make another)
if inlist("`outcome'", "share_black2010_uc", "poor_share2010_uc") {
	replace lab_`outcome' = "{bf:" + lab_`outcome' + "%" + "}" 
}

* add $ sign to some variables
if inlist("`outcome'", "rent_total", "rent_hap_total", "rent_utilities") {
	replace lab_`outcome' = "{bf:" + string(`outcome', "%9.2fc") + "}" 
	replace lab_`outcome' = "{bf:" + "{c $|}" + lab_`outcome' + "}"
	local `outcome'_diff "{c $|}``outcome'_diff'" 
}


* ------------------------------------------------------------------------------
* Graph Control v. Treatment
* ------------------------------------------------------------------------------
local yline 

* graph settings
if "`outcome'" == "cmto" {
	local ylab "0(20)70"
	local ytitle `" "Share of Households Who Have Moved" "to High Opportunity Areas, Given They Moved" "'
	local d_units "pp"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "cmto_uncond" {
	local ylab "0(10)60"
	local ytitle `" "Share of Households Who Have Moved" "to High Opportunity Areas" "'
	*local yline	"yline(`mean_historical_mto', lcolor(gs8) lpattern(dash))"
	local d_units "pp"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "persist_unit" {
	local ylab "0(20)100"
	local ytitle `" "Percentage who Remain in Initial Unit" "as of Feb 6, 2020" "'
	local d_units "pp"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "search_success" {
	local ylab "0(20)100"
	local ytitle `" "Share of Households Who Have Moved" " " "'
	local d_units "pp"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "days_searching" {
	local ylab "0(25)100"
	local ytitle "Days Searching"
	local d_units "days"
	local xscale "-0.3 1.3"
}
if regexm("`outcome'", "kfr_pooled_pooled_p25")==1 {
	local ylab "40(2)50"
	local ytitle `" "Mean Household Income Rank (p=25)" "in Neighborhood" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if regexm("`outcome'", "kfr_p25_shrunk_constant_uc")==1 {
	local ylab "40(2)50"
	local ytitle `" "Mean Household Income Rank (p=25)" "in Neighborhood" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if regexm("`outcome'", "kir_pooled_pooled_p25")==1 {
	local ylab "44(2)48"
	local ytitle `" "Mean Individual Income Rank (p=25)" "in Neighborhood" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "kfr_race_pooled_p25" {
	local ylab "40(2)50"
	local ytitle `" "Household Income Rank (p=25)" "for HH Race in New Neighborhood" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if regexm("`outcome'", "forecast_kravg30_p25")==1 {
	forval kfr=42(2)50 {
	dis "`kfr'"
	convert_rank_dollar `kfr', kfr
	}
	local ylab "42(2)50"
	local ytitle `" "Mean Predicted Hold Income Rank" "In Neighborhood (Forecast)" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "diff_dest_origin" {
	local ylab "0(1)3"
	local ytitle `" "Difference in Forecasted Income Ranks" "Between Destination and Origin" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "diff_dest_origin_race" {
	local ylab "0(1)3"
	local ytitle `" "Difference in Income Ranks for HH Race" "Between Destination and Origin" "'
	local d_units "ranks"
	local xscale "-0.3 1.3"
}
if regexm("`outcome'", "jail_pooled_pooled_p25")==1 {
	local ylab "0(1)3"
	local ytitle `" "Mean Incarceration Rate When Parents at p=25" "in Tract (%)" "'
	local d_units "pp"
	local xscale "-0.3 1.3"
}
if regexm("`outcome'", "teenbrth_p25")==1 {
	local ylab "0(10)30"
	local ytitle `" "Mean Teen Birth Rate When Parents at p=25" "in Tract (%)" "'
	local d_units "pp"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "rent_twobed2015" {
	local ylab "1000(100)1500"
	local ytitle `" "Mean Two BR Rent (ACS 2015)" "in Neighborhood" "'
	local d_units ""
	local xscale "-0.3 1.3"
}
if "`outcome'" == "distance_moved" {
	local ylab "0(5)15"
	local ytitle `" "Mean Distance in Miles Between" "Origin and Destination Tract Centers" "'
	local d_units "miles"
	local xscale "-0.3 1.3"
}
if "`outcome'" == "rent_total" {
	local ylab "1000(400)2200"
	local ytitle "Monthly Rent ($)"
	local xscale "-0.3 1.3"
	local d_units ""
}
if "`outcome'" == "rent_gross" {
	local ylab "1500(100)2100"
	local ytitle "Gross Rent ($)"
	local d_units ""
	local xscale "-0.3 1.3"
}
if "`outcome'" == "rent_hap_total" {
	local ylab "1200(100)1700"
	local ytitle "HAP Unit Rent Paid by PHAs"
	local xscale "-0.3 1.3"
	local d_units ""
}
if regexm("`outcome'", "share_white2010")==1 {
	local ylab "50(5)60"
	local ytitle "Share White (2010)"
	local xscale "-0.3 1.3"
	local d_units "pp"
}
if regexm("`outcome'", "share_black2010")==1 {
	local ylab "0(5)15"
	local ytitle "Share Black (2010)"
	local xscale "-0.3 1.3"
	local d_units "pp"
}
if regexm("`outcome'", "poor_share2010")==1 {
	local ylab "0(10)20"
	local ytitle "Share Poor (2010)"
	local d_units "pp"
}
if regexm("`outcome'", "rent_utilities")==1 {
	local ylab "80(20)200"
	local ytitle "Out-of-Pocket Household Utility Payment"
	local d_units ""
}
if "`outcome'" == "very_satisfied" {
	local ylab "0(20)80"
	local ytitle `" "Share Very Satisfied" "with New Neighborhood" "'
	local d_units "pp"
}
if "`outcome'" == "very_sure_stay" {
	local ylab "0(20)60"
	local ytitle `" "Share Very Sure They Will" "Stay in New Neighborhood" "'
	local d_units "pp"
}
if "`outcome'" == "square_feet" {
	local ylab "0(500)1600"
	local ytitle `" "Square Feet of Home" " " "'
	local d_units "sq. feet"
}

local mean_historical_graph = `mean_historical_`outcome''+3
local mean_historical_graph_2 = `mean_historical_`outcome''+7
local mean_hist_outcome_fmt = round(`mean_historical_`outcome'', 0.1)

* graphs with historical lines
if inlist("`outcome'", "cmto_uncond") {
	twoway ///
	(bar `outcome' treatment if treatment==0, barwidth(0.4) color(gs12)) ///
	(bar `outcome' treatment if treatment==1, barwidth(0.4) color("102 220 206")) ///
	(function y = `mean_historical_`outcome'', lpattern(dash) range(-0.2 1.2) lcolor(black)) ///
	(scatter `outcome' treatment, ///
		mlabel(lab_`outcome') mcolor(none) mlabs(*1.2) mlabcolor(black) mlabpos(12)) ///
		, ///
		`yline' ///
		legend(off) ///
		text(`mean_historical_graph_2' 0.5 "Historical mean") ///
		text(`mean_historical_graph' 0.5 "rate: `mean_hist_outcome_fmt'%") ///
		xlab(0 "Control" 1 "Treatment", labsize(medium)) ${title} ///
		ylab(`ylab', nogrid labsize(medium)) xsc(range(-0.3 1.3)) ///
		ytitle(`ytitle') ///
		xtitle("") name("`outcome'_nm", replace) ///
		${title} ///
		note("Difference: {bf:``outcome'_diff' `d_units'}" "           SE: (``outcome'_se')", size(*1.2))
		*graph export "${figs}/bar_`outcome'_effect_hist_dec2019.${img}", replace
		
}
* graph 
twoway ///
	(bar `outcome' treatment if treatment==0, barwidth(0.4) color(gs12)) ///
	(bar `outcome' treatment if treatment==1, barwidth(0.4) color("102 220 206")) ///
	(scatter `outcome' treatment, ///
		mlabel(lab_`outcome') mcolor(none) mlabs(*1.2) mlabcolor(black) mlabpos(12)) ///
		, ///
		`yline' ///
		legend(off) ///
		xlab(0 "Control" 1 "Treatment", labsize(medium)) ${title} ///
		ylab(`ylab', nogrid labsize(medium)) xsc(range(-0.3 1.3)) ///
		ytitle(`ytitle') ///
		xtitle("") name("`outcome'_nm", replace) ///
		${title} ///
		note("Difference: {bf:``outcome'_diff' `d_units'}" "           SE: (``outcome'_se')", size(*1.2))
		graph export "${figs}/bar_`outcome'_effect_dec2019.${img}", replace
		
* Graphs for panels side by side in slides: 
if "${version}" == "slides" & ///
 inlist("`outcome'", "very_satisfied", "very_sure_stay", "square_feet", "distance_moved") {
		twoway ///
		(bar `outcome' treatment if treatment==0, barwidth(0.5) color(gs12)) ///
		(bar `outcome' treatment if treatment==1, barwidth(0.5) color("102 220 206")) ///
		(scatter `outcome' treatment, ///
			mlabel(lab_`outcome') mcolor(none) mlabs(*1.2) mlabcolor(black) mlabpos(12)) ///
			, ///
			`yline' ///
			legend(off) ///
			xlab(0 "Control" 1 "Treatment", labsize(medium)) ${title} ///
			ylab(`ylab', nogrid labsize(medium)) xsc(range(-0.5 1.5)) ///
			ytitle(`ytitle', size(*1.2)) ///
			xtitle("") name("`outcome'_nm", replace) ///
			aspectratio(0.75) ///
			${title} ///
			note("Difference: {bf:``outcome'_diff' `d_units'}" "           SE: (``outcome'_se')", size(*1.2))
			graph export "${figs}/bar_`outcome'_effect_dec2019.${img}", replace 
	}
}
