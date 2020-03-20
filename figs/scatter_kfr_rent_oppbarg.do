********************************************************************************
* Scatter Opportunity Bargain: Upward Mobility v. Rent in Seattle
********************************************************************************

* set pha 
local pha 

* set outcome
local est	  kfr
local race 	  pooled
local outcome `est'_`race'_pooled_p25
local count   kid_`race'_pooled_blw_p50_n

* ------------------------------------------------------------------------------
* Load Tract-Level KFR and Rent Data
* ------------------------------------------------------------------------------

*load top 25 tracts to which voucher holders leased historically:
import delimited "${map_inputs}/tract_top25_historical_voucher_tracts_kids", clear
drop lat lon
tempfile top25
save `top25'

* load census data
use state county tract `outcome' `count'  ///
	using "${census}/tract_race_gender_early_dp", clear
	
* get national mean (for convert rank dollar)
summ `outcome' [w = `count']
local nat_mean = `r(mean)'
	
* restrict to seattle
keep if state == 53 & county == 33

*merge top25 voucher holder tracts: 
merge 1:1 state county tract ///
	using `top25', ///
	keep(match master)
gen top25 = (_merge==3)
drop _merge

* merge rent data
rename (state county tract) (state10 county10 tract10)
merge 1:1 state10 county10 tract10 using "${fg_covar}/covariates_tract_wide", ///
	nogen keep(matched) ///
	keepusing(rent_twobed2015 pop2010)
rename (state10 county10 tract10) (state county tract)

* merge on neighborhood names 
merge 1:1 state county tract ///
	using "${fg}/data/derived/crosswalks/tracts_to_nhbd_gmaps", ///
	nogen keep(match master) keepusing(location)	

	* drop if missing
foreach var in `outcome' rent_twobed2015 `count' {
	drop if mi(`var')
}

* multiply kfr_pooled_pooled_p25 by 100
replace `outcome' = `outcome' * 100

* bold the locations for the scatters
replace location = "{bf:" + location + "}"

* make y axis labels-- convert ranks to dollars
forval dist=30(10)60  {
convert_rank_dollar `dist', kfr
local k_dollars = round(`r(dollar_amount)' / 1000)
local k_dollars_format: dis %2.0f `k_dollars'
local ylab `"`ylab' `dist' `" "$`k_dollars_format'K" "`dist'" "' "'
}

* make x axis labels-- dollar amounts
forval rent=500(500)2500 {
local x_dollars_format: dis %-6.0fc 	`rent'
local xlab `"`xlab' `rent' `" "$`x_dollars_format'" "' "'
}

* ------------------------------------------------------------------------------
* Scatter with Example Control and Treatment Tract
* ------------------------------------------------------------------------------

* highlight a treatment high-opp tract and control low-opp tract
gen tag = 1 if inlist(tract, 29101) // Kent 
gen left_tag = 1 if inlist(tract, 30004) //Newport is a tract with high kfr that had the most CMTO people moved to (8),
gen high_tag = 1 if inlist(tract, 25001)
gen high_tag_left = 1 if inlist(tract, 32319) 
replace location = "{bf} West Kent" if tract == 29101 //  Renaming Kent to the more specific geo region
* scatter
replace location = "{bf} Woodinville" if tract == 32319 //Renaming Towncenter as its actual city
twoway ///
	(scatter kfr_pooled_pooled_p25 rent_twobed2015 if high_tag != 1 & high_tag_left != 1, msize(tiny) mcolor(gs10)) ///
	(lfit kfr_pooled_pooled_p25 rent_twobed2015 [w = `count'], lcolor(black)) ///
	(scatter kfr_pooled_pooled_p25 rent_twobed2015 if tag ==  1, ///
		mlabel(location) mlabpos(3) mlabcolor("41 182 164")  mcolor(gs4) ///
			msize(medsmall) mlabsize(medsmall)) ///
	(scatter kfr_pooled_pooled_p25 rent_twobed2015 if left_tag ==  1, ///
		mlabel(location) mlabpos(9) mlabcolor("41 182 164")  mcolor(gs4) ///
			msize(medsmall) mlabsize(medsmall)) ///
	(scatter kfr_pooled_pooled_p25 rent_twobed2015 if high_tag ==  1, ///
		mlabel(location) mlabpos(3) mlabcolor("41 182 164")  mcolor(gs10) ///
		msymbol(circle_hollow)	msize(small) mlabsize(medsmall)) ///
	(scatter kfr_pooled_pooled_p25 rent_twobed2015 if high_tag_left ==  1, ///
		msymbol(circle_hollow) mlabel(location) mlabpos(9) mlabcolor("41 182 164")  mcolor(gs10) ///
			msize(small) mlabsize(medsmall)) ///
	(scatter kfr_pooled_pooled_p25 rent_twobed2015 if top25==1, msize(medium) mcolor(gs4)) ///
	, legend(off) ///
	ylabel(`ylab', nogrid) ///
	xlabel(`xlab', nogrid) ///
	xtitle("Median 2-Bedroom Rent in 2015") ///
	ytitle("Mean Household Income Ranks of Children" "with Low-Income (25th Percenctile) Parents") ///
	${title}

graph export "${figs}/scatter_kfr_rent_oppbarg.${img}", replace
