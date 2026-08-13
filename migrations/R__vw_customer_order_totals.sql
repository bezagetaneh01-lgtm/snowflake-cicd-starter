CREATE OR REPLACE VIEW {{ database_name }}.ANALYTICS.VW_CUSTOMER_ORDER_TOTALS AS
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    COUNT(o.order_id)      AS order_count,
    SUM(o.order_total)     AS lifetime_spend
FROM {{ database_name }}.RAW.CUSTOMERS c
LEFT JOIN {{ database_name }}.RAW.ORDERS o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.email;