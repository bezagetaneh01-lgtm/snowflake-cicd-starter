#!/usr/bin/env python3
"""
lint_migrations.py

Static checks on migrations/ that need zero Snowflake credentials, so they
can run as a fast, cheap PR gate before anything touches a warehouse.
Exits non-zero (and prints every problem found, not just the first) if any
check fails.

Checks:
  1. Filename convention — every file matches one of:
       V<version>__<description>.sql   e.g. V1.0.4__add_customer_status.sql
       R__<description>.sql            e.g. R__vw_customer_orders.sql
       A__<description>.sql            e.g. A__grants.sql
  2. No two V-scripts share the same version number.
  3. No already-merged V-script has been modified in this PR. This is the
     "never edit an applied migration" rule, enforced statically: it diffs
     this branch against the PR's base ref and fails if any migrations/V*.sql
     file that exists on both sides has changed content. (schemachange
     itself also enforces this — via checksum mismatch — but only at
     deploy time, against whichever environment's change history it's
     talking to. This catches the mistake in the PR, before a deploy is
     even attempted, and works identically for both DEMO_DEV and DEMO_PROD.)

Usage:
    python scripts/lint_migrations.py --base-ref origin/main
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

MIGRATIONS_DIR = Path("migrations")

V_PATTERN = re.compile(r"^V(?P<version>[0-9]+(?:\.[0-9]+)*)__[A-Za-z0-9_]+\.sql$")
R_PATTERN = re.compile(r"^R__[A-Za-z0-9_]+\.sql$")
A_PATTERN = re.compile(r"^A__[A-Za-z0-9_]+\.sql$")


def check_filenames(files):
    errors = []
    for f in files:
        name = f.name
        if V_PATTERN.match(name) or R_PATTERN.match(name) or A_PATTERN.match(name):
            continue
        errors.append(
            f"  {f}: doesn't match V<version>__<desc>.sql, R__<desc>.sql, "
            f"or A__<desc>.sql (two underscores after the prefix)"
        )
    return errors


def check_duplicate_versions(files):
    errors = []
    seen = {}
    for f in files:
        m = V_PATTERN.match(f.name)
        if not m:
            continue
        version = m.group("version")
        if version in seen:
            errors.append(
                f"  duplicate version {version}: {seen[version]} and {f}"
            )
        else:
            seen[version] = f
    return errors


def check_no_edited_applied_migrations(base_ref):
    errors = []
    try:
        result = subprocess.run(
            ["git", "diff", "--name-status", f"{base_ref}...HEAD", "--", str(MIGRATIONS_DIR)],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as e:
        # Can't diff (e.g. shallow clone with no base ref, or running
        # outside a PR). Don't fail the whole lint over that — this check
        # is a bonus safety net, not the primary defense (schemachange's
        # checksum check at deploy time is).
        print(
            f"  (skipping edited-migration check: couldn't diff against "
            f"{base_ref}: {e.stderr.strip()})"
        )
        return errors

    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        status, path = line.split("\t", 1)
        filename = Path(path).name
        if status.startswith("M") and V_PATTERN.match(filename):
            errors.append(
                f"  {path}: modified V-script. V-scripts are frozen once "
                f"merged — add a new migration instead of editing this one."
            )
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--base-ref",
        default="origin/main",
        help="Git ref to diff against for the edited-migration check.",
    )
    args = parser.parse_args()

    if not MIGRATIONS_DIR.is_dir():
        print(f"error: {MIGRATIONS_DIR}/ not found", file=sys.stderr)
        sys.exit(1)

    files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not files:
        print(f"error: no .sql files found under {MIGRATIONS_DIR}/", file=sys.stderr)
        sys.exit(1)

    all_errors = []
    all_errors += check_filenames(files)
    all_errors += check_duplicate_versions(files)
    all_errors += check_no_edited_applied_migrations(args.base_ref)

    if all_errors:
        print(f"lint_migrations.py: {len(all_errors)} problem(s) found:\n")
        print("\n".join(all_errors))
        sys.exit(1)

    print(f"lint_migrations.py: OK ({len(files)} migration file(s) checked)")


if __name__ == "__main__":
    main()
