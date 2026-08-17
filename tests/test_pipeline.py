from pathlib import Path

import yaml

from ipo_lottery.cli import run_pipeline
from tests.fixtures.make_synthetic import write_synthetic


def test_synthetic_pipeline_runs_end_to_end(tmp_path: Path):
    input_dir = tmp_path / "synthetic"
    output_dir = tmp_path / "processed"
    write_synthetic(input_dir)
    config = {
        "sample": {"nations": ["US"], "security_types": ["COMMON"]},
        "features": {"lottery_threshold": 0.20},
        "paths": {"input": str(input_dir), "output": str(output_dir)},
    }
    config_path = tmp_path / "config.yaml"
    config_path.write_text(yaml.safe_dump(config), encoding="utf-8")

    run_pipeline(config_path)

    assert (output_dir / "allocation_summary.csv").is_file()
    assert (output_dir / "unmatched_ipos.csv").is_file()

