/*******************************************************************************
			METAFILE FOR CMTO PHASE 1 PAPER
********************************************************************************

This file runs all the figures and tables for 
Bergman, P., Chetty, R., DeLuca, S., Hendren, N., Katz, L. F., & Palmer, C. (2020)

	Note: due to privacy restrictions, accompanying data is not shared. 
	
*******************************************************************************/

* cmto file paths
global code 		"${github}/cmto"
global cmto 		"${dropbox}/outside/cmto"
global cmto_der 	"${cmto}/data/derived"
global crosswalks 	"${cmto}/data/crosswalks"
global phase1_der 	"${cmto}/data/derived/baseline_pha_dec2019"
global mis_clean 	"${cmto}/data/derived/MIS_dec2019"
global tiers 		"${cmto}/data/raw/tiers"
global outpath		"${cmto}/figs"
global tabs  		"${cmto}/tabs"
global scalars		"${cmto}/scalars"
global map_inputs 	"${cmto}/figs/map_inputs"
global manual_edits "${cmto}/figs/paper/manual_edits"

* Opportunity Atlas data file paths
global fg			"${dropbox}/outside/finer_geo"
global lat_lon		"${dropbox}/outside/finer_geo/data/raw/covariates/geovar"
global census		"${dropbox}/outside/finer_geo/data/raw/census/data_for_paper"
global forecasts    "${dropbox}/outside/finer_geo/data/derived/forecasts/seattle"
global fg_raw		"${dropbox}/outside/finer_geo/data/raw"
global fg_der		"${dropbox}/outside/finer_geo/data/derived"
global fg_covar		"${dropbox}/outside/finer_geo/data/derived/covariates"

* set the version of the figures (paper or slides)
global version paper

*set the file type (png, wmf, or pdf)
global img pdf

*set folder name for the output
global figs		 	"${outpath}/${version}/${img}"  	

* set scheme, font, and title size
if "${version}" == "slides" {
	set scheme leap_slides //opp_insights_policy leap_slides
	graph set window fontface default
	global title "title(" ", size(vhuge))"
}
else if "${version}" == "paper" {
    set scheme leap_slides
	graph set window fontface default
	global title "title("")"
}

/********************************************************************************
* Tables
********************************************************************************/

* 1. Summary Statistics
* ------------------------------------------------------------------------------
	
	*set: local whichtable to "fullbalance" inside do-file
	if "${version}" == "paper" 	 	include "${code}/tabs/baseline_balance.do" 
	if "${version}" == "slides"  	include "${code}/tabs/baseline_balance_abridged_slides.do"

* 2. Heterogeneous Treatment Effects
* ------------------------------------------------------------------------------

	include "${code}/tab_heterogeneous_treatment_effects.do"

* 3. Costs
* ------------------------------------------------------------------------------
	
	*Refer to Appendix B in the paper. 
	
* 4. DD Hist Reforms
* ------------------------------------------------------------------------------

	include "${code}/tabs/tab_DD_KCHA_SHA_reforms.do" 

/********************************************************************************
* Appendix Tables
********************************************************************************/
	
* App Table 1. Cost Comparisons
* ------------------------------------------------------------------------------
	
	*From other papers +  Our cost table (Table 3). 

* App Table 2. Qualitative Study Sampling and Response Rates
* ------------------------------------------------------------------------------
	
	 *From Stefanie DeLuca's team. 
	 
* App Table 3. Qualitative Study Sample vs Rest of Sample
* ------------------------------------------------------------------------------
	
	*set: local whichtable to "fullbalancequal" inside do-file
	include "${code}/tabs/baseline_balance.do"

* App Table 4. Treatment vs Control Among Qualitative Sample
* ------------------------------------------------------------------------------
	
	*set: local whichtable to "compquanttoqual" inside do-file
	include "${code}/tabs/baseline_balance.do"

* App Table 5. Lifetime Earnings Impact
* ------------------------------------------------------------------------------
	
	include "${code}/tabs/lifetime_earnings_impact.do"

* App Table 6. Lease-up Heterogeneity
* ------------------------------------------------------------------------------
	
	*Already produced by: include "${code}/tabs/tab_heterogeneous_treatment_effects.do"

* App Table 7. Treatment Effects on Neighborhood and Housing Unit Characteristics
* ------------------------------------------------------------------------------
	
	include "${code}/tabs/table_treatment_effects_house_characteristics_uc.do"

* App Table 8. Neighborhood Characteristics of High vs. Low Opportunity Areas
* ------------------------------------------------------------------------------
	
	include "${code}/tabs/table_nbhd_characteristics_high_low_opp.do"

* App Table 9. Intervention Dosage: Treated Households' Usage of CMTO Services
* ------------------------------------------------------------------------------
	
	*Panels A, B, and C:
	include "${code}/tabs/service_usage_short.do"
	
	*Panel D: 
	include "${code}/tabs/corr_services.do"

* App Table 10. Variable Sources
* ------------------------------------------------------------------------------
	
	*Manually in excel file. 

********************************************************************************
* Set-Up Figure Scalarout File
********************************************************************************

* set file name
clear 
clear matrix
clear mata
local file_name		cmto_figure_scalarout_dec2019
set maxvar 100000

* create spacing for headers
local header 		"."
local scalar_mode   "on"

* replace old scalarout file with a new one
cap erase 			"${scalars}/`file_name'.csv"

********************************************************************************
* Main Figures
********************************************************************************

* create scalarout header
scalarout using "${scalars}/`file_name'.csv", id("Main Figures") num(`header')

* 1. Opportunity Bargains in Seattle
* ------------------------------------------------------------------------------

* A. Map Top Voucher 25 Most Common Vouchers

	include "${code}/figs/map_lat_lon_top25_historical_voucher_tracts.do"  
	*+ Manually prepared in ArcGIS + Screenshot + PPP manual edits
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\cmto_top25_locations_vouchers_historical"
	* Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

* B. Scatter KFR p25 on Rent (Opp Bargain)

	include "${code}/figs/scatter_kfr_rent_oppbarg.do" 

* 2. Comparing Opp Measures (Atlas v. Kirwan)
* ------------------------------------------------------------------------------

* A. CMTO Opportunity Areas

	*Manually prepared in ArcGIS + Screenshot + PPP manual edits:
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\cmto_destinations_pins_dec2019_acrgis_pro"
	* Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

*B. Kirwin and KFR

	include "${code}/figs/map_kfr_kirwan_forecast.do"
	*+ Manually prepared in ArcGIS + Screenshot + PPP manual edits:
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\cmto_top25_locations_vouchers_historical"
    * Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

* 3. Treatment intervention and Family Experience Process Flow
* ------------------------------------------------------------------------------

* A and B.:

	* Mostly text and images from Manual edits PPP.
	* Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"
	* Stats from cost table (Table 3). 


* 4.  CMTO Treatment Effects
* ------------------------------------------------------------------------------
	
*All panels: 

	include "${code}/figs/bar_mto_effects.do" 

* 5.  Map of Destination Tracts for Voucher Recepients
* ------------------------------------------------------------------------------

	include "${code}/figs/map_lat_lon_orig_dest_by_household.do" 
	*+ Manually prepared in ArcGIS + Screenshot + PPP manual edits:
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\cmto_destinations_pins_dec2019_acrgis_pro"
    * Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

* 6. Distribution of Tract-Level Upward Mobility in Destinations
* ------------------------------------------------------------------------------

	include "${code}/figs/kdensity_destination_kfr.do"

* 7. Heterogeneity in Treatment Effects
* ------------------------------------------------------------------------------

* A and B.:

	include "${code}/figs/bar_mto_hetergeneous_effects.do" 

* 8. Treatment Effects on Neighborhood and Unit Characteristics
* ------------------------------------------------------------------------------

*All panels: 
	*Already produced by: "${code}/figs/bar_mto_effects.do" 
	
* 9. Persistence of Treatment Effects on Neighborhood Choice
* ------------------------------------------------------------------------------
	
* A. :

	include "${code}/figs/bar_4bars_mto_effects_persistence.do" 

* B. :

	*Already produced by: "${code}/figs/bar_mto_effects.do" 

* 10. Treatment Effects on Post-Move Neighborhood Satisfaction
* ------------------------------------------------------------------------------

	*Already produced by: "${code}/figs/bar_mto_effects.do" 

* 11. Neighborhood Satisfaction in Low vs. High-Opportunity Areas
* ------------------------------------------------------------------------------
	
	include "${code}/figs/bar_survey_satisfac_cmto_treat_descriptive.do" 

* 12. Distribution of Preferences (CDF) for High Opp Neighborhoods
* ------------------------------------------------------------------------------

	include "${code}/figs/wtp_cdf_treat_plots.do" 

* 11. Effects of Vouhcer Payment Standard Changes 
* ------------------------------------------------------------------------------

* A. Effect of KCHA 5-Tier Reform on Share Moving to Opp:
	
	include "${code}/figs/connected_diff_in_diff_KCHA_2016.do" 
	
* B. Effect of SHA Family Access Supplement on Share Moving to Opp:
	
	include "${code}/figs/connected_diff_in_diff_FAS_and_Pilot_SHA_2018.do" 

********************************************************************************
* Appendix Figures
********************************************************************************

* create scalarout header:
scalarout using "${scalars}/`file_name'.csv", id("Appendix Figures") num(`header')

* App Fig 1. Hockey Sticks Around the World (Manual Edit)
* ------------------------------------------------------------------------------

	* Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

* App Fig 2. Preliminary and Final Versions of Opportunity Atlas 
* ------------------------------------------------------------------------------

	include "${code}/figs/map_kfr_kirwan_forecast.do"
	*+ Manually prepared in ArcGIS + Screenshot + PPP manual edits:
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\cmto_top25_locations_vouchers_historical"
    * Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

*App Fig 3. Map of Origin Tracts for Voucher Recepients
* ------------------------------------------------------------------------------

	include "${code}/figs/map_lat_lon_orig_dest_by_household.do" 
	*+ Manually prepared in ArcGIS + Screenshot + PPP manual edits:
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\cmto_destinations_pins_dec2019_acrgis_pro"
    * Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

*App Fig 4. Predicted Treatment Effects on Other Long-Term Outcomes
* ------------------------------------------------------------------------------
		
	*Already produced by: "${code}/figs/bar_mto_effects.do" 

*App Fig 5. Unconditional Short-Run Persistence of Treatment Effects on Neighborhood Choice
* ------------------------------------------------------------------------------
	
	*Already produced by: "${code}/figs/bar_4bars_mto_effects_persistence.do" 

*App Fig 6. Post-Move Survey All Answers
* ------------------------------------------------------------------------------

	include "${code}/figs/bar_survey_satisfaction_effects_5bars.do" 

*App Fig 7.  King County Housing Authority Payment Zones
* ------------------------------------------------------------------------------

	include "${code}/figs/map_kcha_tier_reform_prepare_data.do"
	*+ Manually prepared in ArcGIS + Screenshot + PPP manual edits:
	* ArcGIs Pro file: "${dropbox}\outside\cmto\code\arcgis\maps_difference_tiers.mxd"
    * Manual edits PPP: "${dropbox}\outside\cmto\figs\Figure Manual Edits dec 2019.pptx"

