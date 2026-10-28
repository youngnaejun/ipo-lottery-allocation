# Input schemas

Field names are the LSEG/SDC field titles as exported. Order matters where noted.

## SDC_IPO_FILE (40 fields, header in row 1)

Stage 01 imports the sheet with SAS `PROC IMPORT` (`getnames=yes`) and renames fields by their SAS names.
The two file-price fields (positions 19 and 20) are read by position (`VAR19`, `VAR20`), so keep this order.

| # | Field |
|---|---|
| 1 | Dates: Filing Date |
| 2 | Dates: Issue Date |
| 3 | Listing Date |
| 4 | Date of Lockup Expiration |
| 5 | Issuer/Borrower Name Full |
| 6 | Issuer/Borrower State |
| 7 | Issuer/Borrower Nation |
| 8 | Issuer/Borrower Ticker Symbol |
| 9 | Issuer/Borrower 6-digit CUSIP |
| 10 | Issuer/Borrower 9-digit CUSIP |
| 11 | SDC Deal Number |
| 12 | IPO Flag |
| 13 | Original IPO Flag |
| 14 | Security Type This Market |
| 15 | Primary Exchange Listing Of Issue |
| 16 | Tranche Currency |
| 17 | SIC |
| 18 | Offer Price (USD) |
| 19 | File Price, Low (USD) |
| 20 | File Price, High (USD) |
| 21 | Amended Low File Price (USD) |
| 22 | Amended High File Price (USD) |
| 23 | Proceeds Amount This Market (USD Millions) |
| 24 | Primary Shares Offered This Market |
| 25 | Secondary Shares Offered This Market |
| 26 | Full History Amount Filed This Market (USD Millions) |
| 27 | Venture Capital Backed IPO Issue Flag |
| 28 | New Issues Fees: Gross Spread as Pct of Offer Price |
| 29 | All New Issues Manager Roles |
| 30 | Number of Shares Subject to Lockup Agreement |
| 31 | Over Subscription Flag |
| 32 | Not Underwritten Issue Flag |
| 33 | Lead Managers |
| 34 | Lead Managers Code |
| 35 | Blank Check (SPAC) Involvement Y/N: |
| 36 | Issuer/Borrower Public Status |
| 37 | Transaction Status |
| 38 | Financials: Shares Outstanding After Offer |
| 39 | Shares Outstanding After Offer from Prospectus |
| 40 | Lockup: Lockup Shares as Percent of Shares Outstanding After Offer |

## SDC_ALL_FILINGS_FILE (43 fields, two title rows, header in row 3)

Stage 01b reads columns A–AQ from row 3 of sheet `SDC_ALL_FILINGS_SHEET`; the bridge (`build_final.py`) reads the
workbook's first (active) sheet from row 3. Fields 1–40 as above, then:

| # | Field |
|---|---|
| 41 | Postponed Date |
| 42 | Additional Comments |
| 43 | Date Deal was Last Updated |

## SDC_FULL_HISTORY_FILE (52 fields, two title rows, header in row 3)

Fields 1–43 as the all-filings export, then:

| # | Field |
|---|---|
| 44 | SIC |
| 45 | Issuer/Borrower SIC |
| 46 | Full History Filing Date |
| 47 | Full History Total Shares Filed This Market |
| 48 | Full History Primary Shares Filed This Market |
| 49 | Full History Overallotment Shares Filed This Market |
| 50 | Full History High File Price (USD) |
| 51 | Full History Low File Price (USD) |
| 52 | Full History Mid File Price (USD) |

Full History fields hold one value per filing amendment, separated by `;`, in the same order across fields.
`workflow/python/parse_sdc_fullhistory.py` stops if the lists are misaligned.

## Public files (fixed names in INPUT_DIR)

| File | Columns read |
|---|---|
| `UMCSENT.csv` | `observation_date`, `UMCSENT` (monthly) |
| `ipo_age_clean.csv` | `offer date` (YYYYMMDD), `IPO name`, `Ticker`, `CUSIP`, `ADR (2=ADR)`, `VC`, `Dual`, `Post-issue shares`, `Internet`, `CRSP Perm`, `Founding`, `Rollup` |
| `underwriter_clean.csv` | `Underwriter Name`, then one rank column per period: `Rank8084`, `Rank8591`, `Rank9200`, `Rank0104`, `Rank0507`, `Rank0809`, `Rank1011`, `Rank1217`, `Rank1820`, `Rank2122`, `Rank23`, `Rank24`, `Rank25`, `Rank26` (−9 = not ranked) |
| `sentiment_clean.csv` | `yearmo`, `SENT`, `SENT_ORTH`, `pdnd`, `ripo`, `nipo`, `cefd`, `s`, `indpro`, `consdur`, `consnon`, `consserv`, `recess`, `employ`, `cpi` (in this order) |
| `reference/census_sic88_97.txt` | Census SIC titles: 4-character code, two spaces, title |

## Table-input (analysis) datasets

`workflow/run_workflow.sh` builds these four Stata datasets; `workflow/run_analysis.sh` accepts them from any source.
The machine-readable version is `workflow/analysis/table_input_schema.json`, which the structural checks use.
Variable definitions follow the paper's Appendix A; see also [conventions.md](conventions.md).

### ipo_returns.dta

Unit: IPO. Tables: Tables 1, 2, 3, B1, B2. Key: analysis_id.

`analysis_id`, `PERMNO`, `ipo_year`, `yr`, `ff30`, `tercile`, `skew1`, `r0`, `age_ritter`, `coskewness`, `internet`, `NASDAQ`, `NYSE`, `lnproceeds_adj1975`, `price_adj`, `price_adj_imp`, `share_overhang`, `pure_primary`, `VB`, `TT_ave`, `lagmcsi`, `lagcummktret`, `ipo_vol`, `ind_ret`, `ind_mom`, `ind_vol`, `ind_turn`, `r2_bhar_1y`, `r2_bhar_3y`, `r2_bhar_5y`, `r3_bhar_1y`, `r3_bhar_3y`, `r3_bhar_5y`

### revisions.dta

Unit: IPO (price-revision sample and recovered IPOs). Tables: Tables 6, 7, B3, B4. Key: analysis_id.

`analysis_id`, `PERMNO`, `ipo_year`, `yr`, `ff30`, `restored61`, `skew1`, `r0`, `rev_signed`, `rev_up`, `rpos`, `range_width`, `share_revision_raw`, `proceeds_revision`, `sample_price`, `sample_sr_full`, `sample_proceeds`, `sample_rpos`, `mkt_reg_ew`, `mkt_reg_ew_pos`, `lagmcsi`, `lagcummktret`, `ipo_vol`, `age_ritter`, `coskewness`, `internet`, `NASDAQ`, `NYSE`, `ln_amount_filed_adj1975`, `share_overhang`, `pure_primary`, `VB`, `uw_rank_ave`, `ind_ret`, `ind_mom`, `ind_vol`, `ind_turn`

### t4_panel.dta

Unit: FF30 industry x filing quarter (completed IPOs). Tables: Table 4, IA1, IA2. Key: ff30, time_id.

`ff30`, `time_id`, `lag_skew`, `lag_return`, `lag_momentum`, `lag_ivol`, `lag_turnover`, `lag_lnfirms`, `skew_l1`, `skew_l2`, `skew_l3`, `skew_l4`, `n_primary`, `nominal_total`, `n_restored`, `avg_primary`, `outcome_total`, `q_age`, `q_lnexpected`, `q_overhang`, `q_uwrank`, `q_vcshare`, `q_primaryshare`, `q_optimism`, `q_ipovol`, `n_age`, `n_lnexpected`, `n_overhang`, `n_uwrank`, `n_vcshare`, `n_primaryshare`, `n_optimism`, `n_ipovol`, `adjusted_total`, `n_ipo`, `t11`, `t12`, `t13`, `q_indret`, `q_indmom`, `q_indvol`, `q_indturn`, `q_lnfirms`, `l_indret`, `l_indmom`, `l_indvol`, `l_indturn`, `l_lnfirms`, `l_age`, `l_lnexpected`, `l_overhang`, `l_uwrank`, `l_vcshare`, `l_primaryshare`, `l_optimism`, `l_ipovol`, `q_cosk`, `l_cosk`, `yr`, `market_return_qminus1_candidate`, `proceeds`

### t5_panel.dta

Unit: FF30 industry x filing quarter (filings). Tables: Table 5, IA3. Key: ff30, time_id.

`ff30`, `time_id`, `lag_skew`, `lag_return`, `lag_momentum`, `lag_ivol`, `lag_turnover`, `lag_lnfirms`, `skew_l1`, `skew_l2`, `skew_l3`, `skew_l4`, `n_primary`, `nominal_total`, `n_restored`, `avg_primary`, `outcome_total`, `q_age`, `q_lnexpected`, `q_overhang`, `q_uwrank`, `q_vcshare`, `q_primaryshare`, `q_optimism`, `q_ipovol`, `n_age`, `n_lnexpected`, `n_overhang`, `n_uwrank`, `n_vcshare`, `n_primaryshare`, `n_optimism`, `n_ipovol`, `adjusted_total`, `n_ipo`, `t11`, `t12`, `t13`, `q_indret`, `q_indmom`, `q_indvol`, `q_indturn`, `q_lnfirms`, `l_indret`, `l_indmom`, `l_indvol`, `l_indturn`, `l_lnfirms`, `l_age`, `l_lnexpected`, `l_overhang`, `l_uwrank`, `l_vcshare`, `l_primaryshare`, `l_optimism`, `l_ipovol`, `q_cosk`, `l_cosk`, `yr`, `skew_l5`, `n_main`, `n_comp`, `n_wd`, `n_pp`, `n_open`, `n_unk`, `n_no_unk`, `n_all_unk`, `n_no_fund_screen`, `n_priorA`, `n_bridge`, `n_day`, `n_first`, `n_first_wd`, `n_common_mix`, `n_common_sdc`, `n_cmix_wd`, `n_csdc_wd`, `n_uniform`, `n_uniform_wd`, `market_return_qminus1_candidate`, `all_amount`, `all_valid`, `all_n`, `all_empty`, `all_missing`, `completed_amount`, `completed_valid`, `completed_n`, `completed_empty`, `completed_missing`, `all_uw`, `all_uw_valid`, `all_uw_n`
