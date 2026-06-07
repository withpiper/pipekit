# Changelog

All notable Pipekit releases. Versioning follows semver-ish — minor bumps for new capability, patch for fixes/docs only.

Pin to a specific version: `./scripts/sync-method.sh v1.8.2`.

---

## Release Checklist

Every `chore(release): vX.Y.Z` PR must complete the following before merging to `main`:

- [ ] Bump `PK_VERSION` in `bin/pk`.
- [ ] Add a new `## vX.Y.Z — YYYY-MM-DD` section to `CHANGELOG.md` (this file).
- [ ] **Stamp every doc you actually edited in this release.** Don't bump stamps on untouched docs — the version gap between an older stamp and the current release is the drift signal we keep them for. The stamped doc set lives in the table below. If you add a new top-level doc or SOP, stamp it and add it to that table.
- [ ] If `method.md` / `RUNBOOK.md` / `GUIDE.md` were edited, also bump their stamps to `vX.Y.Z` with today's date (these three are the "constitutional" docs — they describe current behavior and should always carry the latest version).
- [ ] Update `RUNBOOK.md` line 14 (`./scripts/sync-method.sh vX.Y.Z` example) to the new tag.
- [ ] PR title contains `vX.Y.Z` so the `auto-tag-release` workflow can tag the merge commit (see `.github/workflows/auto-tag-release.yml`).
- [ ] Skip-check: leave historical `vX.Y.Z` references in prose alone (e.g., "as of v2.3.0" describes when a behavior shipped — that's intentional, not drift).

### Stamped docs (maintained list)

Every doc below carries a `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(blurb)*` line right after its H1. The stamp's `vX.Y.Z` is the release **the doc is calibrated to**, not the release we last touched typography in. When a release modifies a doc, bump its stamp to the new version + today's date. Otherwise, leave it alone so the gap surfaces drift.

| Doc | Role |
|-----|------|
| `method.md` | Constitutional — deep methodology |
| `RUNBOOK.md` | Constitutional — one-page daily flow |
| `GUIDE.md` | Constitutional — full instruction manual |
| `README.md` | Public-facing repo intro |
| `CLAUDE.md` | Guidance for Claude Code sessions in this repo |
| `STARTUP.md` | Project bootstrap reference |
| `VBW_COMMANDS.md` | VBW `/vbw:help` snapshot |
| `method.config.template.md` | Project-config template |
| `sop/Code_Quality.md` | SOP — coding conventions |
| `sop/Git_and_Deployment.md` | SOP — branches, merges, release flow |
| `sop/Hooks_SOP.md` | SOP — Claude Code hooks |
| `sop/Linear_SOP.md` | SOP — Linear model, states, labels |
| `sop/Session_Management_SOP.md` | SOP — Claude Code session hygiene |
| `sop/Skills_SOP.md` | SOP — skill anatomy, sync, overrides |

Format (copy verbatim): `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(one-line release blurb)*`. The three constitutional docs additionally carry an `HH:MM` suffix on the date to disambiguate same-day patch releases (e.g., `2026-05-13 21:04`).

Why this list exists: v2.4.0 through v2.4.3.1 all shipped with stale `v2.3.0` header stamps because release PRs edited prose at specific line numbers without touching the "Last updated" line. The header tells humans and AI sessions which version the doc describes — when it lies, every reader after that ships against the wrong contract.

---

## Unreleased

_Nothing yet._

---

## v2.8.0-rc3 — 2026-06-07

> **`/security-review` finding-stage discipline.** Folds review-quality guidance — proven in a downstream project's override — into the portable upstream skill so every project gets it. Skill-only; continues the rc cycle.

- **`/security-review` gains finding-stage coverage + an adversarial verification pass.** Three additions, all stack-agnostic: (1) a "Running this review" preamble (high reasoning effort; dynamic-workflow/`ultracode` fit; **grounded reads** — cite `file:line`, never infer a vuln or an all-clear from a filename); (2) a **finding-stage coverage** rule in the audit step (surface every finding tagged with confidence + severity, do not self-filter — capable models otherwise investigate deeply but under-report); (3) an **adversarial verification pass** after the agents report (try to *refute* each candidate against real auth/RLS/call-sites; mark confirmed/refuted/needs-info; only confirmed + needs-info feed the score). Plus Key Principle #5 (coverage before filtering). Generalized from SiteLine's project-specific override, which is being retired in favor of this upstream version (no more override drift).

> **Reviewer-trigger hardening + `/pk-bug` branch guard.** CI review templates now re-run on every push (self-healing) and carry a loud warning about the workflow-validation 401 that masquerades as a secrets failure; `/pk-bug` refuses to run its main-anchored phases from the wrong checkout. All fixes/docs — no new capability. Continues the rc cycle.

- **`claude-review.yml` + `semgrep.yml` now trigger on `synchronize`** (every push to a Ready PR) in addition to `opened` + `ready_for_review`. A failed review — transient, or the workflow-validation 401 below — now self-heals on the next push instead of forcing a Draft → Ready re-flip to re-trigger. Per-push cost on `claude-review.yml` stays bounded: Draft PRs are exempt (the `triage` job's `draft == false` guard) and the **skip-on-trivial `triage` job** filters doc-only / <5-LOC pushes before the paid review runs. Semgrep is free (Community Rules), so it re-runs unconditionally on non-Draft pushes. Reverses the original `synchronize` omission (Piper WIT-463, 23-commit branch) now that the triage guard absorbs the cheap-push noise — and without it, a one-line workflow-file mistake (SiteLine POC-87) had no automatic recovery path.
- **`claude-review.yml` hardened against the app-token-exchange 401.** `anthropics/claude-code-action` requires the workflow file on a PR to be byte-identical to the version on the default branch — a deliberate guard so a PR can't alter the reviewer that runs with the OAuth secret. Editing the file on a feature branch (even deleting a comment) fails the exchange with `401 Unauthorized - Workflow validation failed`. Added a prominent warning to the template header **and** `templates/ci/README.md`, including the load-bearing detail that `ANTHROPIC_API_KEY: empty` in the log is **normal under OAuth auth and not the cause** — scan for the 401 — plus the one-line restore fix (`git checkout origin/<default-branch> -- .github/workflows/<file>`). Anchor: SiteLine POC-87, 2026-06-07 (first misdiagnosed as a 1Password secret-load failure; the OAuth token had loaded fine).
- **`/pk-bug` checkout guard.** Phases 1–4 are main-anchored: intake → reproduce → diagnose → the *failing regression test* are authored on the integration checkout, uncommitted, before Phase 4's `pk branch` cuts the worktree (off `origin/<integration>`). A test written on any other branch is orphaned by that handoff. Added a preflight guard that **STOPs with a redirect** when the skill is invoked from a feature branch or an existing worktree, with the escape hatch that resuming a past-Phase-4 bug by `<ISSUE-ID>` skips the guard. Phases 5–8 (post-worktree) are unaffected.

---

## v2.8.0-rc1 — 2026-06-06

> **New capability: portable `/financial-review`.** A finance/calculation-accuracy review skill, generalized from SiteLine's project-specific version so any finance project (Piper, SiteLine, other users) gets it via the framework + checks-file split. Plus a sync-noise self-heal. Minor bump for the new skill; cut as a release candidate.

- **New portable skill `/financial-review`** — periodic financial-accuracy review for finance/calculation-heavy projects: cross-layer parity audit (DB view ↔ server/client calc ↔ UI footer; delta > tolerance = finding), baseline tests, parallel sub-agent audit, regression scan, severity-ranked report, and a recurring-WIT Linear lifecycle (In Progress → In Review → Done, transitions by **state name** via `pk` — no hardcoded UUIDs). Generalized from SiteLine's project-specific version using the **framework + checks-file** split: the skill ships the discipline + report shape; each project supplies its concrete checks (test cmd, calc files, DB-integrity SQL, parity formulas) in `resources/financial-review-checks.md`, scaffolded from `templates/financial-review-checks.template.md`. No-op on projects without a checks file. New `method.config.md` keys: `Financial review WIT` (blank disables the Linear lifecycle) + `Financial review checks` (path). Indexed in `Skills_SOP.md`.
- **`sync-method.sh` now gitignores `pipekit/.sync-changelog.md`** (idempotent self-heal). The sync changelog is regenerated on every run, so committing it was pure history noise — it had been landing in consuming-project sync commits. The sync now appends the ignore line to `.gitignore` if missing; the method content itself stays committed (worktrees check out tracked files only, so skills/rules/templates must be tracked — only this transient artifact is ignored).

---

## v2.7.1 — 2026-06-05

> **Merge-driven Linear transition — the real fix for the state-lag gap.** Closes `resources/linear-state-lag.md` item #1, the highest-leverage open item after v2.7.0.

- **`templates/ci/linear-transition.yml`** — a GitHub Action on `pull_request: closed` + `merged` against the integration branch extracts every `<PREFIX>-NNN` from the branch name + PR title + body and advances each issue to the configured `TARGET_STATE` (`In <FirstEnv>` multi-tier, `Done` single-tier) via the Linear GraphQL API — same auth + `workflowStates`/`issueUpdate` shapes as `bin/pk`. Removes the dependency on a human running `pk done` after a GitHub-UI merge, which silently stranded issues in their pre-merge state and made `/strategy-sync` under-report shipped work (bit three consecutive runs). Idempotent (skips a WIT already at target — harmless alongside `pk done`) and forward-only (a configurable `PRE_MERGE_STATES` allowlist means it never pulls a promoted/`Done` WIT backward and never leap-frogs an Approved WIT that bypassed UAT). PR-supplied text is passed via `env`, never interpolated into the shell (injection-safe); portable to bash 3.2+.
- **Live-validated on SiteLine (2026-06-05):** a real `POC-NNN` WIT in `UAT`, merged via a real PR, transitioned to `Done` by the workflow in CI, with the idempotent skip confirmed on a second pass.
- **Documented the relationship with Linear's native GitHub integration** (`templates/ci/README.md`). The native integration overlaps but can't respect Pipekit's state ladder — the SiteLine test caught it pulling a WIT `UAT → In Progress` (backward) on PR-open. Recommended posture: single-tier projects may leave native on (this workflow is then a harmless idempotent net); multi-tier projects should turn native **off** and use this workflow per hop (it's ladder-aware and forward-only). The original lag was on a multi-tier project — native's exact blind spot.
- Known limitations (tracked in the source doc): commit messages are not yet parsed for IDs (only branch + title + body); one workflow watches one hop (downstream promote hops need a sibling file or stay on `pk promote --finish`).

---

## v2.7.0 — 2026-06-05

> **The enforcement-substrate release, stabilized.** v2.7.0 hardened the gates that protect a ship — `/verify` and `/pr-fix` stop punting judgment back to the human and instead carry a verdict — and added `/pk-express`, an idea→Draft-PR autopilot for simple WITs. This final tag is the rc6 tree with no new behavior: the last gate before cutting was re-validating the portable `/pr-fix --engine=builtin` fallback (the engine every consuming project without the `pr-review-toolkit` plugin lands on), which passed end-to-end including the rc3 historical finders (git-history + prior-pr-comments) firing in the builtin path.

The 2.7.0 arc, by release (detailed sections below):

- **rc1** — discipline substrate, source-authority hierarchy, evidence-gated `/verify`, `pk ship` hard-fail on missing `verify-complete.md`.
- **rc2** — pluggable-engine `/pr-fix` (pr-review-toolkit agents by default, built-in fallback) + two-axis severity×confidence triage; Opus 4.8 framing audit (Fresh-Chat → stage-isolation).
- **rc3** — `/pr-fix` dependency-free historical finders (git-blame regression + prior-PR-comment reapplication); `/pipekit-update` Phase P (pr-review-toolkit as a managed dependency); first Linear-state-lag fixes.
- **rc4** — `/verify` migration flag self-reviews via subagent (Hold/Approve verdict, not a raw `git show`); `pk branch` auto-discovers and symlinks nested per-app env files into worktrees.
- **rc5** — `pk doctor` false-ship cross-check; completed `pk done` finish (parent-branch reset, stack advisory, script-deploy `Deploy command` reminder); migration pre-merge re-check; discipline lines.
- **rc6** — `/pk-express` idea→Draft-PR autopilot (tier-guarded; quick/standard only), validated live on SiteLine POC-14; load-bearing `/light-spec` fix (publish to configured `Spec ready state`, not hardcoded `Specced`); `pipekit-cmux` turn-end-detection lesson.

### What changed since rc6

- `PK_VERSION` → `2.7.0`; CHANGELOG `Unreleased` finalized into this section; `CLAUDE.md` + `RUNBOOK.md` stamps and the `sync-method.sh` example bumped to `v2.7.0`.
- Re-validated `/pr-fix --engine=builtin` (the rc2 restructure + rc3 historical-finder widening) — PASS. No code change; the gate that was blocking the final tag is cleared.
- **Documentation content pass** — brought the constitutional + reference docs current with the whole rc3→rc6 feature set (they had lagged at rc2/older): `GUIDE.md` and `method.md` (→ v2.7.0) now document `/pk-express`, the `/pr-fix` pluggable engine + historical finders, `/verify` migration self-review verdict, `pk branch` nested env symlinks, `pk doctor` false-ship check, `pk done` rc5 finish, `/pipekit-update` Phase P, and `/light-spec`'s configured `Spec ready state`; `sop/Skills_SOP.md`, `sop/Linear_SOP.md` (tier labels), `STARTUP.md` (V2 config-key reference), and `README.md` updated to match. `method.md`/`GUIDE.md` stamps move rc2 → v2.7.0; `method.config.template.md` left unstamped (content already complete — the version gap is the intended drift signal).
- **Full-release drift sweep** — ran `drift-check.sh` + five parallel deep audits across every template, SOP, skill, CI/config template, and a cross-cutting consistency pass. Fixes: `agents/plan-reviewer.md` referenced the retired v1 `/launch` as its invoker (→ `/review-plan`); `skills/06-linear-todo-runner/skill.md` hardcoded the `Specced` overflow-fetch state (→ configured `Spec ready state` — the same two-state-board bug the rc6 `/light-spec` fix closed); `skills/verify/skill.md` dropped a phantom `/pk-compound` forward-ref; `templates/strategy/design-direction.md` de-pinned two `Opus 4.7` model references to be model-agnostic; `sop/Session_Management_SOP.md` stamp rc2 → v2.7.0 (content was already final). The remaining drift-check hits are illustrative example paths and correctly-labelled v1-historical mentions, left as-is.
- **Positioning** — `README.md` gains a "Why Enforcement, Not Memory" section making the enforcement-over-persistence thesis legible: Pipekit bets on independent-judgment gates, not context persistence, because confident-wrong output scales with model capability while a larger window does not make an agent able to review its own work.

---

## v2.7.0-rc6 — 2026-06-03

> **`/pk-express` — an idea→Draft-PR autopilot for *simple* WITs.** Takes an existing brainstormed WIT (or a raw idea) and drives it through the four stages that already self-drive — `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify + ship) — advancing on each stage's success signal and stopping only at genuine attention gates. Quick/Standard tier only; refuses heavy work. Validated end-to-end on a live SiteLine WIT (POC-14): it correctly split off the heavy half as a follow-up, drove the simple half to a merged PR, and stopped at the tier guard the first time around.

### What changed

**`/pk-express` idea→PR autopilot** (`skills/pk-express/skill.md`, indexed in `Skills_SOP.md` + `CLAUDE.md`)
- New orchestrator skill. `/pk-express <ISSUE-ID>` (primary) takes a brainstormed WIT to a Draft PR; `/pk-express "<idea>"` prepends brainstorm. Resume routing reads the issue's Linear state and joins at the right stage.
- **Auto-advances** on success signals (brainstorm Now, spec Approved, branch ok, verify Pass+0-flags) and **stops + notifies** at exactly five gates: brainstorm not-Now, **`tier:heavy` (refuses heavy)**, spec stalemate, `/verify` flags, and the Draft-PR/UAT handoff. Never runs `pk ready`/`pk done`/`pk promote`.
- Express mode collapses only the low-judgment friction (between-stage typing, the Now/Later/Kill prompt, spec passes 2–3); the `/verify` gate and human PR/merge gates stay intact.
- Handles the **Quick→Approved spec-skip path** (a Quick item brainstorm sends straight to Approved skips the spec stage).

**`/light-spec` publishes to the configured `Spec ready state`, not hardcoded `Specced`** (`skills/01-light-spec/skill.md`)
- `/light-spec` hardcoded moving the issue to `Specced`, but `pk spec-cycle`'s entry precondition is config-driven (`Spec ready state`) — two halves of one interlock, only one read config. On a board without a `Specced` state (e.g. SiteLine's Piper-poc: `Needs Spec → Approved`), `/light-spec` tried to set a nonexistent state and broke the cycle. Now it publishes to the configured ready state (default `Specced` — no change for canonical boards), so the interlock holds on any workflow. The skill's own line 239 already stated this intent; the implementation now matches.

**`pipekit-cmux`: watch worker turn-end, not narration keywords** (`templates/rules/pipekit-cmux.md`)
- New orchestration subsection + anti-pattern: when master control watches a worker Claude via `read-screen`, detecting gates/completion by grepping for keywords false-fires on the worker *narrating its own plan*. Detect the **turn ending** (live present-tense spinner gone across 2 polls — never the past-tense completion marker) or wire `Stop`/`Notification` hooks to `cmux notify`. Earned watching the `/pk-express` validation run.

---

## v2.7.0-rc5 — 2026-06-03

> **Log-mining release: ten fixes surfaced by Piper + SiteLine session logs.** The dominant signal across both projects was *"Done" overstating reality* — issues marked built/shipped that git never built, and merges that never deployed. rc5 adds a `pk doctor` integrity check for the false-ship case, completes `pk done`'s finish (process/branch teardown + a deploy reminder for script-deploy projects), hardens migration pre-merge coordination, and adds four discipline lines. (The SHA-aware `verify-complete.md` gate was scoped out — it's a behavior change, deferred to its own cut.)

### What changed

**`pk doctor` flags false-ships via Linear↔git cross-check** (`bin/pk`, `scripts/test-pk-doctor-integrity.sh`)
- New testable helper `pk_git_build_evidence` (`built | docs-only | none`) plus a `pk doctor` section: for WITs the board calls UAT/Done, confirm git history on the integration branch actually contains implementation referencing the id. No commits — or only docs commits — flags a likely false-ship. The leading-direction mirror of `/strategy-sync` 4b (which catches merged-but-not-Done). Advisory + heuristic (assumes commits reference the WIT id); surfaces candidates, never hard-fails.

**`pk done` finish completed** (`bin/pk`, `method.config.template.md`)
- **Deploy reminder** (new optional `Deploy command` config): for script-deploy projects where `pk promote` is disabled, `pk done` surfaces the deploy command after merge so "merged ≠ deployed" can't pass silently. Advisory — never auto-runs a deploy.
- **Parent-branch reset:** when the parent repo is sitting on the just-merged feature branch, `pk done` returns it to the integration branch (clean-tree guarded) before deleting — you can't delete the branch you're on, and parking there was recurring friction.
- **Stack advisory:** notes that a worktree's local Supabase stack / dev server keeps running after teardown (`pk done` won't stop it — may be shared).
- **Softened migration check:** the post-merge "not on remote" check is now an explicit advisory that notes a collision-rename can cause a false mismatch (ground truth: `supabase migration list` / the live DB), instead of a bare scary warning.

**Discipline rules — four log-mined additions** (`templates/rules/`)
- `pipekit-migrations`: re-check migration timestamps against the base-branch tail right *before merge*, not only at creation (long-lived branches get overtaken; the collision is invisible in the worktree).
- `pipekit-cmux`: when a worker surface ref goes stale, treat git/Linear/`gh` as ground truth instead of polling a dead pane.
- `pipekit-discipline`: red flag — a vendor-UI affirmative state (green check, "disabled") is a claim to verify, not evidence of effect.
- `pipekit-tooling`: project-critical MCP servers must live in committed `.mcp.json`, or they're invisible inside `pk branch` worktrees.

---

## v2.7.0-rc4 — 2026-06-02

> **Two gates stop punting work back to the human.** `/verify`'s migration flag used to hand the user a raw `git show` to review themselves — it now runs the migration rubric in a subagent and carries a Hold/Approve **verdict** the user approves. And `pk branch` only ever symlinked root-level env files, so monorepo worktrees came up reading the `*.example` placeholder with no real backend — it now auto-discovers and links nested per-app env files too. Carries forward the rc3 `/pr-fix` historical finders and `pr-review-toolkit` managed dependency.

### What changed

**`/verify` migration flag now carries a verdict, not a bare pointer** (`skills/verify/skill.md`)
- Step 6 Flag check A previously detected migration files in the diff and surfaced a bare `FLAG: … review for irreversibility, RLS, search_path` — handing the user a raw `git show` to review themselves, the exact analysis the skill exists to perform. It now spawns a review subagent (`pr-review-toolkit:code-reviewer`, fallback `general-purpose`) that applies `/pr-security-review`'s migration rubric (M1–M8, plus the RLS / SECURITY DEFINER / GRANT rubrics when the diff body contains those patterns), writes `migration-review.md`, and the flag carries the resulting **Hold/Approve verdict**. `reality-check.md` gained a `## Migration review` section that inlines it.
- Runs on **every tier** (migrations are high-stakes regardless of tier) and is complementary to Step 5's generic antagonistic pass — that lens finds "what's wrong"; this one returns a structured verdict against named rubric IDs.
- A `Hold` verdict pauses auto-ship via the flag but does **not** auto-downgrade `/verify` status to NEEDS WORK — consistent with how antagonistic findings and every other flag behave; classification stays the user's RECONCILE step. The human gate is unchanged in spirit (migrations always pause for a human eye), changed in substance: the user now approves `Hold: M3 missing backfill` or `Approve — no findings` instead of a `git show` they were never positioned to act on.

**`pk branch` now symlinks nested per-app env files into the worktree** (`bin/pk`, `scripts/test-pk-env-links.sh`)
- `pk branch` symlinked only a hardcoded **root-level** env list (`.env .env.local .envrc …`). In a monorepo, the browser client reads `apps/web/.env.local` — which is gitignored, so a fresh worktree never had it and fell back to the `*.example` placeholder (`NEXT_PUBLIC_SUPABASE_URL=your-project.supabase.co`), leaving the app with no real backend to talk to.
- Extracted the linking into a testable `pk_link_env_files` helper and added pass (2): auto-discover every real nested env file (`.env` / `.env.local` / `.env.dev` / `.env.prod`) in the parent and symlink it at the same relative path. Exact-name match (never `*.example`), pruning `node_modules` / `.git` / `.worktrees`. Idempotent; never clobbers a real file already in the worktree.
- **Auto-discover, not config:** a `method.config.md` env-link list was considered and rejected — the failure was that the need was *implicit* and nobody enumerated it; a config list reintroduces the same "forgot to configure it" footgun. Discovery mirrors parent reality with zero setup, so new monorepo apps are picked up automatically.
- **Recovery for existing worktrees:** the worktree-exists path in `pk branch` falls through to the symlink step, so re-running `pk branch <ID>` (idempotent) backfills the missing links into a worktree created before this fix.
- New `scripts/test-pk-env-links.sh` exercises the real helper (sources `bin/pk`): real-value link, `.example` exclusion, nested depth, `node_modules` prune, idempotency, no-clobber.

**`/strategy-sync` fresh-chat → stage-isolation framing** (`skills/10-strategy-sync/skill.md`)
- Aligned the fresh-chat requirement with v2.7.0-rc2's `method.md` stage-isolation reframe: clarified it's *deliberate isolation* (an agent that watched the build can't independently diff shipped-reality vs. the docs), **not** a context-window workaround — a 1M window doesn't relax it because the risk is contaminated judgment, not lost memory. Wording only, no behavior change. Surfaced by the Opus 4.8 rollout review.

---

## v2.7.0-rc3 — 2026-05-31

> **`/pr-fix` gains temporal signal; `pr-review-toolkit` becomes a managed dependency.** rc2 made `/pr-fix`'s native engine the `pr-review-toolkit` specialists — but those agents only ever see the diff. rc3 adds two dependency-free **historical finders** that read *how the code got here* and *what reviewers already said*, running alongside the specialists in the same parallel wave. Separately, the plugin dependency rc2 introduced was being borrowed from a project-local install on an unrelated repo; rc3 promotes it to a user-scope managed dependency and teaches `/pipekit-update` to keep it current.

### What changed

**Historical finders in `/pr-fix`** (`skills/pr-fix/skill.md`)
- Two new dependency-free finders (`git` + `gh` only) join the native fan-out (§3.1), **alongside** the toolkit specialists — peers, not a pre-pass:
  - **git-history** — `git blame`/`git log` on modified+deleted line ranges. Flags (a) changes that regress a recent deliberate bugfix (cites the prior commit sha), (b) removed guards whose blame points to a fix/incident commit, (c) high-churn fragile regions needing extra test coverage.
  - **prior-pr-comments** — pulls review comments from recently-merged PRs that touched the same files and flags any that **reapply** to the current diff (confidence ≈70 — past feedback is a lead, not proof).
- Because they need no plugin, they also run in the `--engine=builtin` path (§3.2).
- New dedup rule §4.1.5 **Historical corroboration**: a historical finder matching a specialist *raises* that finding's confidence (+10, cap 99) instead of being dropped — recurrence-is-a-reality-signal applied across finders, not just across `--runs`.
- Ordering rationale recorded: running the finders *first* to prime the specialists was considered and rejected for this cut — it serializes the wave for marginal gain, and the corroboration rule already captures most of the benefit.

**`pr-review-toolkit` as a managed dependency** (`skills/pipekit-update/skill.md`)
- New **Phase P — Ensure Plugin Dependencies**, routed through *both* upstream (Pipekit repo) and downstream (consuming project) modes. It installs/updates `pr-review-toolkit@claude-plugins-official` at **user scope** via the `claude plugin` CLI. Plugins are not files `sync-method.sh` can copy — they live in `~/.claude/plugins/` — so Phase P calls the CLI directly; it touches harness config, never project files.
- If the `claude` CLI is absent (e.g. a CI runner), Phase P skips with a printed note — `/pr-fix --engine=builtin` remains the dependency-free fallback. Project-scope documented as the alternative for teams wanting the dependency to travel reproducibly with a repo.

**Linear-state-lag fixes** (`bin/pk`, `skills/10-strategy-sync/skill.md`)
- Surfaced by a Piper handoff (`resources/handoffs/Handoff-Pipekit-Linear-State-Lag.md`): post-`pk ship` Linear transitions are command-driven, not merge-driven, so a merged PR can leave its issue stranded in UAT — under-reporting shipped work to `/strategy-sync`. Verified against the code: `pk promote --finish` already transitions every bundled WIT and fails loud, but `pk done` transitioned a single issue and swallowed the failure with `|| true`.
- `pk done` now **fails loud** on a failed UAT→In <Env> transition — it warns that the issue is stranded but continues worktree cleanup (the merge already succeeded; hard-failing post-merge would strand the worktree, which is worse).
- `/strategy-sync` Phase 1 gains a **mandatory merged-PR cross-check** (§4b): diff merged PRs on the integration branch against the Linear `Done` set and treat any merged-but-not-Done issue as shipped. Ports the guard Piper carried locally into the canonical skill so every project inherits it. The deeper root-cause fixes (a merge-driven transition Action; bundled-WIT parsing in `pk done`) remain a scoped follow-up.

> **Release note:** stamped `CLAUDE.md` + `RUNBOOK.md` to `v2.7.0-rc3` (RUNBOOK has no daily-flow change — only the sync example + stamp); `method.md` / `GUIDE.md` left at their prior stamps (untouched this cut — the gap is the intended drift signal). Bumped `PK_VERSION` and the RUNBOOK sync example. **Operational note for this machine:** `pr-review-toolkit` was re-homed from a `local` install on the SiteLine project to a `user`-scope global install, so Pipekit (and every other project) no longer borrows another repo's plugin registration. The synced skill changes are portable; the plugin re-home is environment state, not shipped content.

---

## v2.7.0-rc2 — 2026-05-31

> **Opus 4.8 framing audit — docs reframed, one handoff slimmed, nothing lost.** An impact audit of Pipekit's artifacts against Opus 4.8 (1M context window + harness-persistent memory) found that the persistence layer those capabilities would obsolete was *already pruned in the 4.7 cycle* (`NEXT.md` retired v2.1.0, bash Stop hook retired, `Session_Management_SOP.md` already 1M-aware). No artifact was REDUNDANT-delete. The real finding was framing rot: a few docs still justified discipline as a small-window workaround. These edits correct the *why* without changing the rule, refresh the external prompt-engineering snapshot to 4.8, codify a durable-vs-ephemeral split for handoff docs (git history holds any removed runbook), and harden `pr-fix` against 4.8 recall loss (the one enforcement skill that suppressed findings at the find stage).

### What changed

**Stage isolation decoupled from context scarcity** (`method.md` § Fresh-Chat Discipline)
- Reframed the section's core: the load-bearing principle is **stage isolation** (an agent can't independently review work it helped produce), not "start fresh because the model forgets." Added an explicit paragraph that this is *not* a context-window workaround — the 1M window + harness memory do not relax it, because the risk is **contaminated judgment, not lost memory**. Named the two mechanisms (hands-on fresh chat / by-construction subagent spawning) as interchangeable deliveries of the same isolation. Header name kept to preserve ~10 live `§ Fresh-Chat Discipline` cross-references (GUIDE.md + 5 skills).

**Session boundaries reframed as cognitive-load hygiene** (`sop/Session_Management_SOP.md`)
- Added explicit "session boundaries exist for cognitive load, not token scarcity" framing, distinguishing these *optional* hygiene boundaries from the *mandatory* stage-isolation gates in `method.md`. De-versioned two unverifiable behavioral claims (subagent-default rate; effort-tier defaults) — kept the durable guidance, flagged the effort table as "calibrated on 4.7, re-validate." Bumped the source attribution 4.7 → 4.8.

**Scope-guidance de-versioned** (`sop/Skills_SOP.md`)
- Generalized the "Writing Skill Prompts for Opus 4.7" subsection to be model-agnostic — literal-instruction-following guidance is durable prompt hygiene, not a 4.7-specific trait. Model-pinning section left unchanged (a cost/capability tradeoff independent of context size).

**Anthropic prompt-engineering snapshot refreshed to 4.8** (`sop/Anthropic - Prompting best practices.md`)
- Re-fetched the live published doc (snapshot date → `2026.05.31`); upstream had been restructured to lead with a `Prompting Claude Opus 4.8` section plus updated model strings. This is a verbatim external snapshot (not a Pipekit-stamped doc), so it was refreshed by re-fetch — never hand-edited. Surfaced two Pipekit-relevant facts: (a) `xhigh` remains Anthropic's recommended default for coding/agentic on 4.8; (b) a new "Code review harnesses" caveat — 4.8 obeys "only report high-severity" instructions more faithfully, lowering *measured* recall unless review prompts say "report everything, filter downstream."

**Handoff & session-log content discipline codified** (`sop/Session_Management_SOP.md`, `resources/nebula-piper-pipekit-v2.5.0.1-handoff.md`)
- New section splitting handoff/log content into **durable** (decisions, caveats, lessons, gaps — keep) vs **ephemeral** (step-by-step state recaps — now carried by Linear + harness memory). Retrofitted the v2.5.0.1 Piper migration handoff as the worked example: a ~430-line Step 0–7 runbook slimmed to a one-page durable record (F-caveats + the `Withpiper` team-name footgun + gaps), with the procedural body preserved in git history.

**Enforcement-layer recall audit + `pr-fix` fix** (`skills/pr-fix/skill.md`)
- Audited the four enforcement surfaces (`pr-fix`, `security-review`, `verify`, the DOUBT loop) against the refreshed Anthropic doc's new "Code review harnesses" guidance — 4.8 obeys "be conservative / only report high-severity" instructions more faithfully, investigating as deeply but converting *fewer* investigations into reported findings. Result: the DOUBT loop (`pipekit-discipline.md`), `security-review`, and `verify` already follow the "coverage at finding, filter downstream" pattern — no change needed. `pr-fix` was the outlier: it discarded sub-80-confidence findings *at the finding stage* (§3.3) with "silence is better than noise," which on 4.8 biases the self-assigned confidence score downward and silently drops real bugs.
- Fix: decoupled finding from display. §3.3 now mandates coverage-first honest scoring with no self-censoring; the `>= 80` threshold became a Phase-4 **display** filter; sub-80 findings are retained in a collapsed "below threshold" coverage list instead of discarded. The clean-by-default precision UX (only `>= 80` shown up front) is unchanged. Reframed the §8 intro and Calibration rule 1 from "precision over recall / zero noise" to "coverage when finding, precision when displaying."

**`/pr-fix` review engine made pluggable + two-axis triage** (`skills/pr-fix/skill.md`)
- Born from the audit's `/pr-fix` vs `pr-review-toolkit:review-pr` comparison on Piper PR #408: a properly-configured native toolkit run matched or beat `/pr-fix`'s built-in review on depth, but `/pr-fix` owns the parts review-pr lacks (intent + cross-spec handoff scan, dedup, interactive fix, Linear/pipeline integration). Rather than retire either, `/pr-fix` Phase 3 is now **engine-pluggable** (mirrors `/work`'s backend model): default `native` fans out the `pr-review-toolkit` specialist agents (code-reviewer, silent-failure-hunter, pr-test-analyzer, …) as read-only subagents; `--engine=builtin` runs the original reference-file dimensions with zero plugin dependency. **Fail-loud** if the plugin is absent (no silent downgrade) — `--engine=builtin` is the escape hatch. One invocation, native engine, /pr-fix's remediation.
- **Two-axis triage replaces the single confidence threshold.** Severity (impact) and confidence (likelihood) are now kept independent — `severity=Critical, confidence=20` is valid and surfaces. New **INVESTIGATE** quadrant (high severity, low confidence): surfaced up top, never auto-fixed. Surfacing rule = `confidence ≥ 80 OR severity ≥ High`; ordering = severity-dominant priority (`0.7·severity + 0.3·confidence`); below-threshold collapsed list = low-severity *and* low-confidence only. Fixes the morning's edit's blind spot — the PR #408 fail-open guard (Critical/78) now surfaces instead of sitting below an 80 line. `--quick` auto-fixes the FIX quadrant only.
- New flags: `--engine=native|builtin`, `--runs=N` (recurrence across runs raises confidence). `--from-review` now explicitly composes as a merge source — including ingesting a `pr-review-toolkit` run that already posted.

> **Release note:** stamped `method.md` / `GUIDE.md` / `CLAUDE.md` / `RUNBOOK.md` (constitutional, +`HH:MM`) and `sop/Session_Management_SOP.md` / `sop/Skills_SOP.md` to `v2.7.0-rc2`; bumped `PK_VERSION` and the RUNBOOK sync example. **Native `/pr-fix` engine adds a `pr-review-toolkit` plugin dependency** (Anthropic first-party, Apache-2.0, actively maintained — repo pushed 2026-05-31, plugin last touched 2026-04-28). Not carried by `sync-method.sh`; consuming projects must install the plugin for `--engine=native`, and `--engine=builtin` is the dependency-free path. The `/pr-fix --engine=native` flow was smoke-tested end-to-end against Piper PR #408 this cycle.

---

## v2.7.0-rc1 — 2026-05-25

> **Release candidate: discipline substrate + evidence-gated `/verify` + `pk ship` hard-fail.** Week 1 lays the rules substrate that the rest of v2.7 leans on (Completion Claims doctrine, two-tier Plan Gate, source-authority hierarchy, trigger-phrased skill descriptions). Week 2-3 rewrites `/verify` to write a per-issue evidence layer (`evidence.txt` with per-command anchors, `reality-check.md`, `verify-complete.md`) and wires `pk ship` to hard-fail on missing `verify-complete.md` for `tier:standard | tier:heavy`. Antagonistic review is mandatory for `tier:heavy` and opt-in via `--review` for `tier:standard`, using the verbatim DOUBT prompt from `pipekit-discipline.md`. RC because Week 4 (`/pr-fix` full subagent dispatch + cross-persona promotion) is still ahead; ship to consumers when Week 2-3 validation completes on Pipekit-the-repo.

### What changed

**Discipline substrate** (`templates/rules/pipekit-discipline.md`, `templates/rules/pipekit-tooling.md`, `sop/Skills_SOP.md`, `templates/CLAUDE.md.template`)
- **Completion Claims doctrine.** New H2 section in `pipekit-discipline.md`: CLAIM → EXTRACT → DOUBT → RECONCILE → STOP loop with verbatim adversarial subagent prompt. RECONCILE precedence: AC misread → Valid actionable → Valid trade-off → Noise. Doubt-theater red flag at 2+ cycles with substantive findings but zero actionable.
- **Plan Gate two-tier.** Inline form (`PLAN: 1. … 2. … 3. … → Executing unless you redirect.`) for small/single-module changes; Expanded 5-bullet form for cross-module/new-surface/multi-file. Replaces the prior single 5-bullet ad-hoc gate.
- **Source Authority Hierarchy.** New subsections in `pipekit-tooling.md`: Tier 1 official docs + installed source under `node_modules/<pkg>/` is ground truth; Tiers 2-4 vendor changelogs / web standards / runtime tables are authoritative for their scope; StackOverflow / third-party blogs / AI-generated examples / training data are leads not facts. UNVERIFIED flag pattern when no Tier 1-4 source available.
- **Enumerate the Surface Before Claiming Behavior** (`pipekit-tooling.md`). Sibling rule to source authority: before claiming what CI/infra does, `ls` the full surface (workflows, migrations, env files, scripts) — never reason from a single known file. Case study from 2026-05-25: a session knew about `supabase-production.yml` (beta-merge trigger) and confidently advised the user that dev-merge wouldn't auto-apply a migration, missing that `supabase-dev.yml` existed and DID fire on dev-merge. The advisory cost ~5 min of manual verification that was already done by CI. Six concrete enumeration commands documented per claim category (workflows / migrations / env vars / scripts / rules / skills).
- **Skill frontmatter conventions** in `sop/Skills_SOP.md`: trigger-phrased descriptions (pack `Use when X. Use when Y.` into the `description:` field — this is the surface Claude scans for auto-invocation) + `disable-model-invocation: true` for prompt-only skills (`/pk-exit`, `/concept`, `/define`).
- **`resources/solutions/` routing pointer** in `templates/CLAUDE.md.template` — placeholder for Phase 2's `/pk-compound` bug-track corpus.
- **30 skill descriptions** updated to trigger-phrase format. Verification: `grep -E '^description:' .claude/skills/*/skill.md | grep -v 'Use when'` returns only intentional exemptions (`/pk-exit`, `/pk-bug`).

**`/verify` full rewrite** (`skills/verify/skill.md`)
- **Tier-aware dispatch.** Step 0.5 one-screen contract: `quick` is virtual (stdout only, no file writes); `standard` writes the evidence layer; `heavy` adds mandatory antagonistic review.
- **Evidence artifact layer.** For `TIER != quick`, every run produces three files under `Logs/Verify/<YYYYMMDD>/<ISSUE>/`:
  - `evidence.txt` — per-command `==> $ <cmd>` header, tee'd stdout/stderr, `exit:` + `duration:` trailers. Flag-enumeration appends `FLAG: ...` lines. Per-command structure enables anchor cites as `evidence.txt:L<line>`.
  - `reality-check.md` — gate-results table with anchors, inlined `qa-verdict.md` (Step 4) + `adversarial.md` (Step 5), flags surfaced, status reasoning, next actions.
  - `verify-complete.md` — minimal sentinel (issue, stamp, tier, status, sha) written **only on PASS**. Stale sentinels are explicitly removed on NEEDS WORK so `pk ship`'s gate cannot trust a stale file.
- **QA verdict via Write tool.** Subagent is configured with `allowed-tools: Read, Bash, Write` and writes its verdict block to `$VERIFY_DIR/qa-verdict.md` directly. Returns a one-line confirmation. Removes parent-side parsing. Anchor-emit discipline: cite sources as `<file>:<line>`, gate output as `evidence.txt:L<line>`.
- **Step 5 antagonistic review.** New subagent dispatch using the **verbatim** DOUBT prompt from `pipekit-discipline.md`. Mandatory for `tier:heavy`. For `tier:standard`: auto-fires on **sensitive-path diffs** (paths matching `supabase/migrations/`, `/auth/`, `/middleware\.`, `/rls\.`, `/policies\.` or diff content matching `SECURITY DEFINER` / `GRANT EXECUTE` / `REVOKE EXECUTE` / `CREATE POLICY` / `ALTER POLICY`); otherwise opt-in via `--review`. Skipped for `tier:quick`. Patterns mirror Week 4's `/pr-fix` design. Writes findings to `$VERIFY_DIR/adversarial.md`. Findings do NOT auto-downgrade status — classification (AC misread / actionable / trade-off / noise) is the user's RECONCILE call, not the subagent's.
- **Flag check E** added to Step 6 enumeration: antagonistic findings count surface as flags, pausing auto-ship per the load-bearing F6 rule. Existing Step 3.5 (now Step 6) flag logic and Step 4 (now Step 9) auto-ship behavior preserved verbatim.

**`pk ship` verify-complete.md gate** (`bin/pk`)
- New `pk_linear_tier` helper queries the issue's Linear labels for `tier:(quick|standard|heavy)`, defaults to `standard` on miss/error so the gate stays operative when Linear is unreachable.
- After issue extraction (~line 1090 of `cmd_ship`), before `git push`: read `Logs/Verify/<YYYYMMDD>/<ISSUE>/verify-complete.md`. Missing file → `return 1` with the expected path printed.
- Three escape hatches: `--force` (parsed in `cmd_ship`; bypass + Linear comment audit trail via `pk_linear_comment`); `PK_VERIFY_BYPASS=1` env var (emergency bypass + `Logs/Verify/bypass.log` entry); `tier:quick` (warn + proceed, virtual gate by design).
- Shipped in two atomic commits (warn-only then hard-fail flip) for bisect-clean rollback.

**`/light-spec` tier auto-derive** (`skills/01-light-spec/skill.md`)
- New Phase 3.6 parses the spec body's `**Complexity:**` field and maps it to a `tier:*` Linear label: `Trivial | Low → tier:quick`, `Medium → tier:standard`, `High | Very High | Critical → tier:heavy`. Hour-range fallback when no named token present (`≤4h → quick`, `5-11h → standard`, `≥12h → heavy`).
- Phase 5's Linear save merges existing labels (stripping any stale `tier:*`) with `spec` + the Phase 3.6-derived tier. Custom human-applied labels (`Feature`, `Finance`, domain tags) survive the publish.
- Closes the spec-author-classified-as-Heavy-but-the-label-says-otherwise gap surfaced by WIT-419 (spec body said `Complexity: High (~16-22h)` but the Linear label was `Heavy`, not `tier:heavy` — `pk_linear_tier` defaulted to `standard` instead of recognizing the intent).

**`PK_VERSION`** 2.6.0.1 → 2.7.0-rc1.

### Why

The catalog audit (multi-day external review of `shanraisshan/claude-code-best-practice`, deep-dives into `addyosmani/agent-skills`, `msitarzewski/agency-agents` Testing division, and `EveryInc/compound-engineering-plugin`) surfaced one convergent gap: **artifact-gated review that the model cannot persuade its way through**. Pipekit's prior `/verify` was persuasion-based prose — the LLM decided whether to comply. v2.7's evidence layer turns review into an artifact chain with explicit stop conditions (the `verify-complete.md` sentinel) and default-deny posture (`pk ship` aborts on missing file).

The DOUBT prompt format borrows from doubt-driven-development (addyosmani) and adapts the "Contract misread" classification to Pipekit's Linear AC list. The Plan Gate two-tier reformulation absorbed feedback that the prior single 5-bullet gate was over-applied to trivial edits — inline mode now handles bug fixes and small refactors without ceremony.

### Migration

- **Pin to v2.7.0-rc1.** Run `./scripts/sync-method.sh v2.7.0-rc1` from inside your consuming project. RC sync recommended for one cycle of dogfooding before bumping to v2.7.0 stable.
- **`tier:*` labels.** Add the `tier:(quick|standard|heavy)` Linear labels to your team if not already present (per v2.6.0 reinstatement). Issues without a tier label default to `standard` — gate behaves as if the issue is opted in to the artifact pipeline.
- **`.gitignore` recommendation.** Add `.pk-work/` only (transient `/work` marker files). `Logs/Verify/` is **intentionally committed** as the per-PR audit trail — the `verify-complete.md` sentinel travels with the merge as evidence that the pre-deploy gate passed at the verified SHA. Retention is the consumer's call (periodic `git rm -r Logs/Verify/<old-date>/` commits work fine).
- **Linear API key required for `pk_linear_tier`.** The gate falls back to `standard` if Linear is unreachable, but the artifact layer requires you to actually call `/verify` to produce `verify-complete.md`. Projects without a Linear key still gate on file presence — they just can't differentiate tiers.
- **`--force` audit trail.** Bypassing the gate via `pk ship --force` posts a Linear comment to the issue: `Shipped without verify-complete.md (--force at <ISO-timestamp>)`. Use sparingly — `pk_linear_comment` is best-effort so an outage won't block the ship.
- **`PK_VERIFY_BYPASS=1`** is the emergency escape, not the daily-driver escape. It bypasses Linear comment writing and only appends to `Logs/Verify/bypass.log`. Reserve for production incident recovery when Linear is also down.

### What's deferred to v2.7.0 stable

- **Week 4: `/pr-fix` full subagent dispatch.** Diff-aware persona dispatch (always-on quartet + conditional security/migration/performance/adversarial), cross-persona promotion (3-line bucket match-key + 25→50→75→100 confidence ladder), severity × autofix matrix with `--quick` remap. `--legacy-flat` escape hatch preserves v2.6 behavior.
- **Project-configurable sensitive-path patterns for `/verify`** — currently hardcoded; future `[verify.sensitive_paths]` block in `method.config.md` would let consumers override the defaults. Deferred to v2.7.1+ along with the analogous `[pr-fix.sensitive_paths]` block.
- **`/02-light-spec-revise` tier re-derive** — currently only `/01-light-spec` runs Phase 3.6. If a revise cycle changes the Complexity field, the `tier:*` label doesn't auto-refresh. v2.7.1 candidate.
- **Phase 2: `/pk-compound` + `resources/solutions/`.** Bug-track first, knowledge-track reassess at month 3.

---

## v2.6.0.1 — 2026-05-24

> **Patch: `pk branch` auto-allows direnv on the worktree.** v2.6.0 #14 added `.envrc` to the symlink loop in `cmd_branch`, but direnv treats the worktree path as a new `.envrc` and blocks it until manually allowed. Symptom: MCP servers and other direnv-loaded tooling still fail to auth at Claude Code launch in fresh worktrees — the exact failure mode #14 was meant to fix. v2.6.0.1 closes the half-broken state by running `direnv allow` on the worktree after the symlink lands.

### What changed

- **`bin/pk` `cmd_branch`** — after the `.envrc` symlink, run `direnv allow "$wt_path"` if `direnv` is on `$PATH`. Fails soft (suppressed via `|| true`) when direnv is missing. The symlink target is the parent's `.envrc` which the user has already `direnv allow`-ed (otherwise direnv wouldn't have loaded in the parent), so the auto-allow doesn't bypass the user's trust decision — it propagates it.

**`PK_VERSION`** 2.6.0 → 2.6.0.1.

### Why

v2.6.0 #14 shipped the `.envrc` symlink to fix MCP auth failures in fresh worktrees launched via `pk branch`. In testing 2026-05-24, the symlink lands correctly but direnv refuses to load it with `error /<worktree>/.envrc is blocked. Run \`direnv allow\` to approve its content`. Net effect: same MCP auth failure mode, one extra manual step (`direnv allow`) to recover. The fix delivered half its value.

The justification for auto-allow: direnv's allow-gate exists to prevent malicious `.envrc` files from being added to a repo without the user's knowledge. The worktree's `.envrc` is not new content — it's a symlink to the parent's `.envrc` which the user has already explicitly allowed. Auto-allowing on the symlink target propagates an existing trust decision rather than bypassing the security model.

### Migration

- **Pin to v2.6.0.1.** Run `./scripts/sync-method.sh v2.6.0.1` from inside your consuming project.
- **Existing fresh worktrees** still need a one-time manual `direnv allow $WT_PATH` to recover (v2.6.0.1's auto-allow only fires on new `pk branch` invocations).
- **direnv not installed?** No-op — `command -v direnv` check skips the auto-allow silently.

---

## v2.6.0 — 2026-05-23

> **Minor: tier system restored + Path 3 reviewer pipeline + two-phase promote + worktree-setup polish.** Twelve candidates landed in one release — the v2.5.0 / v2.5.0.1 cycle's findings plus the 2026-05-17 cmux parallel-native batch (5 WITs / 75 min / 1.5-1.8× speedup) and the 2026-05-18 reviewer-strategy work. Three headline groups: (1) **tier inference** is back in `/work` via Linear `tier:*` labels — closing the config↔code mismatch since v2.0.0; (2) **Path 3 reviewer pipeline** ships — Semgrep + Claude templates, `/pr-fix --from-review` + `--second-opinion=gemini` flags, `pk ship --draft` default + new `pk ready <ID>` command, and the F2 two-phase promote that stops `pk promote` from writing Linear state ~5 minutes ahead of reality; (3) **VBW plan-state finalization** in `pk done` unblocks fresh-worktree batch flows. Plus six smaller items: `.envrc` symlink, `pk branch` auto-install + `--no-install`, `pk done` auto-pull, `pk_promote` silent-exit fix, `sync_file` idempotent, cmux numeric-menu rule.

### What changed

**Tier system reinstatement** (`skills/work/skill.md`)
- **Step 2.6 (new)**: infer tier from Linear `tier:*` labels (defaults to Standard). Surface a Quick → `/06-linear-todo-runner` batch alternative and a Heavy `/strategy-sync`-required warning.
- **Step 3 (Plan)**: Quick forces inline planning (no spec-validator / Explore / vbw-scout subagents even with `--deep`). Heavy forces parallel grounding regardless of `--deep`. Standard unchanged.
- **Step 4 (Verdict)**: Quick uses a single y/N gate — no revision loop. Standard / Heavy keep the 3-revision verdict.
- **Step 6 (Security)**: Quick skips review even with `--deep`. Heavy forces it regardless of `--deep`.
- **Step 7 (Hand-off)**: Heavy appends a `/strategy-sync` reminder before close.
- Semantics match the existing per-tier templates at `templates/tier-{quick,standard,heavy}.md`. The `method.config.template.md` Tiers section was already accurate; the code side now honors it.

**`pk done` writes VBW SUMMARY + flips PLAN status** (`bin/pk`)
- After a confirmed merge, flips `.vbw-planning/phases/<phase>/<phase>-<id>-PLAN.md` frontmatter `status: ready` → `status: complete` (frontmatter-scoped via awk).
- Writes `<phase>-<id>-SUMMARY.md` alongside with PR URL, merge SHA, commits-shipped count, diffstat, close date.
- Prints a commit hint so the user can land the changes when ready.
- Idempotent (re-runs preserve existing SUMMARY; status flip is no-op if already complete). Skips silently when there's no `.vbw-planning/` or no matching PLAN.md.
- Unblocks fresh-worktree edits for batch flows — VBW's file-guard otherwise treats every `status: ready` PLAN.md as in-progress.

**`pk done` auto-pulls integration branch post-merge** (`bin/pk`)
- After confirmed merge, fast-forwards local `dev`/`main` if HEAD is on it; otherwise fetches so the next checkout is current. Divergence warns rather than fails.

**`pk branch` auto-runs lockfile-matched install + `--no-install` opt-out** (`bin/pk`)
- Replaces the F8 fresh-worktree hint (added v2.4.3.3 / 2026-05-14) with the action it suggested. Detects `pnpm` / `yarn` / `npm` from the lockfile, runs install in foreground.
- New `--no-install` flag for cached-deps or spec-only worktrees. Flag surfaces in the "To enter:" output after an install runs so it's discoverable for next time.
- Install failure warns loudly but doesn't return 1 — the worktree, env symlinks, and Linear state are already set up.

**`pk branch` symlinks `.envrc` alongside `.env`** (`bin/pk`)
- Adds `.envrc` to the env-symlink loop in `cmd_branch`. Without it, direnv stays inert in fresh worktrees and MCP servers / other direnv-loaded tooling fail to auth at Claude Code session launch. Existing `-f` guard means non-direnv projects are unaffected.

**`pk promote` no longer silent-exits on commit ranges with no WIT matches** (`bin/pk`)
- The two `git log | grep -oE PREFIX-N` pipelines in `cmd_promote` exited 1 under `set -euo pipefail` when commit ranges contained no issue-prefix matches — killing the script before the `if [ -n "$bundled_ids" ]` check could skip safely. Fixed with `{ grep ... || true; }` scoped to grep, matching the precedent at `bin/pk:528-529`.

**`sync_file` is idempotent on unchanged files** (`scripts/sync-method.sh`)
- Skip `cp` when `diff -q` reports no content change. Prevents the F3 "bin/pk drift in worktrees" symptom and reduces git-status noise on no-op syncs. Side effect: faster sync (no cp for unchanged files).

**cmux numeric-menu discipline** (`.claude/rules/pipekit-cmux.md`)
- Codified pre-v2.6.0 in the canonical rule file (`Never send <digit>\n to a Claude interactive menu` + `Wait 2-3s between send-key enter and the next read-screen`). Listed here for v2.6.0 traceability.

**F2 — `pk promote` two-phase Linear transition** (`bin/pk`)
- Replaces the optimistic-at-PR-open behavior (v2.3.0–v2.5.0) where Linear advanced to `In <Env>` ~5 minutes before the merge landed. Aborted promotes required manual Linear revert.
- **Phase 1**: `pk promote <env>` opens the promote PR. Bundled WITs stay in source-env state. The PR body embeds a `<!-- pipekit-promote-tracking: source=<s> target=<t> wits=<W1,W2,...> -->` marker (stateless, cross-machine — no local state file required).
- **Phase 2**: `pk promote <env> --finish` finds the most recent merged promote PR, parses the marker, transitions each bundled WIT to the target state. Falls back to deriving WITs from PR commits when no marker exists (older PRs).
- Phase 1 prints the exact `--finish` command at the end so the two-step flow is discoverable without docs.

**CI workflow templates** (`templates/ci/`)
- `templates/ci/semgrep.yml` — deterministic outside reviewer (`semgrep ci --config=auto`, free Community Rules, no token required). Triggers on `[opened, ready_for_review]` only — matches Pipekit's Draft-PR lifecycle.
- `templates/ci/claude-review.yml` — semantic outside reviewer via `anthropics/claude-code-action@v1`. Includes a `triage` job (Option B path-filtering per v2.6.0 #5) that skips doc-only PRs (`.md`/`.txt`/`.rst`) and trivial PRs (<5 LOC). Path filtering is intentionally absent — PR #331 evidence showed claude-review caught bugs in non-high-leverage paths that any allowlist would miss.
- `templates/ci/semgrep-rules/uuid-route-params.yml` — starter custom rule flagging dynamic route params flowing into Supabase queries without UUID validation. Deterministic backup for the Piper PR #341 miss (claude-review caught the pattern on PR #331 but missed it on #341).
- `templates/ci/README.md` — documents the Draft-PR lifecycle, `branches:` configuration per tier, custom-rule adoption, and the `/pr-fix` flags below.

**`/pr-fix` — `--from-review` + `--second-opinion=gemini` flags** (`skills/pr-fix/skill.md`)
- `--from-review` — skip Phase 3's fresh review and ingest existing PR review comments (typically from `claude-review.yml` GHA) instead. Maps each comment to a structured finding (file:line + body → severity inference). Default confidence = 85.
- `--second-opinion=gemini` — after Phase 4, invoke `gemini-flash-latest` for a parallel review. Surfaces findings as a separate section, NOT merged into Phase 4 (the point of a second opinion is comparison). Requires `GEMINI_API_KEY`; refuses cleanly without. Documents the thinking-tokens gotcha (`maxOutputTokens=65536`, `thinkingBudget=-1`).
- Flags compose: `/pr-fix --review --from-review --second-opinion=gemini` is valid (reviews-only + ingest GHA + parallel Gemini).

**`pk ship` opens Draft by default + new `pk ready` command** (`bin/pk`)
- `pk ship` now passes `--draft` to `gh pr create` unless `--ready` is set. Outside reviewers (Semgrep + claude-review templates) trigger on `[opened, ready_for_review]` — opening Draft means no review fires during iteration.
- New `pk ready [<ID>]` flips the feature PR from Draft to Ready (`gh pr ready <#>`). No Linear state change. Closes the dead-code gap from Piper PR #330 (`ready_for_review` trigger was wired but nothing in Pipekit fired it).
- `pk ship --ready` opens Ready immediately for one-shot tiny WITs where iteration won't happen.
- `pk_gh_pr_create` helper gained a `--draft` flag (REST `-F draft=true`, gh CLI `--draft`).

**`PK_VERSION`** 2.5.0.1 → 2.6.0.

### Why

This release stacks four motivations:

1. **Tier reinstatement is the headliner.** Empirical anchor: 2026-05-17 cmux parallel-native batch shipped 5 WITs in 75 min wall-clock vs 90-135 min serial (1.5-1.8× speedup), 5/5 clean. WIT-478 PR 1 took 3 hours for one ADR doc under the full gate stack (would be <30 min on Quick). WIT-474 (Production Fee float drift) sat unworked for 2 days as "Quick Win, can slot any time" because no fast lane existed. v2.6.0 closes the config↔code gap and restores the Quick fast lane.
2. **Path 3 reviewer pipeline closes the "no real outside reviewer" gap.** Pre-v2.6.0 consumers ran two Claude reviewers in parallel (GHA + local `/pr-fix`) — convergent perspective, shared blind spots, double credit cost. v2.6.0 ships Semgrep (deterministic, no LLM, free) + Claude (semantic, the empirically-strongest LLM reviewer on Piper PR #331) + opt-in Gemini second-opinion. OpenAI/Microsoft stack disqualified on the IP-absorption pattern (`resources/v2.6.0-candidates.md` § "Why OpenAI/Microsoft are disqualified"), not on quality.
3. **F2 fixes the "Linear ahead of reality" semantic bug.** Pre-v2.6.0 `pk promote` wrote `In <Env>` at PR-open, ~5 minutes before the merge landed. Two-phase (`pk promote` opens; `pk promote --finish` transitions post-merge) trades one extra command for accurate Linear state.
4. **`bin/pk` worktree-setup paper cuts.** `.envrc` symlink (Piper handoff 2026-05-23) and auto-install (v2.4.3.3 F8 follow-through) make fresh worktrees ready-to-use without the human typing the lockfile-install command. `pk done` SUMMARY + PLAN flip unblocks batch flows that were hitting VBW's file-guard wall on every fresh worktree. `pk_promote` silent-exit on RS-Vault 2026-05-15 was a trivial fix with high signal-restoration value.

### Migration

- **Pin to v2.6.0.** Run `./scripts/sync-method.sh v2.6.0` from inside your consuming project.
- **Tier labels in Linear.** To use the new tier behavior, add a `tier:quick`, `tier:standard`, or `tier:heavy` label to your Linear issues. Issues without a `tier:*` label default to **Standard** (current behavior). No action needed for projects that don't want to adopt tiers yet.
- **CI workflow adoption.** Copy `pipekit/templates/ci/semgrep.yml` and `pipekit/templates/ci/claude-review.yml` into `.github/workflows/` and edit the `branches:` list to match your `Ship environments`. `claude-review.yml` requires the `CLAUDE_CODE_OAUTH_TOKEN` repo secret. See `pipekit/templates/ci/README.md` for the full lifecycle doc.
- **Draft-PR flow.** `pk ship` now opens Draft by default. Iterate freely, then `pk ready <WIT-ID>` to fire the outside reviewers at the merge moment. Use `pk ship --ready` if you want the old behavior on a one-shot tiny WIT.
- **Two-phase promote.** `pk promote <env>` opens the PR but no longer writes Linear state. After merge, run `pk promote <env> --finish` to transition WITs to the target state. Phase 1 prints the exact `--finish` command at the end — no docs lookup needed.
- **`pk branch --no-install`.** If your workflow doesn't need a fresh `pnpm install` on every worktree (cached deps, spec-only worktrees), pass `--no-install`. The flag surfaces in the "To enter:" output after the first install runs so it's discoverable.
- **VBW SUMMARY / PLAN-flip commits.** `pk done` now leaves `.vbw-planning/` files modified (SUMMARY written, PLAN status flipped). Commit them with `git add .vbw-planning/ && git commit` to propagate the status to future worktrees. Without the commit, batch workers may still hit the stale-PLAN file-guard wall.

### Knock-on followups (not in this release)

Held for v2.6.x+:

- **#10 — `pk_promote` strict ownership match.** Closing-keyword + commit-title prefix verification. ~3h, defense-in-depth — cuts leap-frog noise.
- **#11 — `/light-spec` two-step placeholder workaround.** Investigate root cause first; may already be moot if upstream fixed it.

Full backlog: `resources/v2.6.0-candidates.md`.

---

## v2.5.0.1 — 2026-05-15

> **Patch: `sync-method.sh` wrong-target bug.** RS-Vault's v2.5.0 migration (Finding #1 in `resources/rs-vault-v2.5.0-migration-followup.md`) surfaced that the sync script resolved its target from the script's own location instead of the consuming project's working directory. Result: invoking `bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0` from outside the pipekit repo silently synced INTO the pipekit repo itself, leaving the consuming project unchanged and dirtying pipekit's working tree with ~20 file rewrites. Recoverable but invisible until you noticed `pk version` still printed the old number.

### What changed

- **`scripts/sync-method.sh`** — `PROJECT_ROOT` now defaults to `${PWD:-$(pwd)}` instead of `$(dirname "$0")/..`. This matches the `cd <project> && bash <pipekit>/scripts/sync-method.sh` invocation pattern documented everywhere. Adds a safety check that compares the target's git origin URL against `METHOD_REPO` and refuses with a clear error message if they match (i.e. the user is about to sync Pipekit into itself). Error message explains both the likely cause (forgot to `cd`) and the recovery paths. Adds a `--target=<path>` flag for explicit override.
- **Constitutional doc stamps (`method.md`, `RUNBOOK.md`, `GUIDE.md`)** — bumped to v2.5.0.1 per the v2.4.3.2 Release Checklist exception.
- **`RUNBOOK.md` sync-example** — `v2.5.0` → `v2.5.0.1`.

**`PK_VERSION`** 2.5.0 → 2.5.0.1.

### Why

Two things this patch achieves:

1. **The documented invocation now works.** Every Pipekit handoff, README, RUNBOOK, and STARTUP example says some variant of `cd ~/Projects/<project> && bash ~/Projects/pipekit/scripts/sync-method.sh v<tag>`. Pre-v2.5.0.1, the `cd` was effectively ignored — `PROJECT_ROOT` was script-relative. v2.5.0.1 honors `$PWD` so the `cd` actually controls where the sync lands.
2. **Self-sync is no longer silent.** If the user *does* forget to `cd` (or invokes from a session that lost its cwd), the script now refuses with `exit 1` and a helpful error rather than chewing through pipekit's own working tree. Detection is structural (git origin URL comparison), not heuristic.

The handoff template (`resources/nebula-rs-vault-pipekit-v2.5.0-handoff.md`) still says `bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0` because that pattern now works correctly post-patch. Older handoffs that say the same thing will Just Work after the consuming project syncs to v2.5.0.1 (their local copy of sync-method.sh updates via the self-update guard on first sync).

### Migration

- **Pin to v2.5.0.1.** Run `./scripts/sync-method.sh v2.5.0.1` from inside your consuming project to pick up the patched script. The self-update guard re-execs with the new logic mid-sync.
- **If you already synced v2.5.0 successfully**, you're fine — the v2.5.0 sync touched the same target files; v2.5.0.1 only changes the *invocation safety*. No re-sync needed unless you want the new safety check locally.
- **If your v2.5.0 sync went into pipekit itself**, recover by: (a) `git status` in pipekit shows the spurious changes, (b) `git checkout .` discards them, (c) cd into your actual consuming project, (d) re-run with v2.5.0.1.

### Knock-on followups (not in this patch)

The RS-Vault migration surfaced four other findings beyond this one. Tracked separately:

- **F2: `pk promote` optimistic Linear write.** Writes terminal state at PR-open, not merge. Documented behavior since v2.3.0 but semantically louder in v2.5.0's env-as-status model. Resolution path TBD — likely either a two-phase transition (`pk promote` opens PR + sets `In <NextEnv>`, then a `--finish` flag or post-merge hook writes terminal) or a `--wait` flag.
- **F3: `bin/pk` drift in fresh worktrees.** `pk install` or sync rewrites `bin/pk` on disk in a way that shows as modified in worktrees pinned to older commits. Cosmetic; workaround is `git checkout -- bin/pk`. Likely fix: only update the user-PATH copy, not the in-tree file.
- **F4: protected-branch consumer projects can't `git push` direct.** Handoff template says `git push` but Piper / RS-Vault / etc. require PR + status checks. Fix: handoff Step 6 should route through a sync PR. Not a code change — handoff template only.
- **F5: extra started-type Linear states unflagged in pre-flight.** rs-vault has `In Progress` + `Building` + `In Dev`; canonical pair assumed. Fix: handoff Step 0c should list all started-type states. Not a code change.

Full RS-Vault findings: `resources/rs-vault-v2.5.0-migration-followup.md`.

---

## v2.5.0 — 2026-05-15

> **Env-as-status.** Linear state names now derive from `Ship environments` chain position: `UAT` (PR open on preview, pre-merge) → `In <FirstEnv>` (e.g. `In Dev` — merged to first env) → `In <Env>` per intermediate hop → `Done` (final env). `Released` retired. `pk done` regains state-transition responsibility (UAT → `In <FirstEnv>`) with optional `--merge` flag to run `gh pr merge` for you. Resolves "tested but still UAT" status headache on multi-tier projects.

### What changed

**`bin/pk`:**

- **`pk_state_rank`** — refactored to compute "In `<env>`" ranks from `Ship environments` chain position (rank 11 + idx). Pre-deploy ranks (Triage through UAT) stay hardcoded; Done = 50 (fixed high). Unknown "In `<x>`" envs return 0 to fall through the leap-frog gate. Replaces v2.3.0's fixed `UAT < Released < Done` ladder which couldn't generalize past 3-tier.
- **`pk_first_env_state_name`** (new helper) — returns `"In <FirstEnv-Capitalized>"` (n-tier) or `"Done"` (1-tier).
- **`pk_env_state_name <env>`** (new helper) — returns `"In <Env-Capitalized>"` for intermediate hops, `"Done"` for the final env, empty string for envs not in the chain.
- **`pk_capitalize`** (new helper) — first-letter capitalization for env names → state names.
- **`cmd_done`** — adds Linear state transition (UAT → `In <FirstEnv>`, or → Done for 1-tier) after the PR-merge check passes. **Drops** the v2.4.3 UAT-state refusal — `pk done` IS the legitimate UAT-out transition now; the PR-merge check is the load-bearing gate. **Adds `--merge` flag** (M3 opt-in) — runs `gh pr merge "$current" --merge` before the merge-verification step, so one command handles the full hand-off. `--confirmed` is still parsed (backward compat) but is a no-op.
- **`cmd_promote`** — target-state mapping now goes through `pk_env_state_name "$target"` instead of position-based `Released` / `Done` binary. Intermediate hops set `In <Env>` (e.g. `In Beta`, `In Staging`); final hop still sets `Done`. UAT-refusal gate retained — still refuses if any bundled issue is in `UAT` (PR not yet merged); `--confirmed` bypasses after env-UAT signoff.
- **`pk_linear_set_state` leap-frog check** — threshold changed from `pk_state_rank Released` (== 11 in v2.4.x, == 0 in v2.5.0 since Released is gone) to a literal `11` (any "In `<env>`" or Done state). Comment updated.
- **`cmd_status`** — now iterates `Ship environments` and shows one bucket per non-final env (`In Dev`, `In Beta`, etc.) alongside the existing `In Progress` / `Building` / `UAT` / `Approved` buckets. Final env (Done) excluded from in-flight view.
- **`cmd_help`** — `pk done`/`pk ship`/`pk promote` descriptions updated; `--merge` flag documented; `--confirmed` deprecation note for `pk done`.

**Docs (rename + flow updates):**

- **`method.md`** — Stage 3+4 narratives rewritten: UAT semantics narrowed to "PR open on preview"; `In <FirstEnv>` introduced; pk done's state transition documented; pk promote rows updated (Released → `In <Env>`); quick-reference tables refreshed.
- **`RUNBOOK.md`** — `[5e]` interactive-UAT box rewritten to reference the two-phase UAT (`UAT` pre-merge, `In Dev` post-merge); `[8]` pk done box updated with state transition + `--merge` flag; `[9]` pk promote box updated (Released → `In <Env>`); cheat-sheet rows refreshed.
- **`README.md`** — Stage 10 pk done description and Stage 11 pk promote description updated.
- **`STARTUP.md`** — header stamp v2.3.0 → v2.5.0; transition-quick-table updated.
- **`GUIDE.md`** — pipeline overview, two-tier/three-tier release flows, status ladder, and command tables updated. PROJ-6 example status changed from UAT to In Dev.
- **`CLAUDE.md`** — header stamp v2.4.3.2 → v2.5.0; v2 daily loop sequence shows the new chain; pk done / pk promote table rows updated.
- **`sop/Linear_SOP.md`** — header stamp v2.4.3.2 → v2.5.0; pipeline diagram + state-meaning table + transitions table + fast-track paths all rewritten for env-as-status.
- **`sop/Git_and_Deployment.md`** — 2-tier and 3-tier transition blocks updated; v2.5.0 UAT-gate note replaces v2.4.3 description.
- **`sop/Skills_SOP.md`** — pk ship / pk done / pk promote rows updated.
- **`skills/linear/skill.md`**, **`skills/startup/skill.md`**, **`skills/pk-exit/skill.md`** — state-name references refreshed; `/startup` now prompts to create `In <FirstEnv>` + `In <Env>` workflow states; `/pk-exit` discipline note explains pk done's new state-transition role.
- **`method.config.template.md`** — 2-tier and 3-tier example Linear-transition blocks rewritten with explicit UAT → `In Dev` → (`In Beta` →) `Done` paths.

**Tests:**

- **`scripts/test-pk-promote.sh`** — pk_state_rank assertions updated for env-derived ranks. Stubs `pk_config` to return `dev,beta,main` so In Dev=11, In Beta=12, Done=50 are deterministic. Pairwise checks now reference `In Dev` and `In Beta` instead of `Released`. 27/27 passing.
- **`scripts/test-pk-v2.4.3.sh`** — Finding 1 (cmd_done UAT-refusal) inverted: now asserts that cmd_done with state==UAT does NOT refuse (proceeds to PR-merge check) and that `--confirmed` is accepted as a no-op. 9/9 passing.

**`PK_VERSION`** 2.4.3.3 → 2.5.0. (v2.4.3.3 landed on origin during the v2.5.0 design session — see v2.4.3.3 section below for its scope.)

### Why

Multi-tier projects (Piper: dev → beta → main) accumulated a UX headache through v2.3.0–v2.4.x: an issue could be tested + signed off in dev but Linear still showed `UAT`, because the only thing that flipped state was `pk promote`. "UAT" reads as "actively being tested" — confusing when testing is complete and the issue is just parked awaiting the next hop.

The fix isn't a deeper state machine; it's matching state names to the physical question "which env is this on?". v2.3.0 already had the state-maps-to-env intuition (CHANGELOG: *"With state mapped 1:1 to environment (UAT = on dev, Released = on beta, Done = on main), Linear's state always reflects reality"*), but `Released` as a single label collapsed every non-final env into one bucket and didn't generalize past 3-tier. v2.5.0 derives per-env state names directly from `Ship environments`, so the status column on a Linear board literally tells you "this is on beta" or "this is on staging" — no ambiguity, no per-project naming guessing.

The split of UAT into two phases (`UAT` = on preview branch pre-merge; `In <FirstEnv>` = on dev post-merge) honestly maps to the two distinct activities that previously shared one label: PR review on the preview URL, vs interactive UAT on the deploy env. `pk done` becomes the legitimate transition between them (it verifies the merge happened, so the In `<FirstEnv>` claim isn't a lie).

### Breaking changes (consumer migration required)

- **Linear workspace states.** Consuming projects must:
  1. Rename existing `Released` state → `In <SecondEnv>` (e.g. `In Beta`). Linear's UUIDs persist across renames so existing issues stay attached.
  2. Add new `In <FirstEnv>` state (e.g. `In Dev`), type `started`, positioned between `UAT` and the renamed-Released.
  3. (Optional) Reclassify currently-`UAT` issues whose PR is already merged → `In <FirstEnv>`.
  4. Pull updated Pipekit via `./scripts/sync-method.sh v2.5.0`.

- **`method.config.md` "Workflow State IDs" table.** Add rows for the new per-env states + capture their UUIDs.

- **`pk done` flag semantics.** `--confirmed` is now a no-op (was: bypass UAT-state refusal). `--merge` is new (opt-in: runs `gh pr merge` before state transition + cleanup). Scripts/skills that passed `--confirmed` to `pk done` will continue to work; the flag is silently accepted.

### Migration runbook (Piper-specific)

Piper is the lead consumer. Steps already partially executed during the v2.5.0 design session (states renamed/added in Linear before this code shipped):

1. ✅ Done (already executed manually): Rename `Released` → `In Beta` in Linear workflow.
2. ✅ Done (already executed manually): Add `In Dev` (type: started) between `UAT` and `In Beta`.
3. **TODO**: Reclassify currently-`UAT` issues whose PR is already merged → `In Dev`. WIT-414 is the known case (PR #279 merged 2026-05-14). Eyeball any other `UAT` issues for PR-merge state.
4. **TODO**: Sync Piper to v2.5.0: `cd ~/Projects/piper && bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0` (or `./scripts/sync-method.sh` for HEAD).
5. **TODO**: Spot-check Piper's `method.config.md` Workflow State IDs table — add UUIDs for `In Dev` and verify `In Beta` UUID matches the renamed state.
6. **TODO**: Smoke test on a sandbox WIT — full chain (`pk branch` → `pk ship` → merge → `pk done` → `pk promote beta` → `pk promote main`).

If steps 1+2 hadn't been done before code shipped: `pk promote beta` would have written to the non-existent `Released` state and gotten "state not found" errors. Recoverable (manual state flip in Linear UI) but messy.

### Conceptual reversal

v2.3.0 deliberately stripped `pk done` of state-transition responsibility ("a worktree closing does not mean the issue is shipped"). v2.5.0 reverses that: pk done sets `In <FirstEnv>`, not `Done`. The v2.3.0 objection doesn't apply — pk done is no longer claiming the issue is shipped, just that it's now on the first deploy env (which is accurate, since pk done verified the merge). State movement is still owned by pk ship + pk done + pk promote collectively; pk done now sits between pk ship (sets UAT) and pk promote (sets per-env / Done).

---

## v2.4.3.3 — 2026-05-14

> **Canary-driven release.** One load-bearing skill behavior change (F6 — `/verify` pauses auto-ship when human-decision flags surface) plus a five-finding doc-polish bundle. All six items surfaced by a live v2.4.3.2 canary against Piper WIT-456 the same day. The canary itself validated v2.4.3.2's headline UAT-gate feature end-to-end (P1, P12, P13) and v2.3.3's skip-backward-transition guard in production (P15). Twelve passing signals total. Full canary log: `Logs/Sessions/2026-05-14_0838.md`.

### What changed

**`/verify` auto-ship now gates on `Pass AND zero flags AND --auto-ship` (F6 — load-bearing).** New Step 3.5 enumerates human-decision flags before the rollover decision:
- Migration files in diff (always pause regardless of QA — migrations are high-stakes and warrant a human eye for irreversibility, RLS, `search_path` review).
- QA verdict Pass with non-"none" Omissions / Scope-creep / Bugs-noticed sub-sections (the subagent classified the work as shippable in aggregate but still flagged items worth surfacing — treat each as a flag).
- User invoked `/verify --qa` (forcing QA signals "I want eyes on it"; auto-ship would contradict the explicit flag).
- `/work` advisory marker file (`.pk-work/<ID>.flags`) present (cross-skill signal — see below).

When `FLAG_COUNT > 0`, auto-ship is forbidden even with `--auto-ship`. The skill surfaces the flag list + three resolution paths (address, accept-and-amend, `/work --resume`), then stops. The auto-chain itself stays — it is a feature when nothing is surfaced. F6 anchor: 2026-05-14 canary verbatim feedback from the user: *"the F6 — /work → /verify → pk ship auto-chain is a feature. The programming should pause on verify if there is ANY Flag for human decision making."*

**`/work` Step 6.5 writes `.pk-work/<ISSUE-ID>.flags` when advisories surface (F6 cross-skill signal).** Triggers: self-reference grep #1/#2/#3 returns a match outside the file just edited, behavioral self-check finds a gap and the work ships anyway with the gap documented, or a documented Risk-fallback was invoked during execution. Marker file is one line per flag, gitignored at `.pk-work/`, consumed by `/verify` Step 3.5, cleaned up automatically when `pk done` removes the worktree. Re-runs of `/work --resume` overwrite the marker rather than appending. Empty markers are forbidden — file existence is the signal.

**`bin/pk pk_config` → `pk config` in `/work` skill (F1).** Replaced 6 invocations in `skills/work/skill.md` (lines 65, 68-71, 79, 504). `pk_config` is an internal shell function inside `bin/pk` reachable only when the binary is *sourced*; the subcommand exposed for skill bodies is `pk config <key> [default]`. The skill body's wrong form crashed the first config read of every `/work` invocation; workers self-recovered by retrying with the correct form, but each crash + retry burned a Bash tool call + LLM cycles. Doc-only fix; no binary change needed.

**`/work` Step 5 gains a "Test command discipline" preamble (F7).** One paragraph instructing executors to use the AC-stated test command verbatim before improvising. Surfaced by 3 retries on WIT-456: `pnpm --filter=@piper/web vitest run <abs-path>` (no such script) → `cd apps/web && pnpm test <abs-path>` (wrong relative path) → finally the AC's literal `pnpm turbo run test --filter=@piper/web`. Each ad-hoc invocation costs ~30s of retry; the AC string is pre-tested.

**`pk branch` emits a fresh-worktree dependency-install hint (F8).** When the new worktree has `package.json` but no `node_modules/`, `pk branch` now ends with:
```
⚠️  Fresh worktree — install deps before first test:
     (cd <wt-path> && <pkg-manager> install)
```
Lockfile detection picks `pnpm install` / `yarn install` / `npm install`. Worktrees inherit tracked files but not gitignored ones; the first test invocation otherwise triggered a multi-minute `pnpm install` while the worker session tried to figure out what was wrong. Surfaced on canary WIT-456 worker session.

**`/pr-fix` Phase 6.6 pre-documents the expected external-action security warning (F10).** Posting a Linear comment from inside `/pr-fix` triggers a generic "external action" security warning because Linear is an external write. The action is sanctioned by the skill (Phase 6.6 is an explicit step), but the harness can't know that — so workers improvised transparency notes per-run. The new preamble in `skills/pr-fix/skill.md` § 6.6 gives the worker the exact line to surface, removing the need to improvise.

**`pk done` + `/pk-exit` ordering hints (F11).** Two non-load-bearing additions:
- `bin/pk done --help` row now appends *"Run from parent repo (not worktree); run /pk-exit inside the worktree session first."*
- `skills/pk-exit/skill.md` frontmatter description now appends *"For worker sessions in a worktree, run /pk-exit before pk done (pk done cleans up the worktree this session lives in, so the log must be written first)."*

The canonical sequence was already documented in RUNBOOK step [7]→[8] and the refuse-table line 435 (`pk done` from worktree → refuses with hint). But experienced users still paused mid-canary to ask "do I run /pk-exit first?" — the join between the two skills was implicit in the flowchart. These hints surface the dependency at each command's own help text.

**`PK_VERSION`** 2.4.3.2 → 2.4.3.3. **`RUNBOOK.md`** sync-example line bumped to `v2.4.3.3`.

### Why

The 2026-05-14 canary against Piper WIT-456 ran the full v2 daily loop end-to-end against the v2.4.3.2 release and validated the headline UAT-gate features in production (PR #276 shipped, `pk done --confirmed` honored UAT bypass, `pk promote beta` refused without `--confirmed` then ran clean with it). In the process, six findings surfaced. F6 is the only behavior change — it was an explicit user methodology decision to keep the auto-chain but make `/verify` itself smarter about pausing. F1/F7/F8/F10/F11 are doc-tier polish that the v2.4.3.2 stamped-docs inventory and drift-check.sh wouldn't have caught (they check stamps and removed-skill references, not command examples vs `bin/pk`'s actual subcommand surface, and not user-friction patterns that show up only mid-loop).

The canary pattern paid off: zero methodology rework, six fixes ready the same day, all anchored to concrete observed behavior rather than speculative cleanup. The canary log is the substantive artifact — read `Logs/Sessions/2026-05-14_0838.md` for the structured P/F findings tally + the moment-by-moment observations.

### Migration

None for consumers already on v2.4.3.2 — F1/F7/F8/F10/F11 are doc-only or hint-only. F6 changes `/verify`'s auto-ship gate: it is strictly *more conservative* (paused chains are easier to recover than over-eager shipping), and the new pause path is the documented expected behavior when a flag is present. Re-run `/pipekit-update v2.4.3.3` or `./scripts/sync-method.sh v2.4.3.3` in consumer projects.

If your project already uses `.pk-work/` for something else, the F6 marker scheme will collide — but `.pk-work/` is a new directory in Pipekit's vocabulary and is unlikely to be in use already. (Pipekit's own `.gitignore` adds the entry.)

---

## v2.4.3.2 — 2026-05-14

> **Doc-polish release.** No code behavior changes. Brings every constitutional doc + SOP into alignment with the v2.4.3 code gate, establishes a stamped-docs inventory + release checklist, and closes drift that accumulated across v2.4.0 through v2.4.3.1.

### What changed

**Stamped-docs inventory (new).** Every top-level doc and SOP now carries a `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(blurb)*` line right after its H1. The version on each stamp is the release the doc is **calibrated to** — when a release modifies a doc, bump its stamp; otherwise leave it alone so the gap between stamped version and current release surfaces drift. 14 docs are covered; the maintained list lives in the Release Checklist section above.

**Release Checklist (new).** Top of `CHANGELOG.md` now carries a checklist that every `chore(release): vX.Y.Z` PR must complete before merging — bump `PK_VERSION`, add CHANGELOG entry, stamp edited docs, update RUNBOOK sync example, ensure PR title carries `vX.Y.Z` for the auto-tag workflow. The root cause this closes: v2.4.0 through v2.4.3.1 all shipped with stale `v2.3.0` header stamps because release PRs edited prose at specific lines without touching the "Last updated" line.

**Content polish across 10 docs.**

- **`method.md`, `RUNBOOK.md`, `GUIDE.md`** — `--confirmed` flag now appears on every `pk done` / `pk promote` row in the daily-loop tables and cheat sheets. `Backend: auto` listed alongside `vbw` / `native` in the config table. Three-layer enforcement model (CLAUDE.md / CI+hooks / skills) called out in method.md Overview. `/strategy-from-code` deferral reworded — was "deferred to v1.4.0" (a version that already shipped 2026-04-27 without the skill); now "deferred; originally promised for v1.4.0 but never built."
- **`CLAUDE.md`** — daily-loop sequence shows the full v2.4.3 chain with `[--confirmed]` modifiers and `pk promote`; `/pk-exit` flagged as manual-invocation-only (never auto-chained from another skill); `Backend: auto` listed; `sop/` list expanded to include all seven SOPs.
- **`README.md`** — `pk done` / `pk promote` rows updated; `/pk-exit` per-session emphasis; versioning example refreshed from `v1.0` to `v2.4.3.2`.
- **`sop/Code_Quality.md`** — stack-agnostic note (was implicitly TypeScript-only); `/verify` named as canonical pre-deploy gate runner.
- **`sop/Git_and_Deployment.md`** — Release Flow now explicitly describes optimistic state transitions at PR-open, the merge as source-of-truth anchor, and the v2.4.3 `--confirmed` gate semantics.
- **`sop/Linear_SOP.md`** — UAT row + transitions reference `--confirmed`; 2-tier clarification that Released state is unused.
- **`sop/Session_Management_SOP.md`** — `/pk-exit` added as explicit session bookend in the session pattern table.
- **`sop/Skills_SOP.md`** — skill-author guidance now says "Dispatch heavy work through `/work`" (which routes to vbw/native/auto backends) rather than "Use VBW agents directly"; `/pipekit-help` usage hint added.

**`PK_VERSION`** 2.4.3.1 → 2.4.3.2.

### Why

The methodology is correct; the docs were lagging. Stamping every doc with its calibration version makes drift legible (you can see a doc is "v2 minor releases behind current" at a glance), and the checklist forces future releases to keep the stamps honest. Cutting v2.4.3.2 instead of leaving the polish on main without a tag lets Piper and other consumers `./scripts/sync-method.sh v2.4.3.2` to pin a known-good doc set.

### Migration

None. Re-run `/pipekit-update` or `./scripts/sync-method.sh v2.4.3.2` in consumer projects. Consumers already on v2.4.3 / v2.4.3.1 see only doc changes (no behavior changes).

---

## v2.4.3.1 — 2026-05-13

> Patch: doc reconciliation for v2.4.3. The v2.4.3 code shipped with `method.md` and `RUNBOOK.md` still describing only the v2.4.2 *prose* UAT gate — neither mentioned that the binary now refuses with `exit 1`. Closes the doc lag.

### What changed

- **`method.md` Stage 3 (line 219)** — Interactive UAT paragraph appended: "v2.4.3 added code-level enforcement as a belt-and-braces backstop: `pk done` and `pk promote` now refuse with `exit 1` when Linear state is `UAT` (or any bundled issue is in `UAT` for `pk promote`). Pass `--confirmed` once UAT is signed off to bypass."
- **`method.md` Stage 4 (lines 236-237)** — `pk done <ID>` and `pk promote <env>` step descriptions updated with the `[--confirmed]` flag and the UAT-refusal clause.
- **`method.md` Tooling table (lines 435-436)** — `pk done <ID> [--confirmed]` and `pk promote <env> [--confirmed]` rows updated.
- **`RUNBOOK.md` `[5e]` box** — extra line: "v2.4.3+ enforces this in code: pk done / pk promote refuse with exit 1 when Linear state is UAT. Pass --confirmed once UAT is signed off to bypass."
- **`PK_VERSION`** 2.4.3 → 2.4.3.1.

### Why

v2.4.3's code-level UAT refusal is the load-bearing change of the day, but the prose docs still implied "this is a discipline rule, not enforced." Users (and AI sessions) reading `method.md` would think the gate is advisory when it now exits 1. Doc rot starts within hours of the code shipping; closing it the same night while the context is fresh.

### Migration

None. Re-run `/pipekit-update v2.4.3.1` in consumer projects (or in the Pipekit clone itself — same command, auto-detects mode).

---

## v2.4.3 — 2026-05-13

> Patch: code-level enforcement of the v2.4.2 UAT-gate doc, plus a `pk install` lag fix surfaced when the v2.3.3 state-ladder gate failed to fire because the user's installed `pk` was at v2.3.2. Five fixes, one bundled PR.

### What changed

- **`bin/pk cmd_done`** — refuses with `exit 1` when the issue is in Linear state `UAT` unless `--confirmed` is passed. v2.4.2's doc gate told future sessions not to chain `pk done` past UAT; this is the belt-and-braces. Doc gates rely on the model reading prose; code gates rely on `exit 1` and don't lie. Anchor: WIT-451 worker session 2026-05-13, where auto-merge → auto `pk done` wiped the worktree mid-UAT.
- **`bin/pk cmd_promote`** — same shape, narrower trigger: refuses when any bundled issue (scanned from `git log <target>..<source>`) is in `UAT`. Released / Done bundles still pass through (re-promote is fine). Approved-or-earlier is already caught by the v2.3.3 ladder leap-frog refusal in `pk_linear_set_state`, so no double-emit. `--confirmed` opt-out.
- **`bin/pk pk_linear_get_state`** — new helper: fetches the current workflow-state name for a Linear issue by identifier. Returns empty string on lookup failure so callers can treat absence as "don't know" rather than aborting. Used by both UAT refusals above.
- **`bin/pk cmd_install`** — `--force` now always re-links, even when the existing target already points at `$src`. Previously the `existing == src` short-circuit returned 0 before `--force` was evaluated, so `pk install --force` was a silent no-op against valid symlinks (anchor: Pendragon 2026-05-13). Reports `Re-linked: …` instead of `Installed: …` when the re-link was forced. Adjacent design question — should `pk install` default to symlinking the global `~/Projects/pipekit/bin/pk` clone instead of the calling project's `bin/pk`? — left for a future cycle; not in scope for v2.4.3.
- **`scripts/sync-method.sh`** — after each sync, compares the synced `bin/pk` content against `~/.local/bin/pk` and `/usr/local/bin/pk` via `cmp -s` (follows symlinks). If they differ, warns with the `pk install --force` remediation. New `--auto-install` flag invokes `pk install --force` automatically post-sync for unattended sync paths (CI, batch scripts). Closes the lag-bug anchor: PR #270 ran the v2.3.3 state-ladder gate code path… except it didn't, because `~/.local/bin/pk` was at `pk 2.3.2` while the synced `bin/pk` was 2.4.2. WIT-275 got falsely transitioned Approved → Done and had to be reverted manually.
- **`sop/Git_and_Deployment.md` § Hotfix Procedure**  — new sub-section "When the explicit beta cherry-pick is needed (three-tier)". The standard three-tier hotfix flow files three branches (`hotfix/*-main`, `*-cherrypick-dev`, `*-cherrypick-beta`), but the explicit beta cherry-pick is redundant when a `dev → beta` promote is imminent — the dev cherry-pick sweeps to beta via the next promote. Filing it anyway leaves an orphan branch. Anchor: WIT-455, 2026-05-13 — `hotfix/margin-cherrypick-beta` orphaned because the dev cherry-pick swept to beta via PR #268 the same day.
- **`scripts/test-pk-v2.4.3.sh`** — new test harness covering: `pk install --force` re-links a valid symlink, `pk_linear_get_state` helper presence, `cmd_done` / `cmd_promote` `--confirmed` arg parsing, and end-to-end UAT-refusal trigger + bypass via a stubbed `pk_linear_get_state`. 9 assertions, network-free (Linear lookups stubbed inside subshells).
- **`bin/pk cmd_help`** — adds `--confirmed` to the `pk done` and `pk promote` synopsis lines.
- **`skills/pipekit-update/skill.md`** — new Phase 0 auto-detects upstream vs downstream mode by `git remote get-url origin` + sentinel files (`method.md` + `CHANGELOG.md` + `bin/pk`). Upstream mode (running inside the Pipekit repo itself) does `git fetch --tags && git checkout <tag>` + `pk install --force`; downstream mode keeps the existing `sync-method.sh` flow. Same `/pipekit-update v2.4.3` command works on both: a machine where `~/.local/bin/pk` symlinks to a consumer project's `bin/pk` AND a machine where it symlinks to the Pipekit clone itself. `--push` refuses in upstream mode (incoherent). Closes the multi-machine update divergence — every machine runs the same incantation.
- **`PK_VERSION`** 2.4.2 → 2.4.3.

### Why

The v2.4.2 doc gate (Stage 3 + RUNBOOK [5e] + `/work`/`pk-exit` "does NOT do") is the right gate for normal use, but the empirical failure mode is an LLM session auto-chaining past prose. Doc gates rely on the model reading and respecting natural language; code gates rely on `exit 1`. Belt-and-braces. The same week the v2.4.2 doc gate landed, the v2.3.3 state-ladder gate (a code gate that DID exist) silently bypassed itself because the user's installed `pk` was old — surfacing the lag-bug that `sync-method.sh` now warns on. Both classes of failure now have explicit code-level guards.

### Migration

None for consumers. Re-run `./scripts/sync-method.sh v2.4.3` in consumer projects. After sync:

- `pk version` returns `2.4.3`
- `pk done <ID>` refuses with a clear message when the issue is in UAT — pass `--confirmed` once UAT is signed off
- `pk promote <env>` refuses when any bundled issue is in UAT — pass `--confirmed` to override
- `pk install --force` always re-links, even on valid symlinks (no more silent no-op)
- `./scripts/sync-method.sh` warns when `~/.local/bin/pk` differs from the synced `bin/pk`; add `--auto-install` for unattended sync

### What this fixes (anchor incidents from 2026-05-13)

- **WIT-451 worker auto-firing `pk done` mid-UAT** → `cmd_done` UAT refusal
- **Same root, narrower** → `cmd_promote` UAT refusal on bundled issues
- **PR #270 / WIT-275 false transition: state-ladder gate didn't fire because installed `pk` was v2.3.2** → `sync-method.sh` install-lag warning + `--auto-install`
- **Pendragon `pk install --force` silent no-op** → `cmd_install` force/symlink fix
- **WIT-455 orphaned `hotfix/margin-cherrypick-beta` branch** → `sop/Git_and_Deployment.md` hotfix nuance

### Tests

```
bash scripts/test-pk-promote.sh   # 25 assertions (v2.3.3 ladder + missing-target guard)
bash scripts/test-pk-config.sh    # 14 assertions (pk_config parsing)
bash scripts/test-pk-v2.4.3.sh    #  9 assertions (v2.4.3 additions)
```

---

## v2.4.2 — 2026-05-13

> Patch: daily-loop discipline polish. Five doc-only fixes from the WIT-451 canary that ran today against Piper. Closes the "implicit UAT gate" and "auto-cascade past UAT" failure modes, plus two `/spec-preflight` Phase 3.6 false-positive reductions and a `/work` rule that auto-files follow-up WITs when a documented Risk-fallback is invoked.

### What changed

- **`method.md` Stage 3 + Stage 4** — Stage 3 renamed "Verify + Ship + UAT" so the UAT step is named, not implied. Adds the gate-clause: `pk done` and `pk promote` MUST NOT run until UAT signs off AND the PR merges. Stage 4 reframes both as "Deliberate human step — must NOT be auto-invoked by `/work`, `/verify`, `/pk-exit`, or any session-automation skill." Both anchor on the WIT-451 canary 2026-05-13 ("the worker session auto-fired `pk done` mid-test and wiped the worktree").
- **`RUNBOOK.md` flowchart** — new explicit `[5e] Interactive UAT` box between PR review and merge, with the no-auto-chain rule inline so future readers don't need to re-derive it from `method.md`.
- **`skills/work/skill.md` "What this skill does NOT do"** — adds two explicit bullets: "No `pk done` invocation, ever" and "No `pk promote` invocation, ever." Names the WIT-451 canary as the anchor incident. Tightens what the worker session is allowed to do at completion.
- **`skills/pk-exit/skill.md`** — new "What this skill does NOT do" section with the same two bullets + "No Linear state writes." Closes the secondary path the worker session could have used to chain past UAT.
- **`skills/work/skill.md` Step 6.5 Risk-fallback follow-up filing** — MANDATORY clause when a documented `R<N>: Mitigation` clause was invoked during implementation. Worker now must (1) identify the deferred scope, (2) `mcp__claude_ai_Linear__save_issue` to file the follow-up WIT in Approved state, (3) reference the new WIT-ID in the hand-off, (4) update parent spec's AC to mark as "partial per R<N>; tracked in <NEW-WIT-ID>". Closes WIT-451's R4 follow-up-rot pattern (dual-field inline NOTE editor only got filed in triage, not at ship time).
- **`skills/spec-preflight/skill.md` Step 3a explicit-NEW marker** — file-paths probe now recognizes `**NEW**`, `(NEW)`, `, NEW`, `(new file)`, "Files to create" section heading, `NEW: <path>` prefix. NEW-marked paths record as `🆕 expected-new` instead of `✗ missing`. Verdict category treats them as `✓`. Eliminates the over-statement false positive on every WIT that legitimately introduces files (WIT-348, WIT-451 each hit this 2-3 times).
- **`skills/spec-preflight/skill.md` Probe 3.6a Strategy-citation downgrade** — Canonical-doc cross-check now scans for inline Strategy citations (`Strategy/Doc<N>`, `Strategy/Doc<N> §<section>`, or an "Authority hierarchy" table naming a Strategy file). If ≥1 inline citation, downgrades `⚠ Cross-check Strategy` → `✓ Canonical docs: cross-check performed in-spec`. Probe still emits `⚠` when POC is mentioned but no inline Strategy citation exists. WIT-451's revised spec was the canonical example that motivated this — fully cited, still drew `⚠`.
- **`PK_VERSION`** 2.4.1 → 2.4.2.

### Why

The WIT-451 canary 2026-05-13 against Piper ran the full v2 daily loop end-to-end and surfaced three procedural gaps. Listed from highest impact down:

1. **No interactive UAT gate.** Stage 3's "Human performs UAT" line was prose-only. The worker session shipped PR #265, auto-merged on green CI, then auto-fired `pk done` and `pk promote beta` in the same ~60-second window while the user was still in the middle of UAT on `dev.withpiper.ai`. The worktree got wiped mid-test. Stage 3 now names UAT as the gate, names `pk done` and `pk promote` as deliberate human steps, and explicitly forbids `/work` and `/pk-exit` from chaining past them.
2. **Worker sessions auto-firing `pk done` / `pk promote`.** Symptom of (1). Both skills now carry explicit "no pk done, ever / no pk promote, ever" bullets that name the anchor incident.
3. **Risk-fallback follow-up rot.** WIT-451's spec documented R4 ("if the dual-field inline cell editor proves brittle, fall back to NOTE-via-modal-only"). The worker correctly invoked the fallback but only filed 2 follow-up WITs, missing the dual-field editor — that one got caught later in triage and became WIT-454. Step 6.5 of `/work` now makes the follow-up filing mandatory when an `R<N>: Mitigation` clause is invoked.

Two adjacent Phase 3.6 probe-polish items also surfaced:

4. **NEW-file false positives.** WIT-348 (3 NEW files) and WIT-451 (3 NEW files) each drew `⚠ File paths: N/M exist (missing: ...)` warnings on paths the spec explicitly marked NEW. Verdict noise that erodes signal.
5. **Strategy-citation false positives on Probe 3.6a.** WIT-451's revised spec cited Strategy/Doc6 §2.1, §3.3, and Doc2 §3.3.1 throughout, with an explicit Authority hierarchy table — and the probe still emitted `⚠ Cross-check spec claims against Strategy` because the trigger fired blindly. Downgrade closes the false positive.

All five are docs-only, low-blast-radius. A deeper code-level guard for (1) and (2) — `pk done` refuses when Linear state is `UAT` and a `--confirmed` flag isn't passed — is deliberately deferred to v2.4.3, after the doc gate has run in practice.

### Migration

None. Re-run `./scripts/sync-method.sh v2.4.2` in consumer projects. After sync:

- `pk version` returns `2.4.2`
- `method.md` Stage 3 / Stage 4 + `RUNBOOK.md` flowchart reflect the named UAT gate
- `/work` and `/pk-exit` carry explicit "no pk done / no pk promote" bullets
- `/spec-preflight` Phase 1 + Probe 3.6a emit fewer false positives on real specs

### What this fixes (canary findings)

- **WIT-451 canary finding "implicit UAT gate"** → method.md Stage 3 + Stage 4 + RUNBOOK.md [5e]
- **WIT-451 canary finding "worker session auto-fired pk done / pk promote"** → /work + /pk-exit "does NOT do" sections
- **WIT-451 canary finding "R-fallback follow-up filed only at triage time"** → /work Step 6.5 mandatory clause
- **WIT-451 + WIT-348 finding "NEW-file false positives"** → /spec-preflight Step 3a
- **WIT-451 finding "Strategy cited inline but probe still warned"** → /spec-preflight Probe 3.6a downgrade

### Deferred to v2.4.3

- Code-level guard in `bin/pk cmd_done`: refuse when Linear state is `UAT` unless `--confirmed` flag passed. Belt-and-suspenders with the v2.4.2 doc gate.
- Same for `cmd_promote` when source-branch issues are still in UAT.

---

## v2.4.1 — 2026-05-13

> Patch: `/linear-todo-runner` creates real worktrees explicitly. Closes the empirically-observed "Agent isolation:`worktree` parameter is a no-op" failure mode where 4 parallel agents collapsed into one shared checkout and trampled each other's uncommitted work via branch switches.

### What changed

- **`skills/06-linear-todo-runner/skill.md` Phase 3 worktree creation** — the orchestrator now runs `git worktree add <path> -b <branch> <BASE>` before each Agent spawn. Worktree path is interpolated into the worker prompt as a concrete value (the Agent tool exposes no `cwd` parameter).
- **Worker first-action verification** — the spawned worker must `cd <WORKTREE_PATH>` then run a 4-way check (`pwd`, `git rev-parse --show-toplevel`, `git rev-parse --abbrev-ref HEAD`, `git worktree list`). Any mismatch halts the worker before any edits and reports the actual output — prompt-level `cd` + verification is now the actual containment mechanism, not optional.
- **Preflight against path/branch collision** — refuses to start a worker if `WORKTREE_PATH` or `BRANCH_NAME` already exist; logs the collision in a Linear comment, moves the issue back to Approved, continues with the next queue item. Eliminates the "blended diff" failure mode where re-runs trampled prior partial work.
- **Phase 4 cleanup asymmetry** — on success, `git worktree remove <path>` clears the worktree (with `--force` documented for cases where the worker leaves untracked files); the branch stays for PR creation. On failure, both the worktree and the branch are preserved for forensic inspection; the user cleans up after triage.
- **Worker prompt template** — outer fence now uses 4 backticks so the inner `` ```bash `` verification block nests cleanly. Worktree path and branch name passed as concrete values, not placeholders.
- **Prerequisites + Related Skills sections updated** — explicitly document that `isolation: "worktree"` is a no-op on current harnesses; runner uses sibling `../<repo>-<id>` worktree paths, distinct from `pk branch`'s in-repo `.worktrees/<ID>-<slug>/` pattern, so the two coexist without fighting over paths.
- **`PK_VERSION`** 2.4.0 → 2.4.1.

### Why

Empirically observed on 2026-05-13 while running `/linear-todo-runner` against rs-vault: 4 parallel agents spawned with `isolation: "worktree"` collapsed into one shared checkout. Sibling branch switches inside that shared checkout silently discarded each other's uncommitted work — the workers produced a "blended diff" where each agent's final state contained fragments of every sibling's work overlaid by the last branch switch.

Root cause: the Agent tool's `isolation: "worktree"` parameter is accepted but does not honor on current harnesses — there's no actual worktree provisioned, just the shared parent cwd that the workers race over. The Agent tool also exposes no `cwd` parameter, so neither path of "containment" the original skill assumed actually exists. The fix moves containment to the orchestrator's pre-spawn `git worktree add` plus a worker prompt that fails loudly when verification doesn't match.

### Migration

None. Re-run `./scripts/sync-method.sh v2.4.1` in consumer projects. After sync:

- `pk version` returns `2.4.1`
- `/linear-todo-runner` creates real worktrees via `git worktree add` before each agent spawn
- Workers refuse to proceed if the 4-way first-action verification doesn't match — preventing the silent-corruption failure mode
- Failed worker runs preserve both the worktree and the branch for forensic inspection (`git worktree remove <path>` and `git branch -D <branch>` are the manual cleanup once triaged); successful runs clean up the worktree but keep the branch for PR creation
- Preflight collision refusal protects against re-running the same queue across leftover worktrees from prior failed runs

### What this fixes (empirical findings)

- **2026-05-13 rs-vault 4-agent collapse** — Agent tool `isolation: "worktree"` parameter is a no-op → orchestrator now creates real worktrees explicitly and the worker verifies before any edits. Memory entry "Agent isolation:'worktree' broken" anchors this in cross-session context.

### Related notes

If you cannot run `git worktree add` from the orchestrator (e.g., the orchestrator's repo state is non-trivial), the skill now documents `--max-agents 1` (sequential) as the safe fallback. Sequential is slower but immune to the parallel-collapse failure mode.

---

## v2.4.0 — 2026-05-13

> Minor: `/spec-preflight` Phase 3.6 — project signal probing. Closes the "environmental blindness" class of bug surfaced by the WIT-348 Gate 3 canary. Four new probes: canonical-doc cross-check, platform capability, tooling availability, migration data shape.

### What changed

- **`skills/spec-preflight/skill.md`** — new Step 3.6 ("Project signal probes") between Steps 3 and 4. Steps 1–3 verify claims the spec explicitly makes; Step 3.6 probes claims the spec implies by referencing a tool, proposing a platform-specific mechanism, drafting a migration, or anchoring to a non-canonical source. Four probes:
  - **3.6a — Canonical-doc cross-check (#21)** — when the spec body references POC and `Strategy docs path` resolves to an existing dir, surfaces Strategy docs + section hints for cross-check. `⚠` warning (ambiguous; human decides).
  - **3.6b — Platform capability (#20)** — detects GUC patterns (`ALTER DATABASE`, `current_setting`, `app.X`). Hard-fails on managed-supabase (the postgres role lacks `SET DATABASE` privilege even as DB owner). Reads new `Platform` V2 key.
  - **3.6c — Tooling availability (#22)** — detects test runner / quality tool names in ACs (Playwright, Cypress, Jest, Vitest, Storybook, Lighthouse, ESLint, Prettier, MSW, Testing Library). Greps repo-root + workspace `package.json` files for the corresponding package names. Hard-fails when AC requires a tool that isn't in `dependencies` or `devDependencies`. Auto-downgrades to warning when the same AC text acknowledges the gap ("to be added", "follow-up", "next phase").
  - **3.6d — Migration data shape (#24)** — scans cited migration SQL for new `CHECK`, `NOT NULL`, type-narrowing, and column renames. Builds inverse-predicate `SELECT COUNT(*)` queries. Executes against the parent project via any bound `mcp__supabase-*__execute_sql` tool (read-only); otherwise surfaces the query templates. `⚠` warning with the violator counts (or templates).
- **`skills/spec-preflight/skill.md` `--accept` flag** — downgrade Phase 3.6 hard-fails (`✗`) to warnings (`⚠`) for accepted-risk cases. Findings still appear; only the blocking verdict softens. Phase 1–3 hard-fails remain blocking (`--accept` does not bypass empirical claim divergence).
- **`skills/spec-preflight/skill.md` verdict block** — now sectioned: "Empirical claims (Phase 1–3)" and "Project signal probes (Phase 3.6)". New output examples include the WIT-348 canary pattern (Strategy cross-check + Playwright tooling miss + migration data-shape probes firing simultaneously).
- **`method.config.template.md`** — new `Platform` V2 key (values: `managed-supabase`, `self-hosted-postgres`, `none`; default `none`). `Migration dir` "Used by" column extended to call out `/spec-preflight` Probe 3.6d.
- **`PK_VERSION`** 2.3.3 → 2.4.0.

### Why

The v2.3.x recovery established that Pipekit had two distinct classes of "trust but never verify" bug. v2.3.2 fixed parser blindness (`pk_config` returned defaults silently); v2.3.3 fixed promote-chain blindness (target branch and Linear ladder). v2.4.0 fixes the remaining class: environmental blindness — the spec is internally coherent and passes the Spec Review Agent, but it references tooling that isn't installed, a platform mechanism the deployment doesn't support, or a column model that contradicts the project's canonical Strategy docs. Every downstream gate (plan-reviewer, `/verify`, QA subagent) reads the spec body as ground truth; none of them re-check spec-vs-reality at the surroundings layer. The Gate 3 canary surfaced all four probe gaps in a single WIT (WIT-348):

- **#21 (Strategy cross-check)** — spec claimed 5 lifecycle date fields with "parity with POC" framing. Strategy/Doc1 §3.1 + Strategy/Doc2 §3.2.3 define **6** fields with engagement-default scoping. Without the canonical-doc probe, `/light-spec` and every downstream gate would have shipped the wrong column set.
- **#22 (Tooling)** — an AC required Playwright; `@playwright/test` was not in `package.json`. The AC was unsatisfiable as written; the `/work` agent had to invent a Vitest substitution mid-execution.
- **#20 (Platform)** — WIT-450's prod-safety mechanism used `ALTER DATABASE postgres SET app.is_prod`; managed Supabase blocked the write with `42501: permission denied` at deploy-time, forcing a redesign to a sentinel-table pattern. The capability mismatch was knowable from the platform fact alone.
- **#24 (Migration data shape)** — per-PR branch DBs run with `with_data: false`, so the migration's chronological `CHECK` constraint passed CI three times. At apply-time against populated piper-dev, 1 row violated `show_end_date <= onsite_end_date` because `end_date → show_end_date` and `wrap_date → onsite_end_date` reversed the natural project-closure ordering.

All four are "the project has the answer; the toolchain didn't apply it." Phase 3.6 puts the probes at the earliest gate (`/spec-preflight`) so the spec author resolves divergence once, before downstream agents lock in.

### Migration

Optional. Re-run `./scripts/sync-method.sh v2.4.0` in consumer projects to pick up the updated `spec-preflight` skill and template. After sync:

- `pk version` returns `2.4.0`
- `/spec-preflight PROJ-XXX` emits a Phase 3.6 section in the verdict block. Probes that don't match the spec content render as `n/a` — projects with no GUC patterns / no Strategy dir / no migrations see the same flow they had pre-v2.4.0 plus four `n/a` lines.
- Optional `Platform: managed-supabase` (or `self-hosted-postgres`) in `method.config.md` enables hard-fails on platform-incompatible GUC designs. Leave blank for projects without DB or with non-Postgres backends.
- `/spec-preflight PROJ-XXX --accept` downgrades Phase 3.6 hard-fails to warnings (for tooling intentionally absent / to be bootstrapped later). Phase 1–3 hard-fails remain blocking.

### What this fixes (loop-notes references)

- **#20** Managed-Supabase blocks GUC parameter writes → Probe 3.6b refuses GUC-based prod-safety designs at spec time (reads `Platform` config key)
- **#21** `/spec-preflight` doesn't cross-check `Strategy/*` canonical docs → Probe 3.6a surfaces Strategy docs + section hints when spec references POC
- **#22** `/spec-preflight` doesn't probe test-runner / tooling availability → Probe 3.6c grep `package.json` for every tool mentioned in an AC; hard-fails when absent
- **#24** Per-PR branch DBs lack production data; migrations pass CI then fail at apply-time → Probe 3.6d scans migration SQL for CHECK/NOT NULL/rename/narrowing, builds inverse-predicate SELECT COUNT(*) queries, runs them via Supabase MCP when bound

### Deferred to future patches

Piper-side infra items (#23 dev migration CI, #26 branch protection, #27 SessionStart `gh auth` hook) are tracked downstream in the Piper repo — they are project-specific operational hardening, not Pipekit upstream changes.

---

## v2.3.3 — 2026-05-13

> Patch: `pk promote` correctness. Refuses when the target branch is missing on origin instead of exiting 128 silently; respects the Linear workflow ladder instead of force-transitioning every bundled WIT to the env's mapped state.

### What changed

- **`bin/pk` `cmd_promote` missing-target guard** — runs `git ls-remote --exit-code origin refs/heads/$target` after target validation. On miss, refuses with an actionable error containing the exact `gh api -X POST repos/<owner>/<repo>/git/refs` recovery command (owner/repo derived from the origin URL). New `--bootstrap` flag auto-recreates the branch at `origin/<source>` tip via `gh api`.
- **`bin/pk` `pk_state_rank`** (new helper) — ranks Linear workflow states along the canonical ladder (`Triage` < `Ideas` < `Future Phases` < `On Deck` < `Needs Spec` < `Specced` < `Approved` < `Building` < `In Progress` < `UAT` < `Released` < `Done`). Unknown states return 0 (preserves current behavior for projects with custom workflows); `Canceled` / `Duplicate` outrank `Done` (never promote forward).
- **`bin/pk` `pk_linear_set_state` ladder gate** — opt-in `mode="advance"` argument. When set, refuses backward transitions (logs "already at <state> (skip backward transition)") and refuses Approved-or-earlier → Released/Done leap-frogs (logs a loud warning to stderr; commits made it into a promote bundle without UAT verification).
- **`bin/pk` `cmd_promote` issue-loop** — passes `"advance"` mode to `pk_linear_set_state`. Bundled WITs only move forward along the ladder; the audit trail stays monotonic across cycles.
- **`scripts/test-pk-promote.sh`** (new) — fixture-based bash harness. Asserts pairwise ladder ordering, unknown-state fallback, terminal-off-ladder behavior, `git ls-remote --exit-code` semantics, and owner/repo extraction from both https and ssh origin URLs. 25 assertions; run with `bash scripts/test-pk-promote.sh`.
- **`PK_VERSION`** 2.3.2 → 2.3.3.

### Why

The v2.3.1 recovery Gate 3 canary (WIT-348, closed 2026-05-13) surfaced 8 new findings. Two were direct regressions of the promote chain that v2.3.2 was supposed to stabilize:

- **#25** — `pk promote beta` exited 128 with zero diagnostic output when `origin/beta` was missing. Root cause: `git fetch origin beta --quiet || true` swallowed the "couldn't find remote ref" message and masked the non-zero exit; the downstream `git log origin/beta..origin/dev` then exited 128 on the unknown revision. Without `bash -x`, the failure mode is essentially undebuggable. (The branch went missing because GitHub's repo-level auto-delete-on-merge removed it when a previous beta→main PR merged — handoff finding #26, fixed Piper-side via branch protection.)
- **#28** — `pk promote beta` force-transitioned every WIT mentioned in commit messages to the env's mapped state, regardless of current Linear state. In the canary, this pulled 3 already-Done WITs backward to Released and leap-frogged 1 Approved WIT straight to Released, skipping Building/In Progress/UAT entirely. Audit-trail integrity loss compounds per cycle — the next `pk promote main` would have force-moved the Released WITs back to Done, producing a "shipped → unreleased → shipped" lifecycle on three issues that never actually un-shipped.

Both regressions fired on the first real canary use. v2.3.2 happened to have `origin/beta` bootstrapped, so #25 (a direct regression of canary 3's loop-note #16) was deprioritized as parallel-track; v2.3.3 folds it in.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.3` in consumer projects. After sync:

- `pk version` returns `2.3.3`
- `pk promote <env>` refuses loudly when the target branch is missing on origin (instead of exiting 128 silently)
- `pk promote <env> --bootstrap` recreates the missing target branch at the source tip via `gh api`
- `pk promote <env>` only transitions Linear issues forward along the workflow ladder; backward and leap-frog attempts log and skip without mutating Linear state
- `bash scripts/test-pk-promote.sh` exits 0 (25 assertions)

### What this fixes (loop-notes references)

- **#25** `pk promote` silent exit 128 on missing target branch → fixed (`git ls-remote` guard + `--bootstrap` flag)
- **#28** `pk promote` force-transitions bundled WITs ignoring Linear state → fixed (ladder gate in `pk_linear_set_state` via opt-in `mode="advance"`)

### Deferred to a future patch

The Gate 3 canary also flagged `/spec-preflight` capability gaps (#20 managed-Supabase GUC probe, #21 canonical `Strategy/` cross-check, #22 test-runner/tooling availability, #24 migration data-shape probe) and three Piper-side infra items (#23 dev migration CI, #26 branch protection, #27 SessionStart `gh auth` hook). The `/spec-preflight` Phase 3.6 capability-probing extension lands in a separate Pipekit PR; the Piper-side items are tracked downstream.

---

## v2.3.2 — 2026-05-12

> Patch: closes the v2.3.1 canary cascade. `pk_config` reads the actual code-block config format; `pk config` subcommand exposed; `/verify` skill stops self-terminating; `pk done` no longer destroys its own CWD.

### What changed

- **`bin/pk` `pk_config` parser** — accepts plain `Key: Value` inside fenced code blocks (the format every consumer actually uses, per `method.config.template.md` lines 162-180) in addition to the legacy markdown-table form. Code-block matched first; table is the fallback. Restores correct values for `Backend`, `Integration branch`, `Ship environments`, `Require QA review`, and every other V2 key.
- **`bin/pk config <key>` subcommand** — added. Plain-value output for `$(pk config K)` substitution. No-arg form dumps all known V2 keys + resolved values. `pk cfg` is an alias. Skills now have one place to read config.
- **`bin/pk` sourceability** — bottom-of-file `main "$@"` guarded with `[ "${BASH_SOURCE[0]}" = "${0}" ]` so test harnesses can `source bin/pk` to exercise helpers directly.
- **`scripts/test-pk-config.sh`** (new) — fixture-based bash harness. Asserts `pk_config` against code-block style (Piper, rs-vault), legacy markdown-table, missing-key + default, and malformed blank-value. 14 assertions; run with `bash scripts/test-pk-config.sh`.
- **`skills/verify/skill.md`** — Step 0 + Step 3b replace the markdown-table `grep` for Integration branch with `pk config "Integration branch"` (one source of truth). Step 2's awk gate-extractor no longer self-terminates: the start regex uses `next` so the end pattern only evaluates on subsequent lines, restoring the bash block extraction that v2.3.1 silently broke.
- **`bin/pk` `cmd_done` worktree refusal** — prefix-matches CWD against the worktree path via `pwd -P`, refusing for *any* nesting level (subdirs included), and runs before posting Linear comments or computing diffs so refused runs leave no side effects.
- **`PK_VERSION`** 2.3.1 → 2.3.2.

### Why

The v2.3.1 canary (WIT-280 in Piper, closed 2026-05-12) surfaced 19 findings. One root cause — `pk_config` matched only markdown-table rows, never the `Key: Value` code-block format documented in `method.config.template.md` — silently returned defaults for every V2 key in every consumer project. `pk promote beta` refused with "not a valid target" because `Ship environments` read as the default `dev,main` instead of Piper's `dev,beta,main`. `Backend: auto` read as `vbw`. `Require QA review: true` read as `false`. `pk ship` and `pk branch` accidentally kept working because `pk_integration_branch` had a separate fallback chain.

Three downstream findings rode the same parser blind spot: `/verify` Step 0's Integration-branch grep (#3) and Step 2's awk gate-extractor (#4) — the awk used `/^## Pre-Deploy Gate/,/^## /` which self-terminated on its own start line, emitting an empty gate. And `pk done`'s late, exact-match CWD check (#13/#14) destroyed the running Claude session's working directory when called from inside the worktree's subdirectories.

This patch closes the cascade plus adds a test harness so the silent-default class of bug cannot recur unnoticed.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.2` in consumer projects. After sync:

- `pk version` returns `2.3.2`
- `pk config Backend` returns the actual configured value (e.g. `auto`) in projects that use the code-block V2-key format
- `pk promote <env>` works for any project with a multi-env `Ship environments` chain
- `pk done` from inside the worktree (or any subdirectory of it) refuses with a clear error instead of destroying the CWD

### What this fixes (loop-notes references)

- **#15** `pk_config` parser blind to code-block format → fixed
- **#2** No `pk config` subcommand → added (with `cfg` alias)
- **#3** `/verify` Step 0 Integration-branch parser → routed through `pk config`
- **#4** `/verify` Step 2 awk self-terminates on start line → corrected (`next` after start match)
- **#13** `pk done` exact-match CWD check skipped subdirs → prefix-match via `pwd -P`
- **#14** `pk done` side-effect ordering destroyed CWD partway through cleanup → refusal moved above side effects

---

## v2.3.1 — 2026-05-09

> Patch: `RUNBOOK.md` is now synced into consumer projects.

### What changed

- **`scripts/sync-method.sh`** — adds `RUNBOOK.md` to the synced doc set alongside `method.md`, `GUIDE.md`, and `STARTUP.md`. Three edits: header comment listing what syncs, `sync_file` invocation, and the post-sync changelog comparison loop. Consumer projects now get `pipekit/RUNBOOK.md` populated and kept up-to-date on each sync.
- **`PK_VERSION`** 2.3.0 → 2.3.1.

### Why

`RUNBOOK.md` exists in pipekit's main repo as the one-page operational doc — the canonical daily-loop flowchart. Until v2.3.1 it was never synced, so consumer projects had `pipekit/method.md` (deep methodology, ~700 lines) and `pipekit/GUIDE.md` (full manual, ~1200 lines) but no one-pager for daily reference. Surfaced during Piper's v2.3.0 sync canary (PR #242 on piper).

`method.md` line 5 self-describes the relationship: "RUNBOOK is the canonical one-page operational doc; this document is the deeper methodology." Both have distinct, non-overlapping roles. Adding RUNBOOK to the sync gives consumers the daily-use surface.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.1` and `pipekit/RUNBOOK.md` lands in your project's `pipekit/` folder.

---

## v2.3.0 — 2026-05-09

> State machine maps 1:1 to environment. New `Released` Linear state for 3-tier projects. `pk promote` walks `Ship environments` one hop per call. `pk done` is cleanup-only.

### What changed

- **`bin/pk` cmd_promote rewritten** (PR #76) — `pk promote <env>` walks `Ship environments` one hop per invocation. Validates target against the chain, derives source from chain position, opens source→target PR, transitions matching issues optimistically at PR-open time. Position-based state mapping: last env in chain → **Done**, any non-final → **Released**. 2-tier backwards-compat: `pk promote` with no arg auto-picks the only hop. Preserves `--stash` / `--take-remote` conflict handling.
- **`bin/pk` cmd_done strip-down** (PR #76) — removed the `pk_linear_set_state ... "Done"` call. `pk done` is now **pure cleanup**: removes worktree, deletes branch, posts commits + diffstat to Linear. State movement is owned entirely by `pk ship` (→ UAT) and `pk promote` (→ Released / → Done). A worktree closing does not mean the issue is shipped.
- **`bin/pk` v2.2.2 fixes folded in** (PR #75) — `pk verify` parser rewrite (awk section-extractor; removes gate-must-be-last constraint and the silent 10-command truncation cap); `pk doctor` Linear error surfacing (parses `userPresentableMessage` / `.message` from GraphQL responses; falls through to truncated body snippet; distinct "no response" branch for network failures); `pk branch` honors `Worktree prefix` from `method.config.md` (defaults to `${root}/.worktrees/`; trailing char in prefix value controls join style).
- **Help text + headers** — `bin/pk` header comment block, `cmd_help` table, and inline `pk` echo strings all updated to reflect new transitions and the `pk promote <env>` target-arg form.
- **`method.config.template.md`** — Released row added to Workflow State IDs table. Two-tier and three-tier release-flow sections rewritten with new transition semantics. (PR #76 + #78.)
- **`sop/Linear_SOP.md`** — pipeline diagrams (Planned + Ad-hoc), state-meaning table, key transitions, and fast-track paths updated to include Released. Explicit note: `pk done` is cleanup-only and does NOT transition state. (PR #76.)
- **`sop/Git_and_Deployment.md`** — Step 5/6 docs use `pk promote <env>` (primary). Linear-transitions lines for both 2-tier and 3-tier rewritten. Pre-deploy gate sub-section updated. (PR #78.)
- **`sop/Skills_SOP.md`** — `pk done` and `pk promote` rows updated. (PR #77.)
- **Constitutional docs aligned** — `method.md`, `RUNBOOK.md`, `GUIDE.md`, `STARTUP.md`: version stamps bumped from v2.1.2 → v2.3.0; pipeline tables, flowcharts, and walkthroughs reflect Released state and the new pk done / pk promote semantics. (PRs #77, #78, #79.)
- **Templates** (`templates/tier-{quick,standard,heavy}.md`) — close-path lines rewritten to reflect cleanup-only `pk done` and target-arg `pk promote <env>`. (PR #78.)
- **Skills updated** — `skills/linear/skill.md` (Phase 4 step 3 documents 2-tier vs 3-tier transitions); `skills/sync-linear/skill.md` (workflow status ladder includes Released); `skills/task-processor/skill.md` (adds Released as a state option); `skills/pr-fix/skill.md` (visibility-gap description includes Released). (PR #78.)
- **`PK_VERSION` 2.1.3 → 2.2.2 → 2.3.0** — caught a pre-existing version drift (PR #75) and bumped through to current.

### Why

The v1 → v2 daily loop validated end-to-end on Piper (May 2026 migration), but two structural problems surfaced during the canary:

1. **`pk done` was 3-tier-blind** — it transitioned issues to Done unconditionally on merge to the integration branch (e.g. `dev`). For 3-tier projects (Piper, any team-with-QA project), this lied about issue status: the code was still on `dev`, awaiting beta and main promotions. Workaround was a manual revert to UAT after every `pk done`. Filed as Loop-Notes finding #6.
2. **`pk promote` was hardcoded single-hop** — opened `--base main --head $integration` directly, skipping any intermediate environments. For 3-tier projects, `pk promote` was effectively a no-op for `dev → beta` and a misuse risk for `dev → main`. Filed as Loop-Notes finding #8.

Both problems share a root cause: the v2 design hadn't fully committed to "state tracks WHERE in the pipeline." With state mapped 1:1 to environment (UAT = on dev, Released = on beta, Done = on main), Linear's state always reflects reality. No more "Done then revert" pingpong on intermediate hops. `pk done`'s pre-v2.3.0 state-transition responsibility evaporates — state movement belongs entirely to `pk ship` (the one transition into the deploy chain) and `pk promote` (each subsequent hop).

This is the load-bearing simplification: `cmd_done` shrinks, `cmd_promote` carries all promotion-state logic, and the contract becomes legible — "the command's invocation is the trigger; state moves at PR-open optimistically; `pk done` is just cleanup."

### What this fixes

- **3-tier `pk done` lying about status** — gone. State stays UAT through any number of intermediate hops; `pk promote main` is the only command that can mark Done.
- **3-tier `pk promote` skipping environments** — gone. `pk promote <env>` walks one hop, validates against `Ship environments`, refuses skip-ahead.
- **State-machine ambiguity** — Linear's state and the deploy reality now diverge only when a promote PR is closed without merging (rare, recoverable by manual state revert).
- **Project portability** — position-based state mapping (last hop → Done, else → Released) means projects can use any env names, not just `dev,beta,main`. `develop,staging,production` works identically.

### What this breaks

**Backwards-compat preserved for 2-tier projects.** `pk promote` with no arg still works there — auto-picks the only hop in `Ship environments`, transitions directly to Done. Released is unused on 2-tier.

**3-tier projects must:**
1. Add a **Released** Linear state (type: `started`) between UAT and Done. Capture the state UUID.
2. Add the UUID to `method.config.md` Workflow State IDs.
3. Switch from `pk promote` (no arg) to explicit `pk promote <env>` invocations.

If a 3-tier project syncs v2.3.0 before adding Released, intermediate `pk promote <env>` calls fail-soft per issue: "Released state not configured — add it via Linear UI + method.config.md, then re-run." Final-hop promotes (`pk promote main` → Done) continue working unchanged.

### Migration

Per consuming project:
1. Add `Released` state via Linear UI (type `started`, position between UAT and Done). Capture state UUID.
2. Update `method.config.md` Workflow State IDs table — add `| Released | <uuid> |` row.
3. Run `./scripts/sync-method.sh v2.3.0`.
4. (3-tier only) Update consumer-side SOPs that reference `/g-promote-*` or single-hop `pk promote` to use `pk promote <env>` form.
5. First canary: `pk promote beta` on the next real Linear issue.

### Cross-references

- PR #75: v2.2.2 — `pk verify` / `pk doctor` / `pk branch` fixes
- PR #76: v2.3.0 — `cmd_promote` rewrite + `cmd_done` strip + Released state
- PR #77: docs alignment pass 1 (constitutional docs + Skills_SOP)
- PR #78: docs alignment pass 2 (Git_and_Deployment + templates + skills)
- PR #79: RUNBOOK final-mile alignment

---

## v2.2.1 — 2026-05-09

> Patch: stop wiping project-local agents on sync.

### What changed

- **`scripts/sync-method.sh` agents sync** — replaced `sync_dir --delete` with per-file `sync_file` over upstream agent files. Project-local agents in `.claude/agents/` (e.g., `code-reviewer.md`, `supabase-reviewer.md`, `{library}-pitfalls.md`) now persist across syncs.

### Why

Surfaced during Piper's v2 canary (PR #235): `rsync --delete` on `.claude/agents/` would have deleted 8 Piper-local agents because upstream pipekit ships only `plan-reviewer.md`. Patched manually in PR #235 by restoring from HEAD; this is the permanent fix. Mirrors the canonical-rules pattern (`README.md`, `pipekit-*.md`), which uses `sync_file` for the same reason — consumers extend `.claude/rules/` and `.claude/agents/` with project-specific files that must survive sync.

### Migration

None. Re-run `./scripts/sync-method.sh v2.2.1` and project-local agents are preserved.

---

## v2.2.0 — 2026-05-09

> Two paired changes: **synced-folder rename** (`method/` → `pipekit/`) and **squash retirement** (merge-commit-only on `main`, squash disabled repo-wide). Breaking changes for consumers — see Migration section.

### What changed — folder rename

- **Sync target folder renamed `method/` → `pipekit/`.** All consumer-side synced content (`sop/`, `templates/`, `method.md`, `GUIDE.md`, `STARTUP.md`, `.sync-changelog.md`) now lands under `pipekit/` instead of `method/`. This Pipekit source repo's layout is unchanged — only the destination path on the consumer side moves.
- **Updated:** `scripts/sync-method.sh` (sync targets, snapshot path, override target paths), `scripts/drift-check.sh` (path filter regex), and all skill docs and templates that reference consumer-side paths (`pipekit-update`, `00-roadmap-review`, `01-light-spec`, `startup`, `templates/overrides-manifest.template.md`, `templates/rules/README.md`, `GUIDE.md`, `README.md`, `method.config.template.md`, `method.md`).
- **Unchanged:** `method.config.md` filename (still at consumer repo root), Pipekit source layout (`sop/`, `templates/`, `method.md` at root of this repo), all override paths under `.claude/overrides/`, `bin/pk`, all skills and agents.

### What changed — merge strategy

- **`scripts/pipekit-configure-repo.sh` rewritten** — repo-level `allow_squash_merge=false`; new `pipekit-main-merge-only` ruleset enforces `allowed_merge_methods=["merge"]` on PRs targeting main. The legacy `pipekit-main-squash-only` ruleset is auto-deleted on re-run.
- **`sop/Git_and_Deployment.md` § Merge Strategy by Hop** — table rewritten. Squash row removed; merge-commit is the enforced strategy for dev → main. Rebase or merge-commit are both fine for feature → dev.
- **`bin/pk` reminders updated** — `pk ship` no longer tells you to squash on main; `pk promote` PR body and prompt updated to "Create a merge commit."
- **`RUNBOOK.md`, `method.md`, `STARTUP.md`, `GUIDE.md`** — all "squash" references updated to reflect the new policy.

### Why — folder rename

`method/` was generic and confusing — both Pipekit and consumer projects used "method" interchangeably, with no signal about ownership. Renaming the synced folder to `pipekit/` makes ownership immediately legible: `pipekit/` is upstream content (don't hand-edit; gets overwritten on sync). Pairs cleanly with whatever the consumer chooses to name its own engineering workspace folder (e.g., `engineering/` for piper, `local/` for rs-vault).

The rename also eliminates a long-standing collision risk for consumers with a pre-existing `method/` folder (notably Piper, which had Piper-flavored v1 method docs there from the era when Pipekit was extracted from Piper). Sync now writes to a fresh `pipekit/` and leaves any pre-existing `method/` alone for manual dissolution.

### Why — merge strategy

v1.7.0 banned merge-commits everywhere. v1.8.0.6 reversed: rebase/merge for feature → dev, squash for dev → main. **Both schemes hit phantom conflicts in production.** Piper's `nebula-piper-migration-handoff.md:282` documents the v1.8.0.6 failure ("GitHub squash ruleset breaks parent linking. Every promote re-conflicts on files added on both sides"); rs-vault hit the identical trap on PR #173 / #175 in May 2026.

The misdiagnosis: prior versions believed "merge-commits on main cause phantom conflicts." Squash on main causes them — by collapsing N atomic dev commits into one orphan commit on main, the next promote's merge-base finds two divergent histories that both modified the same files relative to the common ancestor. Merge-commits prevent the divergence: dev's atomic commits flow onto main with stable SHAs.

The cleanup-via-squash use case (collapse messy WIP commits) doesn't apply: Pipekit's discipline rules already enforce "one atomic change per commit," and vbw-dev makes atomic commits per task. Squash was throwing away useful bisect/blame information for an aesthetic linear-history preference. `git log main --first-parent` gives the squash-equivalent view (one entry per merged PR) without the cost.

### What this fixes

- **Phantom conflicts on `pk promote`** — gone. Same SHAs flow feature → dev → main.
- **`git bisect` and `git blame` on main** — newly useful. Today main is a series of squash-mega-commits attributed to whoever clicked the merge button.
- **`git branch -d` after `pk done`** — would now succeed (latent improvement; `pk done` still uses `-D` for safety).

### Migration (consuming projects)

After `./scripts/sync-method.sh v2.2.0`:

```bash
# 1. Folder rename — sync creates pipekit/ alongside any existing method/.
#    - Verify pipekit/ has the canonical content (sop/, templates/, method.md, etc.).
#    - Move any project-specific content out of method/ to its appropriate home
#      (engineering/, .claude/overrides/, Strategy/_decisions/, etc.).
#    - Re-point references in CLAUDE.md, skills, and docs from method/* to pipekit/*.
#    - rm -rf method/ once empty.
#    - method.config.md filename unchanged — no action needed there.

# 2. Merge strategy — re-run the configure script. It will:
#    - Set allow_squash_merge=false at the repo level
#    - Delete the legacy pipekit-main-squash-only ruleset
#    - Create the new pipekit-main-merge-only ruleset
bash scripts/pipekit-configure-repo.sh
```

If you have an open dev → main PR that's hitting a phantom conflict from the prior squash policy, resolve it once with a merge-commit (or close + reopen as a no-ff merge); subsequent promotes will be clean.

For consumers with extensive `method/` customization, see Piper's worked example at `engineering/Pipekit-Migration-Plan.md` for a phased dissolution approach.

---

## v2.1.2 — 2026-05-03

> Session-log redesign: bash Stop hook retired, narrative `/pk-exit` skill restored.

### What changed

- **`/pk-exit` skill (new)** — writes a narrative session log to `Logs/Sessions/<YYYY-MM-DD>_<HHMM>.md` before `/exit`. Captures summary, commits shipped, decisions/findings, outstanding work, optional QA trail. Restores the v1 `/end-session` artifact shape without the v1 baggage. User runs as the last command of every Claude Code session; no auto-trigger (forget = no log, accepted tradeoff).
- **Bash Stop hook retired (`scripts/pipekit-journal-hook.sh` deleted)** — fired on every assistant turn, dumped duplicate commit-list entries to `.pipekit/journal/<branch>.md`, couldn't write narrative anyway. The per-branch journal cache it produced is no longer used.
- **`pk done` reads commits directly from `git log`** for its Linear close comment (was: read from `.pipekit/journal/<branch>.md`). Same Linear output, simpler source of truth, no cache to drift.
- **`pk log` repointed** at `Logs/Sessions/` — shows the latest session log instead of the per-branch journal cat.
- **`pk init` / `pk doctor`** create/verify `Logs/Sessions/` and flag stale Stop-hook artifacts (`scripts/pipekit-journal-hook.sh`, Stop block in `.claude/settings.json`, `.pipekit/journal/`) so consuming projects can clean up post-upgrade.
- **`templates/v2/settings-snippet.json` deleted** — no Stop hook to wire anymore. `pk init` setup steps reduced from 7 to 6.
- **`method.config.template.md`** drops the `Journal in repo` config key (no longer used).
- **`RUNBOOK.md`** updated end-to-end: setup step removed, flowchart shows `/pk-exit → /exit` as the close-of-session sequence, recovery row covers "forgot to run /pk-exit", v1↔v2 table maps `/end-session → /pk-exit`.

### Why

The v2.0 bash Stop hook was structurally wrong on three axes: (1) Stop fires on *every* assistant turn, producing 4-10 duplicate entries per session with the same commit list — see `chore-v2.0.0-cleanup.md` from 2026-05-02 with identical commit blocks 4 times; (2) bash can't write narrative, so the entry was just `git log -5` repeated, missing the decisions/lessons/QA-trail content that made v1 session logs actually useful; (3) the per-branch journal it wrote was a cache of git log, and `pk done` was the only consumer — repointing at `git log` directly removed the entire cache without losing anything.

The v1 `/end-session` skill's session-log shape (compare `rs-vault/Logs/Sessions/2026-04-26_1555.md` vs `.pipekit/journal/chore-v2.0.0-cleanup.md`) was strictly better as a human archive. `/pk-exit` restores that artifact while keeping the v2 simplifications (no NEXT.md write, no branch-status orchestration — `pk next` and `pk done` own those).

### Migration (consuming projects)

After `./scripts/sync-method.sh v2.1.2`:

```
# Remove the Stop hook block from .claude/settings.json (pk doctor will flag it).
# Delete the retired hook script:
rm scripts/pipekit-journal-hook.sh
# Existing .pipekit/journal/ is gitignored and harmless — dies with branches on `pk done`.
# Run pk doctor to confirm Logs/Sessions/ exists; pk init creates it if not.
```

End every Claude session with `/pk-exit` → `/exit`.

---

## v2.1.1 — 2026-05-02

> Notepad convention: replaces retired v1 NEXT.md.

### What changed

- **`pk init` seeds a gitignored `notepad.md`** if one doesn't already exist, and ensures `.gitignore` excludes it. Free-form personal scratch space; never committed.
- **`.gitignore` (pipekit's own)** adds `notepad.md` for pipekit-side development.
- **`method.md` documents the convention** — NEXT.md is officially retired; consuming projects should delete any committed NEXT.md and rely on `pk next` for canonical "what's next?".
- **`pk init` flags stale NEXT.md** if found, suggesting the cleanup command (does not auto-delete — user's call).

### Why

v1's `NEXT.md` was machine-readable state. v2's `pk next` (phase-aware as of v2.1.0) replaces that role. Consuming projects kept editing `NEXT.md` manually as a personal notepad, which created git-status churn + drift from any auto-source. `notepad.md` (gitignored) is the right shape for that use case.

---

## v2.1.0 — 2026-05-02

> Three improvements surfaced during rs-vault Phase 2.5 execution. Same-day v2.0.0 → v2.1.0.

### What changed

- **`/pr-security-review` skill** (new) — security-focused antagonistic PR review for migrations, RLS policies, SECURITY DEFINER functions, GRANT/REVOKE, auth code, and Server Actions on privileged tables. 30+ rubric items across 6 surface categories. Different from `/security-review` (periodic repo audit) and `/pr-fix` (broad PR review). Surfaced by RS-74 (rs-vault saved_searches migration) where neither existing skill fit the security-focused PR-diff need.
- **Phase-aware `pk next`** — reads `## Current Phase:` from `.vbw-planning/PHASES.md`, matches to `linear-map.json` project entry via `Phase X.Y` prefix (handles em-dash vs colon separator drift), groups Linear results by status: In Progress / Approved / Needs Spec, with per-group next-action hints. Surfaces "Other phases: N Approved outside" footer. Falls back to legacy global behaviour when no phase context is available. Surfaced by Phase 2.5 having 6 Needs Spec issues + RS-63 In Progress while old `pk next` reported nothing.
- **Mid-loop Linear visibility for `pk ship --review` + `/pr-fix`** — `pk ship --review` now posts a Linear comment flagging the review-in-flight; `/pr-fix` Phase 6.6 posts a triage-complete summary with fixed/rejected/deferred counts. Closes the gap where Linear sees `In Progress → UAT → Done` but no record of the review/fix cycle's findings.

### v2.1 backlog still open (deferred to v2.1.x or v2.2)

- `resources/` vs `temp/` portable convention + `pk branch` worktree resource sync
- Cross-spec handoff verification at flowchart level (skill prose already shipped in v2.0; flowchart promotion deferred)
- Visual + functional verification step in flowchart (Playwright + diff infra — too big for same-day cut)
- "Defended status quo" guardrail at flowchart level (already in `/work` prose; flowchart promotion deferred)
- `/ship` skill auto-dispatch (subagent boundary — see `temp/ship-skill-spec.md`)

---

## v2.0.0 — 2026-05-02

> Cut to v2 after RS-63 proved the v2 ↔ VBW handshake on a Heavy spike (rs-vault). v1 daily-loop skills retired to `archive/v1-skills/`. v2 is now the canonical Pipekit.

### What changed at the cut

- **`bin/pk` is the dispatcher.** All daily-loop work goes through `pk next / pk branch / pk ship / pk done / pk promote`. Idempotent against Linear+git ground truth.
- **`/work` + `/verify`** replace the v1 launch chain. `/work --backend=vbw|native` chooses execution backend per-invocation.
- **`RUNBOOK.md`** is now the v2 one-page flowchart (was `V2_RUNBOOK.md`). Old runbooks archived.
- **`method.md`** carries a v2 transition banner; full rewrite queued for v2.0.1.

### v1 retirement (skills moved to `archive/v1-skills/`)

`/branch`, `/launch`, `/launch-native`, `/start-session`, `/end-session`, `/linear-status`, `/g-promote-dev`. All replaced by `pk` subcommands or the Stop hook (journal). Stage 0 skills (`/concept`, `/define`, `/strategy-create`, `/startup`, `/roadmap-create`, `/phase-plan`) and orthogonal skills (`/light-spec`, `/brainstorm`, `/pr-fix`, `/sync-linear`, etc.) are unchanged — v2 only retires the daily loop.

### Validation

- rs-vault Phase 1 closeout (RS-25, RS-30, RS-60, RS-61, RS-62) shipped on the v2 loop
- RS-63 (Phase 2.5 Foundation + Search redesign) — Heavy spike, vbw backend, antagonistic review, /pr-fix triage all worked end-to-end
- DB migration auto-apply workflow (`db-migrate.yml` + `db-pr-check.yml`) shipped, secrets verified via dry-run

### Known gaps (v2.0.1)

- `method.md` still references v1 paths (banner added, rewrite queued)
- `sync-method.sh` may copy v1 skill paths — needs audit
- See `RUNBOOK.md § Backlog` for alpha.15-style improvements that didn't land at the cut: phase-aware `pk next`, `resources/` vs `temp/` portable convention, `/ship` skill auto-dispatch

---

## v2.0.0-alpha — 2026-05-01 → 2026-05-02

> Pre-cut development. 14 alphas across two days. v2/main long-running branch.

### What v2 is

A `pk` shell dispatcher + `/work` and `/verify` skills replace the heavy multi-step v1 launch chain. The daily loop is `pk next → pk branch <ID> → /work <ID> → pk ship → pk done → pk promote`. Idempotent at every step; runs from a worktree.

### Highlights across 13 alphas

- **`bin/pk`** — daily-loop dispatcher (next, status, branch, ship, done, verify, promote, log, doctor, delegate). Idempotent + safe to re-run.
- **`/work`** — plan + execute a Linear issue from inside its worktree. Backend-pluggable (`vbw` | `native`), now overridable per-invocation via `--backend=`.
- **`/verify`** — pre-ship validation skill paired with `pk ship --review` for antagonistic code review.
- **Worktree pk-sync** — `pk branch` copies the parent's `bin/pk` into the worktree so feature work always uses the project's pinned dispatcher version (alpha.12).
- **Stop hook** — `scripts/pipekit-journal-hook.sh` writes a per-feature branch journal on every Claude Code Stop event.
- **Short slugs** — `pk_slug` strips stop words and trims to 3 tokens, keeping worktree paths and status bars sane.
- **REST fallback** — `pk_gh_pr_view` and `pk_gh_pr_create` fall through to GitHub REST when GraphQL is rate-limited (alpha.13). Caught the friction of GraphQL exhaustion silently misreading as "PR not found."
- **Linear robustness** — single-line GraphQL queries, minimal field selections, `.env.local` fallback for the API key, team-name filtering on state transitions.

### Alpha.14 (latest)

- `pk install` global installer — symlinks pk onto `$PATH` (`/usr/local/bin` or `~/.local/bin`); idempotent through the installed symlink
- `pk done` richer Linear comment — commits, diffstat, session count, PR link (replaces raw 50-line journal head dump)
- `pk promote --stash` / `--take-remote` flags — resolve local-edit conflicts with incoming dev (today's friction pattern)

### Alpha.13

- gh REST fallback for `pr view` / `pr create` — initially fallback-only, then **inverted to REST-first** after a session-wide GraphQL exhaustion proved the fallback wasn't enough. REST has its own quota bucket; pk no longer burns GraphQL on normal operation
- `/work --backend=vbw|native` per-invocation override
- Brainstorm skills updated for v2 tier routing (`/brainstorm`, `/brainstorm-review`)
- This consolidated changelog entry

### Carried into beta candidates

- Multi-env `pk ship --env=` for Piper-style multi-environment delivery
- Automated subagent dispatch from `pk ship --review` (currently prints invocation)
- `pk done` richer Linear comments from journal highlights
- `pk install` global installer
- Skills directory reorg: `skills/{loop,stage0,orthogonal}/`
- GitHub Actions `pr-review.yml` (CI-side antagonistic review)

### Notes

- v2 is **not** synced via `sync-method.sh` yet — the script's v2 paths exist but consuming projects pull `bin/pk` and the new skills directly.
- The full v2 design rationale lives in `archive/v2-design-2026-05-01/` (5 design docs from the redesign session).

---

## v1.8.2 — 2026-04-30

### Fixes

Four bugs surfaced in the v1.8 code review (v1.7.0..v1.8.1). All Quick-tier fixes, no behavior changes for the happy path.

- **`/start-session`** — Pre-flight `INTEGRATION` resolver was a literal `$(...)` placeholder. The skill couldn't run end-to-end on a feature worktree. Inlined the same fallback chain `/end-session` Step 0a uses.
- **`/end-session`** — Pre-flight B used a no-op `INTEGRATION="$INTEGRATION"` self-assignment with a forward reference to Step 0a. Inlined the resolver so Pre-flight B is self-contained; Step 0a still refines from `method.config.md` afterward.
- **`/g-promote-dev` Step 3** — Bare `$GATE_CMD` only invoked the first command in an `&&` chain; `&&` became a literal arg. Wrapped in `eval` so the shell parses the chain.
- **`/g-promote-dev` Step 5** — Removed misleading "drop the `-u`" advice. `-u` is idempotent; the actual non-fast-forward case was already documented correctly in the next sentence.

### Filed for v1.9.0

Three issues drafted from the same review, deferred:

- `pipekit-configure-repo.sh` hardening — Rulesets PUT preserves bypass actors, auth/admin precheck, error surfacing
- `/g-promote-dev` Linear-state ownership — three skills now transition the same issue; canonical ownership map needed
- `/launch --auto` refactor — define stalemate overlap precisely, fix Revise default ordering, consider state-machine restructure

Drafts in `temp/issue-v1.9-*.md`.

---

## v1.8.1 — 2026-04-30

### What's New

**`/g-promote-dev` ported from project-local copies into Pipekit.** First skill in the `/g-*` port (v1.8.1–v1.8.5). Eliminates divergence between rs-vault's and piper's project-local copies; bug fixes propagate via `/pipekit-update`.

#### `skills/g-promote-dev/skill.md` (NEW)

Parameterized via `method.config.md`. Reads:

- § Linear → Issue prefix (e.g. `RS`, `PROJ`)
- § Linear → Workflow State IDs → In Progress
- § Git Architecture → Integration branch (`dev`)
- § Pre-Deploy Gate
- § Stack → Hosting (`vercel` | `none`), DB push command (e.g. `supabase db push`), Migration dir, Shared DB across environments

Skips capabilities gracefully when stack values are missing (no Vercel? No DB? Skill still works for the PR-only path).

The migration push step (was hardcoded for rs-vault's shared Supabase) is now config-driven:
- If `DB_PUSH_CMD` empty → skip migration step entirely
- If `SHARED_DB=yes` → warn about forward-mutation, default-no on push prompt
- If `SHARED_DB=no` → default-yes on push prompt (separate dev/prod DBs make this safe)

#### `method.config.template.md` — § Stack section (NEW)

New keys for skill parameterization:

| Key | Used by |
|---|---|
| Hosting (`vercel` \| `none`) | `/g-test-vercel`, `/g-deploy` |
| DB push command | `/g-promote-dev` |
| Migration dir | `/g-promote-dev` |
| Production smoke URL | `/g-deploy` |
| Shared DB across environments (`yes` \| `no`) | `/g-promote-dev` |

### Migration

For rs-vault and other consumers with project-local `/g-promote-dev`:

```bash
./scripts/sync-method.sh v1.8.1
```

Pipekit's parameterized `g-promote-dev` will replace the project-local copy. Before running, verify your `method.config.md` has:
- § Linear → Issue prefix ✓
- § Linear → State IDs → In Progress ✓
- § Pre-Deploy Gate ✓
- § Stack section populated (NEW — copy from `method.config.template.md`)

For rs-vault specifically: Stack section should set `Hosting=vercel`, `DB push command=supabase db push`, `Migration dir=supabase/migrations/`, `Shared DB across environments=yes` to preserve current behavior.

If you need to keep the project-local version (e.g. piper hasn't migrated yet), place it at `.claude/overrides/skills/g-promote-dev/skill.md` — sync-method.sh will preserve the override.

### Open items deferred to v1.8.2 – v1.8.5

- v1.8.2: `/g-promote-main` port
- v1.8.3: `/g-test-vercel` port
- v1.8.4: `/g-deploy` port
- v1.8.5: `/g-promote-beta` port (three-tier flows; piper-relevant)

---

## v1.8.0.6 — 2026-04-30 (patch)

### What changed

**Per-branch merge enforcement via GitHub Rulesets.** Earlier patches (v1.7.0–v1.8.0.5) disallowed merge-commits at the repo level to prevent the phantom-conflict trap on `main`. That's machine-safe but blunt — also bans merge bubbles on `dev`, which some users prefer for feature-branch readability in GitKraken / git-log.

v1.8.0.6 switches to per-branch enforcement:

- **Repo level**: all three merge methods enabled (rebase + squash + merge-commit).
- **`pipekit-main-squash-only` ruleset**: enforces squash-only on `main`. UI dropdown will only show "Squash and merge" for PRs targeting main.
- **Net effect**: feature → dev gets the user's choice (rebase or merge-commit). dev → main is squash, machine-enforced. Mistakes on the dangerous hop are impossible.

`scripts/pipekit-configure-repo.sh` extended to handle both — repo-flag PATCH plus ruleset create-or-update via `POST/PUT /repos/<org>/<repo>/rulesets`. Idempotent. The ruleset name is `pipekit-main-squash-only` so re-runs find and update the existing rule rather than creating duplicates.

### Touched

- `scripts/pipekit-configure-repo.sh` — full rewrite. 2 steps: repo-level flags + ruleset.
- `RUNBOOK.md` § One-time setup — updated table; recommends rulesets-based config.
- `sop/Git_and_Deployment.md` § Merge Strategy by Hop — explains the per-branch model + why the change.

### Migration

`./scripts/sync-method.sh v1.8.0.6` then `bash scripts/pipekit-configure-repo.sh <org>/<repo>`. The script will:
1. Re-enable `allow_merge_commit` at the repo level (was disabled by v1.7.0–v1.8.0.5).
2. Create the `pipekit-main-squash-only` ruleset.

If you want to keep the v1.8.0.5 behavior (merge-commits disallowed globally), just don't run the configure script.

---

## v1.8.0.5 — 2026-04-30 (patch)

### What changed

**`/branch finish` clarified — accepts explicit slug arg, auto-detects merged worktrees.** Live RS-59 observation: RUNBOOK step 13 said "exit + /branch finish" but didn't make clear that /branch finish runs from the parent repo (not from inside the worktree being removed), and the skill itself didn't define how it would identify the right worktree if multiple existed.

This patch:

- **`skills/branch/skill.md`** — Finish subcommand now documents the run-from-parent contract explicitly and adds a 3-tier resolution algorithm: (1) explicit slug arg matches a worktree path; (2) running from inside a worktree errors with a clear "exit and re-run from parent" message; (3) no-arg in parent auto-detects merged-on-origin worktrees, confirms the unambiguous one, or asks user to pick from multiple.
- **`RUNBOOK.md`** — step 13 split into Part A (exit) + Part B (cd to parent, run /branch finish). Notes that squash-merge breaks `git branch -d`'s ancestry check; `-D` is the correct response.

### Migration

`./scripts/sync-method.sh v1.8.0.5`. Pure documentation + skill-prose change; no behavior change unless you were relying on `/branch finish` running from inside the worktree (which fails today regardless).

---

## v1.8.0.4 — 2026-04-30 (patch)

### What changed

**QA-Pass default is now `pause-for-end-session`, not `close-now`.** Live RS-59 observation: /launch --auto's QA-Pass prompt still recommended `close` as the default action, which routes through the v1.7.0 cherry-pick path and defeats v1.8.0's "one PR per issue" model.

The recommended flow on QA Pass is:

1. `pause-for-end-session` (new default) — exit cleanly so the user can run `/end-session` (writes log + NEXT.md to the feature branch), then `/launch --close` (opens the single bundled PR). One PR. No cherry-pick.
2. `close-now` (legacy, preserved) — old v1.7.0 behavior; closes immediately, requires cherry-pick of the session log later.

Touched: `skills/launch/skill.md` auto-chain mode step 6 prose. Fail/Partial defaults unchanged (`pause-here`).

### Migration

`./scripts/sync-method.sh v1.8.0.4`. No breaking changes — `close-now` is still available for users who prefer the v1.7.0 flow.

---

## v1.8.0.3 — 2026-04-30 (patch)

### What changed

**`/launch --auto` no longer auto-advances on Revise.** Live RS-21 observation: plan-reviewer returned Revise, Lead applied the fixes, and `--auto` proceeded straight to Dev — without re-spawning plan-reviewer to validate the revised plan. The user did not approve skipping re-review. The "verdict gate" was effectively a no-op for Revise.

Root cause: skills/launch/skill.md treated Revise as a soft-pass — `proceed on Pass / Revise; abort on Block`. That's wrong. Revise's whole purpose is "fix and re-review."

v1.8.0.3 implements round-2 plan-review on Revise:

1. Round 1 Revise → spawn Lead to apply blocking fixes
2. **Re-spawn plan-reviewer with the revised PLAN.md (NEW)**
3. Round-2 verdict: Pass → Dev; Revise → loop to round 3; Block → abort
4. **Stalemate detection at round 3+**: if round 3's Revise verdict overlaps with round 2's blocking items, pause and surface to user. No auto-loop on round 4.

An explicit override `proceed-without-re-review` exists for the rare case where the user genuinely wants to skip re-review. The override is logged to the pipeline state file (`override: "skip-plan-review-round-2"`).

### Touched

- `skills/launch/skill.md` — auto-chain mode step 3 expanded with round-2 logic; "proceed on Pass / Revise" wording removed in 3 places
- `RUNBOOK.md` — plan-review verdict decision-point table updated with new defaults

### Migration

`./scripts/sync-method.sh v1.8.0.3`. No behavior change in Pass or Block paths. Revise now defaults to `apply-fixes-and-re-review` instead of `proceed`. If you rely on the old soft-pass behavior, use the explicit `proceed-without-re-review` option.

---

## v1.8.0.2 — 2026-04-30 (patch)

### What changed

**Default `/launch` recommendations to `--auto`.** Live test on RS-21 surfaced that /start-session offered "say `/launch RS-21` (or `go` and I'll fire it)" — without `--auto`. The bare form skips the auto-chain orchestration that's the whole point of v1.6.0+. Default should match the canonical Standard-tier path.

Three skill prose updates:

- **`/start-session`** — new step 9 explicitly offers the next command in `--auto` form (Standard tier). Tier handling: Standard → `--auto`, Heavy → plain `/launch` (since `--auto` rejects Heavy), Quick → `/06-linear-todo-runner`.
- **`/end-session`** — NEXT.md recompute writes `/launch RS-XX --auto` instead of bare `/launch RS-XX`. Same tier exceptions.
- **`/launch --close`** — close-time NEXT.md logic emits `/launch {next issue} --auto`. Same tier exceptions.

### Migration

`./scripts/sync-method.sh v1.8.0.2`. No behavior change in the auto-chain itself; only what gets recommended in NEXT.md and what /start-session offers to fire.

---

## v1.8.0.1 — 2026-04-30 (patch)

### What changed

**`/start-session` paired with `/end-session` inside the worktree.** v1.8.0 left an asymmetry: /start-session ran in the parent on dev, /end-session ran in the worktree on the feature branch. They didn't bracket the same scope, and /start-session's NEXT.md view could go stale before the user even got to the worktree.

v1.8.0.1 moves /start-session into the worktree as the kickoff command (after `/branch` and entering the worktree). It now refreshes NEXT.md from `origin/<integration>` tip the same way /end-session does — so both ends of the session see current state.

The parent-on-dev case is preserved: /start-session still works there as a "what should I work on?" view (no refresh, since you're already on integration). The pre-flight only triggers on a feature branch.

### Touched

- `skills/start-session/skill.md` — Pre-flight section added (NEXT.md refresh on feature branch; pass-through on integration)
- `RUNBOOK.md` — loop reordered to 13 steps. Step 0 is now lightweight issue-picking in parent; step 3 is /start-session in worktree (paired with step 9's /end-session). Quick Index TOC updated. Decision tree updated to show the parent/worktree boundary clearly.

### Migration

`./scripts/sync-method.sh v1.8.0.1` pulls the updated /start-session + RUNBOOK. No breaking changes — old order still works, but the new one pairs cleanly.

---

## v1.8.0 — 2026-04-30

### What's New

**One-PR-per-issue release.** Three coupled fixes that close the cherry-pick friction observed during RS-22 work and tighten the per-issue loop. Closes #15, #16, #17.

#### `/end-session` re-orders before `/launch --close` (closes #15)

The biggest day-to-day friction in v1.6.0/v1.7.0: /end-session ran *after* /launch --close, so the session log + NEXT.md update landed on a feature branch *after* PR merge — orphaned unless cherry-picked. The runbook documented a workaround that cost one extra PR (5-min gate-check tax) per issue.

v1.8.0 reverses the order: **/end-session runs first, /launch --close second.** Both inside the worktree, on the feature branch. The session log + NEXT.md update commit to the feature branch *before* the PR opens; /launch --close then bundles everything into the single PR. **One PR per issue. No cherry-pick.**

Two coupled changes inside /end-session:

1. **Integration-branch refusal.** /end-session refuses to run if the current branch is `dev` or `main`. Pre-flight A added; clear error message points to RUNBOOK.md § The loop step 10. Prevents accidental direct-to-integration writes.
2. **NEXT.md base refresh.** Inside the feature worktree, NEXT.md is a snapshot from when `/branch` ran. If a parallel session has shipped to dev since, the snapshot is stale. Pre-flight B fetches `origin/<integration>` and `git checkout`s NEXT.md to the current dev tip *before* recomputing. Race window shrinks from "hours of work in worktree" to "minutes between /end-session and PR merge."

#### Short branch names from `/branch --linear` (closes #16)

`/branch --linear RS-21` used to produce `feature/ethan/rs-21-record-edit-delete-with-change-tracking` (40+ chars, awkward in TUIs and PR titles, derived from Linear's verbose `gitBranchName`).

v1.8.0 derives a short slug from the Linear title: **`feature/RS-21-edit-delete`** (issue ID + 2-3 meaningful words). Algorithm is deterministic — same Linear title always yields the same slug. Stopwords (`with`, `and`, `the`, `for`, `of`, `to`, `in`, `on`, `a`, `an`, `change`, `tracking`, `record`) are stripped before picking the first 2-3 words.

The printed spawn hint also updates: `cd .worktrees/<branch> && claude --dangerously-skip-permissions` — saves a manual flag every time.

#### Recommended merge strategy: rebase feature→dev, squash dev→main (closes #17)

Squash-merging *everything* (v1.7.0's recommendation) flattens atomic per-task commits on dev — unreadable in GitKraken/git-log, useless for `git blame` per task, breaks `git bisect`. Squash-merging dev → main is correct (kills phantom-conflict topology), but feature → dev should preserve atomic commits.

v1.8.0 documents the right combination:

| Hop | Strategy |
|---|---|
| feature/* → dev | **Rebase** (preserves atomic commits as a linear sequence) |
| dev → main | **Squash** (one release commit; kills merge-commit topology) |
| Anything → merge-commit | **Disabled** (creates phantom conflicts on subsequent promotes) |

New `scripts/pipekit-configure-repo.sh` flips all four GitHub repo settings idempotently in one shot:

```bash
bash scripts/pipekit-configure-repo.sh <org>/<repo>
```

Updated: `RUNBOOK.md` § One-time setup, `sop/Git_and_Deployment.md` § Merge Strategy by Hop. The actual flip is per-consumer (Pipekit doesn't enforce repo settings — it recommends).

### Migration

For consuming projects on v1.7.0:

1. `./scripts/sync-method.sh v1.8.0` — pulls updated `/branch`, `/end-session`, `/launch` skills, `Git_and_Deployment.md`, `RUNBOOK.md`, and the new `scripts/pipekit-configure-repo.sh` helper.
2. **Configure your repo's merge strategy:**
   ```bash
   bash scripts/pipekit-configure-repo.sh <org>/<repo>
   ```
3. **New per-issue loop** — see `RUNBOOK.md` § The loop. The order is now: `/end-session` → `/launch --close` → rebase-merge PR → `/branch finish`. The cherry-pick workaround documented in v1.7.0 is removed.
4. No config / template / state-ID changes. Old per-issue flow (`/launch --close` first, /end-session after, cherry-pick log) still works if invoked in that order — but strongly prefer the new order.

### Open items deferred to v1.8.1

- **Port `/g-promote-dev`, `/g-promote-main`, `/g-test-vercel`, `/g-deploy`, `/g-promote-beta`** from rs-vault/piper into Pipekit with parameterization via `method.config.md`. Currently these are project-local copies, diverged between consumers. Folding them into Pipekit closes the per-issue + promotion loop end-to-end.

### Open items deferred to v1.9.0

- `/pipekit-resume` — state-file consumer for cross-session resumption (carried forward).
- Diagnostic gate output (no more bare `REMEDIATION_REQUIRED`).
- Orchestrator-side permission-denial detection (carried since v1.4.0).

---

## v1.7.0 — 2026-04-30

### What's New

**Bug-fix release closing the silent-drop gap left in v1.6.0.** Single observation from rs-vault RS-22 (real-time, 2026-04-29 → 2026-04-30) drove the whole release: the v1.6.0 NEXT.md defer mechanism only worked for non-VBW-scoped writers, exactly the case it was *not* meant to fix.

#### Pipekit machine-local state moved out of repo (closes #13)

v1.6.0 placed the deferred-NEXT.md queue and pipeline-state records inside the repo at `<repo>/.pipekit/`. VBW's file-guard hook blocks any in-repo write that isn't in the active plan's `files_modified` field. The queue file written to dodge the original block hit the same wall — net result: continued silent audit-trail loss, just one level deeper.

The fix: relocate Pipekit's machine-local state to `${XDG_CACHE_HOME:-~/.cache}/pipekit/<repo-basename>/`, resolved consistently by the new `scripts/pipekit-state-dir.sh` helper. VBW's file-guard never inspects paths outside the repo, so writes succeed unconditionally — no more best-effort, no more silent drops.

```bash
# Resolve the path
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)

# Pipekit's directory layout (per consuming project):
#   ${XDG_CACHE_HOME:-~/.cache}/pipekit/<repo-basename>/
#     ├── pending-next-md.json     (NEXT.md defer queue)
#     ├── pending-strategy-sync    (post-archive marker)
#     └── pipeline-state/<issue-id>.json
```

Touched: `sop/Skills_SOP.md`, `method.md`, `VBW_COMMANDS.md`, `templates/tier-heavy.md`, seven skills (`/review-plan`, `/launch`, `/end-session`, `/06-linear-todo-runner`, `/start-session`, `/10-strategy-sync`, `/pipekit-help`), `scripts/pipekit-post-archive.sh` (with inline fallback for mid-upgrade safety), `scripts/verify-next-md-defer.sh` (asserts STATE_DIR is outside repo). The verify script's round-trip dogfood passes against the new path.

#### Sync script reliability fixes

- `--dry-run` now survives the self-update re-exec path (prior shift-based parser silently dropped the flag) — `fix(sync): preserve --dry-run across self-update re-exec` (47e0f9d).
- `diff -rq` exit-1-on-difference no longer kills `--dry-run` under `set -o pipefail` — `fix(sync): tolerate diff -rq exit 1 in --dry-run pipelines` (2b400ef).

These two latent bugs surfaced once `--dry-run` actually started running.

#### Repo URL update

Pipekit moved from `ethan-piper/pipekit` to `withpiper/pipekit`. Updated `METHOD_REPO` default, README/GUIDE/STARTUP install instructions, and `/pipekit-update` + `/startup` curl URLs (417c266). Old URL still redirects, so existing consumers don't break — but pin to v1.7.0+ to pick up the canonical reference.

### Migration

For consuming projects on v1.6.0:

1. `./scripts/sync-method.sh v1.7.0` — pulls updated skills, SOPs, the new `scripts/pipekit-state-dir.sh` helper, and the relocated `verify-next-md-defer.sh`.
2. **One-shot move existing state out of repo** (skip if `.pipekit/` is empty or absent):
   ```bash
   STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
   mkdir -p "$STATE_DIR"
   mv .pipekit/* "$STATE_DIR/" 2>/dev/null
   rmdir .pipekit 2>/dev/null
   ```
   Files are ephemeral; a clean wipe (`rm -rf .pipekit`) is also fine — queue and state files self-recreate on next write.
3. Optionally remove `.pipekit/` from `.gitignore` — Pipekit no longer writes there. Harmless to leave.
4. No config / template / state-ID changes. No breaking API changes.

### Open items deferred to v1.8.0

- `/pipekit-resume` — state-file consumer skill for cross-session resumption (carried forward from v1.6.0/v1.7.0).
- Orchestrator-side permission-denial detection (carried forward from v1.4.0).
- /end-session writes session log onto the merged feature branch (orphan unless cherry-picked) — friction observation from RS-19 + RS-22 closes; right fix is for /end-session to write to integration directly.

---

## v1.6.0 — 2026-04-29

### What's New

**Workflow-friction release.** Two issues closing observations from rs-vault RS-19 (real-time, 2026-04-29). Together they cut per-issue Standard-tier human input count from 6+ down to 3, while fixing a silent audit-trail loss at the Pipekit/VBW boundary. Order matters: #12 ships first because reliable NEXT.md and state-file writes are the substrate #11 builds on.

#### `/launch --auto` auto-chains non-decision pipeline transitions (closes #11)

New `--auto` flag on `/launch` (Standard tier only) orchestrates the full pipeline — `vbw:vbw-lead` → `plan-reviewer` → `vbw:vbw-dev` → `vbw:vbw-qa` → `--close` — pausing only at the two real decision points: the plan-review verdict and the QA verdict. Total human inputs drop from 6+ command re-types (per stage) to 3 (tier confirm + plan-review verdict + QA verdict). The actual cost reduction isn't keystrokes — it's the 5–120 minute resumption tax when the user walks away mid-pipeline and has to context-load on return.

```
/launch RS-19 --auto    # Standard tier
/launch RS-19           # unchanged — manual chaining still supported
```

Each pipeline stage runs as a **fresh Task-spawned subagent**, so the fresh-chat discipline (`method.md` § Fresh-Chat Discipline) is preserved by construction: the orchestrator's conversation context never bleeds into Lead, plan-reviewer, Dev, or QA reasoning. Agents see prior stage output as documents (PLAN.md, REVIEW.md, VERIFICATION.md), not as recalled conversation. This is the load-bearing constraint — no plan-review skip on "trivial" plans, no QA skip on "low-risk" specs. Auto-chain reduces transition friction; it does not lower the gate bar.

Tier handling: Quick → delegates to `/linear-todo-runner` (already auto-chained); Standard → runs the orchestration; Heavy → rejected with a clear message (security review + mandatory `/strategy-sync` gates intentionally human-paced). Permission-denial protocol from v1.4.0 is carried into the spawned Dev task description so hook-driven blocks surface immediately rather than burning turns.

#### NEXT.md write defers under VBW active-plan scope (closes #12)

Real-time observation during rs-vault RS-19's plan-review: VBW's file-guard hook blocked `/review-plan`'s `NEXT.md` write because NEXT.md was not in the active plan's `files_modified` field. The verdict was delivered correctly above the hook error; the audit-trail write was lost silently. Per `method.md` § VBW / Pipekit Ownership Model, NEXT.md is unambiguously Pipekit's — but VBW's hook can't tell that.

The fix (Option A in #12, Pipekit-side, ships in v1.6.0): Pipekit skills that update NEXT.md inside potential VBW-scoped contexts (`/review-plan`, `/launch --close` mid-session, etc.) now run a deferral check. If active-plan scope is detected and NEXT.md is not whitelisted in the plan's `files_modified`, the write is queued to `.pipekit/pending-next-md.json` instead. `/end-session` applies the queue atomically on next session-end, then deletes the queue file (no persistent cruft, per AC).

The inline `➜ Next:` line is **not** deferred — the user still sees their next-command in terminal output of the current skill. Only the file write defers. If/when VBW lands an upstream `always_allow` allowlist for the file-guard hook (Option B in #12, parallel track), the queue mechanism becomes redundant but does not break — both paths coexist gracefully.

A new helper, `scripts/verify-next-md-defer.sh`, dogfoods the round-trip end-to-end against an ephemeral fake project tree. Re-run after any future edit to the deferral mechanism.

#### Pipeline state file (supports `--auto` and future resumption)

Pipeline skills (`/launch` open + `--close`, `/review-plan`, `/linear-todo-runner`) now write a small JSON record to `.pipekit/pipeline-state/<issue-id>.json` at each meaningful state transition: `stage`, `verdict`, `next_command`, `cwd`, `timestamp`. Schema documented in `sop/Skills_SOP.md` § Pipeline state file. Consumed by `/launch --auto` for chain-progress tracking; the state-file writes lay the substrate for `/pipekit-resume` (deferred to v1.7.0) to recover cross-session.

State-file writes that hit a hook block during VBW active-plan scope are best-effort — skip silently rather than failing the skill. The orchestrator reconstructs from VBW state where needed.

### Migration

For consuming projects on v1.5.0:

1. `./scripts/sync-method.sh v1.6.0` — pulls updated `launch`, `review-plan`, `end-session`, `06-linear-todo-runner` skills, plus `Skills_SOP.md`, `method.md`, and the new `scripts/verify-next-md-defer.sh` helper. The new `.pipekit/pipeline-state/` directory is created lazily on first write — no upfront scaffold needed.
2. **Add `.pipekit/` to `.gitignore`** if not already present. The directory holds ephemeral, per-machine state (queue file, pipeline-state records, strategy-sync marker) and must not be committed.
3. No config changes. No template changes. No new state IDs.
4. No breaking changes. Existing `/launch` invocations without `--auto` behave identically to v1.5.0. NEXT.md writes outside VBW active-plan scope behave identically (the deferral check returns `DEFER_NEXT_MD=0` and the direct write proceeds as before).

### Open items deferred to v1.7.0

- **`/pipekit-resume`** — state-file consumer skill that reads `.pipekit/pipeline-state/<issue-id>.json` to resume an interrupted `/launch --auto` chain across Claude Code session boundaries. The state file is written now so the data exists when the consumer ships.
- **Orchestrator-side permission-denial detection** — carried forward from v1.4.0 → v1.5.0 → v1.6.0. The agent-side stop instruction is now in v1.6.0's `--auto` Dev spawn; the orchestrator-side proactive surfacing (without depending on agent compliance) remains open.
- **Option B (VBW-side `always_allow` allowlist)** — upstream coordination required. When it lands, supersedes the v1.6.0 queue mechanism for projects that adopt the VBW config. Both paths coexist safely in the meantime.

---

## v1.5.0 — 2026-04-28

### What's New

**Productivity skills release.** Two new portable skills closing recurring friction observed across the v1.4.x release cycle (rs-vault Phase 1 closeout, four Pipekit releases shipped 2026-04-27). Both are read-only by design and slot cleanly into existing pipeline positions — no behavioral changes to `/launch`, `/light-spec`, or any prior skill. Clean sync from v1.4.1 (no breaking changes, no config migration).

#### `/spec-preflight` automates empirical pre-flight checks on specs (closes #9)

New skill that verifies a Linear issue's spec against reality before `/launch`. Parses file paths, line citations, phase-detect baselines, Linear status, and dependency claims from the spec body and confirms each against the actual project state. Slots between Spec Review Agent (which reviews narrative coherence) and `/launch` (which validates gates).

```
/light-spec → Spec Review Agent → human approval → /spec-preflight → /launch
```

Catches the empirical-drift class of defect agent review structurally cannot see — stale baselines (the recurring failure mode where a spec passed agent review with `phase_count=0` while reality was `1`), renamed files cited in §Technical Context, blockers that re-opened post-approval, etc.

Read-only: never modifies the spec, never transitions Linear status, never writes any project file. Output goes to stdout. Graceful degradation when `phase-detect.sh` or Linear MCP is unavailable — infrastructure flake produces `⚠ unverified` markers, not failures, so a single dropped tool doesn't block the rest of the report. For Quick-tier issues that skip agent review entirely, this is the only automated check before `/launch`.

#### `/release-changelog` generates draft CHANGELOG entry from commits (closes #10)

New skill that parses git commits between two refs, buckets by conventional commit type (`feat` → What's New, `fix` → Fix, `docs` → Documentation, others → Other Changes), and renders a draft CHANGELOG entry mirroring this file's existing format. Output to stdout — human edits the narrative lead and migration sections, then commits. Auto-detects new skill directories in the range to seed the migration bullet.

```
/release-changelog --version v1.6.0
/release-changelog --version v1.6.0 --from v1.5.0
/release-changelog --version v1.6.0 --from v1.5.0 --to HEAD
```

`--version` is required (validated against `vX.Y.Z[-suffix]`); `--from` defaults to the latest tag; `--to` defaults to `HEAD`. Edge cases: no prior tag → error requesting explicit `--from`, empty range → exit 0 with `"no changes since <prev>"`, misformatted commits → bucket gracefully into Other Changes with the full original subject. Read-only on git state and on `CHANGELOG.md`; the human's editing pass is load-bearing and explicitly preserved.

This release dogfooded the skill: the entry above was drafted by hand-running the algorithm on the four commits in the v1.4.1..HEAD range, then expanded with narrative.

### Migration

For consuming projects on v1.4.1:

1. `./scripts/sync-method.sh v1.5.0` — pulls two new skill directories: `skills/spec-preflight/` and `skills/release-changelog/`. Also pulls updated `sop/Skills_SOP.md` and `method.md` skill tables.
2. No config changes required. No template changes. No new state IDs.
3. No breaking changes. Existing pipelines run unchanged. The new skills are additive — projects can adopt `/spec-preflight` selectively (or always) before `/launch`; `/release-changelog` is Pipekit-internal release tooling and consumers may or may not have a use for it depending on their own changelog conventions.

### Open items deferred to v1.6.0

- **Orchestrator-side denial detection** — carried forward from v1.4.0. The "lighter-fix" path landed in v1.4.0 (subagent-side stop instruction); the orchestrator-side detection that surfaces denials proactively without depending on agent compliance remains open.

---

## v1.4.1 — 2026-04-27

### Fix

**`/launch` Step 1.6 resolves `phase-detect.sh` from VBW plugin cache (closes #8).** Hit immediately on first v1.4.0 consumer sync. Step 1.6's lookup checked PATH and `.vbw-planning/scripts/` but didn't know VBW installs `phase-detect.sh` at `~/.claude/plugins/cache/vbw-marketplace/vbw/<VERSION>/scripts/`. Consumers had to write a wrapper script to make Step 1.6 work. Now /launch resolves the canonical install path automatically; if multiple VBW versions are installed, the highest version wins via alphabetic glob expansion.

PATH and project-local lookups still take precedence (preserves override capability). Behavior on no-phase-detect-anywhere is unchanged from v1.4.0 — graceful degradation with non-blocking warning.

### Migration

Patch release. `./scripts/sync-method.sh v1.4.1` — single skill file updated (`launch/skill.md`). No config changes. Consumer wrapper scripts at `.vbw-planning/scripts/phase-detect.sh` continue to work (they take precedence over the plugin-cache fallback).

---

## v1.4.0 — 2026-04-27

### What's New

**Friction-fix release.** Five fixes closing the observations from v1.3.x real-world use (rs-vault Phase 1 closeout, sessions across 2026-04-27). No new capability — all five are behavioral tightenings that close silent-failure modes and cross-system gaps observed in production. Clean sync from v1.3.0 (no breaking changes, no config migration).

#### `/branch` pre-checks Linear status before worktree creation (closes #5)
When `--linear PROJ-XX` is passed, `/branch` now fetches the Linear issue **before** creating the worktree. Done/Canceled/Duplicate prompts confirmation (default abort); In Progress/Building warns and proceeds; other states proceed silently. Linear transition to In Progress still happens after worktree creation (preserves prior behavior). Catches "the work was already shipped" before the user wastes setup time.

#### `/launch --close` is idempotent + comment-on-presence (closes #4)
`--close` no longer silently no-ops when the issue has already moved past UAT (PR-merge automation, label-driven Linear automation, `/linear-todo-runner`, etc.). The status transition and the close-summary comment are now decoupled:
- status `<= Building` → transition to UAT (canonical path)
- status `>= UAT` → status transition is a no-op
- always: scan existing comments for the `**Build complete.**` marker; post the close-summary if absent, skip silently if present

Re-running `--close` is safe: idempotent on the comment, idempotent on the status. Audit trail survives all closeout-style flows.

#### Subagent permission-denial-stop instruction + canonical-file pattern doc (closes #6)
Spawned worker agents in `/linear-todo-runner` (and any future agent spawn from `/launch`) now include an explicit permission-denial protocol in the task description: stop on first `EditPermissionDenied` / `HookFeedbackBlocked`, do not retry, surface denied path + intended change + rationale. Prevents agents from burning turns retrying against hook-protected canonical files. The canonical-file-protection pattern (`.claude/rules/*` as agent-write-locked) is now documented in `sop/Skills_SOP.md` so projects intentionally protect their canonical files.

Orchestrator-side denial detection deferred to v1.5.0 per the issue's lighter-fix path.

#### `/launch` surfaces VBW phase-state warnings (closes #7)
New Step 1.6 reads `phase-detect.sh` (read-only) after the Linear gate-check and surfaces unresolved VBW state — `qa_status=failed`, `qa_status=pending` on shipped phases, `has_unverified_phases`, `next_phase_state=needs_qa_remediation` / `needs_uat_remediation`. User can continue (default), address VBW state first, or abort. `phase-detect.sh` failure is non-blocking. Closes the read-only awareness gap between Pipekit and VBW called out in `method.md` § VBW / Pipekit Ownership Model. Ownership boundary unchanged — Pipekit never writes VBW state.

#### `/launch` handoff routing for closeout-style work (closes #3)
`/launch` now runs a VBW absorption check inside Step 7b before emitting the canonical handoff. If `next_phase_state=all_done` or no matching unbuilt phase exists, the user gets a three-way routing prompt: (1) add a new VBW phase first, (2) skip VBW and author plan manually + `/review-plan <path>`, or (3) abort and escalate. Always confirms; never auto-routes. The manual-plan path explicitly documents that `/review-plan` accepts a path argument (not just a phase slug) so Standard-tier's plan-review gate is satisfied without VBW. Fixes the recurring friction where `/launch` emitted `/vbw:vibe --plan <slug>` against a closed VBW state, producing a broken command for closeout work.

### Migration

For consuming projects on v1.3.0:

1. `./scripts/sync-method.sh v1.4.0` — pulls the updated `branch`, `launch`, `06-linear-todo-runner` skills and `Skills_SOP.md`.
2. No config changes required. No template changes. No new state IDs.
3. If your project has agents that edit canonical files via Pipekit-spawned skills, the new permission-denial protocol will surface hook denials immediately rather than silently — review any prior partial-progress reports against the new behavior.

No breaking changes. The five fixes are all backward-compatible: canonical paths (open VBW phase, in-pipeline issue, fresh `--close` on Building, `/branch` without `--linear`) behave identically to v1.3.0.

---

## v1.3.0 — 2026-04-26

### What's New

**Stage 0 reframed as a contract; entry-mode routing.** Stage 0 is no longer documented as a script you "run once per project" — it's the *contract* (a set of artifacts) that the dev pipeline consumes. Three legitimate entry modes (greenfield, brownfield, inherited) are now first-class, replacing the implicit greenfield-only assumption.

#### Foundation Contract section in `method.md`
A new section enumerates every artifact the dev pipeline (Stages 1-5) requires, with paths and consuming skills. The contract is presence-only — `[TBD]` content is fine; missing files are not. `/roadmap-review` remains the gate that verifies the contract before speccing.

#### Entry-mode tables (parity in `method.md`, `README.md`, `GUIDE.md`)
The greenfield/brownfield/inherited table now appears prominently in all three docs, with `method.md` as the canonical source. Each mode lists who it's for, which skills run, and which are skipped.

#### `/startup --mode={greenfield,brownfield,inherited}` flag
- `--mode=greenfield` — existing 12-step flow, no behavioral change.
- `--mode=brownfield` — skips `/concept` and `/define`, prompts for project metadata, routes through `/strategy-create` with a manual-edit note. Tech-stack and infrastructure steps populate `method.config.md` from the existing project rather than scaffolding.
- `--mode=inherited` — runs the new Foundation Check subroutine (presence audit of every contract artifact) and exits with a next-step recommendation. Does not modify state.

When `--mode=` is absent, `/startup` auto-detects from project state and **always confirms with the user** (mirrors `/launch` Step 1.5 tier resolution — never auto-pick).

#### Foundation Check subroutine in `/startup`
Verifies every foundation-contract artifact, suggests retrofit paths for missing ones, and reports the current phase from `PHASES.md` when the contract is intact. Used internally by `--mode=inherited` and callable standalone whenever you want a foundation audit. No new skill — keeps the skill count steady.

#### Mode-aware Rule #1 in `/pipekit-help`
The single "Stage 0 not complete → run /startup" rule is replaced with four sub-rules:
- Empty project → greenfield → `/startup`
- Code present, no foundation → brownfield → `/startup --mode=brownfield`
- Foundation present, no recent activity → returning/inherited → `/start-session`
- Partial foundation → diagnose via `/startup --mode=inherited`

All other rules are unchanged.

### Migration

For consuming projects on v1.2.0:

1. `./scripts/sync-method.sh v1.3.0` — pulls the updated `method.md`, `/startup` skill, and `/pipekit-help` state rules.
2. No config changes required. Existing greenfield projects continue to behave identically.
3. New contributors joining an existing Pipekit project can now run `/startup --mode=inherited` to verify the foundation contract before picking up work.

No breaking changes.

### Open items deferred to v1.4.0

- **`/strategy-from-code`** — auto-audit skill that would generate strategy docs by inspecting an existing codebase. Brownfield mode currently routes through `/strategy-create` with a banner instructing the user to manually edit the generated docs against reality. Auto-audit is the v1.4.0 follow-up.
- **Brownfield tracker bootstrap from `package.json`** — `/startup --mode=brownfield` currently prompts for project metadata; v1.4.0 will infer name, stack, and deployment from existing project files where possible.

---

## v1.2.0 — 2026-04-26

### What's New

**BMAD-inspired upgrade pack.** Four discrete steals from [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) that strengthen Pipekit without touching the parts that already work — Linear stays the visibility layer, the strategy-sync loop stays the apex, the spec-as-contract principle stays load-bearing. Lands as four sequential commits (P4 → P3 → P1 → P2) that ship value alone if you stop after any of them.

#### Sync-Safe Overrides (`.claude/overrides/`)
Projects can now customize synced skills, SOPs, and `method.md` without forking and without losing upstream improvements. The sync script applies overrides on top of the upstream copy and surfaces a **drift warning** when upstream changes a file you override.

- `.claude/overrides/skills/<name>/skill.md` — full-file replacement
- `.claude/overrides/sop/<file>.md` — full-file replacement
- `.claude/overrides/method.md.patch` — unified diff
- `.claude/overrides/MANIFEST.md` — human-curated index (what + why)

Failed patches dry-run first — they don't half-apply. See `method.md` § Sync-Safe Overrides.

#### First-class scale tiers in `/launch` (Quick / Standard / Heavy)
`/launch` now resolves a **tier** for every issue. Tiers shape *which gates apply*; complexity (Low/Medium/High) shapes *how execution is routed*. The two are orthogonal.

- **Quick** — 1–3 stories, AC-as-plan. Skips spec review, milestone-readiness, plan review, QA agent. Routes to batch runner.
- **Standard** (default) — Existing pipeline.
- **Heavy** — Adds security review + mandatory `/strategy-sync` before close. Always full VBW planning, batch runner disallowed.

Tier inference is **always confirmed with the human** — auto escalation/de-escalation is disallowed by design. Per-tier templates live at `templates/tier-{quick,standard,heavy}.md`. Per-project tier configuration in `method.config.md` § Tiers.

#### `/pipekit-help` skill + opt-in next-step nudge
Push-based replacement for "what skill do I run now?" — replaces pull-based skill discovery in a 12-step pipeline.

- `/pipekit-help` reads project state (branch, recent commits, presence of `PLAN.md` / `REVIEW.md` / `VERIFICATION.md`, `.pipekit/pending-strategy-sync` marker, Linear status) and recommends exactly one next step with a one-line why.
- Rules live in `skills/pipekit-help/state-rules.md` — first match wins; customizable via the override system.
- `scripts/pipekit-next-step-nudge.sh` is an **opt-in** Stop hook that suggests `/pipekit-help` after pipeline-relevant skills finish. Scoped by transcript inspection (silent unless the previous turn invoked a pipeline skill).

#### Fresh-chat discipline (documented enforcement)
The spec-as-contract principle ("no stage may introduce guesswork into the next stage") only holds if downstream agents read prior stage output as documents, not as recalled conversation.

- New `method.md` § Fresh-Chat Discipline section lists which transitions require a new conversation and why.
- Preamble nudges added to skills that cross stage boundaries: `/launch`, `/light-spec-revise`, `/review-plan`, `/strategy-sync`.

### Other Changes Since v1.1.0

This release also bundles the Tier 1 / Tier 2 / Tier 3 `/launch` refactor that landed prior to the BMAD upgrade pack:

- `/launch` split into open + close phases; Pipekit owns Linear status transitions, VBW owns plan/execute/verify
- `/review-plan` standalone skill spawning the `plan-reviewer` agent at `model: opus`
- Post-archive hook (`scripts/pipekit-post-archive.sh`) → `/strategy-sync` nudge via `.pipekit/pending-strategy-sync` marker
- Batch-promote SOP and `/launch --close` messaging
- Canonical `.claude/rules/` hub-and-spoke template (`pipekit-discipline`, `pipekit-tooling`, `pipekit-security`)
- `sync-method.sh` self-update guard + re-exec for single-invocation upgrades

### Deprecations

- `/launch --deep` — no-op since Tier 1; emits a one-line warning. Use `/vbw:vibe --execute --effort=max` instead.

### Migration

For consuming projects on v1.1.0:

1. `./scripts/sync-method.sh v1.2.0` — pulls everything.
2. (Optional) Add `## Tiers` section to `method.config.md` if you want to disable a tier or document tier policy. Default is all three available with **Standard** as fallback.
3. (Optional) Wire the next-step nudge by adding the snippet from `sop/Skills_SOP.md` § Next-Step Nudges to `.claude/settings.local.json`.
4. (Optional) Migrate any pre-v1.2.0 forked skills into `.claude/overrides/skills/<name>/skill.md` so they stop getting clobbered on sync.

No breaking changes. Existing pipelines run unchanged with **Standard** tier as the default.

---

## v1.1.0-opus4.7 — 2026-04-17

Adapted methodology to Claude Opus 4.7 behavioral changes:

- DesignDirection template counters Opus 4.7's default cream/serif/terracotta aesthetic; requires 4 distinct directions before building.
- Literal-scope authoring guidelines added to skills.
- Explicit subagent guidance for Opus 4.7.
- `Session_Management_SOP.md` for Claude Code + Opus 4.7 context handling.

---

## Earlier

See `git log` and `PIPEKIT_IMPROVEMENTS.md` for pre-v1.1.0 history.
