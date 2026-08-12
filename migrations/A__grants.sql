/*
  A__grants.sql - ALWAYS migration.

  Naming convention: A__<description>.sql. Runs on EVERY deploy, every
  time, unconditionally — no checksum gate, no "did this change" check.
  Reserved for statements that are safe and cheap to repeat and that you
  want re-asserted on every deploy regardless of drift (e.g. someone
  manually revoked a grant in Snowsight — this puts it back next push).

  Keep A__ scripts small and idempotent. This is not the place for anything
  with side effects that compound if run twice (nothing here does; GRANTs
  are naturally idempotent).
*/

GRANT USAGE ON DATABASE {{ database_name }} TO ROLE ANALYST_ROLE;
GRANT USAGE ON SCHEMA {{ database_name }}.ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA {{ database_name }}.ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ database_name }}.ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA {{ database_name }}.ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA {{ database_name }}.ANALYTICS TO ROLE ANALYST_ROLE;
