*******************************************************************************
* Implications for Models of Neighborhood Choice
********************************************************************************

* define locals
local treatmenteffect=.431  //Figure 4c
local treatmentmean=.607 //Figure 4c
local controlmean=`treatmentmean'-`treatmenteffect'
local cost=2700 //Table 3 (exact number is 2660, rounded to nearest 100 to show in plot

* do some math

* perform NLS to estimate parameters of normal distribution based on two moments F(cost) and F(0)
clear
set obs 2
gen x=0
replace x=`cost' in 2
gen y=`treatmentmean'-`treatmenteffect'
replace y=`treatmentmean' in 2
nl (y=normal((x-{mu=1000})/{sigma=5000}))
mat theta=e(b)
local mu=theta[1,1]
local sigma=theta[1,2]
di `mu'
di `sigma'

clear
local mu_wide=-5000 //designed by fsolve(@(x) normcdf(0,x,15000)-.176) hypothetical wide distribution
set obs 1000
gen wtp=`mu_wide'-50000+_n*100000/1000
gen CDF=normal((wtp-`mu')/`sigma') //draw CDF implied by those two moments
keep if inrange(wtp,-40000,40000) //shrink scale to be a little more manageable

replace CDF = CDF * 100

local wtpfornonopp = `treatmentmean' * 100
local wtpfornonopp_0 = `controlmean' * 100
local averse = `controlmean'*100
di `CDF'

*Create Graph:

twoway  (line CDF wtp if wtp > 0 & wtp < `cost', pstyle(p2)) ///
	(line CDF wtp if wtp < 0, pstyle(p2) lpattern(-)) ///
	(line CDF wtp if wtp > `cost', pstyle(p2) lpattern(-)) ///
	(scatter CDF wtp if inlist(wtp,0,`cost'),pstyle(p1) msymbol(circle_hollow)) ///
	(dropline  wtp CDF if inlist(wtp,`cost'),lpattern(dash)  pstyle(p1) horizontal base(-40000)) /// 
	(dropline CDF wtp if inlist(wtp,`cost'),lpattern(dash)  pstyle(p1)) ///
	(dropline  wtp CDF if inlist(wtp,0),lpattern(dash)  msymbol(circle_hollow)  pstyle(p1) horizontal base(-40000)) /// 
	(dropline CDF wtp if inlist(wtp,0),lpattern(dash) msymbol(circle_hollow)  pstyle(p1)) ///
	(pcarrowi 73 15000 65 5000,color(black)) ///
	(pcarrowi 34 -16000 20 -3000,color(black)) ///
	,legend(off) xtick(`cost') text(5 22000 "$2,660 (cost of CMTO program)", j(left)) ///
	xlabel(-40000 "-$40,000" -20000 "-$20,000" 0 "$0" 20000 "$20,000" 40000 "$40,000",format(%9.0gc)) ///
	text(80 25000 "`wtpfornonopp'% have WTP < $2,660 for" "{bf:low-opportunity} neighborhood") ///
	text(40 -18000 "`wtpfornonopp_0'% have WTP < $0 for" "{bf:low-opportunity} neighborhood") ///
	graphregion(margin(2 4 3 3)) ///
	ylabel(0 `averse' 50 `wtpfornonopp' 100, nogrid) name(Test,replace)  ///
	ytitle(CDF of Neighborhood Indirect Utility) xtitle("Net Willingness to Pay for Low-Opportunity Area" "V(Low Opportunity Area) – V(High Opportunity Area)") ///
	ytitle("Cumulative Distribution Function (%)" " ") ${title}

graph export "${figs}/wtp_cdf_treat_6_dec2019.${img}", replace

