CREATE DATABASE IF NOT EXISTS ecommerce_analysis;

USE ecommerce_analysis;
SHOW TABLES;

USE ecommerce_analysis;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers;

SHOW VARIABLES LIKE 'local_infile';

LOAD DATA LOCAL INFILE 'C:/Users/ankic/Downloads/INTERNSHIP PROJECTS-(JoobAaj)/Python-SQL Project-03/geolocation.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
);

SELECT customer_id, COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT product_id, COUNT(*)
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT seller_id, COUNT(*)
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

SELECT order_id, order_item_id, COUNT(*)
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

SELECT order_id, payment_sequential, COUNT(*)
FROM payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

SELECT
    SUM(product_category IS NULL) AS missing_category,
    SUM(product_name_length IS NULL) AS missing_name_length,
    SUM(product_description_length IS NULL) AS missing_description_length,
    SUM(product_photos_qty IS NULL) AS missing_photos,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_length_cm IS NULL) AS missing_length,
    SUM(product_height_cm IS NULL) AS missing_height,
    SUM(product_width_cm IS NULL) AS missing_width
FROM products;

SELECT
    SUM(order_approved_at IS NULL) AS missing_approved,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM orders;

SELECT
    product_id,
    COALESCE(NULLIF(TRIM(product_category), ''), 'Unknown') AS product_category
FROM products;

CREATE TABLE geolocation_clean AS
SELECT
    geolocation_zip_code_prefix,
    AVG(geolocation_lat) AS latitude,
    AVG(geolocation_lng) AS longitude,
    MAX(geolocation_city) AS city,
    MAX(geolocation_state) AS state
FROM geolocation
GROUP BY geolocation_zip_code_prefix;

SELECT COUNT(*)
FROM geolocation_clean;

SELECT COUNT(*) AS unmatched_order_items
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS unmatched_products
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS unmatched_sellers
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

SELECT COUNT(*) AS unmatched_payments
FROM payments p
LEFT JOIN orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

#BASIC ANALYSIS-----------

#Basic 1 — Unique cities
SELECT DISTINCT customer_city
FROM customers
ORDER BY customer_city;

#BASIC 2 — Orders placed in 2017
SELECT COUNT(*) AS orders_2017
FROM orders
WHERE YEAR(order_purchase_timestamp) = 2017;

#BASIC 3 — Total sales per category
SELECT
    COALESCE(NULLIF(TRIM(p.product_category), ''), 'Unknown') AS product_category,
    ROUND(SUM(oi.price), 2) AS total_sales
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
GROUP BY COALESCE(NULLIF(TRIM(p.product_category), ''), 'Unknown')
ORDER BY total_sales DESC;

#BASIC 4 — Percentage of orders paid in installments
SELECT
    ROUND(
        100.0 *
        COUNT(DISTINCT CASE
            WHEN payment_installments > 1 THEN order_id
        END)
        / COUNT(DISTINCT order_id),
        2
    ) AS installment_percentage
FROM payments;

#BASIC 5 — Customers from each state
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS customer_count
FROM customers
GROUP BY customer_state
ORDER BY customer_count DESC;

#INTERMEDIATE ANALYSIS--------------
#Intermediate 1 — Orders per month in 2018
SELECT
    MONTH(order_purchase_timestamp) AS month_number,
    MONTHNAME(order_purchase_timestamp) AS month_name,
    COUNT(*) AS order_count
FROM orders
WHERE YEAR(order_purchase_timestamp) = 2018
GROUP BY
    MONTH(order_purchase_timestamp),
    MONTHNAME(order_purchase_timestamp)
ORDER BY month_number;

#Intermediate 2 — Average products per order by customer city
WITH order_product_count AS (
    SELECT
        o.order_id,
        c.customer_city,
        COUNT(oi.order_item_id) AS products_in_order
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY
        o.order_id,
        c.customer_city
)

SELECT
    customer_city,
    ROUND(AVG(products_in_order), 2) AS avg_products_per_order
FROM order_product_count
GROUP BY customer_city
ORDER BY avg_products_per_order DESC;

#Intermediate 3 — Revenue percentage by category
WITH category_sales AS (
    SELECT
        COALESCE(NULLIF(TRIM(p.product_category), ''), 'Unknown')
            AS product_category,
        SUM(oi.price) AS category_revenue
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    GROUP BY
        COALESCE(NULLIF(TRIM(p.product_category), ''), 'Unknown')
)

SELECT
    product_category,
    ROUND(category_revenue, 2) AS category_revenue,
    ROUND(
        100 * category_revenue /
        SUM(category_revenue) OVER (),
        2
    ) AS revenue_percentage
FROM category_sales
ORDER BY category_revenue DESC;

#INTERMEDIATE 4 — Correlation between product price and purchase count
SELECT
    product_id,
    AVG(price) AS avg_price,
    COUNT(*) AS purchase_count
FROM order_items
GROUP BY product_id;

#INTERMEDIATE 5 — Seller revenue and ranking
SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    SUM(oi.price) AS total_revenue
FROM order_items oi
JOIN sellers s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY total_revenue DESC;

SELECT
    seller_id,
    seller_city,
    seller_state,
    total_revenue,

    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank

FROM (
    SELECT
        oi.seller_id,
        s.seller_city,
        s.seller_state,
        SUM(oi.price) AS total_revenue
    FROM order_items oi
    JOIN sellers s
        ON oi.seller_id = s.seller_id
    GROUP BY
        oi.seller_id,
        s.seller_city,
        s.seller_state
) seller_sales;

SELECT *
FROM (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS total_revenue,
        RANK() OVER (
            ORDER BY SUM(oi.price) DESC
        ) AS revenue_rank
    FROM order_items oi
    GROUP BY oi.seller_id
) x
WHERE revenue_rank <= 10;

#ADVANCED LEVEL-----------------
#ADVANCED 1 — Moving average of order values per customer
WITH order_values AS (

    SELECT
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp,
        SUM(oi.price) AS order_value

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp
)

SELECT
    customer_id,
    order_id,
    order_purchase_timestamp,
    order_value,

    AVG(order_value) OVER (
        PARTITION BY customer_id
        ORDER BY order_purchase_timestamp
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_order_value

FROM order_values
ORDER BY
    customer_id,
    order_purchase_timestamp;
    
    #ADVANCED 2 — Cumulative sales per month for each year
    WITH monthly_sales AS (

    SELECT
        YEAR(o.order_purchase_timestamp) AS sales_year,
        MONTH(o.order_purchase_timestamp) AS sales_month,
        SUM(oi.price) AS monthly_sales

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT
    sales_year,
    sales_month,
    monthly_sales,

    SUM(monthly_sales) OVER (
        PARTITION BY sales_year
        ORDER BY sales_month
    ) AS cumulative_sales

FROM monthly_sales

ORDER BY
    sales_year,
    sales_month;
    
#ADVANCED 3 — Year-over-year sales growth
WITH yearly_sales AS (

    SELECT
        YEAR(o.order_purchase_timestamp) AS sales_year,
        SUM(oi.price) AS total_sales

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY
        YEAR(o.order_purchase_timestamp)
)

SELECT
    sales_year,
    total_sales,

    LAG(total_sales) OVER (
        ORDER BY sales_year
    ) AS previous_year_sales,

    ROUND(
        100 *
        (
            total_sales -
            LAG(total_sales) OVER (
                ORDER BY sales_year
            )
        )
        /
        NULLIF(
            LAG(total_sales) OVER (
                ORDER BY sales_year
            ),
            0
        ),
        2
    ) AS yoy_growth_percentage

FROM yearly_sales

ORDER BY sales_year;

#ADVANCED 4 — Customer retention within 6 months
WITH customer_first_purchase AS (

    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY customer_unique_id
)

SELECT *
FROM customer_first_purchase;

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase
    FROM customer_orders
    GROUP BY customer_unique_id
),

eligible_customers AS (
    SELECT
        customer_unique_id,
        first_purchase
    FROM first_purchase
    WHERE first_purchase <= (
        SELECT MAX(order_purchase_timestamp)
        FROM customer_orders
    ) - INTERVAL 6 MONTH
),

retained_customers AS (
    SELECT DISTINCT
        e.customer_unique_id
    FROM eligible_customers e
    JOIN customer_orders co
        ON co.customer_unique_id = e.customer_unique_id
       AND co.order_purchase_timestamp > e.first_purchase
       AND co.order_purchase_timestamp <= DATE_ADD(
            e.first_purchase, INTERVAL 6 MONTH
       )
)

SELECT
    COUNT(*) AS eligible_customers,
    COUNT(r.customer_unique_id) AS retained_customers,
    ROUND(
        100.0 * COUNT(r.customer_unique_id) / COUNT(*),
        2
    ) AS retention_rate
FROM eligible_customers e
LEFT JOIN retained_customers r
    ON e.customer_unique_id = r.customer_unique_id;
    
    WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase
    FROM customer_orders
    GROUP BY customer_unique_id
),

eligible_customers AS (
    SELECT
        customer_unique_id,
        first_purchase
    FROM first_purchase
    WHERE first_purchase <= (
        SELECT MAX(order_purchase_timestamp)
        FROM customer_orders
    ) - INTERVAL 6 MONTH
),

retained_customers AS (
    SELECT DISTINCT
        e.customer_unique_id
    FROM eligible_customers e
    JOIN customer_orders co
        ON co.customer_unique_id = e.customer_unique_id
        AND co.order_purchase_timestamp > e.first_purchase
        AND co.order_purchase_timestamp <= DATE_ADD(
            e.first_purchase,
            INTERVAL 6 MONTH
        )
),

retention_data AS (
    SELECT
        COUNT(*) AS total_customers,
        COUNT(r.customer_unique_id) AS retained_customers
    FROM eligible_customers e
    LEFT JOIN retained_customers r
        ON e.customer_unique_id = r.customer_unique_id
)

SELECT
    total_customers,
    retained_customers,
    ROUND(
        100.0 * retained_customers / NULLIF(total_customers, 0),
        2
    ) AS retention_rate
FROM retention_data;

#Advanced 5 — Top 3 customers by spending in each year
WITH customer_year_sales AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS sales_year,
        c.customer_unique_id,
        SUM(oi.price) AS total_spent
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY
        YEAR(o.order_purchase_timestamp),
        c.customer_unique_id
),

ranked_customers AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY sales_year
            ORDER BY total_spent DESC
        ) AS customer_rank
    FROM customer_year_sales
)

SELECT
    sales_year,
    customer_unique_id,
    ROUND(total_spent, 2) AS total_spent,
    customer_rank
FROM ranked_customers
WHERE customer_rank <= 3
ORDER BY sales_year, customer_rank;

