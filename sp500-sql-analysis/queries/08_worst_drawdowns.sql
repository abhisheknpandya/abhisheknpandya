-- Q8. What were the five worst bear markets in real (inflation-adjusted) terms,
-- and how long did they take to recover?
-- Skills: running MAX() window, "gaps and islands" grouping to identify episodes

WITH running AS (
    SELECT
        month,
        real_price,
        MAX(real_price) OVER (ORDER BY month ROWS UNBOUNDED PRECEDING) AS peak_so_far
    FROM market_history
    WHERE real_price IS NOT NULL
),
episodes AS (
    -- each new all-time high starts a new episode; months below it belong to that episode
    SELECT
        *,
        SUM(CASE WHEN real_price >= peak_so_far THEN 1 ELSE 0 END)
            OVER (ORDER BY month ROWS UNBOUNDED PRECEDING) AS episode_id
    FROM running
),
summary AS (
    SELECT
        episode_id,
        MIN(month)                                  AS peak_month,
        MIN(real_price / peak_so_far) - 1           AS max_drawdown,
        COUNT(*) - 1                                AS months_below_peak
    FROM episodes
    GROUP BY episode_id
),
troughs AS (
    SELECT e.episode_id, MIN(e.month) AS trough_month
    FROM episodes e
    JOIN summary s ON s.episode_id = e.episode_id
    WHERE e.real_price / e.peak_so_far - 1 = s.max_drawdown
    GROUP BY e.episode_id
)
SELECT
    s.peak_month,
    t.trough_month,
    ROUND(100 * s.max_drawdown, 1)                  AS real_fall_pct,
    ROUND(s.months_below_peak / 12.0, 1)            AS years_to_new_real_high
FROM summary s
JOIN troughs t ON t.episode_id = s.episode_id
ORDER BY s.max_drawdown
LIMIT 5;
