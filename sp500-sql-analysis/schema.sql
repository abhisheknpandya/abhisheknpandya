-- S&P 500 analysis database schema (SQLite)

DROP VIEW IF EXISTS issuers;
DROP TABLE IF EXISTS financials;
DROP TABLE IF EXISTS companies;
DROP TABLE IF EXISTS market_history;

-- Current index members (source: Wikipedia via datasets/s-and-p-500-companies)
CREATE TABLE companies (
    symbol        TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    sector        TEXT NOT NULL,      -- GICS sector, e.g. 'Information Technology'
    sub_industry  TEXT,
    headquarters  TEXT,
    date_added    DATE,               -- date the company joined the index
    cik           INTEGER,            -- SEC company identifier
    founded       TEXT                -- free text, e.g. '1902' or '1886/1999'
);

-- Valuation snapshot per company (source: Yahoo Finance via datasets/s-and-p-500-companies-financials)
CREATE TABLE financials (
    symbol          TEXT PRIMARY KEY REFERENCES companies(symbol),
    price           REAL,
    pe_ratio        REAL,             -- price / earnings
    dividend_yield  REAL,             -- as a fraction: 0.025 = 2.5%
    eps             REAL,             -- earnings per share
    low_52w         REAL,
    high_52w        REAL,
    market_cap      REAL,             -- USD
    ebitda          REAL,             -- USD
    price_sales     REAL,
    price_book      REAL
);

-- Monthly index history since 1871 (source: Robert Shiller via datasets/s-and-p-500)
-- Values the source reports as 0 (not yet available) are stored as NULL.
CREATE TABLE market_history (
    month           DATE PRIMARY KEY, -- first day of the month
    sp500           REAL NOT NULL,    -- index level (monthly average price)
    dividend        REAL,             -- trailing 12-month dividends, index points
    earnings        REAL,             -- trailing 12-month earnings, index points
    cpi             REAL,             -- consumer price index
    long_rate       REAL,             -- 10-year US Treasury yield, %
    real_price      REAL,
    real_dividend   REAL,
    real_earnings   REAL,
    cape            REAL              -- Shiller cyclically adjusted P/E (PE10)
);

CREATE INDEX idx_companies_sector ON companies(sector);

-- One row per company (issuer). Alphabet, Fox and News Corp each have two share classes
-- listed separately, and the data source reports the WHOLE company's market cap on both
-- rows. Without this view their market value would be counted twice.
CREATE VIEW issuers AS
WITH ranked AS (
    SELECT
        c.symbol, c.name, c.sector, c.sub_industry, c.date_added,
        f.price, f.pe_ratio, f.dividend_yield, f.eps, f.low_52w, f.high_52w,
        f.market_cap, f.ebitda, f.price_sales, f.price_book,
        ROW_NUMBER() OVER (PARTITION BY c.cik ORDER BY f.market_cap DESC, c.symbol) AS share_class_rank
    FROM companies c
    JOIN financials f ON f.symbol = c.symbol
)
SELECT
    symbol,
    REPLACE(REPLACE(REPLACE(REPLACE(name, ' (Class A)', ''), ' (Class B)', ''), ' (Class C)', ''), '  ', ' ') AS name,
    sector, sub_industry, date_added, price, pe_ratio, dividend_yield, eps, low_52w, high_52w,
    market_cap, ebitda, price_sales, price_book
FROM ranked
WHERE share_class_rank = 1;
