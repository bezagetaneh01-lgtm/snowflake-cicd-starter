/*
  V1.0.4 - Add a STATUS column to CUSTOMERS.

  *** This file is the whole point of the demo. ***

  What NOT to do: go back and edit V1.0.2 to add this column to the
  original CREATE TABLE. schemachange fingerprints every applied migration
  (checksum stored in METADATA.SCHEMACHANGE.CHANGE_HISTORY). If you edit
  V1.0.2 after it has already run somewhere, schemachange will refuse to
  proceed on that environment the next time it deploys — checksum mismatch,
  deploy fails, on purpose. That's the tool protecting you from silently
  rewriting history that some environment has already applied.

  What TO do instead, always: write a new, additive, forward-only
  migration. That's this file.
*/

ALTER TABLE {{ database_name }}.RAW.CUSTOMERS
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active';
