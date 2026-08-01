# Pipekit — Instruction Manual

A complete guide to using Pipekit from project inception through production delivery. This document covers every stage, every skill, and every decision point in the pipeline.

**v4.26.3** — Last updated: 2026-08-01  *(**v4.26.3 — closed the one spot v4.26.2's cleanup missed.** SiteLine's `claude-review` on the v4.26.2 sync PR caught it: `templates/tier-heavy.md`'s "Required artifacts" section still listed the `/strategy-sync` diff log unqualified, alongside genuinely pre-ship items (QA report, security review report) — contradicting the sentence v4.26.2 added 11 lines below in the same file. Qualified the bullet: produced at the initiative boundary, not required to close the individual issue. Doc-only. Smoke 161, unchanged.)*

---

## Table of Contents

1. [What This Is](#what-this-is)
2. [Core Principle](#core-principle)
3. [The Complete Pipeline](#the-complete-pipeline)
4. [Stage 0: Foundation](#stage-0-foundation)
   - [Step 0.1: Concept](#step-01-concept)
   - [Step 0.2: Define](#step-02-define)
   - [Step 0.3: Strategy Create](#step-03-strategy-create)
   - [Step 0.4: Infrastructure Setup](#step-04-infrastructure-setup)
   - [Step 0.5: Roadmap Create](#step-05-roadmap-create)
   - [Step 0.6: Phase Plan](#step-06-phase-plan)
5. [Stage 0 Gate: Roadmap Review](#stage-0-gate-roadmap-review)
6. [Stage 1: Spec](#stage-1-spec)
   - [Light Spec](#light-spec)
   - [Agent Review](#agent-review)
   - [Human Review](#human-review)
7. [Stage 2: Plan + Build](#stage-2-plan--build)
   - [Branch](#branch)
   - [Work](#work)
   - [Plan Review](#plan-review)
8. [Stage 3: Verify + Ship](#stage-3-verify--ship)
   - [Verify](#verify)
   - [Ship](#ship)
   - [PR Review (opt-in)](#pr-review-opt-in)
   - [UAT](#uat)
9. [Stage 4: Release](#stage-4-release)
10. [Stage 5: Documentation Loop](#stage-5-documentation-loop)
11. [Between Initiatives](#between-initiatives)
12. [The Initiative Model](#the-initiative-model)
13. [The Strategy Doc Framework](#the-strategy-doc-framework)
14. [The Linear Model](#the-linear-model)
15. [Execution Model](#execution-model)
16. [Three-Layer Enforcement](#three-layer-enforcement)
17. [Project Configuration](#project-configuration)
18. [Syncing the Method](#syncing-the-method)
19. [Skill Quick Reference](#skill-quick-reference)
20. [Key Principles](#key-principles)

---

## What This Is

Pipekit is a structured, AI-assisted software delivery system. It provides a deterministic pipeline from "I have an idea" to "it's in production" with quality gates at every stage.

It was extracted from the Piper production finance platform and is designed to be portable — you sync it into any project and it adapts via a project-specific config file.

The method is opinionated about process but flexible about technology. It doesn't care if you use React or Svelte, Postgres or MongoDB. It cares that you spec before you plan, plan before you execute, and review before you ship.

---

## Core Principle

**No stage may introduce guesswork into the next stage.**

- Concepts must not require definition guesses
- Definitions must not require strategy guesses
- Specs must not require planning guesses
- Plans must not require execution guesses
- Execution must not require interpretation

When ambiguity is detected, the pipeline sends work **backward** — not forward. A spec that forces the planner to guess is returned for revision, not passed through with caveats. A concept that's too vague for definition is refined, not defined with assumptions.

---

## The Complete Pipeline

```
STAGE 0: FOUNDATION (a contract — greenfield path shown below)
──────────────────────────────────────────────────────────────────────

  /concept ──→ /define ──→ /strategy-create ──→ /startup
      │            │               │                │
  concept-     project-       Strategy/         repo, DB,
  brief.md    definition.md    docs           deploy, MCP

      ──→ /roadmap-create ──→ /phase-plan ──→ /roadmap-review (GATE)
                │                   │                │
          Linear hierarchy      current initiative    Stage 0
          (i{N}. → I{N}.P{N}.  derived live;     validated ✓
          → Issue) authored    first sub-phase
          in Linear            issues → "Needs Spec"


STAGES 1-5: DEVELOPMENT PIPELINE (repeats per issue)
──────────────────────────────────────────────────────────────────────

  Stage 1: Spec
    /light-spec ──→ Agent Review ──→ Human Review
         │                │                │
     Structured      Pass/Revise      Approved
     spec in         verdict          by human in
     Linear                           Linear

  Stage 2: Plan + Build
    pk next ──→ pk branch <ID> ──→ /work <ID>   (→ /review-plan to gate the plan)
        │             │                  │
    Initiative-aware   Worktree +         Plan-verdict
    Linear        Linear → In        gate, then
    grouping      Progress           execute

  Stage 3: Verify + Ship
    /verify ──→ /security-gate ──→ pk ship [--review]  (→ /pr-fix | /pr-security-review) ──→ UAT
        │            │                  │                                                     │
    Pre-deploy   Classify diff;     Push, PR, Linear                                       Human
    gate + AC    review if a        → UAT                                                  accepts
    table        category matches

  Stage 4: Release
    pk done <ID> ──→ pk promote <env>
         │                  │
     Worktree           One hop per
     cleanup;           invocation;
     Linear: UAT →      transitions
     In <FirstEnv>      issues to
     (or → Done for     In <Env> or
     1-tier)            Done

  Stage 5: Doc Loop
    /strategy-sync (after UAT)
         │
     Strategy docs updated
     to match what was built

  Per session (not per issue):
    /pk-exit ──→ Logs/Sessions/<date>_<HHMM>.md  (last command of every Claude Code session)

BETWEEN INITIATIVES:
──────────────────────────────────────────────────────────────────────

  /phase-plan --next ──→ /roadmap-review ──→ /light-spec (next initiative begins)
```

**Stage 0** is the foundation contract — a set of artifacts the dev pipeline depends on. Greenfield projects build the contract by running the full Stage 0 chain; brownfield projects skip `/concept` and `/define`; inherited projects verify and proceed. See [Entry Modes](#stage-0-foundation) below. After Stage 0 is satisfied, the dev pipeline repeats for each initiative of features. Between initiatives, `/phase-plan --next` selects the next batch and `/roadmap-review` validates before speccing begins again.

---

## Stage 0: Foundation

Stage 0 is the **foundation contract** — a set of artifacts the dev pipeline (Stages 1-5) requires before the daily loop is safe to run. It is not a script you run once; it is a pre-condition. *How* the contract is satisfied depends on your entry mode.

### Entry Modes

Pick the mode that matches your situation. Full description in [method.md § Entry Modes](method.md#entry-modes).

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` |
| **Inherited** | New contributor joining a Pipekit project | None — verify foundation, jump to dev pipeline | All of Stage 0 |

`/startup` auto-detects the mode and confirms with you before proceeding (same pattern as tier resolution in `/work`). `/strategy-from-code` (auto-audit for brownfield) is deferred — originally promised for v1.4.0 but never built; brownfield currently routes through `/strategy-create` with a manual-edit note.

The rest of this section describes the **greenfield flow** in detail. Brownfield skips Steps 0.1 and 0.2 — adapt accordingly. Inherited mode runs no Stage 0 steps; jump straight to [Stage 1](#stage-1-spec) once the foundation check passes.

The `/startup` skill orchestrates the greenfield flow — you can run each step individually or let `/startup` chain them.

### Step 0.1: Concept

**Skill:** `/concept`
**Input:** A raw project idea + optionally existing documents (proposals, research, notes)
**Output:** `concept-brief.md`

This is the starting point. You have an idea — maybe just a sentence, maybe a folder full of proposal docs. `/concept` takes whatever you have and produces a structured concept brief.

**What it does:**

1. If you have existing documents, provide them: `/concept --docs path/to/folder/`
   - The skill reads everything, extracts problem statements, user descriptions, scope ideas, constraints
   - It then asks only about what's missing — it doesn't re-ask what's already written
2. If starting from scratch, it walks through each section interactively
3. Produces a concept brief covering: Problem, Solution, Target Users, Scale & Revenue, Constraints, Competitive Landscape, Risks

**The gate question:** Is this concept specific enough to invest definition time?
- **Yes** → proceed to `/define`
- **No** → needs more research (save as draft, come back later)
- **Kill** → not worth pursuing (save with rationale for the record)

**Key distinction:** `/concept` is for projects ("should I build this product?"). `/brainstorm` is for features within an existing project ("should I add this feature?").

**Example:**
```
/concept --docs ~/Projects/my-project/proposal/

Reading 6 documents from ~/Projects/my-project/proposal/...

Extracted:
  - Problem: shared spreadsheet leaks data, corrupts formulas
  - Users: ~40 internal team members
  - Solution: internal tool for structured data management
  - Missing: revenue model, competitive landscape, risk assessment

Let me ask about the gaps...
```

---

### Step 0.2: Define

**Skill:** `/define`
**Input:** `concept-brief.md` + optionally additional documents
**Output:** `project-definition.md`

The concept brief says "should I build this?" The project definition says "what exactly am I building?" This is the distillation step — turning a validated idea into a structured document complete enough to make tech stack decisions and write strategy docs.

**What it produces:**

| Section | What It Captures |
|---------|-----------------|
| Project Identity | Name, one-liner, audience, problem, success definition |
| Stage Breakdown | MVP scope, Stage 2 scope, future parking lot — with exit criteria |
| User Roles | Each role, what they do, what they can access |
| Key Workflows | 3-5 critical user journeys (actor, trigger, steps, outcome) |
| Integration Requirements | External systems, data flows, priority per stage |
| Success Criteria | Measurable outcomes per stage (not vague — "10 users complete core workflow") |
| Non-Functional Requirements | Performance, security, availability, compliance, accessibility |

**Critical rule:** Stage 1 (MVP) must be independently valuable. If Stage 1 only makes sense with Stage 2 features, the split is wrong. Push back.

**The gate question:** Can we make tech stack decisions and write strategy docs from this definition?

**Example:**
```
/define

Reading concept-brief.md...

## Project Identity
  Name: My Project
  One-liner: Internal tool for team data management
  Users: ~40 team members
  Problem: Shared spreadsheet leaks data, corrupts formulas, no search

## Stage Breakdown

Stage 1 (MVP):
  - Data import and storage
  - Search by criteria (category, status, type)
  - Basic CRUD operations
  Exit: 10 users can search and find records without spreadsheets

Stage 2 (Growth):
  - Advanced filters and saved searches
  - Activity tracking and audit log
  - Reporting dashboard
  Exit: All 40 users migrated off spreadsheets

Is this accurate? Want to adjust anything?
```

---

### Step 0.3: Strategy Create

**Skill:** `/strategy-create`
**Input:** `project-definition.md`
**Output:** `Strategy/` directory with docs, `method.config.md` updated

Strategy docs are the human-readable explanation of the product. They serve stakeholders (what does it do?) and developers (how does it work?). These are living documents — `/strategy-create` generates v0.1.0, and `/strategy-sync` updates them after features ship.

**How the doc set is determined:**

The skill analyzes the project definition and recommends which docs are needed:

| Doc | Template | Created When |
|-----|----------|-------------|
| Conceptual Overview | `templates/strategy/conceptual-overview.md` | Always — every project needs a plain-language description |
| Technical Architecture | `templates/strategy/technical-architecture.md` | Always — developers need to understand the system design |
| Design Direction | `templates/strategy/design-direction.md` | Project has a UI — captures visual style, inspiration, and anti-patterns for build agents |
| Permissions | `templates/strategy/permissions.md` | Project has user roles with different access levels |
| Data Model | `templates/strategy/data-model.md` | Complex data relationships or calculations |
| Workflow Examples | `templates/strategy/workflow-examples.md` | Multi-step user journeys defined |
| UX Reference | `templates/strategy/ux-reference.md` | Complex UI interactions (often added later, not at creation) |

**Audience discipline:** Each doc type has a target audience. Conceptual Overview is stakeholder-friendly (no jargon). Technical Architecture is developer-level (schema detail). Design Direction is practical and read by both developers and AI agents (including `/frontend-design`) during execution. The skill matches the tone to the audience.

**What gets configured:** The doc set is recorded in `method.config.md` under `## Strategy Docs`. Both `/strategy-create` and `/strategy-sync` read this table to know which docs exist and how to update them.


## Strategy Docs

| Doc | File | Purpose | Audience |
|-----|------|---------|----------|
| Conceptual Overview | `Strategy/ConceptualOverview.md` | What the product does | Stakeholders |
| Technical Architecture | `Strategy/TechnicalArchitecture.md` | System design | Developers |
| Permissions | `Strategy/Permissions.md` | Auth, roles, access control | Developers, Admins |


**v0.1.0 is intentionally incomplete.** Strategy docs grow with the project. `[TBD]` sections are expected — they'll be filled as features are built.

---

### Step 0.4: Infrastructure Setup

**Skill:** `/startup` (Phases 3-6 of the orchestrator)
**Input:** Project definition + tech stack decisions
**Output:** Working repository, database, deployment, MCP servers

This is where you set up the actual infrastructure. The `/startup` orchestrator handles this as part of its flow, but it can also be run standalone if you've already completed concept/define/strategy.

**What gets set up:**

1. **Tech Stack Decisions** — framework, language, database, auth, deployment, CSS/UI, testing
   - The skill presents options with trade-offs based on your project definition
   - You decide — it never locks in a choice without approval
2. **Git Architecture Decision** — choose your branching model:

   | Model | Branches | Best For |
   |-------|----------|----------|
   | **Two-tier** | `dev` → `main` | Solo dev, small teams, preview URLs suffice for UAT |
   | **Three-tier** | `dev` → `beta` → `main` | Teams with QA, need stable UAT env, regulated industries |

   This decision is recorded in `method.config.md` (under `Ship environments` in the V2 keys) and determines:
   - Which environments to configure (2 or 3)
   - The chain `pk promote` walks (`dev,main` for two-tier; `dev,beta,main` for three-tier)
   - How Linear status transitions work on merge (see `sop/Git_and_Deployment.md`)

3. **Repository** — GitHub repo, framework init, TypeScript strict, .gitignore, .env.example
4. **Database** — project creation, initial schema, auth setup, local dev
5. **Deployment** — Vercel/equivalent linking, env vars, custom domains, preview deploys
6. **Tooling** — ESLint, Vitest, Playwright, pre-deploy gate
7. **MCP Servers** — Linear, GitHub, database, browser, Playwright in `.mcp.json`

**Linear setup is special:**
- What can be automated (via MCP/CLI): issue creation, relations, labels
- What needs manual setup (in Linear UI): workflow state configuration, initiative creation
- The skill gives explicit instructions for manual steps, then fetches state IDs to populate `method.config.md`

---

### Step 0.5: Roadmap Create

**Skill:** `/roadmap-create`
**Input:** Strategy docs + `project-definition.md`
**Output:** The Linear Initiative→Project→Issue hierarchy (`i{N}.` / `I{N}.P{N}.`), populated directly in Linear

This is where strategy becomes work items. The skill reads your strategy docs and project definition, extracts requirements, groups them into feature clusters, identifies dependencies, and authors the phase hierarchy **directly in Linear** — no `.vbw-planning/ROADMAP.md` merge dependency and no `linear-map.json`.

**What it produces:**

1. **Linear Initiatives** named `i{N}. label` — one per roadmap initiative, ordered by the numeric prefix (`i1.`, `i2.`, …). This is the initiative surface `pk next`/`pk status` read live.
2. **Linear Projects** named `I{N}.P{N}. label` — ordered sub-phases (execution batches) within a phase; the issues live here. The project carries its initiative number (e.g. `I1.P2.`) so the phase reads at the project level — the unit you navigate in Linear. (`bin/pk` accepts legacy bare `P{N}.` too; the `P{N}` number sets order either way.)
3. **Linear Issues** — one issue per requirement, with:
   - Correct status (On Deck for Stage 1, Future Phases for Stage 2+, Ideas for parking lot)
   - Dependency relations (`blocked_by`)
   - Type and domain labels
   - Milestone (Work Package) assignment

A narrative `ROADMAP.md` may still be written as an optional legacy/handoff artifact, but it is no longer a required output or a state file the pipeline reads.

**Feature clusters become `I{N}.P{N}.` Linear Projects.** A feature cluster is a logical grouping of related requirements — "Data Foundation", "Search & CRUD", "Auth & Permissions." Each becomes an `I{N}.P{N}.` Project (sub-phase) under its phase's `i{N}.` Initiative (e.g. `I1.P2. Auth & Permissions`).

**Manual vs. automated:** The skill automates issue creation, relations, and labels via MCP. For things that require the Linear UI (initiatives, workflow states), it gives explicit step-by-step instructions.

**The `--verify` flag:** After completing manual Linear setup, run `/roadmap-create --verify` to confirm everything is wired up correctly.

---

### Step 0.6: Phase Plan

**Skill:** `/phase-plan`
**Input:** The populated Linear hierarchy (`i{N}.` Initiatives → `P{N}.` Projects → Issues)
**Output:** Current initiative derived live from Linear + issues in the current sub-phase promoted to "Needs Spec"

An initiative is a batch of issues selected for the current execution cycle. This skill selects which issues to work on next, validates dependencies, and promotes them so the spec pipeline can begin. It **derives and advances initiative state via Linear initiative/project status** — there is no `PHASES.md` registry to write.

**Initiative composition guidelines:**

| Guideline | Target |
|-----------|--------|
| Initiative size | 3-8 issues |
| Complexity mix | At least 1 Low for quick wins, no more than 2 High |
| Dependencies | No issue blocked by something outside the initiative (unless it's Done) |
| Milestone coverage | Prefer completing milestones over splitting them |

**What happens when you approve an initiative:**

1. Selected issues move from "On Deck" → "Needs Spec"
2. If On Deck is now empty, issues from "Future Initiatives" get promoted to On Deck
3. A Linear comment is posted on each issue noting its initiative assignment

**Initiative state is derived from Linear, not a file.** The current initiative is the lowest-numbered `i{N}.` Initiative whose status is not `Completed`; the current sub-phase is the lowest-numbered `P{N}.` Project in it whose state is not `completed`/`canceled`. `/phase-plan` advances the initiative by transitioning that initiative/project state in Linear — `pk next`/`pk status` then read the new current initiative live. (Projects not yet migrated to `i{N}.`-prefixed initiatives fall back to the legacy `.vbw-planning/PHASES.md` automatically.)

---

## Stage 0 Gate: Roadmap Review

**Skill:** `/roadmap-review`

Before the spec pipeline begins, `/roadmap-review` validates that Stage 0 is complete and the roadmap is healthy. This is the gate between "foundation" and "building."

**Stage 0 checks:**

| Check | Surface | If Missing |
|-------|---------|-----------|
| Concept brief | `concept-brief.md` | Run `/concept` |
| Project definition | `project-definition.md` | Run `/define` |
| Strategy docs | `Strategy/` matching config | Run `/strategy-create` |
| Roadmap | Linear `i{N}.` Initiatives + `P{N}.` Projects exist | Run `/roadmap-create` |
| Linear board | Issues exist for requirements | Run `/roadmap-create` |
| Phase defined | A non-`Completed` `i{N}.` Initiative with a current `P{N}.` Project | Run `/phase-plan` |

**Ongoing health checks** (run every initiative):

- **Completeness** — every roadmap requirement has a Linear issue
- **Roadmap progress** *(if the roadmap uses checkboxes; v4.15.0)* — `ROADMAP.md`'s `- [x]`/`- [ ]` boxes reconcile with Linear `Done` (report-only — it flags drift both ways but never writes the human-owned roadmap)
- **Assignment** — issues are in the correct stage/project/milestone
- **Dependencies** — `blocked_by` relations match the roadmap
- **Ordering** — workflow states are consistent with dependency order
- **Phase-label layer** *(optional, if `method.config.md § Phase Label Layer` is configured; v4.14.0)* — the `Roadmap: Phase *` / `Order: Any` label mirror of `ROADMAP.md`'s build order matches the board; bootstrapped onto an existing board on first run, drift-checked thereafter
- **Spec coverage** — how many issues in the current initiative have specs
- **Doc freshness** — strategy docs flagged if features shipped without a sync

If any check fails, the report tells you exactly which skill to run to fix it. The roadmap-progress and phase-label checks no-op silently when they don't apply (no checkboxes / no `### Phase Label Layer` config), so they cost nothing on projects that don't use them.

---

## Stage 1: Spec

Stage 1 turns raw issues into planning-safe specs. This is where the "no guesswork" principle is enforced most rigorously.

### Light Spec

**Skill:** `/light-spec` or `/light-spec PROJ-1`
**Input:** Feature idea or existing Linear issue
**Output:** Structured spec in the Linear issue description

A light spec is an **AI-to-AI contract**: Generator → Reviewer → Planner. It's not a document for humans to read casually — it's a structured contract that constrains the next stage.

**The spec template** (`templates/light_spec_template.md`) has these sections:

| Section | Purpose |
|---------|---------|
| Problem | What's broken/missing — 2-3 sentences |
| Goal | End-state, not work description |
| Proposed Solution | 3-5 bullets, outcomes not implementation |
| Scope (In/Out) | Explicit boundaries — prevents creep |
| Decisions | Every behavioral decision: DEFINED or `[TBD]` |
| Requirements | Functional requirements checklist |
| Acceptance Criteria | Input/state → observable output (must be verifiable) |
| Technical Context | What exists, patterns to follow, **authority** (source of truth) |
| Risks & Open Questions | Unknowns for planning to resolve |

**Critical rules:**

- **WHAT, not HOW.** If a statement can be rewritten as "change X line" or "use Y syntax," it's implementation detail and must be removed.
- **No implicit decisions.** A decision left unmentioned makes the spec invalid. `[TBD]` is fine if it doesn't block task decomposition.
- **Authority must be explicit.** For data/calculations: is DB, utils, or API authoritative? If multiple layers could disagree, define precedence.
- **Acceptance criteria must be verifiable.** "Works correctly" fails review. "Given X input, when Y action, then Z output on [specific page]" passes.

**The skill explores the codebase** before writing the spec — it uses an Explore agent to understand existing code, patterns, and infrastructure. The spec is informed by reality, not assumptions.

### Agent Review

**Tool:** Linear Spec Review Agent (triggered via `/light-spec`)

After the spec is written, the Spec Review Agent evaluates it for planning readiness. The agent is calibrated for light specs — it won't fail a spec for brevity, missing sections from template limitations, or explicit `[TBD]` markers.

**It WILL fail a spec if:**
- Concision hides ambiguity
- `[TBD]` forces the planner (`/work`) to guess
- Core decisions are missing
- Source of truth is unclear for calculations/data
- Acceptance criteria aren't testable

**Output:** Pass/Revise verdict, readiness score (X/10), blocking issues, fast path to pass.

If the verdict is **Revise**, the spec goes back to `/light-spec` for iteration. This loop continues until the agent passes.

**Review history accumulates (v4.25.0+).** Each pass appends a `### Review N — <date> — <verdict>` block to the issue description's `## Agent Review` section; nothing prior is rewritten. That trail is load-bearing: `/02-light-spec-revise` reads earlier passes to tell a resolved blocker from a re-raised one, and the same section holds the human stalemate-override note its Phase 6 writes. Through v4.24.0 the trigger prompt told the agent to *replace* the section, so pass 2 destroyed pass 1 and pass 3 destroyed both — silently. The per-pass verdict **comments** on the issue were never affected; only the consolidated in-description trail was.

**Config note (v2.7.0+):** `/light-spec` publishes the spec to the configured **`Spec ready state`** in `method.config.md` — not a hardcoded `Specced`. `pk spec-cycle` requires that same state on entry, so the interlock holds on any board: a two-state workflow (e.g. `Needs Spec → Approved`, no `Specced` state) just sets `Spec ready state: Needs Spec`. If publishing fails because the configured state doesn't exist in Linear, that's a `method.config.md` ↔ workflow mismatch to fix, not a skill bug.

### Human Review

**Tool:** You, in Linear

After agent review passes, you review the spec in Linear. This is where product decisions get locked in — scope, priority, trade-offs.

**What you're checking:**
- Does the scope match your intent?
- Are the decisions correct?
- Is the priority right relative to other work?
- Anything the agent missed that you know from context?

**Outcome:** Move the issue to "Approved" in Linear. This signals that the spec is locked — no more scope changes. Planning (`/work`'s inline plan step) can begin.

---

## Stage 2: Plan + Build

### Branch

**Commands:** `pk next` then `pk branch <ID>`
**Input:** Approved spec
**Output:** Worktree + feature branch + Linear → In Progress

`pk next` is initiative-aware (v2.1.0+): it **derives the current initiative live from the Linear hierarchy** — the lowest-numbered `i{N}.` Initiative that isn't `Completed`, then its lowest-numbered open `P{N}.` Project (by numeric name prefix, `P2` before `P10`; Linear's `sortOrder` is never used) — and groups that initiative's Linear results by status (In Progress / Approved / Needs Spec) with per-group hints. Legacy `.vbw-planning/PHASES.md` + `linear-map.json` fall back automatically for un-migrated projects. Falls back to global "next Approved" when no initiative context.

`pk branch <ID>` is mechanical setup — idempotent against Linear+git ground truth. It creates the worktree, the branch, and transitions Linear:

- Creates `feature/<ID>-<3-word-slug>` (slug derived from issue title)
- Worktree at `.worktrees/<ID>-<slug>`
- Symlinks `.env` / `.env.local` / `.mcp.json` into the worktree — plus **nested per-app env files** (v2.7.0+): auto-discovers and links real nested env files (e.g. `apps/web/.env.local`, `packages/*/.env`) at the same relative path, so monorepo worktrees don't come up reading the `*.example` placeholder. Exact-name match (never `*.example`), idempotent, never clobbers a real file already in the worktree. **Never links `.env.prod`** — prod credentials stay out of feature worktrees — and announces every link it makes on stdout. Projects on the secrets-manager pattern (committed `op://` reference files) don't need the symlinks at all: tracked reference files travel via git checkout. See `pipekit-security.md` § Secrets Managers and Worktrees.
- Copies parent's `bin/pk` so v2 commands work from inside the worktree
- Linear: Approved → In Progress

After branching, `cd .worktrees/<ID>-<slug>` and start a fresh Claude Code session inside the worktree (fresh-chat discipline — see method.md § Fresh-Chat Discipline).

### Work

**Skill:** `/work <ID>` (or `/work <ID> --deep`)
**Input:** Approved spec from Linear
**Output:** Code committed against verify/done criteria

`/work` is the consolidated plan + execute skill. It reads the spec from Linear and produces a one-screen plan with a **verdict gate** before any code is written:

- `proceed` — plan is sound, execute as planned
- `revise: <feedback>` — plan needs adjustment
- `abort` — issue isn't ready / scope was wrong

Tier inference (Quick / Standard / Heavy) drives which gates apply. Tier is **always confirmed with the human** before the verdict step — automatic tier escalation/de-escalation is disallowed by design. See `method.md` § Tiers and `templates/tier-{quick,standard,heavy}.md` for per-tier gate tables. Quick skips spec review, milestone-readiness, plan review, and QA; Heavy adds security review + mandatory `/strategy-sync` before the initiative closes (post-merge, not a per-issue `pk ship`/`pk done` gate).

**Execution** is native-on-Workflow — the sole executor as of v4.0.0:

`/work` plans in your current Claude session (parallel `Agent` calls for grounding), materializes a task DAG to `.pk-work/<ID>-PLAN.md`, then executes on the Workflow primitive — atomic commit per task with verify-before-integrate — writing a `.pk-work/<ID>-SUMMARY.md` trail. Trivial plans (≤2 tasks/files, no migration) run inline. Artifacts are gitignored (executor contract only — no UAT/known-issue/sprint state). There is no backend selection — native-on-Workflow is the only executor (a stale `Backend:` row in `method.config.md` is ignored).

`--deep` adds spec-validator + plan-review + security-review subagents for the planning step. Use it when scope is fuzzy or risk is high.

**All commits include the issue ID** in the message format: `feat(scope): description (PROJ-1)`. CLAUDE.md conventions are followed (the native backend reads it via your session).

### Plan Review

**Skill:** `/review-plan` (spawns the `plan-reviewer` agent on the plan-review tier per `method.config.md § Model Policy` — default `opus`, effort `xhigh`)
**Input:** the inline plan — `/work` emits a task DAG at `.pk-work/<ID>-PLAN.md`, which `/review-plan` targets directly. (For un-migrated projects with a legacy `PLAN.md` under `.vbw-planning/phases/{phase-slug}/`, `/review-plan` still reviews those as a fallback.)
**Output:** Validated plan or revision requests

Run between `/work`'s inline planning and execution as an optional plan-quality gate. Native execution has per-task verify-before-integrate as its own plan-safety net, so `/review-plan` is most useful when a plan is large or high-risk and you want a whole-plan stress-test before any task runs. The plan reviewer stress-tests:

- Scope alignment with the spec
- Task atomicity (each task produces one logical commit)
- Dependencies and ordering
- Success criteria completeness
- Risk identification

If the plan fails review, it goes back to `/work`'s planning step for rework. Once the plan passes, execution begins.

---

## Stage 3: Verify + Ship

### Verify

**Skill:** `/verify` (or `pk verify`)
**Input:** Completed work in the worktree
**Output:** Pre-deploy gate report — Pass / Partial / Fail with per-AC table

`/verify` runs the project's pre-deploy gate from `method.config.md` § Pre-Deploy Gate (typically types + lint + test). Returns:

- Overall verdict (Pass / Partial / Fail)
- Per-AC table (which acceptance criteria are satisfied, which aren't)
- If `Require QA review: true` in `method.config.md`, also spawns the QA subagent for goal-backward verification (starts from AC, works backward)

**Migration self-review (v2.7.0+).** When the diff touches the configured `Migration dir`, `/verify`'s migration flag no longer hands you a raw `git show` — it spawns a review subagent (`pr-review-toolkit:code-reviewer`, falling back to `general-purpose`) that applies `/pr-security-review`'s migration rubric (M1–M8, plus RLS / SECURITY DEFINER / GRANT rubrics when those patterns appear), writes `migration-review.md`, and the flag carries a **Hold / Approve verdict**. Runs on every tier. A `Hold` pauses auto-ship but does **not** auto-downgrade the verify status — you RECONCILE the verdict (approve `Hold: M3 missing backfill` or `Approve — no findings`) rather than re-deriving the review yourself.

If verify fails → fix the gaps in the worktree (often by re-invoking `/work` with feedback) and rerun. If verify passes → run the security gate, then ship.

### Security Gate *(v4.4.0; projects with a categories file)*

**Skill:** `/security-gate` (or `/security-gate <ID>`)
**Input:** Verify-passed feature branch
**Output:** PASS/FAIL gate report + Linear comment

`/security-gate` runs at the Building → UAT seam — after `/verify`, before `pk ship`. Its first job is to **classify**: a read-only sub-agent maps the feature diff to six sensitive categories (auth, payments, user-input, external-APIs, file-storage, PII) using the project's `resources/security-categories.md` signals. If **none match**, the gate is an instant PASS — most features touch nothing sensitive and this path is meant to be cheap. If a category matches, a per-category checklist runs against the diff (parallel read-only sub-agents), every finding is adversarially refutation-tested, and the gate emits a PASS/FAIL report.

It is a **hard gate** as of v4.17.0 — on PASS the gate writes a sha-matched `secgate-complete.md` sentinel, and `pk ship` **refuses** without one matching HEAD on any project with a categories file (`--force` / `PK_SECGATE_BYPASS=1` escape, both audited). A FAIL writes no sentinel: close the findings and re-gate. It is distinct from `/security-review` (periodic whole-repo audit) and `/pr-security-review` (PR-scoped, antagonistic): this one is feature-scoped and category-triggered, and it runs automatically at the ship seam like `/verify`. A no-op without a `resources/security-categories.md` file (scaffolds the template and stops on first run). Full methodology in `sop/Security_Gate_SOP.md`.

### Ship

**Command:** `pk ship` (or `pk ship --review`, or `pk ship --ready`)
**Input:** Verify-passed worktree
**Output:** Branch pushed, PR opened as **Draft** (v2.6.0+), Linear → UAT

`pk ship` is idempotent — rerun is safe. It:

- Pushes the feature branch (skips if already current)
- Opens a PR via `gh pr create --draft` against the integration branch from `method.config.md` (`Integration branch: dev` for most projects). The Draft state means outside reviewers (Semgrep + claude-review per `templates/ci/`) do NOT fire during iteration. v2.6.0+.
- Transitions Linear from In Progress → UAT (or → In Review per project config)

Variants:

- `pk ship --ready` opens the PR Ready immediately (outside reviewers fire on `opened` event). Use for one-shot tiny WITs where iteration won't happen.
- `pk ship --review` additionally posts a Linear comment flagging review-in-flight + prints the antagonistic reviewer subagent invocation (v2.1.0). The reviewer plays devil's advocate vs `/work` + `/verify` — surfaces cross-cutting concerns the spec didn't think to mention. Don't skip on anything auth, security, financial, or compliance-adjacent.

### Flip Draft → Ready (v2.6.0+)

**Command:** `pk ready [<ID>]`
**Input:** Open Draft PR
**Output:** PR flipped to Ready; outside reviewers fire on `ready_for_review` event

The merge-moment gesture. After iterating on a Draft PR (pushing fixes, addressing your own review notes), flip to Ready when you actually want the outside reviewers to run. The `pk ready` command:

- Finds the PR for the feature branch (by branch name match)
- Runs `gh pr ready <#>` — fires `ready_for_review` event
- Outside reviewers listen for this event and run once, at the merge moment, not on every push. `templates/ci/` ships two (Semgrep, claude-review) but they are **opt-in copy-ins** — sync lands them under `templates/`, never in `.github/workflows/`. `pk ready` probes your workflows for the `ready_for_review` trigger and names the ones that will actually fire; if it reports none installed, no outside review is happening on that PR (v4.25.0+)
- **Conflicting PRs get no CI at all, silently (v4.26.0+).** GitHub cannot build the merge ref for a conflicting PR, so it dispatches **zero** `pull_request` workflows — required checks simply never run, and the board keeps whatever it last showed. `pk ready` now warns on `CONFLICTING`, before the already-Ready early return (SiteLine's PIPER-174 was already Ready *when* it conflicted, and merged with its only required gate never having run). It warns rather than blocks, and stays silent on `MERGEABLE` and `UNKNOWN` alike — mergeability is computed asynchronously, and pk will not assert a state it did not observe. The tell, if you are reading the board by hand: a check list containing only `pull_request_target` entries means conflicting, not passing
- **"Runs once" cuts both ways (v4.26.0+).** A reviewer whose `pull_request` types omit `synchronize` reviews the Ready flip and *nothing you push after it* — so the commits that fix its own findings are the ones no reviewer sees, and the PR shows no sign of it. `pk ready` now probes for this and names any such workflow, with the recovery (`gh pr ready --undo <#> && gh pr ready <#>`, which re-fires the event on the current head). Observed on SiteLine: PIPER-345's `879748e5` and PIPER-499's final head `778edbec` both merged unreviewed for exactly this reason. Adding `synchronize` to the workflow trades CI minutes for reviewing every push — a project-level call, so Pipekit reports the gap rather than closing it for you
- No Linear state change (UAT stays UAT — the WIT was already In Review/UAT after `pk ship`)

Idempotent: if the PR is already Ready, prints "No flip needed" and exits 0.

### PR Review (opt-in)

**Skills:** `/pr-fix` and `/pr-security-review`

After the reviewer posts findings to the PR, two skills triage them:

**`/pr-fix`** — pluggable-engine PR review: by default it fans out the `pr-review-toolkit` specialist agents (`--engine=native`, fail-loud if the plugin is absent), or the built-in reference-file review via `--engine=builtin` (zero plugin dependency — the portable fallback). Either engine also runs two **dependency-free historical finders** (v2.7.0): **git-history** (git-blame regression detection — flags a change that removes or rewrites a line a recent commit added to fix a bug) and **prior-pr-comments** (reapplication — flags past reviewer feedback on the same file/region that recurs in this diff). Findings from all sources converge and triage on two independent axes (**severity × confidence**), kept separate so a catastrophic-but-uncertain finding routes to **INVESTIGATE** (surfaced, not auto-fixed) rather than being buried by low confidence; when a historical finder corroborates a specialist at the same location, confidence is raised. Reads PR review comments + diff, scans for cross-spec handoff promises (any "X will…" reference in the spec must have landed in this PR), then lets you triage interactively (fix / reject / defer). Applies fixes as separate commits, validates the gate, force-pushes to the PR. Posts a Linear comment with the triage summary (fixed N / rejected N / deferred N). `--runs=N` fans the review out N times and raises confidence on findings that recur.

**`/pr-security-review`** — security-focused antagonistic review for migrations, RLS policies, SECURITY DEFINER functions, GRANT/REVOKE, auth code, and Server Actions on privileged tables. 30+ rubric items across 6 surface categories. Use **instead of** (or alongside) the generic reviewer when the PR touches any of those surfaces.

Skip PR review for pure copy/UI tweaks and internal-only refactors with no external surface. Always opt in for anything labeled `auth-rls`, `payments`, `pii`, `compliance`, `breaking-change`.

### UAT

**Tool:** You (in the running app — Vercel preview URL or local dev)
**Input:** Built feature, PR open with preview deployment
**Output:** Accepted or rejected against spec AC

Test the feature against the spec's acceptance criteria under real usage conditions. The PR should already have a Vercel preview URL by the time you start UAT (Vercel auto-deploys on PR open).

**Accept:** Merge the PR (rebase or merge-commit; squash is disabled repo-wide). Then exit the worktree and run `pk done <ID>` from the parent repo — this verifies the merge, cleans up the worktree + branch, posts commits + diffstat to Linear, transitions Linear `UAT → In <FirstEnv>` (e.g. `In Dev`, or → `Done` for 1-tier projects), auto-pulls the integration branch (v2.6.0+), and — for un-migrated projects that still carry a legacy `.vbw-planning/` layer — writes its `.vbw-planning/.../SUMMARY.md` + flips PLAN status to complete (v2.6.0+; skipped silently otherwise). Or pass `--merge` and let `pk done` run `gh pr merge` for you. v2.7.0+ also resets the parent branch after worktree teardown, prints a stack advisory (a local dev server / Supabase keeps running), and — for script-deploy projects with a `Deploy command` set in `method.config.md` — reminds you to deploy (the merge doesn't auto-ship the app).

**Reject:** Describe what's wrong — the issue re-enters execution with your feedback (return to Stage 2's `/work`).

---

## The Express Lane: `/pk-express`

**Skill:** `/pk-express <ISSUE-ID>` (primary) or `/pk-express "<idea>"` (prepends brainstorm)
**Input:** A brainstormed WIT, or a raw one-line idea
**Output:** An open **Draft PR** (Linear → UAT) — or a pause at one of five gates

For *simple* WITs, `/pk-express` collapses Stages 1–3 into a single hands-off pass. It is connective glue over four stages that already self-drive — it removes the between-stage typing and the two interactive triage/confirm prompts, nothing more:

```
/brainstorm "<idea>"  →  /light-spec <ID>  →  pk branch <ID>  →  /work <ID>
   (file the WIT)         (auto-cycle to        (worktree)         (execute → auto /verify
                           Approved)                                  → auto pk ship → Draft PR)
```

It is **express, not reckless** — the gates that protect real risk stay intact. The lane auto-advances on each stage's success signal and **stops to tag you at exactly five points**:

| # | Stop | Why it's yours |
|---|------|----------------|
| 1 | `/brainstorm` verdict is **Later / Kill**, or the idea is too vague to scope | the premise is a judgment call |
| 2 | Derived tier is **`tier:heavy`** | heavy work needs the full planning + antagonistic gates; the spec is preserved, but the lane refuses to drive it |
| 3 | Spec **stalemate** (3 review cycles, no Pass) | the reviewer and the spec disagree — you decide override vs. rework |
| 4 | `/verify` raises **any flag** or a non-Pass verdict | a migration verdict, QA finding, or gate failure — your RECONCILE call |
| 5 | **Draft PR opened** (terminal success) | the downstream gates are deliberately yours: `pk ready` → reviewers + UAT → `pk done` → `pk promote` |

Use it when the idea is genuinely small (Quick/Standard tier) and you want it built without babysitting each stage. **Do not** use it for anything you suspect is `tier:heavy` (it refuses — gate 2), for bugs (use `/pk-bug` for regression-test-first discipline), or for work that already has an Approved spec (just `pk branch` + `/work`). It stores no local state — `/pk-express <ID>` reads the issue's Linear state and rejoins the lane at the right stage, so it's safe to resume in a fresh session.

It never runs `pk ready`, `pk done`, or `pk promote` — those are the human gates it hands back at gate 5.

---

## Stage 4: Release

**Every step forward is a PR.** No direct merges between long-lived branches. Promotion is owned by `pk promote`, configured per project via `Ship environments` in `method.config.md` (e.g., `dev,main` or `dev,beta,main`).

Your git architecture (chosen during `/startup`) determines the release flow:

**Two-tier** (`dev` → `main`):
```
feature/* → pk ship (Draft) → pk ready → pk done (UAT → In Dev)
         → pk promote (PR to main) → pk promote --finish (→ Done)
```
- `pk ship` opens the feature → dev PR as Draft (Linear → `UAT`)
- `pk ready` flips Draft → Ready (fires outside reviewers)
- `pk done <ID>` after merge: cleanup + Linear → `In Dev` + auto-pull + planning SUMMARY/PLAN-flip
- `pk promote main` (or `pk promote` with no arg) opens the dev → main PR. WITs stay in `In Dev`.
- `pk promote main --finish` (v2.6.0+ Phase 2) after the promote PR merges: transitions the issue → `Done`

**Three-tier** (`dev` → `beta` → `main`):
```
feature/* → pk ship (Draft) → pk ready → pk done (UAT→In Dev)
         → pk promote beta → pk promote beta --finish (→ In Beta)
         → pk promote main → pk promote main --finish (→ Done)
```
- `pk ship` opens the feature → dev PR as Draft (Linear → `UAT`)
- `pk ready` flips Draft → Ready (fires outside reviewers)
- `pk done <ID>` after merge: cleanup + Linear → `In Dev` + auto-pull + planning SUMMARY/PLAN-flip
- `pk promote beta` opens dev → beta. WITs stay in `In Dev`. `--finish` after merge transitions → `In Beta`.
- `pk promote main` opens beta → main. WITs stay in `In Beta`. `--finish` after merge transitions → `Done`.

**Auto-machinery** firing on PR open / main merge (Pipekit owns none of these — they're project infrastructure):

- **CI** enforces the pre-deploy gate at every PR. If types, lint, or tests fail, the merge is blocked.
- **Vercel** deploys preview on PR open and prod on main merge.
- **GitHub Actions** (Supabase projects only): `db-pr-check.yml` validates migrations on PR open against ephemeral postgres; `db-migrate.yml` applies them on main merge. Lift the workflow pair from rs-vault if your project doesn't have them yet.
- **Linear transition** (optional, v2.7.1): `templates/ci/linear-transition.yml` advances a merged WIT's Linear state automatically on integration-branch merge — the safety net for when `pk done` is skipped (e.g. a GitHub-UI merge). Forward-only and idempotent. See `templates/ci/README.md` for setup and the note on Linear's native GitHub integration (turn native off on multi-tier projects; this workflow is ladder-aware where native isn't).

---

## Stage 5: Documentation Loop

**Skill:** `/strategy-sync`
**Input:** Shipped features + current Strategy docs
**Output:** Updated Strategy docs reflecting what was actually built

After features ship and UAT passes, `/strategy-sync` closes the documentation loop:

```
Strategy Docs (vision) → Specs → Plans → Code → Strategy Docs (reality)
                  ↑                                        |
                  └──────── /strategy-sync ───────────────┘
```

**How it works:**

1. Identifies features shipped since the last doc update
2. Maps each feature to affected Strategy doc sections
3. Reads the actual implementation (code is truth, not the spec)
4. Drafts updated sections matching each doc's audience level
5. Presents before/after diffs for your approval
6. Applies approved changes and bumps doc versions

**Critical rule: Code is truth.** If the implementation differs from the spec, the Strategy doc matches the code — not the spec. Specs describe intent; code describes reality.

**When to run:**
- After UAT passes for an initiative
- Before stakeholder presentations
- Before onboarding new team members
- When `/roadmap-review` flags doc staleness

---

## Between Initiatives

When an initiative's issues are all Done (or an initiative is otherwise complete):

1. **`/phase-plan --next`** — archives the completed initiative and proposes the next one
   - Shows a brief retrospective: how long the initiative took, complexity accuracy
   - Identifies newly unblocked issues (their blockers just completed)
   - Proposes the next initiative composition
2. **`/roadmap-review`** — validates the roadmap is still healthy before speccing
3. **`/light-spec`** — begin speccing the next initiative's issues

**`/phase-plan --status`** is available anytime for a progress dashboard:
```
Initiative 2 Status — 2026-04-15

| Issue | Title | Status | Days |
|-------|-------|--------|------|
| PROJ-4 | Advanced search | Done | — |
| PROJ-5 | Saved searches | Building | 2d |
| PROJ-6 | Activity log | In Dev | 0d |
| PROJ-7 | Export reports | Needs Spec | 4d |

Progress: 1/4 Done (25%)
Alert: PROJ-7 in "Needs Spec" for 4 days — run /light-spec PROJ-7
```

**`/phase-plan --rebalance`** adjusts the current initiative if priorities shift — add, remove, or swap issues.

---

## The Initiative Model

Initiatives, milestones, and cycles serve different purposes. Understanding their relationship is important for initiative planning.

### The Three Concepts

| Concept | What It Is | Linear Construct | Lifespan |
|---------|-----------|-----------------|----------|
| **Initiative** | An ordered roadmap initiative | Linear **Initiative** named `i{N}. label` | Permanent (ordered by `{N}`) |
| **Sub-phase** | An execution batch — what we're building right now; holds the issues | Linear **Project** named `I{N}.P{N}. label` (legacy bare `P{N}.` still parses) | Ordered within its initiative by the `P{N}` number |
| **Milestone (Work Package)** (optional) | A feature cluster — groups related issues for gating; orthogonal to phases | Linear Milestone | Intra-project grouping |
| **Cycle** (optional) | A time-boxed sprint — capacity planning | Linear Cycle | Configurable duration |

### How They Relate

**Milestones group by feature. Initiatives group by execution order.**

An initiative may pull from multiple milestones:
```
Initiative 1:
  - PROJ-1 from WP-1 (Foundation)
  - PROJ-2 from WP-1 (Foundation)
  - PROJ-3 from WP-2 (Search)
```

A large milestone may span multiple initiatives:
```
WP-2 (Search) — 8 issues:
  - Initiative 1: PROJ-3, PROJ-4 (core search)
  - Initiative 2: PROJ-7, PROJ-8 (advanced search, export)
  - Initiative 3: PROJ-11, PROJ-12, PROJ-13, PROJ-14 (filters, saved searches)
```

### Milestone Gating

`/work` uses milestones for its gating check: all sibling issues in a milestone must be at least Specced before any can enter Plan + Build. This ensures coordinated planning within a feature cluster.

### Linear Cycles (Optional)

If you want time-boxed sprints with capacity tracking, map initiatives to Linear Cycles. This is optional — the method works without cycles. Cycles add:
- Start/end dates
- Team capacity tracking
- Velocity measurement

### Initiative State Tracking

Initiatives are tracked **live in Linear**, not in a committed file. An initiative is a `i{N}.` Initiative; its sub-phases are `I{N}.P{N}.` Projects that hold the issues (v4.5.0 — the project carries its initiative number so the initiative reads at the project level; legacy bare `P{N}.` still parses). The current initiative is derived on demand — the lowest-numbered `i{N}.` Initiative not yet `Completed`, then its lowest-numbered open `P{N}` Project (ordered by the numeric name prefix, never Linear's `sortOrder`). Linear also tracks individual issue status (Needs Spec, Building, UAT, In Dev, In Beta, Done — env-mapped per `Ship environments`). `pk next`/`pk status` read which issues belong to the current initiative and the initiative's overall progress straight from this hierarchy. (Un-migrated projects fall back to the legacy `.vbw-planning/PHASES.md` automatically.)

---

## The Strategy Doc Framework

Strategy docs are configurable per project. Each project defines which docs it maintains in `method.config.md`.

### Default Doc Types

| Doc Type | Template | Audience | When to Create |
|----------|----------|----------|---------------|
| Conceptual Overview | `templates/strategy/conceptual-overview.md` | Stakeholders | Always — every project |
| Technical Architecture | `templates/strategy/technical-architecture.md` | Developers | Always — every project |
| Design Direction | `templates/strategy/design-direction.md` | Developers, AI Agents | If project has a UI |
| Permissions | `templates/strategy/permissions.md` | Developers, Admins | If auth/roles exist |
| Data Model | `templates/strategy/data-model.md` | Developers | If complex data |
| Workflow Examples | `templates/strategy/workflow-examples.md` | All | If multi-step user flows |
| UX Reference | `templates/strategy/ux-reference.md` | Developers, Support | If complex UI (often added later) |

### Lifecycle

```
/strategy-create (v0.1.0) ──→ features ship ──→ /strategy-sync (v0.2.0, v0.3.0, ...)
```

- **v0.1.0** is intentionally incomplete — `[TBD]` sections are expected
- Each `/strategy-sync` run bumps the version and fills in more detail
- Code is always truth — docs track reality, not aspirations

### Configuration

The doc manifest lives in `method.config.md`:

```markdown
## Strategy Docs

| Doc | File | Purpose | Audience |
|-----|------|---------|----------|
| Conceptual Overview | `Strategy/ConceptualOverview.md` | What the product does | Stakeholders |
| Technical Architecture | `Strategy/TechnicalArchitecture.md` | How it works | Developers |
```

Both `/strategy-create` and `/strategy-sync` read this table. Add or remove rows as the project evolves.

---

## The Linear Model

Linear is the view layer. The executor (`/work`, native by default) plans and builds. They share data but serve different purposes.

### Hierarchy

```
Initiative `i{N}. label` = Phase             "Which ordered roadmap phase?"
  └── Project `I{N}.P{N}. label` = Sub-phase  "Which ordered execution batch? (issues live here)"
       └── Issue = Feature/Task                "What work needs to happen?"
            └── Milestone = Work Package (opt)   "Optional feature-cluster grouping, orthogonal to phases"
```

Ordering is the integer in the `i{N}.`/`P{N}.` name prefix, parsed numerically (`P2` before `P10`). Linear's `sortOrder` is never used. Unprefixed initiatives are strategic themes — `pk next`/`pk status` ignore them.

### Workflow States

```
Planned path:
  Triage → Ideas → Future Phases → On Deck → Needs Spec → Specced → Approved → Building → UAT → In <FirstEnv> → [In <Env> →]* Done

Ad-hoc path:
  Triage → In Progress → UAT → In <FirstEnv> → [In <Env> →]* Done

Terminal:
  → Canceled | Duplicate
```

`[In <Env> →]*` is one state per non-final env in `Ship environments`. For 3-tier (`dev,beta,main`): `In Dev → In Beta → Done`. For 2-tier (`dev,main`): `In Dev → Done`. State maps 1:1 to environment: `UAT` = PR open on preview branch; `In Dev` = merged to dev; `In Beta` = promoted to beta; `Done` = on the final env.

**Key distinction:**
- **Building** = automated execution owns it (`/work`, native-on-Workflow). Initiative-batched, planned work.
- **In Progress** = You're doing it manually. Ad-hoc, outside the initiative.

### Initiative Management via Status

| Status Group | Initiative Role |
|-------------|-----------|
| Ideas | Someday — evaluated but not scheduled |
| Future Initiatives | Known future stage — not current or next |
| On Deck | Next initiative — staging area |
| Needs Spec → UAT | Current initiative — active pipeline |
| Done | Shipped |

`/phase-plan` manages the On Deck → Needs Spec promotion. Refilling On Deck from Future Initiatives happens when the current initiative starts.

### Labels

| Category | Labels | Purpose |
|----------|--------|---------|
| Type | Feature, Bug, Improvement, Research, Tech Debt, Chore | What kind of work |
| Flag | Quick Win, Blocked, Hotfix, Breaking Change | Special handling |
| Domain | (project-specific) | Product area |
| Tier | (stage-numbered) | Which stage |
| Audience | Client Request | External origin |

### What Lives Where

| Content | Home | Never In |
|---------|------|----------|
| Feature specs, AC, scope | Linear issue description | plan files |
| Task decomposition | `.pk-work/` PLAN files (legacy `.vbw-planning/` for un-migrated projects) | Linear |
| Execution status | Both (synced via `/sync-linear`) | — |
| Code | Git | Linear or plan files |
| Phase composition | Linear `i{N}.` Initiatives + `P{N}.` Projects (derived live) | a committed file |

**Never create Linear issues for plan tasks** (they live in the `.pk-work/` task DAG). Features are the bridge between Linear and the executor's plan.

---

## Execution Model

**Native-on-Workflow is the sole executor.** `/work` plans the issue inline (parallel `Agent` calls for grounding) and executes on Claude Code's Workflow primitive — atomic commit per task, verify-before-integrate. There is no backend selection and no separate planning service: planning and execution both run in your Claude session, against the spec read live from Linear.

The roadmap's initiative order lives in **Linear** (`i{N}.` Initiatives → `P{N}.` Projects, derived live), authored directly by `/roadmap-create` — there is no scaffolded phase file to initialize. `pk next`/`pk status` derive the current initiative live from that hierarchy.

| Pipeline Stage | Tool | Used when | Purpose |
|---------------|------|-----------|---------|
| Stage 0.5 | `/roadmap-create` authors the Linear `i{N}.`/`P{N}.` hierarchy | Always | Populate roadmap in Linear |
| Stage 2 (planning) | `/work` inline planning | Always | Generate the plan from the spec — planning runs in-session, no separate planning service |
| Stage 3 (execute) | native-on-Workflow | Always | Execute tasks on the Workflow primitive — atomic commit per task, verify-before-integrate |
| Anytime | `pk status` | Always | Project progress dashboard, derived live from Linear |

The plan-safety net is per-task verify-before-integrate (`/work`) plus the `/verify` gate and the antagonistic review gates (`/review-plan`, `/pr-security-review`), not a separate QA agent.

### Legacy `.vbw-planning/` fallback

Pipekit fully retired VBW: no Pipekit skill, gate, or executor depends on it, and the VBW plugin is not installed. The one remaining vestige is read-only — `bin/pk` keeps a legacy fallback that reads `.vbw-planning/PHASES.md` / `linear-map.json` **only** for projects that haven't yet migrated to the Linear-native initiative surface. Migrated projects (the normal path) never touch it. `/work` writes its task DAG and run trail to gitignored `.pk-work/`, never `.vbw-planning/`.

---

## Three-Layer Enforcement

The method uses three layers to enforce conventions. Each layer serves a different audience:

| Layer | Purpose | Who Reads It | When |
|-------|---------|-------------|------|
| **CLAUDE.md** | Documents conventions | The executor (native-on-Workflow) during execution | Every agent session |
| **CI / Hooks** | Hard enforcement — blocks merges | Everyone (agents and humans) | Every PR |
| **Skills** | Interactive shortcuts | You, in hands-on sessions | When you invoke them |

**Skills are convenience wrappers.** They automate the same conventions documented in CLAUDE.md. Executor agents don't call skills — they read CLAUDE.md and write code directly.

**CLAUDE.md is the single document** that agents read to understand the project. Build it up as the project grows:

| Add This Section | When |
|-----------------|------|
| Database Conventions | First migration |
| API Route Pattern | First API endpoint |
| Component Conventions | First shared component |
| Data Layer | First server state hook |
| Security Rules | First RLS policy |

**`.claude/rules/`** files auto-load every session for enforceable constraints:
- `security.md` — auth patterns, env var rules
- `naming.md` — file naming, code naming, DB naming
- `patterns.md` — data layer, API routes, mutations
- `file-structure.md` — directory layout
- `tooling.md` — commands, CI, pre-deploy gate

---

## Project Configuration

Each consuming project maintains `method.config.md` with project-specific values. Portable skills read this file at runtime — it's how the method adapts to each project.

**Key sections:**

| Section | What It Configures |
|---------|-------------------|
| Project | Name, display name, worktree prefix, paths |
| Linear | Workspace slug, team name/ID, issue prefix |
| Workflow State IDs | UUID for each of the 14 states — skills use these for transitions |
| Strategy Docs | Which docs exist, their files, purposes, audiences |
| Slack (optional) | Channel IDs for notifications |
| Environments | URLs and branches for each environment |
| Pre-Deploy Gate | Commands that must pass before deployment |

**Template:** `method.config.template.md` — copy this to your project root and fill in your values.

---

## Syncing the Method

The method repo is the source of truth. Projects pull from it using `scripts/sync-method.sh`.

### What Gets Synced

| Source (method repo) | Destination (project) |
|---------------------|----------------------|
| `skills/*/` | `.claude/skills/*/` |
| `sop/` | `pipekit/sop/` |
| `templates/` | `pipekit/templates/` |
| `method.md` | `pipekit/method.md` |
| `STARTUP.md` | `pipekit/STARTUP.md` |

### What Never Gets Synced

| File | Why |
|------|-----|
| `method.config.md` | Project-specific |
| `pipekit/.local-skills` | Committed manifest declaring project-specific skills (v3.1.0) — the sync reads it to separate "local by design" from "removed upstream" in its changelog |
| `.claude/rules/` | Project coding conventions |
| `.claude/skills/{project-specific}/` | Stack-specific skills |
| `.claude/overrides/` | Sync-safe customization (applied on top of sync; see `method.md` § Sync-Safe Overrides) |
| `.vbw-planning/` | Project state (legacy fallback for un-migrated projects) |
| `CLAUDE.md` | Project-specific |

### Commands

```bash
# First time — fetch sync script from GitHub
mkdir -p scripts
curl -fsSL https://raw.githubusercontent.com/withpiper/pipekit/main/scripts/sync-method.sh -o scripts/sync-method.sh
chmod +x scripts/sync-method.sh
./scripts/sync-method.sh

# Update to latest (from terminal)
./scripts/sync-method.sh

# Or update from inside Claude Code
/pipekit-update

# Pin to a version
./scripts/sync-method.sh v1.0

# Preview changes
./scripts/sync-method.sh --dry-run

# Push improvements back to method repo
/pipekit-update --push
```

---

## Drift Detection

Documentation references file paths, skill names, commands, and config values that can go stale when code changes. The drift checker (`scripts/drift-check.sh`) catches this automatically.

### What It Checks

| Check | What It Does |
|-------|-------------|
| **File paths** | Extracts backtick-quoted paths from all markdown files, verifies they exist on disk |
| **Skill cross-references** | Verifies that `/skill-name` references in skills point to real skills |
| **Document staleness** | Flags docs not updated in 50+ commits |
| **Script references** | Checks that `pnpm run X` commands exist in `package.json` |
| **Config completeness** | Checks `method.config.md` for empty fields and missing strategy doc files |

### Usage

```bash
./scripts/drift-check.sh              # Full check
./scripts/drift-check.sh --paths      # File path check only
./scripts/drift-check.sh --stale      # Staleness check only
./scripts/drift-check.sh --scripts    # Script/command check only
./scripts/drift-check.sh --ci         # Exit 1 if errors found (for CI)
```

### Context Detection

The script auto-detects whether it's running in the method repo or a consuming project:
- **Method repo:** Scans skills, templates, SOPs, method.md, GUIDE.md
- **Consuming project:** Scans CLAUDE.md, `.claude/rules/`, synced method docs, skills

### When to Run

- After renaming or moving files
- After modifying CLAUDE.md or rules
- Before committing documentation changes
- As a post-commit hook or CI step
- Periodically as a health check

### Wiring as a Post-Commit Hook

Add to `.git/hooks/post-commit` or your project's hook system:

```bash
./scripts/drift-check.sh --ci || echo "Drift detected — review documentation references"
```

---

## Skill Quick Reference

### Stage 0: Foundation

| Skill | Command | What It Does |
|-------|---------|-------------|
| Concept | `/concept` | Raw idea → concept brief |
| Concept (with docs) | `/concept --docs path/` | Ingest existing docs → concept brief |
| Define | `/define` | Concept → project definition |
| Strategy Create | `/strategy-create` | Definition → strategy docs |
| Startup | `/startup` | Full orchestrator (chains everything) |
| Roadmap Create | `/roadmap-create` | Strategy → Linear `i{N}.`/`P{N}.` hierarchy (authored directly in Linear) |
| Roadmap Verify | `/roadmap-create --verify` | Check Linear matches roadmap |
| Initiative Plan | `/phase-plan` | Select first/next initiative |
| Initiative Status | `/phase-plan --status` | Current initiative progress |
| Initiative Next | `/phase-plan --next` | Archive + plan next initiative |
| Initiative Rebalance | `/phase-plan --rebalance` | Adjust current initiative |

### Stage 1: Spec

| Skill | Command | What It Does |
|-------|---------|-------------|
| Roadmap Review | `/roadmap-review` | Full health check (Stage 0 → Stage 1 gate) |
| Brainstorm | `/brainstorm` | Feature-level ideation (within an existing project) |
| Light Spec | `/light-spec PROJ-1` | Create spec for an issue |
| Light Spec Revise | `/light-spec-revise PROJ-1` | Apply Spec Review Agent feedback surgically |
| Spec Preflight | `/spec-preflight PROJ-1` | Empirical pre-flight checks before `pk branch` (file paths, symbol/line refs, baselines, Linear status). Read-only. |
| Spec Validator | `/spec-validator` | Validate spec completeness |

### Stage 2: Plan + Build (the v2 daily loop)

| Command / Skill | Invocation | What It Does |
|-----------------|------------|-------------|
| Find next | `pk next` | Initiative-aware: groups Linear by status (In Progress / Approved / Needs Spec) with per-group hints |
| Branch | `pk branch <ID>` | Worktree + feature branch + Linear → In Progress (idempotent) |
| Work | `/work <ID>` | Plan + execute on native-on-Workflow. Verdict gate before code. |
| Work Deep | `/work <ID> --deep` | Adds spec-validator + plan-review + security-review subagents |
| Plan Review | `/review-plan` | Spawn `plan-reviewer` against the inline `PLAN.md` (optional gate) |

### Fast lanes (autopilots over the loop)

| Skill | Invocation | What It Does |
|-------|------------|-------------|
| Express | `/pk-express <ISSUE-ID>` (or `"<idea>"`) | Idea→Draft-PR autopilot for **simple** WITs (Quick/Standard only). Chains `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify + ship). Stops only at 5 gates: not-Now, tier:heavy refusal, spec stalemate, verify flag, Draft PR opened. Resumes from Linear state. |
| Bug | `/pk-bug` | Bug pipeline with regression-test-first discipline: intake → reproduce → failing test → fix → ship → postmortem. Wraps `/work` + `pk ship` with discipline gates. |

### Stage 3: Verify + Ship

| Command / Skill | Invocation | What It Does |
|-----------------|------------|-------------|
| Verify | `/verify` (or `pk verify`) | Pre-deploy gate (types + lint + test); QA subagent if `Require QA review: true` |
| Ship | `pk ship` | Push, open PR as **Draft** (v2.6.0+) against integration branch, Linear → UAT |
| Ship Ready | `pk ship --ready` | Open Ready immediately (v2.6.0+; one-shot tiny WITs) |
| Ready flip | `pk ready [<ID>]` | Flip Draft → Ready (v2.6.0+); fires outside reviewers |
| Ship + Review | `pk ship --review` | Adds Linear "review-in-flight" comment + reviewer invocation printed |
| PR Fix | `/pr-fix` | Pluggable-engine review (`--engine=native` pr-review-toolkit, default · `--engine=builtin` portable fallback) + git-history/prior-PR-comment historical finders (v2.7.0); two-axis severity×confidence triage with INVESTIGATE quadrant; fix / reject / defer; posts Linear summary. `--from-review` ingests GHA review; `--runs=N` raises confidence on recurrence; `--second-opinion=gemini` adds a parallel Gemini Flash read. |
| PR Security Review | `/pr-security-review` | Antagonistic security review for migrations / RLS / SECURITY DEFINER / auth |

### Stage 4: Release

| Command | Invocation | What It Does |
|---------|------------|-------------|
| Cleanup | `pk done <ID> [--merge]` | Post-merge: verify merge, cleanup worktree+branch, post commits/diffstat to Linear, transition UAT → In `<FirstEnv>` (or → Done for 1-tier). v2.6.0+: also auto-pulls integration + writes planning SUMMARY + flips PLAN status. v2.7.0+: resets the parent branch, prints a stack advisory, and reminds you to deploy when a `Deploy command` is configured (script-deploy projects). |
| Prod Ready | `/prod-ready [<ID>]` | Production-readiness gate (v4.3.0). Runs **once** before the final promote (the last `Ship environments` entry; the merge to `main` on 1-tier). Six operational checks — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, flag on risky paths, dashboard chart. PASS/FAIL report + Linear comment. **Hard gate v4.17.0**: PASS writes a source-branch-sha sentinel; `pk promote <final-env>` refuses without it on projects with a checks file (`--force` / `PK_PRODREADY_BYPASS=1`; 1-tier projects have no promote seam, so it stays advisory there). Portable framework, project checks in `resources/prod-readiness-checks.md`. No-op without a checks file. |
| Promote — open | `pk promote <env>` | Phase 1 (v2.6.0+): opens promote PR. WITs stay in source state. PR body embeds bundled-WIT tracker. 2-tier: `pk promote` with no arg picks the only hop. |
| Promote — finish | `pk promote <env> --finish` | Phase 2 (v2.6.0+): after the promote PR merges, transitions matching issues → `In <Env>` (intermediate) or → Done (final). |
| Deploy (script projects) | `pk deploy [<env>] [-- <args>]` | Run the project's configured `Deploy command` for `<env>` (v4.6.0). Bare / `prod` → `Deploy command`; `pk deploy dev` → `Deploy command dev`. Args after `--` pass through to the script (a file list, `--all`, …). Script-deploy projects only — branch-promotion projects deploy via `pk promote`. Thin delegate: the script owns confirmation + safety. |

### Stage 5: Doc Loop

| Skill | Command | What It Does |
|-------|---------|-------------|
| Strategy Sync | `/strategy-sync` | Update Strategy docs to match shipped code |

### Per session

| Skill | Command | What It Does |
|-------|---------|-------------|
| Exit | `/pk-exit` | Narrative session log to `Logs/Sessions/<date>_<HHMM>.md` (last command of every Claude Code session) |

### Ongoing operations

| Command / Skill | Invocation | What It Does |
|-----------------|------------|-------------|
| Status | `pk status` | Full unscoped Linear board view |
| Doctor | `pk doctor` | Diagnostic: config, Linear API, worktree dir, stale artifacts, **false-ship cross-check** (v2.7.0 — flags UAT/Done WITs with no real commits on the integration branch, via git evidence), **upstream-staleness check** (v3.1.0 — warns when the synced Pipekit lags the method repo's latest release; offline-soft) |
| Init | `pk init` | One-time per consuming project: seeds `notepad.md`, `Logs/Sessions/`, checks config |
| Sync Linear | `/sync-linear` | Reconcile strategy-doc / requirement drift against the Linear initiative hierarchy |
| Linear | `/linear` | Linear issue workflow helper |
| Pipekit Help | `/pipekit-help` | Read project state, recommend next pipeline step |
| Security Review | `/security-review` | Periodic repo security audit (different from `/pr-security-review`) |
| Financial Review | `/financial-review` | Periodic financial-accuracy review (finance/calculation-heavy projects) — cross-layer parity audit + severity report. Portable framework; project checks in `resources/financial-review-checks.md`. No-op without a checks file. |
| Release Changelog | `/release-changelog --version vX.Y.Z` | Generate draft CHANGELOG entry from commits between tags (Pipekit-internal release tooling) |
| Pipekit Update | `/pipekit-update` | Pull latest Pipekit from GitHub into project. **Phase P** (v2.7.0) also ensures managed plugin dependencies — installs/updates `pr-review-toolkit` at user scope so `/pr-fix`'s native engine resolves. |
| Update + Push | `/pipekit-update --push` | Push improvements back to method repo |

---

## Red Flags in Skills

Key skills include a `## Red Flags` section — self-sabotage thoughts that Claude should recognize as danger signals. When any of these thoughts arise, the skill's process should be followed *more* strictly, not less.

**Examples from across the pipeline:**

| Thought | What It Really Means |
|---------|---------------------|
| "This is simple, I don't need a plan" | You definitely need a plan |
| "I know this API" | Check the installed version — your training data is stale |
| "The spec is close enough" | If it doesn't pass the gate, it doesn't launch |
| "Stage 1 needs Feature X to be useful" | The stage split is wrong — Stage 1 must stand alone |
| "I'll write tests after" | Write them first or concurrently |
| "This doesn't need a Linear issue" | Every idea gets an issue. Issues without tracking get forgotten. |
| "I'll keep it in Ideas for now" | "Keep" without a trigger condition is how issues die |

Skills with Red Flags: `/concept`, `/define`, `/strategy-create`, `/roadmap-create`, `/phase-plan`, `/work`, `/light-spec`, `/brainstorm`.

---

## Portable Rule Templates

The method includes rule templates in `templates/rules/` that consuming projects sync into their `.claude/rules/` directory. These are auto-loaded every session by Claude Code under the **hub-and-spoke model** (CLAUDE.md hub → rules/ auto-loaded → pipekit/sop/ demand-loaded).

Canonical files use a `pipekit-` prefix so they never collide with project-specific rule filenames. Five canonical topic files ship from Pipekit. Rules that don't apply to a project (`pipekit-cmux.md` outside cmux, `pipekit-migrations.md` without a versioned migration system) can be skip-listed via a `Skip rules` key in `method.config.md` — the sync stops syncing them and removes previously-synced copies, since an auto-loaded rule the session was told to ignore still costs input tokens every turn (v4.21.0+; see `templates/rules/README.md` § Opting out).

### `pipekit-discipline.md`

Cross-cutting AI coding discipline:

- **Red Flags** — thoughts that mean "go slower, not faster" (e.g., "this is simple, I don't need a plan" → you do)
- **Ad-hoc Plan Gate** — 3-5 bullet plan template for ad-hoc interactive changes outside a `/work` plan, with When-This-Applies / Does-Not-Apply scope
- **Scope hygiene** — no features/abstractions beyond the task, no speculative error handling, no backwards-compat shims
- **Comment & commit discipline** — comments match the surrounding code and state constraints the code can't show (judgment form, v4.21.0+), one atomic change per commit, never amend published

### `pipekit-tooling.md`

Library/tool/CI constraints:

- **Verify Library API before use** — installed-version check sequence (pnpm/npm/yarn list, read `node_modules/` source, prefer `context7` MCP). Never-assume list: signatures, config options, import paths, default behaviors.
- **Package manager pinning** — read from `method.config.md` or lockfile; never mix
- **Pre-deploy gate** — project's gate (`method.config.md` → `## Pre-Deploy Gate`) is authoritative; no `--no-verify` workarounds
- **Use package.json scripts** over ad-hoc CLI invocations

### `pipekit-security.md`

Non-negotiable security baseline:

- **Secrets** — never commit; `.env` always gitignored; rotate if accidentally published
- **Input validation at boundaries only** — internal code trusts internal code
- **Authorization must be explicit** at every layer (RLS / policies / ACLs); never rely on UI restrictions
- **SQL/injection** — always parameterized; never `eval` on untrusted input
- **OWASP Top 10** awareness — 10-item quick-reference checklist
- **Feature flags / kill switches** for fail-unsafe features (financial, bulk destructive, data leak potential)

### `pipekit-migrations.md`

Discipline for projects with a versioned migration system (Supabase, Prisma, Knex, Alembic, Rails). Informational if the project has none:

- **Frozen-file invariant** — once a migration is applied to any env, the file is immutable; fix/harden/revert with a *new* migration
- **Hardening during review** — close `/db-review` findings with a later-timestamped migration, never an edit
- **Parallel-branch coordination** — re-check timestamps against the base branch immediately before merge
- **MCP-applied-migration drift** — never `apply_migration` SQL that also lives on disk (auto-stamp mismatch)
- **Silent-failure patterns** — nullable version FKs, auto-create triggers vs manual inserts, stale DEFAULTs vs new CHECK constraints

### `pipekit-cmux.md`

cmux pane/surface discipline (informational if not running in cmux):

- **Discover before acting** — re-fetch topology; surface refs from a previous turn go stale
- **Use the CLI, not RPC** — `cmux send --surface`, never `cmux rpc surface.send_text` (routing bug)
- **Pair every send with a read-screen** — verify the command landed where intended
- **Track long-running work by PID**, not by scrollback; detect turn-END, not narration keywords

### Adding project-specific rules

Consumers add new files directly to their `.claude/rules/` — `sync-method.sh` won't touch them. See `templates/rules/README.md` for naming conventions (`patterns.md`, `file-structure.md`, `{library}-pitfalls.md`).

---

## Brainstorm Disposition (EXPAND/HOLD/REDUCE)

`/brainstorm` creates well-analyzed Linear issues, but without a disposition step they accumulate in Ideas with no next step. The method uses a three-phase framework to force a decision:

### EXPAND

Already handled by `/brainstorm` — full vision, feasibility analysis, codebase exploration, complexity estimate.

### HOLD (Disposition)

Immediately after creating the issue, force one of three decisions:

| Decision | What Happens |
|----------|-------------|
| **Now** | Route to pipeline — assign to an initiative/stage, move to Needs Spec |
| **Later** | Park with explicit trigger condition + target initiative. Tagged `Parked` in Linear. |
| **Kill** | Archive with rationale. Move to Canceled. |

**Parking rules for "Later" items:**
- Must have a trigger condition (e.g., "revisit when PROJ-56 ships")
- Must have a target initiative/stage (e.g., "Initiative 4+")
- Surfaced by `/roadmap-review` when trigger conditions are met

### REDUCE (for "Now" items)

If the brainstorm is broad, cut to v1 scope before entering the spec pipeline:
- "What's the smallest useful version?"
- "What can wait for v2?"
- Update the issue with a `## v1 Scope` section

### Batch Disposition

`/brainstorm-review` handles batch triage — reviewing all undisposed issues at once with the same Now/Later/Kill framework. Run it periodically to clear the backlog.

### Integration Points

| Skill | Role |
|-------|------|
| `/brainstorm` | EXPAND + immediate HOLD + optional REDUCE |
| `/brainstorm-review` | Batch HOLD for untriaged backlog |
| `/roadmap-review` | Surfaces parked items whose triggers have fired |
| `/phase-plan --rebalance` | Adds "Now" dispositions to current initiative |

---

## Key Principles

### No Guesswork
Every stage produces output that the next stage can consume without guessing. When guessing is detected, work goes backward.

### AI → AI Contracts
Specs are structured contracts between generator, reviewer, and planner. Every rule must be explicit, unambiguous, and enforceable by a downstream agent.

### WHAT vs HOW
Specs define WHAT. Plans define HOW. If a spec statement can be rewritten as "change X line," it's implementation detail and must be removed.

### Explicit Decisions
All behavior-affecting decisions must be defined or marked `[TBD]`. `[TBD]` is valid only if it doesn't block task decomposition. A decision left implicit (not mentioned) makes the spec invalid.

### Authority
Source of truth must be explicit (DB, utils, API). When multiple layers could disagree, define precedence. Ambiguous authority is the #1 cause of spec revision.

### Controlled Incompleteness
Brevity, `[TBD]`, limited context are fine. Hidden assumptions and implicit behavior are not. The test: _can the next stage work without guessing?_

### Human Ownership
AI proposes, reviews, and executes. Humans decide. AI never locks in a product decision — it presents analysis and waits for the call.

### Code Is Truth
When code and documentation disagree, trust the code. Strategy docs track reality, not aspirations. `/strategy-sync` enforces this after every initiative.

### Every Step Forward Is a PR
No direct merges between long-lived branches. Each promotion (dev → beta → main) is a PR with CI gates. Hotfixes cherry-pick back immediately.
