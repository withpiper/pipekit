# Pipekit — Instruction Manual

A complete guide to using Pipekit from project inception through production delivery. This document covers every stage, every skill, and every decision point in the pipeline.

**Last updated:** 2026-05-03 *(rewritten for v2.1.2)*

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
   - [Step 0.5: VBW Init](#step-05-vbw-init)
   - [Step 0.6: Roadmap Create](#step-06-roadmap-create)
   - [Step 0.7: Phase Plan](#step-07-phase-plan)
5. [Stage 0 Gate: Roadmap Review](#stage-0-gate-roadmap-review)
6. [Stage 1: Spec](#stage-1-spec)
   - [Light Spec](#light-spec)
   - [Agent Review](#agent-review)
   - [Human Review](#human-review)
7. [Stage 2: Plan + Build](#stage-2-plan--build)
   - [Branch](#branch)
   - [Work](#work)
   - [Plan Review (vbw backend)](#plan-review-vbw-backend)
8. [Stage 3: Verify + Ship](#stage-3-verify--ship)
   - [Verify](#verify)
   - [Ship](#ship)
   - [PR Review (opt-in)](#pr-review-opt-in)
   - [UAT](#uat)
9. [Stage 4: Release](#stage-4-release)
10. [Stage 5: Documentation Loop](#stage-5-documentation-loop)
11. [Between Phases](#between-phases)
12. [The Phase Model](#the-phase-model)
13. [The Strategy Doc Framework](#the-strategy-doc-framework)
14. [The Linear Model](#the-linear-model)
15. [VBW Integration](#vbw-integration)
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

  /concept ──→ /define ──→ /strategy-create ──→ /startup ──→ /vbw:init
      │            │               │                │            │
  concept-     project-       Strategy/         repo, DB,    .vbw-planning/
  brief.md    definition.md    docs           deploy, MCP     scaffold

      ──→ /roadmap-create ──→ /phase-plan ──→ /roadmap-review (GATE)
                │                   │                │
          ROADMAP.md +          PHASES.md        Stage 0
          Linear board      (first phase in    validated ✓
          populated         "Needs Spec")


STAGES 1-5: DEVELOPMENT PIPELINE (repeats per issue)
──────────────────────────────────────────────────────────────────────

  Stage 1: Spec
    /light-spec ──→ Agent Review ──→ Human Review
         │                │                │
     Structured      Pass/Revise      Approved
     spec in         verdict          by human in
     Linear                           Linear

  Stage 2: Plan + Build
    pk next ──→ pk branch <ID> ──→ /work <ID>   (→ /review-plan if vbw backend)
        │             │                  │
    Phase-aware   Worktree +         Plan-verdict
    Linear        Linear → In        gate, then
    grouping      Progress           execute

  Stage 3: Verify + Ship
    /verify ──→ pk ship [--review]   (→ /pr-fix | /pr-security-review) ──→ UAT
        │            │                                                       │
    Pre-deploy    Push, PR, Linear                                       Human
    gate + AC     → UAT                                                  accepts
    table

  Stage 4: Release
    pk done <ID> ──→ pk promote
         │                │
     Worktree         dev → main (or
     cleanup +        dev → beta → main)
     Linear → Done    PR

  Stage 5: Doc Loop
    /strategy-sync (after UAT)
         │
     Strategy docs updated
     to match what was built

  Per session (not per issue):
    /pk-exit ──→ Logs/Sessions/<date>_<HHMM>.md  (last command of every Claude Code session)

BETWEEN PHASES:
──────────────────────────────────────────────────────────────────────

  /phase-plan --next ──→ /roadmap-review ──→ /light-spec (next phase begins)
```

**Stage 0** is the foundation contract — a set of artifacts the dev pipeline depends on. Greenfield projects build the contract by running the full Stage 0 chain; brownfield projects skip `/concept` and `/define`; inherited projects verify and proceed. See [Entry Modes](#stage-0-foundation) below. After Stage 0 is satisfied, the dev pipeline repeats for each phase of features. Between phases, `/phase-plan --next` selects the next batch and `/roadmap-review` validates before speccing begins again.

---

## Stage 0: Foundation

Stage 0 is the **foundation contract** — a set of artifacts the dev pipeline (Stages 1-5) requires before the daily loop is safe to run. It is not a script you run once; it is a pre-condition. *How* the contract is satisfied depends on your entry mode.

### Entry Modes

Pick the mode that matches your situation. Full description in [method.md § Entry Modes](method.md#entry-modes).

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield`, `/vbw:init`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` |
| **Inherited** | New contributor joining a Pipekit project | None — verify foundation, jump to dev pipeline | All of Stage 0 |

`/startup` auto-detects the mode and confirms with you before proceeding (same pattern as tier resolution in `/work`). `/strategy-from-code` (auto-audit for brownfield) is deferred to v1.4.0; brownfield currently routes through `/strategy-create` with a manual-edit note.

The rest of this section describes the **greenfield flow** in detail. Brownfield skips Steps 0.1 and 0.2 — adapt accordingly. Inherited mode runs no Stage 0 steps; jump straight to [Stage 1](#stage-1-definition) once the foundation check passes.

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

### Step 0.5: VBW Init

**Skill:** `/vbw:init`
**Input:** —
**Output:** `.vbw-planning/` directory scaffold

VBW (Vibe-Based Workflow) is the planning and execution engine. `/vbw:init` creates the directory structure that VBW uses to track roadmap, state, plans, and execution.

This step is simple — run `/vbw:init` and it scaffolds:
```
.vbw-planning/
├── ROADMAP.md        ← populated by /roadmap-create (next step)
├── STATE.md          ← tracks progress
├── linear-map.json   ← Linear ID mappings
└── phases/           ← PLAN.md files go here during execution
```

---

### Step 0.6: Roadmap Create

**Skill:** `/roadmap-create`
**Input:** Strategy docs + `project-definition.md`
**Output:** `.vbw-planning/ROADMAP.md` + populated Linear board + `.vbw-planning/linear-map.json`

This is where strategy becomes work items. The skill reads your strategy docs and project definition, extracts requirements, groups them into feature clusters, identifies dependencies, and populates both ROADMAP.md and Linear.

**What it produces:**

1. **ROADMAP.md** — requirements organized by stage, grouped into feature clusters, with dependency mapping and strategy doc traceability
2. **Linear Issues** — one issue per requirement, with:
   - Correct status (On Deck for Stage 1, Future Phases for Stage 2+, Ideas for parking lot)
   - Dependency relations (`blocked_by`)
   - Type and domain labels
   - Milestone (Work Package) assignment
3. **linear-map.json** — ID mappings between roadmap and Linear

**Feature clusters become Linear Projects.** A feature cluster is a logical grouping of related requirements — "Data Foundation", "Search & CRUD", "Auth & Permissions." Each becomes a Linear Project under its stage's Initiative.

**Manual vs. automated:** The skill automates issue creation, relations, and labels via MCP. For things that require the Linear UI (initiatives, workflow states), it gives explicit step-by-step instructions.

**The `--verify` flag:** After completing manual Linear setup, run `/roadmap-create --verify` to confirm everything is wired up correctly.

---

### Step 0.7: Phase Plan

**Skill:** `/phase-plan`
**Input:** Populated Linear board + `.vbw-planning/ROADMAP.md`
**Output:** `.vbw-planning/PHASES.md` + issues promoted to "Needs Spec"

A phase is a batch of issues selected for the current execution cycle. This skill selects which issues to work on next, validates dependencies, and promotes them so the spec pipeline can begin.

**Phase composition guidelines:**

| Guideline | Target |
|-----------|--------|
| Phase size | 3-8 issues |
| Complexity mix | At least 1 Low for quick wins, no more than 2 High |
| Dependencies | No issue blocked by something outside the phase (unless it's Done) |
| Milestone coverage | Prefer completing milestones over splitting them |

**What happens when you approve a phase:**

1. Selected issues move from "On Deck" → "Needs Spec"
2. If On Deck is now empty, issues from "Future Phases" get promoted to On Deck
3. A Linear comment is posted on each issue noting its phase assignment
4. `.vbw-planning/PHASES.md` is created/updated with the phase registry

**PHASES.md tracks phase history:**
```markdown
## Current Phase: Phase 1
- Started: 2026-04-08
- Theme: Foundation
- Milestone(s): WP-1 Data Foundation, WP-2 Search
- Issues:
  - PROJ-1 — Core data model [Needs Spec]
  - PROJ-2 — Basic search [Needs Spec]
  - PROJ-3 — User authentication [Needs Spec]

## Completed Phases
- (none yet)
```

---

## Stage 0 Gate: Roadmap Review

**Skill:** `/roadmap-review`

Before the spec pipeline begins, `/roadmap-review` validates that Stage 0 is complete and the roadmap is healthy. This is the gate between "foundation" and "building."

**Stage 0 checks:**

| Check | File | If Missing |
|-------|------|-----------|
| Concept brief | `concept-brief.md` | Run `/concept` |
| Project definition | `project-definition.md` | Run `/define` |
| Strategy docs | `Strategy/` matching config | Run `/strategy-create` |
| VBW scaffold | `.vbw-planning/` | Run `/vbw:init` |
| Roadmap | `.vbw-planning/ROADMAP.md` | Run `/roadmap-create` |
| Linear board | Issues exist for requirements | Run `/roadmap-create` |
| Phase defined | `.vbw-planning/PHASES.md` | Run `/phase-plan` |

**Ongoing health checks** (run every phase):

- **Completeness** — every roadmap requirement has a Linear issue
- **Assignment** — issues are in the correct stage/project/milestone
- **Dependencies** — `blocked_by` relations match the roadmap
- **Ordering** — workflow states are consistent with dependency order
- **Spec coverage** — how many issues in the current phase have specs
- **Doc freshness** — strategy docs flagged if features shipped without a sync

If any check fails, the report tells you exactly which skill to run to fix it.

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
- `[TBD]` forces VBW to guess
- Core decisions are missing
- Source of truth is unclear for calculations/data
- Acceptance criteria aren't testable

**Output:** Pass/Revise verdict, readiness score (X/10), blocking issues, fast path to pass.

If the verdict is **Revise**, the spec goes back to `/light-spec` for iteration. This loop continues until the agent passes.

### Human Review

**Tool:** You, in Linear

After agent review passes, you review the spec in Linear. This is where product decisions get locked in — scope, priority, trade-offs.

**What you're checking:**
- Does the scope match your intent?
- Are the decisions correct?
- Is the priority right relative to other work?
- Anything the agent missed that you know from context?

**Outcome:** Move the issue to "Approved" in Linear. This signals that the spec is locked — no more scope changes. VBW planning can begin.

---

## Stage 2: Plan + Build

### Branch

**Commands:** `pk next` then `pk branch <ID>`
**Input:** Approved spec
**Output:** Worktree + feature branch + Linear → In Progress

`pk next` is phase-aware (v2.1.0+): it reads `## Current Phase:` from `.vbw-planning/PHASES.md`, matches to `linear-map.json`, and groups Linear results by status (In Progress / Approved / Needs Spec) with per-group hints. Falls back to global "next Approved" when no phase context.

`pk branch <ID>` is mechanical setup — idempotent against Linear+git ground truth. It creates the worktree, the branch, and transitions Linear:

- Creates `feature/<ID>-<3-word-slug>` (slug derived from issue title)
- Worktree at `.worktrees/<ID>-<slug>`
- Symlinks `.env` / `.env.local` / `.mcp.json` into the worktree
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

Tier inference (Quick / Standard / Heavy) drives which gates apply. Tier is **always confirmed with the human** before the verdict step — automatic tier escalation/de-escalation is disallowed by design. See `method.md` § Tiers and `templates/tier-{quick,standard,heavy}.md` for per-tier gate tables. Quick skips spec review, milestone-readiness, plan review, and QA; Heavy adds security review + mandatory `/strategy-sync` before close.

**Backend dispatch** is per `method.config.md`:

| Backend | What `/work` does |
|---------|-------------------|
| `vbw` | Spawns `vbw-lead` to generate `PLAN.md`, then `vbw-dev` to execute. PLAN.md captures task decomposition with verify/done criteria per task. Each task gets one atomic commit. |
| `native` | Plans + executes in your current Claude session. Uses parallel `Agent` calls only for grounding (codebase reads, doc lookups). No PLAN.md artifact. |

`--deep` adds spec-validator + plan-review + security-review subagents for the planning step. Use it when scope is fuzzy or risk is high.

**All commits include the issue ID** in the message format: `feat(scope): description (PROJ-1)`. CLAUDE.md conventions are followed (vbw-dev reads it; native backend reads it via your session).

### Plan Review (vbw backend)

**Skill:** `/review-plan` (spawns `plan-reviewer` agent at `model: opus`)
**Input:** `PLAN.md` (vbw backend only — native backend has no PLAN.md to review)
**Output:** Validated plan or revision requests

Run between `vbw-lead`'s plan generation and `vbw-dev`'s execution. The plan reviewer stress-tests:

- Scope alignment with the spec
- Task atomicity (each task produces one logical commit)
- Dependencies and ordering
- Success criteria completeness
- Risk identification

If the plan fails review, it goes back to vbw-lead for rework. Once the plan passes, vbw-dev's execution begins.

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

If verify fails → fix the gaps in the worktree (often by re-invoking `/work` with feedback) and rerun. If verify passes → ship.

### Ship

**Command:** `pk ship` (or `pk ship --review` for antagonistic review)
**Input:** Verify-passed worktree
**Output:** Branch pushed, PR open against integration branch, Linear → UAT

`pk ship` is idempotent — rerun is safe. It:

- Pushes the feature branch (skips if already current)
- Opens a PR via `gh pr create` against the integration branch from `method.config.md` (`Integration branch: dev` for most projects)
- Transitions Linear from In Progress → UAT (or → In Review per project config)

`pk ship --review` additionally:

- Posts a Linear comment flagging review-in-flight (closes the mid-loop visibility gap — v2.1.0)
- Prints the antagonistic reviewer subagent invocation for you to paste into a Claude session

The reviewer plays devil's advocate vs `/work` + `/verify` (which validate spec adherence) — surfaces cross-cutting concerns the spec didn't think to mention. Don't skip on anything auth, security, financial, or compliance-adjacent.

### PR Review (opt-in)

**Skills:** `/pr-fix` and `/pr-security-review`

After the reviewer posts findings to the PR, two skills triage them:

**`/pr-fix`** — precision PR review across 4 dimensions with confidence-gated findings. Reads PR review comments + diff, scans for cross-spec handoff promises (any "X will…" reference in the spec must have landed in this PR), then lets you triage interactively (fix / reject / defer). Applies fixes as separate commits, validates the gate, force-pushes to the PR. Posts a Linear comment with the triage summary (fixed N / rejected N / deferred N).

**`/pr-security-review`** — security-focused antagonistic review for migrations, RLS policies, SECURITY DEFINER functions, GRANT/REVOKE, auth code, and Server Actions on privileged tables. 30+ rubric items across 6 surface categories. Use **instead of** (or alongside) the generic reviewer when the PR touches any of those surfaces.

Skip PR review for pure copy/UI tweaks and internal-only refactors with no external surface. Always opt in for anything labeled `auth-rls`, `payments`, `pii`, `compliance`, `breaking-change`.

### UAT

**Tool:** You (in the running app — Vercel preview URL or local dev)
**Input:** Built feature, PR open with preview deployment
**Output:** Accepted or rejected against spec AC

Test the feature against the spec's acceptance criteria under real usage conditions. The PR should already have a Vercel preview URL by the time you start UAT (Vercel auto-deploys on PR open).

**Accept:** Merge the PR (squash). Then exit the worktree and run `pk done <ID>` from the parent repo — this cleans up the worktree + branch and posts commits + diffstat to Linear.

**Reject:** Describe what's wrong — the issue re-enters execution with your feedback (return to Stage 2's `/work`).

---

## Stage 4: Release

**Every step forward is a PR.** No direct merges between long-lived branches.

Your git architecture (chosen during `/startup`) determines the release flow:

**Two-tier** (`dev` → `main`):
```
feature/* → PR to dev → PR to main
```
- Promotion skills: `/g-promote-dev`, `/g-promote-main`
- Merge to main → issues move to Done

**Three-tier** (`dev` → `beta` → `main`):
```
feature/* → PR to dev → PR to beta → PR to main
```
- Promotion skills: `/g-promote-dev`, `/g-promote-beta`, `/g-promote-main`
- Merge to beta → issues move to UAT
- Merge to main → issues move to Done

Each project creates its own promotion skills during `/startup` Phase 9, based on the chosen model.

**CI enforces the pre-deploy gate at every PR.** If types, lint, or tests fail, the merge is blocked.

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
- After UAT passes for a phase
- Before stakeholder presentations
- Before onboarding new team members
- When `/roadmap-review` flags doc staleness

---

## Between Phases

When a phase's issues are all Done (or a phase is otherwise complete):

1. **`/phase-plan --next`** — archives the completed phase and proposes the next one
   - Shows a brief retrospective: how long the phase took, complexity accuracy
   - Identifies newly unblocked issues (their blockers just completed)
   - Proposes the next phase composition
2. **`/roadmap-review`** — validates the roadmap is still healthy before speccing
3. **`/light-spec`** — begin speccing the next phase's issues

**`/phase-plan --status`** is available anytime for a progress dashboard:
```
Phase 2 Status — 2026-04-15

| Issue | Title | Status | Days |
|-------|-------|--------|------|
| PROJ-4 | Advanced search | Done | — |
| PROJ-5 | Saved searches | Building | 2d |
| PROJ-6 | Activity log | UAT | 0d |
| PROJ-7 | Export reports | Needs Spec | 4d |

Progress: 1/4 Done (25%)
Alert: PROJ-7 in "Needs Spec" for 4 days — run /light-spec PROJ-7
```

**`/phase-plan --rebalance`** adjusts the current phase if priorities shift — add, remove, or swap issues.

---

## The Phase Model

Phases, milestones, and cycles serve different purposes. Understanding their relationship is important for phase planning.

### The Three Concepts

| Concept | What It Is | Linear Construct | Lifespan |
|---------|-----------|-----------------|----------|
| **Milestone (Work Package)** | A feature cluster — groups related issues for gating | Linear Milestone | Permanent within a stage |
| **Phase** | An execution batch — what we're building right now | `.vbw-planning/PHASES.md` | Temporary (one cycle) |
| **Cycle** (optional) | A time-boxed sprint — capacity planning | Linear Cycle | Configurable duration |

### How They Relate

**Milestones group by feature. Phases group by execution order.**

A phase may pull from multiple milestones:
```
Phase 1:
  - PROJ-1 from WP-1 (Foundation)
  - PROJ-2 from WP-1 (Foundation)
  - PROJ-3 from WP-2 (Search)
```

A large milestone may span multiple phases:
```
WP-2 (Search) — 8 issues:
  - Phase 1: PROJ-3, PROJ-4 (core search)
  - Phase 2: PROJ-7, PROJ-8 (advanced search, export)
  - Phase 3: PROJ-11, PROJ-12, PROJ-13, PROJ-14 (filters, saved searches)
```

### Milestone Gating

`/work` uses milestones for its gating check: all sibling issues in a milestone must be at least Specced before any can enter Plan + Build. This ensures coordinated planning within a feature cluster.

### Linear Cycles (Optional)

If you want time-boxed sprints with capacity tracking, map phases to Linear Cycles. This is optional — the method works without cycles. Cycles add:
- Start/end dates
- Team capacity tracking
- Velocity measurement

### Phase State Tracking

Phases are tracked in `.vbw-planning/PHASES.md`, not in Linear. Linear tracks individual issue status (Needs Spec, Building, UAT, Done). PHASES.md tracks which issues belong to which phase and the phase's overall progress.

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

Linear is the view layer. VBW is the planning engine. They share data but serve different purposes.

### Hierarchy

```
Initiative = Stage              "What stage does this ship in?"
  └── Project = Feature Cluster   "What area of the product?"
       └── Issue = Feature/Task     "What work needs to happen?"
            └── Milestone = Work Package  "What execution batch?"
```

### Workflow States

```
Planned path:
  Triage → Ideas → Future Phases → On Deck → Needs Spec → Specced → Approved → Building → UAT → Done

Ad-hoc path:
  Triage → In Progress → UAT → Done

Terminal:
  → Canceled | Duplicate
```

**Key distinction:**
- **Building** = VBW owns it. Phase-batched, planned work.
- **In Progress** = You're doing it manually. Ad-hoc, outside the phase.

### Phase Management via Status

| Status Group | Phase Role |
|-------------|-----------|
| Ideas | Someday — evaluated but not scheduled |
| Future Phases | Known future stage — not current or next |
| On Deck | Next phase — staging area |
| Needs Spec → UAT | Current phase — active pipeline |
| Done | Shipped |

`/phase-plan` manages the On Deck → Needs Spec promotion. Refilling On Deck from Future Phases happens when the current phase starts.

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
| Feature specs, AC, scope | Linear issue description | VBW plans |
| Task decomposition | `.vbw-planning/` PLAN files | Linear |
| Execution status | Both (synced via `/sync-linear`) | — |
| Code | Git | Linear or VBW |
| Phase composition | `.vbw-planning/PHASES.md` | Linear |

**Never create Linear issues for VBW tasks.** Features are the bridge between Linear and VBW.

---

## VBW Integration

VBW (Vibe-Based Workflow) is the planning and execution engine. Here's where its tools appear in the pipeline:

| Pipeline Stage | VBW Tool | Purpose |
|---------------|----------|---------|
| Stage 0.5 | `/vbw:init` | Scaffold `.vbw-planning/` |
| Stage 0.6 | `/roadmap-create` writes to `.vbw-planning/ROADMAP.md` | Populate roadmap |
| Stage 0.7 (optional) | `/vbw:discuss` | Discuss first phase before speccing |
| Stage 2 | VBW Lead Agent | Generate PLAN.md from spec |
| Stage 3 | VBW Dev Agent | Execute tasks with atomic commits |
| Stage 3 | VBW QA Agent | Verify against acceptance criteria |
| Anytime | `/vbw:status` | Project progress dashboard |

### VBW Agent Roster

| Agent | Role |
|-------|------|
| Architect | Requirements → roadmap, stage decomposition |
| Lead | Research, task decomposition, plan generation |
| Dev | Plan execution with atomic commits |
| QA | Goal-backward verification |
| Debugger | Scientific method bug diagnosis |
| Docs | Documentation generation |
| Scout | Research and codebase scanning |

### Keeping VBW Updated

When `/work` runs against Low-complexity issues with `Backend: native` (in-context plan + execute, no PLAN.md), `.vbw-planning/STATE.md` must still be updated to reflect progress. The method tracks all work — not just VBW-planned work.

---

## Three-Layer Enforcement

The method uses three layers to enforce conventions. Each layer serves a different audience:

| Layer | Purpose | Who Reads It | When |
|-------|---------|-------------|------|
| **CLAUDE.md** | Documents conventions | VBW agents during execution | Every agent session |
| **CI / Hooks** | Hard enforcement — blocks merges | Everyone (agents and humans) | Every PR |
| **Skills** | Interactive shortcuts | You, in hands-on sessions | When you invoke them |

**Skills are convenience wrappers.** They automate the same conventions documented in CLAUDE.md. VBW agents don't call skills — they read CLAUDE.md and write code directly.

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
| Workflow State IDs | UUID for each of the 13 states — skills use these for transitions |
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
| `sop/` | `method/sop/` |
| `templates/` | `method/templates/` |
| `method.md` | `method/method.md` |
| `STARTUP.md` | `method/STARTUP.md` |

### What Never Gets Synced

| File | Why |
|------|-----|
| `method.config.md` | Project-specific |
| `.claude/rules/` | Project coding conventions |
| `.claude/skills/{project-specific}/` | Stack-specific skills |
| `.claude/overrides/` | Sync-safe customization (applied on top of sync; see `method.md` § Sync-Safe Overrides) |
| `.vbw-planning/` | Project state |
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
| Roadmap Create | `/roadmap-create` | Strategy → ROADMAP.md + Linear |
| Roadmap Verify | `/roadmap-create --verify` | Check Linear matches roadmap |
| Phase Plan | `/phase-plan` | Select first/next phase |
| Phase Status | `/phase-plan --status` | Current phase progress |
| Phase Next | `/phase-plan --next` | Archive + plan next phase |
| Phase Rebalance | `/phase-plan --rebalance` | Adjust current phase |

### Development Pipeline

| Skill | Command | What It Does |
|-------|---------|-------------|
| Roadmap Review | `/roadmap-review` | Full health check (Stage 0 gate) |
| Brainstorm | `/brainstorm` | Feature-level ideation |
| Light Spec | `/light-spec PROJ-1` | Create spec for an issue |
| Light Spec Revise | `/light-spec-revise PROJ-1` | Apply Spec Review Agent feedback surgically |
| Spec Preflight | `/spec-preflight PROJ-1` | Empirical pre-flight checks before /launch (file paths, baselines, Linear status). Read-only. |
| Launch | `/launch PROJ-1` | Validate gates → route → execute |
| Launch Auto | `/launch PROJ-1 --auto` | Standard tier only: auto-chain Lead → plan-review → Dev → QA → close. Pauses only at the two verdict gates (3 human inputs total). |
| Launch Batch | `/launch --milestone WP-1` | Launch all ready issues in a WP |
| Launch Dry Run | `/launch --dry-run PROJ-1` | Check gates without executing |
| Todo Runner | `/linear-todo-runner` | Batch execute Low-complexity issues |
| Todo Prep | `/linear-todo-runner --prep` | Generate draft AC for unspecced issues |

### Ongoing Operations

| Skill | Command | What It Does |
|-------|---------|-------------|
| Sync Linear | `/sync-linear` | Bidirectional VBW ↔ Linear sync |
| Linear Status | `/linear-status` | Quick board triage view |
| Branch | `/branch feature-name` | Create worktree + branch + Linear link |
| Start Session | `/start-session` | Review progress, capture intentions |
| End Session | `/end-session` | Changelog, Linear updates |
| Strategy Sync | `/strategy-sync` | Update docs to match shipped code |
| Pipekit Help | `/pipekit-help` | Read project state, recommend next pipeline step |
| Release Changelog | `/release-changelog --version vX.Y.Z` | Generate draft CHANGELOG entry from commits between tags (Pipekit-internal release tooling) |
| Pipekit Update | `/pipekit-update` | Pull latest Pipekit from GitHub into project |
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

Skills with Red Flags: `/concept`, `/define`, `/strategy-create`, `/roadmap-create`, `/phase-plan`, `/launch`, `/light-spec`, `/brainstorm`.

---

## Portable Rule Templates

The method includes rule templates in `templates/rules/` that consuming projects sync into their `.claude/rules/` directory. These are auto-loaded every session by Claude Code under the **hub-and-spoke model** (CLAUDE.md hub → rules/ auto-loaded → method/sop/ demand-loaded).

Canonical files use a `pipekit-` prefix so they never collide with project-specific rule filenames. Three canonical topic files ship from Pipekit:

### `pipekit-discipline.md`

Cross-cutting AI coding discipline:

- **Red Flags** — thoughts that mean "go slower, not faster" (e.g., "this is simple, I don't need a plan" → you do)
- **Ad-hoc Plan Gate** — 3-5 bullet plan template for non-VBW interactive changes, with When-This-Applies / Does-Not-Apply scope
- **Scope hygiene** — no features/abstractions beyond the task, no speculative error handling, no backwards-compat shims
- **Comment & commit discipline** — default to no comments, one atomic change per commit, never amend published

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
| **Now** | Route to pipeline — assign to a phase/stage, move to Needs Spec |
| **Later** | Park with explicit trigger condition + target phase. Tagged `Parked` in Linear. |
| **Kill** | Archive with rationale. Move to Canceled. |

**Parking rules for "Later" items:**
- Must have a trigger condition (e.g., "revisit when PROJ-56 ships")
- Must have a target phase/stage (e.g., "Phase 4+")
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
| `/phase-plan --rebalance` | Adds "Now" dispositions to current phase |

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
When code and documentation disagree, trust the code. Strategy docs track reality, not aspirations. `/strategy-sync` enforces this after every phase.

### Every Step Forward Is a PR
No direct merges between long-lived branches. Each promotion (dev → beta → main) is a PR with CI gates. Hotfixes cherry-pick back immediately.
