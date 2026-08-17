"""Command-line interface for staged and end-to-end synthetic runs."""

import argparse
from pathlib import Path

import pandas as pd
import yaml

from ipo_lottery.analysis import summarise_allocation
from ipo_lottery.clean import clean_ipos
from ipo_lottery.features import add_lottery_features
from ipo_lottery.ingest import read_inputs
from ipo_lottery.link import resolve_links

STAGES = ("clean", "link", "features", "analysis", "all")


def _write(frame: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frame.to_csv(path, index=False)
    print(f"wrote {len(frame):,} rows -> {path}")


def run_pipeline(config_path: str | Path, stage: str = "all") -> None:
    """Run through the requested stage, materialising audit-friendly outputs."""
    with Path(config_path).open(encoding="utf-8") as stream:
        config = yaml.safe_load(stream)
    paths = config["paths"]
    output = Path(paths["output"])
    inputs = read_inputs(paths["input"])

    cleaned = clean_ipos(
        inputs["ipos"],
        nations=tuple(config["sample"]["nations"]),
        security_types=tuple(config["sample"]["security_types"]),
        start_year=int(config["sample"].get("start_year", 1975)),
        end_year=int(config["sample"].get("end_year", 2024)),
    )
    _write(cleaned, output / "cleaned_ipos.csv")
    if stage == "clean":
        return

    linked, unmatched = resolve_links(cleaned, inputs["link_candidates"])
    _write(linked, output / "linked_ipos.csv")
    _write(unmatched, output / "unmatched_ipos.csv")
    if stage == "link":
        return

    featured = add_lottery_features(
        linked,
        inputs["industry_returns"],
        threshold=float(config["features"]["lottery_threshold"]),
    )
    _write(featured, output / "featured_ipos.csv")
    if stage == "features":
        return

    summary = summarise_allocation(featured)
    _write(summary, output / "allocation_summary.csv")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ipo-lottery")
    subparsers = parser.add_subparsers(dest="command", required=True)
    run = subparsers.add_parser("run", help="run the synthetic research pipeline")
    run.add_argument("--stage", choices=STAGES, default="all")
    run.add_argument("--config", default="config/config.yaml")
    return parser


def main(argv: list[str] | None = None) -> None:
    args = build_parser().parse_args(argv)
    if args.command == "run":
        run_pipeline(args.config, args.stage)
