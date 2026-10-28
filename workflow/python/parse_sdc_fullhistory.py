"""Parse SDC New Issues Full History fields into an auditable deal-level file.

The seven Full History columns are semicolon-delimited parallel lists.  This
utility validates that alignment and exports only the first and last observed
tokens.  It deliberately does not construct ShareRevision: the last SDC
history token is not necessarily the actual IPO offer.  Final offer terms must
come from the SDC offer-level fields in the analysis data.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import pandas as pd


HISTORY_COLUMNS = {
    "dates": "Full History Filing Date",
    "total": "Full History Total Shares Filed This Market",
    "primary": "Full History Primary Shares Filed This Market",
    "overallot": "Full History Overallotment Shares Filed This Market",
    "high": "Full History High File Price (USD)",
    "low": "Full History Low File Price (USD)",
    "mid": "Full History Mid File Price (USD)",
}

BASE_COLUMNS = {
    "deal_num": "SDC Deal Number",
    "cusip6": "Issuer/Borrower 6-digit CUSIP",
    "cusip9": "Issuer/Borrower 9-digit CUSIP",
    "ticker": "Issuer/Borrower Ticker Symbol",
    "issuer_name": "Issuer/Borrower Name Full",
    "fdate": "Dates: Filing Date",
    "idate": "Dates: Issue Date",
    "status": "Transaction Status",
}


def split_cell(value: object) -> list[str]:
    """Split an SDC history cell while preserving empty aligned tokens."""
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return []
    text = str(value).strip()
    if not text or text.lower() == "nan":
        return []
    return [part.strip() for part in text.split(";")]


def normalize_id(value: object) -> str:
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return ""
    text = str(value).strip()
    return text[:-2] if text.endswith(".0") else text


def parse_number(value: str | None) -> float | None:
    if value is None:
        return None
    text = value.strip().replace(",", "").replace("$", "")
    if not text or text.lower() in {"na", "n/a", "nan", "."}:
        return None
    if text.startswith("(") and text.endswith(")"):
        text = f"-{text[1:-1]}"
    try:
        return float(text)
    except ValueError:
        return None


def parse_date(value: object) -> str:
    date = pd.to_datetime(value, errors="coerce")
    return "" if pd.isna(date) else date.strftime("%Y-%m-%d")


def first_last(parts: list[str], numeric: bool = True) -> tuple[object, object]:
    if not parts:
        return (None, None) if numeric else ("", "")
    if numeric:
        return parse_number(parts[0]), parse_number(parts[-1])
    return parse_date(parts[0]), parse_date(parts[-1])


def parse_workbook(input_path: Path, sheet: str) -> pd.DataFrame:
    data = pd.read_excel(input_path, sheet_name=sheet, header=2)
    required = set(BASE_COLUMNS.values()) | set(HISTORY_COLUMNS.values())
    missing = sorted(required.difference(data.columns))
    if missing:
        raise ValueError(f"Missing required workbook columns: {missing}")

    output_rows: list[dict[str, object]] = []
    misaligned: list[str] = []

    for _, row in data.iterrows():
        deal_num = normalize_id(row[BASE_COLUMNS["deal_num"]])
        histories = {
            name: split_cell(row[column]) for name, column in HISTORY_COLUMNS.items()
        }
        n_filings = len(histories["dates"])
        if n_filings:
            lengths = {len(values) for values in histories.values()}
            if len(lengths) != 1:
                misaligned.append(deal_num)

        date_first, date_last = first_last(histories["dates"], numeric=False)
        total_first, total_last = first_last(histories["total"])
        primary_first, primary_last = first_last(histories["primary"])
        overallot_first, overallot_last = first_last(histories["overallot"])
        mid_first, mid_last = first_last(histories["mid"])
        low_first, low_last = first_last(histories["low"])
        high_first, high_last = first_last(histories["high"])

        output_rows.append(
            {
                "sdc_deal": deal_num,
                "cusip6": normalize_id(row[BASE_COLUMNS["cusip6"]]),
                "cusip9": normalize_id(row[BASE_COLUMNS["cusip9"]]),
                "ticker": normalize_id(row[BASE_COLUMNS["ticker"]]),
                "issuer_name": str(row[BASE_COLUMNS["issuer_name"]]).strip(),
                "fdate": parse_date(row[BASE_COLUMNS["fdate"]]),
                "idate": parse_date(row[BASE_COLUMNS["idate"]]),
                "status": str(row[BASE_COLUMNS["status"]]).strip(),
                "n_filings": n_filings,
                "fh_first_date": date_first,
                "fh_last_date": date_last,
                "tot_first": total_first,
                "tot_last": total_last,
                "pri_first": primary_first,
                "pri_last": primary_last,
                "ovr_first": overallot_first,
                "ovr_last": overallot_last,
                "mid_first": mid_first,
                "mid_last": mid_last,
                "lo_first": low_first,
                "lo_last": low_last,
                "hi_first": high_first,
                "hi_last": high_last,
            }
        )

    if misaligned:
        preview = ", ".join(misaligned[:10])
        raise ValueError(
            f"Full History list lengths are misaligned for {len(misaligned)} deals: "
            f"{preview}"
        )

    output = pd.DataFrame(output_rows)
    if output["sdc_deal"].eq("").any():
        raise ValueError("Blank SDC Deal Number encountered")
    if output["sdc_deal"].duplicated().any():
        duplicates = output.loc[output["sdc_deal"].duplicated(), "sdc_deal"].head()
        raise ValueError(f"Duplicate SDC Deal Number(s): {duplicates.tolist()}")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="SDC .xlsx extract")
    parser.add_argument("--output", type=Path, required=True, help="Parsed .csv output")
    parser.add_argument("--sheet", default="Request 4", help="Workbook data sheet")
    args = parser.parse_args()

    parsed = parse_workbook(args.input, args.sheet)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    parsed.to_csv(args.output, index=False, encoding="utf-8")

    has_history = parsed["n_filings"].gt(0)
    first_matches = parsed.loc[has_history, "fh_first_date"].eq(
        parsed.loc[has_history, "fdate"]
    )
    print(f"Rows: {len(parsed):,}")
    print(f"Unique deals: {parsed['sdc_deal'].nunique():,}")
    print(f"Deals with Full History: {has_history.sum():,}")
    print(
        "First history date equals filing date: "
        f"{first_matches.sum():,}/{has_history.sum():,} "
        f"({first_matches.mean():.1%})"
    )
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()
