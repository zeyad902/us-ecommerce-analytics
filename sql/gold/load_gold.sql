TRUNCATE TABLE gold.dim_customer
;WITH customer_orders AS
(
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT CASE
            WHEN o.order_status = 'Delivered'
            THEN o.order_id
        END) AS delivered_orders

    FROM silver.customers c

    LEFT JOIN silver.orders o
        ON c.customer_id = o.customer_id

    GROUP BY
        c.customer_unique_id
),

customer_classification AS
(
    SELECT
        customer_unique_id,

        CASE
            WHEN delivered_orders = 1
                THEN 'One-time'

            WHEN delivered_orders >= 2
                THEN 'Repeat'

            ELSE 'Unknown'
        END AS customer_type

    FROM customer_orders
)

INSERT INTO gold.dim_customer
(
    customer_id,
    customer_unique_id,
    customer_name,
    customer_gender,
    customer_age,
    customer_zip_code_prefix,
    customer_segment,
    customer_type
)

SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_name,
    c.customer_gender,
    c.customer_age,
    c.customer_zip_code_prefix,
    c.customer_segment,
    cc.customer_type

FROM silver.customers c

LEFT JOIN customer_classification cc
    ON c.customer_unique_id = cc.customer_unique_id;


GO
TRUNCATE TABLE gold.dim_geolocation
INSERT INTO gold.dim_geolocation(
	zip_code_prefix,
	geolocation_lat,
	geolocation_lng,
	geolocation_city,
	geolocation_state
)
SELECT 
    zip_code_prefix,
	geolocation_lat,
	geolocation_lng,
	geolocation_city,
	geolocation_state
FROM silver.geolocation
GO
TRUNCATE TABLE gold.dim_product
INSERT INTO gold.dim_product(
	product_id,
	product_category_name ,
	product_name ,
	product_brand,
	product_weight_g ,
	product_length_cm,
	product_height_cm ,
	product_width_cm ,
	cost,
	price 
)
SELECT 
	product_id,
	product_category_name ,
	product_name ,
	product_brand,
	product_weight_g ,
	product_length_cm,
	product_height_cm ,
	product_width_cm ,
	cost,
	price
FROM silver.products
GO
TRUNCATE TABLE gold.dim_seller
INSERT INTO gold.dim_seller(
	seller_id,
	seller_company_name ,
	seller_contact_name,
	seller_contact_gender,
	seller_contact_age,
	seller_zip_code_prefix 
)
SELECT 
    	seller_id,
	seller_company_name ,
	seller_contact_name,
	seller_contact_gender,
	seller_contact_age,
	seller_zip_code_prefix 
FROM silver.sellers

TRUNCATE TABLE gold.dim_date;

DECLARE @start DATE = (SELECT CAST(MIN(order_purchase_timestamp) AS DATE) FROM silver.orders);

DECLARE @end DATE = (
    SELECT CAST(MAX(x) AS DATE) FROM (
        SELECT MAX(order_purchase_timestamp)         AS x FROM silver.orders
        UNION ALL SELECT MAX(order_approved_at)             FROM silver.orders
        UNION ALL SELECT MAX(order_delivered_carrier_date)  FROM silver.orders
        UNION ALL SELECT MAX(order_delivered_customer_date) FROM silver.orders
        UNION ALL SELECT MAX(order_estimated_delivery_date) FROM silver.orders
        UNION ALL SELECT MAX(shipping_limit_date)           FROM silver.order_items
        UNION ALL SELECT MAX(review_answer_timestamp)       FROM silver.order_reviews
    ) t
);
SET @end = DATEADD(YEAR, 1, @end);   -- buffer: deliveries & estimates spill past purchase dates

;WITH date_series AS (
    SELECT @start AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM date_series
    WHERE full_date < @end
),
dates AS (
    SELECT
        CAST(CONVERT(CHAR(8), full_date, 112) AS INT) AS date_key,
        full_date,
        DAY(full_date)                                AS day,
        DATENAME(WEEKDAY, full_date)                  AS day_name,
        DATEDIFF(DAY, '1900-1-1', full_date) % 7 + 1  AS day_of_week,
        DATEPART(DAYOFYEAR, full_date)                AS day_of_year,
        DATEPART(ISO_WEEK, full_date)                 AS week_of_year
    FROM date_series
)
INSERT INTO gold.dim_date  WITH(TABLOCK)
    (date_key, full_date, day, day_name, day_of_week, day_of_year,
     week_of_year,iso_year, week_start_date, week_end_date, month, month_name,
     month_short_name, quarter, quarter_name, year, year_month,
     is_weekend, is_month_start, is_month_end)
SELECT
    date_key,
    full_date,
    day,
    day_name,
    day_of_week,
    day_of_year,
    week_of_year,
	YEAR(DATEADD(DAY, 4 - day_of_week, full_date))         AS iso_year,
    DATEADD(DAY, -(day_of_week - 1), full_date) AS week_start_date,
    DATEADD(DAY, 6, DATEADD(DAY, -(day_of_week - 1), full_date)) AS week_end_date,
    MONTH(full_date)                            AS month,
    DATENAME(MONTH, full_date)                  AS month_name,
    FORMAT(full_date, 'MMM')                    AS month_short_name,
    DATEPART(QUARTER, full_date)                AS quarter,
    CONCAT('Q', DATENAME(QUARTER, full_date))   AS quarter_name,
    YEAR(full_date)                             AS year,
    CONVERT(CHAR(7), full_date, 23) AS year_month,
    CASE WHEN day_of_week IN (6, 7) THEN 1 ELSE 0 END AS is_weekend,
    CASE WHEN DAY(full_date) = 1 THEN 1 ELSE 0 END    AS is_month_start,
    CASE WHEN full_date = EOMONTH(full_date) THEN 1 ELSE 0 END AS is_month_end
FROM dates
OPTION (MAXRECURSION 0);


TRUNCATE TABLE gold.dim_order;

INSERT INTO gold.dim_order WITH (TABLOCK)
(
    order_id,
    order_status,
    order_purchase_date_key,
    order_approved_date_key,
    order_delivered_carrier_date_key,
    order_delivered_customer_date_key,
    order_estimated_delivery_date_key,
    delivery_days_band,
    is_late
)
SELECT
    b.order_id,
    b.order_status,
    op.date_key  AS order_purchase_date_key,
    oa.date_key  AS order_approved_date_key,
    od.date_key  AS order_delivered_carrier_date_key,
    odc.date_key AS order_delivered_customer_date_key,
    oe.date_key  AS order_estimated_delivery_date_key,

    CASE
        WHEN b.delivery_days IS NULL THEN 'Unknown'
        WHEN b.delivery_days <= 3  THEN 'Fast'
        WHEN b.delivery_days <= 7  THEN 'Normal'
        WHEN b.delivery_days <= 14 THEN 'Slow'
        ELSE 'Very Slow'
    END AS delivery_days_band,

    CASE
        WHEN b.delivered_d IS NULL THEN NULL
        WHEN b.delivered_d > b.estimated_d THEN 1
        ELSE 0
    END AS is_late

FROM
(
    SELECT
        o.order_id,
        o.order_status,

        CAST(o.order_purchase_timestamp AS DATE)      AS purchase_d,
        CAST(o.order_approved_at AS DATE)             AS approved_d,
        CAST(o.order_delivered_carrier_date AS DATE)  AS carrier_d,
        CAST(o.order_delivered_customer_date AS DATE) AS delivered_d,
        CAST(o.order_estimated_delivery_date AS DATE) AS estimated_d,

        DATEDIFF(
            DAY,
            o.order_purchase_timestamp,
            o.order_delivered_customer_date
        ) AS delivery_days

    FROM silver.orders o
) b

INNER JOIN gold.dim_date op
    ON op.full_date = b.purchase_d

INNER JOIN gold.dim_date oa
    ON oa.full_date = b.approved_d

LEFT JOIN gold.dim_date od
    ON od.full_date = b.carrier_d

LEFT JOIN gold.dim_date odc
    ON odc.full_date = b.delivered_d

INNER JOIN gold.dim_date oe
    ON oe.full_date = b.estimated_d;

GO

DROP INDEX IF EXISTS ux_dim_order_order_id
ON gold.dim_order;

CREATE UNIQUE INDEX ux_dim_order_order_id
ON gold.dim_order (order_id);

GO

-- =========================================================================================================
-- fact load 
-- =========================================================================================================

-- 1)-
TRUNCATE TABLE gold.fact_orders 
INSERT INTO gold.fact_orders (
    order_id,
	order_key ,
    customer_key,
    order_purchase_date_key,
    delivery_days,
    days_to_approve,
	hours_to_approve,
    days_to_carrier
)
SELECT 
    o.order_id,
	do.order_key,
	c.customer_key,
    do.order_purchase_date_key,
	DATEDIFF(DAY , order_purchase_timestamp , order_delivered_customer_date ) AS delivery_days,
	DATEDIFF(DAY , order_purchase_timestamp , order_approved_at ) AS days_to_approve,
	DATEDIFF(HOUR , order_purchase_timestamp , order_approved_at ) AS hours_to_approve,
	DATEDIFF(DAY , order_purchase_timestamp , order_delivered_carrier_date ) AS days_to_carrier
FROM silver.orders o
INNER JOIN gold.dim_customer c
	ON o.customer_id = c.customer_id
INNER JOIN gold.dim_order do
	ON o.order_id = do.order_id

-- 2)-
CREATE INDEX ix_fact_orders_order_purchase_date_key
ON gold.fact_orders (order_purchase_date_key);

-- 3)-
ALTER TABLE gold.fact_orders
ADD CONSTRAINT fk_fact_orders_date
FOREIGN KEY (order_purchase_date_key)
REFERENCES gold.dim_date(date_key);

TRUNCATE TABLE gold.fact_payments;

INSERT INTO gold.fact_payments WITH (TABLOCK)
(
    order_key,
    order_id,
    payment_sequential,
    customer_key,
    payment_type,
    payment_installments,
    payment_value,
    order_purchase_date_key
)
SELECT 
    do.order_key,
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
    ON CAST(o.order_purchase_timestamp AS DATE) = d.full_date

INNER JOIN gold.dim_order do
    ON p.order_id = do.order_id



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

TRUNCATE TABLE gold.fact_reviews
INSERT INTO gold.fact_reviews
(
    review_id,
    order_key,
    customer_key,
    review_score,
    review_creation_date_key
)
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