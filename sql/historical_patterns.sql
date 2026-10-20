-- ============================================================
-- Historical Spending Pattern Gold
--
-- Purpose
--   Build monthly historical spending patterns for completed
--   fiscal years prior to the current reporting year.
--
-- Grain
--   fiscal_year × fiscal_month × cost_center × gl_account
--
-- Key metrics
--   actual_ytd
--   full_year_actual
--   historical_ytd_share
-- ============================================================


CREATE OR REPLACE TABLE finance.gold.finance_historical_patterns
AS

WITH current_reporting_period AS (

    SELECT
        fiscal_year AS reporting_year

    FROM finance.silver.reporting_period

    ORDER BY fiscal_year DESC

    LIMIT 1
),


-- ------------------------------------------------------------
-- Use only completed years before the current reporting year
-- ------------------------------------------------------------

historical_actual AS (

    SELECT
        a.fiscal_year,
        a.fiscal_month,
        a.month_name,

        a.cost_center,
        a.department_name,
        a.department_name_en,

        a.gl_account,
        a.account_en,
        a.gl_name_kr,
        a.gl_name_en,

        a.special_cost_check,
        a.control_type,

        CAST(
            a.actual_amount
            AS DECIMAL(18,2)
        ) AS actual_monthly

    FROM finance.silver.fact_actual_monthly_all a

    CROSS JOIN current_reporting_period r

    WHERE a.fiscal_year < r.reporting_year
),


-- ------------------------------------------------------------
-- Calculate cumulative YTD and full-year Actual
-- ------------------------------------------------------------

historical_amounts AS (

    SELECT
        *,

        CAST(
            SUM(actual_monthly) OVER (

                PARTITION BY
                    fiscal_year,
                    cost_center,
                    gl_account

                ORDER BY
                    fiscal_month

                ROWS BETWEEN
                    UNBOUNDED PRECEDING
                    AND CURRENT ROW
            )

            AS DECIMAL(18,2)
        ) AS actual_ytd,


        CAST(
            SUM(actual_monthly) OVER (

                PARTITION BY
                    fiscal_year,
                    cost_center,
                    gl_account
            )

            AS DECIMAL(18,2)
        ) AS full_year_actual

    FROM historical_actual
)


-- ------------------------------------------------------------
-- Historical YTD Share
--
-- Example:
--   August YTD       = 80M
--   Full-Year Actual = 120M
--   YTD Share        = 66.67%
-- ------------------------------------------------------------

SELECT
    fiscal_year,
    fiscal_month,
    month_name,

    cost_center,
    department_name,
    department_name_en,

    gl_account,
    account_en,
    gl_name_kr,
    gl_name_en,

    special_cost_check,
    control_type,

    actual_monthly,
    actual_ytd,
    full_year_actual,

    CASE
        WHEN full_year_actual IS NULL
          OR full_year_actual <= 0
        THEN NULL

        ELSE CAST(
            actual_ytd / full_year_actual
            AS DECIMAL(18,6)
        )
    END AS historical_ytd_share

FROM historical_amounts;