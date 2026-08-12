/*
  V1.0.1 - Create the application database and its schemas.

  This is migration #1 in the strict schemachange sense: it's the first
  thing that runs, and once it has run against an environment, this file
  is FROZEN. Never edit it again — see V1.0.4 for what to do instead when
  you need to change something this file already created.

  Reminder: session context resets after every migration script.
  `USE DATABASE {{ database_name }}` here does NOT carry over into
  V1.0.2. Every object below (and in every later migration) is fully
  qualified: {{ database_name }}.SCHEMA.OBJECT. This is not stylistic
  preference, it's required — Snowflake does not persist USE statements
  across separate script executions the way a psql session would.
*/

CREATE DATABASE IF NOT EXISTS {{ database_name }};

CREATE SCHEMA IF NOT EXISTS {{ database_name }}.RAW
  COMMENT = 'Landing schema for source-shaped data. Nothing here should be treated as a stable contract.';

CREATE SCHEMA IF NOT EXISTS {{ database_name }}.ANALYTICS
  COMMENT = 'Modeled / query-ready objects. This is what ANALYST_ROLE reads from.';
