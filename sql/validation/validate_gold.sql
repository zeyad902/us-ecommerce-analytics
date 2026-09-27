-- =====================================================================
-- validate_gold.sql  —  Gold-layer QA / regression suite
-- Project : US E-Commerce Analytics — End-to-End Data Warehouse & BI
--
-- PURPOSE
--   Proves the loaded warehouse still matches its verified state after
--   any bronze / silver / gold reload. Run this BEFORE refreshing Power BI.
--
-- HOW TO RUN
--   SSMS -> connect to localhost\MSSQLSERVER01 -> database EcommerceDB
--   -> execute the whole file. Every statement is a SELECT; the script
--   writes nothing and is safe to re-run any number of times.
--
-- PASS CRITERIA
--   Every row of every result set must show status = 'PASS'.
--   Any FAIL means: stop, fix the layer, re-run. Do not refresh Power BI
--   on a red suite.
--
-- BASELINES
--   Expected values are the verified state of the 2019-2025 extract
--   (1,000,000 orders). If the source data ever changes, re-derive and
--   update the baselines — a changed baseline must be a conscious act,
--   never a silent edit.
-- =====================================================================

USE EcommerceDB;
GO


-- ---------------------------------------------------------------------
-- 1. LAYER ROW COUNTS vs VERIFIED BASELINES
--    bronze = silver row-for-row on every table, except geolocation
--    which intentionally dedupes 11,500 coordinate rows -> 900 zips.
--    silver = gold row-for-row on every mapped table.
-- ---------------------------------------------------------------------

WITH actual AS (
    SELECT 
        s.name + '.' + t.name AS table_name,
        SUM(p.rows) AS row_count
    FROM sys.tables t
    JOIN sys.schemas s
        ON t.schema_id = s.schema_id
    JOIN sys.partitions p
        ON p.object_id = t.object_id
       AND p.index_id IN (0, 1)
    WHERE s.name IN ('bronze', 'silver', 'gold')
    GROUP BY s.name + '.' + t.name
),
expected AS (
    SELECT *
    FROM (VALUES
        ('bronze.customers',      1000000),
        ('bronze.geolocation',     11500),
        ('bronze.order_items',    2199819),
        ('bronze.order_payments', 1149371),
        ('bronze.order_reviews',   933748),
        ('bronze.orders',         1000000),
        ('bronze.products',          2000),
        ('bronze.sellers',            500),

        ('silver.customers',      1000000),
        ('silver.geolocation',        900),
        ('silver.order_items',    2199819),
        ('silver.order_payments', 1149371),
        ('silver.order_reviews',   933748),
        ('silver.orders',         1000000),
        ('silver.products',          2000),
        ('silver.sellers',            500),

        ('gold.dim_customer',     1000000),
        ('gold.dim_product',          2000),
        ('gold.dim_seller',            500),
        ('gold.dim_geolocation',       900),
        ('gold.dim_date',             2942),
        ('gold.dim_order',         1000000),
        ('gold.fact_sales',        2199819),
        ('gold.fact_orders',       1000000),
        ('gold.fact_payments',     1149371),
        ('gold.fact_reviews',       933748)
    ) AS v(table_name, expected_rows)
)
SELECT 
    a.table_name,
    a.row_count AS actual_rows,
    e.expected_rows,
    CASE 
        WHEN a.row_count = e.expected_rows 
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM actual a
INNER JOIN expected e
    ON e.table_name = a.table_name
ORDER BY a.table_name;

GO


-- ---------------------------------------------------------------------
-- 2. GOLD GRAIN — row count must equal distinct business/composite key
--    (catches duplicates even if a PK constraint were ever dropped)
-- ---------------------------------------------------------------------

SELECT 
    'dim_customer' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT customer_id) AS distinct_key,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT customer_id)
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM gold.dim_customer

UNION ALL

SELECT 
    'dim_product',
    COUNT(*),
    COUNT(DISTINCT product_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT product_id)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_product

UNION ALL

SELECT 
    'dim_seller',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT seller_id)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_seller

UNION ALL

SELECT 
    'dim_geolocation',
    COUNT(*),
    COUNT(DISTINCT zip_code_prefix),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT zip_code_prefix)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_geolocation

UNION ALL

SELECT 
    'dim_date',
    COUNT(*),
    COUNT(DISTINCT full_date),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT full_date)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_date

UNION ALL

SELECT 
    'dim_order',
    COUNT(*),
    COUNT(DISTINCT order_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT order_id)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order

UNION ALL

SELECT 
    'fact_sales',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_key, '|', order_item_id)),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT CONCAT(order_key, '|', order_item_id))
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales

UNION ALL

SELECT 
    'fact_orders',
    COUNT(*),
    COUNT(DISTINCT order_key),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT order_key)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_orders

UNION ALL

SELECT 
    'fact_payments',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_key, '|', payment_sequential)),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT CONCAT(order_key, '|', payment_sequential))
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_payments

UNION ALL

SELECT 
    'fact_reviews',
    COUNT(*),
    COUNT(DISTINCT review_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT review_id)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_reviews

ORDER BY table_name;

GO


-- ---------------------------------------------------------------------
-- 3. GOLD REFERENTIAL INTEGRITY — orphan sweep over all 21 relationships
--    (facts -> dimensions, dimensions -> dim_geolocation,
--    dim_order date keys -> dim_date,
--    fact_orders purchase date -> dim_date)
--    Nullable date keys are checked only when present.
-- ---------------------------------------------------------------------

SELECT 
    'fact_sales.customer_key -> dim_customer' AS relationship,
    COUNT(*) AS orphan_rows,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM gold.fact_sales f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_customer d
    WHERE d.customer_key = f.customer_key
)

UNION ALL

SELECT 
    'fact_sales.product_key -> dim_product',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_product d
    WHERE d.product_key = f.product_key
)

UNION ALL

SELECT 
    'fact_sales.seller_key -> dim_seller',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_seller d
    WHERE d.seller_key = f.seller_key
)

UNION ALL

SELECT 
    'fact_sales.order_key -> dim_order',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_order d
    WHERE d.order_key = f.order_key
)

UNION ALL

SELECT 
    'fact_sales.shipping_limit_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date d
    WHERE d.date_key = f.shipping_limit_date_key
)

UNION ALL

SELECT 
    'fact_sales.order_purchase_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date d
    WHERE d.date_key = f.order_purchase_date_key
)

UNION ALL

SELECT 
    'fact_orders.customer_key -> dim_customer',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_orders f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_customer d
    WHERE d.customer_key = f.customer_key
)

UNION ALL

SELECT 
    'fact_orders.order_purchase_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_orders f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date d
    WHERE d.date_key = f.order_purchase_date_key
)

UNION ALL

SELECT 
    'fact_payments.order_key -> dim_order',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_payments f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_order d
    WHERE d.order_key = f.order_key
)

UNION ALL

SELECT 
    'fact_payments.customer_key -> dim_customer',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_payments f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_customer d
    WHERE d.customer_key = f.customer_key
)

UNION ALL

SELECT 
    'fact_payments.order_purchase_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_payments f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date d
    WHERE d.date_key = f.order_purchase_date_key
)

UNION ALL

SELECT 
    'fact_reviews.order_key -> dim_order',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_reviews f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_order d
    WHERE d.order_key = f.order_key
)

UNION ALL

SELECT 
    'fact_reviews.customer_key -> dim_customer',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_reviews f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_customer d
    WHERE d.customer_key = f.customer_key
)

UNION ALL

SELECT 
    'fact_reviews.review_creation_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_reviews f
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date d
    WHERE d.date_key = f.review_creation_date_key
)

UNION ALL

SELECT 
    'dim_order.order_purchase_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order d
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date dd
    WHERE dd.date_key = d.order_purchase_date_key
)

UNION ALL

SELECT 
    'dim_order.order_approved_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order d
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date dd
    WHERE dd.date_key = d.order_approved_date_key
)

UNION ALL

SELECT 
    'dim_order.order_estimated_delivery_date_key -> dim_date',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order d
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_date dd
    WHERE dd.date_key = d.order_estimated_delivery_date_key
)

UNION ALL

SELECT 
    'dim_order.order_delivered_carrier_date_key -> dim_date (non-null only)',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order d
WHERE d.order_delivered_carrier_date_key IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM gold.dim_date dd
      WHERE dd.date_key = d.order_delivered_carrier_date_key
  )

UNION ALL

SELECT 
    'dim_order.order_delivered_customer_date_key -> dim_date (non-null only)',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order d
WHERE d.order_delivered_customer_date_key IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM gold.dim_date dd
      WHERE dd.date_key = d.order_delivered_customer_date_key
  )

UNION ALL

SELECT 
    'dim_customer.customer_zip_code_prefix -> dim_geolocation',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_customer c
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_geolocation g
    WHERE g.zip_code_prefix = c.customer_zip_code_prefix
)

UNION ALL

SELECT 
    'dim_seller.seller_zip_code_prefix -> dim_geolocation',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_seller s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_geolocation g
    WHERE g.zip_code_prefix = s.seller_zip_code_prefix
);

GO


-- ---------------------------------------------------------------------
-- 4. SILVER -> GOLD SET EQUALITY — no row lost or invented in either
--    direction (catches swaps that row counts alone would miss)
-- ---------------------------------------------------------------------

SELECT 
    'silver.orders missing in gold.dim_order' AS check_name,
    COUNT(*) AS missing_rows,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM silver.orders s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_order g
    WHERE g.order_id = s.order_id
)

UNION ALL

SELECT 
    'gold.dim_order missing in silver.orders',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_order g
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.orders s
    WHERE s.order_id = g.order_id
)

UNION ALL

SELECT 
    'silver.customers missing in gold.dim_customer',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.customers s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_customer g
    WHERE g.customer_id = s.customer_id
)

UNION ALL

SELECT 
    'gold.dim_customer missing in silver.customers',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.dim_customer g
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.customers s
    WHERE s.customer_id = g.customer_id
)

UNION ALL

SELECT 
    'silver.order_items missing in gold.fact_sales',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.order_items s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.fact_sales g
    WHERE g.order_id = s.order_id
      AND g.order_item_id = s.order_item_id
)

UNION ALL

SELECT 
    'gold.fact_sales missing in silver.order_items',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM gold.fact_sales g
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.order_items s
    WHERE s.order_id = g.order_id
      AND s.order_item_id = g.order_item_id
)

UNION ALL

SELECT 
    'silver.order_payments missing in gold.fact_payments',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.order_payments s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.fact_payments g
    WHERE g.order_id = s.order_id
      AND g.payment_sequential = s.payment_sequential
)

UNION ALL

SELECT 
    'silver.order_reviews missing in gold.fact_reviews',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.order_reviews s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.fact_reviews g
    WHERE g.review_id = s.review_id
)

UNION ALL

SELECT 
    'silver.products missing in gold.dim_product',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.products s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_product g
    WHERE g.product_id = s.product_id
)

UNION ALL

SELECT 
    'silver.sellers missing in gold.dim_seller',
    COUNT(*),
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.sellers s
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.dim_seller g
    WHERE g.seller_id = s.seller_id
);

GO


-- ---------------------------------------------------------------------
-- 5. VALUE RECONCILIATION — silver and gold money sums must agree with
--    each other and with the verified baselines, to the cent.
--
--    Baselines:
--      price    = 983,139,078.63
--      freight  = 239,045,494.22
--      payments = 1,222,184,572.85
-- ---------------------------------------------------------------------

SELECT 
    'order_items.price (silver vs gold vs baseline)' AS measure,
    (SELECT SUM(price) FROM silver.order_items) AS silver_value,
    (SELECT SUM(price) FROM gold.fact_sales) AS gold_value,
    CASE 
        WHEN ABS(
                (SELECT SUM(price) FROM silver.order_items)
                - (SELECT SUM(price) FROM gold.fact_sales)
             ) <= 0.01
         AND ABS(
                (SELECT SUM(price) FROM gold.fact_sales)
                - 983139078.63
             ) <= 0.01
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status

UNION ALL

SELECT 
    'order_items.freight_value',
    (SELECT SUM(freight_value) FROM silver.order_items),
    (SELECT SUM(freight_value) FROM gold.fact_sales),
    CASE 
        WHEN ABS(
                (SELECT SUM(freight_value) FROM silver.order_items)
                - (SELECT SUM(freight_value) FROM gold.fact_sales)
             ) <= 0.01
         AND ABS(
                (SELECT SUM(freight_value) FROM gold.fact_sales)
                - 239045494.22
             ) <= 0.01
            THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT 
    'order_payments.payment_value',
    (SELECT SUM(payment_value) FROM silver.order_payments),
    (SELECT SUM(payment_value) FROM gold.fact_payments),
    CASE 
        WHEN ABS(
                (SELECT SUM(payment_value) FROM silver.order_payments)
                - (SELECT SUM(payment_value) FROM gold.fact_payments)
             ) <= 0.01
         AND ABS(
                (SELECT SUM(payment_value) FROM gold.fact_payments)
                - 1222184572.85
             ) <= 0.01
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status;

GO


-- ---------------------------------------------------------------------
-- 6. BUSINESS RULES — the data facts the KPI definitions rest on
-- ---------------------------------------------------------------------

SELECT 
    'canceled orders have NULL delivered date keys' AS rule_name,
    (
        SELECT COUNT(*)
        FROM gold.dim_order
        WHERE order_status = 'canceled'
          AND (
                order_delivered_carrier_date_key IS NOT NULL
                OR order_delivered_customer_date_key IS NOT NULL
              )
    ) AS violations,
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM gold.dim_order
            WHERE order_status = 'canceled'
              AND (
                    order_delivered_carrier_date_key IS NOT NULL
                    OR order_delivered_customer_date_key IS NOT NULL
                  )
        ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status

UNION ALL

SELECT 
    'delivered orders have a customer delivery date',
    (
        SELECT COUNT(*)
        FROM gold.dim_order
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date_key IS NULL
    ),
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM gold.dim_order
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date_key IS NULL
        ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT 
    'reviews exist only for delivered orders',
    (
        SELECT COUNT(*)
        FROM gold.fact_reviews r
        JOIN gold.dim_order o
            ON o.order_key = r.order_key
        WHERE o.order_status <> 'delivered'
    ),
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM gold.fact_reviews r
            JOIN gold.dim_order o
                ON o.order_key = r.order_key
            WHERE o.order_status <> 'delivered'
        ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

-- GRAIN RULE:
-- Each fact is aggregated to order grain FIRST, then joined 1:1.
-- A row-level join between two facts would fan out (lines x payments)
-- and corrupt both sums.

SELECT 
    'per-order payment_value = price + freight',
    (
        SELECT COUNT(*)
        FROM (
            SELECT 
                sales.order_key,
                sales.order_total,
                pay.paid_total
            FROM (
                SELECT 
                    order_key,
                    SUM(price + freight_value) AS order_total
                FROM gold.fact_sales
                GROUP BY order_key
            ) sales
            JOIN (
                SELECT 
                    order_key,
                    SUM(payment_value) AS paid_total
                FROM gold.fact_payments
                GROUP BY order_key
            ) pay
                ON pay.order_key = sales.order_key
        ) t
        WHERE ABS(t.order_total - t.paid_total) > 0.01
    ),
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM (
                SELECT 
                    sales.order_key,
                    sales.order_total,
                    pay.paid_total
                FROM (
                    SELECT 
                        order_key,
                        SUM(price + freight_value) AS order_total
                    FROM gold.fact_sales
                    GROUP BY order_key
                ) sales
                JOIN (
                    SELECT 
                        order_key,
                        SUM(payment_value) AS paid_total
                    FROM gold.fact_payments
                    GROUP BY order_key
                ) pay
                    ON pay.order_key = sales.order_key
            ) t
            WHERE ABS(t.order_total - t.paid_total) > 0.01
        ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT 
    'fact_orders purchase date matches dim_order',
    (
        SELECT COUNT(*)
        FROM gold.fact_orders f
        INNER JOIN gold.dim_order d
            ON d.order_key = f.order_key
        WHERE f.order_purchase_date_key <> d.order_purchase_date_key
           OR f.order_purchase_date_key IS NULL
           OR d.order_purchase_date_key IS NULL
    ),
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM gold.fact_orders f
            INNER JOIN gold.dim_order d
                ON d.order_key = f.order_key
            WHERE f.order_purchase_date_key <> d.order_purchase_date_key
               OR f.order_purchase_date_key IS NULL
               OR d.order_purchase_date_key IS NULL
        ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT 
    'dim_order Unknown delivery band equals canceled order count',
    ABS(
        (SELECT COUNT(*)
         FROM gold.dim_order
         WHERE delivery_days_band = 'Unknown')
        -
        (SELECT COUNT(*)
         FROM gold.dim_order
         WHERE order_status = 'canceled')
    ),
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM gold.dim_order
            WHERE delivery_days_band = 'Unknown'
        ) = 66252
        AND (
            SELECT COUNT(*)
            FROM gold.dim_order
            WHERE order_status = 'canceled'
        ) = 66252
            THEN 'PASS'
        ELSE 'FAIL'
    END;

GO


-- ---------------------------------------------------------------------
-- 7. DIM_DATE COVERAGE — the calendar must span every date key used
--    anywhere in the model.
--
--    Delivered/estimated/approved dates of canceled orders that are
--    structurally NULL are naturally excluded.
-- ---------------------------------------------------------------------

SELECT 
    d.min_key AS dim_min_date_key,
    u.min_used AS min_used_date_key,
    d.max_key AS dim_max_date_key,
    u.max_used AS max_used_date_key,
    CASE 
        WHEN u.min_used >= d.min_key
         AND u.max_used <= d.max_key
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM (
    SELECT 
        MIN(date_key) AS min_key,
        MAX(date_key) AS max_key
    FROM gold.dim_date
) d
CROSS JOIN (
    SELECT 
        MIN(k) AS min_used,
        MAX(k) AS max_used
    FROM (
        SELECT order_purchase_date_key
            AS k
        FROM gold.fact_sales

        UNION ALL

        SELECT shipping_limit_date_key
        FROM gold.fact_sales

        UNION ALL

        SELECT order_purchase_date_key
        FROM gold.fact_payments

        UNION ALL

        SELECT review_creation_date_key
        FROM gold.fact_reviews

        UNION ALL

        SELECT order_purchase_date_key
        FROM gold.dim_order

        UNION ALL

        SELECT order_purchase_date_key
        FROM gold.fact_orders

        UNION ALL

        SELECT order_approved_date_key
        FROM gold.dim_order

        UNION ALL

        SELECT order_estimated_delivery_date_key
        FROM gold.dim_order

        UNION ALL

        SELECT order_delivered_carrier_date_key
        FROM gold.dim_order
        WHERE order_delivered_carrier_date_key IS NOT NULL

        UNION ALL

        SELECT order_delivered_customer_date_key
        FROM gold.dim_order
        WHERE order_delivered_customer_date_key IS NOT NULL
    ) x
) u;

GO


-- ---------------------------------------------------------------------
-- 8. FACT -> DIM -> SILVER KEY CONSISTENCY — catches stale surrogate
--    keys after a dimension reload. When a dimension is re-loaded, its
--    IDENTITY keys can be reassigned in a different order while the fact
--    tables keep the old values; row counts, orphan sweeps and grain
--    checks all PASS in that state — only this check catches it.
-- ---------------------------------------------------------------------

SELECT
    'fact_orders.customer_key resolves to the order''s customer' AS check_name,
    COUNT(*) AS violations,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM silver.orders s
JOIN gold.fact_orders f
    ON f.order_id = s.order_id
JOIN gold.dim_customer dc
    ON dc.customer_key = f.customer_key
WHERE dc.customer_id <> s.customer_id

UNION ALL

SELECT
    'fact_sales.product_key resolves to the item''s product',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.order_items s
JOIN gold.fact_sales f
    ON f.order_id = s.order_id AND f.order_item_id = s.order_item_id
JOIN gold.dim_product p
    ON p.product_key = f.product_key
WHERE p.product_id <> s.product_id

UNION ALL

SELECT
    'fact_sales.seller_key resolves to the item''s seller',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM silver.order_items s
JOIN gold.fact_sales f
    ON f.order_id = s.order_id AND f.order_item_id = s.order_item_id
JOIN gold.dim_seller se
    ON se.seller_key = f.seller_key
WHERE se.seller_id <> s.seller_id;

GO