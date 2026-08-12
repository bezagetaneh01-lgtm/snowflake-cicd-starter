/*
  V1.0.3 - Create the ORDERS table.

  Frozen once applied. FOREIGN KEY below is, again, metadata only (see
  V1.0.2 note) — Snowflake will happily let you insert an order_id
  referencing a customer_id that doesn't exist. It's declared anyway
  because query optimizers and BI tools can use it, and because it
  documents intent for the next person reading this schema.
*/

CREATE TABLE IF NOT EXISTS {{ database_name }}.RAW.ORDERS (
    order_id        NUMBER(38,0)    NOT NULL,
    customer_id     NUMBER(38,0)    NOT NULL,
    order_total     NUMBER(12,2)    NOT NULL,
    ordered_at      TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_orders PRIMARY KEY (order_id),                                    -- metadata only
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)                          -- metadata only
        REFERENCES {{ database_name }}.RAW.CUSTOMERS (customer_id)
);
