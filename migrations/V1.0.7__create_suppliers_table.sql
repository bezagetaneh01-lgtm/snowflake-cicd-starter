/*
  V1.0.7 - Create the SUPPLIERS table.
*/

CREATE TABLE IF NOT EXISTS {{ database_name }}.RAW.SUPPLIERS (
    supplier_id     NUMBER(38,0)   NOT NULL,
    supplier_name   VARCHAR(255)   NOT NULL,
    contact_email   VARCHAR(255),
    created_at      TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_suppliers PRIMARY KEY (supplier_id)  -- metadata only, not enforced
);