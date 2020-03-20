********************************************************************************
* Plot Heterogeneous Effect by Income and Race
********************************************************************************

* set outcomes
local outcome 		cmto_uncond

* set demographic variable
local demo_vars three_racial_groups higher_income

* ------------------------------------------------------------------------------
* Load and Merge Data
* ------------------------------------------------------------------------------

* load data
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1, clear

* restrict sample (if PHA specified, otherwise just pooled)
if "`pha'" != ""		keep if pha == "`pha'"

*generate PHA dummy
gen pha_dummy=1 if pha=="KCHA"
replace pha_dummy=0 if pha=="SHA"

* income binary
summ hh_income, d
local med = `r(p50)'
local med_income : di %6.0fc `r(p50)'
gen higher_income = hh_income > `med' if ~mi(hh_income)

* three racial groups: 
gen race_black = 1 if race_ethnicity=="African American/Black"
replace race_black= 0 if race_ethnicity!="African American/Black" & ~mi(race_ethnicity)
gen race_white = 1 if race_ethnicity=="White"
replace race_white= 0 if race_ethnicity!="White" & ~mi(race_ethnicity)
gen three_racial_groups = .
replace three_racial_groups = 0 if race_black == 1 // 0 is black
replace three_racial_groups = 1 if race_white == 1 // 1 is white
replace three_racial_groups = 2 if race_white != 1 & race_black != 1 & !mi(race_ethnicity) // 2 is other

* save base 
tempfile base
save `base'

* loop through variables
foreach demo in `demo_vars' {

* ------------------------------------------------------------------------------
* Calculate Effects by Group and Differences, Collapse Data to Treatment / Control Means & SE's
* ------------------------------------------------------------------------------

* re-load data
use `base' if ~mi(`demo'), clear

* scale variable by 100
replace `outcome' = 100 * `outcome'

* calculate treatment effects and SEs
reg `outcome' treatment pha_dummy if `demo' == 0, r
local `outcome'_dif0: dis %4.1fc _b[treatment]
local `outcome'_se0: dis %2.1fc _se[treatment]
reg `outcome' treatment pha_dummy if `demo' == 1 , r
local `outcome'_dif1: dis %4.1fc _b[treatment]
local `outcome'_se1: dis %2.1fc _se[treatment]

if "`demo'" == "three_racial_groups" {
	reg `outcome' treatment pha_dummy if `demo' == 2, r
	local `outcome'_dif2: dis %4.1fc _b[treatment]
	local `outcome'_se2: dis %2.1fc _se[treatment]
}
di "``outcome'_dif2'" 

* collapse to get means for treatment v. control in each group
drop if `demo'==.
gen count = 1 if `outcome'!=.
collapse (rawsum) count (mean) `outcome', by(treatment `demo')

*Given that we control for PHA, we want to plot the bar of 
*the treatment group as control group mean plus effect:
xtset `demo' treatment

levelsof `demo', local(demo_levels)
foreach level of local demo_levels {
replace `outcome' =  l.`outcome' + ``outcome'_dif`level'' if treatment==1 & `demo'==`level'
}

gen se_lab = "   (" + "``outcome'_se0'" + ")" if treatment==0 & `demo'==0
replace se_lab = "   (" + "``outcome'_se1'" + ")"  if treatment==0 & `demo'==1
replace se_lab = "   (" + "``outcome'_se2'" + ")"  if treatment==0 & `demo'==2

if "`demo'" == "working" {
replace se_lab = " (SE: " + string(``outcome'_se0') + ")"  if treatment==0 & `demo'==0
replace se_lab = " (SE: " + string(``outcome'_se1') + ")"  if treatment==0 & `demo'==1
}

* create labels for bar chart
gen lab_`outcome' = string(`outcome', "%2.1fc") 
replace lab_`outcome' = "{bf:" + lab_`outcome' + "%" + "}" 

* ------------------------------------------------------------------------------
* Graph Control v. Treatment
* ------------------------------------------------------------------------------

* graph settings
if "`outcome'" == "cmto_uncond" {
	local ylab "0(10)70"
	local ytitle `" "Percent of Households Who Moved" "to High Opportunity Areas" "'
}
if "`demo'" == "higher_income" {	
	local xlab `" 0 `" "Control Treatment" "Income < $`med_income'" "' 1 `" "Control Treatment" "Income > $`med_income'" "' "'
}
if "`demo'" == "three_racial_groups" {
		local xlab `" 0 "Black Non-Hispanic" 1 "White Non-Hispanic" 2 "Other Race/Ethnicity" "'
		local ylab "0(20)80"
}

* gen xaxis
gen x_axis = .
replace x_axis = `demo' - 0.2 if treatment == 0
replace x_axis = `demo' + 0.2 if treatment == 1

* calculate difference
preserve 
	replace `outcome' = -1 * `outcome' if treatment == 0
	collapse (rawsum) `outcome', by(`demo')
	rename `outcome' diff
	tempfile diff
	save `diff'
restore
merge m:1 `demo' using `diff', nogen

* make labels
gen diff_lab = "Diff. = " + string(diff, "%4.1f") // + " pp"
gen count_lab = "n = " + string(count, "%4.0f")

* calculate means for position
bysort `demo' : egen mean_pos = mean(`outcome')
*shift a little down: 
gen mean_pos_below = mean_pos - 4

*set position of legend
local pos = 2

* set local for range of x-axis
if "`demo'" == "three_racial_groups" {
local range_high = 2.5
}
else{
local range_high = 1.5
}



* graph pooled
if "`demo'" == "three_racial_groups" {
gen se_x_position = x_axis +.1
}
else{
gen se_x_position = x_axis + .07
}
gen new_mean_pos_below = mean_pos_below + 1

if "`demo'" == "higher_income" {
twoway ///
	(bar `outcome' x_axis if treatment == 0, barwidth(0.4) color(gs12)) ///
	(bar `outcome' x_axis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
	(scatter mean_pos x_axis if treatment == 0, ///
		mlabel(diff_lab) mcolor(none) mlabcolor(black) mlabpos(6)) ///
	(scatter new_mean_pos_below se_x_position if treatment == 0, ///
		mlabel(se_lab) mcolor(none) mlabcolor(black) mlabpos(6)) ///
	(scatter `outcome' x_axis, ///
		mlabel(lab_`outcome') mcolor(none) mlabs(*1.1) mlabcolor(black) mlabpos(12)) ///
		, ///
		legend(off) ///
		xlab(`xlab') ///
		${title} ///
		xtitle("") ///
		ylab(`ylab', nogrid) ///
		xsc(range(-0.5 `range_high')) ///
		ytitle(`ytitle') ///
		name("`outcome'_`demo'", replace) ///
		xlabel(-.2 "Control" 0 `" " " "Income < $`med_income'" "' .2 "Treatment" 0.8 "Control" 1 `" " " "Income > $`med_income'" "' 1.2 "Treatment", noticks) xtick(-.2 .2 .8 1.2)
		
		graph export "${manual_edits}/bar_heterog_`outcome'_`demo'_dec2019.wmf", replace
}
else {
twoway ///
	(bar `outcome' x_axis if treatment == 0, barwidth(0.4) color(gs12)) ///
	(bar `outcome' x_axis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
	/*(rcap ci_upper ci_lower x_axis if treatment ==1, color(black))*/ ///
	(scatter mean_pos x_axis if treatment == 0, ///
		mlabel(diff_lab) mcolor(none) mlabcolor(black) mlabpos(6)) ///
	(scatter new_mean_pos_below se_x_position if treatment == 0, ///
		mlabel(se_lab) mcolor(none) mlabcolor(black) mlabpos(6)) ///
	(scatter `outcome' x_axis, ///
		mlabel(lab_`outcome') mcolor(none) mlabs(*1.1) mlabcolor(black) mlabpos(12)) ///
		, ///
		legend(off) ///
		xlab(`xlab') ///
		${title} ///
		xtitle("") ///
		ylab(`ylab', nogrid) ///
		xsc(range(-0.5 `range_high')) ///
		ytitle(`ytitle') ///
		name("`outcome'_`demo'", replace) ///
		xlabel(-.2  "Control"  0.03  `" " " "Black Non-Hispanic" "' .2 "Treatment" 0.8 "Control" 1.03 `" " " "White Non-Hispanic" "' 1.2 "Treatment"1.8 "Control" 2.03 `" " " "Other Race/Ethnicity" "' 2.2 "Treatment", noticks) xtick(-.2 .2 .8 1.2 1.8 2.2)

if "`demo'" == "three_racial_groups" graph export "${manual_edits}/bar_heterog_`outcome'_`demo'_dec2019.wmf", replace
}
}
