/*
  00_bootstrap.sql

  THE ONE MANUAL STEP. Run this once, by hand, in Snowsight, logged in as
  ACCOUNTADMIN. Nothing after this point is manual — schemachange takes
  over from here and every future change is a migration file + a git push.

  Why this can't be a migration itself: schemachange needs somewhere to
  store its own change-history table (METADATA.SCHEMACHANGE.CHANGE_HISTORY),
  and it needs a role/warehouse/user to connect as *before* it has ever
  run. You can't bootstrap the bootstrapper. `--create-change-history-table`
  will create the SCHEMACHANGE schema and table for you later, but it will
  never create the METADATA database itself — that's a deliberate schemachange
  design choice, so this step does it.

  Run top to bottom. Safe to re-run (everything is CREATE ... IF NOT EXISTS
  or CREATE OR REPLACE where that's harmless).
*/

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 1. Database that will hold schemachange's own bookkeeping table.
--    Deliberately separate from the databases your migrations create, so
--    "drop my demo database and start over" never takes the change history
--    with it.
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS METADATA;

-- ---------------------------------------------------------------------------
-- 2. Warehouse the deploy job runs on.
--    XSMALL + 60s auto-suspend: trial credits are finite and migrations are
--    seconds of compute, not minutes. AUTO_RESUME so a scheduled/PR-triggered
--    run doesn't need anyone to manually wake it up first.
-- ---------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS DEPLOY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Used only by CI/CD deploys (schemachange). Not for interactive queries.';

-- ---------------------------------------------------------------------------
-- 3. Roles.
--    DEPLOY_ROLE: what the CI/CD service user operates as. Scoped to exactly
--    what schemachange needs — create/alter objects in the databases this
--    repo owns, plus USAGE on the deploy warehouse. NOT ACCOUNTADMIN, NOT
--    SYSADMIN. A leaked deploy key should cost you one database, not the
--    whole account.
--    ANALYST_ROLE: read-only role for people/tools querying the resulting
--    tables. Kept separate so "who can change schema" and "who can read
--    data" are two different questions with two different blast radii.
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS DEPLOY_ROLE
  COMMENT = 'Role the CI/CD pipeline (schemachange) operates as. Grants are widened per-database, not account-wide.';

CREATE ROLE IF NOT EXISTS ANALYST_ROLE
  COMMENT = 'Read-only role for humans/BI tools querying deployed schemas.';

-- DEPLOY_ROLE needs to create databases (the very first migration does
-- CREATE DATABASE) and needs the warehouse to run on.
GRANT CREATE DATABASE ON ACCOUNT TO ROLE DEPLOY_ROLE;
GRANT USAGE ON WAREHOUSE DEPLOY_WH TO ROLE DEPLOY_ROLE;
GRANT ALL ON DATABASE METADATA TO ROLE DEPLOY_ROLE;
GRANT ALL ON ALL SCHEMAS IN DATABASE METADATA TO ROLE DEPLOY_ROLE;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE METADATA TO ROLE DEPLOY_ROLE;
GRANT ALL ON ALL TABLES IN DATABASE METADATA TO ROLE DEPLOY_ROLE;
GRANT ALL ON FUTURE TABLES IN DATABASE METADATA TO ROLE DEPLOY_ROLE;

-- ANALYST_ROLE gets USAGE on the deploy warehouse too, so it has somewhere to
-- run SELECTs from — but no write grants. Those come from A__grants.sql,
-- which is itself a migration (so they're versioned like everything else).
GRANT USAGE ON WAREHOUSE DEPLOY_WH TO ROLE ANALYST_ROLE;

-- Let SYSADMIN see/manage these roles in the hierarchy, and grant both
-- roles to ACCOUNTADMIN so they don't become orphaned/unmanageable.
GRANT ROLE DEPLOY_ROLE TO ROLE SYSADMIN;
GRANT ROLE ANALYST_ROLE TO ROLE SYSADMIN;
GRANT ROLE DEPLOY_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE ANALYST_ROLE TO ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 4. Service user for GitHub Actions.
--    TYPE = SERVICE is the key line. A service user CANNOT have a password
--    at all — Snowflake rejects it outright. That's not a policy choice we're
--    making, it's enforced by the platform, which is exactly why we want it:
--    it's structurally impossible for this user to fall back to password auth,
--    even by accident, even under MFA Milestone 3 pressure (Aug-Oct 2026,
--    happening right now).
--    Auth is key-pair only, set up in the next README step (RSA_PUBLIC_KEY).
-- ---------------------------------------------------------------------------
CREATE USER IF NOT EXISTS SVC_GITHUB_DEPLOY
  TYPE = SERVICE
  DEFAULT_ROLE = DEPLOY_ROLE
  DEFAULT_WAREHOUSE = DEPLOY_WH
  COMMENT = 'CI/CD service user, GitHub Actions. Key-pair auth only (see README). No password possible: TYPE=SERVICE forbids it.';

GRANT ROLE DEPLOY_ROLE TO USER SVC_GITHUB_DEPLOY;

-- ---------------------------------------------------------------------------
-- Sanity check. Run this after and confirm:
--   - ROLE = DEPLOY_ROLE
--   - TYPE = SERVICE
--   - RSA_PUBLIC_KEY_FP is NULL for now (you set it in the next README step)
-- ---------------------------------------------------------------------------
DESCRIBE USER SVC_GITHUB_DEPLOY;
