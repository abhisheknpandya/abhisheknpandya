"""Clean the raw UK series, build Power BI tables, and inject the data into dashboard.html.

Outputs
- data/processed/monthly_indicators.csv  one row per month, one column per indicator
- powerbi/dim_date.csv, dim_indicator.csv, fact_observations.csv  star schema for Power BI
- dashboard.html  built from dashboard_template.html with the data embedded
"""

import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).parent
RAW = ROOT / "data/raw"


def month_start(dates):
    """Normalise any date (mid-month, quarter-end, 'YYYY-MM') to the first of its month."""
    return pd.to_datetime(dates).dt.to_period("M").dt.to_timestamp()


def load_series():
    house = pd.read_csv(RAW / "uk_house_prices_nationwide.csv")
    house = pd.DataFrame({
        "month": month_start(house["Date"]),
        "house_price_gbp": house["Price (All)"],
        "house_price_yoy_pct": house["Change (All)"],
    })

    gilt = pd.read_csv(RAW / "uk_gilt_10y_quarterly.csv")
    gilt = pd.DataFrame({"month": month_start(gilt["Date"]), "gilt_10y_pct": gilt["Rate"]})

    # The source quotes pounds per dollar; the market convention is dollars per pound ("cable")
    fx = pd.read_csv(RAW / "gbp_per_usd_monthly.csv")
    fx = pd.DataFrame({"month": month_start(fx["Date"]), "usd_per_gbp": 1 / fx["Exchange rate"]})

    gold = pd.read_csv(RAW / "gold_usd_monthly.csv")
    gold = pd.DataFrame({"month": month_start(gold["Date"]), "gold_usd_oz": gold["Price"]})

    brent = pd.read_csv(RAW / "brent_usd_monthly.csv")
    brent = pd.DataFrame({"month": month_start(brent["Date"]), "brent_usd_bbl": brent["Price"]})

    monthly = (
        house.merge(gilt, on="month", how="outer")
        .merge(fx, on="month", how="outer")
        .merge(gold, on="month", how="outer")
        .merge(brent, on="month", how="outer")
        .sort_values("month")
    )
    # Pound prices only exist where an exchange rate exists (from 1971)
    monthly["gold_gbp_oz"] = monthly["gold_usd_oz"] / monthly["usd_per_gbp"]
    monthly["brent_gbp_bbl"] = monthly["brent_usd_bbl"] / monthly["usd_per_gbp"]
    monthly = monthly[monthly["month"] >= "1953-01-01"]
    value_cols = monthly.columns.drop("month")
    monthly[value_cols] = monthly[value_cols].round(4)
    return monthly


INDICATORS = [
    # key, name, unit, frequency, source
    ("house_price_gbp", "UK average house price", "GBP", "Quarterly", "Nationwide via datasets/house-prices-uk"),
    ("house_price_yoy_pct", "UK house price annual change", "%", "Quarterly", "Nationwide via datasets/house-prices-uk"),
    ("gilt_10y_pct", "10-year UK gilt yield", "%", "Quarterly", "OECD via datasets/bond-yields-uk-10y"),
    ("usd_per_gbp", "Pound to US dollar", "USD per GBP", "Monthly", "Federal Reserve via datasets/exchange-rates"),
    ("gold_usd_oz", "Gold price in dollars", "USD per troy oz", "Monthly", "datasets/gold-prices"),
    ("gold_gbp_oz", "Gold price in pounds", "GBP per troy oz", "Monthly", "Derived: gold USD / USD per GBP"),
    ("brent_usd_bbl", "Brent crude in dollars", "USD per barrel", "Monthly", "EIA via datasets/oil-prices"),
    ("brent_gbp_bbl", "Brent crude in pounds", "GBP per barrel", "Monthly", "Derived: Brent USD / USD per GBP"),
]


def build_power_bi_tables(monthly):
    out = ROOT / "powerbi"
    dates = pd.DataFrame({"date": pd.date_range(monthly["month"].min(), monthly["month"].max(), freq="MS")})
    dates["year"] = dates["date"].dt.year
    dates["quarter"] = "Q" + dates["date"].dt.quarter.astype(str)
    dates["month_number"] = dates["date"].dt.month
    dates["month_name"] = dates["date"].dt.strftime("%b")
    dates["decade"] = (dates["year"] // 10 * 10).astype(str) + "s"
    dates.to_csv(out / "dim_date.csv", index=False, date_format="%Y-%m-%d")

    indicators = pd.DataFrame(INDICATORS, columns=["indicator_key", "indicator_name", "unit", "frequency", "source"])
    indicators.to_csv(out / "dim_indicator.csv", index=False)

    facts = monthly.melt(id_vars="month", var_name="indicator_key", value_name="value").dropna()
    facts = facts.rename(columns={"month": "date"}).sort_values(["indicator_key", "date"])
    facts.to_csv(out / "fact_observations.csv", index=False, date_format="%Y-%m-%d")
    print(f"Power BI tables: {len(dates)} dates, {len(indicators)} indicators, {len(facts):,} observations")


def build_dashboard(monthly):
    series = {}
    for key, *_ in INDICATORS:
        s = monthly[["month", key]].dropna()
        series[key] = [[d.strftime("%Y-%m"), float(v)] for d, v in zip(s["month"], s[key])]
    template = (ROOT / "dashboard_template.html").read_text()
    html = template.replace("/*__DATA__*/{}", json.dumps(series, separators=(",", ":")))
    # Standalone page: add the document shell so it opens correctly straight from disk
    html = (
        '<!doctype html>\n<html lang="en">\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n' + html
    )
    (ROOT / "dashboard.html").write_text(html)
    print(f"dashboard.html written ({len(html) / 1024:.0f} KB)")


if __name__ == "__main__":
    monthly = load_series()
    (ROOT / "data/processed").mkdir(exist_ok=True)
    monthly.to_csv(ROOT / "data/processed/monthly_indicators.csv", index=False, date_format="%Y-%m-%d")
    build_power_bi_tables(monthly)
    if (ROOT / "dashboard_template.html").exists():
        build_dashboard(monthly)
