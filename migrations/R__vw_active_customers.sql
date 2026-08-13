/*
  R__vw_active_customers.sql - REPEATABLE migration.

  Unlike V-scripts, this one isn't frozen — edit it anytime, the next
  deploy picks up the change automatically (schemachange checksums it
  and re-runs only if the content changed since last deploy).
*/

CREATE OR REPLACE VIEW {{ database_name }}.ANALYTICS.VW_ACTIVE_CUSTOMERS AS
SELECT
    customer_id,
    email,
    full_name,
    created_at
FROM {{ database_name }}.RAW.CUSTOMERS
WHERE status = 'active';
