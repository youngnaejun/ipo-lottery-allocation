from ipo_lottery.audit import find_violations


def test_repository_audit_rejects_vendor_data_and_credentials():
    candidates = [
        "README.md",
        "src/clean.py",
        "data/raw/crsp.sas7bdat",
        "analysis/sample.dta",
        ".env",
    ]

    assert find_violations(candidates) == [
        ".env",
        "analysis/sample.dta",
        "data/raw/crsp.sas7bdat",
    ]


def test_repository_audit_allows_synthetic_generator_source():
    assert find_violations(["tests/fixtures/make_synthetic.py"]) == []

