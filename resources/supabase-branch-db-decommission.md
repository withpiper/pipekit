# Supabase Branch-DB Decommission Runbook

**Purpose:** One-time migration from per-PR Supabase branch DBs → rs-vault-pattern (local Supabase + pgtap CI + integration DB at dev-merge). Read `sop/Git_and_Deployment.md` § Solo-dev exception first — this runbook assumes you've already made the decision and the decision rule applies to your project.

**Audience:** A Pipekit consuming project that currently runs the Vercel-Supabase branching integration and wants to switch off it. Written generically; replace `<project>` with your project slug throughout.

**Estimated time:** 2-3 hours for the decommission itself + one full PR cycle to validate.

**Reversibility:** Medium. The Vercel integration stays installed (you're toggling its branch-provisioning feature, not uninstalling it). Workflows can be restored from git. Re-enable trigger conditions documented in the SOP — re-enable when one fires.

---

## Step 0 — Prove low-cost reinstatement BEFORE you decommission

Asymmetric-cost trap: if reinstatement is finicky on your Vercel + Supabase plan combo, the decommission cost balloons. Verify first.

1. Open a throwaway feature branch (`git checkout -b throwaway/branch-db-reinstate-test`) with a trivial change (a comment edit in `README.md`).
2. Open a PR. Confirm the Vercel-Supabase integration provisions a branch DB and the preview-deploy URL is reachable. Note the branch DB id.
3. In Vercel project settings → Integrations → Supabase, toggle off "Create database branches automatically" (or your plan's equivalent).
4. Force a new commit on the throwaway PR. Confirm no new branch DB is provisioned; preview deploy now uses the configured Preview env's `NEXT_PUBLIC_SUPABASE_URL` (whatever you set; default is often blank → preview broken at this stage).
5. Re-enable the toggle. Force a new commit. Confirm a new branch DB is provisioned and preview is restored.
6. Close the throwaway PR + delete the branch.

**If step 5 fails or requires re-granting integration permissions / re-linking the Supabase project / multi-step re-auth:** reinstatement is not one-toggle. STOP. The decommission cost includes future re-onboarding, which changes the calculus. Update the SOP § Solo-dev exception subsection with your project-specific finding before proceeding.

**If step 5 succeeds cleanly:** proceed to Step 1.

---

## Step 1 — Snapshot current state

Document what you're about to remove so reinstatement (if needed) is a checklist, not an investigation:

1. `gh workflow list --all` → record the names + status of every workflow related to Supabase / Vercel / branch DBs.
2. `cat .github/workflows/vercel-supabase-sync.yml` → save a copy to `resources/snapshots/vercel-supabase-sync.yml.pre-decommission.bak` (kept in the repo for reinstatement reference).
3. `cat .github/workflows/vercel-supabase-sync-cleanup.yml` → same treatment.
4. Vercel project settings → screenshot or text-dump the Integrations → Supabase section, including which env vars the integration auto-provisions (typically `POSTGRES_URL`, `POSTGRES_PRISMA_URL`, `NEXT_PUBLIC_SUPABASE_URL`, etc. — names vary by integration version).
5. Record your current Preview env's `NEXT_PUBLIC_SUPABASE_URL` value (you'll be changing it in Step 4).

Commit the snapshot files: `chore: snapshot branch-DB workflow state pre-decommission`. Don't push yet — you'll bundle with the decommission commit later.

---

## Step 2 — Disable the Vercel-Supabase branch-provisioning toggle

In Vercel project settings → Integrations → Supabase → Configure:

- Toggle off "Create database branches automatically" (or equivalent label per your integration version)
- Save changes
- Verify by opening any new PR: no Supabase branch DB should be created

This is the one-line "stop the bleeding" step. From here forward, new PRs do not provision branch DBs.

**Existing open PRs are unaffected** — their existing branch DBs persist until the PR closes. Either close them or let the cleanup workflow handle them on close (Step 3 keeps cleanup functional for legacy PRs).

---

## Step 3 — Decide cleanup workflow disposition

Three options for `vercel-supabase-sync-cleanup.yml`:

| Option | When | Action |
|---|---|---|
| **Keep as-is** | If you have open PRs with pre-existing branch DBs | Leave the workflow active; it'll run on those PRs' close events. Re-evaluate after the last legacy PR merges. |
| **Comment out triggers, leave file** | Once all legacy PRs are closed | Edit `on:` block to `workflow_dispatch:` only — no automatic firing, file remains as reinstatement-template |
| **Delete** | After full validation cycle | `git rm .github/workflows/vercel-supabase-sync-cleanup.yml` — clean removal. Restore from `resources/snapshots/` if needed. |

Same decision tree for `vercel-supabase-sync.yml`.

**Recommend:** option 2 (comment out triggers, leave files). The file-as-template makes reinstatement a 5-line revert, not a from-scratch rewrite.

```diff
 on:
-  pull_request:
-    types: [opened, synchronize, reopened]
+  # Triggers disabled when branch DBs were decommissioned 2026-MM-DD.
+  # See resources/supabase-branch-db-decommission.md § Reinstatement.
+  workflow_dispatch:
```

---

## Step 4 — Repoint Preview env vars at the integration DB

Without branch DBs, preview deploys need a DB to point at. Options:

| Target | Pro | Con |
|---|---|---|
| **Integration DB** (`<project>-dev` per shared beta+prod pattern) | Always-on; preview reflects merged-to-dev state | Pre-merge PR previews see the pre-PR schema (the migration hasn't been applied yet — applies on dev-merge) |
| **Dedicated "preview" Supabase project** | Pre-merge isolation possible via manual `supabase db reset --linked` | Extra Supabase project to maintain; manual reset discipline |
| **Don't change** (preview env stays blank / broken) | Forces local-only validation discipline | Preview deploys become unusable as a review surface |

**Recommend:** integration DB. It's the rs-vault-pattern default and the friction (pre-merge preview sees pre-PR schema) is the exact thing pgtap CI + local validation already covers.

In Vercel project settings → Environment Variables → Preview environment, set:

- `NEXT_PUBLIC_SUPABASE_URL` → `<project>-dev` Supabase URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` → `<project>-dev` anon key
- `SUPABASE_SERVICE_ROLE_KEY` → `<project>-dev` service role (if you use it server-side in previews)
- Any other Supabase-derived var the branch integration was auto-provisioning (use the snapshot from Step 1.4)

**Critical:** confirm the integration DB's RLS policies don't grant test data accidentally — the Preview env is more publicly accessible than you might assume (anyone with a preview URL can hit it). If your integration DB has real-shape data, gate preview deploys behind Vercel password protection.

---

## Step 5 — Beef up local + CI as compensation

The local + CI gates that substitute for branch-DB preview validation:

### 5.1 — Local `supabase start` discipline

Document the expected local-dev loop in your project's `CLAUDE.md` or `README.md`:

```bash
supabase start             # boots local PG + Studio + Storage
supabase db reset          # applies all migrations from supabase/migrations/
supabase gen types typescript --local > apps/web/src/types/supabase.ts
pnpm test                  # vitest against local stack
```

The `supabase gen types` step is the one most easily forgotten. It catches the app-code-against-new-schema drift that branch-DB preview previously caught at build time. Consider a pre-commit hook (`lefthook`, `husky`, or `simple-git-hooks`) that runs `gen-types` on any commit touching `supabase/migrations/**`.

### 5.2 — pgtap CI

Confirm your project runs pgtap in CI on every PR:

```bash
gh workflow view supabase-ci.yml   # or whatever your CI workflow is called
```

The workflow should:

1. Spin up ephemeral PG (`docker run postgres:16` or use `supabase db start` in a runner with Docker available)
2. Apply migrations: `supabase migration up` against the ephemeral PG
3. Run pgtap suites: `supabase test db` or your equivalent
4. Fail PR if any pgtap assertion fails

If you don't have this, the rs-vault pattern from `sop/Git_and_Deployment.md` line 279 has the canonical workflow template (`db-pr-check.yml`). Adopt it before decommissioning, not after — pgtap is the compensatory gate.

### 5.3 — Post-dev-merge UAT checklist

Add a line to your PR template (`.github/PULL_REQUEST_TEMPLATE.md`):

```markdown
## Post-merge validation

- [ ] Confirmed preview-deploy URL serves updated schema on `<project>-dev` after dev-merge
- [ ] (Migration PRs) Verified `supabase-dev.yml` ran successfully and migrations applied to `<project>-dev`
```

This makes the "migration validates on integration DB post-merge" step a deliberate gate, not an implicit assumption.

---

## Step 6 — One-cycle proof

Pick a low-risk PR to validate the new flow end-to-end:

1. Branch a small migration-bearing change (add a non-load-bearing column, or update a CHECK constraint)
2. Local: `supabase db reset` + verify migration applies, types regenerate cleanly
3. Push + open PR → confirm no branch DB is provisioned (Vercel deploy log will say so explicitly)
4. PR-level CI: pgtap runs, all assertions pass
5. Preview deploy: builds (against integration DB schema, which lacks your migration), confirm UI still loads (since migration is additive)
6. Merge to dev → `supabase-dev.yml` fires → migration applies to integration DB
7. Re-open the preview URL: now serves updated schema. Confirm UI behavior matches expectations.
8. Promote dev → beta as usual (schema-first sequencing fires `supabase-production.yml` per the SOP)

If any step fails, you have the snapshot files from Step 1 to roll back: revert the workflow edits, re-toggle the Vercel integration, restore env vars from snapshot.

---

## Reinstatement (if a re-enable trigger fires later)

Triggers documented in `sop/Git_and_Deployment.md` § Solo-dev exception. When one fires:

1. Vercel project settings → Integrations → Supabase → toggle "Create database branches automatically" back on
2. Restore workflows: `git checkout main -- .github/workflows/vercel-supabase-sync.yml .github/workflows/vercel-supabase-sync-cleanup.yml` (or pull from `resources/snapshots/`)
3. Re-revert the `on:` block edits from Step 3 (uncomment `pull_request:` triggers)
4. Repoint Preview env vars: clear the integration-DB overrides from Step 4, letting the Vercel-Supabase integration's auto-provisioning take over again
5. Open a throwaway PR to validate provisioning works
6. Document in your project's `engineering/sop/` (or equivalent) why the re-enable trigger fired — future-you needs the context if the decision flips back

---

## What this runbook does NOT cover

- **Multiple-developer onboarding** that prompts reinstatement: see your onboarding doc
- **Migrating off Supabase entirely** to a different DB provider: out of scope
- **Pin to a Supabase project's schema-snapshot for compliance:** consider Supabase's PITR + read-replica features, not branch DBs
- **Production migration discipline:** still gated by `pipekit-migrations.md` regardless of branch-DB setup. Frozen-file invariant, hardening discipline, schema-first sequencing all unchanged.

---

## File checklist

After decommission:

- [ ] `.github/workflows/vercel-supabase-sync.yml` → triggers commented (or deleted)
- [ ] `.github/workflows/vercel-supabase-sync-cleanup.yml` → same
- [ ] `resources/snapshots/vercel-supabase-sync.yml.pre-decommission.bak` → snapshot committed
- [ ] `resources/snapshots/vercel-supabase-sync-cleanup.yml.pre-decommission.bak` → snapshot committed
- [ ] Vercel Preview env → `SUPABASE_*` vars point at integration DB
- [ ] `CLAUDE.md` / `README.md` → local dev loop documents `supabase gen types` step
- [ ] PR template → post-merge UAT checklist additions
- [ ] `engineering/sop/` (or equivalent) → project-specific note: "branch DBs decommissioned YYYY-MM-DD; re-enable triggers in pipekit/sop/Git_and_Deployment.md § Solo-dev exception"
- [ ] One-cycle proof completed: a migration PR has gone through the new flow successfully
