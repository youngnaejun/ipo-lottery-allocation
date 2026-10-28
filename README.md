# IPO Lottery Allocation: data collection and table code

> Release candidate prepared for review. Not yet published.

This repository provides the data-collection and table-analysis code used for our study of IPOs,
lottery-like return characteristics and capital allocation in the US primary market, so that other
researchers with the required subscriptions can follow the same approach. Adapting it to other periods or
research questions is the user's responsibility.

Because WRDS data may be revised over time, newly downloaded data may not exactly match the dataset used in the
paper.

The repository contains code and settings only. It does not contain SDC, CRSP or Compustat observations, the
paper's analysis datasets or its results.

## Contents

| Path | Content |
|---|---|
| `workflow/sdc_settings/` | SDC search and report settings for the three SDC exports, with the export-to-file mapping |
| `workflow/run_workflow.sh` | the full workflow: supplier exports → SAS data construction → four analysis datasets → Tables 1–7, B1–B4, IA1–IA3 (Stata, SAS median test) and a Word file → structural checks |
| `workflow/run_analysis.sh` | the table step alone, from the four analysis datasets |
| `workflow/check_wrds_connection.sh` | a short check of the WRDS server sign-on before a server-mode run |
| `docs/` | data acquisition, input schemas, configuration, research conventions, architecture |
| `src/ipo_lottery`, `tests/` | a small Python demonstration on generated records (illustration only; not the empirical workflow) |

## Our sample and inputs

| Item | Paper |
|---|---|
| IPOs | US original IPOs issued 1975–2024 |
| Filings | US IPO filings 1975–2024; filing outcomes observed from 1983 |
| SDC exports (LSEG Workspace, Global New Issues) | IPO data 3 June 2026; all filings 12 August 2026; Full History 3 September 2026 |
| CRSP (WRDS) | legacy SIZ `a_stock` release dated 7 February 2025 (data through 31 December 2024) |
| Compustat, Fama–French daily factors (WRDS) | downloaded October 2026 |
| Public files | FRED UMCSENT, Jay Ritter founding dates and underwriter ranks, Baker–Wurgler sentiment, US Census SIC titles |

The SDC IPO search covers issue dates through 31 December 2025; IPOs issued after the CRSP data end
(31 December 2024) cannot be linked to CRSP and drop out in SAS stage 02, so the sample ends in 2024.

How to reproduce each input: [workflow/sdc_settings/README.md](workflow/sdc_settings/README.md) (SDC searches,
reports, export layout, file names, public files) and [docs/data_acquisition.md](docs/data_acquisition.md)
(WRDS tables and access). Field lists: [docs/input_schemas.md](docs/input_schemas.md).

## Software

- Windows with Git Bash.
- SAS 9.4 with Base SAS, SAS/STAT and SAS/CONNECT.
- Stata 19 (StataNow/MP) with `reghdfe`, `ftools`, `ppmlhdfe`, `outreg2` and `estout` (`ssc install …`).
- Python 3.13 with `workflow/requirements.txt`, in its own environment.
- Subscriptions: LSEG Workspace / SDC Platinum and WRDS (CRSP, Compustat, Fama–French).

## WRDS access

Set `WRDS_MODE` in the configuration:

- `local`: previously downloaded WRDS datasets in `WRDS_DATA` (library layout in docs/data_acquisition.md).
  Every WRDS step runs in a local SAS session against these files.
- `wrds`: the WRDS server through SAS/CONNECT, as in the original programs. SAS shows the WRDS sign-on prompt
  (`signon username=_prompt_`) and you type your WRDS user name and password into SAS at each sign-on; they are
  not stored in any file. Run `workflow/check_wrds_connection.sh my_config.sh <folder>` first to check the
  sign-on and library access.

## Running the workflow

1. Obtain the inputs and place them in one folder under the names listed in workflow/sdc_settings/README.md.
2. Copy `workflow/config/workflow_config.example.sh` to `my_config.sh` and set the locations, software paths and
   WRDS mode; the date settings are the paper's ([docs/configuration.md](docs/configuration.md)).
3. Create the Python environment: `py -3.13 -m venv .venv-workflow`, then
   `.venv-workflow/Scripts/python -m pip install -r workflow/requirements.txt`; set `PYTHON_EXE` to it.
4. From Git Bash, with a new run folder outside any synced drive:

```bash
workflow/run_workflow.sh my_config.sh /c/work/ipo_run_01
```

| Stage | What it does |
|---|---|
| `inputs` | copies the inputs into `<run>/raw` (stops if one is missing) |
| `sas` | SAS stages 01–07c: SDC cleaning, CRSP/Compustat linking, underwriter ranks, sample, expected skewness and coskewness, returns, the paper's documented exclusion (06b), industry controls, price revisions, all-filings linking, filing-quarter panel, completion outcomes |
| `external` | SDC Full History parser; industry-quarter coskewness |
| `bridge` | Stata copies and derived variables; filing-quarter panels; filing-link recovery rule and the recovered IPOs' returns and coskewness; Table 5 all-filer controls; total-loss (−100%) correction; final panels |
| `tables` | the four analysis datasets; Stata tables; SAS median test |
| `word` | `ipo_tables.docx` |
| `check` | structural checks → `stata_tables/out/structural_checks.json` |

Stages can be named individually after the run folder. Each SAS program is accepted only if SAS exits with
status 0 (or 1, warnings only, which is reported), writes a complete new log and the log has no `ERROR` line;
otherwise the run stops with the reason. With local WRDS data a full run took about 1 h 20 min on our machine
(SAS WORK needs about 40 GB).

The table step can also be run on its own: `workflow/run_analysis.sh my_config.sh <folder with the four .dta
files> <output folder>`.

## Checks

- **Structural checks** run in every run: schemas, unique keys, value ranges, complete industry-quarter grids,
  consistency between steps, reproduction of stored returns before the total-loss correction, finite estimates.
- **Paper checks** (`PAPER_CHECKS="1"`) also assert the paper's sample counts at each step. They hold only for the
  paper's inputs; keep `PAPER_CHECKS="0"` otherwise.

## What was tested

On our Windows machine with the paper's supplier exports and **local** WRDS data (`WRDS_MODE="local"`):

- the full workflow ran from the supplier exports to the Word tables and structural checks, without any
  archived intermediate files (22 October 2026; 45 of 45 structural checks). Its estimates differ slightly from
  the paper's because the paper used WRDS extracts downloaded earlier (see the data-vintage note above);
- after the changes of 23 October (SAS error handling, total-loss extract routes), the affected stages were rerun
  on the same run folder and reproduced the earlier outputs exactly;
- the bridge and table steps, started from the paper's own SAS master datasets, reproduced the authors' internal
  replication of the paper's analysis datasets and table results exactly;
- the SAS error handling was checked against failed launches, syntax errors, `%abort`, stale and truncated logs,
  errors in redirected logs and a non-zero exit status with a clean log;
- the table step alone ran on generated datasets, and the Python demonstration's tests pass.

WRDS server route (`WRDS_MODE="wrds"`): the connection check passed on 29 October 2026 (SAS sign-on prompt in
batch mode, sign-on to WRDS, `crsp.dsi`, `crsp.dsf` and `crsp.dsedelist` read on the server, upload/download
round trip). The total-loss extract's server route was then run on the 8,982 IPO targets of the full local run:
the daily and delisting returns it downloaded were identical, value by value and in order, to the local
route's (21,648,195 and 8,982 rows). A complete workflow run in server mode has not been carried out.

## Research conventions

The paper's conventions are implemented as used and explained in [docs/conventions.md](docs/conventions.md):
event-observation return windows over the available history, conditional replacement of a missing first
return, the total-loss (−100%) correction, the filing-link recovery rule, the paper-specific Society Pass
exclusion (an SDC data issue for one record), and the separate SIC-to-FF30 map used by stage 04d.

## Python demonstration

`src/ipo_lottery` is a small illustration on generated records:

```bash
python -m venv .venv && .venv/Scripts/python -m pip install -e ".[dev]"
.venv/Scripts/python tests/fixtures/make_synthetic.py --output-dir data/synthetic
.venv/Scripts/python -m ipo_lottery run --config config/config.yaml --stage all
```

It does not use the empirical workflow and its output has no relation to the paper's estimates.

## Licence and citation

Code is released under the [MIT Licence](LICENSE); data remain subject to their providers' terms. Citation
metadata are in [`CITATION.cff`](CITATION.cff). File list and changes from the source materials:
[PUBLIC_MANIFEST.md](PUBLIC_MANIFEST.md).
