* Table 1: summary statistics (Panel A) and industry distribution by expected-skewness tercile (Panel B).
* Terciles follow SAS PROC RANK GROUPS=3 with average ranks: floor(rank*3/(n+1))+1 (built in export).
use "$DATA/ipo_returns.dta", clear
tempname h
tempfile f
postfile `h' str8 panel str40 row str16 stat double value using "`f'", replace
foreach v in skew1 age_ritter coskewness internet NASDAQ NYSE lnproceeds_adj1975 share_overhang ///
             pure_primary VB TT_ave lagmcsi lagcummktret r0 r2_bhar_3y r3_bhar_3y {
    quietly summarize `v'
    post `h' ("A") ("`v'") ("N")    (r(N))
    post `h' ("A") ("`v'") ("Mean") (r(mean))
    post `h' ("A") ("`v'") ("SD")   (r(sd))
    post `h' ("A") ("`v'") ("Max")  (r(max))
    post `h' ("A") ("`v'") ("Min")  (r(min))
}
quietly levelsof ff30, local(inds)
foreach j of local inds {
    quietly count if ff30==`j'
    local n = r(N)
    post `h' ("B") ("`j'") ("N") (`n')
    quietly summarize skew1 if ff30==`j'
    post `h' ("B") ("`j'") ("Mean skew") (r(mean))
    forvalues g = 1/3 {
        quietly count if ff30==`j' & tercile==`g'
        post `h' ("B") ("`j'") ("Tercile `g' %") (100*r(N)/`n')
    }
}
postclose `h'
preserve
use "`f'", clear
export delimited using "$OUT/results_table1.csv", replace
restore
