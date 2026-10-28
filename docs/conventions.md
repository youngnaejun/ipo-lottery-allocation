# Research conventions inherited from the paper

These choices are implemented as in the paper so that the approach can be understood and reproduced. Their
retention does not mean they are the right defaults for every new question; state them when you adapt the
workflow.

## Returns

- **R0** is the offer-price to first-day-close return. **R1** (`r2_bhar_*y`) compounds daily returns over event
  observations 2 to H+1 (from the first-day close); **R2** (`r3_bhar_*y`) over observations 1 to H (from the
  offer price), with H = 252, 756, 1,260 for one, three and five years.
- Windows are event observations, not complete calendar years: available non-missing returns are compounded,
  and IPOs whose history ends before H (delisting or the data end) keep a return over the shorter history.
- The first CRSP return is replaced by R0 only when it is missing.
- Delisting returns are combined with the same-day return.
- **Total loss.** A daily return of −100% makes compounded wealth zero, so the return over that window is −1.
  Stage 06 compounds with sums of logarithms, which would drop such a day; the bridge step
  `bridge/boundary` recomputes the windows from CRSP daily data and sets the affected returns to −1. It first
  checks that every other return is reproduced from the same data and stops otherwise.
- Returns are raw buy-and-hold returns, not benchmark-adjusted.

## Sample and records

- **Filing-link recovery.** Completed IPOs that the CRSP link left without a validated security are recovered
  when the CRSP first trading date is the next market day after the SDC issue date and equals the SDC listing
  date, the security has no CRSP monthly record before the issue, and no other validated deal is the same event
  (`bridge/ws2_panels/restore_ws2_61.py`, `bridge/controls/make_recovered61_list.py`). Their returns and
  coskewness are computed by `sas/external/WRDS_Recovered61.sas` (the "recovered61" label is the paper's name for
  this role; the number of recovered IPOs depends on the sample). The same program recomputes a set of
  already-constructed IPOs as a check (the earliest IPO in every fifth year from `FILING_START_YEAR`, plus the
  last year).
- **Society Pass (PERMNO 22342).** Stage 06b preserves the prior exclusion of Society Pass due to an SDC data
  issue. It is a decision about one record in the paper's SDC extract, not a general screen and not a
  foreign-issuer rule. It applies when `APPLY_PAPER_EXCLUSIONS=1`.
- Main IPO sample: original US IPOs of common equity, USD tranches, FF30 industries 1–29, issue years from
  `SAMPLE_START_YEAR`; SPAC and exchange flags are kept as indicators (see the stage headers).

## Industry classification

- FF30 industries are assigned from CRSP SIC codes with a Compustat SICH fallback (stage 02). The map in
  `sas/common/ff30_mapping.sas` is identical, for every SIC code 0–9999, to the maps embedded in stages 02, 05
  and the external programs (they stay embedded because they run inside WRDS server blocks).
- **Stage 04d uses a different SIC-to-FF30 map** to classify CRSP stocks when it builds the industry return,
  momentum and idiosyncratic-volatility series. It differs from the common map on 548 SIC codes (227 left
  unassigned, for example 2900–2999; 309 assigned only by 04d; 12 assigned to another industry). It is retained
  because it generated the paper's results; whether to harmonise it is an open research review item. An IPO's
  own FF30 code always comes from the common map.

## Estimation (tables)

- OLS with HC1 standard errors; fixed effects as indicators or absorbed with `reghdfe` (singletons dropped);
  probit average marginal effects (`margins, dydx()`) for Table B3; PPML with `ppmlhdfe` for IA1–IA3.
- Expected-skewness terciles use the SAS PROC RANK GROUPS=3 rule with average ranks:
  `floor(rank*3/(n+1))+1`.
- The Table 2 median test (He and Hu, 2002) is computed in SAS PROC QUANTREG with
  `ci=resampling seed=20260930`; there is no Stata implementation.
