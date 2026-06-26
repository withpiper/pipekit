# Git & Deployment

> For the full development pipeline, see [method.md](../method.md).

**v2.6.0** — Last updated: 2026-05-23  *(two-phase `pk promote` + `pk ship` Draft default + `pk ready` flip command; `pk done` auto-pulls integration and writes planning SUMMARY)*
**Source of truth:** Your project's CLAUDE.md defines the authoritative branch strategy, release flow, and deployment mapping. This SOP provides the day-to-day procedures.

---

## Git Architecture

Your project's branching model is chosen during `/startup` and recorded in `method.config.md` under `## Git Architecture`. This choice determines environments, promotion skills, and release flow.

### Two-Tier (dev → main)

Best for solo dev, small teams, or projects where preview URLs replace a staging environment.

```
main (production)
dev  (active development)
  └── feature/*, fix/*   → Preview URLs
```

| Environment | Branch | Purpose |
|---|---|---|
| **Production** | `main` | Live |
| **Dev** | `dev` | Active development |
| **Preview** | PR branches | Per-PR preview URLs |

**Release flow:** `feature/*` → PR to `dev` → PR to `main`
**Promotion mechanism:** `pk ship` opens the feature → `dev` PR as Draft (v2.6.0+; Linear → `UAT`). `pk ready` flips it to Ready (fires outside reviewers). `pk done` after merge → `In Dev`. `pk promote main` (or `pk promote` with no arg, since only one hop exists) opens the `dev` → `main` PR; `pk promote main --finish` runs after merge.
**Linear transitions (v2.6.0+):** `pk ship` → `UAT` (PR open as Draft on preview); `pk done` → `In Dev` (merge confirmed; also auto-pulls integration + writes planning SUMMARY); `pk promote main --finish` → `Done` (after promote PR merges — two-phase, not optimistic).

### Three-Tier (dev → beta → main)

Best for teams with QA, projects needing a stable UAT environment, or regulated industries.

```
main (production)
beta (pre-release)
dev  (active development)
  └── feature/*, fix/*   → Preview URLs
```

| Environment | Branch | Purpose |
|---|---|---|
| **Production** | `main` | Live |
| **Beta** | `beta` | Pre-release, password-protected |
| **Dev** | `dev` | Active development |
| **Preview** | PR branches | Per-PR preview URLs |

**Release flow:** `feature/*` → PR to `dev` → PR to `beta` → PR to `main`
**Promotion mechanism:** `pk ship` opens the feature → `dev` PR as Draft (v2.6.0+). `pk ready` flips to Ready. `pk done` after merge → `In Dev`. `pk promote <env>` walks the chain two-phase per hop (`pk promote beta` opens; `pk promote beta --finish` after merge transitions; repeat for main) per `Ship environments` in `method.config.md`.
**Linear transitions (v2.6.0+):** `pk ship` → `UAT` (PR open as Draft on preview); `pk done` → `In Dev` (merge confirmed); `pk promote beta --finish` → `In Beta` (after merge); `pk promote main --finish` → `Done` (after final merge). Each `pk promote` is two-phase — WITs stay in source state until the `--finish` after the promote PR merges.

### Branch Naming (both models)

| Prefix | Base Branch | Purpose |
|--------|-------------|---------|
| `feature/` | `dev` | New functionality |
| `fix/` | `dev` | Bug fixes |
| `hotfix/` | `main` | Urgent production fixes |

### Branch Protection (both models)

| Branch | Rules |
|---|---|
| `main` | Protected. Requires PR, CI passing. No direct pushes. |
| `beta` (three-tier only) | Protected. Requires PR + CI passing. No direct merges. |
| `dev` | Default branch for PRs. CI runs on all PRs targeting dev. |

### Merge Strategy by Hop (v2.2.0+)

**Squash is disabled. Atomic commits flow feature → dev → main with stable SHAs.** Pipekit discipline already enforces one atomic change per commit, so the cleanup-via-squash use case doesn't apply. `git log main --first-parent` gives the squash-equivalent view (one entry per merged PR) without losing the underlying commits.

| Hop | Recommended | Also OK | Rationale |
|---|---|---|---|
| `feature/*` → `dev` | **Rebase** | Merge-commit | Rebase preserves atomic commits linearly; merge-commit preserves them under a feature bubble. Either keeps SHAs intact for downstream promotes. **Squash is disabled repo-wide.** |
| `dev` → `beta` (three-tier) | Merge-commit | — | One anchor commit per promote (`git log --first-parent`, `git revert -m 1`). |
| **`dev` → `main`** (two-tier) or `beta` → `main` (three-tier) | **Merge-commit (enforced)** | — | Same anchor rationale. **Enforced by ruleset, not user discipline.** |

#### Why no squash anywhere (v2.2.0 reversal)

v1.7.0 banned merge-commits everywhere. v1.8.0.6 reversed: rebase/merge for feature → dev, squash for dev → main. **Both schemes hit phantom conflicts in production** — Piper's `nebula-piper-migration-handoff.md` documents the v1.8.0.6 failure, and rs-vault hit the same trap.

The misdiagnosis: v1.7.0–v2.1.x believed "merge-commits on main cause phantom conflicts." Squash on main causes them — by collapsing N atomic dev commits into one orphan commit on main, the next promote's merge-base sees divergent histories touching the same files. Merge-commits prevent the divergence by keeping SHAs stable across the promote boundary.

#### Enforcement model (v2.2.0+)

- **Repo level:** rebase + merge-commit allowed; **squash disabled** (`allow_squash_merge=false`).
- **`pipekit-main-merge-only` ruleset:** enforces merge-commit-only on PRs targeting `main` (no rebase or squash).
- The legacy `pipekit-main-squash-only` ruleset is auto-deleted on re-run of `pipekit-configure-repo.sh`.

Result: GitHub UI's "Merge pull request" dropdown shows Rebase + Merge on feature → dev PRs, and only "Create a merge commit" on PRs targeting main. Mistakes impossible.

**One-shot configure** (idempotent — safe to re-run on any consuming repo):

```bash
bash scripts/pipekit-configure-repo.sh <org>/<repo>
```

This sets repo-level merge flags AND creates/updates the ruleset. The script lives in pipekit and gets synced into consuming projects via `sync-method.sh`.

---

## Release Flow

**Core principle: every step forward is a PR. No direct merges between long-lived branches.** (Exception: hotfix cherry-picks back to dev — and beta in three-tier — are direct pushes.)

**Two-tier flow:** `feature/*` → PR to `dev` → PR to `main`
**Three-tier flow:** `feature/*` → PR to `dev` → PR to `beta` → PR to `main`

Each project defines its own promotion skills. As of v2.6.0, state transitions fire **after merge**, not optimistically at PR-open — the v2.6.0 F2 fix eliminated the ~5-minute Linear-ahead-of-reality window. After `pk ship` (Draft) → `pk ready` (Ready, fires outside reviewers) and after each `pk promote --finish`, issues transition in Linear:
- `pk ship` (opens Draft) → issues move to **UAT** (PR open on preview branch)
- `pk done` (after merge) → issues move to **In `<FirstEnv>`** (e.g. `In Dev`)
- `pk promote beta --finish` (three-tier, after promote PR merges) → issues move to **In Beta**
- `pk promote main --finish` (final hop, either tier; after promote PR merges) → issues move to **Done**

**v2.5.0+ UAT gate** (still applies): `pk promote <env>` (Phase 1) refuses with `exit 1` when any bundled issue is still in `UAT` (feature PR not yet merged). Pass `--confirmed` after env-UAT is signed off (Linear comment, PR comment, or session-log note recording the accept verdict) to bypass. `pk done` no longer refuses on UAT (it IS the transition out of UAT) — its safety check is the PR-merged verification. The discipline rule remains: "don't advance past UAT without sign-off"; code-level enforcement lives in `pk promote --confirmed`.

**Hotfix flow:** `hotfix/*` → PR to `main` → cherry-pick back to `dev` and `beta`

**Bug found in beta:** Fix on `fix/*` from `dev`, PR to `dev`, re-promote `dev` → `beta`. Do not fix directly on `beta`.

---

## Worktrees

All feature/fix/hotfix work uses git worktrees, not branch switching in the main repo. The worktree prefix is defined in `method.config.md`.

```
~/Projects/
├── {project}/                          <- Main repo (stays on dev or main)
├── {project}-feature-ai-budget/        <- Worktree for feature work
├── {project}-fix-auth-redirect/        <- Worktree for a bug fix
└── {project}-hotfix-typo/              <- Worktree for a hotfix
```

All worktrees share the same git history, remotes, and object store — they're lightweight, not full clones.

### Creating a Worktree

Use `pk branch <ID>` (Linear-issue-based). The worktree + branch + Linear → In Progress transition all happen idempotently.

```bash
pk branch RS-42        # creates feature/RS-42-<3-word-slug>, worktree at .worktrees/RS-42-<slug>
```

The branch name and slug are derived from the Linear issue title; you don't pick them. For non-Linear work (hotfixes, scratch experiments), use plain `git worktree add` — see Hotfix Procedure below.

### Managing Worktrees

```bash
git worktree list                             # List active worktrees
pk done <ID>                                  # After PR merge — cleans up worktree+branch, posts to Linear
```

### Rules

- Each branch can only be checked out in **one** worktree at a time
- Main worktree stays on `dev` or `main`, not feature branches
- Run dependency install in each new worktree (`pk branch` symlinks `.env` / `.env.local` / `.mcp.json`)
- Use `pk done <ID>` to clean up after merge — it handles worktree removal + Linear transition in one step

---

## Workflow: Feature Development to Production

### Step 1: Branch from Linear

```bash
pk next                # surfaces the next Approved issue (initiative-aware)
pk branch <ID>         # worktree + branch + Linear → In Progress
cd .worktrees/<ID>-<slug>
claude --dangerously-skip-permissions
```

### Step 2: Plan + Execute

```
/work <ID>             # plan-verdict gate, then execute on native-on-Workflow
```

### Step 3: Verify

```
/verify                # runs § Pre-Deploy Gate from method.config.md; QA subagent if Require QA review=true
```

### Step 4: Open PR to Dev (with optional review)

```
pk ship                # push, open PR as DRAFT (v2.6.0+) against integration branch from config, Linear → UAT
pk ship --review       # additionally posts review-in-flight to Linear and prints reviewer invocation
pk ship --ready        # open Ready immediately (v2.6.0+; one-shot tiny WITs)
```

The Draft default means outside reviewers (Semgrep + claude-review per `templates/ci/`) do not fire while you iterate. When ready to merge:

```
pk ready [<ID>]        # flip Draft → Ready; fires ready_for_review → outside reviewers run (v2.6.0+)
```

For migrations / RLS / SECURITY DEFINER / auth, use `/pr-security-review` instead of (or alongside) the generic reviewer. After review findings, `/pr-fix` triages (v2.6.0+: `--from-review` ingests the GHA review; `--second-opinion=gemini` adds a parallel Gemini read).

### Step 5: Merge to Dev

PR is reviewed, approved, and merged (rebase or merge-commit per § Merge Strategy by Hop). Feature available on dev. Vercel preview is automatic; for Supabase projects, GitHub Actions `db-pr-check.yml` validates migrations on PR open and `db-migrate.yml` applies them on `main` merge.

```
pk done <ID> [--merge] # verify merge, cleanup worktree+branch, post commits to Linear,
                       # transition UAT → In <FirstEnv>, auto-pull integration (v2.6.0+),
                       # write planning SUMMARY + flip PLAN status (v2.6.0+; skipped if no planning layer)
```

### Step 6: Promote to Production (two-phase as of v2.6.0)

```
# Phase 1 — open the promote PR (WITs stay in source state):
# Two-tier:   pk promote main
# Three-tier: pk promote beta

# ── human merges the promote PR in GitHub UI ──

# Phase 2 — transition Linear states after merge:
# Two-tier:   pk promote main --finish
# Three-tier: pk promote beta --finish    (then pk promote main + --finish after that PR merges)
```

`pk promote <env>` (Phase 1) walks one hop along `Ship environments` per invocation and embeds a bundled-WIT tracker in the PR body. Phase 2 (`--finish`) parses the marker, transitions matching issues → **`In <Env>`** for intermediate hops (e.g. `In Beta`), → **Done** for the final hop. The two-phase model (v2.6.0+) replaces the optimistic-at-PR-open behavior — fixes the F2 ~5min Linear-ahead-of-reality window.

See **Batch vs Per-Issue Promotion** below for when to ship one issue at a time vs. accumulate several before promoting.

### Batch vs Per-Issue Promotion

`pk ship` and `pk promote` support both patterns: ship one issue at a time, or let several land on dev before promoting. The default for feature-heavy phases is **batch**; the default for hotfixes is **per-issue**. Choose deliberately — different work has different risk profiles.

#### When to per-issue (ship now)

- **Hotfix** — security, data corruption, payment, auth issue. Always per-issue, always immediate.
- **Migration with high blast radius** — e.g., a column rename or table drop. Ship alone so the rollback story is clear.
- **First production release of a system** — early users, want fast feedback loop.
- **Inter-issue conflicts** — your in-flight RS-X depends on RS-Y's runtime behavior; batch would couple the test surface.
- **Pre-deploy gate flagging warnings** — if CI is yellow for any reason on the issue you're promoting, ship it alone so you can isolate what's causing the noise.

#### When to batch

- **Feature-heavy phases** — accumulating 2-5 related issues lets reviewers see the cohesive change.
- **Schema migrations that compose** — e.g., RS-7 (profiles) + RS-8 (audit_log refs profiles) + RS-13 (RLS uses both). One main PR with all three is easier to verify than three serial chains.
- **Doc + test + feature triplets** — when the doc update, the test addition, and the feature implementation belong together conceptually.
- **Designer-reviewed UI changes** — batch lets the designer review one preview URL with all the changes, not three.

#### Recommended batch size

- **Small (2-3 issues)** — default for most work. Easy to review, contained blast radius.
- **Medium (4-5 issues)** — when issues are tightly related (same component, same migration set).
- **Large (6+ issues)** — discouraged. Hard to review, hard to roll back. If you find yourself with 6 unmerged issues on dev, ship two batches instead.

If issue count grows past 5, that's a signal — either batch sooner, or ship the most-decoupled issue per-issue to break the queue.

#### When to cut the batch

Concrete triggers that say "stop accumulating, promote now":

- **Hit the size limit** — 3-5 issues on dev that are all UAT-passed
- **One week elapsed** since the last main promotion — accumulated changes get harder to review the longer they sit
- **A new high-priority issue lands** in the queue that can't wait for the current batch
- **Pre-deploy gate flips yellow** on dev — investigate before adding more
- **Risk-bearing issue ready to promote** — migration, security, dependency upgrade. Ship the batch with the risky issue cleanly bracketed; don't pile more work on top.

If none of these have triggered, keep accumulating.

#### DB migration timing during accumulation

The migration application moment depends on your project's Supabase setup. v2's canonical pattern is the rs-vault GitHub Actions pair (`db-pr-check.yml` + `db-migrate.yml`), which decouples migration apply from the promotion skill entirely:

| Setup | Migrations validate at | Migrations apply at | Test on dev preview? | Beta uses isolated DB? |
|-------|------------------------|---------------------|----------------------|------------------------|
| **GitHub Actions (rs-vault pattern, recommended)** | PR open → ephemeral postgres reset (`db-pr-check.yml`) | `main` merge → `db-migrate.yml` runs `supabase db push` | No — schema applies at main merge; dev preview validates against ephemeral postgres | n/a (two-tier) |
| **Separate per-env DBs** | Per-environment GitHub Actions or manual `supabase db push --project-ref <env-ref>` post-merge | Per environment | Yes — each env has its own DB, no shared mutation | Yes |
| **Shared beta+prod DB** (piper pattern) | Per-environment Actions for dev (`piper-dev`); shared workflow for beta+prod (`piper-prod`) | dev env on dev merge; prod env on `main` merge | Yes for dev (own DB); No for beta (reads from prod schema) | **No** — see § Shared beta+prod DB sequencing below |
| **Supabase branching** (per-PR ephemeral DBs) | PR open → Vercel-Supabase integration spins up a branch DB | Per branch DB | Yes — each PR has its own DB branch | n/a (per-PR DBs) |
| **Single shared DB** (no dev/prod split) | Manual or via single GitHub Action on main merge | Main merge only | No — schema doesn't exist on dev preview until main lands | n/a (single DB) |

Read your project's `.github/workflows/` to determine which mode you're in. Lift the rs-vault workflow pair (`db-migrate.yml` + `db-pr-check.yml`) if you don't have migration CI yet — it requires `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF` GitHub secrets and decouples the migration concern from `pk ship` entirely. Pair migration PRs with `/pr-security-review`.

#### Shared beta+prod DB: schema-before-code sequencing

If your project uses the **Shared beta+prod DB** pattern (beta reads from the same Supabase project as prod), the natural sequencing question is: when does the migration apply to the shared DB?

Two options, with different trade-offs:

| Sequence | When `supabase-production.yml` (or equivalent) fires | What lives between merge and apply |
|----------|------------------------------------------------------|--------------------------------------|
| **(a) Code-first** (`main`-merge trigger, default in many starter configs) | After the `beta → main` PR merges | A window where beta runs new code against the old prod schema. Audit-emission / new-function-call paths break on beta until the migration lands. Window length = time between beta merge and main merge + workflow runtime. |
| **(b) Schema-first** (`beta`-merge trigger, **recommended for shared beta+prod**) | After the `dev → beta` PR merges | No window. By the time beta serves new code, the shared DB schema already supports it. Trade-off: prod schema mutates one cycle earlier than code; less rollback flexibility if you decide to abort a beta→main release. |

**Recommendation: schema-first (b)** for shared beta+prod DB setups. The "rollback flexibility" lost in (b) is rarely exercised in practice (most teams forward-fix rather than rollback migrations), while the broken-beta window in (a) is a daily-hazard friction that compounds with every release. The friction is acute when the offending change is a function-signature widening (e.g. adding DEFAULTs that the new code starts omitting params for) — old code on beta breaks the moment new code lands until the next promote closes the loop.

**Implementation**: change the trigger in `supabase-production.yml` (or your project's equivalent) from `push to main` → `push to beta`. One-line YAML change:

```diff
 on:
   push:
-    branches: [main]
+    branches: [beta]
     paths: ['supabase/migrations/**']
```

After the change: document in the project's `engineering/sop/` (or equivalent) that "beta merge = schema cutover, main merge = code cutover."

**Discipline pair**: backward-compatible migrations. Even with schema-first, every migration should still work with the previous code. Example: adding a function DEFAULT is safe because old code still passes all params; renaming a column is NOT safe because old code on prod between the migration and the next deploy would break. Reserve destructive migrations (`DROP`, `RENAME`, type-narrowing CHECK constraints) for explicit zero-downtime patterns (dual-write, dual-read, etc.).

**Fast-cycle recovery** when you discover you're in (a) and need to close the window: run the dev → beta → main promote pair back-to-back. The beta → main merge triggers the prod migration; keep the window under a few minutes by having both PRs ready before starting.

#### Solo-dev exception: making Supabase branch DBs not-ceremony

Per-PR Supabase branch DBs (the "Supabase branching" row in the Setup table above) are designed to isolate concurrent feature branches running mutually-exclusive migrations. The model assumes ≥ 2 developers landing schema changes against the same Supabase project in parallel.

For a solo dev, the parallel-developer assumption never binds. But that doesn't automatically mean branch DBs are wrong — it means their value depends on whether **the branch DB is testable on arrival**. An empty branch DB (no test user, no fixture data, no known credentials) IS ceremony. A branch DB that comes up with a known test user + representative fixtures + the pending migration applied IS exactly the per-PR preview-validation surface the integration was sold on delivering.

Two paths to make branch DBs not-ceremony. **Try Path A first.** Path B is the fallback if Path A is intractable on your stack.

##### Path A — Seed branch DBs properly (recommended)

`supabase/seed.sql` is Supabase's canonical seeding hook. It runs **automatically** after migrations during `supabase db reset` (local) AND during Supabase branch DB initialization (cloud). When configured with a known test user (bcrypt'd password), representative org / entity scaffolding, and minimal sample data, every branch DB lands provisioned-and-usable in the same ~30s the integration takes anyway.

Why this is preferable to Path B:

- **You keep all the branch-DB value** — pre-merge preview validation with pending migration applied, schema isolation, `supabase gen types` at preview-build time
- **The fix is one file (`supabase/seed.sql`)** plus ongoing maintenance discipline — no workflow surgery
- **Reversible at zero cost** — `git rm supabase/seed.sql` and you're back to empty-branch state
- **Works the same locally and in the cloud** — single seeding pattern, two contexts

The trade-off Path A asks you to absorb:

- **Seed maintenance** as schemas evolve — every column rename, new required field, or RLS predicate change can break the seed. Mitigation: write the seed in terms of the canonical helper functions / RPCs your app uses (e.g., `SELECT create_organization(...)` not `INSERT INTO organizations`), not raw INSERTs. Schema changes propagate through one chokepoint.
- **Test passwords in the repo** — `testpass123` in `seed.sql` is fine in non-prod, but Vercel preview URLs are publicly accessible by default. Either enable Vercel password-protection on the Preview env, or rely on RLS to make the test user's reach inherently bounded (and verify that periodically).
- **`auth.users` column drift across Supabase CLI versions** — the exact required columns / triggers have shifted. Verify the seed pattern against the **installed** Supabase CLI version per `pipekit-tooling.md` § Source Authority Hierarchy + § Enumerate the Surface Before Claiming Behavior. Don't copy a 2-year-old StackOverflow snippet.

**The load-bearing pre-flight check:** confirm `seed.sql` auto-runs on a Supabase branch DB BEFORE investing in the seed design. Open a throwaway PR with a sentinel insert in `seed.sql` (e.g., `INSERT INTO public.config_health_check (key, value) VALUES ('seed_ran', now())`); check whether that row exists in the branch DB after provisioning. If yes, you have the hook you need. If no, your Vercel-Supabase integration version / plan doesn't run seed automatically — Path A requires a CI workflow to bridge the gap, or you fall back to Path B.

Full walkthrough: `resources/supabase-branch-db-seed-strategy.md`.

##### Path B — Decommission branch DBs (fallback)

When to fall back here:

1. Path A's Step 0 fails (seed doesn't auto-run on branch DB and a CI bridge is more work than decommissioning)
2. Seed maintenance proves prohibitively expensive (e.g., schema churn outpaces seed updates and the seed is always stale)
3. The Vercel-Supabase integration's per-branch DB cost on your plan is meaningful and the value isn't justifying it

Substitution model: rs-vault pattern (recommended setup row in the table above) covers schema-invariant testing via pgtap CI + local `supabase start`. You lose pre-merge "click around the preview deploy with new schema" but gain it back at the dev-merge step, when the migration applies to the integration DB and the preview-deploy URL points at it.

**Decision rule for Path B:** drop branch DBs when **all three** hold:

1. Solo dev or two-dev where the second dev's work is non-overlapping by domain
2. Local Supabase + pgtap CI cover schema-invariant testing
3. `supabase gen types` runs in the local pre-commit loop (or you're disciplined about running it manually before `pk ship`)

**Re-enable triggers (any 1 fires → re-evaluate Path A first, then Path B if Path A still won't work):**

- Adding a second developer with concurrent migration work (the original parallel-dev assumption returns)
- A migration class you cannot validate via pgtap alone — complex backfill timing, multi-table data migration with intermediate states, or migration correctness depends on app-code-against-new-schema interaction not covered by integration tests
- The integration DB (`<project>-dev`) becomes load-bearing for external integration — e.g., a partner integration tests against it and can't tolerate schema-state changes mid-test
- Compliance / audit requires per-change schema-state isolation

**Asymmetric reinstatement cost:** decommissioning is fast (Vercel toggle + workflow removal). Reinstatement requires re-verifying the Vercel-Supabase integration's permissions, re-testing sync workflows on a fresh PR, and possibly re-granting Supabase project access. Before you decommission, verify reinstatement is one-toggle by flipping the integration off and immediately back on against a throwaway test PR. If that round-trip is clean, you've proven low-cost reinstatement. If reinstatement is finicky on your specific Vercel + Supabase plan configuration, Path A's tradeoff calculus shifts further in Path A's favor.

Full walkthrough: `resources/supabase-branch-db-decommission.md`.

#### Three-tier specifics (dev → beta → main)

In three-tier projects, batch decisions happen at two boundaries:

| Boundary | Default | Trigger to deviate |
|----------|---------|--------------------|
| `dev` → `beta` | Batch — accumulate until UAT-ready | Hotfix, single high-risk issue, beta release cut for marketing/PR reasons |
| `beta` → `main` | Wait for beta UAT to pass on the whole batch | Per-issue if any beta-UAT failure isolates to one issue (cherry-pick the rest) |

Beta is the UAT environment in three-tier. Don't promote partial beta — if RS-13 passes UAT but RS-14 doesn't, hold the batch and either fix RS-14 in place or cherry-pick RS-13 to a new branch off beta and re-promote.

#### Pre-deploy gate at each promotion

Run the pre-deploy gate **before** each promotion hop, not just before the first one. `/verify` (or `pk verify`) is the canonical entry point and reads § Pre-Deploy Gate from `method.config.md`:

- Before `pk ship` (feature → dev): gate must pass on the feature branch (handled inline by `/verify`)
- Before `pk promote beta` (three-tier, dev → beta): gate must pass on dev tip
- Before `pk promote main` (two-tier dev → main, or three-tier beta → main): gate must pass on the source branch

The gate at each boundary catches integration-level regressions that wouldn't show on the originating feature branch. CI also enforces the gate at PR open — don't skip "because it passed earlier."

#### Rollback per tier

If a promotion turns out to be wrong:

- **Dev rollback** — revert the merge commit on dev. Cheap. Re-promote the working subset.
- **Beta rollback** (three-tier) — revert beta's merge from dev, then cherry-pick the working issues forward. Document what was rolled back in the Linear issue's comments.
- **Main rollback** — revert main's merge, run `supabase db push` if a migration was rolled back (sometimes requires manual `DROP` for additive-only migrations), notify any external users. Treat as an incident.

Database migrations are typically forward-only — the rollback for a destructive migration is a forward migration that re-creates the dropped state. Plan migrations with rollback in mind (avoid `DROP COLUMN` until you're sure no readers depend on the column; prefer `ADD COLUMN` + transitional dual-read period).

### Verification

After any promotion, verify the deployment (smoke tests, health check).

---

## Hotfix Procedure

Hotfixes don't fit `pk branch <ID>` (which is Linear-issue-based and targets `dev`); they branch from `main` and merge back to `main`. Use plain git:

```bash
# 1. Create hotfix worktree off main
git worktree add ../<project>-hotfix-<slug> -b hotfix/<slug> main
cd ../<project>-hotfix-<slug>

# 2. Fix, commit, push
git push -u origin hotfix/<slug>
gh pr create --base main --title "hotfix(<scope>): <desc>" --body "..."

# 3. After merge, cherry-pick back to long-lived branches
# Two-tier:
git checkout dev && git pull && git cherry-pick <hash> && git push origin dev

# Three-tier (see § When the explicit beta cherry-pick is needed below):
git checkout dev && git pull && git cherry-pick <hash> && git push origin dev
git checkout beta && git pull && git cherry-pick <hash> && git push origin beta

# 4. Clean up
cd ../<project>
git worktree remove ../<project>-hotfix-<slug>
```

If the hotfix corresponds to a Linear issue, post the merge commit back to that issue manually — `pk done` is for `pk branch`-created branches.

### When the explicit beta cherry-pick is needed (three-tier)

The standard three-tier flow files three branches: `hotfix/*-main`, `*-cherrypick-dev`, and `*-cherrypick-beta`. But if a `dev → beta` promote is imminent within one cycle of the hotfix landing on dev, the explicit beta cherry-pick is **redundant** — the dev cherry-pick will sweep onto beta automatically via the next `pk promote beta`.

**File the explicit beta cherry-pick only when:**

- Production is bleeding from the bug and beta needs the fix **before** the next scheduled `dev → beta` promote.
- The next `dev → beta` promote is unscheduled or blocked (feature freeze, awaiting unrelated UAT, marketing hold).

**Otherwise:** skip the beta cherry-pick branch. The dev cherry-pick will land on beta naturally on the next promote. Filing it anyway produces an orphan branch that needs manual cleanup (anchor: WIT-455, 2026-05-13 — `hotfix/margin-cherrypick-beta` orphaned because the dev cherry-pick swept to beta via PR #268 the same day).

If you're unsure, ask: "Will the next `dev → beta` promote happen within ~24h of this hotfix landing on dev?" If yes, skip beta cherry-pick. If no or unknown, file it.

---

## Commit Messages

```
{type}({scope}): {description}
```

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `style` | CSS/visual changes |
| `refactor` | Code restructuring |
| `perf` | Performance improvement |
| `chore` | Maintenance, config |
| `docs` | Documentation |
| `test` | Tests |

Include issue IDs in commit messages: `feat(grid): add column definitions ({PREFIX}-42)`

---

## Rollback

### App Rollback

Use your hosting platform's rollback feature (e.g., `vercel rollback [deployment-url]`).

### Database Rollback

Migrations are forward-only. To undo: create a new migration that reverses the changes and deploy through the normal flow.

---

## Golden Rules

1. **Every step forward is a PR.** No direct merges between long-lived branches.
2. **Main is always deployable.** Only merge tested, validated code.
3. **All PRs target dev** (except hotfixes, which target main).
4. **Use `pk ship` and `pk promote`.** They automate pre-deploy gates and Linear transitions; route everything through them so Linear stays in sync.
5. **Test on preview before opening a PR.**
6. **Commit often, push when stable.** Small commits are easier to debug.
7. **Never force push to main.** Use `--force-with-lease` on feature branches only.
8. **Write meaningful commit messages.** Follow the type(scope) format.
9. **Cherry-pick hotfixes back immediately.** To dev (and beta if three-tier), verified clean.
