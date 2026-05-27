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

- **`fix(db):` hook false-positive** in Piper — commits with valid `{type}({scope}): {desc}` format keep getting flagged. Non-blocking (commits push regardless), but worth a separate bug. Suspect heredoc body content tripping it. Same pattern across PRs #380, #381, #379.
- **Port 54322 collision** — WIT-419 worktree's Supabase still running. Run `supabase stop --project-id piper-WIT-419-tax-code-tax` from inside that worktree before next worktree boot.
- **`agent isolation: "worktree"` is still a no-op on this harness** — orchestrators must `git worktree add` explicitly + pass `cwd:`. See `[[agent_isolation_worktree_broken]]`.

## State Locations

- Piper PR #379 — https://github.com/withpiper/piper/pull/379 (branch `feat/seed-qa-budget-content` @ `48f0d9e`)
- Pipekit v2.7.0-rc1 — `c36c080` on `origin/main`
- Piper session log — `Logs/Sessions/2026-05-26_1334.md` (untracked)
- WIT-419 session log — `Logs/Sessions/2026-05-26_0759.md` (Piper, merged)

## If Things Go Sideways

- **UAT shows wrong role view** → likely the entity_memberships UPDATE-on-conflict landed but role values are stale from the backfill. Inspect: `SELECT user_id, entity_id, role, is_default FROM public.entity_memberships;` against local. The migration's `DO UPDATE SET role = EXCLUDED.role` should overwrite — if it didn't, the WHERE clause filtered.
- **Login fails** → check `auth.users.encrypted_password` was actually set; the migration uses `crypt(password, gen_salt('bf'))` and won't error silently if `pgcrypto` isn't enabled in the schema. Verify: `SELECT extname FROM pg_extension WHERE extname = 'pgcrypto';`
- **Need to roll back the seed** → it's a migration. Frozen-file invariant applies. Write a counter-seed migration with later timestamp; do not edit `20260527110000_seed_dual_user_dual_entity.sql`.
