-- Q6. When did today's members join the index, and how has its sector mix changed?
-- Skills: date functions, CASE bucketing, pivot with conditional aggregation

SELECT
    (CAST(strftime('%Y', date_added) AS INTEGER) / 10) * 10 || 's'           AS decade_added,
    COUNT(*)                                                                   AS companies,
    SUM(CASE WHEN sector = 'Information Technology' THEN 1 ELSE 0 END)         AS tech,
    SUM(CASE WHEN sector = 'Financials'             THEN 1 ELSE 0 END)         AS financials,
    SUM(CASE WHEN sector = 'Health Care'            THEN 1 ELSE 0 END)         AS health_care,
    SUM(CASE WHEN sector = 'Industrials'            THEN 1 ELSE 0 END)         AS industrials,
    SUM(CASE WHEN sector IN ('Energy', 'Utilities', 'Materials') THEN 1 ELSE 0 END) AS energy_utilities_materials
FROM companies
WHERE date_added IS NOT NULL
GROUP BY decade_added
ORDER BY decade_added;
