* Helpers shared by the table do-files.
* post_model: after an estimation command, post b/se/t/p for each listed term.
capture program drop post_model
program define post_model
    syntax, handle(name) table(string) panel(string) column(integer) terms(string) [fit(real -99) stat(string)]
    if "`stat'"=="" local stat t
    local N = e(N)
    local f = `fit'
    if `f'==-99 local f = e(r2_a)
    foreach x of local terms {
        local b  = _b[`x']
        local se = _se[`x']
        local tt = `b'/`se'
        if "`stat'"=="z" local p = 2*normal(-abs(`tt'))
        else local p = 2*ttail(e(df_r), abs(`tt'))
        post `handle' ("`table'") ("`panel'") (`column') ("`x'") (`b') (`se') (`tt') (`p') (`N') (`f')
    }
end

* open_results / close_results wrap postfile and export the results as CSV.
capture program drop open_results
program define open_results
    args handle name
    * A tempfile would vanish when this program returns, so the post file lives in $OUT.
    global POSTFILE_`handle' "$OUT/_post_`name'.dta"
    postfile `handle' str12 table str8 panel int column str40 term double(b se stat p N fit) using "${POSTFILE_`handle'}", replace
end
capture program drop close_results
program define close_results
    args handle name
    postclose `handle'
    preserve
    use "${POSTFILE_`handle'}", clear
    export delimited using "$OUT/results_`name'.csv", replace
    restore
end
