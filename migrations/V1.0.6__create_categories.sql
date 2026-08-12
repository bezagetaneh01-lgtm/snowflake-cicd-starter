/*
  V1.0.6 - Create the CATEGORIES table.

  First migration deployed via the PR path instead of straight to main.
  Same file, same rules — the only thing different this time is which
  workflow picks it up (validate.yml on the PR, targeting DEMO_DEV,
  instead of deploy.yml on main, targeting DEMO_PROD).
*/

CREATE TABLE IF NOT EXISTS {{ database_name }}.RAW.CATEGORIES (
    category_id     NUMBER(38,0)   NOT NULL,
    category_name   VARCHAR(255)   NOT NULL,
    created_at      TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_categories PRIMARY KEY (category_id)  -- metadata only, not enforced
);
