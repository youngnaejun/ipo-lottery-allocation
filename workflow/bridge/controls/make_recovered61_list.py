"""Write the list of IPOs recovered by the filing-link rule (Recovered61_audit_records.csv).
Applies the approval rule coded in restore_ws2_61.py to a link-audit JSON:
next CRSP market day == first CRSP date, CRSP first date == SDC listing date,
no monthly CRSP record before issue, and no validated same-event deal."""
import json, sys
import pandas as pd
recs = json.loads(open(sys.argv[1], encoding="utf-8").read())["records"]
keep = [r for r in recs if r["next_market_day_match"] and r["CRSP_matches_SDC_listing_date"]
        and not r["monthly_prior_to_issue"] and not r["validated_same_event_deals"]]
assert @PAPER_CHECKS@ == 0 or len(keep) == 61, len(keep)
df = pd.DataFrame(keep)
df.to_csv(sys.argv[2], index=False)
print(len(df), "deals")
