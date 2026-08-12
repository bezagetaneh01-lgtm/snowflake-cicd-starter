/*
  V1.0.5 - Create the PRODUCTS table.

  First migration added after the pipeline was already live. Nothing
  special about it mechanically — same rules as every other V-script:
  fully-qualified names, frozen once applied, additive only. The point of
  this one is watching the Dry run log recognize it as the only new file
  and skip V1.0.1 through V1.0.4 and R__vw_customer_orders.sql entirely.
*/

CREATE TABLE IF NOT EXISTS {{ database_name }}.RAW.PRODUCTS (
    product_id      NUMBER(38,0)   NOT NULL,
    product_name    VARCHAR(255)   NOT NULL,
    price           NUMBER(12,2)   NOT NULL,
    created_at      TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_products PRIMARY KEY (product_id)  -- metadata only, not enforced
);
