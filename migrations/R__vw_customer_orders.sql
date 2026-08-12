/*
  R__vw_customer_orders.sql - REPEATABLE migration.

  Naming convention: R__<description>.sql, note the double underscore —
  same convention family as V<version>__ and A__, no version number because
  repeatables don't have one.

  Unlike V-scripts, this is not frozen. schemachange checksums this file on
  every deploy; if the content has changed since last time it ran against an
  environment, it re-runs. If it's unchanged, it's skipped. This makes views
  (and other logic you actively iterate on) practical to keep under version
  control without the "never edit it again" rule that applies to V-scripts —
  edit this file freely and the next deploy picks it up.

  CREATE OR REPLACE is intentional and required here, not just style: a
  repeatable script needs to be safely re-runnable, and OR REPLACE is what
  makes re-running it idempotent.
*/

CREATE OR REPLACE VIEW {{ database_name }}.ANALYTICS.VW_CUSTOMER_ORDERS AS
SELECT
    c.customer_id,
    c.email,
    c.full_name,
    c.status,
    COUNT(o.order_id)              AS order_count,
    COALESCE(SUM(o.order_total), 0) AS lifetime_value
FROM {{ database_name }}.RAW.CUSTOMERS c
LEFT JOIN {{ database_name }}.RAW.ORDERS o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.email, c.full_name, c.status;
