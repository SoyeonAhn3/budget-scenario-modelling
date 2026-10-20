-- ============================================================
-- Year-End Forecast Backtest
--
-- Purpose
--   Compare Simple Annualization and Seasonal EAC using
--   the latest completed fiscal year as the test year.
--
-- Example with reporting year = 2026:
--
--   Historical training period : 2021-2024
--   Test year                  : 2025
--   Forecast cutoff            : Current reporting cutoff
--
-- Evaluation metric:
--   APE = Absolute Percentage Error
-- ============================================================


WITH params AS (

    SELECT
        fiscal_year AS reporting_year,
        cutoff_month,

        fiscal_year - 1 AS test_year,
        fiscal_year - 5 AS train_start_year

    FROM finance.silver.reporting_period

    ORDER BY fiscal_year DESC

    LIMIT 1
),


-- ------------------------------------------------------------
-- Historical department-level YTD / Full-Year Actual
-- ------------------------------------------------------------

history_by_year AS (

    SELECT
        h.fiscal_year,
        h.cost_center,
        h.department_name,

        SUM(h.actual_ytd)
            AS actual_ytd,

        SUM(h.full_year_actual)
            AS full_year_actual

    FROM finance.gold.finance_historical_patterns h

    CROSS JOIN params p

    WHERE h.fiscal_month = p.cutoff_month

      AND h.fiscal_year
          BETWEEN p.train_start_year
          AND p.test_year - 1

    GROUP BY
        h.fiscal_year,
        h.cost_center,
        h.department_name
),


-- ------------------------------------------------------------
-- Calculate annual YTD Share
-- ------------------------------------------------------------

history_share AS (

    SELECT
        fiscal_year,
        cost_center,
        department_name,

        CASE
            WHEN full_year_actual > 0
            THEN actual_ytd / full_year_actual

            ELSE NULL
        END AS ytd_share

    FROM history_by_year
),


-- ------------------------------------------------------------
-- Historical average YTD Share by department
-- ------------------------------------------------------------

history_summary AS (

    SELECT
        cost_center,
        department_name,

        AVG(ytd_share)
            AS avg_historical_ytd_share,

        COUNT(ytd_share)
            AS history_year_count

    FROM history_share

    GROUP BY
        cost_center,
        department_name
),


-- ------------------------------------------------------------
-- Test-year Actual
--
-- At the cutoff month:
--   actual_ytd_test       = information available at forecast time
--   actual_full_year_test = actual outcome used only for evaluation
-- ------------------------------------------------------------

test_year_actual AS (

    SELECT
        h.cost_center,
        h.department_name,

        SUM(h.actual_ytd)
            AS actual_ytd_test,

        SUM(h.full_year_actual)
            AS actual_full_year_test

    FROM finance.gold.finance_historical_patterns h

    CROSS JOIN params p

    WHERE h.fiscal_year = p.test_year

      AND h.fiscal_month = p.cutoff_month

    GROUP BY
        h.cost_center,
        h.department_name
),


-- ------------------------------------------------------------
-- Forecast methods
-- ------------------------------------------------------------

backtest AS (

    SELECT
        a.cost_center,
        a.department_name,

        p.test_year,
        p.cutoff_month,

        h.avg_historical_ytd_share,
        h.history_year_count,

        a.actual_ytd_test,
        a.actual_full_year_test,


        -- ----------------------------------------------------
        -- Simple Annualization
        --
        -- Assumption:
        -- Current average monthly spending continues
        -- through year-end.
        -- ----------------------------------------------------

        a.actual_ytd_test
            / p.cutoff_month
            * 12.0
            AS simple_annualization,


        -- ----------------------------------------------------
        -- Seasonal EAC
        --
        -- Uses historical share of annual spending completed
        -- by the same cutoff month.
        -- ----------------------------------------------------

        CASE
            WHEN h.avg_historical_ytd_share > 0

            THEN
                a.actual_ytd_test
                / h.avg_historical_ytd_share

            ELSE NULL
        END AS seasonal_eac


    FROM test_year_actual a

    INNER JOIN history_summary h
        ON a.cost_center = h.cost_center

    CROSS JOIN params p
),


-- ------------------------------------------------------------
-- Forecast errors
-- ------------------------------------------------------------

backtest_result AS (

    SELECT
        *,

        simple_annualization
            - actual_full_year_test
            AS simple_error_amount,

        seasonal_eac
            - actual_full_year_test
            AS seasonal_error_amount,


        -- APE = Absolute Percentage Error

        CASE
            WHEN actual_full_year_test <> 0

            THEN
                ABS(
                    simple_annualization
                    - actual_full_year_test
                )
                /
                ABS(actual_full_year_test)

            ELSE NULL
        END AS simple_ape,


        CASE
            WHEN actual_full_year_test <> 0

            THEN
                ABS(
                    seasonal_eac
                    - actual_full_year_test
                )
                /
                ABS(actual_full_year_test)

            ELSE NULL
        END AS seasonal_ape

    FROM backtest
)


-- ============================================================
-- Department-level Backtest Result
-- ============================================================

SELECT
    cost_center,
    department_name,

    test_year,
    cutoff_month,

    history_year_count,
    avg_historical_ytd_share,

    actual_ytd_test,
    actual_full_year_test,

    simple_annualization,
    seasonal_eac,

    simple_error_amount,
    seasonal_error_amount,

    simple_ape,
    seasonal_ape,

    simple_ape * 100
        AS simple_ape_pct,

    seasonal_ape * 100
        AS seasonal_ape_pct,

    CASE
        WHEN seasonal_ape < simple_ape
            THEN 'SEASONAL_EAC_BETTER'

        WHEN simple_ape < seasonal_ape
            THEN 'SIMPLE_BETTER'

        ELSE 'SAME'
    END AS better_method

FROM backtest_result

ORDER BY
    department_name;