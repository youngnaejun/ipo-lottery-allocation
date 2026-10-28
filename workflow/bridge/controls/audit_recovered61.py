"""Read-only source audit and reconstruction of 61 recovered IPOs.
Preserve original definitions; do not substitute monthly for daily IPO returns.
"""
from pathlib import Path
import json,re,hashlib
import pandas as pd
import numpy as np

R=Path(__file__).resolve().parents[1]; P=Path('@RUN_ROOT@')
O=R/'results/recovered61'; O.mkdir(exist_ok=True,parents=True)
QA={}
def sas(name,folder='master'):
    d=pd.read_sas(P/folder/(name+'.sas7bdat'))
    for c in d.select_dtypes(include=['object']).columns:
        d[c]=d[c].map(lambda x:x.decode('cp1252').strip() if isinstance(x,bytes) else x)
    if 'deal_num' in d:d['deal_num']=pd.to_numeric(d.deal_num,errors='raise')
    return d
def clean(x):
    x=str(x).upper().strip().replace('\t',' ').replace('\xa0',' ')
    x=re.sub(r"[.,']",'',x)
    for t in [' INCORPORATED',' INC',' LLC',' LTD',' LP',' CORPORATION',' CORP',' COMPANY',' CO']:x=x.replace(t,' ')
    x=x.replace('&','AND')
    for t in [' SECURITIES',' CAPITAL MARKETS',' INVESTMENT BANKING']:x=x.replace(t,' ')
    return ' '.join(re.sub(r'\(.*?\)','',x).split())
def rankcol(y):
    for hi,col in [(1984,'Rank8084'),(1991,'Rank8591'),(2000,'Rank9200'),(2004,'Rank0104'),(2007,'Rank0507'),(2009,'Rank0809'),(2011,'Rank1011'),(2017,'Rank1217'),(2020,'Rank1820'),(2022,'Rank2122'),(2023,'Rank23'),(2024,'Rank24'),(2025,'Rank25'),(2026,'Rank26')]:
        if 1975<=y<=hi:return col
def audit_equal(label,actual,expected,tol=1e-10):
    ok=np.isclose(actual,expected,rtol=0,atol=tol,equal_nan=True)
    QA[label]={'N':len(ok),'match':int(ok.sum()),'max_abs_difference':float(np.nanmax(np.abs(np.asarray(actual)-np.asarray(expected))))}
    return ok

def main():
    base=sas('analysis_full2')
    ids=pd.read_csv(R/'results/table1/Recovered61_audit_records.csv').deal_key.astype('int64')
    s=sas('sdc_clean'); link=sas('filing_outcomes_linked')
    new=s[s.deal_num.isin(ids)].copy()
    lc=['deal_num','PERMNO','crsp_first_date','SHRCD','EXCHCD','ff30','absprc','ret_first','SHROUT']
    new=new.merge(link[lc],on='deal_num',validate='one_to_one')
    assert len(new)==len(ids) and (@PAPER_CHECKS@==0 or len(new)==61) and not new.PERMNO.isin(base.PERMNO).any()
    new['iyearmonth']=new.idate.dt.to_period('M').dt.to_timestamp()
    new['r0']=(new.absprc-new.oprc)/new.oprc
    new['share_overhang']=np.log(new.SHROUT*1000/new.primary_shares).where(new.SHROUT.gt(0)&new.primary_shares.gt(0))
    for name,values in [('NASDAQ',['Nasdaq','Sm Cap Mkt','OTC']),('NYSE',['New York Stock Exchange']),('AMEX',['American','NYSE Amex','NYSE MKT','NYSE Arca'])]:
        new[name]=new.exchange.isin(values).astype(int)
    new['main_sample_flag']=((new.NASDAQ+new.NYSE+new.AMEX>0)&new.spac_flag.str.upper().ne('TRUE')).astype(int)
    new['passes_universe_filter']=new.ff30.notna()&new.ff30.ne(30)&new.ipo_year.between(@SAMPLE_START_YEAR@,@SAMPLE_END_YEAR@)
    QA['screens']={'N':len(new),'universe_pass':int(new.passes_universe_filter.sum()),'main_sample_flag':int(new.main_sample_flag.sum()),'r0_above_7_35':int(new.r0.gt(7.35).sum()),'r0_missing':int(new.r0.isna().sum()),'unique_permno':int(new.PERMNO.nunique())}
    # Scaling is deterministic within issue year, not CPI. Verify existing ratios.
    ratios=base.proceeds_adj1975/base.proceeds_mil
    factor=ratios.groupby(base.ipo_year).first()
    assert np.allclose(ratios,base.ipo_year.map(factor),equal_nan=True,rtol=1e-12)
    new['proceeds_adj1975']=new.proceeds_mil*new.ipo_year.map(factor)
    new['lnproceeds_adj1975']=np.log(new.proceeds_adj1975.where(new.proceeds_adj1975.gt(0)))
    # Exact industry/month lookup reproduces every old IPO's skewness.
    sk=sas('exp_skew_panel').rename(columns={'yearmonth':'iyearmonth'})
    for v in ['skew1','skew5']:
        lookup=sk.set_index(['ff30','iyearmonth'])[v]
        audit_equal('baseline_'+v,base.set_index(['ff30','iyearmonth']).index.map(lookup),base[v])
        new[v]=new.set_index(['ff30','iyearmonth']).index.map(lookup)
    # Coskewness is deterministic within the same industry/issue month.
    assert base.groupby(['ff30','iyearmonth']).coskewness.nunique().max()==1
    lookup=base.groupby(['ff30','iyearmonth']).coskewness.first()
    new['coskewness']=new.set_index(['ff30','iyearmonth']).index.map(lookup)
    new['coskewness_source']=np.where(new.coskewness.notna(),'identical FF30 and issue-month baseline value','unavailable industry-month daily-regression result')
    # Ritter: exact CUSIP6, closest Ritter date, as source SAS.
    age=sas('ipo_age2','raw')
    def ages(d):
        x=d[['PERMNO','cusip_new','idate']].copy();x['key']=x.cusip_new.str[:6]
        x=x.merge(age[['cusip6_ritter','idate_ritter','age_ritter','Internet','Founding']],left_on='key',right_on='cusip6_ritter',how='left')
        x['gap']=(x.idate-x.idate_ritter).abs().dt.days.fillna(99999)
        return x.sort_values(['PERMNO','gap'],kind='stable').drop_duplicates('PERMNO').set_index('PERMNO')
    aa=ages(base); audit_equal('baseline_age',base.PERMNO.map(aa.age_ritter),base.age_ritter)
    audit_equal('baseline_internet',base.PERMNO.map(aa.Internet),base.internet)
    aa=ages(new)
    new['age_ritter']=new.PERMNO.map(aa.age_ritter);new['internet']=new.PERMNO.map(aa.Internet)
    # Exact original underwriter name bridge, issue-year rank blocks.
    uw=sas('underwriter','raw'); ranks=[c for c in uw if c.startswith('Rank')]
    uw[ranks]=uw[ranks].replace(-9,np.nan);uw['key']=uw.Underwriter_Name.map(clean)
    uw['score']=uw[ranks].sum(axis=1)
    uw=uw.sort_values(['key','score'],ascending=[True,False],kind='stable').drop_duplicates('key').set_index('key')
    source=(P/'sas/03_stage1_underwriter_matching.sas').read_text(encoding='utf-8-sig')
    bridge=dict(re.findall(r'sdc_name\s*=\s*"([^"]+)";\s*ritter_name\s*=\s*"([^"]+)";',source))
    def ranks_for(d):
        result=[]
        for row in d.itertuples():
            vals=[]
            for token in str(row.lead_managers_raw).split(';'):
                key=clean(token);key=bridge.get(key,key);col=rankcol(row.ipo_year)
                if key in uw.index and col and col in uw.columns:
                    v=uw.at[key,col]
                    if pd.notna(v): vals.append(v)
            avg=np.mean(vals) if vals else np.nan;mx=max(vals) if vals else np.nan
            result.append([mx,avg,float(mx>=8) if vals else np.nan,float(avg>=8) if vals else np.nan])
        return pd.DataFrame(result,columns=['uw_rank','uw_rank_ave','TT','TT_ave'],index=d.index)
    rr=ranks_for(base)
    for c in rr:
        ok=audit_equal('baseline_'+c,rr[c],base[c])
        z=base.loc[~ok,['deal_num','ipo_year','lead_managers_raw',c]].copy();z['rebuilt']=rr.loc[~ok,c];z.to_csv(O/('UW_mismatch_'+c+'.csv'),index=False)
    rr=ranks_for(new)
    for c in rr:new[c]=rr[c]
    sent=sas('umcsent2','raw').set_index('yearmonth').lagmcsi
    new['lagmcsi']=new.iyearmonth.map(sent)
    market=sas('crsp_index_daily').sort_values('DATE')
    def mr(date):
        v=market.loc[market.DATE.lt(date),'logewretd'].tail(15)
        return np.expm1(v.sum()) if len(v)==15 else np.nan
    oldmr=base.idate.map({t:mr(t) for t in base.idate.unique()})
    audit_equal('baseline_market_return',oldmr,base.lagcummktret)
    new['lagcummktret']=new.idate.map(mr)
    # Match original industry definitions exactly before filling new months.
    for v,n,c in [('ind_ret','ff30_ret','in_ewlagmret'),('ind_mom','ff30_mom','ind_mom'),('ind_vol','ff30_ivol','lagin_ivol'),('ind_turn','ff30_turnover','in_lagturnover')]:
        lookup=sas(n).set_index(['ff30','yearmonth'])[c]
        av=base.set_index(['ff30','iyearmonth']).index.map(lookup)
        assert audit_equal('baseline_'+v,av,base[v]).all()
        new[v]=new.set_index(['ff30','iyearmonth']).index.map(lookup)
    mid=(new.file_price_low+new.file_price_high)/2
    amended=(new.amended_low+new.amended_high)/2
    mid=mid.where(new.file_price_low.gt(0)&new.file_price_high.gt(0),amended.where(new.amended_low.gt(0)&new.amended_high.gt(0)&amended.between(new.oprc*.1,new.oprc*10)))
    new['price_adj']=(new.oprc-mid).abs()/mid
    # Recompute IPO volatility for BOTH existing and newly added IPOs.
    def volatility(target,pool):
        by={}
        for m in target.iyearmonth.unique():
            lo=pd.Timestamp(m)-pd.DateOffset(months=3)
            z=pool.loc[pool.iyearmonth.ge(lo)&pool.iyearmonth.lt(m)]
            by[m]=z.r0.std(ddof=1)
        return target.iyearmonth.map(by)
    audit_equal('baseline_ipo_vol',volatility(base,base),base.ipo_vol)
    combined=pd.concat([base,new],ignore_index=True)
    combined['restored61']=combined.PERMNO.isin(new.PERMNO).astype(int)
    combined['ipo_vol']=volatility(combined,combined)
    new=combined.loc[combined.restored61.eq(1)].copy()
    QA['old_IPOs_volatility_changed']=int(np.sum(np.abs(combined.iloc[:len(base)].ipo_vol.to_numpy()-base.ipo_vol.to_numpy())>1e-10))
    vars=['skew1','coskewness','age_ritter','internet','NASDAQ','NYSE','lnproceeds_adj1975','share_overhang','pure_primary','VB','TT','TT_ave','uw_rank_ave','lagmcsi','lagcummktret','ipo_vol','price_adj','ind_ret','ind_mom','ind_vol','ind_turn','r0','r2_bhar_1y','r2_bhar_3y','r2_bhar_5y','r3_bhar_1y','r3_bhar_3y','r3_bhar_5y']
    coverage=pd.DataFrame([dict(variable=v,available=int(new[v].notna().sum()),missing=int(new[v].isna().sum())) for v in vars])
    new.to_csv(O/'Recovered61_variables.csv',index=False)
    combined.to_pickle(O/'Expanded_analysis.pkl')
    base.to_pickle(O/'Baseline_analysis.pkl')
    coverage.to_csv(O/'Coverage.csv',index=False)
    (O/'Construction_QA.json').write_text(json.dumps(QA,indent=2),encoding='utf8')
    print(json.dumps(QA,indent=2));print(coverage.to_string(index=False))

if __name__=='__main__':main()
