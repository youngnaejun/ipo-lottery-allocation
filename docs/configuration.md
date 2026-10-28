# Configuration

Copy `workflow/config/workflow_config.example.sh` to a file of your own and edit it. The runner copies every
workflow script into `<run_root>/code` and fills in its `@SETTING@` placeholders from that file
(`workflow/tools/materialise.py`); no script contains machine-specific paths.

## Settings

| Setting | Paper value | Used by |
|---|---|---|
| `INPUT_DIR` | — | inputs stage: folder with the supplier exports and public files |
| `WRDS_MODE`, `WRDS_DATA` | `local`, local WRDS copy | all WRDS steps (`sas/paths.sas`, the recovery program, the total-loss extract); `WRDS_DATA` only in `local` mode |
| `SAS_EXE`, `STATA_EXE`, `PYTHON_EXE` | — | runner |
| `SDC_IPO_FILE`, `SDC_ALL_FILINGS_FILE`, `SDC_FULL_HISTORY_FILE`, `SDC_ALL_FILINGS_SHEET`, `SDC_FULL_HISTORY_SHEET` | — | stages 01, 01b, external parser, bridge (`build_final.py`, `audit_all_filer_controls.py`) |
| `SAMPLE_START_YEAR` | 1975 | stage 04 (first IPO year), 07b (panel start), stage 03 rank blocks start at 1975 regardless |
| `SAMPLE_END_YEAR` | 2024 | 01b (last filing date), 07b (panel end), Stata exports, filing panels, recovery targets |
| `FILING_START_YEAR` | 1983 | 07b (filing outcomes observed from), filing panels (Table 4/5 outcome quarters, one prior year for lags), recovery rule window, validation IPO selection |
| `DATA_END_DATE` | 31DEC2024 | CRSP/Fama–French windows in stages 02, 02b, 02c, 04d, 05, coskewness export, recovery program, −100% correction extract |
| `LINK_START_DATE` | 01JAN1970 | CRSP windows for security linking and monthly returns (02, 02b, 02c) |
| `CONTROLS_START_DATE` | 01JAN1974 | CRSP daily window for the industry controls (04d), one year before the sample for lags |
| `SKEW_START_DATE` | 01JAN1975 | stock universe for expected skewness and coskewness (05, coskewness export, recovery program) |
| `SDC_EXTRACTION_DATE` | 12AUG2026 | 01b: filings still pending at the export date are treated as unresolved |
| `APPLY_PAPER_EXCLUSIONS` | 1 | stage 06b (see conventions.md) |
| `PAPER_CHECKS` | 1 only for the paper's inputs | asserts the paper's sample counts at each step; use 0 for any other sample |

## What depends on dates

Changing `SAMPLE_START_YEAR` / `SAMPLE_END_YEAR` alone is not enough:

- **Return horizons.** One-, three- and five-year returns use 252, 756 and 1,260 trading-day event windows after
  the issue. IPOs near `DATA_END_DATE` have shorter available histories; returns are compounded over the
  available observations (the paper's convention), not set to missing. Use a CRSP release that extends far
  enough beyond the sample end for the horizons you report.
- **Lagged controls.** Industry controls need one year of CRSP data before the first IPO year
  (`CONTROLS_START_DATE`); filing-quarter panels use one year before `FILING_START_YEAR` for lags;
  market-return and IPO-volatility controls use the preceding quarter or three months.
- **Filing outcomes.** Filings close to `SDC_EXTRACTION_DATE` may still be pending; 01b treats outcomes as
  resolved after 18 months (`resolution_months`, fixed in the code).
- **Underwriter ranks.** Ritter ranks are matched by IPO-year blocks up to `Rank26`; later years need new rank
  columns and code blocks in stage 03 and the two bridge scripts that repeat them.

## Fixed conventions (not configuration)

These remain as in the paper and are not changed by the date settings:

- Proceeds are deflated with the CRSP market-capitalisation index with base year 1975 (`*_adj1975`
  variables), independent of `SAMPLE_START_YEAR`.
- `analysis.do` and the recovery input builder create the paper's historical period indicators (1980–89,
  1990–98, …, 2019–24, and an alternative split). They are used only by diagnostic regressions, not by the
  table do-files, and are not extended for later years.
- Industry-quarter index `time_id` uses the Stata `%tq` origin (1960q1); stage 07b's `quarter_id` counts from
  1975q1.
- Panels cover FF30 industries 1–29 (industry 30, "other", is excluded).
- File names of intermediate datasets keep their historical names (for example
  `ws2_eligible8905_deals_20260917.dta`); the numbers in them describe the paper's run, not the content of a
  new run.
