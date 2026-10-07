"""Build sp500.db (SQLite) from the CSV files in data/."""

import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).parent
DB_PATH = ROOT / "sp500.db"


def load():
    companies = pd.read_csv(ROOT / "data/companies.csv").rename(columns={
        "Symbol": "symbol", "Security": "name", "GICS Sector": "sector",
        "GICS Sub-Industry": "sub_industry", "Headquarters Location": "headquarters",
        "Date added": "date_added", "CIK": "cik", "Founded": "founded",
    })

    financials = pd.read_csv(ROOT / "data/financials.csv").rename(columns={
        "Symbol": "symbol", "Price": "price", "Price/Earnings": "pe_ratio",
        "Dividend Yield": "dividend_yield", "Earnings/Share": "eps",
        "52 Week Low": "low_52w", "52 Week High": "high_52w", "Market Cap": "market_cap",
        "EBITDA": "ebitda", "Price/Sales": "price_sales", "Price/Book": "price_book",
    })
    # Keep only current index members; drop columns already held in companies
    financials = financials[financials["symbol"].isin(companies["symbol"])]
    financials = financials.drop(columns=["Name", "Sector", "SEC Filings"])

    history = pd.read_csv(ROOT / "data/market_history.csv").rename(columns={
        "Date": "month", "SP500": "sp500", "Dividend": "dividend", "Earnings": "earnings",
        "Consumer Price Index": "cpi", "Long Interest Rate": "long_rate",
        "Real Price": "real_price", "Real Dividend": "real_dividend",
        "Real Earnings": "real_earnings", "PE10": "cape",
    })
    # The source uses 0 for "not available"; NULL is the honest value in SQL
    value_cols = history.columns.drop(["month", "sp500"])
    history[value_cols] = history[value_cols].mask(history[value_cols] == 0)

    with sqlite3.connect(DB_PATH) as conn:
        conn.executescript((ROOT / "schema.sql").read_text())
        companies.to_sql("companies", conn, if_exists="append", index=False)
        financials.to_sql("financials", conn, if_exists="append", index=False)
        history.to_sql("market_history", conn, if_exists="append", index=False)
        for table in ["companies", "financials", "market_history"]:
            count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            print(f"{table:<15} {count:>5} rows")


if __name__ == "__main__":
    load()
