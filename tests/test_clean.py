import pytest

from ipo_lottery.clean import clean_ipos


def test_filters_and_collapses_duplicate_issuer_dates(raw_ipos):
    cleaned = clean_ipos(raw_ipos)

    assert cleaned["deal_id"].tolist() == [1]
    assert not cleaned.duplicated(["issuer_name", "offer_date"]).any()


def test_missing_required_value_raises_instead_of_propagating(raw_ipos):
    raw_ipos.loc[0, "offer_price"] = None

    with pytest.raises(ValueError, match="Missing values in required fields"):
        clean_ipos(raw_ipos)


def test_invalid_date_raises(raw_ipos):
    raw_ipos.loc[0, "offer_date"] = "not-a-date"

    with pytest.raises(ValueError):
        clean_ipos(raw_ipos)

