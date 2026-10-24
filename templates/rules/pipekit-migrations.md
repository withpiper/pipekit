# Database Migration Rules

For projects with a versioned migration system (Supabase, Prisma, Knex, Alembic, Rails, …); informational otherwise. Full narratives and recovery: `sop/Database_SOP.md`.

## The Frozen-File Invariant

<important>
Once a migration has been applied to any environment (local DB, preview branch, dev, beta, prod), the file is immutable. No rename, no content edit, no delete.
</important>

Every environment records applied migrations by filename/timestamp; changing an applied file causes history drift and `db push` refuses the next deploy. To fix, harden or revert an applied migration, write a **new** migration. A migration never applied anywhere (not even `supabase db reset`) is still mutable.

## Hardening During Review

When a review flags a critical issue in a migration already applied to a preview DB: don't edit or rename the original. Add a later-timestamped hardening migration (`ALTER`, `DROP CONSTRAINT IF EXISTS`, `REVOKE`, …) and cite the original's filename in its header comment.

## Parallel Branch Coordination

1. Before creating a migration, `git pull` the base branch and check the latest applied timestamp (`supabase migration list --linked`, or `ls supabase/migrations/ | sort | tail -3`).
2. Pick a timestamp **strictly later** than every applied-to-remote migration.
3. On a collision found after the fact, rename the file **before** it is applied anywhere, including local Supabase — that window is legitimate.
4. **Re-check right before merge.** Another branch may have landed a later migration since; your worktree and `/verify` can't see it.
   ```bash
   git fetch origin <integration-branch>
   git diff --name-only "origin/<integration-branch>...HEAD" -- supabase/migrations/ | sort
   git ls-tree -r --name-only "origin/<integration-branch>" -- supabase/migrations/ | sort | tail -5
   ```
   If your earliest new migration is not strictly later than the base tail, rename now (step 3).

## Manual Schema Changes on Remote Envs

<important>
Never run ad-hoc schema SQL (CREATE, ALTER, GRANT, …) against a remote env outside a migration file.
</important>

If incident recovery forces one, immediately backfill an idempotent migration (`IF NOT EXISTS`, `CREATE OR REPLACE`, `DO … pg_constraint`). `supabase migration repair` is the one sanctioned history edit and needs explicit human confirmation.

### MCP-applied migrations and disk drift

<important>
Never use `mcp.apply_migration` for SQL that will also exist as a committed file under `supabase/migrations/`. It stamps the remote history with wall-clock time, which won't match the disk filename, and every later `db push` refuses until repaired.
</important>

To test against a live env before merge, `supabase db push` to a per-PR branch DB or a throwaway local reset. For one-off forensics outside the chain, use `psql` or the SQL editor and immediately backfill an idempotent disk migration. The MCP tool stays fine for greenfield exploration and read-only queries.

## Silent-Failure Patterns (authoring-time checks)

Migrations that apply cleanly but produce silently-wrong runtime behavior. Check when authoring:

- **Parent gains a version column** (`snapshot_id`, `revision_id`, …) ⇒ every descendant's FK to it is NOT NULL **or** carries an explicit global sentinel; nullable + filter-by-version = silent-empty reads. Audit: `grep -r "snapshot_id\|version_id\|revision_id" supabase/migrations | grep -iE "null|nullable"`
- **A trigger auto-creates a default child row** ⇒ fixtures/seeds FETCH it via the canonical helper (`ensure_<child>()`), never insert a competing row. Audit: `grep -rE "CREATE TRIGGER.*(BEFORE|AFTER) INSERT" supabase/migrations` — every trigger inserting into a child table needs a paired retrieval helper.
- **Adding a CHECK to an existing column** ⇒ audit that column's DEFAULT in the same migration; a DEFAULT outside the allowed set breaks schema-dump-derived seeds later. Audit: `SELECT column_default FROM information_schema.columns WHERE table_name='<t>' AND column_name='<c>';`
