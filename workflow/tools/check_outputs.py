"""Structural checks of a workflow run, suitable for any sample period or data vintage.

Usage: check_outputs.py <data_dir> <out_dir> <table_input_schema.json>

Checks (no paper-specific counts or coefficients):
  datasets  the four table-input datasets exist, carry every column in the schema, have unique keys and
            at least one row; ff30 in 1-29; expected-skewness terciles in 1-3; returns not below -100%;
            panel cells form a complete FF30 x quarter grid
  results   every results_*.csv written by the analysis do-files exists and is non-empty; coefficients and
            standard errors are finite; N is positive; every table in the paper's layout has estimates
  word      the Word table file exists and contains tables
Writes <out_dir>/structural_checks.json and exits with status 1 if any check fails. Exact reproduction of the
paper's table cells is a separate check that needs the archived analysis datasets (see README.md).
"""
import json
import math
import sys
from pathlib import Path

import pandas as pd

data_dir, out_dir, schema_path = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
schema = json.loads(schema_path.read_text(encoding="utf-8"))
checks = []


def check(name, ok, detail=""):
    checks.append({"check": name, "passed": bool(ok), "detail": detail})


for f, spec in schema.items():
    p = data_dir / f
    if not p.is_file():
        check(f"{f}: exists", False, str(p))
        continue
    d = pd.read_stata(p, convert_categoricals=False, convert_dates=False)
    missing = [c["name"] for c in spec["columns"] if c["name"] not in d.columns]
    check(f"{f}: schema columns present", not missing, ", ".join(missing))
    check(f"{f}: rows", len(d) > 0, f"{len(d)} rows")
    check(f"{f}: unique keys {spec['keys']}", not d.duplicated(spec["keys"]).any())
    if "ff30" in d:
        check(f"{f}: ff30 within 1-29", d.ff30.dropna().between(1, 29).all())
    if "tercile" in d:
        check(f"{f}: tercile within 1-3", d.tercile.dropna().isin([1, 2, 3]).all())
    rets = [c for c in d.columns if c == "r0" or c.endswith(("_1y", "_3y", "_5y"))]
    if rets:
        check(f"{f}: returns >= -1 (total loss = -1)", bool((d[rets].min() >= -1 - 1e-12).all()), ", ".join(rets))
    if spec["keys"] == ["ff30", "time_id"]:
        grid = d.ff30.nunique() * d.time_id.nunique()
        check(f"{f}: complete ff30 x quarter grid", grid == len(d), f"{d.ff30.nunique()} x {d.time_id.nunique()} vs {len(d)}")

expected = {"table1": None, "table2": None, "returns": ["Table3", "TableB1", "TableB2"],
            "panels": ["Table4", "Table5"], "revisions": ["Table6", "Table7"],
            "appendix_b": ["TableB3", "TableB4"], "ppml": ["TableIA1", "TableIA2", "TableIA3"]}
for name, tables in expected.items():
    p = out_dir / f"results_{name}.csv"
    if not p.is_file():
        check(f"results_{name}.csv: exists", False)
        continue
    r = pd.read_csv(p)
    check(f"results_{name}.csv: non-empty", len(r) > 0, f"{len(r)} rows")
    if tables:
        have = set(r["table"].astype(str))
        check(f"results_{name}.csv: tables present", all(t in have for t in tables), f"have {sorted(have)}")
        num = r[["b", "se"]].apply(pd.to_numeric, errors="coerce")
        check(f"results_{name}.csv: finite b and se", num.map(math.isfinite).all().all())
        check(f"results_{name}.csv: N positive", (pd.to_numeric(r["N"], errors="coerce") > 0).all())
med = out_dir / "table2_median_params.csv"
check("table2_median_params.csv: exists", med.is_file())

word = out_dir / "ipo_tables.docx"
if word.is_file():
    from docx import Document
    n = len(Document(word).tables)
    check("Word file: contains tables", n > 0, f"{n} tables")
else:
    check("Word file: exists", False, str(word))

ok = all(c["passed"] for c in checks)
summary = {"all_structural_checks_pass": ok, "checks": checks}
(out_dir / "structural_checks.json").write_text(json.dumps(summary, indent=1), encoding="utf-8")
for c in checks:
    if not c["passed"]:
        print("FAILED:", c["check"], c["detail"])
print(f"structural checks: {sum(c['passed'] for c in checks)} of {len(checks)} passed")
sys.exit(0 if ok else 1)
