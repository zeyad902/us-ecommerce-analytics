-- Ckeck the nulls of the tables: 
DECLARE @SQL NVARCHAR(MAX);

SELECT @SQL = STRING_AGG(
    CAST(
        'SELECT ''' + c.name + ''' AS column_name,
        ''' + t.name + ''' AS table_name,
        COUNT(*) - COUNT(' + QUOTENAME(c.name) + ') AS null_count,
        CAST(
            100.0 * (COUNT(*) - COUNT(' + QUOTENAME(c.name) + '))
            / COUNT(*)
            AS DECIMAL(5,2)
        ) AS null_percentage
        FROM ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name)
        AS NVARCHAR(MAX)
    ),
    ' UNION ALL '
)
FROM sys.columns c
JOIN sys.tables t
    ON c.object_id = t.object_id
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'bronze';

EXEC sp_executesql @SQL;

SELECT COUNT(*)
FROM bronze.orders
WHERE order_status = 'Canceled'
AND order_delivered_carrier_date IS NULL AND 
    order_delivered_customer_date IS NULL
-- 66252 nulls is from canceled orders
-- NULL delivered dates = order canceled before fulfillment; legitimate, not imputed

-- customer silver table
SELECT 
    customer_id,
    customer_unique_id,
    TRIM(customer_name) as customer_name,
    CASE 
        WHEN TRIM(customer_gender) = 'M' THEN 'Male'
        WHEN TRIM(customer_gender) = 'F' THEN 'Female'
    ELSE 'n/a'
    END AS customer_gender,
    customer_age,
    TRIM(customer_segment) as customer_segment,
    TRIM(customer_zip_code_prefix) AS customer_zip_code_prefix,
    TRIM(customer_city) as customer_city,
    TRIM(customer_state) as customer_state
FROM bronze.customers

-- geolocation silver table
SELECT
CAST(zip_code_prefix AS nvarchar(10)) zip_code_prefix,
AVG(geolocation_lng) geolocation_lng,
AVG(geolocation_lat) geolocation_lat,
MAX(TRIM(geolocation_city)) geolocation_city,
MAX(TRIM(geolocation_state)) geolocation_state
FROM bronze.geolocation
GROUP BY zip_code_prefix


-- order_items silver table

SELECT 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value, 
    discount_rate
FROM bronze.order_items 

-- order_payments silver table

SELECT 
    order_id,
    payment_sequential,
    TRIM(payment_type) as payment_type,
    payment_installments,
    payment_value
FROM bronze.order_payments
ORDER BY order_id

-- order_reviews silver table 

SELECT 
    review_id,
    order_id,
    review_score,
    TRIM(review_comment_title) as review_comment_title,
    TRIM(review_comment_message) as review_comment_message ,
    review_creation_date,
    review_answer_timestamp
FROM bronze.order_reviews


-- orders silver table 
SELECT 
    order_id,
    customer_id,
    TRIM(order_status) order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM bronze.orders

SELECT
    COUNT(*)                                                              AS total_orders,
    SUM(CASE WHEN order_purchase_timestamp > order_approved_at            THEN 1 ELSE 0 END) AS approval_before_purchase,
    SUM(CASE WHEN order_approved_at > order_delivered_carrier_date        THEN 1 ELSE 0 END) AS carrier_before_approval,
    SUM(CASE WHEN order_delivered_carrier_date > order_delivered_customer_date THEN 1 ELSE 0 END) AS delivery_before_carrier,
    SUM(CASE WHEN order_purchase_timestamp > order_delivered_customer_date THEN 1 ELSE 0 END) AS delivery_before_purchase
FROM bronze.orders;

-- all date are right 


-- products silver table 

SELECT
    product_id,
    TRIM(product_category_name) AS product_category_name,
    TRIM(product_name) AS product_name,
    TRIM(product_brand) AS product_brand,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    cost,
    price
FROM bronze.products


-- seller silver table 
SELECT 
    seller_id,
    TRIM(seller_company_name) AS seller_company_name,
    TRIM(seller_contact_name) AS seller_contact_name,
    CASE 
        WHEN TRIM(seller_contact_gender) = 'F' THEN 'Female'
        WHEN TRIM(seller_contact_gender) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS seller_contact_gender,
    seller_contact_age,
    TRIM(seller_zip_code_prefix) AS seller_zip_code_prefix,
    TRIM(seller_city) AS seller_city ,
    TRIM(seller_state) AS seller_state
FROM bronze.sellers


