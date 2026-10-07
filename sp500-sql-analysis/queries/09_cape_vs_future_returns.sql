-- Q9. Does a high valuation (Shiller CAPE) predict lower returns over the next 10 years?
-- Each month is placed in one of five valuation buckets, then compared with the
-- real price return over the following 120 months.
-- Skills: LEAD() to look forward, NTILE() for quintiles, aggregation by bucket

WITH forward AS (
    SELECT
        month,
        cape,
        LEAD(real_price, 120) OVER (ORDER BY month) / real_price AS real_growth_10y,
        real_dividend / real_price                               AS dividend_yield
    FROM market_history
    WHERE real_price IS NOT NULL
),
bucketed AS (
    SELECT *, NTILE(5) OVER (ORDER BY cape) AS cape_quintile
    FROM forward
    WHERE cape IS NOT NULL AND real_growth_10y IS NOT NULL
)
SELECT
    cape_quintile,
    ROUND(MIN(cape), 1) || ' - ' || ROUND(MAX(cape), 1)                 AS cape_range,
    COUNT(*)                                                            AS months,
    ROUND(100 * AVG(POWER(real_growth_10y, 0.1) - 1), 1)                 AS avg_real_price_return_10y_pa,
    ROUND(100 * AVG(dividend_yield), 1)                                 AS avg_dividend_yield_pct,
    ROUND(100.0 * AVG(CASE WHEN real_growth_10y < 1 THEN 1 ELSE 0 END)) AS pct_of_months_losing_money_10y
FROM bucketed
GROUP BY cape_quintile
ORDER BY cape_quintile;
