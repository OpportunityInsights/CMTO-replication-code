********************************************************************************
* Correlation Matrix: Total Hours of Non-Profit Staff Time, Financial Assistance,
* Indicator for Whether Families Found Unit Through Landlord Referral
********************************************************************************

* load data
use "${phase1_der}/baseline_phas_dec2019", clear
keep if treatment==1 & eligible==1
keep oi_hh_id pha treatment search_success cmto_uncond cmto ///
	voucher_begin_date random_assign_date lease_begin_date

* merge in finantial assistance data
merge 1:m oi_hh_id using "${mis_clean}/financial_assistance_oi_cleaned_dec2019", ///
		keep(match master)
	
gen any_fin_received = 1 if _merge==3
gen any_fin_times_rec = 1 if _merge==3 
gen any_fin_amount = amount_received if _merge==3
gen any_fin_amount_0 = amount_received if _merge==3
gen any_fin_amount_m = (any_fin_amount==.)

collapse (mean) *_m search_success cmto  ///
	 (rawsum) *_amount   (firstnm) ///
	pha *_received, by(oi_hh_id)

*make it unconditional
replace any_fin_amount = 0 if any_fin_amount_m == 1 

sum any_fin_amount if cmto==1 & search_success == 1

* merge in contact data
merge 1:m oi_hh_id using "${mis_clean}/participant_contact_oi_cleaned_dec2019", ///
	keep(match master) keepusing(meeting_length who_initiated_contact)
	
* create quantitative variable for total time spent in meetings with cmto staff based on categorical survey question
gen total_time_meetings = .
replace total_time_meetings = 2.5 if meeting_length == "Less than 5 minutes"
replace total_time_meetings = 7.5 if meeting_length == "5-10 minutes"
replace total_time_meetings = 12.5 if meeting_length == "10-15 minutes"
replace total_time_meetings = 17.5 if meeting_length == "15-20 minutes"
replace total_time_meetings = 22.5 if meeting_length == "20-25 minutes"
replace total_time_meetings = 27.5 if meeting_length == "25-30 minutes"
replace total_time_meetings = 50 if meeting_length == "1 hour" // this is not a typo. 50 because there is no 30-60 option and histogram shows mass at 1 hour
replace total_time_meetings = 90 if meeting_length == "1-2 hours"
replace total_time_meetings = 150 if meeting_length == "More than 2 hours"
replace total_time_meetings = total_time_meetings / 60

replace total_time_meetings = . if who_initiated_contact=="PHA staff"

collapse (mean) *_m search_success cmto  ///
	(rawsum) total_time_meetings   (firstnm) *_amount ///
	pha *_received, by(oi_hh_id)

*make sure it's unconditional
replace total_time_meetings=0 if mi(total_time_meetings)==1

sum any_fin_amount if cmto==1 & search_success == 1

* merge in contact data
preserve
*load crosswalk from hhs to units: 
use "${mis_clean}/unit_landlord_household_cw_oi_cleaned_dec2019", clear
sum 
tempfile cross_walk
save `cross_walk'
*load landlord_info
use "${mis_clean}/landlord_information_oi_cleaned_dec2019.dta", clear
isid landlord_id
merge 1:m landlord_id using `cross_walk'
keep if _merge==3
tempfile landords_w_hh
drop _merge
save `landords_w_hh'
restore

* merge with landlord data
merge 1:m oi_hh_id using `landords_w_hh'  , ///
	keep(match master) 

* variable creation
gen ref_landlord_any = 1 if _merge==3
gen ref_landlord_interim = 1 if _merge==3 & referral_source=="Interim"
gen ref_landlord_hh = 1 if _merge==3 & referral_source=="Household"
gen ref_landlord_housinglocator = 1 if _merge==3 & /// 
	referral_source!="Household" & !mi(referral_source)
replace ref_landlord_housinglocator = 0 if mi(ref_landlord_housinglocator) ///
	& _merge==3 & !mi(referral_source)
replace ref_landlord_housinglocator = 0 if mi(referral_source)
sum ref_landlord_housinglocator
scalar frac_ref_hous_locators = `r(mean)'

* convert missings to zeros because collapse using "max" and "." = Inf
foreach variable in ref_landlord_any ref_landlord_interim ref_landlord_hh ///
ref_landlord_housinglocator {
	replace `variable' = 0 if mi(`variable')
}

* collapse back down to oi hh id level
collapse (mean) *_m search_success cmto (max) ref_landlord_* ///
	total_time_meetings (firstnm) *_amount, by(oi_hh_id)
		
sum any_fin_amount total_time_meetings ref_landlord_housinglocator if cmto==1 & search_success == 1

pwcorr total_time_meetings any_fin_amount ref_landlord_housinglocator if cmto==1 & search_success==1, sig
mat def Corrs=r(C)

clear 
svmat Corrs, names(col)

export excel using "${cmto}/tabs/service_correlations_dec2019.xlsx", firstrow(variables) replace
export delimited using "${tabs}/service_correlations_dec2019", replace

 
