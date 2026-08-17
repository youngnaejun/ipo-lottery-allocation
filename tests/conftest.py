import pandas as pd
import pytest


@pytest.fixture
def raw_ipos() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "deal_id": 2,
                "issuer_name": "Alpha Labs",
                "offer_date": "2020-01-02",
                "cusip": "000001AA",
                "nation": "US",
                "security_type": "COMMON",
                "offer_price": 10.0,
                "shares_offered": 100,
                "industry_ff30": 5,
            },
            {
                "deal_id": 1,
                "issuer_name": "Alpha Labs",
                "offer_date": "2020-01-02",
                "cusip": "000001AB",
                "nation": "US",
                "security_type": "COMMON",
                "offer_price": 10.0,
                "shares_offered": 100,
                "industry_ff30": 5,
            },
            {
                "deal_id": 3,
                "issuer_name": "Beta Tech",
                "offer_date": "2020-02-03",
                "cusip": "000002AA",
                "nation": "CA",
                "security_type": "COMMON",
                "offer_price": 12.0,
                "shares_offered": 200,
                "industry_ff30": 6,
            },
            {
                "deal_id": 4,
                "issuer_name": "Gamma Unit",
                "offer_date": "2020-03-04",
                "cusip": "000003AA",
                "nation": "US",
                "security_type": "UNIT",
                "offer_price": 8.0,
                "shares_offered": 300,
                "industry_ff30": 7,
            },
        ]
    )

