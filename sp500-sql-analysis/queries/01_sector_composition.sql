-- Q1. Which sectors make up the S&P 500, by number of companies and by market value?
-- Skills: a view that removes duplicate share classes, GROUP BY, window function over the whole result (SUM() OVER ())

SELECT
    c.sector,
    COUNT(*)                                              AS companies,
    ROUND(SUM(c.market_cap) / 1e12, 2)                    AS market_cap_trn,
    ROUND(100.0 * SUM(c.market_cap) / SUM(SUM(c.market_cap)) OVER (), 1) AS pct_of_index
FROM issuers c
WHERE c.market_cap IS NOT NULL
GROUP BY c.sector
ORDER BY market_cap_trn DESC;
