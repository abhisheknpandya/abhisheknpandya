-- Q7. What real (inflation-adjusted) total return did US stocks deliver in each decade?
-- Monthly total return = (price + dividend for the month) / last month's price, then
-- adjusted for inflation with CPI. Monthly returns are compounded with EXP(SUM(LN(...))).
-- Dividend and CPI data end in mid-2023, so the 2020s figure is a partial decade.
-- Skills: LAG(), multi-step CTEs, compounding with logarithms

WITH monthly AS (
    SELECT
        month,
        (sp500 + dividend / 12.0) / LAG(sp500) OVER (ORDER BY month)   AS nominal_growth,
        cpi / LAG(cpi) OVER (ORDER BY month)                           AS inflation_growth
    FROM market_history
    WHERE dividend IS NOT NULL AND cpi IS NOT NULL
),
by_decade AS (
    SELECT
        (CAST(strftime('%Y', month) AS INTEGER) / 10) * 10    AS decade,
        COUNT(*)                                              AS months,
        EXP(SUM(LN(nominal_growth)))                          AS nominal_multiple,
        EXP(SUM(LN(nominal_growth / inflation_growth)))       AS real_multiple
    FROM monthly
    WHERE nominal_growth IS NOT NULL
    GROUP BY decade
)
SELECT
    decade || 's'                                                          AS decade,
    months,
    ROUND(100 * (POWER(nominal_multiple, 12.0 / months) - 1), 1)           AS nominal_return_pa,
    ROUND(100 * (POWER(real_multiple,    12.0 / months) - 1), 1)           AS real_return_pa,
    ROUND(real_multiple, 2)                                                AS real_growth_of_1
FROM by_decade
ORDER BY decade;
