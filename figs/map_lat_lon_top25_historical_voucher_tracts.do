********************************************************************************
* Export Lat / Lon of Top 25 Most Common Voucher Tracts and Overlay in Atlas
********************************************************************************

*set how many to keep 
local top 25

*set if only kids:
local only_kids yes

* file paths
*Load historical data: 
use "${cmto_der}/historical_voucher_data", clear

*restrict to main voucher_type category (tenant_based)
tab1 vouchertype2015 vouchertype_col increment_category
keep if vouchertype2015=="MTW" | vouchertype_col=="General" | increment_category=="TENANT BASED"

*restrict to pre 2018 and households with kids:
keep if voucher_cohort<2018
keep if search_success==1 & ~mi(tract)
if "`only_kids'" == "yes" keep if num_kids>0 & num_kids!=.
tab1 vouchertype2015 vouchertype_col increment_category

*collapse to tract level:
gen count=1 
collapse (rawsum) count, by(tract)

*always in King County, WA
gen state=53
gen county=33

*Merge 2010 pop
rename (state county tract) (state10 county10 tract10)
merge m:1 state10 county10 tract10 using "${fg_covar}/covariates_tract_wide", ///
	 keep(master match) nogen keepusing(pop2010)
rename (state10 county10 tract10) (state county tract) 

*Compute moves per pop:
gen moves_per_pop = count / pop2010

gsort - moves_per_pop
gen top`top'_voucher = (_n<=`top')

keep if top`top'_voucher == 1

* merge to lat / lon of tract centroids:
merge 1:1 state county tract using "${lat_lon}/tract_lat_lon", keep(master match) nogen

* export
keep lat lon state county tract
export delimited "${map_inputs}/tract_top`top'_historical_voucher_tracts_kids", replace

keep lat lon 
export delimited "${map_inputs}/lat_lon_top`top'_historical_voucher_tracts_kids", replace

