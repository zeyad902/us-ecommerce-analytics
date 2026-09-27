IF OBJECT_ID('gold.dim_order','U') IS NOT NULL
    DROP TABLE gold.dim_order;
CREATE TABLE gold.dim_order (
    order_key                         INT IDENTITY(1,1) NOT NULL,
    order_id                          NVARCHAR(100) NOT NULL,
    order_status                      NVARCHAR(50)  NOT NULL,
    order_purchase_date_key           INT           NOT NULL,
    order_approved_date_key           INT           NOT NULL,
    order_delivered_carrier_date_key  INT           NULL,
    order_delivered_customer_date_key INT           NULL, 
    order_estimated_delivery_date_key INT           NOT NULL,
    delivery_days_band                NVARCHAR(10)  NOT NULL,
    is_late                           BIT           NULL,

    CONSTRAINT pk_dim_order      PRIMARY KEY (order_key),
    CONSTRAINT ck_dim_order_band CHECK (delivery_days_band IN
        ('Fast','Normal','Slow','Very Slow','Unknown'))
);
GO
IF OBJECT_ID('gold.dim_customer','U') IS NOT NULL
	DROP TABLE gold.dim_customer
CREATE TABLE gold.dim_customer
(
    customer_key    INT IDENTITY(1,1) PRIMARY KEY, 
    customer_id              NVARCHAR(50) NOT NULL,
    customer_unique_id       NVARCHAR(50) NOT NULL,
    customer_name            NVARCHAR(100) NOT NULL,
    customer_gender          NVARCHAR(10) NOT NULL,
    customer_age             INT NOT NULL,
    customer_zip_code_prefix NVARCHAR(10) NOT NULL,
    customer_segment         NVARCHAR(50) NOT NULL,
    customer_type NVARCHAR(20) NOT NULL,

    CONSTRAINT UQ_dim_customer_customer_id
    UNIQUE (customer_id)
);
GO
IF OBJECT_ID('gold.dim_geolocation','U') IS NOT NULL
	DROP TABLE gold.dim_geolocation
CREATE TABLE gold.dim_geolocation
(
    zip_code_key INT IDENTITY(1,1) PRIMARY KEY ,
	zip_code_prefix NVARCHAR(10) NOT NULL,
	geolocation_lat FLOAT NOT NULL,
	geolocation_lng FLOAT NOT NULL,
	geolocation_city NVARCHAR(20) NOT NULL,
	geolocation_state NVARCHAR(20) NOT NULL,
    CONSTRAINT UQ_dim_geolocation_zip_code_prefix
    UNIQUE (zip_code_prefix)
);
GO
IF OBJECT_ID('gold.dim_product','U') IS NOT NULL
	DROP TABLE gold.dim_product
CREATE TABLE gold.dim_product(
    product_key INT IDENTITY(1,1) PRIMARY KEY,
	product_id NVARCHAR(100) NOT NULL,
	product_category_name NVARCHAR(100) NOT NULL,
	product_name NVARCHAR(100) NOT NULL,
	product_brand NVARCHAR(100) NOT NULL,
	product_weight_g INT NOT NULL,
	product_length_cm INT NOT NULL, 
	product_height_cm INT NOT NULL,
	product_width_cm INT NOT NULL,
	cost DECIMAL(10,2) NOT NULL,
	price DECIMAL(10,2) NOT NULL,

    CONSTRAINT UQ_dim_product_product_id
    UNIQUE (product_id)
	)
GO
IF OBJECT_ID('gold.dim_seller','U') IS NOT NULL
	DROP TABLE gold.dim_seller
CREATE TABLE gold.dim_seller(
    seller_key INT IDENTITY(1,1) PRIMARY KEY,
	seller_id NVARCHAR(100) NOT NULL,
	seller_company_name NVARCHAR(100) NOT NULL,
	seller_contact_name NVARCHAR(100) NOT NULL,
	seller_contact_gender NVARCHAR(20) NOT NULL,
	seller_contact_age INT NOT NULL,
	seller_zip_code_prefix NVARCHAR(10) NOT NULL,
    CONSTRAINT UQ_dim_seller_seller_id
    UNIQUE (seller_id)
)

IF OBJECT_ID('gold.dim_date','U') IS NOT NULL
	DROP TABLE gold.dim_date
CREATE TABLE gold.dim_date
(
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL,

    day TINYINT NOT NULL,
    day_name VARCHAR(10) NOT NULL,
    day_of_week TINYINT NOT NULL,
    day_of_year SMALLINT NOT NULL,

    week_of_year TINYINT NOT NULL,
	iso_year SMALLINT NOT NULL, 
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,

    month TINYINT NOT NULL,
    month_name  VARCHAR(10) NOT NULL,
    month_short_name VARCHAR(3) NOT NULL,

    quarter TINYINT NOT NULL,
    quarter_name VARCHAR(2) NOT NULL,

    year SMALLINT NOT NULL,
	year_month VARCHAR(10) NOT NULL,

    is_weekend BIT NOT NULL,
    is_month_start BIT NOT NULL,
    is_month_end BIT NOT NULL
);
CREATE UNIQUE INDEX ix_dim_date_full_date ON gold.dim_date (full_date);

-- ============================================================================================
-- fact tables
-- ============================================================================================

-- =================================
-- fact_sales
-- =================================

IF OBJECT_ID('gold.fact_sales','U') IS NOT NULL
	DROP TABLE gold.fact_sales
CREATE TABLE gold.fact_sales(
    order_key INT NOT NULL,
	order_id NVARCHAR(100) NOT NULL,
	order_item_id INT NOT NULL,
	customer_key INT NOT NULL,
	product_key INT NOT NULL,
	seller_key INT NOT NULL,
	shipping_limit_date_key INT NOT NULL,
	order_purchase_date_key INT NOT NULL,
	price DECIMAL(10,2) NOT NULL,
	freight_value DECIMAL(10,2) NOT NULL,
	discount_rate DECIMAL(10,2) NOT NULL,

	CONSTRAINT pk_fact_sales PRIMARY KEY (order_key, order_item_id)
)
-- =================================
-- fact_payments 
-- =================================
GO
IF OBJECT_ID('gold.fact_payments','U') IS NOT NULL
	DROP TABLE gold.fact_payments
CREATE TABLE gold.fact_payments(
    order_key INT NOT NULL ,
	order_id NVARCHAR(100) NOT NULL,
	payment_sequential INT NOT NULL,
	customer_key INT NOT NULL, 
	payment_type NVARCHAR(50) NOT NULL,
	payment_installments INT NOT NULL,
	payment_value DECIMAL(10,2) NOT NULL,
    order_purchase_date_key INT NOT NULL,

	CONSTRAINT pk_fact_payments PRIMARY KEY (order_key , payment_sequential)
);
-- =================================
-- fact_payments 
-- =================================
GO
IF OBJECT_ID('gold.fact_reviews','U') IS NOT NULL
	DROP TABLE gold.fact_reviews
CREATE TABLE gold.fact_reviews(
	review_id NVARCHAR(100) NOT NULL,
    order_key INT NOT NULL,
    customer_key INT NOT NULL,
	review_score INT NOT NULL,
	review_creation_date_key INT NOT NULL,

    CONSTRAINT pk_fact_reviews PRIMARY KEY(review_id)

);
-- =================================
-- fact_order 
-- =================================
GO
IF OBJECT_ID('gold.fact_orders','U') IS NOT NULL
    DROP TABLE gold.fact_orders;

CREATE TABLE gold.fact_orders
(
    order_key INT NOT NULL,
    order_id NVARCHAR(100) NOT NULL,
    customer_key INT NOT NULL,
    order_purchase_date_key INT NOT NULL,
    delivery_days INT NULL,
    days_to_approve INT NULL,
	hours_to_approve INT NOT NULL,
    days_to_carrier INT NULL,

    CONSTRAINT pk_fact_orders
        PRIMARY KEY (order_key)
);

