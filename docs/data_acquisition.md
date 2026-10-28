# Data acquisition

The workflow distributes code only. Every input below must be obtained by the user under their own
authorised access; provider terms govern the data and anything derived from it. Access to a provider is not
permission to redistribute its data, and the repository's code licence does not cover any data.

Place the files in one folder (`INPUT_DIR` in the workflow configuration). The SDC search and report settings,
the export layout and the expected file names are in
[../workflow/sdc_settings/README.md](../workflow/sdc_settings/README.md); exact field lists are in
[input_schemas.md](input_schemas.md).

## Licensed sources

| Source | File (configuration setting) | Content | How the paper obtained it |
|---|---|---|---|
| LSEG Workspace / SDC Platinum, Global New Issues | `SDC_IPO_FILE` | US IPOs (original IPOs, common equity), one row per deal, 40 fields | Search `IPO project.sdcs` with report `datacollection.sdcrpt` (issue dates 1975–2025; post-2024 IPOs drop at CRSP linking), exported 3 June 2026 |
| same | `SDC_ALL_FILINGS_FILE` (sheet `SDC_ALL_FILINGS_SHEET`) | All US IPO filings regardless of outcome (completed, withdrawn, postponed, pending), 43 fields | Content set "Common Stock, Equity Pipeline and Registrations", filing dates 1975–2024, exported 12 August 2026 (set `SDC_EXTRACTION_DATE` to your export date) |
| same | `SDC_FULL_HISTORY_FILE` (sheet `SDC_FULL_HISTORY_SHEET`) | As the all-filings export plus the Full History fields (filing dates, shares, file prices for each amendment), 52 fields | Exported 3 September 2026 |
| CRSP via WRDS | local copy or WRDS server | `crsp.dsf`, `crsp.dsedelist`, `crsp.dsi`, `crsp.msf`, `crsp.msenames` (legacy SIZ `a_stock` layout) | Annual release dated 7 February 2025 (data through 31 December 2024) |
| Compustat via WRDS | local copy or WRDS server | `comp.funda` (SIC fallback for linking) | Downloaded October 2026 |
| Fama–French factors via WRDS | local copy or WRDS server | `ff.factors_daily` | Downloaded October 2026 |

SDC exports write two title rows above the header. Keep the default export layout: header in row 3 for the
all-filings and Full History exports, data on the worksheet that opens first, and the column order listed in
input_schemas.md (stage 01 reads the low and high file prices by position).

### WRDS access modes

- `WRDS_MODE="wrds"`: SAS/CONNECT sign-on to the WRDS server, as in the original programs
  (`signon username=_prompt_`); SAS prompts for the WRDS user name and password at each sign-on, and they are
  never stored. Every WRDS step, including the total-loss correction extract, then runs on the server. Check
  the sign-on first with `workflow/check_wrds_connection.sh`.
- `WRDS_MODE="local"`: a local copy of the WRDS libraries under `WRDS_DATA`:
  `raw\crsp\a_stock\*.sas7bdat` (CRSP), `raw\ff\factors_daily.sas7bdat`, and `catalog\comp_local.sas`, a file
  you write that assigns the `comp` libref to your Compustat copy, for example
  `libname comp "C:\data\wrds\raw\d_na" access=readonly;`.

## Public sources

| File (fixed name) | Source | Notes |
|---|---|---|
| `UMCSENT.csv` | FRED series UMCSENT (University of Michigan consumer sentiment) | Download the CSV from https://fred.stlouisfed.org/series/UMCSENT |
| `ipo_age_clean.csv` | Jay Ritter, IPO founding dates (https://site.warrington.ufl.edu/ritter/ipo-data/) | Saved as CSV with the columns in input_schemas.md; the paper's cleaning steps were not recorded |
| `underwriter_clean.csv` | Jay Ritter, underwriter (Carter–Manaster) ranks | One column per rank period (`Rank8084` … `Rank26`); IPO years without a rank column get missing ranks |
| `sentiment_clean.csv` | Baker–Wurgler investor sentiment (https://pages.stern.nyu.edu/~jwurgler/) | Read by stage 04 but not used in the paper's tables |
| `reference/census_sic88_97.txt` | US Census SIC code titles (sic88_97.txt) | Used by the SDC industry-name crosswalk |

## Other periods

The settings and dates in this repository are the paper's. Adapting them to another period is the user's
responsibility; [configuration.md](configuration.md) lists the date settings and what depends on them.
