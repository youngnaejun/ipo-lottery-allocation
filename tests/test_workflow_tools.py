"""Tests for the empirical workflow's portable helpers (no SAS, Stata or licensed data needed).

They cover placeholder filling (workflow/tools/materialise.py) and the synthetic
analysis-dataset generator. They do not test the SAS/Stata pipeline itself.
"""

import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / "workflow"
SCHEMA = WORKFLOW / "analysis" / "table_input_schema.json"
GENERATOR = WORKFLOW / "examples" / "make_synthetic_analysis_inputs.py"


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


materialise = load(WORKFLOW / "tools" / "materialise.py", "materialise")


def test_config_values_are_read_without_shell_expansion(tmp_path):
    config = tmp_path / "config.sh"
    config.write_text(
        "SAMPLE_END_YEAR=\"2024\"  # comment\nWRDS_DATA='C:\\data\\wrds'\n", encoding="utf-8"
    )
    expected = {"SAMPLE_END_YEAR": "2024", "WRDS_DATA": "C:\\data\\wrds"}
    assert materialise.read_config(config) == expected


def test_run_root_keeps_the_separator_style_of_each_reference():
    text = "r'@RUN_ROOT@\\ext' '@RUN_ROOT@/raw' '@RUN_ROOT@\\\\x' Path('@RUN_ROOT@')"
    out = materialise.fill(text, {}, "C:\\run")
    assert out == "r'C:\\run\\ext' 'C:/run/raw' 'C:\\\\run\\\\x' Path('C:/run')"


def test_settings_are_filled_and_missing_settings_stop():
    values = {"START": "1983", "END": "2024"}
    assert materialise.fill("between(@START@,@END@)", values, "C:\\run") == "between(1983,2024)"
    with pytest.raises(SystemExit):
        materialise.fill("@UNDEFINED_SETTING@", {}, "C:\\run")


def test_every_workflow_placeholder_is_defined_in_the_example_configuration():
    example = WORKFLOW / "config" / "workflow_config.example.sh"
    defined = set(materialise.read_config(example)) | {"RUN_ROOT"}
    used = set()
    for path in WORKFLOW.rglob("*"):
        if path.suffix in {".sas", ".py", ".do"} and path.name != "materialise.py":
            text = path.read_text(encoding="latin-1")
            used |= set(re.findall(r"@([A-Z][A-Z0-9_]*)@", text))
    assert used <= defined, sorted(used - defined)


def test_synthetic_analysis_inputs_follow_the_published_schema(tmp_path):
    args = [str(tmp_path), "--ipos", "200", "--start", "2000", "--end", "2004"]
    subprocess.run([sys.executable, str(GENERATOR), *args], check=True)
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    for name, spec in schema.items():
        d = pd.read_stata(tmp_path / name, convert_categoricals=False)
        assert list(d.columns) == [c["name"] for c in spec["columns"]]
        assert not d.duplicated(spec["keys"]).any()
        if spec["keys"] == ["ff30", "time_id"]:
            assert len(d) == 29 * 5 * 4
