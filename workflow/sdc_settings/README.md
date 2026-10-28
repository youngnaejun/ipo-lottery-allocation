# SDC search and report settings

These are the LSEG Workspace / SDC Platinum (Global New Issues) settings used for the paper's three SDC exports.
They are settings only; the exported observations are licensed and are not included. In the search files the
local path of the linked report file was reduced to the file name and the desktop session token was cleared;
everything else is as used. The report files are unchanged.

| Export | Search settings | Report settings | Columns in the export | Save as (setting in `workflow_config.sh`) |
|---|---|---|---|---|
| IPO data | `IPO project.sdcs` | `datacollection.sdcrpt` (41 items) | 40 | `SDC_IPO_FILE` |
| All filings | `SDC_all_filings_1975_2024_20260812.sdcs` | `sdc_all_filings_report_20260812.sdcrpt` (44 items) | 43 | `SDC_ALL_FILINGS_FILE`, worksheet `SDC_ALL_FILINGS_SHEET` |
| Full History | `SDC_all_filings_1975_2024_20260812.sdcs` | `sdc_all_filings_report_20260903.sdcrpt` (53 items) | 52 | `SDC_FULL_HISTORY_FILE`, worksheet `SDC_FULL_HISTORY_SHEET` |

Each report has one mandatory system item (the SDC deal identifier), so the export has one column fewer than
the report has items. The reports extend one another: the all-filings report is the IPO report plus three
fields, and the Full History report is the all-filings report plus nine fields. Column order and names are
listed in [../../docs/input_schemas.md](../../docs/input_schemas.md).

## Search criteria

- **IPO data** (`IPO project.sdcs`): Global New Issues, Common Stock; issue date 1 January 1975 – 31 December
  2025; primary-exchange nation of the issuer's stock excludes a list of non-US nations. The paper's export
  therefore also contains 2025 issues. This broader extraction is intentional and kept: the paper's sample
  ends in 2024 because IPOs issued after `DATA_END_DATE` (31 December 2024) cannot be linked to CRSP within
  the stage 02 linking window and drop there. Original-IPO, security-type and currency screens are applied in
  SAS stage 01.
- **All filings** (`SDC_all_filings_1975_2024_20260812.sdcs`): Global New Issues, Common Stock and Equity
  Pipeline and Registrations; filing date 1 January 1975 – 31 December 2024; the same nation exclusion;
  Original IPO Flag = True.
- **Full History**: the same search as the all-filings export, run with the Full History report. The Session
  Details sheet of the paper's Full History export records this search session with identical criteria and
  this report (26,167 deals on 3 September 2026 against 26,168 on 12 August 2026). The pairing was confirmed
  from those export records; these public copies were not reopened or re-exported in SDC.

## Export details expected by the code

- Output: Excel workbook (Columnar Grid). Export each search to its own workbook.
- IPO data: header in row 1 on the first worksheet. Stage 01 reads the low and high file prices by position
  (columns 19 and 20), so keep the report's column order.
- All filings and Full History: SDC writes two title rows, so the header is in row 3 and data start in row 4,
  on the worksheet named in the configuration (the paper's exports used `Request 4`). Keep that worksheet first
  in the workbook (the bridge reads the first sheet), and do not add or reorder columns.
- Set the search dates to your own period if you extend it; the code's sample settings are separate
  (`docs/configuration.md`).

## Reference inputs prepared manually

Save these in the same input folder (`INPUT_DIR`) under the names shown; the column lists are in
`docs/input_schemas.md`.

| Local file name | Source |
|---|---|
| `UMCSENT.csv` | FRED series UMCSENT, CSV download: https://fred.stlouisfed.org/series/UMCSENT |
| `ipo_age_clean.csv` | Jay Ritter, founding dates of IPOs (https://site.warrington.ufl.edu/ritter/ipo-data/), saved as CSV with the listed columns |
| `underwriter_clean.csv` | Jay Ritter, underwriter ranks (same page), saved as CSV with one column per rank period |
| `sentiment_clean.csv` | Baker–Wurgler investor sentiment (https://pages.stern.nyu.edu/~jwurgler/), saved as CSV |
| `reference/census_sic88_97.txt` | US Census Bureau SIC code titles: https://www2.census.gov/programs-surveys/cbp/technical-documentation/records-layouts/sic-code-descriptions/sic88_97.txt |
