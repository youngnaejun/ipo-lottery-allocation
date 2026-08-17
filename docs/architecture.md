# Architecture

The production and public-validation paths are deliberately separated.

The authoritative SAS and Stata programs operate on licensed SDC/LSEG and WRDS
data held outside this repository. The Python package implements the same core
contracts—cleaning, auditable identifier resolution and expected-skewness
construction—against generated data. Tests and continuous integration therefore
exercise pipeline behaviour without redistributing a vendor record.

## Stage contracts

| Stage | Input | Output | Failure behaviour |
|---|---|---|---|
| Ingest | Local files or vendor extraction | Schema-conformant frames | Missing inputs raise |
| Clean | SDC-style deals | One valid row per issuer-date | Missing required values raise |
| Link | IPOs and CRSP candidates | Linked IPOs plus unmatched report | Unmatched records remain visible |
| Features | Linked IPOs and industry returns | Expected skewness and lottery flag | Missing industries raise |
| Analysis | Feature-complete IPOs | Allocation summary or research models | Missing fields raise |

Production row-count checkpoints are documented as expectations, not bundled
outputs: 12,936 cleaned SDC deals, 9,400 CRSP matches, 8,924 observations in the
analysis universe and 8,923 observations in the saved analysis dataset after a
confirmed issuer exclusion.

