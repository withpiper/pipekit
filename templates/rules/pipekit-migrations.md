# Database Migration Rules

Discipline for projects with a versioned migration system (Supabase, Prisma, Knex, Alembic, Rails, etc.). Once a migration touches any environment, its identity and content are frozen — the only way to "undo" or "fix" is a *new* migration.

If the project does not use a versioned migration system, this rule is informational and need not be enforced.

## The Frozen-File Invariant

<important>
Once a migration file has been applied to any environment (local dev DB, preview branch DB, dev, beta, prod), the file is immutable. No rename. No content edit. No delete.
</important>

This invariant exists because every environment records what it applied by **filename and timestamp** in its `schema_migrations` (or equivalent) history table. Renaming or editing a file after it's been applied creates a mismatch between what the env believes it applied and what's on disk. The result is "migration history drift" — `db push` fails on the next deploy with errors like *"Remote migration versions not found in local migrations directory"*, blocking the merge until manual repair.

If you need to:

- **Fix a bug in an applied migration** → write a new migration that corrects the state.
- **Harden an applied migration** (e.g., closing critical findings from `/db-review`) → write a hardening migration with a later timestamp. Never edit the original.
- **Revert an applied migration** → write a reverting migration (DDL that undoes the state). Do not delete the file from the filesystem.

The exception is migrations that have **never been applied anywhere**: while a feature branch is being authored locally and the migration hasn't been pushed to any DB (not even local Supabase via `supabase db reset`), the file is still mutable. The moment it runs against any DB, the freeze begins.

## Hardening During Review

When `/db-review`, `/pr-security-review`, or a human reviewer flags a critical issue in a migration that's already been applied to a preview branch DB:

1. **Do not** edit the original migration file.
2. **Do not** rename it to "fix the version number."
3. **Do** add a new hardening migration with a later timestamp that closes the finding via additional DDL (`ALTER`, `DROP CONSTRAINT IF EXISTS`, `REVOKE`, etc.) on the same objects.
4. Reference the original migration's filename in the hardening migration's header comment so reviewers can trace the chain.

## Parallel Branch Coordination

When two feature branches each add migrations targeting the same remote DB on merge:

1. **Before** running `supabase migration new` (or the equivalent for your migration tool), `git pull` the base branch and check the latest applied timestamp:
   ```bash
   supabase migration list --linked   # or: ls supabase/migrations/ | sort | tail -3
   ```
2. Pick a timestamp **strictly later** than every applied-to-remote migration.
3. If you discover a collision after the fact (your branch's migration timestamp is earlier than a migration that landed on the base branch while you were working), **rename the file** *before* the migration is applied anywhere — including local Supabase. This is a legitimate rename window, before the freeze begins.

## Manual Schema Changes on Remote Envs

<important>
Never run ad-hoc SQL against a remote env's schema (CREATE TABLE, ALTER TABLE, GRANT, etc.) outside a migration file. Doing so creates an "invisible" schema change — the history table has no record, but the schema diverges from filesystem reality.
</important>

If incident recovery forces a one-off SQL fix, follow up *immediately* with a backfill migration that re-asserts the change via standard DDL. Idempotent guards (`CREATE TABLE IF NOT EXISTS`, `DO ... pg_constraint`, `CREATE OR REPLACE`) let the migration apply cleanly on envs that already have the change.

The `supabase migration repair` command is the one sanctioned exception — it edits the history table to reconcile drift without touching the schema. It still requires explicit human confirmation per `pipekit-security.md` (shared-state mutation on a non-local DB).

## What Goes Wrong When This Is Violated

The forensic recovery path is non-trivial:

1. `supabase db push` fails on merge or deploy with a history-table mismatch.
2. The merge commit becomes the trigger, blocking UAT until repaired.
3. Repair requires `supabase migration repair --status reverted <orphan> --status applied <new>` against the env's history table — a shared-state mutation.
4. Multiple WITs queued behind the failed deploy block until repair completes.

Cost grows with environment seniority: dev is cheap (greenfield-test, low blast radius), beta is moderate (shared with other devs), prod is expensive (real users, real data). The point of this rule is to keep all of those at zero.
