import pandas as pd

from ipo_lottery.link import resolve_links


def test_resolves_expected_matches_and_reports_unmatched():
    ipos = pd.DataFrame(
        {"deal_id": [1, 2, 3], "cusip": ["AAA", "BBB", "CCC"], "issuer_name": ["A", "B", "C"]}
    )
    candidates = pd.DataFrame(
        {
            "deal_id": [1, 1, 2],
            "candidate_cusip": ["AAA", "AAA", "WRONG"],
            "permno": [101, 102, 201],
            "link_score": [80, 95, 100],
        }
    )

    linked, unmatched = resolve_links(ipos, candidates)

    assert len(linked) == 1
    assert linked.loc[0, "permno"] == 102
    assert unmatched["deal_id"].tolist() == [2, 3]
    assert unmatched["unmatched_reason"].eq("no exact CUSIP candidate").all()

