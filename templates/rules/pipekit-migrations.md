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
4. **Re-check right before merge, not only at creation.** A long-lived branch can be overtaken: another branch may land a same-day migration on the base branch *after* you picked your timestamp. The collision is invisible in your worktree — it passes local validation and `/verify`, because both only ever see your branch's tree. Immediately before merge, fetch the base branch and re-compare your new migrations against its current tail:
   ```bash
   git fetch origin <integration-branch>
   # your branch's new migration timestamps:
   git diff --name-only "origin/<integration-branch>...HEAD" -- supabase/migrations/ | sort
   # the base branch's current migration tail:
   git ls-tree -r --name-only "origin/<integration-branch>" -- supabase/migrations/ | sort | tail -5
   ```
   If your earliest new migration is not strictly later than the base tail, rename now — pre-merge is still before the freeze on the base DB — per step 3. (Anchor: Piper WIT-550, 2026-06-02 — a same-day migration merged to `dev` mid-session collided on merge after passing all local checks.)

## Manual Schema Changes on Remote Envs

<important>
Never run ad-hoc SQL against a remote env's schema (CREATE TABLE, ALTER TABLE, GRANT, etc.) outside a migration file. Doing so creates an "invisible" schema change — the history table has no record, but the schema diverges from filesystem reality.
</important>

If incident recovery forces a one-off SQL fix, follow up *immediately* with a backfill migration that re-asserts the change via standard DDL. Idempotent guards (`CREATE TABLE IF NOT EXISTS`, `DO ... pg_constraint`, `CREATE OR REPLACE`) let the migration apply cleanly on envs that already have the change.

The `supabase migration repair` command is the one sanctioned exception — it edits the history table to reconcile drift without touching the schema. It still requires explicit human confirmation per `pipekit-security.md` (shared-state mutation on a non-local DB).

### MCP-applied migrations and disk drift

<important>
Never use `mcp.apply_migration` (Supabase MCP server's migration tool) for SQL that will also exist as a committed disk file under `supabase/migrations/`. The MCP tool auto-stamps the applied version with the server's wall-clock time, producing a timestamp that does not match the disk filename. The next `supabase db push` from CI or a human will detect drift between disk and remote history and refuse to apply any further migrations until reconciled.
</important>

The auto-stamp writes a wall-clock version into the remote history that doesn't match the disk filename; the next `supabase db push` (CI or human) detects the mismatch and refuses **all** further migrations until repaired — and the repair (`supabase migration repair`) is a shared-state mutation needing human confirmation per `pipekit-security.md`. Full failure anatomy + recovery walkthrough in `sop/Database_SOP.md` § MCP-applied migrations.

**Prescribed workaround for testing a migration against a live env before merge:** `supabase db push` against a per-PR branch DB or a throwaway local reset — the CLI uses the disk filename verbatim, no auto-stamping. One-off forensics that genuinely belong outside the migration chain: apply via `psql` or the SQL editor, then immediately backfill an idempotent disk migration per Manual Schema Changes above. The MCP tool stays fine for greenfield exploration (no disk file yet) and read-only operations; the rule is specifically about the write path colliding with the disk migration chain.

Anchor: Piper WIT-514, 2026-05-27 — an MCP-applied RPC stamped `piper-dev`'s history at wall-clock while the disk file shipped with a different timestamp; ~5h of deploy lockup across every in-flight migration PR; reconciled by PR #393 backfilling the disk file at the MCP-stamped version.

## Silent-Failure Patterns (authoring-time checks)

The frozen-file invariant catches rename/edit-after-apply. These three incident-anchored invariants catch a different class: migrations that *apply cleanly* but produce silently-wrong runtime behavior (empty reads, duplicate child rows, seed-time constraint violations) — a "looks idempotent" migration can still ship a data-shape footgun that surfaces at read time. Check them when authoring; full failure narratives + discipline in `sop/Database_SOP.md` § Silent-Failure Patterns.

- **Parent gains a version column** (`snapshot_id`, `revision_id`, …) ⇒ every descendant's FK to the version is NOT NULL **or** carries an explicit global sentinel — nullable + filter-by-version = silent-empty reads. Audit: `grep -r "snapshot_id\|version_id\|revision_id" supabase/migrations | grep -iE "null|nullable"`
- **A trigger auto-creates a default child row** ⇒ fixtures/seeds must FETCH via the canonical helper (`ensure_<child>()`), never insert a competing row. Audit: `grep -rE "CREATE TRIGGER.*(BEFORE|AFTER) INSERT" supabase/migrations` — any trigger inserting into a child table needs a paired retrieval helper.
- **Adding a CHECK constraint to an existing column** ⇒ audit the column's DEFAULT in the same migration — a stale DEFAULT outside the allowed set breaks schema-dump-derived seeds later. Audit: `SELECT column_default FROM information_schema.columns WHERE table_name='<t>' AND column_name='<c>';`

## What Goes Wrong When This Is Violated

`db push` fails on merge/deploy with a history-table mismatch; the merge blocks UAT until a `supabase migration repair` (shared-state mutation, human-confirmed) reconciles disk and history; every WIT queued behind the deploy waits. Cost grows with environment seniority — dev cheap, beta moderate, prod expensive. The point of this rule is to keep all of it at zero.
