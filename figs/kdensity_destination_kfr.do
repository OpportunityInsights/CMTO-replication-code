****************************************************************
** Kernel density plot of upward mobility in destination      **
** for treatment and control groups.                          **
****************************************************************

*define outcome (kfr_pooled_pooled_p25 or forecast_kravg30_p25):
local out kfr_pooled_pooled_p25

use "${phase1_der}/baseline_phas_dec2019" ///
    if eligible == 1 & drop_short_run!=1, clear

*scale percentiles to go from 0 to 100
replace `out' = `out'*100

if "`out'"=="forecast_kravg30_p25" local xtitle "Forecasted Upward Mobility (Predicted Income Rank in Adulthood of Child with Parents at 25th Percentile) in Destination Tract"
if "`out'"=="kfr_pooled_pooled_p25" local xtitle ""Upward Mobility (Predicted Income Rank in Adulthood of Child with" "Parents at 25th Percentile) in Destination Tract""

local pos 11
local xlab "40(5)55"
local ylab "0(0.02)0.10"

*Plot distribution of kfr in treatment vs control group
twoway (kdensity `out' if treat==0, color(gs8)) ///
(kdensity `out' if treat==1, color("102 220 206")) ///
, ///
legend(label(1 "Control") label(2 "Treatment") textw(*0.7) symx(*0.7) ring(0) pos(11) col(1)) ///
 ytitle("Density") $title ylab(`ylab', nogrid format(%03.2f)) ///
 xtitle(`xtitle')  ysc(range(0.11))
 
graph export "${figs}\kden_dist_by_treatment_`out'_dec2019.${img}", replace

