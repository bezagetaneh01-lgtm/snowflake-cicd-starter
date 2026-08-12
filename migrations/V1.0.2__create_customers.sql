/*
  V1.0.2 - Create the CUSTOMERS table.

  Frozen once applied. Fully-qualified names throughout (see V1.0.1 note on
  why — session context does not carry between migration scripts).

  Constraint note: PRIMARY KEY / UNIQUE below are declared for documentation
  and for BI/ER tools that read Snowflake's metadata — Snowflake does not
  enforce them. The only constraint Snowflake actually enforces is NOT NULL.
  If you need real uniqueness guarantees, you must enforce them in the
  loading logic, not in the DDL.
*/

CREATE TABLE IF NOT EXISTS {{ database_name }}.RAW.CUSTOMERS (
    customer_id     NUMBER(38,0)   NOT NULL,
    email           VARCHAR(255)   NOT NULL,
    full_name       VARCHAR(255),
    created_at      TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)  -- metadata only, not enforced
);
