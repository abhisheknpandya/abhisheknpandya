# Rebuild this dashboard in Power BI

This folder holds the same data as the web dashboard, shaped as a **star schema**: one fact table of observations, plus date and indicator dimension tables. That's the model Power BI works best with. Following these steps takes about an hour and gives you a `.pbix` file for your portfolio.

## 1. The data model

| Table | Rows | Role | Key columns |
|---|---|---|---|
| `fact_observations.csv` | 3,912 | Fact: one value per indicator per month | `date`, `indicator_key`, `value` |
| `dim_date.csv` | 885 | Date dimension, Jan 1953 to Sep 2026 | `date`, `year`, `quarter`, `month_name`, `decade` |
| `dim_indicator.csv` | 8 | What each series is | `indicator_key`, `indicator_name`, `unit`, `frequency`, `source` |

## 2. Load and model the data

1. **Home → Get data → Text/CSV** and load all three files.
2. In Power Query, check the types: `date` = Date, `value` = Decimal number, `year` and `month_number` = Whole number. Then click **Close & Apply**.
3. In **Model view**, create the relationships (Power BI may detect them automatically):
   - `dim_date[date]` 1 → * `fact_observations[date]`
   - `dim_indicator[indicator_key]` 1 → * `fact_observations[indicator_key]`
4. Select `dim_date` and choose **Table tools → Mark as date table**, with `date` as the date column.
5. Select `dim_date[month_name]` and choose **Sort by column → month_number**, so months sort Jan to Dec instead of alphabetically.

## 3. DAX measures

Create a `_Measures` table (**Home → Enter data**, then load an empty table) and add these measures.

```dax
Value = AVERAGE ( fact_observations[value] )

House Price =
CALCULATE ( [Value], dim_indicator[indicator_key] = "house_price_gbp" )

Gilt Yield % =
CALCULATE ( [Value], dim_indicator[indicator_key] = "gilt_10y_pct" )

USD per GBP =
CALCULATE ( [Value], dim_indicator[indicator_key] = "usd_per_gbp" )

Gold in GBP =
CALCULATE ( [Value], dim_indicator[indicator_key] = "gold_gbp_oz" )

-- Latest available value, whatever the frequency of the series (for KPI cards)
Latest Value =
VAR LastDate =
    CALCULATE ( MAX ( fact_observations[date] ), REMOVEFILTERS ( dim_date ) )
RETURN
    CALCULATE ( [Value], dim_date[date] = LastDate )

Latest Date =
CALCULATE ( MAX ( fact_observations[date] ), REMOVEFILTERS ( dim_date ) )

-- Change on a year earlier, in %
YoY % =
VAR Curr = [Value]
VAR Prev = CALCULATE ( [Value], DATEADD ( dim_date[date], -12, MONTH ) )
RETURN
    DIVIDE ( Curr - Prev, Prev )

-- Index a series to 100 at the first date in the current filter (gold £ vs $ chart)
Indexed (Start = 100) =
VAR FirstDate =
    CALCULATE ( MIN ( fact_observations[date] ), ALLSELECTED ( dim_date ) )
VAR FirstValue =
    CALCULATE ( [Value], dim_date[date] = FirstDate )
RETURN
    DIVIDE ( [Value], FirstValue ) * 100

-- Long-run growth rate between the first and last value in view
CAGR % =
VAR FirstDate = CALCULATE ( MIN ( fact_observations[date] ), ALLSELECTED ( dim_date ) )
VAR LastDate  = CALCULATE ( MAX ( fact_observations[date] ), ALLSELECTED ( dim_date ) )
VAR FirstValue = CALCULATE ( [Value], dim_date[date] = FirstDate )
VAR LastValue  = CALCULATE ( [Value], dim_date[date] = LastDate )
VAR Years = DATEDIFF ( FirstDate, LastDate, DAY ) / 365.25
RETURN
    POWER ( DIVIDE ( LastValue, FirstValue ), 1 / Years ) - 1
```

Format `Gilt Yield %` as a decimal number with 2 places. Format `YoY %` and `CAGR %` as percentages. Format `House Price` and `Gold in GBP` as currency (£).

## 4. Build the report page

Match the web version's layout:

| Visual | Fields | Settings |
|---|---|---|
| **Slicer** (top right) | `dim_date[year]` | Style: Between (a range slider). This replaces the All / 25 / 10 / 5 year buttons. |
| **5 × Card (new)** | `Latest Value` + `YoY %` | Filter each card to one indicator in the Filters pane: house price, gilt yield, USD per GBP, Brent in £, gold in £ |
| **Line chart**: house price | X: `dim_date[date]`, Y: `House Price` | |
| **Clustered column**: annual change | X: `dim_date[date]`, Y: `Value`, filtered to `house_price_yoy_pct` | Conditional formatting: columns red when the value is below 0 |
| **Line chart**: gilt yield | X: `dim_date[date]`, Y: `Gilt Yield %` | Add constant line at 0 |
| **Line chart**: pound to dollar | X: `dim_date[date]`, Y: `USD per GBP` | |
| **Line chart**: gold £ vs $ | X: `dim_date[date]`, Y: `Indexed (Start = 100)`, Legend: `dim_indicator[indicator_name]` | Filter to `gold_gbp_oz` and `gold_usd_oz` |
| **Text box** | Key findings | Copy from the web dashboard |

## 5. Finishing touches

- **View → Themes:** pick a clean theme, or import a JSON theme using blue `#2A78D6` and orange `#EB6834`, the same colour-blind-safe pair as the web version.
- **Tooltips:** on by default. Add `dim_indicator[source]` to the tooltip fields so readers can see where each number comes from.
- **Publish:** File → Publish to Power BI Service (needs a work or school account), or save the `.pbix` and add screenshots to this folder.

## Interview talking points

- **Why a star schema?** One narrow fact table and small dimension tables keep the model fast and make DAX time intelligence (`DATEADD`, `SAMEPERIODLASTYEAR`) work properly.
- **Why a separate date table?** Time-intelligence functions need a continuous date table marked as such. The facts have gaps (quarterly series), but the date dimension doesn't.
- **Why long format (`indicator_key`, `value`) instead of one column per indicator?** New indicators can be added as rows without changing the model or the measures.
