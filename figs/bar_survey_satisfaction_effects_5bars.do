********************************************************************************
* Bar Graph of Full Neighborhood Satisfaction 
* Survey Responses by Treatment v. Control
********************************************************************************
	
* set outcome to graph:
foreach survey_q in satisfaction chance_stay {

* ------------------------------------------------------------------------------
* Load and Merge Data
* ------------------------------------------------------------------------------

	* load data for survey outcomes
	use "${phase1_der}/baseline_phas_dec2019" if eligible == 1, clear
	keep oi_hh_id treatment `survey_q' pha interview_date
	
	*include missings in plot. The variable interview date
	* is not missing if households were interviewed after lease-up. 
	replace `survey_q' =  0 if ~mi(interview_date) & mi(`survey_q')
	
	keep if ~mi(`survey_q') 
	
	* gen new variables for each answer of survey (0-5)
	forval answer = 0/5 {
		gen `survey_q'`answer' = `survey_q' == `answer'
	}

	* make pha dummy
	gen pha_dummy = pha == "KCHA"

	* calculate differences in treatment size and SE's for answer 5
	reg `survey_q'5 treatment pha_dummy, r
	local diff: dis %2.1fc _b[treatment] * 100
	local se: dis %2.1fc _se[treatment] * 100
	
	*ksmirnov `survey_q', by(treatment)
	tab `survey_q' treatment, chi2
	drop `survey_q'
	
	* collapse to get means for treatment v. control
	collapse (rawsum) `survey_q'*, by(treatment)

	* reshape
	reshape long `survey_q', i(treatment) j(answer)
	rename `survey_q' count
	label drop _all
	format answer %4.0f
	order count answer treatment
	
	* calculate percentages
	bysort treatment : egen tot_count = total(count)
	gen percent = count / tot_count * 100
	drop tot_count
	order answer treatment count percent

	* add percent labels
	gen percent_lab = string(percent, "%4.1f") + "%"
	gen count_lab = "n = " + string(count, "%1.0f")

* ------------------------------------------------------------------------------
* Graph
* ------------------------------------------------------------------------------

	* xaxis
	gen xaxis = .
	replace xaxis = answer - 0.2 if treatment == 0
	replace xaxis = answer + 0.2 if treatment == 1
	
	*shift up a bit scatter for labels: 
	gen  percent_shifted= percent + 1.2
	
	* satisfaction
	if "`survey_q'" == "satisfaction" {
		twoway ///
			(bar percent xaxis if treatment == 0, barwidth(0.4) color(gs12)) ///
			(bar percent xaxis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
			(scatter percent xaxis, mlabel(percent_lab) ///
				mcolor(none) mlabcolor(black) mlabpos(12)) ///
			(scatter percent_shifted xaxis, mlabel(count_lab) ///
				mcolor(none) mlabcolor(white) mlabsize(vsmall) mlabpos(6)) ///
			, ///
			legend(lab(1 "Control") lab(2 "Treatment") order(1 2) col(1) pos(11) ring(0)) ///
			ylab(0(20)60, nogrid) ///
			xlab(0 `" "No" "Answer" "' 1 `" "Very" "Dissatisfied" "' 2 `" "Somewhat" "Dissatisfied" "' ///
				 3 `" "Neither" "Satisfied nor" "Unsatisfied" "' ///
				 4 `" "Somewhat" "Satisfied" "' 5 `" "Very" "Satisfied" "') ///
			ytitle("Neighborhood Satisfaction") xtitle("") ${title} ///
			note("Difference in % Very Satisfied: {bf:`diff'pp}" "                                         SE: (`se')", size(*1.2))
			graph export "${figs}/bar_survey_`survey_q'_effect_dec2019.${img}", replace
	}
		
	* chance they will stay
	if "`survey_q'" == "chance_stay" {
	twoway ///
		(bar percent xaxis if treatment == 0, barwidth(0.4) color(gs12)) ///
		(bar percent xaxis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
		(scatter percent xaxis, mlabel(percent_lab) ///
			mcolor(none) mlabcolor(black) mlabpos(12)) ///
		(scatter percent_shifted xaxis, mlabel(count_lab) ///
			mcolor(none) mlabcolor(white) mlabsize(vsmall) mlabpos(6)) ///
		, ///
		legend(lab(1 "Control") lab(2 "Treatment") order (1 2) col(1) pos(11) ring(0)) ///
		ylab(0(20)60, nogrid) ///
		xlab(0 `" "No" "Answer" "' 1 `" "Very Sure" "Wants to" "Move" "' 2 `" "Somewhat" "Sure" "Wants to" "Move" "' ///
		 3 "In the Middle" ///
		 4 `" "Somewhat" "Sure" "Wants to" "Stay" "' 5 `" "Very Sure" "Wants to" "Stay""') ///
		ytitle("Certainty About Wanting to Stay or Leave") xtitle("") ${title} ///
		note("Difference in % Very Sure Want to Stay: {bf:`diff'pp}" "                                                         SE: (`se')", size(*1.2))
		graph export "${figs}/bar_survey_`survey_q'_effect_dec2019.${img}", replace
	}
}
