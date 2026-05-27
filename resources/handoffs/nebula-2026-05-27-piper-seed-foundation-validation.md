# Handoff — Piper PR #379 (Foundation Seed) Ready For UAT

**From:** Nebula · 2026-05-27
**Status:** Migration applies cleanly locally; awaiting browser UAT before merge.

## What's Done

- Pipekit **v2.7.0-rc1** tagged at `c36c080` and pushed to `origin`.
  - Discipline substrate (Completion Claims + Plan Gate two-tier) in `pipekit-discipline.md`
  - Source authority hierarchy + UNVERIFIED flag + Enumerate-the-Surface rule in `pipekit-tooling.md`
  - `/verify` rewrite with tier-aware evidence layer (`Logs/Verify/<date>/<id>/`)
  - `pk ship` hard-fails on missing `verify-complete.md` for `tier:standard|heavy`
  - Step 5 antagonistic review (verbatim DOUBT prompt) — mandatory `tier:heavy`, opt-in `tier:standard --review`
- Validated end-to-end against **Piper WIT-419 (Tax Code Library)** — 4 `/verify` cycles, 10 production-impacting findings caught that v2.6 wouldn't have.
- **Piper workflow polling bound** raised 120s → 300s — PR #376 merged.
- **Migration timestamp collision** (WIT-275 + WIT-512) fixed via PR #380 (rename to `20260526123222`).
- **Piper PR #379** — foundation seed (2 users × 2 entities × membership matrix):
  - Migration: `supabase/migrations/20260527110000_seed_dual_user_dual_entity.sql`
  - All five iterative fixes landed: `tax_pct` overflow, `handle_new_user` trigger collision, `clients.entity_id` NOT NULL, `budget_snapshots.status` (doesn't exist), `entity_memberships` natural-key conflict target.
  - **`supabase db reset` now succeeds locally on main** (confirmed 2026-05-27).

## What's Next (in order)

1. **Browser UAT against `<project>-dev`** — log into preview as each user, verify role-gated UI matches the matrix:

   | User | Email | Password | Q-Prod | P-Prod |
   |---|---|---|---|---|
   | QA | `qa@piper.dev` | `qa-piper-2026` | admin | producer |
   | Ethan | `ethan@withpiper.ai` | `piperlives!` | producer | admin |

   Project URLs are on org/entity pages once logged in. Confirm: admin sees admin-only controls on their entity; producer sees producer-restricted view on the other.

2. **Merge PR #379** once UAT passes.

3. **Reset/decide on WIT-275 + WIT-512** — both shipped to dev. User said "on deck" but wanted seed work finished first. Pick next via `pk next` from main.

## What's Deferred

- **`/seed-pr-fixtures` Pipekit skill** — prompt-driven budget seeding (sections, sub-sections, line items attributed to a client) so per-PR test fixtures don't require migration churn. Static foundation stays; budget content goes through the prompt. Draft when you next touch tax/FX functionality and need real budgets.
- **3 unpushed Pipekit commits** (decommission docs, seeding strategy, Step 0.5) — ride with v2.7.0 **stable** cut, not rc1:
  - `a09686c docs(sop,resources): solo-dev branch-DB exception + decommission runbook`
  - `912ddab docs(sop,resources): seeding strategy as Path A, decommission as Path B fallback`
  - `ee2222d docs(resources): seed-strategy runbook Step 0.5 — sync-workflow reliability`
- **Week 4 `/pr-fix` full subagent dispatch** — substantial. Fresh session.

## Open Threads / Watch Items

- **WIT-524** (Linear, Triage): CI/CD vercel-supabase-sync.yml — migration-bearing PR previews not bound to per-PR branch DB (WIT-384 contract violation). Filed via the foundation-seed thread on 2026-05-27 after the bug blocked dev deploys for ~5 hours. Recovery: PR #393 (backfilled the missing disk file at the auto-stamped timestamp). Systemic fix still owed.
- **PR #393** (Piper): merged 2026-05-27. Backfilled `supabase/migrations/20260527105344_wit-514_reorder_line_items_rpc.sql` directly to dev (pure rename from WIT-514's `3542e38`) to reconcile a timestamp drift between disk and remote that locked up `supabase db push`. Sample of the broader WIT-524 surface.
- **`fix(db):` hook false-positive** in Piper — commits with valid `{type}({scope}): {desc}` format keep getting flagged. Non-blocking (commits push regardless), but worth a separate bug. Suspect heredoc body content tripping it. Same pattern across PRs #380, #381, #379.
- **Port 54322 collision** — WIT-419 worktree's Supabase still running. Run `supabase stop --project-id piper-WIT-419-tax-code-tax` from inside that worktree before next worktree boot.
- **`agent isolation: "worktree"` is still a no-op on this harness** — orchestrators must `git worktree add` explicitly + pass `cwd:`. See `[[agent_isolation_worktree_broken]]`.

## Pipekit Gaps Surfaced This Session

Backlog candidates for upstream Pipekit work, ordered by recurrence likelihood.

### 1. `pipekit-migrations.md` missing the "real-user email collision" pattern

The frozen-file rule already covers schema drift. It does NOT cover the data-shape footgun where a seed migration INSERTs into `auth.users` with sentinel ids + email-shaped values, then collides with real users in any environment where someone has logged in via OAuth using the same email.

Concrete failure observed today: `20260527110000_seed_dual_user_dual_entity.sql` succeeded on local + branch DBs but failed on piper-dev with `users_email_partial_key (23505)` because real `ethan@withpiper.ai` already existed from OAuth login. The `handle_new_user` trigger fired on the seed's `INSERT INTO auth.users` and tried to create a duplicate `public.users` row.

**Recovery pattern (worth promoting to a runbook):**
1. Investigate the env via Supabase MCP — find real user ids by email
2. Write a lookup-or-create replacement migration that detects real users and reuses their ids; sentinel-creates only when no real row exists
3. Mark the failing migration as `applied` on the shared env via INSERT into `supabase_migrations.schema_migrations` (sanctioned per migrations.md § Manual Schema Changes; requires explicit human confirmation)
4. Merge the replacement; workflow skips the failing migration, applies the safe one

**Proposed Pipekit changes:**
- Add to `pipekit-migrations.md` § "Silent-Failure Patterns to Watch For": a new subsection "Sentinel-id seeds colliding with real users via email"
- Add a `resources/` runbook documenting the migration-repair recovery dance (the MCP INSERT against `schema_migrations.statements`, with the fix-forward pointer comment as audit trail)
- Same pattern will recur at beta/prod promote time on Piper unless 130000 + 140000 are the only seed migrations that run on shared envs (110000 + 120000 still need pre-marking via repair OR a different mechanism)

### 2. `pk ready` hard-fails on non-`feature/<ID>-*` branches

`pk ready 382` errored with "no feature branch found matching feature/382-*". The PR was on `feat/seed-pr-fixtures-skill` — a project-local methodology branch with no Linear ticket.

The fallback was `gh pr ready 382` which worked instantly. So `pk ready` adds friction without adding safety for methodology PRs.

**Proposed:**
- Accept `--pr=<#>` as an explicit override that skips the branch-name match
- OR detect the current branch's PR via `gh pr view --json number` and use that when the arg-pattern fails
- OR scope the strict pattern to a config setting in `method.config.md` so project-local PRs can opt out

### 3. Migration-repair via MCP is undocumented

The recovery in Gap #1 required this:

```sql
INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
VALUES
  ('20260527110000', 'seed_dual_user_dual_entity',     ARRAY['-- Marked applied via fix-forward. See 20260527130000_seed_dual_user_safe.sql for the safe-on-real-data replacement.']::text[]),
  ('20260527120000', 'seed_dual_user_auth_identities', ARRAY['-- Marked applied via fix-forward. See 20260527130000_seed_dual_user_safe.sql.']::text[])
ON CONFLICT (version) DO NOTHING;
```

This is the MCP equivalent of `supabase migration repair --status applied`. The CLI command requires a linked project + correct env auth; the MCP route is faster when you already have project_ref + are logged into the Supabase MCP.

**Proposed:**
- Document the MCP form in `pipekit-migrations.md` alongside the CLI form
- Include the fix-forward pointer comment as the canonical audit-trail pattern (instead of empty `statements` array)
- Cross-reference from `pipekit-security.md` § shared-state mutation rules

### 4. `mcp.apply_migration` causes silent timestamp drift between disk and remote

`mcp__supabase.apply_migration` is a legitimate tool for emergency hot-fixes on shared envs, but it has a footgun the rules don't currently warn about: **the function auto-stamps the recorded version with wall-clock time at apply-moment**, not with whatever timestamp the developer intended to use for the disk file.

Concrete failure observed today: a developer ran `mcp.apply_migration` against piper-dev with the WIT-514 reorder RPC. The MCP recorded it as version `20260527105344` (the wall-clock minute). Hours later, the developer committed the same RPC as a disk migration at `20260527090000` (an arbitrary "morning" timestamp). Result:

- piper-dev's `schema_migrations` has entry for `20260527105344`
- Disk has file at `20260527090000` (same name, different version)
- Supabase CLI treats them as two distinct migrations → "Remote migration versions not found in local migrations directory" → ALL subsequent `supabase db push` deploys fail
- Today this blocked PR #388 + PR #392 from deploying for ~5 hours; recovered via PR #393 (rename + backfill the disk file at the MCP-recorded version)

**Proposed Pipekit rule** (new subsection in `pipekit-migrations.md` § Manual Schema Changes on Remote Envs):

> **Never `mcp.apply_migration` for code you'll commit as a disk file.** The MCP path auto-stamps the version with wall-clock time, which will not match the disk timestamp you choose later. Use `supabase db push` against a branch DB for testing, or — if you must hot-fix a shared env — choose your disk-file timestamp FIRST, then call `mcp.apply_migration` with a `name` argument that includes that timestamp, OR follow up immediately with a `supabase migration repair` to align versions.
>
> Recovery pattern when drift has already occurred:
> 1. Query the remote: `SELECT version, statements FROM supabase_migrations.schema_migrations WHERE name = '<your-migration-name>'`
> 2. Diff the remote `statements` against your intended disk content (functional match, comments may differ)
> 3. If functionally identical: rename your disk file to the remote's version (legitimate rename window since disk hasn't been pushed). Land on the affected env as a fix-forward PR.
> 4. If different: write a new follow-up migration that brings the env to the intended state. Don't try to make the existing entry "correct" retroactively.

## State Locations

- Piper PR #379 — https://github.com/withpiper/piper/pull/379 (branch `feat/seed-qa-budget-content` @ `48f0d9e`)
- Pipekit v2.7.0-rc1 — `c36c080` on `origin/main`
- Piper session log — `Logs/Sessions/2026-05-26_1334.md` (untracked)
- WIT-419 session log — `Logs/Sessions/2026-05-26_0759.md` (Piper, merged)

## If Things Go Sideways

- **UAT shows wrong role view** → likely the entity_memberships UPDATE-on-conflict landed but role values are stale from the backfill. Inspect: `SELECT user_id, entity_id, role, is_default FROM public.entity_memberships;` against local. The migration's `DO UPDATE SET role = EXCLUDED.role` should overwrite — if it didn't, the WHERE clause filtered.
- **Login fails** → check `auth.users.encrypted_password` was actually set; the migration uses `crypt(password, gen_salt('bf'))` and won't error silently if `pgcrypto` isn't enabled in the schema. Verify: `SELECT extname FROM pg_extension WHERE extname = 'pgcrypto';`
- **Need to roll back the seed** → it's a migration. Frozen-file invariant applies. Write a counter-seed migration with later timestamp; do not edit `20260527110000_seed_dual_user_dual_entity.sql`.
