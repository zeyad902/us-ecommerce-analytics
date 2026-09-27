-- load customer data into silver table
TRUNCATE TABLE silver.customers
    INSERT INTO silver.customers
    (
        customer_id,
        customer_unique_id,
        customer_name,
        customer_gender,
        customer_age,
        customer_segment,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    )
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
GO
TRUNCATE TABLE silver.geolocation
    INSERT INTO silver.geolocation
    (
        zip_code_prefix,
        geolocation_lng,
        geolocation_lat,
        geolocation_city,
        geolocation_state
    )
        SELECT
        CAST(zip_code_prefix AS nvarchar(10)) zip_code_prefix,
        AVG(geolocation_lng) geolocation_lng,
        AVG(geolocation_lat) geolocation_lat,
        MAX(TRIM(geolocation_city)) geolocation_city,
        MAX(TRIM(geolocation_state)) geolocation_state
        FROM bronze.geolocation
        GROUP BY zip_code_prefix
GO

TRUNCATE TABLE silver.order_items
    INSERT INTO silver.order_items
    (
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value, 
        discount_rate
    )
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
GO

TRUNCATE TABLE silver.order_payments
    INSERT INTO silver.order_payments
    (
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value
    )
        SELECT 
            order_id,
            payment_sequential,
            TRIM(payment_type) as payment_type,
            payment_installments,
            payment_value
        FROM bronze.order_payments
GO

TRUNCATE TABLE silver.order_reviews
    INSERT INTO silver.order_reviews
    (
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    )
        SELECT 
            review_id,
            order_id,
            review_score,
            TRIM(review_comment_title) as review_comment_title,
            TRIM(review_comment_message) as review_comment_message ,
            review_creation_date,
            review_answer_timestamp
        FROM bronze.order_reviews
GO
TRUNCATE TABLE silver.orders
    INSERT INTO silver.orders
    (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
    )
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
GO
TRUNCATE TABLE silver.products
    INSERT INTO silver.products
    (
        product_id,
        product_category_name,
        product_name,
        product_brand,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        cost,
        price
    )
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
GO
TRUNCATE TABLE silver.sellers
    INSERT INTO silver.sellers
    (
            seller_id,
            seller_company_name,
            seller_contact_name,
            seller_contact_gender,
            seller_contact_age,
            seller_zip_code_prefix,
            seller_city ,
            seller_state 
    )
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
