# Why not the bash-loop version?

Snowflake's own chatbot suggested something like this as a GitHub Actions
step:

```bash
for f in migrations/*.sql; do
  snowsql -f "$f"
done
```

That's a reasonable thing for a chatbot to suggest — it's not wrong that
this *runs* SQL files against Snowflake on a push. It's worth being clear
about what it gets right before explaining why this repo doesn't do it.

## What it gets right

- It's genuinely simpler. No extra tool, no config file, no change-history
  table to reason about. For a one-time script or a database with exactly
  one person touching it, that simplicity has real value.
- Ordering by filename (`01_x.sql`, `02_y.sql`, ...) is an honest, readable
  way to express "these run in this order."
- It correctly identifies that the core mechanism is "push triggers a
  script that runs SQL." That part is right — schemachange doesn't do
  anything conceptually different, it just does the bookkeeping around it.

## What it misses: it has no memory

Every push re-runs every file, every time, from `01` to the end. The loop
itself doesn't know anything ran before. Two consequences, both immediate
and both worse the longer the repo lives:

1. **It doesn't scale.** Migration #200 means 200 statements re-executed on
   every single push, forever, even though 199 of them are no-ops. On a
   trial account with finite credits, that's not hypothetical waste — it's
   burning real money re-running the same `CREATE TABLE` your first commit
   already applied.

2. **It breaks the moment a script isn't safely re-runnable.** `CREATE
   TABLE IF NOT EXISTS` tolerates being re-run. `ALTER TABLE ... ADD
   COLUMN status ...` (this repo's `V1.0.4`) does not — run it twice and
   the second run fails, because the column already exists. The loop has
   no way to know "I already did this one, skip it." The only way to make
   every migration safely re-runnable forever is to hand-write elaborate
   `IF NOT EXISTS` / `IF COLUMN NOT EXISTS`-style guards into *every* file,
   which is more code than schemachange's actual job, written badly, by
   hand, per migration.

schemachange's entire value proposition is one table:
`METADATA.SCHEMACHANGE.CHANGE_HISTORY`. Every deploy, it asks "what's
already recorded as applied here?" and runs only what isn't. That's *all*
it does beyond the loop — but that one piece of state is the difference
between "re-run everything, hope nothing breaks" and "run only what
changed."

## What else the loop leaves out

These aren't fatal on their own, but they're all state schemachange gives
you for free that a loop doesn't:

- **Tamper detection.** schemachange checksums every applied V-script.
  Edit one after it's already run somewhere, and the next deploy against
  that environment fails loudly with a checksum mismatch, instead of
  silently applying a change you may not have meant to make permanent (see
  `migrations/V1.0.4__add_customer_status.sql`'s comment for the concrete
  example). A loop has no concept of "this file changed since last time."
- **Dev/prod from one codebase.** This repo's migrations reference
  `{{ database_name }}` and the same files deploy to `DEMO_DEV` from a PR
  or `DEMO_PROD` from `main`, controlled entirely by which workflow ran.
  Templating like that isn't something `snowsql -f` gives you — you'd be
  hand-rolling `sed` substitutions or maintaining two copies of every file.
- **A dry-run.** `schemachange deploy --dry-run` shows exactly what would
  execute, and why, before it touches Snowflake. Genuinely useful the
  first time you run this against a real account, and the loop has no
  equivalent.

## When the loop actually would be the right call

If the goal were "run this SQL file against Snowflake from CI" — one file,
or a small fixed set that never changes — the loop is legitimately less to
maintain and easier to explain to a teammate at a glance. It stops being
the right call the moment you need "don't re-run what already ran," which
is exactly the moment a schema starts changing over time instead of being
defined once. That's true of essentially any real project past its first
few days, which is why this repo is built on schemachange instead.
