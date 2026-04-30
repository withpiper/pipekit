# Changelog

All notable Pipekit releases. Versioning follows semver-ish — minor bumps for new capability, patch for fixes/docs only.

Pin to a specific version: `./scripts/sync-method.sh v1.7.0`.

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
