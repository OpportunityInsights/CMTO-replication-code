********************************************************************************
* Calculate the Impact of CMTO on Lifetime Earnings
********************************************************************************

* scale by causal effect of place (62%)
local make_it_causal	0.62

* set discount and wage growth rates
local discount			0.02
local wage_g			0.01 

local age_restriction_l = 18
local age_restriction_u = . // 65
	
* set outcome
local est	  kfr // Options: kir, kfr
local outcome `est'_pooled_pooled_p25 // `est'_pooled_pooled_p25 kfr_p25_shrunk_constant
local forecast_series = "tot_spouse_wage" /* Options: "ftotinc" (Total family income),
	"incwage" (Personal wage and salary income), "tot_spouse_wage" (individual
	+ spouse salary and wage income) */
local acs_to_2015_deflator = 1.001264 /* Source: adjinc from ACS to convert 
	2015 ACS PUMS to 2015 dollars in
	${fg}/data/raw/census/2018_09_21/outside/ACS_IRS_earnings_profiles.xlsx */

* ------------------------------------------------------------------------------
* Calculate Mean Wages at 34 and Undiscounted Wages on Average
* ------------------------------------------------------------------------------

* load IRS earnings profile by age
*Loading ACS data for family income
use "${dropbox}/outside/cmto/data/raw/2015 ACS/usa_00006", replace
keep if age >= `age_restriction_l' & age <= `age_restriction_u'

if "`forecast_series'" == "ftotinc" {
	keep if `forecast_series' != 9999999
	collapse (mean) `forecast_series' [w=hhwt], by(age)
}
else if "`forecast_series'" == "incwage" {
	keep if `forecast_series' != 999999
	collapse (mean) `forecast_series' [w=perwt], by(age)
}
else if "`forecast_series'" == "tot_spouse_wage" {
    keep if incwage != 999999 & incwage != 999998
    keep if incwage_sp != 999999
	replace incwage_sp = 0 if missing(incwage_sp) //1727759 changes
    gen `forecast_series' = incwage + incwage_sp
    collapse (mean) `forecast_series' [w=perwt], by(age)
}

tsset age
tsfill
replace `forecast_series' = 0 if `forecast_series' == . 
gen wage = `forecast_series' * `acs_to_2015_deflator'
keep age wage

* store wage at age 34 from ACS data
sum wage if age == 34
local wage_34 = r(mean)

* merge survival rates by age from Raj's JAMA paper
preserve
	use "${fg}/scratch/lifetime_earnings/survival_rates_by_percentile.dta", clear
	egen surv_rate = rowmean(surv_fit_p*)
	keep age surv_rate
	tempfile survival_rates
	save `survival_rates'
restore
merge 1:1 age using `survival_rates', keep(1 3) nogen
replace surv_rate = 100 if surv_rate == .
replace surv_rate = surv_rate / 100

* generate discount and wage factors
gen disc_factor = surv_rate * ((1/(1 + `discount' - `wage_g'))^age)
gen wage_factor = surv_rate * ((1/(1 - `wage_g'))^age)

* generate discounted and undiscounted wages
gen wage_disc = disc_factor * wage
gen wage_undisc = wage_factor * wage

* add up over all ages
collapse (rawsum) wage_disc wage_undisc

* save aggregate wages
local wage_disc = wage_disc[1]
local wage_undisc = wage_undisc[1]

local steps_8 = `wage_undisc'
local steps_10 = `wage_disc'


* ------------------------------------------------------------------------------
* Calculate CMTO Treatment Effect 
* ------------------------------------------------------------------------------

* load CMTO movers data
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1, clear
	
keep `outcome' treatment cmto pha `outcome'_uc cmto_uncond

* scale variable by 100
replace `outcome' = 100 * `outcome'
replace `outcome'_uc = 100 * `outcome'_uc

gen pha_dummy=(pha=="KCHA")

* calculate treatment effect on outcome
reg `outcome'_uc treatment pha_dummy, robust
local effect_rank = _b[treatment]

* get control_rank
sum `outcome'_uc if treatment == 0
local control_rank = r(mean)

local steps_1 = `control_rank'

* calculate treatment effect on moving to high opp area
reg cmto_uncond treatment pha_dummy, robust
local effect_mto = _b[treatment]

* adjust treatment effect on rank by share MTO
local effect_rank = `effect_rank' / `effect_mto'
local steps_2 = `effect_rank'

local effect_rank = `effect_rank' * `make_it_causal'
local steps_3 = `effect_rank'

local level_plus_impact = `effect_rank' + `control_rank'
local steps_4 = `level_plus_impact'

*Using atlas crosswalk to find new average earnings at age 34 for treatment and control
convert_rank_dollar `level_plus_impact', `est' 
local level_plus_impact_dollars = `r(dollar_amount)'
convert_rank_dollar `control_rank', `est'
local control_level_dollars = `r(dollar_amount)'
local steps_12 = `control_level_dollars'
local steps_13 = `level_plus_impact_dollars'

local effect_dollar = `level_plus_impact_dollars' - `control_level_dollars'
local steps_5 = `effect_dollar'

local steps_6 = `wage_34'

local effect_dollar_pct_age_34 = `effect_dollar' / `wage_34'
local steps_7 = `effect_dollar_pct_age_34'

local steps_9 : di %7.0f round(`effect_dollar_pct_age_34' * `wage_undisc', 1)
local effect_lifetime_dollar = `steps_9'
local steps_11 : di %7.0f round(`effect_dollar_pct_age_34' * `wage_disc', 1)

* ------------------------------------------------------------------------------
* Calculate % Increase in Earnings with CMTO for Low-Income Kids in Seattle 
* ------------------------------------------------------------------------------

*** Calculate Average Low-Income Child's Earnings in Low-Opp Areas

local outcome `est'_pooled_pooled_p25

* load low-opp areas
use "${crosswalks}/cmto_tracts_checked", clear

* merge mobility outcomes
merge 1:1 state county tract using "${census}/tract_race_gender_early_dp", ///
	nogen keep(master match) ///
	keepusing(`outcome' kid_pooled_pooled_blw_p50_n)

* scale variable by 100
replace `outcome' = 100 * `outcome'

* calculate mean
summ `outcome' [w = kid_pooled_pooled_blw_p50_n] if cmto == 0
local rank_low_inc = `r(mean)'

* convert treatment effect into dollars
convert_rank_dollar `rank_low_inc', `est'
local dollar_low_inc = `r(dollar_amount)'

* convert yearly dollars to lifetime dollars
local lifetime_dollar_low_inc = (`dollar_low_inc' / `wage_34') * `wage_undisc'
di "`lifetime_dollar_low_inc'"

* save stat
local steps_14 : di %12.1f `lifetime_dollar_low_inc'
di "`steps_14'"

* annual % inc
local pct_inc = `effect_dollar ' / `dollar_low_inc' * 100
di "`pct_inc'"

* lifetime % inc
local pct_inc_lifetime = `effect_lifetime_dollar' / `lifetime_dollar_low_inc' 
di "`pct_inc_lifetime'"

* save stat
local steps_15 : di %4.2f `pct_inc_lifetime' * 100
di "`steps_15'"
	
** START EXCEL TABLE OUTPUT
preserve
	clear
	set obs 15
	gen steps = ""
	gen value = 0
	forvalues i = 1/15 {
		replace value = `steps_`i'' in `i'
	}
	replace steps = "Average Upward Mobility (in ranks) in control group destinations" in 1
	replace steps = "Treatment effect (TOT) on Upward Mobility (in ranks)" in 2
	replace steps = "Estimated causal effect of move from birth [ = 62% of (3)]" in 3
	replace steps = "Expected Upward Mobility (in ranks) for treated [ = (1) + (3) ]" in 4
	replace steps = "Causal effect of CMTO on yearly income at age 34 ($2015USD) [ = (6) - (2) ]" in 5
	replace steps = "Avg family income at age 34 ($2015USD, from ACS)" in 6
	replace steps = "Impact as % of avg family income in ACS [ = (7) / (8) ]" in 7
	replace steps = "Undiscounted income over the lifecycle from ACS, 0.5% income growth ($2015USD)" in 8
	replace steps = "Causal treatment effect on undiscounted lifetime income (USD) [ = (10) * (9) ]" in 9
	replace steps = "Discounted income over the lifecycle from ACS, 0.5% income growth ($2015USD)" in 10
	replace steps = "Causal treatment effect on discounted lifetime income (USD) [ = (10) * (12) ]" in 11
	replace steps = "Line 1 [Translated to $2015USD]" in 12
	replace steps = "Line 5 [Translated to $2015USD]" in 13
	replace steps = "Average Lifetime Low-Income Kids Earnings in Low Opp Areas in Seattle" in 14
	replace steps = "Effect as % of Low-Income Kids Earnings in Low Opp Areas in Seattle" in 15
	assert value != 0
	assert steps != ""
	export delimited "${dropbox}/outside/cmto/tabs/lifetime_earnings_calc_`est'_`forecast_series'_dec2019", replace nolabel
restore
** END EXCEL TABLE OUTPUT

* display
di "Impact on Annual Rank = `effect_rank'"
di "Impact on Annual Dollar = `effect_dollar'"
di "Impact on Lifetime Dollar = `effect_lifetime_dollar'"
