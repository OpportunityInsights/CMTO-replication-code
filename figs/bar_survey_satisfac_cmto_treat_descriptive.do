********************************************************************************
* Bar Graphs: Satisfaction in Opportunity vs Non-Opportunity Areas
********************************************************************************
	
* set outcome to graph:
foreach survey_q in very_satisfied very_sure_stay very_satisfied_bl very_sure_stay_bl {

* ------------------------------------------------------------------------------
* Load and Merge Data
* ------------------------------------------------------------------------------

	* load data for survey outcomes
	use "${phase1_der}/baseline_phas_dec2019" if eligible == 1, clear
	keep oi_hh_id treatment very_* pha cmto cmto_2 lease_begin_date_2 interview_date ///
	nbhd_satisfaction nbhd_would_stay search_success

	*use the relevant cmto status at the date of interview:
	replace cmto=cmto_2 if interview_date>lease_begin_date_2
	
	*prepare baseline equivalent variables: 
	codebook nbhd_satisfaction nbhd_would_stay
	replace nbhd_satisfaction =. if nbhd_satisfaction==9
	replace nbhd_would_stay =. if nbhd_would_stay==9
	gen very_satisfied_bl = (nbhd_satisfaction == 1) if ~mi(nbhd_satisfaction)
	gen very_sure_stay_bl = (nbhd_would_stay == 1) if ~mi(nbhd_would_stay)
	
	*keep relevant obs:
	keep if ~mi(`survey_q') & search_success==1
	
	*compute diffs and ses:
	reg `survey_q' cmto if treatment==0
	local `survey_q'_diff0: dis %2.1fc _b[cmto] * 100
	local `survey_q'_se0: dis %2.1fc _se[cmto] * 100
	reg `survey_q' cmto if treatment==1
	local `survey_q'_diff1: dis %2.1fc _b[cmto] * 100
	local `survey_q'_se1: dis %2.1fc _se[cmto] * 100
	
	if "`scalar_mode'" == "on" {
	scalarout using "${scalars}/`file_name'.csv", id("`survey_q'_control_diff_mto") num(``survey_q'_diff0')
	}
	
	gen count=1
	
	* collapse to get means for treatment v. control
	collapse (rawsum) count  (mean) percent=`survey_q', by(treatment cmto)
	
	* reshape
	label drop _all
	order cmto treatment  
	
	* add percent labels
	replace percent=percent*100
	gen percent_lab = string(percent, "%4.1f") + "%"
	gen count_lab = "n = " + string(count, "%1.0f")
	
	*Diff labels:
	gen diff_lab = "Diff. = " + string(``survey_q'_diff1', "%4.1f") if treatment==1 & cmto==0
	replace diff_lab = "Diff. = " + string(``survey_q'_diff0', "%4.1f") if treatment==0  & cmto==0
	gen se_lab = "   (" + "``survey_q'_se1'" + ")" if treatment==1  & cmto==0
	replace se_lab = "   (" + "``survey_q'_se0'" + ")" if treatment==0  & cmto==0
	
	bysort treatment: egen mean_pos = mean(percent)
	replace mean_pos = mean_pos + 8
	gen new_mean_pos_below = mean_pos - 4
	
* ------------------------------------------------------------------------------
* Graph
* ------------------------------------------------------------------------------
	
	if "`survey_q'" == "very_satisfied" {
	local ylab "0(20)100"
	local ytitle `" "Percentage Very Satisfied" "with New Neighborhood" "'
	}
	if "`survey_q'" == "very_sure_stay" {
	local ylab "0(20)80"
	local ytitle `" "Percentage Very Sure They Will" "Stay in New Neighborhood" "'
	}
	if "`survey_q'" == "very_satisfied_bl" {
	local ylab "0(20)100"
	local ytitle `" "Percentage Very Satisfied" "with Neighborhood at Baseline" "'
	}
	if "`survey_q'" == "very_sure_stay_bl" {
	local ylab "0(20)80"
	local ytitle `" "Percentage Very Sure They Will" "Stay in Neighborhood at Baseline" "'
	}

	* xaxis
	gen xaxis = .
	replace xaxis = treatment - 0.22 if cmto == 0
	replace xaxis = treatment + 0.22 if cmto == 1
	gen xaxis_diff_lab = xaxis - 0.12
	gen se_x_position =  xaxis_diff_lab + 0.08
	
	if "`survey_q'" == "very_satisfied_bl" {
	replace xaxis_diff_lab = treatment
	replace se_x_position = treatment + 0.095
	replace mean_pos = 52
	replace new_mean_pos_below = 48
	}
	if "`survey_q'" == "very_sure_stay_bl" {
	replace xaxis_diff_lab = treatment
	replace se_x_position = treatment + 0.095
	replace mean_pos = 42
	replace new_mean_pos_below = 39
	}

		twoway ///
			(bar percent xaxis if treatment == 0, barwidth(0.4) color(gs12)) ///
			(bar percent xaxis if treatment == 1, barwidth(0.4) color("102 220 206")) ///
			(scatter percent xaxis, mlabel(percent_lab) ///
				mcolor(none) mlabcolor(black) mlabpos(12) mlabsize(*1.2)) ///
			(scatter percent xaxis, mlabel(count_lab) ///
				mcolor(none) mlabcolor(white) mlabsize(small) mlabpos(6)) ///
			(scatter mean_pos xaxis_diff_lab, ///
				mlabel(diff_lab) mcolor(none) mlabcolor(black) mlabpos(6) mlabsize(*1.2)) ///
			(scatter new_mean_pos_below se_x_position, ///
				mlabel(se_lab) mcolor(none) mlabcolor(black) mlabpos(6) mlabsize(*1.2)) ///
			, ///
			legend(lab(1 "Control") lab(2 "Treatment") ///
			size(medsmall) order(1 2) col(1) pos(2) ring(0)) ///
			ylab(`ylab', nogrid) ///
			xlab(-0.22 `" "Moved to" "Non-Opp. Area" "' ///
			0.22 `" "Moved to" "Opp. Area" "' ///
			0.78 `" "Moved to" "Non-Opp. Area" "' ///
			1.22 `" "Moved to" "Opp. Area" "', labsize(medsmall)) ///
			xsc(range(-0.5 1.5)) ///
			ytitle(`ytitle') xtitle("") ${title} 
			graph export "${manual_edits}/bar_`survey_q'_treat_cmto_dec2019.wmf", replace
		
}
