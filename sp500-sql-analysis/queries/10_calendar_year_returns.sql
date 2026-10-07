-- Q10. What were the best and worst calendar years for the index price?
-- Uses December average levels (the data is monthly averages), so this is the
-- December-to-December change in the index, excluding dividends.
-- Skills: filtering on date parts, LAG(), RANK() for top and bottom N

WITH december AS (
    SELECT
        CAST(strftime('%Y', month) AS INTEGER)            AS year,
        sp500
    FROM market_history
    WHERE strftime('%m', month) = '12'
),
yearly AS (
    SELECT
        year,
        100 * (sp500 / LAG(sp500) OVER (ORDER BY year) - 1) AS price_change_pct
    FROM december
),
ranked AS (
    SELECT
        year,
        price_change_pct,
        RANK() OVER (ORDER BY price_change_pct DESC) AS best_rank,
        RANK() OVER (ORDER BY price_change_pct ASC)  AS worst_rank
    FROM yearly
    WHERE price_change_pct IS NOT NULL
)
SELECT
    CASE WHEN best_rank <= 5 THEN 'Best' ELSE 'Worst' END AS category,
    year,
    ROUND(price_change_pct, 1)                          AS price_change_pct
FROM ranked
WHERE best_rank <= 5 OR worst_rank <= 5
ORDER BY category, ABS(price_change_pct) DESC;
