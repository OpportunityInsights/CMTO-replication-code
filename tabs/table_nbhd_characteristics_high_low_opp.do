********************************************************************************
* Table exploring potential selection of CMTO participants into specific areas ***
* within high-opportunity areas based on neighborhood characteristics          ***											*
********************************************************************************

********************************
* setting up    
********************************
* set outcomes of interest
local selection_outcomes share_black2017 share_white2017 share_hisp2017 pct_foreign2016 ///
	race_theil_2010 mean_commutetime2000 ///
	 mi_to_cz_cent median_value2010  ///
	mail_return_rate2010 environ_health_index ///
	pct_married2010 singleparent_share2017 frac_coll_plus2017 ///
	poor_share2017 popdensity2010 med_hhinc2017 lfp2010 ///
	traveltime15_2016 jobs_nohs_0mi_2015 transit_index ///
	kir_pooled_pooled_p25 kfr_pooled_pooled_p25 ///
	teenbrth_pooled_female_p25 jail_pooled_pooled_p25 /// 
	allcomp edcomp hecomp nbcomp
	
****************************************
* create treatment mover-weighted means    
****************************************
* get data
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1 & treatment == 1 & cmto == 1, clear
rename teenbrth_p25 teenbrth_pooled_female_p25	
gen HHCount = 1
drop *_uc

*make percents out of 100 for formatting 
foreach var in share_white2017 share_black2017 pct_foreign2016 traveltime15_2016 /// ///
lfp2010 pct_married2010 ///
poor_share2017 share_hisp2017 ///
 frac_coll_plus2017 singleparent_share2017 teenbrth_pooled_female_p25 ///
jail_pooled_pooled_p25 kfr_asian_pooled_p25 kfr_black_pooled_p25 ///
kfr_hisp_pooled_p25 kir_pooled_pooled_p25 ///
kfr_pooled_pooled_p25 kfr_white_pooled_p25  ///
{
	replace `var' = 100 * `var'
}

* collapse, weighted by households
collapse (mean) `selection_outcomes'  [aw=HHCount] 
xpose, clear varname
rename (v1 _varname) (movers label)

tempfile mover_weighted
save `mover_weighted'
	
********************************
* collect tract-level covariates    
********************************
* begin with list of opportunity and non-opportunity tracts	
use "${crosswalks}/cmto_tracts_checked.dta", clear
rename (state county tract) (state10 county10 tract10)

* merge in covariates
merge 1:1 state county tract using "${fg_covar}/covariates_tract_wide.dta"
assert _merge != 1 // _merge = 1 would mean we are dropping our Seattle tracts! 
drop if _merge == 2 // We have a lot of _merge = 2, which is the data from outside Seattle.
drop _merge
rename (state10 county10 tract10) (state county tract)
  
*merge in HUD transit index
merge 1:1 state county tract using "${fg_covar}/hud_affht_opp_indices/hud_affht_opp_indices"
assert _merge != 1 // same comment as above
drop if _merge == 2
drop _merge

*add Kirwan Child Opportunity Index:
merge 1:1 state county tract using "${fg_covar}/kirwan_opp_index/kirwan_100cities"
drop if _merge != 3
drop _merge

* merge KFR
merge 1:1 state county tract using "${census}/tract_race_gender_early_dp",  ///
	keepusing(teenbrth_pooled_female_p25 kfr_asian_pooled_p25 kfr_black_pooled_p25 ///
	kfr_hisp_pooled_p25 jail_pooled_pooled_p25 kir_pooled_pooled_p25 ///
	kfr_pooled_pooled_p25 kfr_white_pooled_p25 kid_pooled_pooled_blw_p50_n) keep(master match)
assert _merge != 1 
drop if _merge != 3
drop _merge
    
*make percents out of 100 for formatting 
foreach var in share_white2017 share_black2017 pct_foreign2016 traveltime15_2016 ///
lfp2010 pct_married2010 ///
poor_share2017 share_hisp2017 ///
frac_coll_plus2017 singleparent_share2017 teenbrth_pooled_female_p25 ///
jail_pooled_pooled_p25 kfr_asian_pooled_p25 kfr_black_pooled_p25 ///
kfr_hisp_pooled_p25 kir_pooled_pooled_p25 ///
kfr_pooled_pooled_p25 kfr_white_pooled_p25  ///
{
	replace `var' = 100 * `var'
}

tempfile tract_data
save `tract_data'

**************************************************
* create pooled, high-opp and non-high-opp means    
**************************************************
* create summary statistics
expand 2, gen(duplicate)
replace cmto = 2 if duplicate == 1
collapse (mean) `selection_outcomes' [aw = kid_pooled_pooled_blw_p50_n], by(cmto)

* manipulate into a dataset we can merge later
xpose, clear varname
rename (v1 v2 v3 _varname) (not_high_opportunity high_opportunity pooled label)	
drop if label == "cmto"

tempfile pop_below_p50_weighted
save `pop_below_p50_weighted'

********************************
* create population standard deviations    
********************************
use `tract_data'
foreach outcome in `selection_outcomes'{
	sum `outcome' [aw = kid_pooled_pooled_blw_p50_n]
	local SD_`outcome' = `r(sd)'
	gen tr_sd_`outcome' = `SD_`outcome''
}

* collapse
collapse (mean) tr_sd_*
xpose, clear varname
rename (v1 _varname) (sd_outcome label)

********************************
* put together results table    
********************************
replace label = substr(label, 7, .) if substr(label, 1, 6) == "tr_sd_"

merge 1:1 label using `mover_weighted'
assert _merge == 3 // the characteristics are the same across the three exercises
drop _merge

merge 1:1 label using `pop_below_p50_weighted'
assert _merge == 3 // as above
drop _merge

* create measure for gap in standard deviations
gen SD_movers_less_high = (movers - high_opportunity)/sd_outcome
drop sd_outcome

* set ordering
order label pooled not_high_opportunity high_opportunity movers SD_movers_less_high

gen order = .
replace order = 1 if label == "mean_commutetime2000"
replace order = 2 if label == "mi_to_cz_cent"
replace order = 3 if label == "distance_moved"
replace order = 4 if label == "traveltime15_2016"
replace order = 5 if label == "jobs_nohs_0mi_2015"
replace order = 6 if label == "share_white2017"
replace order = 7 if label == "share_black2017"
replace order = 8 if label == "share_hisp2017"
replace order = 9 if label == "pct_foreign2016"
replace order = 10 if label == "pct_married2010"
replace order = 11 if label == "singleparent_share2017"
replace order = 12 if label == "frac_coll_plus2017"
replace order = 13 if label == "popdensity2010"
replace order = 14 if label == "med_hhinc2017"
replace order = 15 if label == "lfp2010"
replace order = 16 if label == "poor_share2017"
replace order = 17 if label == "median_value2010"
replace order = 18 if label == "mail_return_rate2010"
replace order = 19 if label == "allcomp"
replace order = 20 if label == "edcomp"
replace order = 20.1 if label == "hecomp"
replace order = 21 if label == "nbcomp"
replace order = 22 if label == "transit_index"
replace order = 23 if label == "race_theil_2010"
replace order = 24 if label == "environ_health_index"
replace order = 25 if label == "kir_pooled_pooled_p25"
replace order = 26 if label == "kfr_pooled_pooled_p25"
replace order = 27 if label == "kfr_white_pooled_p25"
replace order = 28 if label == "teenbrth_pooled_female_p25"
replace order = 29 if label == "jail_pooled_pooled_p25"

sort order
drop order

order label pooled not_high_opportunity high_opportunity movers SD_movers_less_high
rename label variable

********************************
* export to excel    
********************************

export excel using "${cmto}/tabs/selection_effects_dec2019.xlsx", firstrow(variables) replace

