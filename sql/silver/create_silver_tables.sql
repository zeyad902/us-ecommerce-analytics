-- Create customer silver table
IF OBJECT_ID('silver.customers','U') IS NOT NULL
	DROP TABLE silver.customers
CREATE TABLE silver.customers
(
    customer_id              NVARCHAR(50) NOT NULL,
    customer_unique_id       NVARCHAR(50) NOT NULL,
    customer_name            NVARCHAR(100) NOT NULL,
    customer_gender          NVARCHAR(10) NOT NULL,
    customer_age             INT NOT NULL,
    customer_zip_code_prefix NVARCHAR(10) NOT NULL,
    customer_city            NVARCHAR(50) NOT NULL,
    customer_state           NVARCHAR(20) NOT NULL,
    customer_segment         NVARCHAR(50) NOT NULL,
	dwh_create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);
GO
CREATE INDEX ix_customers_unique_id ON silver.customers (customer_unique_id);
GO
IF OBJECT_ID('silver.geolocation','U') IS NOT NULL
	DROP TABLE silver.geolocation
CREATE TABLE silver.geolocation
(
	zip_code_prefix NVARCHAR(10) NOT NULL,
	geolocation_lat FLOAT NOT NULL,
	geolocation_lng FLOAT NOT NULL,
	geolocation_city NVARCHAR(20) NOT NULL,
	geolocation_state NVARCHAR(20) NOT NULL,
	dwh_create_date DATETIME2 DEFAULT GETDATE(),

	CONSTRAINT pk_geo PRIMARY KEY (zip_code_prefix)
);

GO
IF OBJECT_ID('silver.order_items','U') IS NOT NULL
	DROP TABLE silver.order_items
CREATE TABLE silver.order_items(
	order_id NVARCHAR(100) NOT NULL,
	order_item_id INT NOT NULL,
	product_id NVARCHAR(100) NOT NULL,
	seller_id NVARCHAR(100) NOT NULL,
	shipping_limit_date DATETIME NOT NULL,
	price DECIMAL(10,2) NOT NULL,
	freight_value DECIMAL(10,2) NOT NULL,
	discount_rate DECIMAL(10,2) NOT NULL,
	dwh_create_date DATETIME2 DEFAULT GETDATE(),

    CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id), 
    CONSTRAINT ck_items_price    CHECK (price > 0),                   
    CONSTRAINT ck_items_freight  CHECK (freight_value >= 0),          
    CONSTRAINT ck_items_discount CHECK (discount_rate BETWEEN 0 AND 1)
)
GO
IF OBJECT_ID('silver.order_payments','U') IS NOT NULL
	DROP TABLE silver.order_payments
CREATE TABLE silver.order_payments(
	order_id NVARCHAR(100) NOT NULL,
	payment_sequential INT NOT NULL,
	payment_type NVARCHAR(50) NOT NULL,
	payment_installments INT NOT NULL,
	payment_value DECIMAL(10,2) NOT NULL,
	dwh_create_date DATETIME2 DEFAULT GETDATE(),
	
    CONSTRAINT pk_order_payments PRIMARY KEY (order_id , payment_sequential)
);
GO
IF OBJECT_ID('silver.order_reviews','U') IS NOT NULL
	DROP TABLE silver.order_reviews
CREATE TABLE silver.order_reviews(
	review_id NVARCHAR(100) NOT NULL,
	order_id NVARCHAR(100) NOT NULL,
	review_score INT NOT NULL,
	review_comment_title NVARCHAR(50),
	review_comment_message NVARCHAR(200),
	review_creation_date DATETIME,
	review_answer_timestamp DATETIME,
	dwh_create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id)
);
CREATE INDEX ix_reviews_order ON silver.order_reviews (order_id);
GO
IF OBJECT_ID('silver.orders','U') IS NOT NULL
	DROP TABLE silver.orders
CREATE TABLE silver.orders(
	order_id NVARCHAR(100) NOT NULL,
	customer_id NVARCHAR(100) NOT NULL,
	order_status NVARCHAR(50) NOT NULL,
	order_purchase_timestamp DATETIME,
	order_approved_at DATETIME,
	order_delivered_carrier_date DATETIME,
	order_delivered_customer_date DATETIME,
	order_estimated_delivery_date DATETIME,
	dwh_create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_orders PRIMARY KEY(order_id),
    CONSTRAINT ck_ord_sequence_1 CHECK (order_approved_at >= order_purchase_timestamp),
    CONSTRAINT ck_ord_sequence_2 CHECK (order_delivered_carrier_date IS NULL OR order_approved_at <= order_delivered_carrier_date),
    CONSTRAINT ck_ord_sequence_3 CHECK (order_delivered_customer_date IS NULL OR order_delivered_carrier_date <= order_delivered_customer_date),
    CONSTRAINT ck_ord_sequence_4 CHECK (order_delivered_customer_date IS NULL OR order_purchase_timestamp <= order_delivered_customer_date)
)
CREATE INDEX idx_orders_customer_id ON silver.orders (customer_id);
GO
IF OBJECT_ID('silver.products','U') IS NOT NULL
	DROP TABLE silver.products
CREATE TABLE silver.products(
	product_id NVARCHAR(100) NOT NULL,
	product_category_name NVARCHAR(100),
	product_name NVARCHAR(100),
	product_brand NVARCHAR(100),
	product_weight_g INT,
	product_length_cm INT,
	product_height_cm INT,
	product_width_cm INT ,
	cost DECIMAL(10,2),
	price DECIMAL(10,2),
	dwh_create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT ck_product_weight_g CHECK (product_weight_g > 0),
    CONSTRAINT ck_product_length_cm CHECK (product_length_cm > 0),
    CONSTRAINT ck_product_height_cm CHECK (product_height_cm > 0),
    CONSTRAINT ck_product_width_cm CHECK (product_width_cm > 0),
    CONSTRAINT ck_cost CHECK (cost > 0),
    CONSTRAINT ck_price CHECK (price > 0)
	)
GO
IF OBJECT_ID('silver.sellers','U') IS NOT NULL
	DROP TABLE silver.sellers
CREATE TABLE silver.sellers(
	seller_id NVARCHAR(100) NOT NULL,
	seller_company_name NVARCHAR(100),
	seller_contact_name NVARCHAR(100),
	seller_contact_gender NVARCHAR(20),
	seller_contact_age INT,
	seller_zip_code_prefix NVARCHAR(10),
	seller_city NVARCHAR(50),
	seller_state NVARCHAR(50),
	dwh_create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_sellers      PRIMARY KEY (seller_id),
    CONSTRAINT ck_seller_age   CHECK (seller_contact_age BETWEEN 18 AND 100)
)
