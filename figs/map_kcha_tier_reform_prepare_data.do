********************************************************************************
* Prepare data for map of change in rental assistance
* in KCHA's voucher reform in 2016
********************************************************************************

* file paths
global cmto			"${dropbox}/outside/cmto"
global raw			"${cmto}/data/raw"
global cw 			"${cmto}/data/crosswalks"

*restrict to 2 bedroom tiers

* 5 tier system:
import excel using "${cw}/vps_KCHA_five_tier.xlsx", clear firstr

rename vps vps_2016
keep if bed==2
export delimited "${raw}/tiers/vps_KCHA_five_tier_2br.csv", replace

*two tier system:		
import excel using "${cw}/vps_KCHA_two_tier.xlsx", clear firstr
	
rename vps vps_2014
keep if bed==2

export delimited "${raw}/tiers/vps_KCHA_two_tier_2br.csv", replace
