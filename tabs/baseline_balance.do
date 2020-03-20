********************************************************************************
* Summary Stats at Baseline
********************************************************************************

	* set table type ("fullbalance" OR "fullbalancequal" OR "compquanttoqual")
	local whichtable "fullbalance"

if inlist("`whichtable'", "fullbalancequal") {
	
	* set group variable
	local group_var    "treatment"
	* set sample restriction
	local restriction  "interview_sample"
}

if inlist("`whichtable'", "compquanttoqual") {

	* set group variable ("treatment" OR "eligible" OR "pha_dummy" OR "qualitative")
	local group_var		"interview_sample"
	* set restriction ("" OR "qual" OR "full_qual" or "tbd_qual" OR "interview_sample")
	local restriction    ""
}

* locals for experimental sample full balance table
if inlist("`whichtable'", "fullbalance"){
	* set group variable ("treatment" OR "eligible" OR "pha_dummy" OR "qualitative")
	local group_var		"treatment"
	* set restriction ("" OR "qual" OR "full_qual" or "tbd_qual" OR "interview_sample")
	local restriction ""
}

* set eligibility restriction 
local eligible		"yes"

* set pha ("SHA" OR "KCHA" OR "")
local pha ""			
		
*Abridged version:		
local table_vars ///
		hoh_age hh_income /// Panel A Vars
		speaks_english born_abroad race_black race_white race_latino race_asian ///	
		hoh_female hoh_married ///
		less_hs hs some_coll college_plus homeless working works_full_time work_commute_30_min license_car ///
		child_count child_age /// 
		origin_cmto happy_with_nbhd would_leave_nbhd could_find_new_place /// Panel B Vars
		could_pay_move happy_move_racial_diff_nbhd feels_good_mto_nbhd ///
		consid_diff_school_any_kid unsat_with_school_any_kid ///
		main_motivation_schools main_motivation_safety main_motivation_home ///
		or_kfr_pooled_pooled_p25 origin_jail_p25 origin_teenbrth_p25 ///
		origin_poor_share2016 ///
		origin_share_black2017 ///
		origin_raw_math_2015_3_poor origin_extreme_pov
		
* ------------------------------------------------------------------------------
* Load Data:
* ------------------------------------------------------------------------------
		 
* load data
use "${phase1_der}/baseline_phas_dec2019" , clear

* restrict sample to subset
if "`eligible'" == "yes"		keep if eligible == 1 

* sample restriction
if "`restriction'" != ""		keep if `restriction' == 1

* ------------------------------------------------------------------------------
* Merge in Child Baseline Data
* ------------------------------------------------------------------------------

preserve

	* load child data
	use oi_hh_id pha treatment child_age *_school ///
		using "${phase1_der}/child_oi_cleaned_april2019", clear

	* set family unsatisfied = 1 if has 1 or more kids' schools they are unsatisifed with 
	gen unsat_with_school = inlist(sat_kid_school, 4, 5) if ~mi(sat_kid_school)
	bysort oi_hh_id : egen unsat_with_school_any_kid = max(unsat_with_school)

	* recode as binary and set to 1 if consid different school for any kid in family
	replace consid_diff_school = consid_diff_school == 1 if ~mi(consid_diff_school)
	bysort oi_hh_id : egen consid_diff_school_any_kid = max(consid_diff_school)

	* count
	gen child_count = 1

	* collapse to household level
	collapse (mean) child_age unsat_with_school_any_kid consid_diff_school_any_kid ///
			 (rawsum) child_count, by(oi_hh_id)

	* save
	tempfile child_data
	save `child_data'
	
restore

* merge to kids
merge 1:1 oi_hh_id using `child_data', nogen keep(master match)

* keep relevant pha (if specified)
if "`pha'" != "" 		keep if pha == "`pha'"

* encode PHA to be a dummy
label define pha_lab 0 "SHA" 1 "KCHA"
encode pha, gen(pha_dummy) lab(pha_lab)
codebook pha_dummy

* ------------------------------------------------------------------------------
* Prepare Variables for Table
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
gen race_latino = race_ethnicity == "Latino" if ~mi(race_ethnicity)
gen race_asian = race_ethnicity == "Asian" if ~mi(race_ethnicity)

* commute more than 30 min to work
codebook work_commute_length
gen work_commute_30_min = 1 if inlist(work_commute_length, 3, 4, 5)
replace work_commute_30_min = 0 if inlist(work_commute_length, 1, 2)

* drivers license and car
gen license_car = 1 if have_drivers == 1 & have_car == 1
replace license_car = 0 if have_drivers == 2 | have_car == 2

* less than high school
codebook education
gen less_hs = 1 if inlist(education, 1, 2, 3)
replace less_hs = 0 if inlist(education, 4, 5, 6, 7, 8)

*High School (including GED)
gen hs = 1 if inlist(education, 4, 5)
replace hs = 0 if inlist(education, 1, 2, 3, 6, 7, 8)

*Some college (no BA)
gen some_coll = 1 if inlist(education, 6, 7)
replace some_coll = 0 if inlist(education, 1, 2, 3, 4, 5, 8)

* college plus
gen college_plus = 1 if education == 8
replace college_plus = 0 if education <= 7

* happy
codebook happy
gen happy_indicator = 1 if inlist(happy, 1, 2)
replace happy_indicator = 0 if happy == 3
replace happy_indicator = . if inlist(happy, 4, 9)
tab happy_indicator

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

* feel good about moving to at least 1 opportunity neighborhood
codebook feel*
gen feels_good_mto_nbhd = 	   (inrange(feel_move_nbhd_nw_north, 1, 2) | ///
							   inrange(feel_move_nbhd_ne_east, 1, 2) | ///
							   inrange(feel_move_nbhd_ship_kent, 1, 2)) ///
							   if (~mi(feel_move_nbhd_nw_north) | ///
							      ~mi(feel_move_nbhd_ne_east) | ///
							      ~mi(feel_move_nbhd_ship_kent))

* poverty rates in origin tract
gen origin_extreme_pov = (origin_poor_share2016 >= 0.4) if origin_poor_share2016!=.
gen origin_high_pov = (origin_poor_share2016 >= 0.2 & origin_poor_share2016<0.4) ///	
						if origin_poor_share2016!=.
gen origin_middle_pov = (origin_poor_share2016 >= 0.1 & origin_poor_share2016<0.2) ///
						if origin_poor_share2016!=.
gen origin_low_pov = (origin_poor_share2016 < 0.1) if origin_poor_share2016!=. 

* works full-time
gen works_full_time = .
replace works_full_time = 0 if working_for_pay == 2
replace works_full_time = 0 if work_hours_per_week < 35
replace works_full_time = 1 if work_hours_per_week >= 35 & ~mi(work_hours_per_week)

* primary motivation
gen main_motivation_schools = .
replace main_motivation_schools = 0 if ~mi(main_reason_move)
replace main_motivation_schools = 1 if main_reason_move == 1

gen main_motivation_safety = .
replace main_motivation_safety = 0 if ~mi(main_reason_move)
replace main_motivation_safety = 1 if main_reason_move == 5

gen main_motivation_home = .
replace main_motivation_home = 0 if ~mi(main_reason_move)
replace main_motivation_home = 1 if main_reason_move == 6

* gender 
rename hoh_gender hoh_female

* drop if starts with "mean" (because messes up reshape)
drop mean_*
rename origin_jail_* origin_jail_p25

* multiply some variables by 100 for formatting
local percentage_vars /// 
		speaks_english born_abroad race_black race_white race_latino race_asian ///
		hoh_female hoh_married ///
		less_hs hs some_coll college_plus homeless working works_full_time work_commute_30_min license_car ///
		origin_cmto happy_with_nbhd would_leave_nbhd could_find_new_place ///
		could_pay_move happy_move_racial_diff_nbhd feels_good_mto_nbhd ///
		consid_diff_school_any_kid unsat_with_school_any_kid ///
		main_motivation_schools main_motivation_safety main_motivation_home ///
		origin_kfr_pooled_pooled_p25 ///
		origin_jail_p25 origin_teenbrth_p25 ///
		origin_poor_share2016 ///
		origin_share_black2017 ///
		origin_raw_math_2015_3_poor origin_extreme_pov

* multiply some variables by 100 for formatting
foreach var in `percentage_vars'{
	replace `var' = 100*`var' if ~mi(`var')
}

rename origin_kfr_pooled_pooled_p25 or_kfr_pooled_pooled_p25

* save base
tempfile base
save `base'

* ------------------------------------------------------------------------------
* Calculate F-Stat
* ------------------------------------------------------------------------------

* generate dummy variables for missings and recode missings as a different number
foreach var in `table_vars' {
	gen miss_`var' = mi(`var')
	replace `var' = -9 if mi(`var')
}

* list variables in table + the flags for missings
ds miss_*
local table_vars_mi `table_vars' `r(varlist)'

ds `table_vars_mi'

* F-test
reg `group_var' `table_vars_mi' pha_dummy
local n_reg `e(N)'
test `table_vars'
local ftest: di %4.3f `r(F)'
local ftest_p: di %4.3f `r(p)'

if inlist("`whichtable'", "fullbalancequal"){
*interview date is not missing if households were interviewed post lease
	reg `group_var' `table_vars_mi' pha_dummy if search_success == 1 & !mi(interview_date)
	local n_reg_2 `e(N)'
	test `table_vars'
	local ftest_2: di %4.3f `r(F)'
	local ftest_p_2: di %4.3f `r(p)'
	}
	
if inlist("`whichtable'", "compquanttoqual"){
*interview date is not missing if households were interviewed post lease
	reg `group_var' `table_vars_mi' pha_dummy ///
		if (interview_sample==0 & search_success == 1 )  ///
		| (interview_sample==1 & search_success == 1 & !mi(interview_date))
	local n_reg_2 `e(N)'
	test `table_vars'
	local ftest_2: di %4.3f `r(F)'
	local ftest_p_2: di %4.3f `r(p)'
	}

* save as file for appending to table below (and align stats with column names)
gen variable = "F-Test"
gen mean_group0 = `ftest'
gen sd_group0 = `ftest_p'
gen n_group0 = `n_reg'
keep variable mean_group0 sd_group0 n_group0
keep if _n == 1
tempfile ftest_file
save `ftest_file'

if inlist("`whichtable'", "fullbalancequal", "compquanttoqual"){
	replace variable = "F-Test (Conditional on Lease-up)"
	replace mean_group0 = `ftest_2'
	replace sd_group0 = `ftest_p_2'
	replace n_group0 = `n_reg_2'
	tempfile ftest_file_2
	save `ftest_file_2'

	}

* ------------------------------------------------------------------------------
* Collapse HOH Data + Reshape like Table (Mean, SD, N)
* ------------------------------------------------------------------------------

* load base
use `base', clear

sum hoh_age origin_teenbrth_p25 origin_tract

* calculate p-value for regression of outcome on indicator for treatment and PHA
foreach var in `table_vars' {
	reg `var' `group_var' pha_dummy, r
	local se_`var' = _b[`group_var']/_se[`group_var']
	local p_`var' = 2*ttail(e(df_r), abs(_b[`group_var']/_se[`group_var']))
	gen p_`var' = `p_`var''
}

* make SD and N variables
foreach var in `table_vars' {
	gen sd_`var' = `var'
	gen n_`var' = 1 if ~mi(`var')
	rename `var' mean_`var'
}

* expand and make new category for pooled
expand 2, gen(duplicate)
replace `group_var' = 2 if duplicate == 1

* variables
collapse (mean) mean_* p_* (sd) sd_* (rawsum) n_*, by(`group_var')

* reshape long (two rows for each variable)
reshape long mean_ sd_ n_ p_, i(`group_var') j(variable) string

* save
tempfile tab_base
save `tab_base'

* save group1 stats separately
keep if `group_var' == 1
renvars mean_ sd_ n_, postfix(group1)
drop `group_var' p_
tempfile group1_stats
save `group1_stats'

* save group0 stats separately
use `tab_base', clear
keep if `group_var' == 0
renvars mean_ sd_ n_, postfix(group0)
drop `group_var'
tempfile group0_stats
save `group0_stats'

* save group2 stats separately
use `tab_base', clear
keep if `group_var' == 2
keep `group_var' variable mean_ n_
renvars mean_, postfix(group2)
renvars n_, postfix(group2)
drop `group_var'

* merge treatment and group0 stats on variable name
merge 1:1 variable using `group1_stats', nogen
merge 1:1 variable using `group0_stats', nogen

* ------------------------------------------------------------------------------
* Append F-Test + Format Labels
* ------------------------------------------------------------------------------

* make p-values last column
order p_, last

* order variables
gen order = .
local i = 1
foreach var in `table_vars' {
	replace order = `i' if variable == "`var'"
	local i = `i' + 1
}
sort order
drop order

* relabel variables
replace variable = "Head of Household's Age" if variable == "hoh_age"
replace variable = "Household Income ($, Annual)" if variable == "hh_income"
replace variable = "% Speak English (w/o Translator)" if variable == "speaks_english"
replace variable = "% Born Outside the U.S." if variable == "born_abroad"
replace variable = "% Black" if variable == "race_black"
replace variable = "% White" if variable == "race_white"
replace variable = "% Latino" if variable == "race_latino"
replace variable = "% Asian" if variable == "race_asian"
replace variable = "% Less than High School Grad" if variable == "less_hs"
replace variable = "% Attended College or More" if variable == "college_plus"
replace variable = "% Homeless" if variable == "homeless"
replace variable = "% Currently Working" if variable == "working"
replace variable = "% Commute > 30 min to Work" if variable == "work_commute_30_min"
replace variable = "% with Car and Driver's License" if variable == "license_car"
replace variable = "% Happy Recently" if variable == "happy"

replace variable = "% Starting in High-Opportunity Tract" if variable == "origin_cmto"
replace variable = "% Good with Moving to Racially Diff Neighborhood" if variable == "happy_move_racial_diff_nbhd"
replace variable = "% Good with Moving to Specific Neighborhood in Opportunity Area" if variable == "feels_good_mto_nbhd"
replace variable = "% Satisfied with Current Neighborhood" if variable == "happy_with_nbhd"
replace variable = "% Feel They Could Find Place in New Neighborhood" if variable == "could_find_new_place"
replace variable = "% Could Pay for a Move" if variable == "could_pay_move"
replace variable = "% Would Leave Neighborhood if Got Voucher" if variable == "would_leave_nbhd"

replace variable = "% in Poverty (2016 ACS)" if variable == "origin_poor_share2016"
replace variable = "% Black (ACS 2013-2017)" if variable == "origin_share_black2017"
replace variable = "% Born Abroad (ACS 2016)" if variable == "origin_pct_foreign2016"
replace variable = "% Low-Inc. 3rd Graders Proficient in Math (2015)" if variable == "origin_raw_math_2015_3_poor"
replace variable = "% High School Degree" if variable == "hs"
replace variable = "% Attended Some College" if variable == "some_coll"
replace variable = "Predicted Mean Household Income Rank (p=25)" if variable == "or_kfr_pooled_pooled_p25"
replace variable = "Incarceration Rate (p=25)" if variable == "origin_jail_p25"
replace variable = "Teen Birth Rate (Women; p=25)" if variable == "origin_teenbrth_p25"
replace variable = "% in Extreme Poverty Tract (2016 ACS)" if variable == "origin_extreme_pov"
replace variable = "% in High Poverty Tract (2016 ACS)" if variable == "origin_high_pov"
replace variable = "% in Intermediate Poverty Tract (2016 ACS)" if variable == "origin_middle_pov"
replace variable = "% in Low Poverty Tract (2016 ACS)" if variable == "origin_low_pov"
replace variable = "% in Poverty (2010 ACS)" if variable == "origin_poor_share2010"
replace variable = "Median Household Income (2016 ACS)" if variable == "origin_med_hhinc2016"
replace variable = "Median Household Income (2017 ACS)" if variable == "origin_med_hhinc2017"
replace variable = "% Black (2010 ACS)" if variable == "origin_share_black2010"
replace variable = "PHA (King County Housing Authority = 1)" if variable == "pha_dummy"

replace variable = "Number of Children" if variable == "child_count"
replace variable = "Children's Average Age" if variable == "child_age"
replace variable = "% Considering Different School for Any Child" if variable == "consid_diff_school_any_kid"
replace variable = "% Unsatisfied with Any Child's Current School" if variable == "unsat_with_school_any_kid"

replace variable = "% Primary Motivation Schools" if variable == "main_motivation_schools"
replace variable = "% Primary Motivation Safety" if variable == "main_motivation_safety"
replace variable = "% Primary Motivation Bigger/Better Home" if variable == "main_motivation_home"

replace variable = "% Married Head of Household" if variable == "hoh_married"
replace variable = "% Female Head of Household" if variable == "hoh_female"
replace variable = "% Works Full-Time (Over 35 Hours/Week)" if variable == "works_full_time"

* add start to p-values
gen p = string(p_, "%4.3f")
replace p = p + "*" if p_ > 0.05 & p_ <= 0.10
replace p = p + "**" if p_ > 0.01 & p_ <= 0.05 
replace p = p + "***" if p_ <= 0.01
drop p_

* append ftest
append using `ftest_file'

if inlist("`whichtable'", "fullbalancequal", "compquanttoqual"){
	append using `ftest_file_2'
}

* formatting table size
gen blank1 = ""
gen blank2 = ""
gen blank3 = ""
order variable *group2 blank1 *group0 blank2 *group1 blank3 p

* rename columns
if "`group_var'" == "treatment"{
	renvars *group2, postsub("group2" "pooled")
	renvars	*group0, postsub("group0" "control")
	renvars	*group1, postsub("group1" "treat")
}
if "`group_var'" == "interview_sample" {
order variable *group2 blank1 *group1 blank2 *group0 blank3 p
	
}

* export
export delimited using "${tabs}/tab_baseline_balance_`whichtable'_dec2019", replace
