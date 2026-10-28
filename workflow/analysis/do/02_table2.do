* Table 2: returns by expected-skewness tercile (pooled sample).
* Mean high-minus-low tests: OLS of the return on a High indicator in the Low+High sample,
* heteroskedasticity-robust (HC1), as in the saved Python/SAS results.
* The median t-statistic (He and Hu, 2002) is computed in SAS (stata/sas/table2_median_t.sas) and is not re-estimated here.
use "$DATA/ipo_returns.dta", clear
tempname h
tempfile f
postfile `h' str8 row str16 stat double value using "`f'", replace
forvalues g = 1/3 {
    quietly summarize r0 if tercile==`g', detail
    post `h' ("`g'") ("Mean R0")      (r(mean))
    post `h' ("`g'") ("Median R0")    (r(p50))
    post `h' ("`g'") ("Observations") (r(N))
    quietly summarize r2_bhar_3y if tercile==`g'
    post `h' ("`g'") ("Mean R1") (r(mean))
    post `h' ("`g'") ("N R1")    (r(N))
    quietly summarize r3_bhar_3y if tercile==`g'
    post `h' ("`g'") ("Mean R2") (r(mean))
}
gen byte high = tercile==3 if inlist(tercile, 1, 3)
foreach y in r0 r2_bhar_3y r3_bhar_3y {
    quietly regress `y' high, vce(robust)
    post `h' ("HL") ("diff `y'") (_b[high])
    post `h' ("HL") ("t `y'")    (_b[high]/_se[high])
    post `h' ("HL") ("N `y'")    (e(N))
}
quietly summarize r0 if tercile==3, detail
local m3 = r(p50)
quietly summarize r0 if tercile==1, detail
post `h' ("HL") ("diff median r0") (`m3' - r(p50))
postclose `h'
preserve
use "`f'", clear
export delimited using "$OUT/results_table2.csv", replace
restore
