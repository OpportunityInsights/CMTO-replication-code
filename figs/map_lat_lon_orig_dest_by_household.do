********************************************************************************
* Map Tract Centroids of Leases (Treatment v. Control)
* as Well as Tract Centroids of Origin Locations
********************************************************************************

* set pha
foreach pha in SHA KCHA {

set seed 8643

* load data
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1 & ~mi(tract), clear
keep if pha == "`pha'"

*merge lat lons of tract centroids:
keep if ~mi(tract)
keep state county tract treatment oi_hh_id treatment
merge m:1 state county tract using "${lat_lon}/tract_lat_lon", keep(match) nogen

* origin tracts
rename lat dest_lat
rename lon dest_lon

* infuse some noise to avoid pin bunching
* and for some privacy protection:
gen noise1 = a*runiform(x,y)
gen noise2 = b*runiform(x,y)
gen noise3 = c*runiform(x,y)

gen dest_lat_r = dest_lat + noise1 if treatment==1
replace  dest_lat_r = dest_lat + noise2 if treatment==0
gen dest_lon_r = dest_lon + noise3

keep if state==53 & county==33

* save origination
keep *lat* *lon*  state county tract oi_hh_id treatment
tempfile dest
save `dest'

export delimited using "${map_inputs}/arcmap_lat_lon_dest_hh_`pha'_dec2019", replace

*Use corrected but not updated data for origin
* ------------------------------------------------------------------------------
* Export CMTO Origin Lat Lon
* ------------------------------------------------------------------------------

* load data
use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1 & ~mi(origin_tract), clear
keep if pha == "`pha'"

*keep origin tracts only:
keep origin_state origin_county origin_tract treatment oi_hh_id
rename origin_tract tract
rename origin_county county
rename origin_state state

*merge lat lons of tract centroids:
merge m:1 state county tract using "${lat_lon}/tract_lat_lon", keep(match) nogen
rename tract origin_tract 
rename county origin_county 
rename state origin_state 

keep if origin_state==53 & origin_county==33

* origin tracts
rename lat orig_lat
rename lon orig_lon

* infuse some noise to avoid pin bunching
* and for some privacy protection:
gen noise1 = a*runiform(x,y)
gen noise2 = b*runiform(x,y)
gen noise3 = c*runiform(x,y)

gen orig_lat_r = orig_lat + noise1 if treatment==1
replace  orig_lat_r = orig_lat + noise2 if treatment==0
gen orig_lon_r = orig_lon + noise3

keep *lat* *lon* origin_* oi_hh_id treatment
tempfile orig
save `orig'

export delimited using "${map_inputs}/arcmap_lat_lon_orig_hh_`pha'_dec2019", replace

}
