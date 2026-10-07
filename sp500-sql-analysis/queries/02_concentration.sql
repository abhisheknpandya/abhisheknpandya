-- Q2. How concentrated is the index? How much of it do the biggest companies represent?
-- Skills: CTE, ROW_NUMBER(), running total with SUM() OVER (ORDER BY ...)

WITH ranked AS (
    SELECT
        c.name,
        c.sector,
        c.market_cap,
        ROW_NUMBER() OVER (ORDER BY c.market_cap DESC) AS size_rank
    FROM issuers c
    WHERE c.market_cap IS NOT NULL
)
SELECT
    size_rank,
    name,
    sector,
    ROUND(market_cap / 1e9)                                                         AS market_cap_bn,
    ROUND(100.0 * market_cap / SUM(market_cap) OVER (), 2)                           AS pct_of_index,
    ROUND(100.0 * SUM(market_cap) OVER (ORDER BY size_rank) / SUM(market_cap) OVER (), 1) AS cumulative_pct
FROM ranked
ORDER BY size_rank
LIMIT 15;
