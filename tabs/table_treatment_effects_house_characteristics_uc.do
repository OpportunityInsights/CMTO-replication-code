********************************************************************************
* Table Showing Treatment Effects on Different
* Neighborhood and Unit Characteristics
********************************************************************************

* set outcomes of interest
local outcomes ///
	mean_commutetime2000_uc mi_to_cz_cent_uc distance_moved_uc ///
	traveltime15_2016_uc jobs_nohs_0mi_2015_uc ///
	share_white2017_uc share_black2017_uc share_hisp2017_uc pct_foreign2016_uc ///
	pct_married2010_uc singleparent_share2017_uc frac_coll_plus2017_uc ///
	popdensity2010_uc ///
	med_hhinc2017_uc lfp2010_uc poor_share2017_uc median_value2010_uc ///
	mail_return_rate2010_uc ///
	allcomp_uc edcomp_uc edcomp_test_scores_uc hecomp_uc nbcomp_uc transit_index_uc ///
	 race_theil_2010_uc environ_health_index_uc ///
	kir_pooled_pooled_p25_uc kfr_pooled_pooled_p25_uc kfr_white_pooled_p25_uc ///
	teenbrth_p25_uc jail_pooled_pooled_p25_uc ///
	sq_ft_ yearbuilt HHApplianceIndex bathsandhalf ac_cooling ///
	rent_utilities rent_total rent_hap_total out_of_pocket_total

local percentages ///
	traveltime15_2016_uc share_white2017_uc share_black2017_uc ///
	share_hisp2017_uc pct_foreign2016_uc pct_married2010_uc ///
	singleparent_share2017_uc frac_coll_plus2017_uc ///
	poor_share2017_uc kir_pooled_pooled_p25_uc kfr_pooled_pooled_p25_uc ///
	kfr_white_pooled_p25_uc teenbrth_p25_uc jail_pooled_pooled_p25_uc ac_cooling

* load data
use "${phase1_der}/baseline_phas_dec2019.dta", clear
keep if eligible == 1 & drop_short_run!=1

* merge amenity data
merge 1:1 oi_hh_id using "${cmto_der}/amenity_data.dta", nogen keep(master match)

**make hh appliance index and combine baths + half baths
gen HHApplianceIndex = (microwave + refrigerator + dishwasher + dryer + washer + garbagedisposal)/6
gen bathsandhalf = baths + halfbaths
label variable treatment "1 = Treatment 0 = Control"

**merge in covariates
merge m:1 state county tract using "${fg_covar}/hud_affht_opp_indices/hud_affht_opp_indices", ///
nogen keep(match master)

*generate PHA dummy
gen pha_dummy=1 if pha=="KCHA"
replace pha_dummy=0 if pha=="SHA"

*topcode distance moved and make unconditional
rename distance_moved distance_moved_uc
replace distance_moved_uc = 50 if distance_moved_uc >= 50 & distance_moved_uc != .
replace distance_moved_uc = 0 if search_success == 0

*code variable that calculates out of pocket expenditues for each household
gen rent_tenant_util_full = rent_tenant_util
replace rent_tenant_util_full = rent_utilities + rent_tenant_no_util if rent_tenant_util == .
gen out_of_pocket_total = rent_tenant_util_full - rent_utility_reimbursement

*normalize with respect to control SDs
foreach var in `outcomes' {
	sum `var' if treatment == 0
	gen `var'_SD = `var' / `r(sd)'
}

* scale some variables to percentages
foreach var in `percentages' {
	replace `var' = 100 * `var'
}

* comput statistics that go into the table:
foreach outcome in `outcomes'{
	sum `outcome' if treatment == 0
	local `outcome'_mean = `r(mean)'
	local `outcome'_sd = `r(sd)'
	gen `outcome'_c_me = ``outcome'_mean'
	gen `outcome'_c_sd = ``outcome'_sd'
	reg `outcome' treatment pha_dummy, r
	local `outcome'_t = _b[treatment]
	local `outcome'_SE = _se[treatment]
	gen `outcome'_t_ef = ``outcome'_t'
	gen `outcome'_t_me = `outcome'_t_ef + `outcome'_c_me
	gen `outcome'_t_SE = ``outcome'_SE'
	reg `outcome'_SD treatment pha_dummy, r
	local `outcome'_t_SD = _b[treatment]
	local `outcome'_SE_SD = _se[treatment]
	gen `outcome'_t_SD = ``outcome'_t_SD'
	gen `outcome'_SESD = ``outcome'_SE_SD'
	gen `outcome'_pval = 2*normal(-abs( `outcome'_t_SD / `outcome'_SESD))
}

collapse (mean) *_c_me *_c_sd *_t_ef *_t_me *_t_SE *_t_SD *_SESD *_pval

*format table:
ds
renvars `r(varlist)', prefix(s_)
gen t = "output"
reshape long s_, i(t) j(label) string
gen  indicator = substr(label, -5, .)

foreach outcome in `outcomes'{
	replace label = "`outcome'" if regexm(label, "`outcome'") == 1
}

reshape wide s_, i(label) j(indicator) string
drop t

* Add stars to p-values and treatment effects
gen pval = string(s__pval, "%4.2f")
replace pval = pval + "*" if s__pval > 0.05 & s__pval <= 0.10
replace pval = pval + "**" if s__pval > 0.01 & s__pval <= 0.05
replace pval = pval + "***" if s__pval <= 0.01

gen treatment_ef = string(s__t_ef, "%4.2f")
replace treatment_ef= treatment_ef + "*" if s__pval > 0.05 & s__pval <= 0.10
replace treatment_ef = treatment_ef + "**" if s__pval > 0.01 & s__pval <= 0.05
replace treatment_ef = treatment_ef + "***" if s__pval <= 0.01
drop s__t_ef
drop s__pval

* add gaps for formatting
forval i = 1/7 {
	gen gap`i' = .
}

order label s__c_me gap1 s__c_sd gap2 s__t_me gap3 treatment_ef gap4 ///
	  s__t_SE gap5 s__t_SD gap6 s__SESD gap7 pval

*order variables:
gen order = .
replace order = 1 if label == "mean_commutetime2000_uc"
replace order = 2 if label == "mi_to_cz_cent_uc"
replace order = 3 if label == "distance_moved_uc"
replace order = 4 if label == "traveltime15_2016_uc"
replace order = 5 if label == "jobs_nohs_0mi_2015_uc"
replace order = 6 if label == "share_white2017_uc"
replace order = 7 if label == "share_black2017_uc"
replace order = 8 if label == "share_hisp2017_uc"
replace order = 9 if label == "pct_foreign2016_uc"
replace order = 10 if label == "pct_married2010_uc"
replace order = 11 if label == "singleparent_share2017_uc"
replace order = 12 if label == "frac_coll_plus2017_uc"
replace order = 13 if label == "popdensity2010_uc"
replace order = 14 if label == "med_hhinc2017_uc"
replace order = 15 if label == "lfp2010_uc"
replace order = 16 if label == "poor_share2017_uc"
replace order = 17 if label == "median_value2010_uc"
replace order = 18 if label == "mail_return_rate2010_uc"
replace order = 19 if label == "allcomp_uc"
replace order = 20 if label == "edcomp_uc"
replace order = 21 if label == "hecomp_uc"
replace order = 22 if label == "nbcomp_uc"
replace order = 23 if label == "transit_index_uc"
replace order = 24 if label == "race_theil_2010_uc"
replace order = 25 if label == "environ_health_index_uc"
replace order = 26 if label == "kir_pooled_pooled_p25_uc"
replace order = 27 if label == "kfr_pooled_pooled_p25_uc"
replace order = 28 if label == "kfr_white_pooled_p25_uc"
replace order = 29 if label == "teenbrth_p25_uc"
replace order = 30 if label == "jail_pooled_pooled_p25_uc"
replace order = 31 if label == "sq_ft_"
replace order = 32 if label == "yearbuilt"
replace order = 33 if label == "HHApplianceIndex"
replace order = 34 if label == "bathsandhalf"
replace order = 35 if label == "ac_cooling"
replace order = 36 if label == "rent_total"
replace order = 37 if label == "rent_hap_total"
replace order = 38 if label == "rent_utilities"
replace order = 39 if label == "out_of_pocket_total"

sort order
drop order

format s__c_me s__c_sd s__t_me s__t_SE s__t_SD s__SESD %9.2fc

rename (s__c_me s__c_sd s__t_me treatment_ef s__t_SE s__t_SD s__SESD ///
		pval) ///
	   (control_mean control_sd treatment_mean treatment_effect ///
		treatment_SE treatment_effect_SD treatment_effect_SD_SE ///
		treatment_effect_pval)

*export excel:
export excel using "${cmto}/tabs/nbhd_charactertics_dec2019.xlsx", ///
	firstrow(variables) replace

*export csv:
export delimited using "${tabs}/nbhd_charactertics_dec2019", replace

