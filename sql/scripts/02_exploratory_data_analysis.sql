/* ============================================================
    Project: E-Commerce Sales Optimization
    File: 02_exploratory_data_analysis.sql
    Author: Bryan Melvida
   
    Purpose:
    - Analyze demand concentration and regional contribution
    - Identify growth signals and opportunity gaps
    - Evaluate product demand and mix performance
    - Assess pricing and discount sensitivity
    - Examine fulfillment and cost impact on demand
    - Evaluate segment demand and contribution
   ============================================================ */


USE global_store_sales


/* ============================================================
    DEMAND CONCENTRATION & MARKET SHARE CONTRIBUTION
   ------------------------------------------------------------
    - Assess how demand and revenue are distributed across markets
   ============================================================ */

-- market-level demand concentration metrics
WITH market_performance AS (
    SELECT
        market,
        COUNT(DISTINCT country) AS country_count,
        SUM(sales) AS total_sales,
        COUNT(order_date) AS total_order,
        AVG(sales) AS AOV,
        SUM(sales) / NULLIF(SUM(SUM(sales)) OVER(),0) AS sales_pct
    FROM sales_transaction
    GROUP BY market
)

-- metrics for cross-market comparison
SELECT
    market,
    country_count AS country_count,
    FORMAT(total_sales / 1e6, 'N2') AS 'revenue(M)',
    FORMAT(sales_pct, 'P2') AS market_revenue_pct,
    FORMAT(total_order, 'N0') AS order_count,
    FORMAT(AOV, 'N2') AS AOV,
    FORMAT((total_sales / country_count) / 1e6, 'N2') AS 'avg_country_revenue(M)',
    FORMAT(total_order / country_count, 'N0') AS 'country_orders'
FROM market_performance
ORDER BY total_sales DESC;



/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Revenue Concentration:
        - APAC, EU, US, and LATAM collectively account for ~87% of total revenue.
        - Overall performance heavily depends on these four core markets.
    
    - Coverage-Driven Markets:
        - APAC, EU, and LATAM generate revenue across many countries with moderate order volumes.
        - Growth in these markets comes from geographic breadth, not concentrated demand.
    
    - Demand-Dense Market:
        - The US delivers revenue comparable to multi-country markets from a single country.
        - Driven by high order concentration.
    
    - Low-Intensity Markets:
        - Africa and EMEA span wide country coverage but contribute limited revenue and orders.
        - Broad presence doesn't translate to meaningful demand.
    
    - Minimal Contributor:
        - Canada contributes minimally to both revenue and order volume.
   ------------------------------------------------------------ */



---------------------------------------------------------------
-- MARKET REVENUE CONCENTRATION ORDER
---------------------------------------------------------------

-- market ranking reference table
SELECT
    market,
    ROW_NUMBER() OVER(ORDER BY total_sales DESC) AS rank_order
INTO #market_revenue_order
FROM (
    SELECT
        market,
        SUM(sales) AS total_sales
    FROM sales_transaction
    GROUP BY market
) AS market_order;



/* ============================================================
    PRODUCT DEMAND & MIX PERFORMANCE
   ------------------------------------------------------------
    - Evaluate product-level demand and sales mix contribution
   ============================================================ */

-- category mix and revenue contribution per market
WITH product_mix AS (
    SELECT
        market,
        category,
        SUM(sales) AS total_sales
    FROM sales_transaction
    GROUP BY
        market,
        category
)

-- rank and percentage share of each category inside its market
SELECT
    PM.market,
    PM.category,
    FORMAT(PM.total_sales, 'N0') AS revenue,
    RANK() OVER(PARTITION BY PM.market ORDER BY PM.total_sales DESC) AS rank_in_market,
    FORMAT(
        PM.total_sales/ NULLIF(SUM(PM.total_sales) OVER(PARTITION BY PM.market), 0),'P2'
    ) AS market_category_revenue_pct
FROM product_mix as PM
JOIN #market_revenue_order AS MRO
    ON PM.market = MRO.market
ORDER BY 
    MRO.rank_order;




/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Category Mix Structure:
    	- Most markets show the top two categories at similar revenue share levels.
    	- The third category drops substantially, with Canada showing the steepest decline.

    - Dominant Category Presence:
        - Technology ranks as the top category in most markets, including APAC, EU, US, EMEA, and Africa.
        - This indicates Technology as the primary revenue driver across regions.

    - Secondary Category Competition:
        - Furniture and Office Supplies compete closely for the second position in most markets.
        - Their relative rank varies by market, but revenue shares are often within a narrow range.

    - Balanced Category Mix (US Positive Outlier):
        - The US shows near-even revenue distribution across all three categories.
        - No single category dominates, reducing reliance on one product line.
   ------------------------------------------------------------ */



/* ============================================================
    PRICING & DISCOUNT SENSITIVITY
   ------------------------------------------------------------
    - Assess customer response to pricing and discount levels
   ============================================================ */

-- discount level bucketing and market AOV
WITH market_sensitivity AS (
    SELECT
        market,
        discount_Level,
        COUNT(market) AS order_count,
        AVG(sales) AS AOV
    FROM (
        SELECT
            market,
            CASE
                WHEN discount > 0.50 THEN 'Aggressive'
                WHEN discount > 0.25 THEN 'High'
                WHEN discount > 0.10 THEN 'Medium'
                WHEN discount > 0 THEN 'Low'
                ELSE 'No-Discount'
            END AS discount_level,
            sales
        FROM sales_transaction
    ) AS dicount_tier
    GROUP BY
        market,
        discount_level
)     

-- cross-market discount response metrics
SELECT
    MS.market,
    MS.discount_level,
    FORMAT(MS.order_count, 'N0') AS order_count,
    FORMAT(
        CAST(MS.order_count AS DECIMAL(18,4)) /
        NULLIF(SUM(MS.order_count) OVER(PARTITION BY MS.market), 0), 'P2'
    ) AS order_pct,
    FORMAT(MS.AOV, 'N0') AS AOV
FROM market_sensitivity AS MS
JOIN #market_revenue_order AS MRO
    ON MS.market = MRO.market
ORDER BY 
    MRO.rank_order,
    CASE
        WHEN MS.discount_level = 'No-Discount' THEN 1
        WHEN MS.discount_level = 'Low' THEN 2
        WHEN MS.discount_level = 'Medium' THEN 3
        WHEN MS.discount_level = 'High' THEN 4
        WHEN MS.discount_level = 'Aggressive' THEN 5
    END;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Core Markets Are Demand-Led (APAC, EU, US, LATAM):
        - 67% to 86% of all orders occur at Medium or lower discount levels.
        - AOV remains stable or peaks in Low/Moderate levels, not in heavy discount levels.
        - High discounts lead to lower order spend, not premium order growth.
        - Aggressive discounts represent a minor share of orders (0.4% to 8.5% depending on market).

    - Split Price-Driven Buyers (EMEA & Africa):
        - Majority of orders transact at No-Discount (67%-77%) with normal AOV ranges (199-202).
        - A large secondary segment only buys at Aggressive discounts (22%-32%) with low AOV (58-78).

    - Small Full-Price Niche Market (Canada):
        - 100% of orders occur at No-Discount.
   ------------------------------------------------------------ */



/* ============================================================
    FULFILLMENT & COST IMPACT ON DEMAND
   ------------------------------------------------------------
    - Examine how fulfillment cost and operational factors
      influence demand
   ============================================================ */

-- ship mode delivery records
WITH shipping_details AS (
    SELECT
        market,
        ship_mode,
        COUNT(*) AS order_count,
        AVG(shipping_cost) AS ship_cost_avg,
        AVG(quantity) AS quantity_avg,
        SUM(sales) AS total_sales,
        AVG(DATEDIFF(DAY, order_date, ship_date)) AS delivery_days_avg
    FROM sales_transaction
    GROUP BY 
        market,
        ship_mode
)
-- ship mode performance metrics
SELECT
    SD.market,
    ship_mode,
    delivery_days_avg,
    FORMAT(order_count, 'N0') AS total_order_count,
    FORMAT(
        CAST(order_count AS FLOAT) / NULLIF(SUM(order_count) OVER(PARTITION BY SD.market), 0),'P2'
    ) AS total_orders_pct,
    FORMAT(ship_cost_avg, 'N0') AS ship_cost_avg,
    quantity_avg,
    FORMAT(total_sales, 'N0') AS revenue,
    FORMAT(
        total_sales / NULLIF(SUM(total_sales) OVER(PARTITION BY SD.market), 0), 'P2'
    ) AS revenue_pct
FROM shipping_details AS SD
JOIN #market_revenue_order AS MRO
    ON SD.market = MRO.market
ORDER BY
    MRO.rank_order,
    CASE 
        WHEN ship_mode = 'Same Day' THEN 1
        WHEN ship_mode = 'First Class' THEN 2
        WHEN ship_mode = 'Second Class' THEN 3
        ELSE 4
    END;



/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    -  Shipping Preference Is Cost-Led, Not Urgency-Led:
      - Standard Class takes 60% of orders and ~60% of revenue in APAC, EU, US, LATAM
      - Same Day stays 5% order share in core markets.
      - Quantity avg is consistent across modes (2-3 units) across all modes.
      - Markets consistently avoid higher-cost faster modes.
   ------------------------------------------------------------ */



/* ============================================================
    Segment Contribution & Demand Quality
   ------------------------------------------------------------
    - Assess how demand and revenue are distributed across segments
    - Check how much segments rely on heavy promotions
    - Measure segment tolerance to shipping cost pressure
   ============================================================ */

-- Segment contribution  (market level)
WITH segment_contribution AS (
    SELECT
        market,
        segment,
        AVG(sales) AS avg_sales,
        SUM(sales) AS total_sales,
        SUM(sales) / NULLIF(SUM(SUM(sales)) OVER(PARTITION BY market), 0) AS sales_pct,
        COUNT(*) AS total_order,
        CAST(COUNT(*) AS FLOAT) / NULLIF(SUM(COUNT(*)) OVER(PARTITION BY market), 0) as order_pct
    FROM sales_transaction
    GROUP BY
        market,
        segment
)
SELECT
    SC.market,
    SC.segment,
    FORMAT(SC.avg_sales, 'N0') AS AOV,
    FORMAT(SC.total_sales, 'N0') AS revenue,
    FORMAT(SC.sales_pct, 'P2') AS segment_revenue_pct,
    FORMAT(SC.total_order, 'N0') as total_order,
    FORMAT(SC.order_pct, 'P2') AS segment_order_pct
FROM segment_contribution AS SC
JOIN #market_revenue_order AS MRO
    ON SC.market = MRO.market
ORDER BY 
    MRO.rank_order,
    CASE
        WHEN SC.segment = 'Corporate' THEN 1
        WHEN SC.segment = 'Home Office' THEN 2
        ELSE 3
    END;


/**
FINDINGS:
 - Demand Concentration Pattern:
  - Consumer segment drives 50-54% of revenue consistently across ALL markets
  - Corporate contributes 26-31%, Home Office 16-19%
  - This pattern holds regardless of market geography or maturity

 - Segment Spending Behavior:
  - AOV differences between segments are marginal across all markets (differences of 0.6%-3.5%)
 
 - Premium segments show regional clustering: 
  - APAC/US pair on Home Office, LATAM/Canada pair on Consumer, while EU and EMEA/Africa show distinct patterns
**/

-- Market Promo-dependency (demand quality)




-- Shipping cost tolerance (market view)





/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Short Summary Findings
   ------------------------------------------------------------ */


/* ============================================================
    END OF EXPLORATORY DATA ANALYSIS SCRIPT
   ============================================================ */