# Git & Deployment

> For the full development pipeline, see [method.md](../method.md).

**Last updated:** 2026-04-08
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
**Promotion skills:** `/g-promote-dev`, `/g-promote-main`
**Linear transitions:** merge to `main` → issues move to Done

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
**Promotion skills:** `/g-promote-dev`, `/g-promote-beta`, `/g-promote-main`
**Linear transitions:** merge to `beta` → issues move to UAT; merge to `main` → issues move to Done

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

### Merge Strategy by Hop (v1.8.0.6+)

Different hops want different strategies. The phantom-conflict trap (observed during v1.7.0 / v1.8.0 work) only happens when the **dev → main** hop uses a merge commit. Other hops can use whatever fits the project's history-readability preferences.

| Hop | Recommended | Also OK | Rationale |
|---|---|---|---|
| `feature/*` → `dev` | **Rebase** | Merge-commit | Rebase = linear atomic commits; merge-commit = bubble preserving feature scope. Either works on dev (no phantom-conflict risk; bubbles get absorbed when dev → main squashes). |
| `dev` → `beta` (three-tier) | Rebase or merge-commit | — | Same as feature → dev. |
| **`dev` → `main`** (two-tier) or `beta` → `main` (three-tier) | **Squash (enforced)** | — | One release commit per promotion. Merge-commits here cause phantom conflicts on subsequent promotes. **Enforced by ruleset, not user discipline.** |

#### Enforcement model (v1.8.0.6+): Rulesets, not repo flags

Earlier (v1.7.0–v1.8.0.5) Pipekit recommended disallowing merge-commits at the repo level (`allow_merge_commit=false`). That's machine-safe but blunt — it bans merge bubbles on dev too, which some users prefer for feature-branch readability.

v1.8.0.6 switches to **per-branch enforcement via GitHub Rulesets**:

- Repo level: all three merge methods enabled (rebase, squash, merge-commit).
- A `pipekit-main-squash-only` ruleset enforces squash-only on `main` specifically.
- Other branches (dev, beta, feature/*) inherit the repo-level flexibility.

Result: GitHub UI's "Merge pull request" dropdown shows all options on feature → dev PRs but only "Squash and merge" on PRs targeting main. Mistakes impossible.

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

Each project defines its own promotion skills. After merge, issues transition in Linear:
- Merge to beta → issues move to **UAT**
- Merge to main → issues move to **Done**

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

Use the `/branch` skill for the full workflow (creates worktree + branch + optional Linear link):

```
/branch feature-name
/branch --fix bug-name
/branch --hotfix urgent-fix
```

### Managing Worktrees

```bash
git worktree list                             # List active worktrees
git worktree remove ../project-feature-name   # Remove after merge
```

### Rules

- Each branch can only be checked out in **one** worktree at a time
- Main worktree stays on `dev` or `main`, not feature branches
- Run dependency install in each new worktree
- Clean up worktrees after branches are merged

---

## Workflow: Feature Development to Production

### Step 1: Create Feature Branch

```
/branch feature-name
```

### Step 2: Develop

Write code on the feature branch. Include database migrations if needed.

### Step 3: Test on Preview

Push branch to get a preview URL. Every push updates the preview automatically.

### Step 4: Open PR to Dev

Run pre-deploy gate, then create PR:
```
/g-promote-dev   (or your project's equivalent)
```

### Step 5: Merge to Dev

PR is reviewed, approved, and merged. Feature available on dev.

Clean up: `/branch finish` from within the worktree.

### Step 6: Promote to Production

**Two-tier:** PR from `dev` → `main`. After merge, referenced Linear issues move to **Done**.

**Three-tier:** PR from `dev` → `beta` (issues → UAT), then PR from `beta` → `main` (issues → Done).

See **Batch vs Per-Issue Promotion** below for when to ship one issue at a time vs. accumulate several before promoting.

### Batch vs Per-Issue Promotion

`/launch --close` and the `/g-promote-*` skills support both patterns. The default for feature-heavy phases is **batch**; the default for hotfixes is **per-issue**. Choose deliberately — different work has different risk profiles.

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

The migration application moment depends on your project's Supabase setup:

| Setup | Migrations apply at | Test on dev preview? |
|-------|---------------------|----------------------|
| **Single shared DB** (no dev/prod split) | `/g-promote-main` only — main is the only path that runs `supabase db push` | No — schema doesn't exist on dev preview until main lands |
| **Single shared DB + `supabase db push` in `/g-promote-dev`** | At each `/g-promote-dev` (forward-mutates shared DB) | Yes — dev preview tests against migrated schema |
| **Separate dev + prod DBs** (piper pattern) | Each `/g-promote-{dev,beta,main}` runs `supabase db push --project-ref <env-ref>` | Yes — each env has its own DB, no shared mutation |
| **Supabase branching** (per-PR ephemeral DBs) | At PR open via Vercel-Supabase integration | Yes — each PR has its own DB branch |

Read your project's `/g-promote-*` skills to determine which mode you're in. If a project's `/g-promote-dev` doesn't reference `supabase db push` and there's only one Supabase project, you're in **mode 1** — migration-bearing issues block batch promotion to dev (the migration won't apply until main).

When mode 1 is the friction, the fix is project-specific: either add `supabase db push` to `/g-promote-dev` (forward-mutation accepted in pre-ship projects), or stand up separate dev/prod Supabase projects (mode 3).

#### Three-tier specifics (dev → beta → main)

In three-tier projects, batch decisions happen at two boundaries:

| Boundary | Default | Trigger to deviate |
|----------|---------|--------------------|
| `dev` → `beta` | Batch — accumulate until UAT-ready | Hotfix, single high-risk issue, beta release cut for marketing/PR reasons |
| `beta` → `main` | Wait for beta UAT to pass on the whole batch | Per-issue if any beta-UAT failure isolates to one issue (cherry-pick the rest) |

Beta is the UAT environment in three-tier. Don't promote partial beta — if RS-13 passes UAT but RS-14 doesn't, hold the batch and either fix RS-14 in place or cherry-pick RS-13 to a new branch off beta and re-promote.

#### Pre-deploy gate at each promotion

Run the pre-deploy gate **before** each `/g-promote-*` step, not just before the first one:

- Before `/g-promote-dev`: gate must pass on the feature branch
- Before `/g-promote-beta` (three-tier): gate must pass on dev
- Before `/g-promote-main`: gate must pass on dev (two-tier) or beta (three-tier)

The gate at each boundary catches integration-level regressions that wouldn't show on the originating feature branch. Don't skip "because it passed earlier."

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

```bash
# 1. Create hotfix
/branch --hotfix describe-the-fix

# 2. Fix, commit, push, PR to main

# 3. After merge, cherry-pick back immediately
# Two-tier:
git checkout dev && git pull && git cherry-pick <hash> && git push origin dev

# Three-tier (also cherry-pick to beta):
git checkout dev && git pull && git cherry-pick <hash> && git push origin dev
git checkout beta && git pull && git cherry-pick <hash> && git push origin beta

# 4. Clean up
/branch finish
```

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
4. **Use the promotion skills.** They automate pre-deploy gates and Linear transitions.
5. **Test on preview before opening a PR.**
6. **Commit often, push when stable.** Small commits are easier to debug.
7. **Never force push to main.** Use `--force-with-lease` on feature branches only.
8. **Write meaningful commit messages.** Follow the type(scope) format.
9. **Cherry-pick hotfixes back immediately.** To dev (and beta if three-tier), verified clean.
