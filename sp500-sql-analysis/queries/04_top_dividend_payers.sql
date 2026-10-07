-- Q4. What are the three highest-yielding dividend stocks in each sector?
-- Skills: "top N per group" with ROW_NUMBER() OVER (PARTITION BY ...)

WITH ranked AS (
    SELECT
        f.sector,
        f.name,
        f.dividend_yield,
        f.pe_ratio,
        ROW_NUMBER() OVER (PARTITION BY f.sector ORDER BY f.dividend_yield DESC) AS rank_in_sector
    FROM issuers f
    WHERE f.dividend_yield > 0
)
SELECT
    sector,
    rank_in_sector,
    name,
    ROUND(100 * dividend_yield, 2) AS dividend_yield_pct,
    ROUND(pe_ratio, 1)             AS pe_ratio
FROM ranked
WHERE rank_in_sector <= 3
ORDER BY sector, rank_in_sector;
