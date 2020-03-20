********************************************************************************
** Differences in differences estimates of effect of KCHA 2016 voucher reform **
********************************************************************************

clear all
set maxvar 25000

*Load data
use "${cmto_der}/historical_voucher_data", clear

*************************************************
*** Generate treatment and pre-post indicators  **
*************************************************

gen treated_KCHA = 1 if pha == "KCHA"
replace treated_KCHA = 0 if pha == "SHA"

*date of update in plot:
global update_dates  march2016
*                      KCHA        

foreach date of global update_dates {
	* Generate pre, post indicator KCHA update 1:
	gen post_`date' = (voucher_issue_date >= td(1`date'))
	*Interactions
	gen interaction_`date' = treated_KCHA * post_`date'
}


*restrict to period where we want to show graph:
drop if voucher_issue_date < td(1july2015) | voucher_issue_date >= td(1nov2016)

*restrict to families with kids
keep if num_kids > 0
	
******************************************************************************
*** Diff in Diff (graph + point estimate) for KCHA update 2016 + fake CMTO ***
******************************************************************************

foreach outcome in uncond_opportunity_area {
		
		preserve 
				
		if "`outcome'" == "uncond_opportunity_area" {
			replace `outcome' = `outcome' * 100
			local extend_y 31 6
			local ytitle `" "Percent of Households Who Moved" "to High Opportunity Areas" "'
			local ylab "0(10)70"
			local cmto_delta 37.9
			local pos 11
			local text_pos 70
		}

		*point estimates:
		reg `outcome' treated_KCHA interaction_march2016 post_march2016, r
		local beta: dis %5.2f _b[interaction_march2016]
		local se: dis %4.2f _se[interaction_march2016]
		
		local upper_bound: dis %2.1fc _b[interaction_march2016] + _se[interaction_march2016]*1.96
		di "`upper_bound'"
		if "`scalar_mode'" == "on" {
		scalarout using "${scalars}/`file_name'.csv", id("upper_bound_DD_KCHA") num(`upper_bound')
		scalarout using "${scalars}/`file_name'.csv", id("effect_DD_KCHA") num(`beta')
		scalarout using "${scalars}/`file_name'.csv", id("se_DD_KCHA") num(`se')
		}

		collapse (mean) `outcome', by(bimester_issued pha)

		*format bin_var for x label
		format bimester_issued %tmMonCCYY

		*Line of treatment
		local cut = mofd(td(1march2016))

		*Manually insert delta of CMTO in KCHA
		gen `outcome'_fake = `outcome'
		replace `outcome'_fake = `outcome' + `cmto_delta' if bimester_issued > `cut' & pha == "KCHA"


		twoway (connected `outcome' bimester_issued if pha=="KCHA", color("102 220 206") lwidth(*1.3)) ///
		(connected `outcome' bimester_issued if pha=="SHA", color(gs11) lwidth(*1.3)) ///
		 (line `outcome'_fake bimester_issued if pha=="KCHA" & bimester_issued >= 673 , color("102 220 206") lwidth(*1.3) lpattern(dash)), ///
		legend(off) /// 
		legend(order(1 2) label(1 "KCHA") label(2 "SHA") ring(0) pos(`pos') col(1) size(*0.9) symxs(*0.6) symys(*0.8)) ///
		xline(`cut', lcolor(gs8) lpattern(dash)) name(`outcome'_graph, replace) ///
		xtitle(" " "Date of Voucher Issuance") ///
		note("Effect of 5-Tier Reform: `beta' ranks" "                                      (`se')") ///
		ytitle(`ytitle') ///
		xscale(range(666 683)) ylab(`ylab', nogrid angle(vertical)) ///
		yscale(range(`extend_y')) ///
		text(`text_pos' 676 "5 Tier Reform" "in KCHA", color(black) j(left)) ///
		xlab(667 `" "Aug/Sep" "2015" "' 669 `" "Oct/Nov" "2015" "' 671 `" "Dec/Jan" "2015/16" "' ///
		673 `" "Feb/Mar" "2016" "' 675 `" "Apr/May" "2016" "' 677 `" "Jun/Jul" "2016" "' 679 ///
		`" "Aug/Sep" "2016" "' 681 `" "Oct/Nov" "2016" "' , labsize(*0.8)) ${title}
		
		graph export "${manual_edits}/DD_`outcome'_bimester_issued_KCHA_2016_fake_kids_dec2019.wmf", replace
		
		restore
		
		}

