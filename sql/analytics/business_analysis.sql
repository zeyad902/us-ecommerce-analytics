-- Q1 How does revenue change over time?
SELECT
    d.year_month,
    SUM(s.price + s.freight_value) AS total_revenue
FROM gold.fact_sales s
JOIN gold.dim_date d
ON s.order_purchase_date_key = d.date_key
JOIN gold.dim_order o
ON s.order_key = o.order_key
WHERE o.order_status = 'Delivered'
GROUP BY d.year_month
ORDER BY d.year_month


-- Q2 Which product categories generate the most revenue and profit?

-- Net Revenue  = SUM(price)
-- Gross Profit = SUM(price - cost)
SELECT * 
FROM(
    SELECT 
        p.product_category_name,
        SUM(s.price) net_revenue,
        SUM(s.price - p.cost) AS gross_profit
    FROM gold.fact_sales s
    INNER JOIN gold.dim_product p
        ON s.product_key = p.product_key
    INNER JOIN gold.dim_order o
        ON s.order_key = o.order_key
    WHERE o.order_status = 'Delivered'
    GROUP BY p.product_category_name
)t
ORDER BY gross_profit DESC

-- Q3 Which products are the top revenue contributors?
SELECT TOP 10 * 
FROM(
    SELECT
        p.product_key,
        p.product_name,
        SUM(s.price) net_revenue
    FROM gold.fact_sales s
    INNER JOIN gold.dim_product p
        ON s.product_key = p.product_key
    INNER JOIN gold.dim_order o
        ON s.order_key = o.order_key
    WHERE o.order_status = 'Delivered'
    GROUP BY  p.product_key , p.product_name    
)t
ORDER BY net_revenue DESC


-- Q4 How does Average Order Value (AOV) change over time?
-- AOV = Total Revenue ÷ Number of Delivered Orders
SELECT 
    year_month,
    ( total_revenue / NULLIF(total_orders,0) ) AS AOV
FROM(
    SELECT 
        dd.year_month,
        SUM(s.price + s.freight_value) total_revenue,
        COUNT(DISTINCT s.order_key) AS total_orders
    FROM gold.fact_sales s
    INNER JOIN gold.dim_order o
        ON s.order_key = o.order_key
    INNER JOIN gold.dim_date dd
        ON s.order_purchase_date_key = dd.date_key
    WHERE o.order_status = 'Delivered' 
    GROUP BY dd.year_month
)t
ORDER BY year_month

-- Q5 How does discount rate relate to units sold and revenue?

SELECT 
    f.discount_rate,
    COUNT(*) AS units_sold,
    SUM(f.price) AS net_revenue
FROM gold.fact_sales f
INNER JOIN gold.dim_order o
    ON f.order_key = o.order_key
WHERE o.order_status = 'Delivered'
GROUP BY f.discount_rate
ORDER BY f.discount_rate;



-- Q6 What proportion of customers are repeat purchasers?
WITH customer_orders AS (
SELECT 
    c.customer_unique_id,
    COUNT(*) AS total_orders
FROM gold.fact_orders o
INNER JOIN gold.dim_order do
    ON o.order_key = do.order_key
INNER JOIN gold.dim_customer c
    ON o.customer_key = c.customer_key
WHERE do.order_status = 'Delivered'
GROUP BY c.customer_unique_id
),
customer_types AS (SELECT 
    CASE 
        WHEN total_orders = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(customer_unique_id) AS total_customers
FROM customer_orders
GROUP BY 
    CASE 
        WHEN total_orders = 1 THEN 'One-time'
        ELSE 'Repeat'
    END    
)
SELECT 
    customer_type,
    total_customers,
        ROUND(
            (CAST(total_customers AS FLOAT) / SUM(total_customers) OVER()) * 100,
            2
        ) AS percentage
FROM customer_types


-- Q7 How do sales differ across customer segments?

SELECT 
    c.customer_segment,
    SUM(s.price) AS net_revenue,
    COUNT(order_item_id) AS units_sold,
    SUM(s.price + s.freight_value) / NULLIF(COUNT(DISTINCT s.order_key),0) AS AOV
FROM gold.fact_sales s
INNER JOIN gold.dim_customer c
    ON s.customer_key = c.customer_key
INNER JOIN gold.dim_order o
    ON s.order_key = o.order_key 
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_segment
ORDER BY net_revenue DESC;



-- Q8 Which sellers generate the highest sales and profit

SELECT *
FROM (
    SELECT  
        se.seller_key,
        se.seller_company_name,
        SUM(s.price) net_revenue,
        SUM(s.price - p.cost) gross_profit
    FROM gold.fact_sales s
    INNER JOIN gold.dim_seller se
        ON s.seller_key = se.seller_key
    INNER JOIN gold.dim_product p
        ON s.product_key = p.product_key
    INNER JOIN gold.dim_order o
        ON s.order_key = o.order_key
    WHERE o.order_status = 'Delivered'
    GROUP BY se.seller_company_name,se.seller_key 
)t
ORDER BY net_revenue DESC, gross_profit DESC

-- How does delivery speed relate to customer review scores?


SELECT 
    o.delivery_days_band,
    COUNT(*) AS review_count,
    ROUND(AVG(CAST(r.review_score AS FLOAT)),2) AS average_review_score
FROM gold.fact_reviews r
INNER JOIN gold.dim_order o
    ON r.order_key = o.order_key
GROUP BY o.delivery_days_band
ORDER BY o.delivery_days_band;


-- How does average customer review score change over time?

SELECT 
    d.year_month,
    ROUND(AVG(CAST(r.review_score AS FLOAT)),2) AS average_review_score
FROM gold.fact_reviews r
INNER JOIN gold.dim_date d
    ON r.review_creation_date_key = d.date_key
GROUP BY d.year_month
ORDER BY d.year_month

SELECT COUNT(DISTINCT customer_unique_id)
FROM gold.dim_customer c
INNER JOIN gold.fact_orders o
    ON c.customer_key = o.customer_key
INNER JOIN gold.dim_order do
    ON o.order_key = do.order_key
WHERE do.order_status = 'Delivered'