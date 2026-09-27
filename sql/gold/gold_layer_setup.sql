/*
-- preparing the dim_date table
DECLARE @start DATE = (SELECT CAST(MIN(order_purchase_timestamp) AS DATE) FROM silver.orders);

DECLARE @end DATE = (
    SELECT CAST(MAX(x) AS DATE) FROM (
        SELECT MAX(order_purchase_timestamp)        AS x FROM silver.orders
        UNION ALL SELECT MAX(order_approved_at)           FROM silver.orders
        UNION ALL SELECT MAX(order_delivered_carrier_date) FROM silver.orders
        UNION ALL SELECT MAX(order_delivered_customer_date) FROM silver.orders
        UNION ALL SELECT MAX(order_estimated_delivery_date) FROM silver.orders
        UNION ALL SELECT MAX(shipping_limit_date)         FROM silver.order_items
        UNION ALL SELECT MAX(review_answer_timestamp)     FROM silver.order_reviews
    ) t
);
SET @end = DATEADD(YEAR, 1, @end);   -- buffer: deliveries & estimates spill past purchase dates

WITH date_series AS (
    SELECT @start AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM date_series
    WHERE full_date < @end         
)
,dates AS (
SELECT 
CAST(CONVERT(CHAR(8), full_date, 112) AS INT )AS date_key,
full_date,
DAY(full_date) AS day,
DATENAME(WEEKDAY,full_date) AS day_name,
DATEDIFF(DAY,'1900-1-1',full_date) %7 + 1 AS day_of_week,
DATEPART(DAYOFYEAR,full_date) AS day_of_year,
DATEPART(ISO_WEEK,full_date) AS week_of_year
FROM date_series


)
SELECT 
    date_key,
    full_date,
    day,
    day_name,
    day_of_week,
    day_of_year,
    week_of_year,
    DATEADD(DAY,-(day_of_week-1),full_date) AS week_start_date,
    DATEADD(DAY,6,DATEADD(DAY,-(day_of_week-1),full_date)) AS week_end_date,
    MONTH(full_date) AS month,
    DATENAME(MONTH,full_date) AS month_name,
    FORMAT(full_date,'MMM') AS month_short_name,
    DATEPART(QUARTER,full_date) AS quarter,
    CONCAT('Q' , DATENAME(QUARTER,full_date)) AS quarter_name,
    YEAR(full_date) AS year,
    CONVERT(CHAR(7), full_date, 23) AS year_month,
    CASE
        WHEN day_of_week IN (6,7) THEN 1 
        ELSE 0
    END AS is_weekend,
    CASE
        WHEN DAY(full_date) = 1 THEN 1
        ELSE 0
    END AS is_month_start,
    CASE
        WHEN full_date = EOMONTH(full_date) THEN 1
        ELSE 0
    END AS is_month_end
FROM dates
OPTION (MAXRECURSION 0);

-- 1. Range and row count (~2,900+ rows, 2019-01-01 → ≈ early 2027)
SELECT COUNT(*) AS rows_loaded, MIN(full_date) AS min_date, MAX(full_date) AS max_date
FROM gold.dim_date;

-- 2. Convention spot-check
SELECT date_key, day_name, day_of_week, is_weekend, year_month
FROM gold.dim_date WHERE full_date = '2019-01-01';
-- expect: Tuesday, 2, 0, 2019-01

-- 3. iso_year boundary proof (should return only year-boundary days)
SELECT date_key, full_date, year, iso_year, week_of_year
FROM gold.dim_date WHERE year <> iso_year ORDER BY full_date;
-- expect: 2019-12-30/31 → iso 2020 week 1, and the equivalent days at each year boundary
*/

-- =======================================================================
-- gold fact_sales table
-- =======================================================================

SELECT
    f.order_id,    
    order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    sd.date_key,
    o.order_purchase_timestamp,
    od.date_key,
    f.price,
    freight_value,
    discount_rate
FROM  silver.order_items f
INNER JOIN gold.dim_product p
    ON f.product_id = p.product_id
INNER JOIN gold.dim_seller s
    ON f.seller_id = s.seller_id
INNER JOIN silver.orders o
    ON o.order_id = f.order_id
INNER JOIN gold.dim_customer c
    ON o.customer_id = c.customer_id
INNER JOIN gold.dim_date sd
    ON CAST(f.shipping_limit_date AS DATE)= sd.full_date
INNER JOIN gold.dim_date od
    ON CAST(o.order_purchase_timestamp AS DATE) = od.full_date
ORDER BY order_id , order_item_id

-- check the quality of fact_sales
SELECT
    COUNT(*) AS row_count,

    COUNT(DISTINCT CONCAT(order_id, '-', order_item_id))
        AS distinct_order_items,

    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END)
        AS missing_customer_keys,

    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END)
        AS missing_product_keys,

    SUM(CASE WHEN seller_key IS NULL THEN 1 ELSE 0 END)
        AS missing_seller_keys,

    SUM(CASE WHEN shipping_limit_date_key IS NULL THEN 1 ELSE 0 END)
        AS missing_date_keys

FROM gold.fact_sales;


SELECT COUNT(*) FROM gold.fact_sales;                    -- expect 2,199,819
SELECT COUNT(DISTINCT order_id) FROM gold.fact_sales;    -- expect 1,000,000
SELECT COUNT(*) FROM gold.fact_sales WHERE order_purchase_date_key IS NULL;  -- 0

-- =======================================================================
-- gold fact_orders table
-- =======================================================================

SELECT
    order_id,
    c.customer_key,
    order_status,
    op.date_key AS order_purchase_date_key,
    orp.date_key AS order_approved_at_date_key,
    od.date_key AS order_delivered_carrier_date_key,
    odc.date_key AS order_delivered_customer_date_key,
    oe.date_key AS order_estimated_delivery_date_key
FROM silver.orders o
INNER JOIN gold.dim_customer c
    ON o.customer_id = c.customer_id
INNER JOIN gold.dim_date op
    ON CAST(o.order_purchase_timestamp AS DATE) = op.full_date
INNER JOIN gold.dim_date orp
    ON CAST(o.order_approved_at AS DATE) = orp.full_date
LEFT JOIN gold.dim_date od
    ON CAST(o.order_delivered_carrier_date AS DATE) = od.full_date
LEFT JOIN gold.dim_date odc
    ON CAST(o.order_delivered_customer_date AS DATE) = odc.full_date
INNER JOIN gold.dim_date oe
    ON CAST(o.order_estimated_delivery_date AS DATE) = oe.full_date
    SET STATISTICS TIME, IO ON;

-- =======================================================================
-- gold fact_payments table
-- =======================================================================
 --> 1149371 rows
SELECT 
    p.order_id,
    p.payment_sequential,
    c.customer_key,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    d.date_key
FROM silver.order_payments p

INNER JOIN silver.orders o
    ON p.order_id = o.order_id

INNER JOIN gold.dim_customer c
    ON o.customer_id = c.customer_id

INNER JOIN gold.dim_date d
    ON CAST(o.order_purchase_timestamp AS DATE) = d.full_date;




-- refactoring fact_sales 
SELECT COUNT(*)
FROM (
    SELECT
    do.order_key,
    f.order_id,    
    order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    f.shipping_limit_date,
    sd.date_key AS shipping_limit_date_key,
    o.order_purchase_timestamp,
    od.date_key AS order_purchase_date_key,
    f.price,
    freight_value,
    discount_rate
FROM  silver.order_items f
INNER JOIN gold.dim_product p
    ON f.product_id = p.product_id
INNER JOIN gold.dim_seller s
    ON f.seller_id = s.seller_id
INNER JOIN silver.orders o
    ON o.order_id = f.order_id
INNER JOIN gold.dim_customer c
    ON o.customer_id = c.customer_id
INNER JOIN gold.dim_date sd
    ON CAST(f.shipping_limit_date AS DATE)= sd.full_date
INNER JOIN gold.dim_date od
    ON CAST(o.order_purchase_timestamp AS DATE) = od.full_date
INNER JOIN gold.dim_order do
    ON f.order_id = do.order_id

) x;
TRUNCATE TABLE gold.fact_sales
INSERT INTO gold.fact_sales
(
    order_key,
    order_id,    
    order_item_id,
    customer_key,
    product_key,
    seller_key,
    shipping_limit_date_key,
    order_purchase_date_key,
    price,
    freight_value,
    discount_rate
)
SELECT
    do.order_key,
    f.order_id,    
    order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    sd.date_key AS shipping_limit_date_key,
    od.date_key AS order_purchase_date_key,
    f.price,
    freight_value,
    discount_rate
FROM  silver.order_items f
INNER JOIN gold.dim_product p
    ON f.product_id = p.product_id
INNER JOIN gold.dim_seller s
    ON f.seller_id = s.seller_id
INNER JOIN silver.orders o
    ON o.order_id = f.order_id
INNER JOIN gold.dim_customer c
    ON o.customer_id = c.customer_id
INNER JOIN gold.dim_date sd
    ON CAST(f.shipping_limit_date AS DATE)= sd.full_date
INNER JOIN gold.dim_date od
    ON CAST(o.order_purchase_timestamp AS DATE) = od.full_date
INNER JOIN gold.dim_order do
    ON f.order_id = do.order_id


SELECT 
    review_id,
    do.order_key,
    c.customer_key,
    review_score,
    dd.date_key AS review_creation_date_key
FROM silver.order_reviews r
INNER JOIN gold.dim_order do
    ON r.order_id = do.order_id
INNER JOIN silver.orders o
    ON r.order_id = o.order_id
INNER JOIN gold.dim_customer c
    ON o.customer_id = c.customer_id
INNER JOIN gold.dim_date dd
    ON CAST(r.review_creation_date AS DATE) = dd.full_date

