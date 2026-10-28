# Workflow configuration. Copy to workflow/config/workflow_config.sh, edit, and run workflow/run_workflow.sh.
# Values are read by the runner (Git Bash) and filled into the @SETTING@ placeholders of the workflow scripts.
# The defaults below are the settings used for the paper (IPOs 1975-2024, data extracted in 2026).

# ---- Locations ---------------------------------------------------------------------------------------
# Folder holding your authorised supplier exports (see docs/data_acquisition.md for names and fields).
INPUT_DIR="/c/data/ipo_inputs"
# Root of a local copy of the WRDS libraries (Windows path) when WRDS_MODE=local: raw\crsp\a_stock, raw\ff,
# and catalog\comp_local.sas (a libname for Compustat; see docs/data_acquisition.md).
WRDS_DATA='C:\data\wrds'
# local = WRDS blocks run in a SAS session spawned on this machine against WRDS_DATA
# wrds  = WRDS blocks run on the WRDS server through SAS/CONNECT (prompts for credentials at each sign-on)
WRDS_MODE="local"

# ---- Software ----------------------------------------------------------------------------------------
SAS_EXE="/c/Program Files/SASHome/SASFoundation/9.4/sas.exe"
STATA_EXE='C:\Program Files\StataNow19\StataMP-64.exe'      # Windows path
PYTHON_EXE="python"                                         # Python 3.13 with workflow/requirements.txt

# ---- Supplier export file names (inside INPUT_DIR) -----------------------------------------------------
SDC_IPO_FILE="sdc_new_issues_ipos.xlsx"                     # SDC New Issues, completed US IPOs
SDC_ALL_FILINGS_FILE="sdc_all_filings.xlsx"                 # SDC New Issues, all filing statuses
SDC_FULL_HISTORY_FILE="sdc_full_history.xlsx"               # SDC New Issues Full History fields
SDC_FULL_HISTORY_SHEET="Request 4"                          # worksheet holding the Full History export
SDC_ALL_FILINGS_SHEET="Request 4"                           # worksheet holding the all-filings export

# ---- Sample and data-coverage dates --------------------------------------------------------------------
# IPO sample: issue years SAMPLE_START_YEAR-SAMPLE_END_YEAR. Changing these alone is not enough: the
# return and control windows below must cover the horizons and lags (see docs/configuration.md).
SAMPLE_START_YEAR="1975"
SAMPLE_END_YEAR="2024"
# Filing outcomes are treated as observed from this year (SDC filing-date coverage starts in 1983).
FILING_START_YEAR="1983"
# Last date of CRSP/Fama-French data used (SAS date literal). Long-horizon returns are truncated here.
DATA_END_DATE="31DEC2024"
# Start of the CRSP windows: security linking/monthly returns, industry controls (one year of lags), and
# the skewness/coskewness estimation universe.
LINK_START_DATE="01JAN1970"
CONTROLS_START_DATE="01JAN1974"
SKEW_START_DATE="01JAN1975"
# Date the SDC all-filings export was made (SAS date literal); filings still pending at this date are open.
SDC_EXTRACTION_DATE="12AUG2026"

# ---- Paper-specific settings ---------------------------------------------------------------------------
# 1 = apply the paper's documented SDC data-issue exclusion (stage 06b: PERMNO 22342, Society Pass).
#     This is a decision for one record in the paper's SDC extract, not a general screen.
APPLY_PAPER_EXCLUSIONS="1"
# 1 = also assert the paper's sample counts at each step (only meaningful with the paper's inputs and
#     dates); 0 = structural checks only. Use 0 for new samples, periods or data vintages.
PAPER_CHECKS="0"
