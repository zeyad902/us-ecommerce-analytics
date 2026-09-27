-- Create customer bronze table
IF OBJECT_ID('bronze.customers','U') IS NOT NULL
	DROP TABLE bronze.customers;
CREATE TABLE bronze.customers
(
	customer_id NVARCHAR(200),
	customer_unique_id NVARCHAR(200),
	customer_name NVARCHAR(200),
	customer_gender NVARCHAR(200),
	customer_age INT,
	customer_zip_code_prefix NVARCHAR(200),
	customer_city NVARCHAR(200),
	customer_state NVARCHAR(200),
	customer_segment NVARCHAR(200)
	)
GO
-- Create customer bronze table
IF OBJECT_ID('bronze.geolocation','U') IS NOT NULL
	DROP TABLE bronze.geolocation;
CREATE TABLE bronze.geolocation
(
	zip_code_prefix NVARCHAR(10),
	geolocation_lat FLOAT,
	geolocation_lng FLOAT,
	geolocation_city NVARCHAR(20),
	geolocation_state NVARCHAR(20)
)
GO
IF OBJECT_ID('bronze.order_items','U') IS NOT NULL
	DROP TABLE bronze.order_items;
CREATE TABLE bronze.order_items(
	order_id NVARCHAR(100),
	order_item_id INT,
	product_id NVARCHAR(100),
	seller_id NVARCHAR(100),
	shipping_limit_date DATETIME,
	price DECIMAL(10,2),
	freight_value DECIMAL(10,2),
	discount_rate DECIMAL(10,2)
)
GO
IF OBJECT_ID('bronze.order_payments','U') IS NOT NULL
	DROP TABLE bronze.order_payments;
CREATE TABLE bronze.order_payments(
	order_id NVARCHAR(100),
	payment_sequential INT,
	payment_type NVARCHAR(50),
	payment_installments INT,
	payment_value DECIMAL(10,2)
	)
	
GO
IF OBJECT_ID('bronze.order_reviews','U') IS NOT NULL
	DROP TABLE bronze.order_reviews;
CREATE TABLE bronze.order_reviews(
	review_id NVARCHAR(100),
	order_id NVARCHAR(100),
	review_score INT,
	review_comment_title NVARCHAR(50),
	review_comment_message NVARCHAR(200),
	review_creation_date DATETIME,
	review_answer_timestamp DATETIME
)
GO
IF OBJECT_ID('bronze.orders','U') IS NOT NULL
	DROP TABLE bronze.orders;
CREATE TABLE bronze.orders(
	order_id NVARCHAR(100),
	customer_id NVARCHAR(100),
	order_status NVARCHAR(50),
	order_purchase_timestamp DATETIME,
	order_approved_at DATETIME,
	order_delivered_carrier_date DATETIME,
	order_delivered_customer_date DATETIME,
	order_estimated_delivery_date DATETIME
)
GO
IF OBJECT_ID('bronze.products','U') IS NOT NULL
	DROP TABLE bronze.products;
CREATE TABLE bronze.products(
	product_id NVARCHAR(100),
	product_category_name NVARCHAR(100),
	product_name NVARCHAR(100),
	product_brand NVARCHAR(100),
	product_weight_g INT,
	product_length_cm INT,
	product_height_cm INT,
	product_width_cm INT ,
	cost DECIMAL(10,2),
	price DECIMAL(10,2)
	)
GO
IF OBJECT_ID('bronze.sellers','U') IS NOT NULL
	DROP TABLE bronze.sellers;
CREATE TABLE bronze.sellers(
	seller_id NVARCHAR(100),
	seller_company_name NVARCHAR(100),
	seller_contact_name NVARCHAR(100),
	seller_contact_gender NVARCHAR(20),
	seller_contact_age INT,
	seller_zip_code_prefix NVARCHAR(10),
	seller_city NVARCHAR(50),
	seller_state NVARCHAR(50)
)
