# Pipekit

**v2.6.0** — Last updated: 2026-05-23  *(tier system restored + `bin/pk` worktree-setup polish — see CHANGELOG.md v2.6.0)*

> **v2.4.3.2 status.** Pipekit's daily loop is `bin/pk` + `/work` + `/verify` + `/pk-exit`. The canonical **one-page** operational doc is [`RUNBOOK.md`](./RUNBOOK.md). This document is the **deeper methodology** — pipeline contract, ownership model, fresh-chat discipline, and tooling reference. Read RUNBOOK first if you only need the daily flow; read this if you're onboarding to the system, tuning gates, or reasoning about why a stage exists.
>
> **NEXT.md is retired.** v1 used `NEXT.md` at the project root as a machine-readable "what to do next" pointer. v2 replaces it with `pk next` (reads Linear directly + scopes to the current phase via `PHASES.md` as of v2.1.0). Consuming projects should:
> - Delete any committed `NEXT.md` (`git rm NEXT.md`)
> - Add `notepad.md` to `.gitignore` for personal free-form notes (never committed; replaces NEXT.md as human scratch space)
> - Use `pk next` for the canonical "what's next?" answer
>
> `pk init` (v2.1.1+) seeds a starter `notepad.md` and adds the gitignore line on first run. If a stale `NEXT.md` is present, `pk init` flags it but does not auto-delete.

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

Development Pipeline (repeats per issue, contract-strict):

  Stage 1: Spec          /light-spec → agent review → human review
  Stage 2: Plan + Build  pk branch → /work    (→ /review-plan if vbw backend)
  Stage 3: Verify + Ship /verify → pk ship    (→ /pr-fix | /pr-security-review) → UAT
  Stage 4: Release       pk promote <env> → pk done   (promote walks one hop per call; pk done is cleanup)
  Stage 5: Doc Loop      /strategy-sync       (after UAT)

Per session (not per issue): /pk-exit          (last command of every Claude Code session)
```

**Stage 0** is the *contract* the development pipeline depends on — a set of artifacts (concept, definition, strategy, config, VBW scaffold, Linear map, phase plan) that must exist before the daily loop is safe to run. It's not a script you run once; it's a pre-condition. *How* those artifacts come to exist depends on the project's entry mode (greenfield, brownfield, inherited — see [Entry Modes](#entry-modes) below). **Stages 1-5** consume the contract and repeat per issue.

**Bookends:** `/roadmap-review` validates Stage 0 outputs and plan health before entering the pipeline. `/strategy-sync` updates Strategy docs after features ship — closing the documentation loop.

**Three-layer enforcement.** Conventions live in `CLAUDE.md` (VBW agents read this), hard gates live in CI + hooks (block merges that violate them), and skills are interactive shortcuts for hands-on sessions. The same rule is enforced at multiple layers so neither a missed skill invocation nor a permissive prompt can bypass it.

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

| # | Stage | Step | Tool | Output | Gate |
|---|-------|------|------|--------|------|
| 1 | 1 | **Light Spec** | `/light-spec` | Structured spec stored in Linear | — |
| 2 | 1 | **Agent Review** | Spec Review Agent (in Linear) | Pass/Revise verdict with readiness score | Spec is unambiguous + decomposable without guessing |
| 3 | 1 | **Human Review** | You, in Linear | Approved spec with product decisions locked | Human signs off on scope/decisions/priority |
| 4 | 2 | **Branch** | `pk next` then `pk branch <ID>` | Worktree + branch created, Linear → In Progress | Spec approved, deps met |
| 5 | 2 | **Work** | `/work <ID>` (vbw or native backend per `method.config.md`) | Code committed against verify/done criteria | Verdict gate passes before code is written |
| 5b | 2 | **Plan Review** *(vbw backend, optional)* | `/review-plan` (spawns `plan-reviewer` agent) | Validated `PLAN.md` or revision requests | Plan executable step-by-step without ambiguity |
| 6 | 3 | **Verify** | `/verify` (or `pk verify`) | Pre-deploy gate report — Pass / Partial / Fail with per-AC table; QA subagent if `Require QA review: true` | Gate green; AC satisfied |
| 7 | 3 | **Ship** | `pk ship [--review]` | Branch pushed, PR open, Linear → UAT | Verify passed |
| 7b | 3 | **PR Review** *(opt-in)* | `/pr-fix` and/or `/pr-security-review` | Triage summary in Linear (fixed / rejected / deferred) | Critical/High findings resolved or explicitly deferred |
| 8 | 3 | **UAT** | You (browser / Linear) | Accepted or rejected against spec AC. State is `UAT` while PR is open on preview; flips to `In <FirstEnv>` (e.g. `In Dev`) on `pk done` after merge. | Matches spec under real usage |
| 9 | 4 | **Cleanup** | `pk done <ID> [--merge]` | Worktree + branch cleaned up; commits + diffstat posted to Linear; Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). `--merge` lets pk run `gh pr merge` first. v2.5.0+: regained the state-transition role retired in v2.3.0 — see v2.5.0 CHANGELOG for rationale. | PR merged (or `--merge` passed) |
| 10 | 4 | **Promote** | `pk promote <env>` *(multi-tier projects only)* | One-hop promotion PR per `Ship environments`. Transitions matching issues optimistically: → **`In <Env>`** for intermediate hops (e.g. `pk promote beta` → `In Beta`), → **`Done`** for the final hop (e.g. `pk promote main`). | — |
| 11 | 5 | **Strategy Sync** | `/strategy-sync` | Updated Strategy docs reflecting reality | Code is truth; diffs human-approved before apply |

**Feedback loops:** steps 2, 5b, 6, and 8 can send work backward. Agent review returns specs for revision. Plan review returns plans for rework. Verify returns tasks to dev. UAT returns features to execution. The pipeline is linear by default, corrective when needed.

**Per session (not per issue):** `/pk-exit` writes the narrative session log to `Logs/Sessions/<date>_<HHMM>.md`. Run as the last command of every Claude Code session, regardless of where the issue stands.

**Between phases:** `/phase-plan --next` selects the next batch of issues and promotes them to "Needs Spec." `/roadmap-review` validates before speccing begins.

> **Optional pre-step:** `/brainstorm` — for exploring feature-level ideas within an existing project. For project-level ideation, use `/concept`.

---

## Foundation Contract

The development pipeline (Stages 1-5) is **contract-strict**: every skill in it assumes a specific set of artifacts already exists. If any of these are missing, the daily loop is unsafe — gates can't validate, plans can't reference strategy, Linear sync has no map. The contract below is the minimum surface; how each artifact came to exist is mode-specific (see [Entry Modes](#entry-modes)).

| Artifact | Path | Required for |
|---|---|---|
| Concept brief | `concept-brief.md` | `/define` |
| Project definition | `project-definition.md` | `/strategy-create`, `/roadmap-create` |
| Strategy docs | `Strategy/*.md` | `/light-spec`, `/strategy-sync` |
| Project config | `method.config.md` | All Pipekit skills, `bin/pk` |
| VBW scaffold | `.vbw-planning/` | `/work` (vbw backend), VBW agents |
| Linear-VBW map | `.vbw-planning/linear-map.json` | `pk next`, `/work`, `/sync-linear` |
| Phase plan | `.vbw-planning/PHASES.md` | `pk next` (phase-aware as of v2.1.0), `/phase-plan` |

`/roadmap-review` is the gate that verifies the contract before the dev pipeline begins. `/pipekit-help` and `/startup --mode=inherited` (see [Entry Modes](#entry-modes)) inspect the contract on demand and recommend retrofits when artifacts are missing.

> **Note on completeness vs. existence.** The contract requires that artifacts *exist*; it does not require them to be perfect. `[TBD]` sections in strategy docs are normal at v0.1.0 — the spec pipeline is what fills them in. The contract is a presence check, not a content audit.

---

## Entry Modes

A project can enter the dev pipeline through three legitimate paths. They differ in how the foundation contract gets satisfied — not in what the contract is.

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain (`/concept` → `/define` → `/strategy-create` → `/startup` → `/vbw:init` → `/roadmap-create` → `/phase-plan`) | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield` (stub for now), `/vbw:init`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` (the project already exists; concept/definition are reverse-engineered manually until the deferred `/strategy-from-code` auto-audit skill ships) |
| **Inherited** | New contributor joining a Pipekit project | None — `/startup --mode=inherited` verifies the contract is intact and points to the dev pipeline | All of Stage 0 (artifacts are already on disk) |

`/startup` auto-detects the mode by inspecting project state (no concept-brief + no code → greenfield; code present, no Strategy/ → brownfield; everything present → inherited) and **always confirms with the user** before proceeding — same pattern as tier resolution in `/work`. Mode is never picked silently.

> **`/strategy-from-code` is deferred.** Originally promised for v1.4.0 (2026-04-27) but never built. Brownfield mode currently routes through `/strategy-create` with a manual-edit note: the generated docs reflect the project definition, not the existing code, so you'll want to edit them against reality before the first `/light-spec`. Track interest in the brainstorm backlog if you'd benefit from auto-audit.

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

**Tools:** `/light-spec`, `pk spec-cycle`, `/light-spec-revise`, Spec Review Agent, Human

- `/light-spec` explores the codebase, reads reference material and Strategy docs, and generates a structured spec as an AI→AI contract
- `/light-spec` Phase 6 then runs the **review cycle** automatically: invokes `pk spec-cycle` (which posts the agent trigger, polls Linear for the verdict, and transitions the issue to **Approved** on Pass), and on Revise auto-invokes `/light-spec-revise` for surgical patches before the next cycle pass
- The cycle is hard-capped at 3 passes. On passes 2 and 3 the user is prompted `[Y/n/o]` (continue / bail / drop into `/light-spec-revise`'s override path) so a stalemating agent can't drive infinite revision
- Spec Review Agent enforces planning readiness (Pass/Revise with blocking issues identified)
- Human validates product decisions, scope, and priority
- Iteration continues until Agent passes AND Human approves

**Output:** Planning-safe spec (stored as Linear issue description)

**Gate:** Spec must be unambiguous and decomposable without guessing. All decisions defined or explicitly marked [TBD] (where TBD does not block task decomposition).

---

## Stage 2: Plan + Build (Execution Quality Gate)

**Steps:** 4–5b (`pk branch` → `/work` → optional `/review-plan` for vbw backend)

**Tools:** `pk branch`, `/work`, `plan-reviewer` agent (via `/review-plan`)

- **`pk branch <ID>`** sets up the worktree + branch and transitions Linear to In Progress. Idempotent — rerun is safe.
- **`/work <ID>`** does plan + execute in one skill, gated by a **verdict** (`proceed` / `revise: <feedback>` / `abort`) before any code is written. Tier (Quick / Standard / Heavy) is human-confirmed before the verdict step. Backend dispatch is per `method.config.md`:
  - `Backend: vbw` → `/work` spawns `vbw-lead` (plan) and `vbw-dev` (execute) with `PLAN.md` as the contract.
  - `Backend: native` → `/work` plans + executes in your current Claude session, using parallel `Agent` calls only for grounding.
- **`/review-plan`** *(vbw backend, optional)* spawns the `plan-reviewer` agent against `PLAN.md` between `vbw-lead`'s output and `vbw-dev`'s execution — independent stress-test of scope, atomicity, dependencies, success criteria, and risks.

**Output:** Code committed against verify/done criteria (or `PLAN.md` + execution for the `vbw` backend)

**Gate:** Plan must be executable step-by-step without ambiguity or rework. No task should require the dev agent to make product decisions.

---

## Stage 3: Verify + Ship + UAT (Build Quality Gate)

**Steps:** 6–8 (`/verify` → `pk ship` → optional PR review → **interactive UAT**)

**Tools:** `/verify`, `pk ship`, optional `/pr-fix` and `/pr-security-review`, Human

- **`/verify`** runs the pre-deploy gate from `method.config.md` (types + lint + test). Returns Pass / Partial / Fail with a per-AC table. If `Require QA review: true`, also spawns the QA subagent for goal-backward verification.
- **Auto-rollover**: `/work` auto-invokes `/verify` on successful completion (no prompt). On Pass, `/verify` auto-invokes `pk ship` (gated by the `PIPEKIT_AUTO_SHIP=1` env var that `/work` sets — standalone `/verify` calls do not auto-ship). On Partial / Fail, the rollover stops with the per-AC table; the user fixes and re-runs. Aborts inside `/work` skip the rollover entirely.
- **`pk ship`** pushes the feature branch, opens the PR against the integration branch from config, and transitions Linear → UAT.
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
2. **`pk done <ID> [--merge]`** verifies the merge happened, posts commits + diffstat to Linear, transitions Linear `UAT → In <FirstEnv>` (e.g. `In Dev`), and removes the worktree + branch. For 1-tier projects the transition is `UAT → Done` directly. **Deliberate human step** — must NOT be auto-invoked by `/work`, `/verify`, `/pk-exit`, or any session-automation skill. The worker session that built the feature has no reliable signal for "PR is mergeable AND human is ready" (WIT-451 canary 2026-05-13 — surfaced this gap). v2.5.0+: `--confirmed` is accepted for backward compat but is a no-op (v2.4.3's UAT-refusal gate was removed because `pk done` IS the UAT-out transition).
3. **Exercise the feature on the deployed first env** (e.g. dev). The issue sits in `In <FirstEnv>` while UAT happens.
4. **`pk promote <env> [--confirmed]`** opens the next-tier promotion PR (one hop per invocation: `pk promote beta`, then `pk promote main`). Transitions matching issues optimistically at PR-open: → **`In <Env>`** for intermediate hops (e.g. `In Beta`, `In Staging`), → **`Done`** for the final hop. 2-tier projects: `pk promote` with no arg picks the only hop. Skipped entirely for `Promote to main: false`. **Deliberate human step**, same rationale as `pk done`. v2.4.3+: refuses with `exit 1` if any bundled issue is in `UAT` (PR not merged); pass `--confirmed` once env-UAT is signed off.

**Auto-machinery** firing on PR open / main merge (Pipekit owns none of these — they're project infrastructure):

- **CI** enforces the pre-deploy gate at each PR.
- **Vercel** deploys preview on PR open and prod on main merge.
- **GitHub Actions** (Supabase projects only): `db-pr-check.yml` validates migrations on PR open against ephemeral postgres; `db-migrate.yml` applies them on main merge. Lift the workflow pair from rs-vault if your project doesn't have them yet.

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
| `/light-spec` → `pk branch` + `/work` | The work agent must validate the spec on its merits, not from memory of how it was built |
| `/work` plan-verdict → `/review-plan` (vbw backend) | Plan reviewer must be independent of the planner |
| `/work` execution → `/verify` | QA must verify against goals, not against the executor's narration |
| `pk ship` → `pk ship --review` (or `/pr-security-review`) | Antagonistic reviewer must approach the PR fresh, without the executor's context |
| Any stage → `/strategy-sync` | Strategy sync compares shipped reality to docs; recall of build decisions contaminates the diff |

### When to stay in-session

- Inside `/light-spec` (capture → draft → publish are one stage)
- Inside `/work` for the duration of one issue (plan + execute are designed to share context)
- Reading-only sessions: `pk status`, `pk next`, `/00-roadmap-review`, `/pipekit-help`

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
| `.vbw-planning/phases/*/PLAN.md` | VBW | `vbw-lead` agent (spawned by `/work` when `Backend: vbw`) | `/work`, `/review-plan`, `/phase-plan --status`, vbw-dev/vbw-qa agents |
| `.vbw-planning/.execution-state.json` | VBW | vbw-dev / vbw-qa agents | `/phase-plan --status` |
| `.vbw-planning/linear-map.json` | Pipekit | `/roadmap-create`, `/sync-linear` | `pk next`, `pk *`, all Pipekit skills |
| `.vbw-planning/PHASES.md` | Pipekit | `/phase-plan` | `pk next` (phase-aware), all Pipekit skills |
| `notepad.md` (project root, gitignored) | Human | Whoever's typing | Whoever's reading. v2 retired the auto-written `NEXT.md` mirror — `pk next` reads "what's next?" live from Linear instead. |
| Linear issues | Pipekit | `/light-spec`, `pk branch`, `pk ship`, `pk done`, `/roadmap-create`, `/phase-plan` | Everyone |
| `concept-brief.md`, `project-definition.md`, `Strategy/` | Pipekit | `/concept`, `/define`, `/strategy-create`, `/strategy-sync` | `/light-spec`, vbw-lead |
| `method.config.md` | Pipekit | `/startup` (populates); human (edits) | All Pipekit skills, `bin/pk` |

### Rules of Engagement

1. **VBW owns the planning layer.** `.vbw-planning/ROADMAP.md`, `PLAN.md` files, and execution state are VBW's. Pipekit reads them but does not overwrite them.
2. **Pipekit owns the visibility layer.** Linear issues, `linear-map.json`, `PHASES.md`, strategy docs, and project config are Pipekit's. VBW does not write to these. (v2 retired the `NEXT.md` mirror — `pk next` reads "what's next?" live from Linear.)
3. **Initial merge happens once** — at `/roadmap-create`. Strategy-derived requirements are added **into** VBW's existing phase structure. VBW's phases, goals, and success criteria are preserved verbatim.
4. **After the merge, the split is one-way.** Pipekit reads VBW state (plan progress, execution state) to update Linear. VBW does not read Linear — its source of truth is its own files.
5. **Pipekit owns gates; VBW owns build.** `pk branch` opens Linear → In Progress; `/work` (with `Backend: vbw`) dispatches `vbw-lead` and `vbw-dev`; `/verify` runs the pre-deploy gate; `pk ship` transitions Linear → UAT (PR open on preview); `pk done` verifies merge, transitions Linear UAT → `In <FirstEnv>` (e.g. `In Dev`), cleans up the worktree; `pk promote <env>` walks `Ship environments` one hop at a time and transitions issues → `In <Env>` (intermediate) or → Done (final). The plan-review gate (Pipekit's value-add over raw VBW) lives in the standalone `/review-plan` skill, which spawns the `plan-reviewer` agent at `model: opus` between `vbw-lead`'s plan and `vbw-dev`'s execution.

   **Pipekit's VBW-steering surface:**
   1. **One direct agent spawn** — `plan-reviewer` in `/review-plan`. Not a VBW agent; Pipekit-shipped.
   2. **`/work` dispatches VBW agents (vbw backend) or runs in-context (native backend).** Backend choice is per-project in `method.config.md`; per-invocation override via `--backend=`.
   3. **Read-only state observation** — `.vbw-planning/{ROADMAP,STATE,PHASES,linear-map}.md` reads from `/sync-linear`, `/phase-plan`, `/00-roadmap-review`, `/01-light-spec`, `/10-strategy-sync`, `pk next`, `pk status`.
   4. **One lifecycle hook** — `scripts/pipekit-post-archive.sh` fires on `/vbw:vibe --archive`, writes a `pending-strategy-sync` marker into Pipekit's machine-local state directory.
   5. **Pipekit-side ephemeral state** lives **outside the repo** at `${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>/`, resolved by `scripts/pipekit-state-dir.sh`. It holds the `pending-strategy-sync` marker and per-issue pipeline-state records consumed by `pk *` commands. Out-of-repo by design — v1.6.0 placed these at `.pipekit/`, but VBW's file-guard hook silently blocked writes during active-plan scope (#13). The relocation made writes succeed unconditionally.

   No direct VBW-agent spawns outside `/work`. No execution-flow wrapping. VBW upgrades touch zero Pipekit code.
6. **When drift is suspected, stop and reconcile.** Symptoms: Linear status doesn't match VBW execution state; a PLAN.md references a Linear issue that doesn't exist; a Linear issue has no corresponding plan. Resolve the mismatch before continuing — drift compounds.

### Known Drift Risks

| Risk | Trigger | Mitigation |
|---|---|---|
| Plan state ≠ Linear state | Running VBW agents directly, not via `/work` | Use `/work` (or `pk *` for non-execution transitions). Route all execution through Pipekit. |
| Spec in Linear updated after plan generated | Someone edits issue description post-plan | Re-run `/light-spec PROJ-XXX --rebase` (regenerates plan from current spec) |
| Orphan plans | Plan generated for an issue that's since been deleted | Detected via future `/drift-check` skill |
| Orphan Linear issues | Issue created in Linear UI, no corresponding roadmap entry | Caught at `/roadmap-review` |

If drift becomes a recurring pattern in practice, add a `/drift-check` skill for on-demand detection. Don't build it speculatively — measure first. Full spec tracked in [pipekit#1](https://github.com/withpiper/pipekit/issues/1).

### Event Hook: Post-Archive → Strategy Sync

VBW v1.35.0 added a post-archive lifecycle hook (PR #481) that fires after `/vbw:vibe --archive` completes. Pipekit ships `scripts/pipekit-post-archive.sh` to wire this into the strategy-sync loop — when a milestone is archived, the hook writes a `pending-strategy-sync` marker into Pipekit's machine-local state directory (out-of-repo, v1.7.0+) that `pk doctor` and `/pipekit-help` surface on the next session, nudging the user to run `/strategy-sync`.

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

**Development Pipeline (v2 daily loop)**

| Command / Skill | Purpose |
|-----------------|---------|
| `/roadmap-review` | Stage 0 gate + health check: completeness, dependencies, spec coverage |
| `/brainstorm` | Feature-level feasibility exploration (within an existing project) |
| `/light-spec` | Structured spec generation with auto-cycled agent review (invokes `pk spec-cycle` and `/light-spec-revise` internally, max 3 passes) |
| `/light-spec-revise` | Apply Spec Review Agent feedback surgically; detects stalemate loops. Usually invoked by `/light-spec` Phase 6, but can be run standalone. |
| `pk spec-cycle <ID>` | Post the Spec Review Agent v5 trigger, poll Linear for the verdict, transition state to Approved on Pass. Owns the `@linear` trigger format and polling — Claude doesn't wait. |
| `/spec-preflight {ISSUE}` | Empirical pre-flight on a specced issue — verifies file paths, line refs, phase-detect baseline, Linear status against reality. Read-only. Run between Spec Review Agent and `pk branch`. |
| `pk next` | Phase-aware: groups Linear results by status with per-group hints |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent) |
| `/work <ID>` | Plan + execute. Dispatches to `vbw` or `native` backend per `method.config.md`. Per-invocation override via `--backend=`. |
| `/verify` | Pre-deploy gate (types + lint + test); QA subagent if `Require QA review: true` |
| `pk ship [--review]` | Push, open PR, Linear → UAT (PR open on preview branch). `--review` flags review-in-flight + prints reviewer invocation. |
| `/pr-fix` | Triage PR review findings: fixed / rejected / deferred, with Linear summary |
| `/pr-security-review` | Security-focused antagonistic review for migrations / RLS / SECURITY DEFINER / auth |
| `pk done <ID> [--merge]` | After PR merge: cleanup worktree+branch, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). `--merge` lets pk run `gh pr merge` first. `--confirmed` accepted for backward compat (no-op v2.5.0+). |
| `pk promote <env> [--confirmed]` | One-hop promotion along `Ship environments`. Transitions matching issues → `In <Env>` (intermediate hops, e.g. `In Beta`) or → Done (final hop). 2-tier projects: `pk promote` with no arg auto-picks the only hop. v2.4.3+: refuses if any bundled issue is in `UAT` (PR not merged); `--confirmed` bypasses after env-UAT signoff. |
| `/pk-exit` | Narrative session log to `Logs/Sessions/<date>_<HHMM>.md`. Last command of every Claude session. |
| `pk status` | Full unscoped Linear board view |
| `/pipekit-help` | Read project state, recommend the next pipeline step. |
| `/review-plan {phase-slug}` | Run plan-reviewer agent against PLAN.md (vbw backend). Run between vbw-lead's plan and vbw-dev's execution. |
| `/sync-linear` | Bidirectional VBW ↔ Linear sync |
| `/strategy-sync` | Post-pipeline: update Strategy docs to reflect shipped features |
| `/release-changelog` | Generate draft CHANGELOG entry from git commits between tags. Output to stdout for human edit. |

Migration deployment is handled by GitHub Actions per the rs-vault pattern (`db-migrate.yml` + `db-pr-check.yml`), not by Pipekit skills.

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

`/work` resolves a **tier** for every issue. Tiers shape *which gates apply*; complexity (Low/Medium/High) shapes *how execution is routed*. The two are orthogonal — a Quick-tier issue can be Low or Medium complexity; a Heavy-tier issue is always routed through full VBW planning regardless of complexity.

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
