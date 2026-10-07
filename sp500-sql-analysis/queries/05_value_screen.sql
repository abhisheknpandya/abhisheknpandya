-- Q5. Value screen: large companies that are cheaper than their sector AND pay a higher dividend.
-- Skills: CTE with sector benchmarks joined back to each company

WITH sector_benchmark AS (
    SELECT
        f.sector,
        SUM(f.market_cap) / SUM(f.market_cap / f.pe_ratio)        AS sector_pe,
        SUM(f.market_cap * f.dividend_yield) / SUM(f.market_cap)  AS sector_yield
    FROM issuers f
    WHERE f.pe_ratio > 0
    GROUP BY f.sector
)
SELECT
    f.name,
    f.sector,
    ROUND(f.market_cap / 1e9)                        AS market_cap_bn,
    ROUND(f.pe_ratio, 1)                             AS pe_ratio,
    ROUND(b.sector_pe, 1)                            AS sector_pe,
    ROUND(100 * f.dividend_yield, 2)                 AS dividend_yield_pct,
    ROUND(100 * b.sector_yield, 2)                   AS sector_yield_pct
FROM issuers f
JOIN sector_benchmark b ON b.sector = f.sector
WHERE f.pe_ratio > 0
  AND f.pe_ratio < 0.75 * b.sector_pe          -- at least 25% cheaper than the sector
  AND f.dividend_yield > b.sector_yield        -- pays more than the sector
  AND f.market_cap > 50e9                      -- large companies only
ORDER BY f.pe_ratio / b.sector_pe   -- biggest discount to sector first
LIMIT 15;
