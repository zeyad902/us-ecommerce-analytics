TRUNCATE TABLE bronze.customers;

BULK INSERT bronze.customers
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\customers.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.products
BULK INSERT bronze.products
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\products.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.geolocation
BULK INSERT bronze.geolocation
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\geolocation.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.order_items
BULK INSERT bronze.order_items
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\order_items.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.order_payments
BULK INSERT bronze.order_payments
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\order_payments.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.order_reviews
BULK INSERT bronze.order_reviews
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\order_reviews.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.orders
BULK INSERT bronze.orders
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\orders.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
TRUNCATE TABLE bronze.sellers
BULK INSERT bronze.sellers
FROM 'D:\college\Data Analysis\PROJECTS\US E-Commerce Analytics — End-to-End Data Warehouse & BI\data\sellers.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);











