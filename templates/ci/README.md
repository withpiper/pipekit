# Pipekit CI Templates

GitHub Actions workflow templates for the **Path 3 reviewer model** shipped in v2.6.0.

## What's in here

| File | Reviewer | Type | Credit cost |
|------|----------|------|-------------|
| `semgrep.yml` | Semgrep | Deterministic static analysis | Free (Community Rules) |
| `claude-review.yml` | Claude Code Action | Semantic, LLM-based | Per-call, OAuth-token-gated |

Together they implement Pipekit's outside-reviewer model: Semgrep catches the classes it's specifically tuned for (injection, XSS, hardcoded secrets, dependency risks, OWASP top ten), Claude catches the semantic / cross-file pattern issues Semgrep can't see.

A third template does something different — state automation, not review:

| File | Purpose | Type |
|------|---------|------|
| `linear-transition.yml` | Advance a merged WIT's Linear state automatically | Merge-event automation |

See [Merge-driven Linear transition](#merge-driven-linear-transition-linear-transitionyml) below.

A fourth guards the migration chain (gap #1 Tier 3, v4.18.0):

| File | Purpose | Type |
|------|---------|------|
| `migration-drift.yml` | Fail a PR whose new migration collides with the base branch's migration tail (or duplicates a version) | Deterministic, git-only, credential-free |

It runs `scripts/check-migration-drift.sh` (synced by `sync-method.sh`) with the PR base as the baseline — catching the parallel-branch timestamp collision (Piper WIT-550) at the merge moment, the only point where both branches' trees are comparable. Copy to `.github/workflows/`, adjust the `paths:` filter to your `Migration dir`. No secrets needed — the `--remote` history check stays a local/deploy-time concern.

Held back for v2.6.x: GitHub Copilot, GPT-4-based reviewers, and Codex GHAs — disqualified on the **IP-absorption pattern** (see `archive/v2.6.0-candidates.md` § "Why OpenAI/Microsoft are disqualified"), not on quality grounds.

## Installation

Copy the files you want into your consuming project's `.github/workflows/`:

```bash
cp pipekit/templates/ci/semgrep.yml       .github/workflows/
cp pipekit/templates/ci/claude-review.yml .github/workflows/
```

Then **edit the `branches:` list in each file** to match your project's release-class branches:

- **2-tier (dev → main)**: `branches: [main]`
- **3-tier (dev → beta → main)**: `branches: [beta, main]`

The list should mirror `method.config.md`'s `Ship environments` minus the first env (which is the day-to-day integration branch, where reviews would burn credit on every shipped WIT).

`claude-review.yml` also requires the `CLAUDE_CODE_OAUTH_TOKEN` repo secret (Settings → Secrets and variables → Actions → New repository secret). Get the token via the Claude Code Action setup flow.

## ⚠️ Never edit `claude-review.yml` on a feature branch

`anthropics/claude-code-action` performs a privileged app-token exchange that **requires the workflow file to be byte-identical to the version on the default branch.** Any change to it on a PR branch — including deleting a comment line — fails the exchange and the review job dies with:

```
App token exchange failed: 401 Unauthorized - Workflow validation failed.
The workflow file must exist and have identical content to the version on
the repository's default branch.
```

This is a deliberate security guard: a PR must not be able to alter the reviewer that runs with the OAuth secret, then have that altered version execute.

**The log is misleading.** It prints `ANTHROPIC_API_KEY: empty` (normal under OAuth auth) just above the real 401. Don't chase it as a secrets/1Password failure — scan for `App token exchange failed`.

**To change the workflow:** land the edit on the default branch first (its own PR), then rebase feature branches on top.

**To fix an already-broken branch** (restore the file to match the default branch):

```bash
git checkout origin/<default-branch> -- .github/workflows/claude-code-review.yml
git commit -m "ci: restore claude-review workflow to match default branch (fixes 401 app-token validation)"
```

Anchor: SiteLine POC-87, 2026-06-07 — a feature branch stripped the file's header comment; the review 401'd and was first misdiagnosed as a 1Password secret-load failure. The OAuth token had loaded fine.

## Trigger model — `opened` + `ready_for_review` + `synchronize`

`claude-review.yml` triggers on:

```yaml
on:
  pull_request:
    types: [opened, ready_for_review, synchronize]
```

**`opened` + `ready_for_review` are the merge-moment signals.** Combined with Pipekit's Draft-PR lifecycle below, the reviewer fires once at PR-open (if not Draft) and once when the user flips Draft → Ready (the "I'm done iterating, review it now" gesture). Draft PRs never fire — the `triage` job's `draft == false` guard keeps Draft iteration free.

**`synchronize` (every push to a Ready PR) is included so failed reviews self-heal.** When a review fails — a transient error, or the 401 workflow-validation guard (see the warning above) — the next push re-runs it automatically, instead of forcing a Draft → Ready re-flip to re-trigger. The cost of every-push reviews is capped two ways: Draft PRs are exempt (iterate as a Draft, push freely, no reviews), and the **skip-on-trivial `triage` job** filters doc-only and <5-LOC pushes before the paid review runs.

> **History:** `synchronize` was originally *omitted* (≤ v2.8.0) to avoid per-push credit burn — Piper's WIT-463 was a 23-commit branch where 23 reviews would have fired. It was added back once two facts converged: (1) the `triage` skip-on-trivial guard already absorbs the cheap-push noise, and (2) without `synchronize`, a failed review has no automatic re-trigger, which turned a one-line workflow-file mistake (SiteLine POC-87) into a Draft-dance to recover. The cost is genuinely modest for small teams; raise the `triage` LOC floor (5 → 50) if your push volume makes it add up.

## Draft-PR lifecycle (v2.6.0 #6)

Pipekit defaults `pk ship` to opening PRs as **Draft**. Iterate freely on a Draft PR without firing reviews. When you're ready to merge, run `pk ready <ID>` to flip Draft → Ready, which fires the `ready_for_review` event — that's when the outside reviewers run.

```bash
pk ship                # opens PR as Draft. No reviewers fire.
# ... iterate, push, fix, push ...
pk ready WIT-123       # flips Draft → Ready. Reviewers fire here.
# ... review, address feedback, merge once green ...
pk done WIT-123        # verifies the merge + cleans up (--merge instead lets pk run gh pr merge)
```

Use `pk ship --ready` to skip the Draft state on tiny one-shot PRs where iteration won't happen.

## Skip-on-trivial guard (`claude-review.yml` only)

The Claude template includes a `triage` job that skips the (paid) semantic review on:

- **Doc-only PRs** — every changed file is `.md`, `.txt`, or `.rst`
- **Trivial PRs** — total LOC changed `< 5` (typo fixes, single-constant tweaks)

Semgrep doesn't need this guard — it's free and short-running.

The threshold matches v2.6.0 #5 Option B (the decided path on path-restriction): all-paths review with a credit-floor, instead of an allowlist that might miss bugs in less-trafficked paths. PR #331 evidence: claude-review caught two must-fix bugs including one in a UI path that any reasonable allowlist would have excluded.

## Path filtering — intentionally absent

Earlier drafts of this template proposed restricting Claude reviews to `supabase/migrations/**`, `**/api/**`, `**/auth/**`, etc. **That was rejected for v2.6.0** based on empirical data from Piper PR #331: claude-review caught project-specific-rule violations (`export default` rule in `budget-editor-view.tsx`) and cross-file UUID-validation gaps in paths a reasonable allowlist would have excluded.

If your project's review costs become prohibitive, the lever is **the skip-on-trivial threshold** (raise LOC from 5 to 50, or extend the doc-only filter to `.json` / `.lock` / `.snap` files), not a path allowlist.

## Reference implementations

- **Semgrep**: Piper PR #335 (`3706208`, 2026-05-18) — 1059 rules / 56 files / 54s on a 6083+/350- promote PR. Zero findings on that PR (wrong PR class for Semgrep's strengths); pays off on user-input handling, dep upgrades, pattern-heavy code.
- **claude-review trigger config**: Piper PR #317 (Draft-skip + `ready_for_review`) + PR #330 (drop `synchronize`).

## Shared beta+prod DB? Read this before configuring your migration workflow

If your project's beta env reads from the same Supabase project as prod (no isolated beta DB), the choice of when migrations apply to the shared DB is load-bearing. The default many starter configs use — `supabase-production.yml` firing on `main`-merge — creates a window between beta-merge and main-merge where beta runs new code against the old prod schema. Audit-emission and new-function-call paths break on beta until the migration lands.

**Pipekit's recommendation for shared beta+prod DBs: fire migrations on `beta`-merge, not `main`-merge.** Closes the window. Full rationale + the one-line YAML diff in [`sop/Git_and_Deployment.md` § Shared beta+prod DB: schema-before-code sequencing](../../sop/Git_and_Deployment.md#shared-betaprod-db-schema-before-code-sequencing).

This is a workflow-shape decision, not a Pipekit code change — but it's worth getting right at project bootstrap so consumers don't rediscover the broken-beta friction one production cycle at a time.

## Related Pipekit gestures

- `pk ship` — opens PR (Draft by default). Will not fire reviewers until `pk ready` flip.
- `pk ship --ready` — opens PR Ready immediately (fires reviewers; use for one-shot tiny WITs).
- `pk ready <ID>` — flips Draft → Ready (fires reviewers).
- `/pr-fix --second-opinion=gemini` — opt-in local second opinion via Gemini Flash (covered in `pr-fix` skill, v2.6.0+). Use when you want a non-Claude, non-OpenAI-stack second read on a specific PR without standing up a GHA.

## Merge-driven Linear transition (`linear-transition.yml`)

Closes the **state-lag gap**: every Linear transition after `pk ship` is command-driven and manual (`pk done`, `pk promote --finish`). When a PR is merged through the GitHub UI — the common path — or those commands are skipped, the code lands on the integration branch but the issue never advances. Any skill that asks Linear "what's `Done`?" to decide "what shipped?" then under-reports (this bit three consecutive `/strategy-sync` runs; see `resources/linear-state-lag.md`).

This workflow drives the transition off the **merge event** instead of a human remembering a command. On a merged PR into the integration branch, it extracts every `<PREFIX>-NNN` from the branch name + PR title + body and advances each issue to `TARGET_STATE`.

It does **not** replace `pk done` / `pk promote --finish` — those also clean up the worktree and post commits to Linear. It's the **safety net** for when they're skipped. Both paths end at the same Linear state, and the transition is idempotent (it skips a WIT already at the target), so running both is harmless.

### Install

```bash
cp pipekit/templates/ci/linear-transition.yml .github/workflows/
```

Then:

1. **Edit the `env:` block** at the top of the job to match `method.config.md`:
   - `LINEAR_TEAM_NAME` → your `Team name`
   - `ISSUE_PREFIX` → your `Issue prefix`
   - `TARGET_STATE` → the state merged WITs move to: `In <FirstEnv>` (e.g. `In Dev`) for a multi-tier project, or `Done` for a single-tier project (integration branch == `main`)
   - `PRE_MERGE_STATES` → the states a WIT may currently be in for the transition to fire (safety guard, see below)
2. **Set the `branches:` trigger** to your integration branch (`method.config.md` → `Integration branch`).
3. **Add a `LINEAR_API_KEY` repo secret** (Settings → Secrets and variables → Actions). Use a Linear personal API key (linear.app → Settings → API) or an OAuth token scoped to issue writes. The workflow sends it as the raw `Authorization` header, matching `bin/pk`.

### Forward-only safety guard

The workflow only transitions a WIT **currently in one of `PRE_MERGE_STATES`** (default `UAT, In Progress, Building, In Review`). This is deliberate:

- A WIT already **past** this hop (promoted, `Done`) is left alone — the Action never pulls state backward.
- A WIT that landed in the merge **without going through UAT** (a bundled leap-frog) is surfaced as a warning and left for a human, not silently jumped to a post-merge state.

If a WIT is already at `TARGET_STATE` (e.g. `pk done` already ran), it's skipped. Genuine API failures emit `::error::` and fail the job so a stranded transition is visible in the Actions tab — but since the merge already succeeded, the failure never blocks anything.

### Multi-tier projects

This template watches **one** hop — the integration-branch merge → `In <FirstEnv>`. For downstream hops (promote PRs merging `dev → beta`, `beta → main`), either:

- copy the file per hop, each with its own `branches:` + `TARGET_STATE` (e.g. one watching `beta` → `In Beta`, one watching `main` → `Done`), or
- if your promote PRs carry the bundled-WIT tracker, keep using `pk promote <env> --finish` for those hops and let this workflow cover only the high-traffic integration-branch merges.

`pk promote --finish` already transitions every bundled `<PREFIX>-NNN` and fails loud, so it remains the recommended path for promote hops; the Action's leverage is highest on the integration-branch merge, which is the one most often done via the GitHub UI.

### Relationship with Linear's native GitHub integration

Linear ships its own GitHub integration that auto-transitions a linked issue on PR open and merge. **Before installing this workflow, check whether your Linear workspace has it enabled** (Linear → Settings → Integrations → GitHub) — the two can overlap.

If the native integration is **on**, it already moves a merged issue toward a "completed" state, so this workflow becomes a harmless idempotent safety net (it sees the issue already at target and skips). But the native integration has two limitations this workflow is built to avoid:

- **It doesn't understand Pipekit's state ladder.** Empirically (SiteLine, 2026-06-05 live test), the native integration moved a WIT `UAT → In Progress` on PR-open — *backward* in the Pipekit model (In Progress is pre-ship/ad-hoc; UAT is post-ship). This workflow is **forward-only**: its `PRE_MERGE_STATES` guard refuses to pull a WIT backward.
- **It can't do per-env hops.** On a multi-tier project the native integration jumps a `dev`-merge straight to its single configured "done" state, skipping `In Dev` / `In Beta`. This workflow targets the correct `<FirstEnv>` state per hop.

**Recommended posture:**

| Project shape | Native integration | This workflow |
|---|---|---|
| Single-tier (merge to `main` → `Done`) | fine to leave on | optional safety net (idempotent, harmless) |
| Multi-tier (env ladder) | turn **off** — it skips the ladder | **the** transition mechanism (one per hop, ladder-aware) |

The original state-lag this workflow fixes (`resources/linear-state-lag.md`) was observed on a **multi-tier** project, where the native integration is the wrong tool and manual `pk done` was the only path — exactly the gap this closes.

### Validation

Live-validated end-to-end on SiteLine, 2026-06-05: a real `POC-NNN` WIT in `UAT`, merged via a real PR, transitioned to `Done` by this workflow in CI (`UAT → Done` in the run log), with the idempotent skip confirmed on a second pass. The forward-only guard and ID extraction were exercised against the live Linear GraphQL API.

## Custom Semgrep rules

Pipekit ships starter Semgrep rules at `templates/ci/semgrep-rules/`. Currently:

- **`uuid-route-params.yml`** — flags dynamic route params flowing into Supabase queries without UUID validation. Deterministic backup for the failure mode surfaced 2026-05-18 (PR #331 claude-review caught it in three files; PR #341 had the same pattern and claude-review missed it). Copy to your project at `.semgrep/uuid-route-params.yml` and add `--config=.semgrep/` to your Semgrep invocation.

These are **starter rules** — test against your codebase before enabling in CI. Patterns may need tuning to your project's route conventions.

## `/pr-fix` flags (v2.6.0)

These flags ship alongside the CI templates:

- **`/pr-fix --from-review`** — skip the local Phase 3 fresh review; ingest existing PR review comments (typically from `claude-review.yml`) and feed them into Phase 4 aggregation + Phase 5 discussion. Use after the GHA reviewer has run to "address what claude-review flagged" without re-reviewing.
- **`/pr-fix --second-opinion=gemini`** — after Phase 4, invoke Gemini Flash for a parallel review. Opt-in only — counts against your Gemini quota. Requires `GEMINI_API_KEY`. See `skills/pr-fix/SKILL.md` § 4.6 for the full procedure and the thinking-tokens gotcha.

The flags compose: `/pr-fix --review --from-review --second-opinion=gemini` reviews-only, ingests GHA, adds Gemini.
