********************************************************************************
* Comparisons of service use by groups:
********************************************************************************

* file paths
global mis_clean 	"${cmto}/data/derived/MIS_dec2019"

*set service to graph
global services_contacts total_time_meetings ///
time_meet_per_mo_in_contact c_visit_locations c_marketability_coach c_neighborhood_tour c_search_assistance   

global services_landlord_info ref_landlord_any ref_landlord_interim 

global services_fin any_fin_amount screening_amount deposits_amount ////
any_fin_received screening_received deposits_received

foreach service_type in services_contacts services_landlord_info services_fin  {
foreach service of global `service_type' {

* ------------------------------------------------------------------------------
* Load and Merge Data
* ------------------------------------------------------------------------------

* load data
use "${phase1_der}/baseline_phas_dec2019", clear
keep if treatment==1 & eligible==1
keep oi_hh_id pha treatment search_success cmto_uncond cmto voucher_begin_date random_assign_date lease_begin_date

* restrict sample (if PHA specified, otherwise just pooled)
if "`pha'" != ""		keep if pha == "`pha'"

* merge in finantial assistance data
if "`service_type'" == "services_fin" {

	merge 1:m oi_hh_id using "${mis_clean}/financial_assistance_oi_cleaned_dec2019", ///
		keep(match master)
	
	*generate totals (any financial assistance)
	gen any_fin_received = 1 if _merge==3
	gen any_fin_times_rec = 1 if _merge==3 
	gen any_fin_amount = amount_received if _merge==3
	gen any_fin_amount_0 = amount_received if _merge==3
	gen any_fin_amount_m = (any_fin_amount==.)
	
	*generate indicators and means by type of financial assistance
	foreach type in screening deposits hold_fee rent_ins other {

	if "`type'" == "screening" local restrict "Screening Fees"
	if "`type'" == "deposits" local restrict "Deposits"
	if "`type'" == "hold_fee" local restrict "Holding Fee"
	if "`type'" == "rent_ins" local restrict "Renter's Insurance"
	if "`type'" == "other" local restrict "Other"

	gen `type'_received = 1 if _merge==3 & type=="`restrict'"
	gen `type'_times_rec = 1 if _merge==3 & type=="`restrict'"
	gen `type'_amount = amount_received if _merge==3 & type=="`restrict'"
	gen `type'_amount_0 = amount_received if _merge==3 & type=="`restrict'"
	gen `type'_amount_m = (`type'_amount==.)

	}
	
	*collapse at the household level:
	collapse (mean) *_m search_success cmto_uncond cmto voucher_begin_date lease_begin_date (rawsum) *_amount *_amount_0 *_times_rec (firstnm) pha *_received, by(oi_hh_id)

	fsum *_amount *_received
	tab1 *_m
	
	*set vars conditional or unconditional on receiving finantial assistance:
		if inlist("`service'", "any_fin_amount", "screening_amount", "deposits_amount", "hold_fee_amount", "rent_ins_amount", "other_amount") {
		replace `service' = . if `service'_m==1 | `service'==0
		}
		else if regexm("`service'", "received")==1 {
		local amount = regexr("`service'", "_received","")
		replace `service' = 0 if `service'==. | `amount'_amount==0
		}
		else {
		replace `service' = 0 if `service'==.
		}
		
	fsum *_amount *_received

}
* merge in Landlord Info data:
if "`service_type'" == "services_landlord_info" {

	preserve
	*load crosswalk from hhs to units:
	use "${mis_clean}/unit_landlord_household_cw_oi_cleaned_dec2019", clear
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

	merge 1:m oi_hh_id using `landords_w_hh', ///
		keep(match master)
	
	*generate indicators of referrals to landlords:
	gen ref_landlord_any = 1 if _merge==3
	gen ref_landlord_interim = 1 if _merge==3 & referral_source=="Interim"
	gen ref_landlord_hh = 1 if _merge==3 & referral_source=="Household"

	*collapse at the household level:
	collapse (mean) search_success cmto_uncond cmto voucher_begin_date lease_begin_date (firstnm) pha ref_landlord_any ref_landlord_interim ref_landlord_hh, by(oi_hh_id)
	
	*assign 0s if no referral:
	replace `service' = 0 if `service'==.
}
if "`service_type'" == "services_contacts" {
	* merge in contact data
	merge 1:m oi_hh_id using "${mis_clean}/participant_contact_oi_cleaned_dec2019", ///
		keep(match master) keepusing(contact_method who_initiated_contact meeting_length contact_successful ///
		contact_date contact_reason)
		
	tab contact_method

	*Instances of contact:
	gen contacts_total = 1 if _merge==3
	gen contacts_in_person = 1 if _merge==3 & contact_method=="In-person meeting"
	gen contacts_by_phone = 1 if _merge==3 & contact_method=="Phone call"
	gen contacts_other = 1 if _merge==3 & inlist(contact_method, "Email", "Mail (letter, post-card)", "Text")
	gen c_visit_locations = 1 if _merge==3 & regexm(contact_reason, "Visited housing unit")==1 
	gen c_marketability_coach = 1 if _merge==3 & regexm(contact_reason, "Marketability coaching")==1 
	gen c_neighborhood_tour = 1 if _merge==3 & regexm(contact_reason, "Neighborhood tour")==1
	gen c_search_assistance = 1 if _merge==3 & regexm(contact_reason, "Housing search assistance")==1

	*months in contact:
	*tab contact_date
	*gen date_of_contact = date(contact_date, "MDY")
	rename contact_date date_of_contact
	tab date_of_contact
	bys oi_hh_id: egen min_date_of_contact = min(date_of_contact)
	bys oi_hh_id: egen max_date_of_contact = max(date_of_contact)
	gen months_in_contact = (max_date_of_contact - min_date_of_contact + 1)/30.42

	* total_time_meetings
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
	
	*collapse at the hhs level:
	collapse (mean) months_in_contact search_success cmto_uncond cmto voucher_begin_date lease_begin_date ///
	(rawsum) total_time_meeting* contacts_* ///
	(firstnm) pha c_visit_locations c_marketability_coach c_neighborhood_tour c_search_assistance, by(oi_hh_id)

	gen contacts_per_month = contacts_total / months_in_contact
	gen time_meet_per_mo_in_contact = total_time_meetings / months_in_contact

	sum contacts_total contacts_per_month contacts_in_person contacts_by_phone contacts_other ///
	total_time_meetings time_meet_per_mo_in_contact c_visit_locations c_marketability_coach c_neighborhood_tour c_search_assistance 

	*assign 0s if no contact:
	replace `service' = 0 if `service'==.
}

* ----------------------------------------------------------------------------
* Collect Statistics:
* ----------------------------------------------------------------------------

	count if ~mi(`service')
	local N_`service' = r(N)
	sum `service'
	local m_`service' = r(mean)
	local s_`service' = r(sd)

	count if ~mi(`service') & search_success==1 & cmto==0 
	local nN_`service' = r(N)
	sum `service' if search_success==1 & cmto==0
	local nm_`service' = r(mean)
	local ns_`service' = r(sd)

	count if ~mi(`service') & search_success==1 & cmto==1
	local cN_`service' = r(N)
	sum `service' if search_success==1 & cmto==1
	local cm_`service' = r(mean)
	local cs_`service' = r(sd)

}
}

* ----------------------------------------------------------------------------
* Create Table
* ----------------------------------------------------------------------------

	clear 
	set obs 50

	gen var_name = ""

	gen N=.
	gen Mean_pooled=.
	gen SD_pooled=.

	gen N_non_mto=.
	gen Mean_non_mto=.
	gen SD_non_mto=.

	gen N_mto=.
	gen Mean_mto=.
	gen SD_mto=.

	local all_vars " "
	local i=1
	foreach service_type in services_contacts services_landlord_info services_fin {
	foreach service of global `service_type' {

	replace var_name = "`service'" if _n==`i'

	replace N = `N_`service'' if _n==`i'
	replace Mean_pooled = `m_`service'' if _n==`i'
	replace SD_pooled = `s_`service'' if _n==`i'

	replace N_non_mto = `nN_`service'' if _n==`i'
	replace Mean_non_mto = `nm_`service'' if _n==`i'
	replace SD_non_mto = `ns_`service'' if _n==`i'

	replace N_mto= `cN_`service'' if _n==`i'
	replace Mean_mto = `cm_`service'' if _n==`i'
	replace SD_mto = `cs_`service'' if _n==`i'

	local i=`i'+1
	}
	}
	
	gen order = .
	replace order = 1 if var_name=="total_time_meetings"
	replace order = 2 if var_name=="time_meet_per_mo_in_contact"
	replace order = 3 if var_name=="c_search_assistance"
	replace order = 4 if var_name=="c_marketability_coach"
	replace order = 5 if var_name=="c_neighborhood_tour"
	replace order = 6 if var_name=="c_visit_locations"
	replace order = 7 if var_name=="ref_landlord_any"
	replace order = 8 if var_name=="ref_landlord_interim"
	replace order = 9 if var_name=="any_fin_received"
	replace order = 10 if var_name=="any_fin_amount"
	replace order = 11 if var_name=="screening_received"
	replace order = 12 if var_name=="screening_amount"
	replace order = 13 if var_name=="deposits_received"
	replace order = 14 if var_name=="deposits_amount"
	
	sort order
	drop order
	drop if mi(var_name)
	
	preserve
	keep var_name N* Mean*
	gen gap1 = .
	gen gap2 = .
	
	order var_name N Mean_pooled gap1 N_non_mto Mean_non_mto gap2 N_mto Mean_mto
	
	export delimited "${tabs}/table_services_short_dec2019", replace 
	restore
	
	keep var_name Mean* SD*
	gen gap1 = .
	gen gap2 = .
	
	keep if inlist(var_name, "total_time_meetings", "ref_landlord_interim", "any_fin_received", "any_fin_amount")==1
	order var_name Mean_pooled SD_pooled gap1 Mean_non_mto SD_non_mto gap2 Mean_mto SD_mto
	
	export delimited "${tabs}/table_services_short_dec2019_slides", replace 
