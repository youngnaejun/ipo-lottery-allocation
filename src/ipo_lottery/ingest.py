"""Read locally supplied inputs without embedding vendor credentials."""

from pathlib import Path

import pandas as pd

REQUIRED_INPUTS = {
    "ipos": "ipos.csv",
    "link_candidates": "link_candidates.csv",
    "industry_returns": "industry_returns.csv",
}


def read_inputs(input_dir: str | Path) -> dict[str, pd.DataFrame]:
    """Read the three pipeline inputs from a local, git-ignored directory."""
    root = Path(input_dir)
    missing = [filename for filename in REQUIRED_INPUTS.values() if not (root / filename).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing required input files in {root}: {', '.join(missing)}")
    return {name: pd.read_csv(root / filename) for name, filename in REQUIRED_INPUTS.items()}

