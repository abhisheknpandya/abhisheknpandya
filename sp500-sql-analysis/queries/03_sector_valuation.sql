-- Q3. Which sectors look expensive or cheap?
-- A simple average of P/E is distorted by tiny companies and loss-makers, so this also
-- computes the market-cap-weighted P/E (total market value / total earnings), which is how
-- index providers report it.
-- Skills: conditional aggregation, NULLIF, handling outliers and missing data

SELECT
    f.sector,
    COUNT(f.pe_ratio)                                                    AS companies_with_pe,
    ROUND(AVG(f.pe_ratio), 1)                                            AS simple_avg_pe,
    ROUND(SUM(f.market_cap) / SUM(f.market_cap / f.pe_ratio), 1)         AS cap_weighted_pe,
    ROUND(100.0 * SUM(f.market_cap * f.dividend_yield) / SUM(f.market_cap), 2) AS cap_weighted_div_yield_pct,
    ROUND(SUM(f.market_cap) / NULLIF(SUM(f.ebitda), 0), 1)               AS market_cap_to_ebitda
FROM issuers f
WHERE f.pe_ratio > 0          -- exclude loss-making companies (negative or missing P/E)
GROUP BY f.sector
ORDER BY cap_weighted_pe DESC;
