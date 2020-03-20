********************************************************************************
* Create Data that Will be Input for Maps in ArcGIS
********************************************************************************

* load data
use state county tract kfr_pooled_pooled_p25 ///
	using "${census}/tract_race_gender_early_dp", clear

* merge to census covariates
rename (state county tract) (state10 county10 tract10)
merge 1:1 state10 county10 tract10 using "${fg_covar}/covariates_tract_wide", nogen ///
	keepusing(poor_share2000 pop2000)
rename (state10 county10 tract10) (state county tract) 
gen nonpoor_share2000 = 1 - poor_share2000
	
* merge to Kirwan index
merge 1:1 state county tract using ///
	"${fg_covar}/kirwan_opp_index/kirwan_100cities", nogen ///
	keepusing(allcomp)

* merge to neighborhood deprivation index
merge 1:1 state county tract using "${fg_der}/neighborhood atlas", nogen ///
	keepusing(adi_natrank)
replace adi_natrank = round(adi_natrank)
replace adi_natrank = 101 - adi_natrank 
	
* merge in HUD indices
merge 1:1 state county tract using ///
	"${fg_covar}/hud_affht_opp_indices/hud_affht_opp_indices", nogen

*merge original Atlas forecast: 
* merge to forecasts
merge 1:1 state county tract using "${forecasts}/irs_kravg30", nogen ///
	keepusing(forecast_2000_irs) keep(master match)
	rename forecast_2000_irs forecast_kravg30_p25
* merge in forecast (without test scores)
merge 1:1 state county tract using "${forecasts}/irs_kravg30_no_test_score", nogen ///
	keepusing(forecast_2000_irs) keep(master match)
	rename forecast_2000_irs forecast_kravg30_p25_notest
* use non-test score forecast if test-score forecast is missing
replace forecast_kravg30_p25 = forecast_kravg30_p25_notest ///
	if mi(forecast_kravg30_p25)
drop forecast_kravg30_p25_notest

* rename outcome names
rename kfr_pooled_pooled_p25	kfr_p25
rename allcomp					kirwan
rename adi_natrank				adi
rename forecast_kravg30_p25		forecast

*restrict to King County:
keep if state == 53 & county == 33

*compute correlations cited in paper and shown on figures: 

corr kfr_p25 kirwan [weight = pop2000]
local kirwancorr : di %4.2f `r(rho)'
di "`kirwancorr'"
if "`scalar_mode'"=="on" {
scalarout using "${scalars}/`file_name'.csv", ///
	id("corr_kfr_kirwan") num(`kirwancorr')
}
corr kfr_p25 forecast [weight = pop2000]
local forecastcorr : di %4.2f `r(rho)'
di "`forecastcorr'"
if "`scalar_mode'"=="on" {
scalarout using "${scalars}/`file_name'.csv", ///
	id("corr_forecast_kfr") num(`forecastcorr')
}

*Export data for ArcGIS:
keep state county tract kfr_p25 kirwan adi forecast
* map data in seattle 
export delimited "${map_inputs}/tract_kfr_kirwan_adi_forecast", replace