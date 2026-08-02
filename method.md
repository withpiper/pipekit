# Pipekit

**v4.28.0** — Last updated: 2026-08-02  *(**v4.28.0 — the lanes board model.** A Linear project is a *completable lane* of 3–8 issues, an initiative is a *completable release phase*, and "no project" + an `Area:` label is the correct home for uncut work — because the `i{N}.`→`P{N}.` walk cannot see inside a project, so a standing pool makes its contents invisible to `pk next`/`pk status` (SiteLine, 2026-08-02: 98 of 162 open issues hidden in three pools). `/linear-hygiene` stops homing orphans into projects and gains four detect-only board-shape checks; `/phase-plan --cut` is the new lane-cutting operation. The naming contract is unchanged and `bin/pk` needed no code change. Smoke 198, unchanged.)*

> **v2.4.3.2 status.** Pipekit's daily loop is `bin/pk` + `/work` + `/verify` + `/pk-exit`. The canonical **one-page** operational doc is [`RUNBOOK.md`](./RUNBOOK.md). This document is the **deeper methodology** — pipeline contract, ownership model, fresh-chat discipline, and tooling reference. Read RUNBOOK first if you only need the daily flow; read this if you're onboarding to the system, tuning gates, or reasoning about why a stage exists.
>
> **The machine-readable NEXT.md is retired; a curated roadmap file is legitimate.** v1 used `NEXT.md` at the project root as a machine-readable "what to do next" pointer that skills auto-wrote. That artifact is retired — `pk next` (reads Linear directly + scopes to the current initiative via the **Linear-native initiative surface** — `i{N}.` initiatives / `P{N}.` projects, v4.1.0; the legacy `PHASES.md` + `linear-map.json` fall back automatically for un-migrated projects) is the canonical "what's next?" answer, and **skills never write a roadmap file**.
>
> What v2's retirement over-rotated on (corrected in v3.1.0): a **hand-curated visual roadmap** at the project root — phases, themes, standing backlogs, the orientation picture Linear's board view doesn't give — is a first-class *optional* artifact. Keep one if you like seeing the whole arc in a file (`NEXT.md` or `ROADMAP.md` by convention). Two rules keep it safe:
> - **Human-owned.** Skills and agents never write it, and never read it as operational state. It can go stale without breaking anything — it's narrative, not state.
> - **Linear stays the truth.** "What should I do now?" is always `pk next`, never the roadmap file.
>
> `notepad.md` (gitignored, seeded by `pk init` v2.1.1+) remains the personal free-form scratch space — distinct from the curated roadmap, which is committed and shareable.

## Overview

A structured AI-assisted delivery system designed to produce high-quality software through controlled stages of generation, review, planning, and execution.

It operates as a pipeline with explicit quality gates to eliminate ambiguity and reduce execution risk. Each gate enforces a contract: the output of one stage must be consumable by the next without guessing.

---

## Core Principle

**No stage may introduce guesswork into the next stage.**

- Specs must not require planning guesses
- Plans must not require execution guesses
- Execution must not require interpretation

When ambiguity is detected, the pipeline sends work backward — not forward. A spec that forces the planner to guess is returned for revision, not passed through with caveats.

---

## Pipeline

```
Stage 0: Foundation (a contract, not a script)
  /concept → /define → /strategy-create → /startup → /roadmap-create → /phase-plan

Development Pipeline (repeats per issue, contract-strict):

  Stage 1: Spec          /light-spec → agent review → human review
  Stage 2: Plan + Build  pk branch → /work    (→ /review-plan to gate the plan)
  Stage 3: Verify + Ship /verify → pk ship    (→ /pr-fix | /pr-security-review) → UAT
  Stage 4: Release       pk promote <env> → pk done   (promote walks one hop per call; pk done is cleanup)
  Stage 5: Doc Loop      /strategy-sync       (after UAT)

Per session (not per issue): /pk-exit          (last command of every Claude Code session)
```

**Stage 0** is the *contract* the development pipeline depends on — a set of artifacts (concept, definition, strategy, config, the Linear-native initiative surface, phase plan) that must exist before the daily loop is safe to run. It's not a script you run once; it's a pre-condition. *How* those artifacts come to exist depends on the project's entry mode (greenfield, brownfield, inherited — see [Entry Modes](#entry-modes) below). **Stages 1-5** consume the contract and repeat per issue.

**Bookends:** `/roadmap-review` validates Stage 0 outputs and plan health before entering the pipeline. `/strategy-sync` updates Strategy docs after features ship — closing the documentation loop.

**Three-layer enforcement.** Conventions live in `CLAUDE.md` (the executor reads this), hard gates live in CI + hooks (block merges that violate them), and skills are interactive shortcuts for hands-on sessions. The same rule is enforced at multiple layers so neither a missed skill invocation nor a permissive prompt can bypass it.

### Step-by-Step

#### Stage 0: Foundation

| # | Step | Tool | Input | Output | Gate |
|---|------|------|-------|--------|------|
| 0.1 | **Concept** | `/concept` | Raw idea + existing docs | `concept-brief.md` | Idea is specific enough to define |
| 0.2 | **Define** | `/define` | Concept brief | `project-definition.md` | Definition supports tech stack + strategy decisions |
| 0.3 | **Strategy Create** | `/strategy-create` | Project definition | `Strategy/` docs (incl. Design Direction) | Docs describe a coherent product |
| 0.4 | **Infra Setup** | `/startup` (Steps 3-6) | Tech stack decisions | Working repo, DB, deploy, MCP | Pre-deploy gate passes |
| 0.5 | **Roadmap** | `/roadmap-create` | Strategy docs + definition | Linear Initiative→Project→Issue hierarchy (`i{N}.` / `I{N}.P{N}.`) | Every requirement has an issue |
| 0.6 | **Phase Plan** | `/phase-plan` | Populated Linear board | First sub-phase's issues in "Needs Spec" | Dependencies clear, initiative sized |

Stage 0 is the foundation contract — a set of artifacts, not a script. The greenfield flow above is one of three entry modes (see [Entry Modes](#entry-modes)). `/startup` orchestrates whichever mode applies.

#### Stages 1-5: Development Pipeline

| # | Stage | Step | Tool | Output | Gate |
|---|-------|------|------|--------|------|
| 1 | 1 | **Light Spec** | `/light-spec` | Structured spec stored in Linear | — |
| 2 | 1 | **Agent Review** | Spec Review Agent (in Linear) | Pass/Revise verdict with readiness score | Spec is unambiguous + decomposable without guessing |
| 3 | 1 | **Human Review** | You, in Linear | Approved spec with product decisions locked | Human signs off on scope/decisions/priority |
| 4 | 2 | **Branch** | `pk next` then `pk branch <ID>` | Worktree + branch created, Linear → In Progress | Spec approved, deps met |
| 5 | 2 | **Work** | `/work <ID>` (native-on-Workflow) | Code committed against verify/done criteria | Verdict gate passes before code is written |
| 5b | 2 | **Plan Review** *(optional)* | `/review-plan` (spawns `plan-reviewer` agent) | Validated plan or revision requests | Plan executable step-by-step without ambiguity |
| 6 | 3 | **Verify** | `/verify` (or `pk verify`) | Pre-deploy gate report — Pass / Partial / Fail with per-AC table; QA subagent if `Require QA review: true` | Gate green; AC satisfied |
| 6a | 3 | **Security Gate** *(v4.4.0; projects with a categories file)* | `/security-gate [<ID>]` | Classifies the feature diff into sensitive categories (auth, payments, user-input, external-APIs, file-storage, PII); on a match, runs the category checklist against the diff → PASS/FAIL report + Linear comment. **Hard v4.17.0** — PASS writes the sentinel `pk ship` requires on categories-armed projects. None matched → instant PASS (sentinel still written). | Security-sensitive change reviewed before it reaches UAT (the Building → UAT seam) |
| 7 | 3 | **Ship** | `pk ship [--review] [--ready]` | Branch pushed, PR opened as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT | Verify passed |
| 7a | 3 | **Flip to Ready** | `pk ready [<ID>]` | PR flipped Draft → Ready; outside reviewers (Semgrep + claude-review per `templates/ci/`) fire on `ready_for_review` event | Ready to merge |
| 7b | 3 | **PR Review** *(opt-in)* | `/pr-fix` and/or `/pr-security-review` | Triage summary in Linear (fixed / rejected / deferred) | Critical/High findings resolved or explicitly deferred |
| 8 | 3 | **UAT** | You (browser / Linear) | Accepted or rejected against spec AC. State is `UAT` while PR is open on preview; flips to `In <FirstEnv>` (e.g. `In Dev`) on `pk done` after merge. | Matches spec under real usage |
| 9 | 4 | **Cleanup** | `pk done <ID> [--merge]` | Worktree + branch cleaned up; commits + diffstat posted to Linear; Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). v2.6.0+: also auto-pulls the integration branch. `--merge` lets pk run `gh pr merge` first. | PR merged (or `--merge` passed) |
| 9a | 4 | **Prod Ready** *(v4.3.0; projects with a checks file)* | `/prod-ready [<ID>]` | Production-readiness report — PASS/FAIL across six operational checks (monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, flag on risky paths, dashboard chart) + Linear comment. **Hard v4.17.0** — PASS writes the sentinel `pk promote` requires at the **final** hop on checks-armed projects (1-tier: advisory, no seam). Run **once per feature**, before the **final** promote. | Operational preconditions verified before production (the last `Ship environments` entry; the merge to `main` on 1-tier) |
| 10a | 4 | **Promote — open** | `pk promote <env>` *(multi-tier projects only)* | One-hop promotion PR per `Ship environments`. v2.6.0+: WITs stay in source state until merge; PR body embeds bundled-WIT tracker. | PR opened |
| 10b | 4 | **Promote — finish** | `pk promote <env> --finish` | After the promote PR merges: bundled WITs transition → **`In <Env>`** for intermediate hops (e.g. `In Beta`), → **`Done`** for the final hop (`pk promote main --finish`). v2.6.0+ two-phase model eliminates the ~5min Linear-ahead-of-reality window. | PR merged + Linear states transitioned |
| 11 | 5 | **Strategy Sync** | `/strategy-sync` | Updated Strategy docs reflecting reality | Code is truth; diffs human-approved before apply |

**Feedback loops:** steps 2, 5b, 6, and 8 can send work backward. Agent review returns specs for revision. Plan review returns plans for rework. Verify returns tasks to dev. UAT returns features to execution. The pipeline is linear by default, corrective when needed.

**Per session (not per issue):** `/pk-exit` writes the narrative session log to `Logs/Sessions/<date>_<HHMM>.md`. Run as the last command of every Claude Code session, regardless of where the issue stands.

**Between initiatives:** `/phase-plan --next` selects the next batch of issues and promotes them to "Needs Spec." `/roadmap-review` validates before speccing begins.

> **Optional pre-step:** `/brainstorm` — for exploring feature-level ideas within an existing project. For project-level ideation, use `/concept`.

> **Express lane (`/pk-express`):** for *simple* WITs (Quick/Standard tier), `/pk-express <ISSUE-ID>` collapses Stages 1–3 into one hands-off pass — chaining `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify + ship) and stopping only at five attention gates (brainstorm not-Now, `tier:heavy` refusal, spec stalemate, `/verify` flag, Draft PR opened). It removes between-stage typing and the two triage prompts, nothing that protects real risk. It is a **portable skill, not a `Workflow`** — sequential and human-gated; a portable methodology cannot depend on the plan-gated `Workflow` primitive. It never runs `pk ready` / `pk done` / `pk promote` — those stay the human gates. Not for `tier:heavy` (it refuses), bugs (`/pk-bug`), or work with an Approved spec (`pk branch` + `/work` directly).

---

## Foundation Contract

The development pipeline (Stages 1-5) is **contract-strict**: every skill in it assumes a specific set of artifacts already exists. If any of these are missing, the daily loop is unsafe — gates can't validate, plans can't reference strategy, Linear sync has no map. The contract below is the minimum surface; how each artifact came to exist is mode-specific (see [Entry Modes](#entry-modes)).

| Artifact | Path | Required for |
|---|---|---|
| Concept brief | `concept-brief.md` | `/define` |
| Project definition | `project-definition.md` | `/strategy-create`, `/roadmap-create` |
| Strategy docs | `Strategy/*.md` | `/light-spec`, `/strategy-sync` |
| Project config | `method.config.md` | All Pipekit skills, `bin/pk` |
| Initiative surface | Linear Initiatives (`i{N}.` release phases) → Projects (`I{N}.P{N}.` lanes, 3–8 issues) → Issues, plus an `Area:`-labelled project-less backlog | `pk next`, `pk status`, `/phase-plan`, `/roadmap-create` (live in Linear; no committed file — see `method.config.md § Initiative Surface`) |

`/roadmap-review` is the gate that verifies the contract before the dev pipeline begins. `/pipekit-help` and `/startup --mode=inherited` (see [Entry Modes](#entry-modes)) inspect the contract on demand and recommend retrofits when artifacts are missing.

> **Note on completeness vs. existence.** The contract requires that artifacts *exist*; it does not require them to be perfect. `[TBD]` sections in strategy docs are normal at v0.1.0 — the spec pipeline is what fills them in. The contract is a presence check, not a content audit.

---

## Entry Modes

A project can enter the dev pipeline through three legitimate paths. They differ in how the foundation contract gets satisfied — not in what the contract is.

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain (`/concept` → `/define` → `/strategy-create` → `/startup` → `/roadmap-create` → `/phase-plan`) | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield` (stub for now), `/roadmap-create`, `/phase-plan` | `/concept`, `/define` (the project already exists; concept/definition are reverse-engineered manually until the deferred `/strategy-from-code` auto-audit skill ships) |
| **Inherited** | New contributor joining a Pipekit project | None — `/startup --mode=inherited` verifies the contract is intact and points to the dev pipeline | All of Stage 0 (artifacts are already on disk) |

`/startup` auto-detects the mode by inspecting project state (no concept-brief + no code → greenfield; code present, no Strategy/ → brownfield; everything present → inherited) and **always confirms with the user** before proceeding — same pattern as tier resolution in `/work`. Mode is never picked silently.

> **`/strategy-from-code` is deferred.** Originally promised for v1.4.0 (2026-04-27) but never built. Brownfield mode currently routes through `/strategy-create` with a manual-edit note: the generated docs reflect the project definition, not the existing code, so you'll want to edit them against reality before the first `/light-spec`. Track interest in the brainstorm backlog if you'd benefit from auto-audit.

---

## Stage 0: Foundation

**Steps:** 0.1–0.6 (Concept → Define → Strategy → Setup → Roadmap → Phase Plan)

**Tools:** `/concept`, `/define`, `/strategy-create`, `/startup`, `/roadmap-create`, `/phase-plan`

Stage 0 is the contract above (Foundation Contract), not a script. The greenfield path runs all six skills in order. Brownfield skips the first two. Inherited skips the entire stage and just verifies the artifacts. See [Entry Modes](#entry-modes) for which path applies to your project. This section documents the greenfield flow; the others are variations on it.

- `/concept` captures the idea and assesses viability — supports ingesting existing documents (proposals, research, notes)
- `/define` distills the concept into stages, roles, workflows, and success criteria
- `/strategy-create` generates configurable strategy docs (doc set defined in `method.config.md`)
- `/startup` orchestrates the full flow and handles infrastructure (repo, DB, deploy, MCP, Linear)
- `/roadmap-create` extracts requirements from strategy docs and authors the **Linear-native initiative surface** — Initiatives (`i{N}.` initiatives) → Projects (`I{N}.P{N}.` sub-phases) → Issues
- `/phase-plan` confirms the current initiative and promotes its first sub-phase's issues to "Needs Spec"

**Output:** `concept-brief.md`, `project-definition.md`, `Strategy/` docs, working infrastructure, and a populated Linear board structured as the native initiative surface (`i{N}.` initiatives → `P{N}.` projects → issues), with the first sub-phase's issues in "Needs Spec". (No `.vbw-planning/` scaffold — the initiative surface lives in Linear; see `method.config.md § Initiative Surface`.)

**Gate:** `/roadmap-review` validates all Stage 0 outputs before the spec pipeline begins.

---

## Pre-Condition: Roadmap Review

**Step:** 0

**Tools:** `/roadmap-review`

Run before entering the spec pipeline to validate that Stage 0 is complete and the roadmap is coherent: concept and definition exist, strategy docs match config, all requirements have Linear issues, dependencies are set, workflow states are consistent, current initiative is defined, and spec coverage is adequate. Also flags Strategy doc staleness (recommends `/strategy-sync` if needed).

**Output:** Health report with action items. Resolve blockers before speccing.

---

## Stage 1: Definition (Spec Quality Gate)

**Steps:** 1–3 (Light Spec → Agent Review → Human Review)
**Pre-condition:** Roadmap Review (Step 0) must pass

**Tools:** `/light-spec`, `pk spec-cycle`, `/light-spec-revise`, Spec Review Agent, Human

- `/light-spec` explores the codebase, reads reference material and Strategy docs, and generates a structured spec as an AI→AI contract
- `/light-spec` publishes the spec to the configured **`Spec ready state`** in `method.config.md` (not a hardcoded `Specced` — v2.7.0+), so two-state boards (e.g. `Needs Spec → Approved`, no `Specced` state) work without modification. `pk spec-cycle` requires that same state on entry, so the interlock holds on any board.
- `/light-spec` Phase 6 then runs the **review cycle** automatically: invokes `pk spec-cycle` (which posts the agent trigger, polls Linear for the verdict, and transitions the issue to the configured **`Spec approved state`** — default `Approved` — on Pass), and on Revise auto-invokes `/light-spec-revise` for surgical patches before the next cycle pass
- The cycle is hard-capped at 3 passes. On passes 2 and 3 the user is prompted `[Y/n/o]` (continue / bail / drop into `/light-spec-revise`'s override path) so a stalemating agent can't drive infinite revision
- Spec Review Agent enforces planning readiness (Pass/Revise with blocking issues identified)
- Human validates product decisions, scope, and priority
- Iteration continues until Agent passes AND Human approves

**Output:** Planning-safe spec (stored as Linear issue description)

**Gate:** Spec must be unambiguous and decomposable without guessing. All decisions defined or explicitly marked [TBD] (where TBD does not block task decomposition).

---

## Stage 2: Plan + Build (Execution Quality Gate)

**Steps:** 4–5b (`pk branch` → `/work` → optional `/review-plan`)

**Tools:** `pk branch`, `/work`, `plan-reviewer` agent (via `/review-plan`)

- **`pk branch <ID>`** sets up the worktree + branch and transitions Linear to In Progress. Idempotent — rerun is safe.
- **`/work <ID>`** does plan + execute in one skill, gated by a **verdict** (`proceed` / `revise: <feedback>` / `abort`) before any code is written. Tier (Quick / Standard / Heavy) is human-confirmed before the verdict step. `/work` **plans inline** (in your current Claude session, with parallel `Agent` grounding), then executes on the **native-on-Workflow** backend — the sole executor as of v4.0.0:
  - `/work` writes a task DAG to `.pk-work/<ID>-PLAN.md`, then executes on the **Workflow primitive** — one atomic commit per task with verify-before-integrate, run trail in `.pk-work/<ID>-SUMMARY.md`. Trivial plans run inline. Scope is the executor contract only — no UAT/known-issue/sprint state.
  - The pluggable backend and `--backend=` flag were removed in v4.0.0 (the `auto` router in v3.2.0). A stale `Backend:` or `--backend=` makes `/work` refuse with a migration message rather than silently routing.
- **`/review-plan`** *(optional)* spawns the `plan-reviewer` agent against the inline `PLAN.md` (`.pk-work/<ID>-PLAN.md`) before execution — independent stress-test of scope, atomicity, dependencies, success criteria, and risks.

**Output:** Code committed against verify/done criteria

**Gate:** Plan must be executable step-by-step without ambiguity or rework. No task should require the dev agent to make product decisions.

---

## Stage 3: Verify + Ship + UAT (Build Quality Gate)

**Steps:** 6–8 (`/verify` → `pk ship` → optional PR review → **interactive UAT**)

**Tools:** `/verify`, `pk ship`, optional `/pr-fix` and `/pr-security-review`, Human

- **`/verify`** runs the pre-deploy gate from `method.config.md` (types + lint + test). Returns Pass / Partial / Fail with a per-AC table. If `Require QA review: true`, also spawns the QA subagent for goal-backward verification.
- **Auto-rollover**: `/work` auto-invokes `/verify` on successful completion (no prompt). On Pass, `/verify` auto-invokes `pk ship` (gated by the `PIPEKIT_AUTO_SHIP=1` env var that `/work` sets — standalone `/verify` calls do not auto-ship). On Partial / Fail, the rollover stops with the per-AC table; the user fixes and re-runs. Aborts inside `/work` skip the rollover entirely.
- **`pk ship`** pushes the feature branch, opens the PR as **Draft** (v2.6.0+) against the integration branch from config, and transitions Linear → UAT. Outside reviewers (Semgrep + claude-review per `templates/ci/`) trigger on `[opened, ready_for_review]` — Draft means no review fires during iteration. `pk ship --ready` opts out for one-shot tiny WITs.
- **`pk ready [<ID>]`** flips a Draft PR to Ready, firing the `ready_for_review` event and the configured outside reviewers. No Linear state change (UAT stays UAT). The merge-moment review gesture. **Refuses (v4.27.0+) when source or a migration changed after the `/verify` that vouches for the branch** — `pk ship`'s gate is point-in-time and post-ship commits go unchecked, so this is the seam where evidence meets reviewers. Also refuses when the recorded sha is unreachable (rebase/squash): drift is uncomputable, which is unknown rather than clean, and `pk ship` would refuse that branch outright anyway. Re-run `/verify`, or `--force` to flip anyway (logs a Linear comment).
- **`pk ship --review`** posts a Linear comment flagging review-in-flight and prints the antagonistic reviewer invocation. The reviewer plays devil's advocate vs `/work` + `/verify` (which validate spec adherence) — surfaces cross-cutting concerns the spec didn't think to mention.
- **`/pr-security-review`** is the right tool for migrations / RLS / SECURITY DEFINER / auth surface (use instead of, or alongside, the generic reviewer).
- **`/pr-fix`** triages review findings into fixed / rejected / deferred and posts a summary comment to Linear.
- **Interactive UAT (the gate).** Human exercises the feature in the running app — on the preview URL pre-merge (Linear state `UAT`), on the first deploy env (e.g. `dev.<project>`) post-merge (Linear state `In <FirstEnv>`). This is **the** Stage 3 gate, not a doc artifact: `pk promote` MUST NOT run until env-UAT signs off. v2.4.2 surfaced the cost of an implicit UAT: the WIT-451 canary's worker session auto-ran `pk done` mid-test and wiped the worktree before the human finished. **Treat UAT as a deliberate human step. Do not chain past it from inside `/work`, `/verify`, `/pk-exit`, or any other session-automating skill.** v2.5.0 split UAT into two state phases: `UAT` (PR open on preview, pre-merge) and `In <FirstEnv>` (e.g. `In Dev` — merged, code on first env, interactive UAT in progress or signed-off-awaiting-promote). `pk done` is the legitimate UAT → In `<FirstEnv>` transition (it just verified the merge). `pk promote --confirmed` is the post-UAT-signoff gate for hopping forward; it refuses with `exit 1` if any bundled issue is still `UAT` (PR not merged).

**Output:** Verified PR open and UAT-accepted in Linear, ready for the human to merge.

**Gate:** Feature matches spec behavior under real usage. All AC checkboxes satisfied. Critical/High review findings resolved or explicitly deferred. **Human UAT verdict recorded** (Linear comment, PR comment, or session-log note — pick one; the point is an audit trail).

---

## Stage 4: Release

**Steps:** 9–10 (`pk done` → `pk promote`)

Every step forward is a PR. No direct merges between long-lived branches. Promotion is owned by `pk promote`, configured per project via `Ship environments` in `method.config.md` (e.g., `dev,main` or `dev,beta,main`).

**Order of operations** (after Stage 3 sets `UAT` and the PR is ready):

1. **Human merges the PR** (rebase or merge-commit; see `sop/Git_and_Deployment.md` § Merge Strategy by Hop). Or pass `--merge` to step 2 and let `pk done` run `gh pr merge` for you (v2.5.0+).
2. **`pk done <ID> [--merge]`** verifies the merge happened, posts commits + diffstat to Linear, transitions Linear `UAT → In <FirstEnv>` (e.g. `In Dev`), removes the worktree + branch, and auto-pulls the integration branch (v2.6.0+). For 1-tier projects the transition is `UAT → Done` directly. **Deliberate human step** — must NOT be auto-invoked by `/work`, `/verify`, `/pk-exit`, or any session-automation skill. The worker session that built the feature has no reliable signal for "PR is mergeable AND human is ready" (WIT-451 canary 2026-05-13). v2.5.0+: `--confirmed` is accepted for backward compat but is a no-op.
3. **Exercise the feature on the deployed first env** (e.g. dev). The issue sits in `In <FirstEnv>` while UAT happens.
4. **`pk promote <env> [--confirmed]`** — v2.6.0+ two-phase model:
    - **Phase 1 (`pk promote <env>`)** opens the next-tier promotion PR (one hop per invocation: `pk promote beta`, then `pk promote main`). Bundled WITs stay in source state. The PR body embeds a tracker marker with the bundled WIT list.
    - **Phase 2 (`pk promote <env> --finish`)** runs after the human merges the promote PR. Reads the marker, transitions bundled WITs → **`In <Env>`** for intermediate hops (e.g. `In Beta`), → **`Done`** for the final hop. Falls back to deriving WITs from PR commits for older promote PRs without the marker.
    - 2-tier projects: `pk promote` with no arg picks the only hop. Skipped entirely for `Promote to main: false`.
    - **Deliberate human step**, same rationale as `pk done`. v2.4.3+: refuses with `exit 1` if any bundled issue is in `UAT` (PR not merged); pass `--confirmed` once env-UAT is signed off.
    - **Why two-phase** (v2.6.0+): the pre-v2.6.0 optimistic-at-PR-open transition left Linear ~5 minutes ahead of reality (F2 from RS-Vault 2026-05-15 canary). Two-phase trades one extra command for accurate state.

**Auto-machinery** firing on PR open / main merge (Pipekit owns none of these — they're project infrastructure):

- **CI** enforces the pre-deploy gate at each PR.
- **Vercel** deploys preview on PR open and prod on main merge.
- **GitHub Actions** (Supabase projects only): `db-pr-check.yml` validates migrations on PR open against ephemeral postgres; `db-migrate.yml` applies them on main merge. Lift the workflow pair from rs-vault if your project doesn't have them yet.
- **Linear transition** (optional, v2.7.1): `templates/ci/linear-transition.yml` advances a merged WIT's Linear state on integration-branch merge — the safety net for a `pk done` skipped via a GitHub-UI merge. Forward-only + idempotent; see `templates/ci/README.md` (incl. the relationship with Linear's native GitHub integration — off for multi-tier, where this workflow is the ladder-aware mechanism).

**Output:** Production release.

**Gate:** CI passes, pre-deploy gate passes, smoke tests pass.

---

## Stage 5: Documentation Loop

**Step:** 11

**Tools:** `/strategy-sync`

After features ship and UAT passes, run `/strategy-sync` to update Strategy docs to reflect what was actually built. Code is truth — if the implementation differs from the spec, docs match the code.

```
Strategy Docs (vision) → Light Specs → Plans → Code → Strategy Docs (reality)
                  ↑                                              |
                  └──────────── /strategy-sync ─────────────────┘
```

**Output:** Updated Strategy docs with version bump. All changes presented as diffs for human approval before applying.

**Cadence:** After UAT passes for an initiative, before stakeholder presentations, before onboarding new team members.

---

## Key Principles

### AI → AI Contracts
Light specs are structured contracts between generator, reviewer, and planner. Every rule must be explicit, unambiguous, and enforceable by a downstream agent.

### WHAT vs HOW
Specs define WHAT. Plans define HOW. If a spec statement can be rewritten as "change X line" or "use Y syntax," it is implementation detail and must be removed.

### Explicit Decisions
All behaviour-affecting decisions must be defined or marked [TBD]. A decision left implicit (not mentioned at all) makes the spec invalid. [TBD] is only valid if it does not block task decomposition.

### Authority
Source of truth must be explicit (DB, utils, API, etc.). When multiple layers could disagree, define precedence. Ambiguous authority is the #1 cause of spec revision.

### No Hidden Assumptions
Controlled incompleteness is allowed — brevity, [TBD], limited context are fine. Hidden assumptions and implicit behaviour are not. The line: _can the next stage work without guessing?_

### Human Ownership
AI proposes, reviews, and executes. Humans decide. AI never locks in a product decision — it presents analysis and waits for the call.

---

## Fresh-Chat Discipline

The real principle here is **stage isolation**: each stage's agent must read the prior stage's output **as a document**, not as recalled conversation. A reviewer who watched the spec get drafted is no longer an independent reviewer; a planner who absorbed the launch handoff carries assumptions the spec didn't make explicit. "Fresh chat" is the hands-on *mechanism* for achieving isolation — in auto-chained flows the same isolation is enforced by construction, because each stage runs as a separately-spawned subagent that never inherits the orchestrator's context.

**This is not a context-window workaround.** It would be easy to read "start fresh" as a concession to a small window — the model forgets, so we re-prime it from a document. That was never the reason, and the 1M context window plus harness-persistent memory do not relax this rule. The risk being managed is **contaminated judgment, not lost memory**: an agent that participated in producing X cannot independently review X, no matter how much of X it can hold in context. If anything, more capable and more autonomous models make independent review *more* load-bearing, because confident-wrong output scales with capability — a one-agent-does-everything session is exactly the failure mode that survives a bigger window untouched.

The corollary: isolation is mandatory only where independence or a clean contract is at stake (the rows below). It is *not* a blanket "always start over" rule. Carrying context forward within a stage, or across read-only steps, costs nothing and rebuilds nothing — see "When to stay in-session."

**Rule:** start a new conversation (or spawn a fresh subagent) when crossing a stage boundary that demands independence. Inside a stage, one chat is fine.

### When to start fresh

| Crossing | Why fresh |
|---|---|
| `/light-spec` → `/light-spec-revise` (after agent review) | Reviser must read the published spec + agent comment as documents, not recall the draft session |
| `/light-spec` → `pk branch` + `/work` | The work agent must validate the spec on its merits, not from memory of how it was built |
| `/work` plan-verdict → `/review-plan` | Plan reviewer must be independent of the planner |
| `/work` execution → `/verify` | QA must verify against goals, not against the executor's narration |
| `pk ship` → `pk ship --review` (or `/pr-security-review`) | Antagonistic reviewer must approach the PR fresh, without the executor's context |
| Any stage → `/strategy-sync` | Strategy sync compares shipped reality to docs; recall of build decisions contaminates the diff |

### When to stay in-session

- Inside `/light-spec` (capture → draft → publish are one stage)
- Inside `/work` for the duration of one issue (plan + execute are designed to share context)
- Reading-only sessions: `pk status`, `pk next`, `/00-roadmap-review`, `/pipekit-help`

### Why this matters more than it looks

The spec-as-contract principle ("no stage may introduce guesswork into the next stage") only works if the next stage is genuinely downstream. A long-running session collapses the stages into one agent making all decisions with shared context — the failure mode this whole pipeline exists to prevent. Isolation is the load-bearing constraint; fresh chats and subagent spawning are just the two mechanisms that deliver it (manual and by-construction, respectively). Both stay cheap, and neither is made redundant by a larger context window — the window changes how much an agent can *hold*, not whether it can *independently judge* work it helped produce.

---

## Three-Layer Enforcement Model

| Layer | Purpose | Who it serves |
|---|---|---|
| **CLAUDE.md** | Documents conventions so the executor follows them automatically | The native executor during plan execution |
| **CI / Hooks** | Hard enforcement — blocks merges that violate conventions | Everyone (agents and humans) |
| **Skills** | Interactive shortcuts for hands-on sessions | You, when working with Claude directly |

Skills are convenience wrappers. They automate the same conventions documented in CLAUDE.md. The executor doesn't call skills — it reads CLAUDE.md and writes code directly.

---

## Initiative Surface Ownership

**The initiative surface is Linear-native (v4.1.0) and wholly Pipekit-owned.** The roadmap's initiative order —
Initiatives (`i{N}.`) → Projects (`I{N}.P{N}.`, v4.5.0; bare `P{N}.` still parses) → Issues — lives in
Linear. VBW is fully retired: the executor went in v4.0.0, the plugin was decoupled in v4.2.0, and no
Pipekit skill, doc, or dependency reaches for it. The lone vestige is `bin/pk`'s **legacy read-only
fallback** — it reads `.vbw-planning/PHASES.md` / `linear-map.json` only for projects that haven't yet
migrated to the Linear-native surface; nothing writes those files. The boundaries below make ownership
explicit.

### Ownership Table

| File / System | Owned by | Writers | Readers |
|---|---|---|---|
| **Initiative surface** — Linear Initiatives (`i{N}.`) → Projects (`I{N}.P{N}.`) → Issues | Pipekit | `/roadmap-create` (authors), `/phase-plan` (advances, cuts lanes) | `pk next`, `pk status`, all Pipekit skills. The naming convention is the contract (`method.config.md § Initiative Surface`); ordering is the prefix number, never Linear `sortOrder`. **Initiatives and projects are both completable** — an initiative is a release phase, a project is a lane of ~3–8 issues. A project that keeps accepting work is a pool, and the walk cannot see inside it. |
| **`Area:` label group + project-less backlog** (v4.28.0, lanes model) | Pipekit | `/linear-hygiene` (classifies), `/roadmap-create` (creates the group) | The default home for **uncut** work. Orthogonal to lane membership in both directions: a label survives a lane move, and a lane may mix areas — so neither is ever inferred from the other. Opt in via `method.config.md § Initiative Surface → Area Labels`. |
| **Phase-label layer** (optional, v4.14.0 — the *other* board shape) | Pipekit | `/roadmap-create` Phase 3.5 (scaffolds at authoring), `/roadmap-review` Phase 3.5 (bootstraps the layer onto an existing board on retrofit, then drift-checks vs `ROADMAP.md`) | Humans (the board view). A **visualization mirror** of `ROADMAP.md`'s per-phase build order, for roadmaps whose phases span many `I{N}.P{N}.` projects. **Mutually exclusive with the lanes model** — there phases ≡ initiatives, so the layer would be a second mirror of an order the prefixes already carry. Opt-in via `method.config.md § Phase Label Layer`; `/linear-hygiene` must **not** touch these labels (project membership ≠ phase-label membership). |
| `.vbw-planning/PHASES.md`, `linear-map.json` (legacy) | Retired | Nothing — no skill writes them | `bin/pk` reads them only as a **legacy read-only fallback** for projects that have no `i{N}.` initiatives yet (not yet migrated to the Linear-native surface) |
| `notepad.md` (project root, gitignored) | Human | Whoever's typing | Whoever's reading. v2 retired the auto-written `NEXT.md` mirror — `pk next` reads "what's next?" live from Linear instead. |
| Curated roadmap (optional — `NEXT.md` / `ROADMAP.md` at project root, committed) | Human | Human only — skills and agents never write it | Humans and stakeholders. Narrative orientation (initiatives, themes, standing backlogs), never read by skills as operational state. |
| Linear issues | Pipekit | `/light-spec`, `pk branch`, `pk ship`, `pk done`, `/roadmap-create`, `/phase-plan` | Everyone |
| `concept-brief.md`, `project-definition.md`, `Strategy/` | Pipekit | `/concept`, `/define`, `/strategy-create`, `/strategy-sync` | `/light-spec`, `/work` (inline planning) |
| `method.config.md` | Pipekit | `/startup` (populates); human (edits) | All Pipekit skills, `bin/pk` |

### Rules of Engagement

1. **The initiative surface is Linear-native and Pipekit-owned.** Initiatives (`i{N}.`) → Projects (`I{N}.P{N}.`) → Issues live in Linear. `/roadmap-create` authors them; `/phase-plan` advances them; `pk next`/`pk status` derive the current initiative live (accepting both `I{N}.P{N}.` and legacy bare `P{N}.`). No committed initiative file — the legacy `PHASES.md`/`linear-map.json` are a read-only fallback only.
2. **Pipekit owns the visibility layer.** Linear issues, the initiative surface, strategy docs, and project config are Pipekit's. (v2 retired the `NEXT.md` mirror; v4.1.0 retired `PHASES.md`/`linear-map.json` — `pk next` reads "what's next?" live from Linear.)
3. **The roadmap is authored directly into Linear** — at `/roadmap-create`. The Linear Initiative→Project hierarchy *is* the roadmap, named by the `i{N}.`/`I{N}.P{N}.` convention. There is no separate initiative skeleton to merge into.
4. **Pipekit owns gates and build.** `pk branch` opens Linear → In Progress; `/work` plans inline and executes on the native-on-Workflow backend (the sole executor as of v4.0.0); `/verify` runs the pre-deploy gate; `pk ship` transitions Linear → UAT (PR open on preview); `pk done` verifies merge, transitions Linear UAT → `In <FirstEnv>` (e.g. `In Dev`), cleans up the worktree; `pk promote <env>` walks `Ship environments` one hop at a time and transitions issues → `In <Env>` (intermediate) or → Done (final). The plan-review gate lives in the standalone `/review-plan` skill, which spawns the `plan-reviewer` agent on the plan-review tier (`method.config.md § Model Policy`, default `opus`/`xhigh`) between `/work`'s inline plan and execution.

   **Pipekit's execution surface:**
   1. **One direct agent spawn** — `plan-reviewer` in `/review-plan`. Pipekit-shipped.
   2. **`/work` executes inline on the native-on-Workflow backend** — the sole executor as of v4.0.0.
   3. **Initiative surface read live from Linear** — `pk next`, `pk status`, `/phase-plan`, `/00-roadmap-review`, `/01-light-spec`, `/sync-linear`, `/10-strategy-sync` derive initiative context from the Linear Initiative/Project hierarchy.
   4. **Strategy-sync nudge** — after a milestone ships, `/strategy-sync` is prompted via `/pk-exit` + convention.
   5. **Pipekit-side ephemeral state** lives **outside the repo** at `${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>/`, resolved by `scripts/pipekit-state-dir.sh`. It holds the `pending-strategy-sync` marker and per-issue pipeline-state records consumed by `pk *` commands. Out-of-repo by design — v1.6.0 placed these at `.pipekit/`, where an active-plan file-guard hook silently blocked writes (#13); the relocation made writes succeed unconditionally.
5. **When drift is suspected, stop and reconcile.** Symptoms: a plan references a Linear issue that doesn't exist; a Linear issue has no corresponding plan. Resolve the mismatch before continuing — drift compounds.

### Known Drift Risks

| Risk | Trigger | Mitigation |
|---|---|---|
| Plan state ≠ Linear state | Mutating Linear state outside `/work` / `pk *` | Use `/work` (or `pk *` for non-execution transitions). Route all execution through Pipekit. |
| Spec in Linear updated after plan generated | Someone edits issue description post-plan | Re-run `/light-spec PROJ-XXX --rebase` (regenerates plan from current spec) |
| Orphan plans | Plan generated for an issue that's since been deleted | Detected via future `/drift-check` skill |
| Orphan Linear issues | Issue created in Linear UI, no corresponding roadmap entry | Caught at `/roadmap-review` |

If drift becomes a recurring pattern in practice, add a `/drift-check` skill for on-demand detection. Don't build it speculatively — measure first. Full spec tracked in [pipekit#1](https://github.com/withpiper/pipekit/issues/1).

### Strategy Sync After a Milestone

After a milestone ships, Strategy docs need to catch up to what was actually built. The trigger is convention, not automation: `/pk-exit` reminds you to run `/strategy-sync`, and `pk doctor` / `/pipekit-help` surface a pending `pending-strategy-sync` marker on the next session.

**Why a nudge instead of auto-running /strategy-sync?** Strategy sync requires human-in-the-loop diff approval (see `/strategy-sync` Phase 5). The reminder nudges rather than acts; the marker is cleared by `/strategy-sync` once updates are applied.

---

## Tooling

### Interactive Skills (for hands-on sessions)

**Stage 0: Foundation**

| Skill | Purpose |
|-------|---------|
| `/concept` | Project-level ideation — produce a concept brief from ideas + existing docs |
| `/define` | Distill concept into full project definition (phases, roles, workflows) |
| `/strategy-create` | Bootstrap strategy docs from project definition |
| `/startup` | Full project bootstrap orchestrator (chains all Stage 0 + setup skills) |
| `/roadmap-create` | Create ROADMAP.md and populate Linear with issues |
| `/phase-plan` | Select execution initiatives, track progress, manage initiative transitions |

**Development Pipeline (v2 daily loop)**

| Command / Skill | Purpose |
|-----------------|---------|
| `/roadmap-review` | Stage 0 gate + health check: completeness, dependencies, spec coverage |
| `/brainstorm` | Feature-level feasibility exploration (within an existing project) |
| `/light-spec` | Structured spec generation with auto-cycled agent review (invokes `pk spec-cycle` and `/light-spec-revise` internally, max 3 passes) |
| `/light-spec-revise` | Apply Spec Review Agent feedback surgically; detects stalemate loops. Usually invoked by `/light-spec` Phase 6, but can be run standalone. |
| `pk spec-cycle <ID>` | Post the Spec Review Agent v5 trigger, poll Linear for the verdict, transition state to Approved on Pass. Owns the `@linear` trigger format and polling — Claude doesn't wait. |
| `/spec-preflight {ISSUE}` | Empirical pre-flight on a specced issue — verifies file paths, symbol/line refs, phase-detect baseline, Linear status against reality. Read-only. Run between Spec Review Agent and `pk branch`. |
| `pk next` | Initiative-aware: derives the current initiative from the Linear-native surface (`i{N}.` initiative → `P{N}.` project; legacy `PHASES.md` falls back), groups Linear results by status with per-group hints |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent) |
| `/work <ID>` | Plan + execute on native-on-Workflow (the sole executor as of v4.0.0). |
| `/pk-express <ISSUE-ID>` | Express lane — idea→Draft-PR autopilot for **simple** WITs (Quick/Standard only). Chains `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify + ship); stops at 5 gates (not-Now, tier:heavy, spec stalemate, verify flag, Draft PR). Resumes from Linear state. Skill, not a Workflow. |
| `/verify` | Pre-deploy gate (types + lint + test); QA subagent if `Require QA review: true`. v2.7.0+: when the diff touches `Migration dir`, spawns a migration-review subagent (`/pr-security-review` rubric M1–M8 + RLS/SECURITY DEFINER/GRANT) and the flag carries a **Hold/Approve verdict** instead of a raw `git show`. Runs every tier; a Hold pauses auto-ship without auto-downgrading status. |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` flags review-in-flight + prints reviewer invocation. |
| `pk ready [<ID>] [--force]` | Flip a Draft PR to Ready (v2.6.0+). Fires `ready_for_review` GH event → outside reviewers (Semgrep + claude-review templates) run. No Linear state change. Refuses on post-verify source/migration drift, or an unreachable verified sha (v4.27.0+); `--force` flips anyway and logs a Linear comment. |
| `/pr-fix` | Pluggable-engine PR review (`--engine=native` pr-review-toolkit default · `--engine=builtin` portable fallback, fail-loud) + dependency-free historical finders (git-history blame-regression + prior-PR-comments reapplication — v2.7.0, run in both engines); two-axis severity×confidence triage with INVESTIGATE quadrant; fixed / rejected / deferred + Linear summary. `--from-review` ingests GHA comments; `--runs=N` raises confidence on recurrence; `--second-opinion=gemini` adds a parallel Gemini Flash read. |
| `/pr-security-review` | Security-focused antagonistic review for migrations / RLS / SECURITY DEFINER / auth |
| `/financial-review` | Periodic financial-accuracy review (finance/calculation-heavy projects). Portable framework; project checks in `resources/financial-review-checks.md`. No-op without a checks file. |
| `pk done <ID> [--merge]` | After PR merge: cleanup worktree+branch, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). v2.6.0+: also auto-pulls integration branch. v2.7.0+: resets the parent branch, prints a stack advisory, and reminds you to deploy when a `Deploy command` is set (script-deploy projects). `--merge` lets pk run `gh pr merge` first. `--confirmed` accepted for backward compat (no-op). |
| `pk promote [<env>]` | **Phase 1** (v2.6.0+): opens promote PR along `Ship environments`. WITs stay in source state. Refuses if any bundled issue is in `UAT`; `--confirmed` bypasses after env-UAT signoff. No arg auto-picks the next ready hop — the earliest pair where the source branch is ahead of the target (2-tier: the only hop; 3+ env: the chain frontier, never skipping ahead). |
| `pk promote <env> --finish` | **Phase 2** (v2.6.0+): after the promote PR merges, transitions bundled WITs → `In <Env>` (intermediate) or → Done (final). Reads the marker from the merged PR body; falls back to PR commits if absent. |
| `pk deploy [<env>] [-- <args>]` | **v4.6.0**: script-deploy front door — runs the configured `Deploy command` for `<env>` (bare / `prod` → `Deploy command`; `pk deploy dev` → `Deploy command dev`; args after `--` pass through). Thin delegate: the deploy script owns confirmation + safety. For projects that ship by script, not branch promotion; branch-promotion projects use `pk promote`. |
| `/pk-exit` | Narrative session log to `Logs/Sessions/<date>_<HHMM>.md`. Last command of every Claude session. |
| `pk status` | Full unscoped Linear board view |
| `pk doctor` | Diagnostic: config, Linear API, worktree dir, stale artifacts. v2.7.0+: **false-ship cross-check** — flags UAT/Done WITs with no real commits on the integration branch (git evidence). |
| `/pipekit-help` | Read project state, recommend the next pipeline step. |
| `/pipekit-update` | Pull latest Pipekit from GitHub into the project (`--push` round-trips improvements back). v2.7.0 **Phase P** also ensures managed plugin dependencies — installs/updates `pr-review-toolkit` at user scope so `/pr-fix`'s native engine resolves. |
| `/review-plan {phase-slug}` | Run plan-reviewer agent against the inline `PLAN.md` (`.pk-work/<ID>-PLAN.md`) before execution — an optional plan-quality gate. |
| `/sync-linear` | Reconcile planning state with the Linear workspace |
| `/strategy-sync` | Post-pipeline: update Strategy docs to reflect shipped features |
| `/release-changelog` | Generate draft CHANGELOG entry from git commits between tags. Output to stdout for human edit. |

Migration deployment is handled by GitHub Actions per the rs-vault pattern (`db-migrate.yml` + `db-pr-check.yml`), not by Pipekit skills.

### Pipekit Agent Roster (for pipeline review)

Agents shipped by Pipekit (synced to consumer projects via `sync-method.sh` → `.claude/agents/`):

| Agent | Role | Invoked by |
|-------|------|------------|
| `plan-reviewer` | Independent review of `/work`'s inline `PLAN.md` (`.pk-work/<ID>-PLAN.md`) before execution. Catches what self-review can't: scope drift, framing errors, atomicity failures, test meaningfulness, risk/trap coverage. Read-only. | `/review-plan` (standalone skill — runs between `/work`'s inline plan and execution) |

### External Systems

| System | Role in Pipeline |
|--------|-----------------|
| Linear | Issue tracking, spec storage, agent review |
| Vercel | Deployment, CI/CD, preview URLs |

Additional integrations (Supabase, Sentry, Langfuse, etc.) are project-specific.

---

## SOPs

Detailed standard operating procedures for each discipline:

| SOP | Covers |
|-----|--------|
| [Git & Deployment](sop/Git_and_Deployment.md) | Branch strategy, worktrees, release flow |
| [Code Quality](sop/Code_Quality.md) | Pre-deploy gates, quality standards |
| [Database](sop/Database_SOP.md) | Schema-change artifact rule, Migration Plan contract, per-tool interface |
| [Linear Configuration](sop/Linear_SOP.md) | Issue tracking, labels, workflow states |
| [Skills](sop/Skills_SOP.md) | Skill authoring, triggers, conventions |

## Templates

| Template | Purpose |
|----------|---------|
| [Light Spec Template](templates/light_spec_template.md) | Standard light spec structure (used by `/light-spec`) |
| [Spec Review Skill](templates/spec_review_skill.md) | Agent review prompt and rubric |
| [Linear Guidance](templates/linear_guidance.md) | Linear agent configuration |

---

## Tiers

`/work` resolves a **tier** for every issue. Tiers shape *which gates apply*; complexity (Low/Medium/High) shapes *how execution is routed*. The two are orthogonal — a Quick-tier issue can be Low or Medium complexity; a Heavy-tier issue always gets the full planning-and-gate treatment (deep `/work` planning + `/review-plan`) regardless of complexity.

| Tier | Use for | Notable behavior |
|------|---------|------------------|
| **Quick** | 1–3 stories, single PR, AC-as-plan | Skips spec review, milestone-readiness, plan review, QA agent. Routes to batch runner. |
| **Standard** (default) | Normal feature work | Full pipeline. Complexity routes execution path. |
| **Heavy** | Security-sensitive, multi-phase, cross-strategy-doc | Adds security review + mandatory `/strategy-sync` before the initiative closes (post-merge, not a per-issue `pk ship`/`pk done` gate). Always full `/work` planning + `/review-plan`. |

Tier inference (label, flag, heuristic) is **always confirmed with the human** before any gate runs — automatic tier escalation/de-escalation is disallowed by design. Per-tier templates live at `templates/tier-{quick,standard,heavy}.md`. Per-project tier configuration lives in `method.config.md` § Tiers.

---

## Project Configuration

Each consuming project maintains a `method.config.md` at its root with project-specific values (Linear workspace, issue prefix, state IDs, environment URLs, pre-deploy commands). Portable skills read this file at runtime. See `method.config.template.md` for the template.

---

## Sync-Safe Overrides

Pipekit syncs upstream content via `scripts/sync-method.sh`, which overwrites `skills/`, `sop/`, `templates/`, and `method.md` on every run. Projects that need to customize a synced file should use the override system rather than editing the synced file directly (which gets clobbered on next sync) or forking the skill (which loses upstream improvements).

### Layout

```
.claude/overrides/
  skills/<name>/SKILL.md        # full-file replacement for a synced skill
  sop/<file>.md                 # full-file replacement for a synced SOP
  method.md.patch               # unified diff applied to pipekit/method.md
  MANIFEST.md                   # human-curated list (what + why)
  .upstream-snapshot/           # managed by sync; do not edit
```

### Behavior

1. `sync-method.sh` first copies upstream files into place (current behavior).
2. Then for each override, the script saves the upstream version it's about to replace into `.upstream-snapshot/`, then applies the override.
3. On the next sync, it compares the new upstream version against the snapshot. If they differ, it surfaces a **drift warning** — upstream changed a file you override, and the override may no longer be appropriate.
4. Patches are applied with `patch --dry-run` first; if the patch can't apply cleanly, sync continues but flags the failure for manual resolution.

### Authoring guidance

- Use **full-file overrides** for skills and SOPs. They're easy to reason about and survive any upstream change.
- Use **patches** for `method.md` (the only patch-target supported). Patches preserve upstream improvements when they don't touch your patched section.
- Always document the override in `MANIFEST.md` with a **why**. Without it, future-you can't tell whether the override is still load-bearing.

See `templates/overrides-manifest.template.md` for the manifest format.

---

## Outcome

This method creates a deterministic, low-ambiguity system for software delivery where:

- AI accelerates output without sacrificing quality
- Agents enforce quality gates at every stage
- Humans retain control over all product decisions
- Ambiguity is caught and resolved before it compounds
