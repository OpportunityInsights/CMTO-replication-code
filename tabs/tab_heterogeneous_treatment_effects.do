********************************************************************************
* Heterogeneous effects of CMTO
********************************************************************************

* set outcomes
local outcome_list cmto_uncond search_success

* set demographics
local demo_list		/// *Panel A (PHA and Controls)
					full_sample full_sample_contr sha kcha /// *Panel B (household characteristics)
					race_black race_white race_other ///  
					born_abroad born_US english_not_primary english_primary more_20_years_seattle less_20_years_seattle ///
					origin_cmto origin_non_cmto  lower_income higher_income no_coll some_coll_or_more working not_working ///
					uses_child_care doesnt_use_child_care /// *Panel C (perceptions)
					feels_good_mto_nbhd feels_nogood_mto_nbhd happy_with_nbhd unhappy_with_nbhd would_leave_nbhd wouldnt_leave_nbhd ///
					happy_move_racial_diff unhappy_move_racial_diff could_pay_move couldnt_pay_move could_find_new_place couldnt_find_new_place  /// *Panel D (Children)
					older_children younger_children more_children less_children ///
					consid_diff_school not_consid_diff_school
					
*set covariates from table 1
local covars_table_1 ///
		hoh_age hh_income ///
		speaks_english born_abroad race_black race_white race_latino ///	
		less_hs hs some_coll college_plus homeless working work_commute_30_min license_car ///
		origin_cmto happy_with_nbhd would_leave_nbhd could_find_new_place ///
		could_pay_move happy_move_racial_diff_nbhd feels_good_mto_nbhd ///
		origin_kfr_pooled_pooled_p25 origin_jail_p25 origin_teenbrth_p25 ///
		origin_poor_share2017 ///
		origin_share_black2017 ///
		origin_raw_math_2015_3_poor pha_dummy ///
		child_count child_age consid_diff_school_any_kid unsat_with_school_any_kid

* ------------------------------------------------------------------------------
* Clean Child Baseline Data
* ------------------------------------------------------------------------------

* load child data
use oi_hh_id pha treatment child_age *_school ///
	using "${phase1_der}/child_oi_cleaned_april2019", clear

* generate age to be collapsed
gen median_child_age = child_age

* set family unsatisfied = 1 if has 1 or more kids' schools they are unsatisifed with school
gen unsat_with_school = inlist(sat_kid_school, 4, 5) if ~mi(sat_kid_school)
bysort oi_hh_id : egen unsat_with_school_any_kid = max(unsat_with_school)

* recode as binary and set to 1 if considering different school for any kid in family
replace consid_diff_school = consid_diff_school == 1 if ~mi(consid_diff_school)
bysort oi_hh_id : egen consid_diff_school_any_kid = max(consid_diff_school)

gen child_count = 1

* collapse to household level
collapse (mean) child_age ///
		 (mean) unsat_with_school_any_kid consid_diff_school_any_kid ///
		 (rawsum) child_count, by(oi_hh_id)

* save
tempfile child_data
save `child_data'

* ------------------------------------------------------------------------------
* Load Data and Create Subgroups
* ------------------------------------------------------------------------------

* load eligible households with info on first move
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1, clear
	
merge 1:1 oi_hh_id using `child_data', nogen keep(master match)

drop sha
* full sample
gen full_sample = 1
gen full_sample_contr = 1

* pha
gen sha = pha == "SHA"
gen kcha = pha == "KCHA"

* encode PHA to be a dummy
label define pha_lab 0 "SHA" 1 "KCHA"
encode pha, gen(pha_dummy) lab(pha_lab)
codebook pha_dummy

* Race
codebook race_ethnicity
gen race_black = race_ethnicity == "African American/Black" if ~mi(race_ethnicity)
gen race_white = race_ethnicity == "White" if ~mi(race_ethnicity)
gen race_other = 1 if race_ethnicity!="African American/Black" & race_ethnicity!="White" & !mi(race_ethnicity)
gen race_latino = race_ethnicity == "Latino" if ~mi(race_ethnicity)
gen race_asian = race_ethnicity == "Asian" if ~mi(race_ethnicity)

* immigrant status
* speaks english
codebook used_translator
gen speaks_english = 1 if used_translator == 2
replace speaks_english = 0 if used_translator == 1

* born abroad
codebook birth_country
gen born_abroad = 1 if birth_country == 2 
replace born_abroad = 0 if birth_country == 1
gen born_US = birth_country == 1 if ~mi(birth_country)

* income binary
summ hh_income, d
gen higher_income = hh_income > `r(p50)' if ~mi(hh_income)
gen lower_income = hh_income <= `r(p50)' if ~mi(hh_income)

* working
codebook working_for_pay
gen working = 1 if working_for_pay == 1
gen not_working = 1 if working_for_pay == 2

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

*High Shcool (including GED)
gen hs = 1 if inlist(education, 4, 5)
replace hs = 0 if inlist(education, 1, 2, 3, 6, 7, 8)

*Some college (no BA)
gen some_coll = 1 if inlist(education, 6, 7)
replace some_coll = 0 if inlist(education, 1, 2, 3, 4, 5, 8)

* college plus
gen college_plus = 1 if education == 8
replace college_plus = 0 if education <= 7

codebook education
*No College:
gen no_coll = 1 if inlist(education, 1, 2, 3, 4, 5)
replace no_coll = 0 if inlist(education, 6, 7, 8)

*Some coll or more:
gen some_coll_or_more = 1 if inlist(education, 6, 7, 8)
replace some_coll_or_more = 0 if inlist(education, 1, 2, 3, 4, 5)

* happy
codebook happy
gen happy_indicator = 1 if inlist(happy, 1, 2)
replace happy_indicator = 0 if happy == 3
replace happy_indicator = . if inlist(happy, 4, 9)
tab happy_indicator

* happy with current neighborhood
codebook nbhd_satisfaction
gen happy_with_nbhd = 1 if inlist(nbhd_satisfaction, 1, 2)
gen unhappy_with_nbhd = 1 if inlist(nbhd_satisfaction, 3, 4, 5)

* would leave
codebook nbhd_would_stay
gen would_leave_nbhd = 1 if inlist(nbhd_would_stay, 4, 5)
gen wouldnt_leave_nbhd = 1 if inlist(nbhd_would_stay, 1, 2, 3)

* happy with racially different neighborhood
codebook feel_diff_race_nbhd
gen happy_move_racial_diff = 1 if inlist(feel_diff_race_nbhd, 1, 2)
gen unhappy_move_racial_diff = 1 if inlist(feel_diff_race_nbhd, 3, 4, 5)

gen happy_move_racial_diff_nbhd = 1 if inlist(feel_diff_race_nbhd, 1, 2)
replace happy_move_racial_diff_nbhd = 0 if inlist(feel_diff_race_nbhd, 3, 4, 5)

* sure could find place
codebook could_find_home_new_nbhd
gen could_find_new_place = 1 if inlist(could_find_home_new_nbhd, 1, 2)
gen couldnt_find_new_place = 1 if inlist(could_find_home_new_nbhd, 3, 4, 5)

* could pay for move
codebook could_pay_move_expense
gen could_pay_move = 1 if inlist(could_pay_move_expense, 1, 2)
gen couldnt_pay_move = 1 if inlist(could_pay_move_expense, 3, 4, 5)

* language
gen english_not_primary = primary_language != 1 if ~mi(primary_language)
gen english_primary = primary_language == 1 if ~mi(primary_language)
gen not_fluent = inlist(english_fluency, 3, 4) if ~mi(english_fluency)
replace used_translator = 0 if used_translator == 2

* feelings about moving to MTO neighborhood
gen feels_good_mto_nbhd = 	   (inrange(feel_move_nbhd_nw_north, 1, 2) | ///
							   inrange(feel_move_nbhd_ne_east, 1, 2) | ///
							   inrange(feel_move_nbhd_ship_kent, 1, 2)) ///
							   if (~mi(feel_move_nbhd_nw_north) | ///
							      ~mi(feel_move_nbhd_ne_east) | ///
							      ~mi(feel_move_nbhd_ship_kent))
								  
gen feels_nogood_mto_nbhd = (feels_good_mto_nbhd==0)

*Rename incarceration rate:
rename origin_jail_* origin_jail_p25

*Origin not high opp: 
gen origin_non_cmto = (origin_cmto == 0)

* Years in USA
replace years_in_usa = . if birth_country == 1
sum years_in_usa, det
local median_migrant_years_in_usa = `r(p50)'
gen above_median_us_years = . 
replace above_median_us_years = 1 if years_in_usa >= `median_migrant_years_in_usa' & ~mi(years_in_usa)
gen below_median_us_years = .
replace below_median_us_years = 0 if years_in_usa < `median_migrant_years_in_usa' & ~mi(years_in_usa)

* Time in Seattle or King City
gen more_20_years_seattle = .
replace more_20_years_seattle = 1 if time_in_king_cty == 4 & ~mi(time_in_king_cty)
gen less_20_years_seattle = .
replace less_20_years_seattle = 1 if time_in_king_cty != 4 & ~mi(time_in_king_cty)

* child care
gen uses_child_care = 1 if child_care_none == 0
gen doesnt_use_child_care = 1 if child_care_none == 1

*child age
sum child_age, det
gen older_children = 1 if child_age >= `r(p50)' & ~mi(child_age)
gen younger_children = 1  if child_age < `r(p50)'  & ~mi(child_age)

*child count
sum child_count, det
gen more_children = 1 if child_count > `r(p50)' & ~mi(child_count)
gen less_children = 1  if child_count <= `r(p50)'  & ~mi(child_count)

*considering different school for kids
gen consid_diff_school = 1 if consid_diff_school_any_kid==1 & ~mi(consid_diff_school_any_kid) 
gen not_consid_diff_school = 1 if consid_diff_school_any_kid==0 & ~mi(consid_diff_school_any_kid)

* working more than 35 hours
gen works_full_time = .
replace works_full_time = 0 if working_for_pay == 2
replace works_full_time = 0 if work_hours_per_week < 35
replace works_full_time = 1 if work_hours_per_week >= 35 & ~mi(work_hours_per_week)

* origin extreme poverty
gen origin_extreme_pov = (origin_poor_share2016 >= 0.4) if origin_poor_share2016!=.
		 
* keep relevant
keep treatment voucher_begin_date `outcome_list' `demo_list' `covars_table_1' hh_income
		
* scale outcomes
foreach var in `outcome_list' {
	replace `var' = 100 * `var'
}

* save base 
tempfile base
save `base'

* ------------------------------------------------------------------------------
* Table Calculations
* ------------------------------------------------------------------------------

foreach var in `covars_table_1' {
	gen mi_`var' = mi(`var')
	replace `var' = -9 if mi(`var')
}

* make empty variables to populate in loop
local row = 1
gen demo = ""	

* loop through outcomes
foreach outcome in `outcome_list' {

	* make empty variables to population below
	gen cm_`outcome'= .
	gen tm_`outcome'= .
	gen d_`outcome' = .
	gen se_`outcome' = .
	gen n_`outcome' = .
	gen pv_`outcome' = .
	
	* loop through demographics
	foreach demo in `demo_list' {
	di  "`demo'"	
		* label estimate
		replace demo = "`demo'" in `row'

		* calculate differences in treatment size and SE's
		if "`demo'" == "full_sample_contr" {
		reg `outcome' treatment `covars_table_1' mi_* if `demo' == 1, robust
		}
		else {
		reg `outcome' treatment pha_dummy if `demo' == 1, robust
		}
		
		*save results:
		replace d_`outcome' = _b[treatment] in `row'
		replace se_`outcome' =   _se[treatment] in `row'
		replace n_`outcome' =    e(N) in `row'
		replace pv_`outcome' =  2*normal(-abs( _b[treatment] / _se[treatment]))  in `row'
		
		*Save means
		sum `outcome' if treatment==0 &  `demo' == 1
		replace cm_`outcome'= `r(mean)' in `row'
		replace tm_`outcome'= cm_`outcome' + d_`outcome' in `row'

		* go to next row
		local row = `row' + 1
		
	}
}

* keep relevant variables:
collapse cm_* tm_* d_* se_* n_* pv_*, by(demo)
keep if ~mi(demo)

* gaps for formatting
forval i = 1/2 {
	gen gap`i' = .
}

* order
order demo *_cmto_uncond gap1 *_search_success gap2 


* order variables
gen order = .
local i=0
*Panel A
foreach demo of local demo_list {
local i =`i'+1
di "`demo'"
replace order = `i' if demo == "`demo'"
}

*assign names: 
replace demo = "All Families" if demo == "full_sample"
replace demo = "All Families (Controls)" if demo == "full_sample_contr"
replace demo = "Seattle Housing Authority" if demo == "sha"
replace demo = "King County Housing Authority" if demo == "kcha"
replace demo = "Black Non-Hispanic" if demo == "race_black"
replace demo = "White Non-Hispanic" if demo == "race_white"
replace demo = "Other Race/Ethnicity" if demo == "race_other"
replace demo = "Born Outside the U.S." if demo == "born_abroad"
replace demo = "Born in the U.S." if demo == "born_US"
replace demo = "English Isn't Primary Language" if demo == "english_not_primary"
replace demo = "English Is Primary Language" if demo == "english_primary"
replace demo = "20 years or more in Seattle/King County" if demo == "more_20_years_seattle"
replace demo = "Less than 20 years in Seattle/King County" if demo == "less_20_years_seattle"
replace demo = "Below Median Sample Income (< $19,000)" if demo == "lower_income"
replace demo = "Above Median Sample Income (> $19,000)" if demo == "higher_income"
replace demo = "Feels Good About Moving to an Opportunity Area" if demo == "feels_good_mto_nbhd"
replace demo = "Doesn't Feel Good About Moving to an Opportunity Area" if demo == "feels_nogood_mto_nbhd"
replace demo = "Satisfied With Current Neighborhood" if demo == "happy_with_nbhd"
replace demo = "Unsatisfied/Indifferent With Current Neighborhood" if demo == "unhappy_with_nbhd"
replace demo = "Sure Wants to Leave Current Neighborhood" if demo == "would_leave_nbhd"
replace demo = "Sure Wants to Stay in Current Neighborhood or Indifferent" if demo == "wouldnt_leave_nbhd"
replace demo = "Feels Good About Moving to Racially Different Neighborhood"  if demo == "happy_move_racial_diff"
replace demo = "Feels Bad/Indifferent About Moving to Racially Different Neighborhood"  if demo == "unhappy_move_racial_diff"
replace demo = "Sure Could Pay for Moving Expenses" if demo == "could_pay_move"
replace demo = "Not Sure Could Pay for a Moving Expenses" if demo == "couldnt_pay_move"
replace demo = "Sure Could Find a New Place" if demo == "could_find_new_place"
replace demo = "Not Sure Could Find a New Place" if demo == "couldnt_find_new_place"
replace demo = "Started in High Opportunity Tract" if demo == "origin_cmto"
replace demo = "Didn't Start in High Opportunity Tract" if demo == "origin_non_cmto"
replace demo = "No College" if demo == "no_coll"
replace demo = "Some College or More" if demo == "some_coll_or_more"
replace demo = "Currently Working" if demo == "working"
replace demo = "Currently Not Working" if demo == "not_working"
replace demo = "Uses Child Care" if demo == "uses_child_care"
replace demo = "Doesn't Use Childcare" if demo == "doesnt_use_child_care"
replace demo = "Mean Children Age Above Median (6 years)" if demo == "older_children"
replace demo = "Mean Children Age Below Median (6 years)" if demo == "younger_children"
replace demo = "More than 2 Children" if demo == "more_children"
replace demo = "2 Children or Less" if demo == "less_children"
replace demo = "Considering Different Schools" if demo == "consid_diff_school"
replace demo = "Not Considering Different Schools" if demo == "not_consid_diff_school"

sort order
drop order

* export
export delimited using "${tabs}/heterogenous_treatment_effects_dec2019", replace
