# snowflake-cicd-starter

Push to `main` → GitHub Actions deploys your `.sql` migrations to Snowflake
via [schemachange](https://github.com/Snowflake-Labs/schemachange). Open a
PR → the same migrations deploy to a dev database first, so you see the
result before it ever touches prod.

This is a learning build. Read `HOW-IT-WORKS`-style explanations in the
comments of every file — they're not filler, they're the point.

---

## How it fits together

```
git push main  ──▶  .github/workflows/deploy.yml  ──▶  schemachange  ──▶  DEMO_PROD
git PR         ──▶  .github/workflows/validate.yml ──▶  lint, then schemachange ──▶  DEMO_DEV
```

schemachange looks at `migrations/`, compares it against a table it keeps
inside Snowflake (`METADATA.SCHEMACHANGE.CHANGE_HISTORY`) recording what's
already been applied, and runs only what's new. That table is *why* this
is stateful and a bash loop over `.sql` files isn't — see
`WHY-NOT-THE-SIMPLE-VERSION.md`.

---

## Setup, in order

### 1. Generate a key pair

Snowflake service users can't use passwords (enforced by the platform, not
a policy choice — see "Why key-pair auth" below). Auth is RSA key-pair.

```bash
# Private key, encrypted with a passphrase you choose.
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out snowflake_key.p8

# Corresponding public key.
openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
```

You'll be prompted for the passphrase twice (encrypt, then confirm to
extract the public key). Remember it — it becomes the
`SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` GitHub Secret in step 3.

### 2. Run the bootstrap SQL

Open Snowsight, log in as **ACCOUNTADMIN**, paste in
`setup/00_bootstrap.sql`, run it top to bottom. This is the one manual
step in the whole setup — see the comment block at the top of that file
for why it can't be a migration.

Then register the public key on the service user and confirm it took:

```sql
USE ROLE ACCOUNTADMIN;

ALTER USER SVC_GITHUB_DEPLOY SET RSA_PUBLIC_KEY = '<contents of snowflake_key.pub,
  without the -----BEGIN/END PUBLIC KEY----- lines and without line breaks>';

DESC USER SVC_GITHUB_DEPLOY;
-- Confirm RSA_PUBLIC_KEY_FP is now populated (not NULL). That fingerprint
-- is Snowflake's proof it has your key on file.
```

You'll also need two databases for the two environments this repo deploys
to — create them (or let the first deploy's `CREATE DATABASE IF NOT EXISTS`
in `V1.0.1` do it, once `DEPLOY_ROLE` has `CREATE DATABASE` — the bootstrap
already grants that account-wide):

```sql
-- optional, schemachange will also create these on first deploy
CREATE DATABASE IF NOT EXISTS DEMO_DEV;
CREATE DATABASE IF NOT EXISTS DEMO_PROD;
```

### 3. Add GitHub Secrets

Repo → Settings → Secrets and variables → Actions → New repository secret.

| Secret | Value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your account identifier, `ORGNAME-ACCOUNTNAME` — **hyphen, not dot**. This is the single most common setup failure; double-check it. |
| `SNOWFLAKE_USER` | `SVC_GITHUB_DEPLOY` |
| `SNOWFLAKE_PRIVATE_KEY` | Full contents of `snowflake_key.p8`, including the `-----BEGIN/END PRIVATE KEY-----` lines. |
| `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | The passphrase you set in step 1. |

Never commit `snowflake_key.p8` or `snowflake_key.pub`. `.gitignore` in
this repo already excludes `*.p8` as a backstop, but the primary control
is: they never leave your machine except as pasted-in Secret values.

### 4. First deploy

Push this repo to GitHub, then trigger the workflow by hand once:
Actions tab → "Deploy to Snowflake (PROD)" → Run workflow.

**Read the "Dry run" step's log.** schemachange prints exactly what it's
about to do — which migrations are new, which are already applied and
unchanged, which (if any) failed a checksum check — without touching
Snowflake. It's the clearest explanation of what this tool actually does,
better than anything in this README.

Then watch the "Deploy" step actually apply `V1.0.1` through `A__grants.sql`
against `DEMO_PROD`.

### 5. See incremental deploys work

Add a new file, e.g. `migrations/V1.0.5__add_customer_notes.sql`:

```sql
ALTER TABLE {{ database_name }}.RAW.CUSTOMERS
    ADD COLUMN IF NOT EXISTS notes VARCHAR(1000);
```

Push it. Watch the next deploy run *only* `V1.0.5` — everything before it
is already recorded in change history and gets skipped. That's the whole
value proposition versus the bash-loop approach in one push.

---

## Why key-pair auth, not password

Snowflake's MFA rollout Milestone 3 (Aug–Oct 2026 — happening now) removes
password auth for service-type users. `SVC_GITHUB_DEPLOY` is created with
`TYPE = SERVICE`, and a `SERVICE` user cannot have a password at all —
Snowflake rejects it at the platform level. So this isn't "we chose the
more secure option," it's "the less secure option is not on the table."
Source: <https://docs.snowflake.com/en/user-guide/security-mfa-rollout>.

## Why a dedicated role instead of ACCOUNTADMIN

`DEPLOY_ROLE` can create databases and operate the deploy warehouse. It
cannot touch account-level settings, other users, billing, or anything
outside what these migrations need. If the GitHub Secret holding the
private key ever leaks, the blast radius is "attacker can modify the
databases this repo owns," not "attacker owns the account."

## What PR vs main actually changes

Nothing in the SQL. `V1.0.1` says `{{ database_name }}`, never a literal
`DEMO_DEV` or `DEMO_PROD`. The workflow sets `TARGET_DATABASE` and passes
it to schemachange as a Jinja variable (`--vars`), so the exact same
migration files run against whichever database the trigger implies. This
is what "the code path is identical between dev and prod" means in
practice.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `250001: Could not connect to Snowflake backend` | Account identifier is wrong — check for a dot where there should be a hyphen (`ORGNAME.ACCOUNTNAME` vs `ORGNAME-ACCOUNTNAME`). |
| `JWT token is invalid` | Public key registered on the user doesn't match the private key in the secret, or the key was re-generated after `ALTER USER ... SET RSA_PUBLIC_KEY` and not re-registered. Re-run `DESC USER SVC_GITHUB_DEPLOY` and compare `RSA_PUBLIC_KEY_FP`. |
| Passphrase seems to be ignored / prompts or fails silently | schemachange does not accept the passphrase as a CLI flag, only via the `SNOWFLAKE_PRIVATE_KEY_FILE_PWD` env var (or `connections.toml`). Confirm the workflow step sets that exact env var name — older guides use `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`, which schemachange no longer reads. |
| `Private key file not found` type error | The key must be a **file path**, not the raw key string. Confirm the "Stage private key" step ran and wrote to `$RUNNER_TEMP` before the deploy step. |
| Deploy fails with a checksum mismatch on an old V-script | Someone edited an already-applied migration file. Don't fix the old file — write a new one (see `V1.0.4`'s comment for the full explanation). |
| `Object does not exist` inside a migration that clearly creates it earlier | Missing fully-qualified name. Session context does **not** carry across migration scripts — `USE DATABASE` in one file has no effect in the next. |
| A migration with a `BEGIN ... END` block errors on the first statement inside it | The connector splits scripts on semicolons client-side, which breaks multi-statement blocks. Wrap the whole block in `EXECUTE IMMEDIATE $$ ... $$;`. |
| schemachange silently runs `SELECT 1` you didn't write | A trailing comment at the very end of a migration file, with nothing after it. Add a blank line or remove the trailing comment. |
| PR's `deploy` job on `validate.yml` never appears / lint job hangs | `fetch-depth: 0` missing from the checkout step — the edited-migration check in `lint_migrations.py` needs full git history to diff against `origin/main`. |
| Everything works locally, `supabase db push`-style "did nothing" behavior *(not applicable here, that's the Supabase repo's issue — included for cross-reference)* | See `supabase-cicd-starter/README.md`. |

---

## What's deliberately not built yet

- **Staging/prod split with required reviewer.** `environment: production`
  is already stubbed into `deploy.yml`'s `deploy` job — it does nothing
  until you create a GitHub Environment named `production` under
  Settings → Environments and add a required reviewer there.
- **OIDC / Workload Identity Federation.** Secretless auth, shipped by
  Snowflake in Aug 2025, strictly better than a long-lived stored key —
  no `SNOWFLAKE_PRIVATE_KEY` secret to leak in the first place. Deferred
  because it's a bigger jump for a first build; key-pair auth is the more
  common starting point and everything above still applies conceptually.
- **dbt.** The transformation layer that typically sits on top of a setup
  like this — migrations create the raw structure, dbt owns the modeling
  logic on top. Not built here; this repo stops at schema/DDL management.
