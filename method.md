# Pipekit

**Last updated:** 2026-04-08 *(content predates v2 cut; see banner below)*

> ⚠️ **v2 transition (2026-05-02):** Pipekit's daily loop has been replaced by `bin/pk` + `/work` + `/verify`. The canonical operational doc is now [`RUNBOOK.md`](./RUNBOOK.md). References below to `/launch`, `/branch`, `/start-session`, `/end-session`, `/linear-status`, `/g-promote-*` describe the **retired v1 daily loop** — those skills now live under `archive/v1-skills/` and are no longer the recommended path. Stage 0 (foundation) and orthogonal skills (`/light-spec`, `/brainstorm`, `/pr-fix`, etc.) are unchanged. A full method.md rewrite is queued for v2.0.1.

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
  /concept → /define → /strategy-create → /startup → /vbw:init → /roadmap-create → /phase-plan

Stages 1-5: Development Pipeline (repeats per phase/feature, contract-strict)
  [Roadmap Review] → Light Spec → Agent Review → Human Review → Launch →
  VBW Plan → Plan Review → Execution → QA → UAT → Ship → [Strategy Sync]
```

**Stage 0** is the *contract* the development pipeline depends on — a set of artifacts (concept, definition, strategy, config, VBW scaffold, Linear map, phase plan) that must exist before `/launch` is safe to run. It's not a script you run once; it's a pre-condition. *How* those artifacts come to exist depends on the project's entry mode (greenfield, brownfield, inherited — see [Entry Modes](#entry-modes) below). **Stages 1-5** consume the contract and repeat per phase of features.

**Bookends:** `/roadmap-review` validates Stage 0 outputs and plan health before entering the pipeline. `/strategy-sync` updates Strategy docs after features ship — closing the documentation loop.

### Step-by-Step

#### Stage 0: Foundation

| # | Step | Tool | Input | Output | Gate |
|---|------|------|-------|--------|------|
| 0.1 | **Concept** | `/concept` | Raw idea + existing docs | `concept-brief.md` | Idea is specific enough to define |
| 0.2 | **Define** | `/define` | Concept brief | `project-definition.md` | Definition supports tech stack + strategy decisions |
| 0.3 | **Strategy Create** | `/strategy-create` | Project definition | `Strategy/` docs (incl. Design Direction) | Docs describe a coherent product |
| 0.4 | **Infra Setup** | `/startup` (Steps 3-6) | Tech stack decisions | Working repo, DB, deploy, MCP | Pre-deploy gate passes |
| 0.5 | **VBW Init** | `/vbw:init` | — | `.vbw-planning/` scaffold | Directory exists |
| 0.6 | **Roadmap** | `/roadmap-create` | Strategy docs + definition | `ROADMAP.md` + populated Linear | Every requirement has an issue |
| 0.7 | **Phase Plan** | `/phase-plan` | Populated Linear board | First phase in "Needs Spec" | Dependencies clear, phase sized |

Stage 0 is the foundation contract — a set of artifacts, not a script. The greenfield flow above is one of three entry modes (see [Entry Modes](#entry-modes)). `/startup` orchestrates whichever mode applies.

#### Stages 1-5: Development Pipeline

| # | Step | Tool | Input | Output | Gate |
|---|------|------|-------|--------|------|
| 0 | **Roadmap Review** | `/roadmap-review` | ROADMAP, Linear state, PHASES.md | Health report: Stage 0 check, gaps, ordering, spec coverage, doc freshness | Stage 0 complete, plan coherent |
| 1 | **Light Spec** | `/light-spec` + Linear | Feature idea or issue | Structured spec exploring codebase and Strategy docs | — |
| 2 | **Agent Review** | Linear Spec Review Agent | Light spec | Pass/Revise verdict with readiness score | Spec must be unambiguous and decomposable without guessing |
| 3 | **Human Review** | You in Linear | Agent-reviewed spec | Approved spec with product decisions locked | Human signs off on scope, decisions, and priority |
| 4 | **Launch (open)** | `/launch {ISSUE}` | Approved spec | Gates validated, complexity routed, issue → Building, handoff text written | Spec exists, deps met, milestone siblings all specced |
| 5 | **VBW Plan** | `/vbw:vibe --plan {phase-slug}` (user-triggered) | Approved spec from Linear | `PLAN.md` with task decomposition, verify/done criteria | — (Low complexity skips to batch runner) |
| 6 | **Plan Review** | `/review-plan {phase-slug}` (Pipekit skill, calls `plan-reviewer` agent) | PLAN.md | Validated plan or revision requests | Plan must be executable step-by-step without ambiguity |
| 7 | **Execution** | `/vbw:vibe --execute` (user-triggered) or `/linear-todo-runner` (for Low complexity) | Approved plan or AC | Atomic commits per task | Each task passes its own verify/done criteria |
| 8 | **QA** | `/vbw:vibe --verify` (user-triggered, VBW-native layouts only) or project-precedent self-verification | Completed tasks | Verification report (or precedent equivalent) | All tasks verified against goals |
| 9 | **Launch (close)** | `/launch {ISSUE} --close` | Verify-passed signal | Linear status → UAT, Linear comment posted | User confirmed verify passed |
| 10 | **UAT** | You | Built feature | Accepted or rejected | Feature matches spec AC under real usage |
| 11 | **Ship** | Promotion skills | Accepted feature | Production release | CI gates pass, smoke tests pass |
| 12 | **Strategy Sync** | `/strategy-sync` | Shipped features, current Strategy docs | Updated docs reflecting reality | Code is truth; diffs approved before apply |

**Feedback loops:** Steps 2, 6, 8, and 9 can send work backward. Agent review returns specs for revision. Plan review returns plans for rework. QA returns tasks to dev. UAT returns features to execution. The pipeline is linear by default, corrective when needed.

**Between phases:** `/phase-plan --next` selects the next batch of issues and promotes them to "Needs Spec." `/roadmap-review` validates before speccing begins.

> **Optional pre-step:** `/brainstorm` — for exploring feature-level ideas within an existing project. For project-level ideation, use `/concept`.

---

## Foundation Contract

The development pipeline (Stages 1-5) is **contract-strict**: every skill in it assumes a specific set of artifacts already exists. If any of these are missing, `/launch` is unsafe — gates can't validate, plans can't reference strategy, Linear sync has no map. The contract below is the minimum surface; how each artifact came to exist is mode-specific (see [Entry Modes](#entry-modes)).

| Artifact | Path | Required for |
|---|---|---|
| Concept brief | `concept-brief.md` | `/define` |
| Project definition | `project-definition.md` | `/strategy-create`, `/roadmap-create` |
| Strategy docs | `Strategy/*.md` | `/light-spec`, `/strategy-sync` |
| Project config | `method.config.md` | All Pipekit skills |
| VBW scaffold | `.vbw-planning/` | `/launch`, VBW agents |
| Linear-VBW map | `.vbw-planning/linear-map.json` | `/launch`, `/sync-linear` |
| Phase plan | `.vbw-planning/PHASES.md` | `/launch`, `/phase-plan` |

`/roadmap-review` is the gate that verifies the contract before the dev pipeline begins. `/pipekit-help` and `/startup --mode=inherited` (see [Entry Modes](#entry-modes)) inspect the contract on demand and recommend retrofits when artifacts are missing.

> **Note on completeness vs. existence.** The contract requires that artifacts *exist*; it does not require them to be perfect. `[TBD]` sections in strategy docs are normal at v0.1.0 — the spec pipeline is what fills them in. The contract is a presence check, not a content audit.

---

## Entry Modes

A project can enter the dev pipeline through three legitimate paths. They differ in how the foundation contract gets satisfied — not in what the contract is.

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain (`/concept` → `/define` → `/strategy-create` → `/startup` → `/vbw:init` → `/roadmap-create` → `/phase-plan`) | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield` (stub for now), `/vbw:init`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` (the project already exists; concept/definition are reverse-engineered manually or via the v1.4.0 `/strategy-from-code` skill) |
| **Inherited** | New contributor joining a Pipekit project | None — `/startup --mode=inherited` verifies the contract is intact and points to the dev pipeline | All of Stage 0 (artifacts are already on disk) |

`/startup` auto-detects the mode by inspecting project state (no concept-brief + no code → greenfield; code present, no Strategy/ → brownfield; everything present → inherited) and **always confirms with the user** before proceeding — same pattern as tier resolution in `/launch`. Mode is never picked silently.

> **`/strategy-from-code` is deferred to v1.4.0.** Brownfield mode currently routes through `/strategy-create` with a manual-edit note: the generated docs reflect the project definition, not the existing code, so you'll want to edit them against reality before the first `/light-spec`.

---

## Stage 0: Foundation

**Steps:** 0.1–0.7 (Concept → Define → Strategy → Setup → VBW Init → Roadmap → Phase Plan)

**Tools:** `/concept`, `/define`, `/strategy-create`, `/startup`, `/vbw:init`, `/roadmap-create`, `/phase-plan`

Stage 0 is the contract above (Foundation Contract), not a script. The greenfield path runs all seven skills in order. Brownfield skips the first two. Inherited skips the entire stage and just verifies the artifacts. See [Entry Modes](#entry-modes) for which path applies to your project. This section documents the greenfield flow; the others are variations on it.

- `/concept` captures the idea and assesses viability — supports ingesting existing documents (proposals, research, notes)
- `/define` distills the concept into stages, roles, workflows, and success criteria
- `/strategy-create` generates configurable strategy docs (doc set defined in `method.config.md`)
- `/startup` orchestrates the full flow and handles infrastructure (repo, DB, deploy, MCP, Linear)
- `/vbw:init` scaffolds `.vbw-planning/` for the planning engine
- `/roadmap-create` extracts requirements from strategy docs and populates both ROADMAP.md and Linear
- `/phase-plan` selects 3-8 issues for the first execution phase

**Output:** `concept-brief.md`, `project-definition.md`, `Strategy/` docs, working infrastructure, `.vbw-planning/ROADMAP.md`, populated Linear board, `.vbw-planning/PHASES.md` with first phase defined.

**Gate:** `/roadmap-review` validates all Stage 0 outputs before the spec pipeline begins.

---

## Pre-Condition: Roadmap Review

**Step:** 0

**Tools:** `/roadmap-review`

Run before entering the spec pipeline to validate that Stage 0 is complete and the roadmap is coherent: concept and definition exist, strategy docs match config, all requirements have Linear issues, dependencies are set, workflow states are consistent, current phase is defined, and spec coverage is adequate. Also flags Strategy doc staleness (recommends `/strategy-sync` if needed).

**Output:** Health report with action items. Resolve blockers before speccing.

---

## Stage 1: Definition (Spec Quality Gate)

**Steps:** 1–3 (Light Spec → Agent Review → Human Review)
**Pre-condition:** Roadmap Review (Step 0) must pass

**Tools:** `/light-spec`, Spec Review Agent, Human

- `/light-spec` explores the codebase, reads reference material and Strategy docs, and generates a structured spec as an AI→AI contract
- Spec Review Agent enforces planning readiness (Pass/Revise with blocking issues identified)
- Human validates product decisions, scope, and priority
- Iteration continues until Agent passes AND Human approves

**Output:** Planning-safe spec (stored as Linear issue description)

**Gate:** Spec must be unambiguous and decomposable without guessing. All decisions defined or explicitly marked [TBD] (where TBD does not block task decomposition).

---

## Stage 2: Launch & Planning (Execution Quality Gate)

**Steps:** 4–6 (Launch → VBW Plan → Plan Review)


**Tools:** `/launch`, VBW Lead Agent, `plan-reviewer` agent

- `/launch {ISSUE}` validates three gates: spec exists, dependencies met, milestone siblings all specced (Gate C)
- Routes by complexity: Low → batch runner (AC is the plan), Medium/High → VBW planning
- Moves issue to Building and posts a Linear comment with gate results
- Lead agent reads the approved spec from Linear, decomposes into tasks, generates `PLAN.md`
- Each task has verify and done criteria derived from the spec's Acceptance Criteria
- Plan reviewer stress-tests scope, dependencies, success criteria, and risks

**Output:** Execution-safe plan (`.vbw-planning/phases/*/PLAN.md`), or batch-runner queue for Low complexity

**Gate:** Plan must be executable step-by-step without ambiguity or rework. No task should require the dev agent to make product decisions.

---

## Stage 3: Execution (Build Quality Gate)

**Steps:** 7–9 (Execution → QA → UAT)

**Tools:** VBW Dev Agent, `/linear-todo-runner`, VBW QA Agent, Human

- Dev agent executes atomic tasks with one commit per task
- `/linear-todo-runner` can batch-process multiple specced issues in parallel (requires AC section)
- QA agent verifies completed work using goal-backward methodology
- Human performs acceptance testing against the spec's AC

**Output:** Shippable feature

**Gate:** Feature must match spec behaviour and pass real usage. All AC checkboxes satisfied.

---

## Stage 4: Release

**Steps:** 10 (Ship)

Every step forward is a PR. No direct merges between long-lived branches. Each project defines its own promotion skills (e.g., `/g-promote-dev`, `/g-promote-beta`, `/g-promote-main`).

- CI enforces pre-deploy gate at each PR
- Post-deploy smoke tests confirm the release

**Output:** Production release

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

**Cadence:** After UAT passes for a phase, before stakeholder presentations, before onboarding new team members.

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

Pipeline stages are AI→AI contracts. The contract only holds if each stage's agent reads the prior stage's output **as a document**, not as recalled conversation. A reviewer who watched the spec get drafted is no longer an independent reviewer; a planner who absorbed the launch handoff carries assumptions the spec didn't make explicit.

**Rule:** start a new conversation when crossing a stage boundary. Inside a stage, one chat is fine.

### When to start fresh

| Crossing | Why fresh |
|---|---|
| `/light-spec` → `/light-spec-revise` (after agent review) | Reviser must read the published spec + agent comment as documents, not recall the draft session |
| `/light-spec` → `/launch` | Gate controller must validate the spec on its merits, not from memory of how it was built |
| `/launch` → `/vbw:vibe --plan` | VBW Lead reads the Linear spec as a contract; prior context biases decomposition |
| `/vbw:vibe --plan` → `/review-plan` | Plan reviewer must be independent of the planner |
| `/vbw:vibe --execute` → `/vbw:vibe --verify` | QA must verify against goals, not against the executor's narration |
| Any stage → `/strategy-sync` | Strategy sync compares shipped reality to docs; recall of build decisions contaminates the diff |

### When to stay in-session

- Inside `/light-spec` (capture → draft → publish are one stage)
- Inside `/launch` open + immediate planning kickoff if VBW handoff is mechanical
- Inside execution (multiple `/vbw:vibe --execute` runs on the same plan)
- Reading-only sessions: `/start-session`, `/linear-status`, `/00-roadmap-review`

### Why this matters more than it looks

The spec-as-contract principle ("no stage may introduce guesswork into the next stage") only works if the next stage is genuinely downstream. A long-running session collapses the stages into one agent making all decisions with shared context, which is the failure mode this whole pipeline exists to prevent. Fresh chats are the cheapest possible enforcement.

---

## Three-Layer Enforcement Model

| Layer | Purpose | Who it serves |
|---|---|---|
| **CLAUDE.md** | Documents conventions so VBW agents follow them automatically | VBW dev agents during plan execution |
| **CI / Hooks** | Hard enforcement — blocks merges that violate conventions | Everyone (agents and humans) |
| **Skills** | Interactive shortcuts for hands-on sessions | You, when working with Claude directly |

Skills are convenience wrappers. They automate the same conventions documented in CLAUDE.md. VBW agents don't call skills — they read CLAUDE.md and write code directly.

---

## VBW / Pipekit Ownership Model

Pipekit wraps VBW — it does not replace VBW's planning layer. The two systems must not compete for the same source of truth, or you'll spend more time reconciling than building. The boundaries below make ownership explicit.

### Ownership Table

| File / System | Owned by | Writers | Readers |
|---|---|---|---|
| `.vbw-planning/ROADMAP.md` | VBW | `/vbw:init` creates it; `/roadmap-create` merges strategy-derived requirements **into** it (never overwrites) | All Pipekit skills, VBW agents |
| `.vbw-planning/phases/*/PLAN.md` | VBW | VBW Lead Agent (spawned by `/launch`) | `/launch`, `/phase-plan --status`, VBW Dev/QA agents |
| `.vbw-planning/.execution-state.json` | VBW | VBW Dev/QA agents | `/phase-plan --status` |
| `.vbw-planning/linear-map.json` | Pipekit | `/roadmap-create`, `/sync-linear` | All Pipekit skills |
| `.vbw-planning/PHASES.md` | Pipekit | `/phase-plan` | All Pipekit skills |
| `NEXT.md` (project root) | Pipekit | Every skill that emits `➜ Next:` | `/start-session`, humans |
| Linear issues | Pipekit | `/light-spec`, `/launch`, `/roadmap-create`, `/phase-plan` | Everyone |
| `concept-brief.md`, `project-definition.md`, `Strategy/` | Pipekit | `/concept`, `/define`, `/strategy-create`, `/strategy-sync` | `/light-spec`, VBW Lead |
| `method.config.md` | Pipekit | `/startup` (populates); human (edits) | All Pipekit skills |

### Rules of Engagement

1. **VBW owns the planning layer.** `.vbw-planning/ROADMAP.md`, `PLAN.md` files, and execution state are VBW's. Pipekit reads them but does not overwrite them.
2. **Pipekit owns the visibility layer.** Linear issues, `linear-map.json`, `PHASES.md`, `NEXT.md`, strategy docs, and project config are Pipekit's. VBW does not write to these.
3. **Initial merge happens once** — at `/roadmap-create`. Strategy-derived requirements are added **into** VBW's existing phase structure. VBW's phases, goals, and success criteria are preserved verbatim.
4. **After the merge, the split is one-way.** Pipekit reads VBW state (plan progress, execution state) to update Linear. VBW does not read Linear — its source of truth is its own files.
5. **Pipekit owns gates; VBW owns build.** `/launch` (open) validates Linear gates and hands off; `/launch --close` transitions Linear to UAT. Between those, the user runs `/vbw:vibe --plan` → `/review-plan` → `/vbw:vibe --execute` → `/vbw:vibe --verify`. Pipekit does not spawn any VBW agents directly from `/launch`. The plan-review gate (Pipekit's value-add over raw VBW) lives in the standalone `/review-plan` skill, which spawns the `plan-reviewer` agent at `model: opus`.

   **Pipekit's VBW-steering surface (Tier 1 / Option 3 architecture, 2026-04-25):**
   1. **One direct agent spawn** — `plan-reviewer` in `/review-plan`. Not a VBW agent; Pipekit-shipped.
   2. **Read-only state observation** — `.vbw-planning/{ROADMAP,STATE,PHASES,linear-map}.md` reads from `/sync-linear`, `/phase-plan`, `/00-roadmap-review`, `/01-light-spec`, `/10-strategy-sync`, `/end-session`.
   3. **One lifecycle hook** — `scripts/pipekit-post-archive.sh` fires on `/vbw:vibe --archive`, writes a `pending-strategy-sync` marker into Pipekit's machine-local state directory.
   4. **Pipekit-side ephemeral state** (v1.6.0+, relocated v1.7.0) — Pipekit's machine-local state lives **outside the repo** at `${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>/`, resolved by `scripts/pipekit-state-dir.sh`. It holds: `pending-strategy-sync` marker, `pending-next-md.json` queue (deferred NEXT.md writes), and `pipeline-state/<issue-id>.json` records (per-skill transition state, consumed by `/launch --auto`). v1.6.0 placed these inside the repo at `.pipekit/`, but VBW's file-guard hook silently blocked the writes during active-plan scope (#13) — the relocation makes them invisible to VBW's hook, so writes succeed unconditionally.

   No direct VBW-agent spawns. No execution-flow wrapping. VBW upgrades touch zero Pipekit code.
6. **When drift is suspected, stop and reconcile.** Symptoms: Linear status doesn't match VBW execution state; a PLAN.md references a Linear issue that doesn't exist; a Linear issue has no corresponding plan. Resolve the mismatch before continuing — drift compounds.

### Known Drift Risks

| Risk | Trigger | Mitigation |
|---|---|---|
| Plan state ≠ Linear state | Running VBW agents directly, not via `/launch` | Use `/launch`. Route all execution through Pipekit. |
| Spec in Linear updated after plan generated | Someone edits issue description post-plan | Re-run `/light-spec PROJ-XXX --rebase` (regenerates plan from current spec) |
| Orphan plans | Plan generated for an issue that's since been deleted | Detected via future `/drift-check` skill |
| Orphan Linear issues | Issue created in Linear UI, no corresponding roadmap entry | Caught at `/roadmap-review` |

If drift becomes a recurring pattern in practice, add a `/drift-check` skill for on-demand detection. Don't build it speculatively — measure first. Full spec tracked in [pipekit#1](https://github.com/withpiper/pipekit/issues/1).

### Event Hook: Post-Archive → Strategy Sync

VBW v1.35.0 added a post-archive lifecycle hook (PR #481) that fires after `/vbw:vibe --archive` completes. Pipekit ships `scripts/pipekit-post-archive.sh` to wire this into the strategy-sync loop — when a milestone is archived, the hook writes a `pending-strategy-sync` marker into Pipekit's machine-local state directory (out-of-repo, v1.7.0+) that `/start-session` surfaces on the next session, nudging the user to run `/strategy-sync`.

This is the first concrete instance of the event-based wrapping discussed in Rule 5 above. It replaces the previous convention ("remember to run /strategy-sync after shipping") with a hook that fires deterministically without Pipekit re-implementing VBW's archive flow.

**Registration.** Add the hook to `.vbw-planning/config.json`:

```json
{
  "hooks": {
    "post_archive": "scripts/pipekit-post-archive.sh"
  }
}
```

VBW resolves the path relative to the project root. The hook is fail-open — if it errors, VBW continues the archive.

**Why a marker instead of auto-running /strategy-sync?** Strategy sync requires human-in-the-loop diff approval (see `/strategy-sync` Phase 5). A hook cannot own human approval, so it nudges rather than acts. The marker is cleared by `/strategy-sync` once updates are applied.

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
| `/phase-plan` | Select execution phases, track progress, manage phase transitions |

**Development Pipeline**

| Skill | Purpose |
|-------|---------|
| `/roadmap-review` | Stage 0 gate + health check: completeness, dependencies, spec coverage |
| `/brainstorm` | Feature-level feasibility exploration (within an existing project) |
| `/light-spec` | Structured spec generation with agent review |
| `/spec-preflight {ISSUE}` | Empirical pre-flight on a specced issue — verifies file paths, line refs, phase-detect baseline, Linear status against reality. Read-only. Run between Spec Review Agent and `/launch`. |
| `/launch {ISSUE}` | Open: validate Linear gates, route by complexity, transition to Building, hand off to VBW |
| `/launch {ISSUE} --close` | Close: transition Linear to UAT after VBW pipeline complete + verify passed |
| `/launch {ISSUE} --auto` | Standard tier only: auto-chain Lead → plan-review → Dev → QA → close. Pauses only at plan-review and QA verdicts (3 human inputs total). |
| `/launch --milestone {WP}` | Launch all ready issues in a milestone |
| `/pipekit-help` | Read project state, recommend the next pipeline step. Use when you don't know what to run next. |
| `/review-plan {phase-slug}` | Run plan-reviewer agent against VBW-generated PLAN.md. Run between `/vbw:vibe --plan` and `/vbw:vibe --execute`. |
| `/linear-todo-runner` | Batch execution of specced issues (called by `/launch` for Low complexity) |
| `/sync-linear` | Bidirectional VBW ↔ Linear sync |
| `/branch` | Create worktree + branch + optional Linear link |
| `/start-session` | Review past progress, capture session intentions |
| `/end-session` | Session wrap-up: changelog, Linear updates |
| `/strategy-sync` | Post-pipeline: update Strategy docs to reflect shipped features |
| `/release-changelog` | Generate draft CHANGELOG entry from git commits between tags. Output to stdout for human edit. Pipekit-internal release tooling. |

Project-specific promotion and deploy skills are defined per project (not in this repo).

### VBW Agent Roster (for automated execution)

| Agent | Role |
|-------|------|
| Architect | Requirements → roadmap, stage decomposition |
| Lead | Research, task decomposition, plan generation |
| Dev | Plan execution with atomic commits |
| QA | Goal-backward verification |
| Debugger | Scientific method bug diagnosis |
| Docs | Documentation generation |
| Scout | Research and codebase scanning |

### Pipekit Agent Roster (for pipeline review)

Agents shipped by Pipekit (synced to consumer projects via `sync-method.sh` → `.claude/agents/`):

| Agent | Role | Invoked by |
|-------|------|------------|
| `plan-reviewer` | Independent review of VBW Lead's `PLAN.md` before Dev execution. Fills the gap VBW Lead's Stage 3 self-review can't cover: scope drift, framing errors, atomicity failures, test meaningfulness, risk/trap coverage. Read-only. | `/review-plan` (standalone skill — runs between `/vbw:vibe --plan` and `/vbw:vibe --execute`) |

### External Systems

| System | Role in Pipeline |
|--------|-----------------|
| Linear | Issue tracking, spec storage, agent review |
| VBW | Planning engine (PLAN.md, execution state) |
| Vercel | Deployment, CI/CD, preview URLs |

Additional integrations (Supabase, Sentry, Langfuse, etc.) are project-specific.

---

## SOPs

Detailed standard operating procedures for each discipline:

| SOP | Covers |
|-----|--------|
| [Git & Deployment](sop/Git_and_Deployment.md) | Branch strategy, worktrees, release flow |
| [Code Quality](sop/Code_Quality.md) | Pre-deploy gates, quality standards |
| [Linear Configuration](sop/Linear_SOP.md) | Issue tracking, labels, workflow states |
| [Skills](sop/Skills_SOP.md) | Skill authoring, triggers, conventions |
| [VBW Help](sop/VBW_Help.md) | VBW plugin reference |

## Templates

| Template | Purpose |
|----------|---------|
| [Light Spec Template](templates/light_spec_template.md) | Standard light spec structure (used by `/light-spec`) |
| [Spec Review Skill](templates/spec_review_skill.md) | Agent review prompt and rubric |
| [Linear Guidance](templates/linear_guidance.md) | Linear agent configuration |

---

## Tiers

`/launch` resolves a **tier** for every issue. Tiers shape *which gates apply*; complexity (Low/Medium/High) shapes *how execution is routed*. The two are orthogonal — a Quick-tier issue can be Low or Medium complexity; a Heavy-tier issue is always routed through full VBW planning regardless of complexity.

| Tier | Use for | Notable behavior |
|------|---------|------------------|
| **Quick** | 1–3 stories, single PR, AC-as-plan | Skips spec review, milestone-readiness, plan review, QA agent. Routes to batch runner. |
| **Standard** (default) | Normal feature work | Full pipeline. Complexity routes execution path. |
| **Heavy** | Security-sensitive, multi-phase, cross-strategy-doc | Adds security review + mandatory `/strategy-sync` before close. Always full VBW planning. |

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
  skills/<name>/skill.md        # full-file replacement for a synced skill
  sop/<file>.md                 # full-file replacement for a synced SOP
  method.md.patch               # unified diff applied to method/method.md
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
