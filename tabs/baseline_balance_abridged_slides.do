********************************************************************************
* Summary Stats Baseline Data
********************************************************************************

* set group variable ("treatment" OR "eligible")
local group_var		treatment

* set eligibility ("yes" OR "")
local eligible 		yes

* set pha ("SHA" OR "KCHA" OR "")
local pha			
	
* ------------------------------------------------------------------------------
* Load Household and Child Baseline Data
* ------------------------------------------------------------------------------

* load child data
use oi_hh_id pha treatment child_age *_school ///
	using "${phase1_der}/child_oi_cleaned_april2019", clear

* set family unsatisfied = 1 if has 1 or more kids' schools they are unsatisifed with 
gen unsat_with_school = inlist(sat_kid_school, 4, 5) if ~mi(sat_kid_school)
bysort oi_hh_id : egen unsat_with_school_any_kid = max(unsat_with_school)

* recode as binary and set to 1 if consid different school for any kid in family
replace consid_diff_school = consid_diff_school == 1 if ~mi(consid_diff_school)
bysort oi_hh_id : egen consid_diff_school_any_kid = max(consid_diff_school)

* collapse to household level
collapse (mean) child_age unsat_with_school_any_kid consid_diff_school_any_kid, ///
	by(oi_hh_id)

* merge household baseline data
merge 1:1 oi_hh_id using ///
	"${phase1_der}/baseline_phas_dec2019", nogen 

* keep relevant pha (if specified)
if "`pha'" != "" 		keep if pha == "`pha'"

* keep only eligible
if "`eligible'" == "yes"	keep if eligible == 1

* ------------------------------------------------------------------------------
* Label Variables for Table
* ------------------------------------------------------------------------------

* speaks english
codebook used_translator
gen speaks_english = 1 if used_translator == 2
replace speaks_english = 0 if used_translator == 1

* born abroad
codebook birth_country
gen born_abroad = 1 if birth_country == 2 
replace born_abroad = 0 if birth_country == 1

* Working
codebook working_for_pay
gen working = 1 if working_for_pay == 1
replace working = 0 if working_for_pay == 2

* Race
codebook race_ethnicity
gen race_black = race_ethnicity == "African American/Black" if ~mi(race_ethnicity)
gen race_white = race_ethnicity == "White" if ~mi(race_ethnicity)

* commute more than 30 min to work
codebook work_commute_length
gen work_commute_30_min = 1 if inlist(work_commute_length, 3, 4, 5)
replace work_commute_30_min = 0 if inlist(work_commute_length, 1, 2)

* less than high school
codebook education
gen hs_grad = 1 if inlist(education, 4, 5, 6, 7, 8)
replace hs_grad = 0 if inlist(education, 1, 2, 3)

* college plus
gen college_plus = 1 if education == 8
replace college_plus = 0 if education <= 7

* happy
codebook happy
gen happy_indicator = 1 if inlist(happy, 1, 2)
replace happy_indicator = 0 if happy == 3

* happy with current neighborhood
codebook nbhd_satisfaction
gen happy_with_nbhd = 1 if inlist(nbhd_satisfaction, 1, 2)
replace happy_with_nbhd = 0 if inlist(nbhd_satisfaction, 3, 4, 5)

* would leave
codebook nbhd_would_stay
gen would_leave_nbhd = 1 if inlist(nbhd_would_stay, 4, 5)
replace would_leave_nbhd = 0 if inlist(nbhd_would_stay, 1, 2, 3)

* happy with racially different neighborhood
codebook feel_diff_race_nbhd
gen happy_move_racial_diff_nbhd = 1 if inlist(feel_diff_race_nbhd, 1, 2)
replace happy_move_racial_diff_nbhd = 0 if inlist(feel_diff_race_nbhd, 3, 4, 5)

* sure could find place
codebook could_find_home_new_nbhd
gen could_find_new_place = 1 if inlist(could_find_home_new_nbhd, 1, 2)
replace could_find_new_place = 0 if inlist(could_find_home_new_nbhd, 3, 4, 5)

* could pay for move
codebook could_pay_move_expense
gen could_pay_move = 1 if inlist(could_pay_move_expense, 1, 2)
replace could_pay_move = 0 if inlist(could_pay_move_expense, 3, 4, 5)

* save base
tempfile base
save `base'
	
* ------------------------------------------------------------------------------
* Collapse HOH Data + Reshape like Table (Mean, SD, N)
* ------------------------------------------------------------------------------

* load base
use `base', clear

* expand to make new group of pooled observations
expand 2, gen(pooled)
replace treatment = 2 if pooled == 1

* make counts
preserve
	gen count = 1
	collapse (rawsum) count, by(treatment)
	gen variable = "Number of Observations"
	reshape wide count, i(variable) j(treatment)
	rename (count0 count1 count2) (mean_control mean_treat mean_pooled)
	tempfile counts 
	save `counts'
restore

* multiply percentages by 100
foreach var in race_black hs_grad homeless working happy_with_nbhd ///
			   unsat_with_school_any_kid {
	replace `var' = `var' * 100
}

* make SD and N variables
foreach var in `table_vars' {
	rename `var' mean_`var'
}
drop mean_dist*

* variables
collapse (mean) mean_*, by(`group_var')

* reshape long (two rows for each variable)
reshape long mean_, i(`group_var') j(variable) string

* save pooled stats separately
preserve 
	keep if `group_var' == 2
	renvars mean_, postfix(group2)
	drop `group_var'
	tempfile group2_stats
	save `group2_stats'
restore

* save treatment stats separately
preserve 
	keep if `group_var' == 1
	renvars mean_, postfix(group1)
	drop `group_var'
	tempfile group1_stats
	save `group1_stats'
restore

* prep group0 stats separately
keep if `group_var' == 0
renvars mean_, postfix(group0)
drop `group_var'

* merge treatment and group0 stats on variable name
merge 1:1 variable using `group1_stats', nogen
merge 1:1 variable using `group2_stats', nogen

* ------------------------------------------------------------------------------
* Append HOH and Child Data + Format Labels
* ------------------------------------------------------------------------------

* order variables
gen order = .
replace order = 1 if variable == "hh_income"
replace order = 2 if variable == "race_black"
replace order = 3 if variable == "hs_grad"
replace order = 4 if variable == "hoh_age"
replace order = 5 if variable == "child_age"
replace order = 6 if variable == "homeless"
replace order = 7 if variable == "working"
replace order = 8 if variable == "happy_with_nbhd"
replace order = 9 if variable == "sat_with_school_all_kids"
sort order
drop order

* relabel variables
replace variable = "Household Income" if variable == "hh_income"
replace variable = "% Black" if variable == "race_black"
replace variable = "% High School Grad" if variable == "hs_grad"
replace variable = "Head of Household's Age" if variable == "hoh_age"
replace variable = "Children's Mean Age" if variable == "child_age"
replace variable = "% Homeless" if variable == "homeless"
replace variable = "% Currently Working" if variable == "working"
replace variable = "% Satisfied with Current Neighborhood" if variable == "happy_with_nbhd"
replace variable = "% Unsatisfied with Children's Current School" if variable == "unsat_with_school_any_kid"

* formatting table size
order variable *group2 *group0 *group1 

* rename columns
if "`group_var'" == "treatment"{
	renvars *group2, postsub("group2" "pooled")
	renvars	*group0, postsub("group0" "control")
	renvars	*group1, postsub("group1" "treat")
}

* append counts
append using `counts'

* export
export delimited using "${tabs}/tab_baseline_balance_abridged_slides_dec2019", replace

