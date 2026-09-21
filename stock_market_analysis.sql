-- ============================================================
-- INDIAN STOCK MARKET ANALYSIS
-- SQL ANALYSIS
-- ============================================================
--
-- Database: PostgreSQL
-- Tool: pgAdmin
-- Dataset: Indian Stock Market Historical Data
--
-- Analysis performed:
-- 1. Data validation
-- 2. Top performing stocks
-- 3. Sector performance
-- 4. Stock volatility
-- 5. Risk vs Return analysis
--
-- ============================================================

-- ============================================================
-- 1. TOP 10 PERFORMING STOCKS
-- ============================================================

WITH stock_returns AS (
    SELECT
        ticker,
        company,
        sector,
        (
            (ARRAY_AGG(close_price ORDER BY date DESC))[1]
            /
            (ARRAY_AGG(close_price ORDER BY date ASC))[1]
            - 1
        ) * 100 AS total_return_pct
    FROM stock_analysis.daily_stock_data
    WHERE sector <> 'Market Index'
    GROUP BY ticker, company, sector
)

SELECT
    company,
    sector,
    ROUND(total_return_pct::numeric, 2) AS total_return_pct
FROM stock_returns
ORDER BY total_return_pct DESC
LIMIT 10;

-- ============================================================
-- 2. SECTOR PERFORMANCE
-- ============================================================

WITH stock_returns AS (
    SELECT
        ticker,
        company,
        sector,
        (
            (ARRAY_AGG(close_price ORDER BY date DESC))[1]
            /
            (ARRAY_AGG(close_price ORDER BY date ASC))[1]
            - 1
        ) * 100 AS total_return_pct
    FROM stock_analysis.daily_stock_data
    WHERE sector <> 'Market Index'
    GROUP BY ticker, company, sector
)

SELECT
    sector,
    COUNT(*) AS number_of_stocks,
    ROUND(AVG(total_return_pct)::numeric, 2)
        AS average_return_pct
FROM stock_returns
GROUP BY sector
ORDER BY average_return_pct DESC;


-- ============================================================
-- 3. STOCK VOLATILITY
-- ============================================================

WITH daily_returns AS (
    SELECT
        ticker,
        company,
        sector,
        date,
        close_price,
        LAG(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
        ) AS previous_close
    FROM stock_analysis.daily_stock_data
    WHERE sector <> 'Market Index'
),

stock_volatility AS (
    SELECT
        ticker,
        company,
        sector,
        STDDEV(
            ((close_price / previous_close) - 1) * 100
        ) * SQRT(252) AS annualized_volatility_pct
    FROM daily_returns
    WHERE previous_close IS NOT NULL
    GROUP BY ticker, company, sector
)

SELECT
    company,
    sector,
    ROUND(annualized_volatility_pct::numeric, 2)
        AS annualized_volatility_pct
FROM stock_volatility
ORDER BY annualized_volatility_pct DESC;


-- ============================================================
-- 4. RISK VS RETURN ANALYSIS
-- ============================================================

WITH stock_returns AS (
    SELECT
        ticker,
        company,
        sector,
        (
            (ARRAY_AGG(close_price ORDER BY date DESC))[1]
            /
            (ARRAY_AGG(close_price ORDER BY date ASC))[1]
            - 1
        ) * 100 AS total_return_pct
    FROM stock_analysis.daily_stock_data
    WHERE sector <> 'Market Index'
    GROUP BY ticker, company, sector
),

daily_returns AS (
    SELECT
        ticker,
        company,
        sector,
        date,
        close_price,
        LAG(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
        ) AS previous_close
    FROM stock_analysis.daily_stock_data
    WHERE sector <> 'Market Index'
),

stock_volatility AS (
    SELECT
        ticker,
        STDDEV(
            ((close_price / previous_close) - 1) * 100
        ) * SQRT(252) AS annualized_volatility_pct
    FROM daily_returns
    WHERE previous_close IS NOT NULL
    GROUP BY ticker
),

risk_return AS (
    SELECT
        r.ticker,
        r.company,
        r.sector,
        r.total_return_pct,
        v.annualized_volatility_pct
    FROM stock_returns r
    JOIN stock_volatility v
        ON r.ticker = v.ticker
),

benchmarks AS (
    SELECT
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY total_return_pct)
            AS median_return,
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY annualized_volatility_pct)
            AS median_volatility
    FROM risk_return
)

SELECT
    rr.company,
    rr.sector,
    ROUND(rr.total_return_pct::numeric, 2)
        AS total_return_pct,
    ROUND(rr.annualized_volatility_pct::numeric, 2)
        AS annualized_volatility_pct,

    CASE
        WHEN rr.total_return_pct >= b.median_return
             AND rr.annualized_volatility_pct < b.median_volatility
            THEN 'High Return / Low Risk'

        WHEN rr.total_return_pct >= b.median_return
             AND rr.annualized_volatility_pct >= b.median_volatility
            THEN 'High Return / High Risk'

        WHEN rr.total_return_pct < b.median_return
             AND rr.annualized_volatility_pct < b.median_volatility
            THEN 'Low Return / Low Risk'

        ELSE 'Low Return / High Risk'
    END AS risk_return_category

FROM risk_return rr
CROSS JOIN benchmarks b
ORDER BY rr.total_return_pct DESC;