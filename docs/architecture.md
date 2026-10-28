# Architecture

The repository has two separate components.

## 1. Synthetic Python demonstration (`src/ipo_lottery`, `tests/`)

A small Python package that illustrates the core contracts — cleaning, auditable identifier linking,
expected-skewness features and a summary — on generated records. It is an illustration only: it is not the
empirical pipeline and its outputs are not the paper's estimates.

| Stage | Input | Output | Failure behaviour |
|---|---|---|---|
| Ingest | Local files | Schema-conformant frames | Missing inputs raise |
| Clean | SDC-style deals | One valid row per issuer-date | Missing required values raise |
| Link | IPOs and CRSP-style candidates | Linked IPOs plus unmatched report | Unmatched records remain visible |
| Features | Linked IPOs and industry returns | Expected skewness and lottery flag | Missing industries raise |
| Analysis | Feature-complete IPOs | Allocation summary | Missing fields raise |

## 2. Empirical workflow (`workflow/`)

The SAS, Python and Stata programs behind the paper, adapted for reuse with your own authorised data.
Windows + Git Bash, SAS 9.4 (Base, STAT, SAS/CONNECT), Stata 19 (StataNow/MP), Python 3.13.

```
supplier exports + WRDS ──► sas/stages (01 … 07c)          SAS master datasets
                            sas/external (coskewness)       industry-quarter coskewness
                       ──► bridge/                          four table-input datasets
                             stata_exports  Stata copies of the master data, derived variables
                             ws2_panels     completed-IPO filing-quarter panels; filing-link recovery rule
                             filing_panels  Table 4/5 industry-quarter panels, market-return control
                             controls       Table 5 all-filer controls; recovered IPOs' variables
                             recovery       recovered IPOs' returns/coskewness (WRDS) and revision variables
                             boundary       −100% (total-loss) correction of long-run returns
                             final_panels   final Table 4/5 estimation panels
                       ──► analysis/                        Tables 1–7, B1–B4, IA1–IA3 (Stata + SAS median
                                                            test), Word file
                       ──► tools/check_outputs.py           structural checks
```

Entry points: `workflow/run_workflow.sh` (everything) and `workflow/run_analysis.sh` (analysis only, from your
own four datasets).

## Two kinds of checks

- **Structural checks** (always on): schemas, unique keys, value ranges, complete industry-quarter grids,
  consistency between steps (for example, deal counts that must equal cell sums), reproduction of stored
  returns before the total-loss correction, and finite estimates. These are meaningful for any period or
  vintage.
- **Paper checks** (`PAPER_CHECKS=1`): the paper's sample counts at each step (for example 17,767 filings,
  8,905 eligible completed IPOs, 61 recovered IPOs, 8,984 IPOs in the return dataset). They hold only for the
  paper's inputs and dates and must be off for any other sample.

Exact reproduction of the paper's table cells is a third kind of check. It needs the archived analysis
datasets, which are not distributed; see the README.
