---
name: phase-plan
description: Compose the next execution phase from the roadmap, track phase state, promote to Needs Spec. Use when current phase is closing and you need to pick the next batch. Use when PHASES.md needs a fresh Current Phase entry.
---

# Phase Plan Skill

You are a phase composition planner. Your job is to define, track, and manage execution phases. Read `method.config.md` for project context. A phase is a batch of issues selected for the current execution cycle — pulled from the roadmap, validated for dependencies, and promoted to "Needs Spec" so the spec pipeline can begin.

## Triggers

- `/phase-plan`
- `/phase-plan --next`
- `/phase-plan --status`
- `/phase-plan --rebalance`

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Plan the next phase (or first phase if none exists) |
| `--next` | Propose the next phase after the current one ships |
| `--status` | Show current phase progress dashboard |
| `--rebalance` | Adjust current phase composition (add/remove issues) |
| `--dry-run` | Show proposed phase without promoting issues |

## Prerequisites

- `.vbw-planning/ROADMAP.md` must exist (output of `/roadmap-create`)
- Linear board must be populated with issues
- `method.config.md` must have Linear state IDs configured

## Phase Model

### How Phases Relate to Milestones and Cycles

| Concept | Purpose | Linear Construct | Relationship to Phases |
|---------|---------|-----------------|----------------------|
| **Milestone (Work Package)** | Feature cluster — groups related issues for gating | Linear Milestone | A phase may pull from multiple milestones. A large milestone may span multiple phases. |
| **Phase** | Execution batch — what we're building right now | Tracked in `.vbw-planning/PHASES.md` | The unit of work between `/phase-plan` and `/phase-plan --next`. |
| **Cycle** (optional) | Time-boxed sprint — capacity planning and velocity tracking | Linear Cycle | Optional overlay. If used, a phase maps to a cycle for time-boxing. Not required. |

**Milestones group by feature. Phases group by execution order.** These are different dimensions — milestones are permanent structure, phases are temporal.

### Phase State

Phases are tracked in `.vbw-planning/PHASES.md`, not in Linear. Linear tracks individual issue status; PHASES.md tracks which issues belong to which phase.

---

## Execution Steps

### Default: Plan a Phase

#### Step 1 — Assess Current State

1. Read `.vbw-planning/PHASES.md` if it exists
2. Read `.vbw-planning/ROADMAP.md` for phase priorities
3. Read `method.config.md` for Linear state IDs
4. Fetch all issues in the current phase from Linear:
   - Issues in On Deck, Needs Spec, Specced, Approved, Building, UAT
   - Group by status to understand pipeline state

If a current phase exists and has unfinished issues, warn:
_"Phase {N} is still in progress ({M} issues not yet Done). Plan the next phase anyway, or check status with `--status`?"_

#### Step 2 — Identify Candidates

1. Fetch issues in "On Deck" status (next phase candidates)
2. If On Deck is empty, check "Future Phases" for promotable issues
3. For each candidate:
   - Check dependencies via `mcp__linear-server__get_issue` with `includeRelations: true`
   - Classify as **ready** (no unresolved blockers) or **blocked** (list blockers)
   - Note milestone membership
   - Note complexity if available from existing description

#### Step 3 — Compose the Phase

Propose a phase following these guidelines:

| Guideline | Target |
|-----------|--------|
| Phase size | 3-8 issues |
| Complexity mix | At least 1 Low for quick wins, no more than 2 High |
| Dependency safety | No issue blocked by another issue outside the phase (unless the blocker is Done) |
| Milestone coverage | Prefer completing milestones over splitting them |
| Phase progress | Prioritize issues that unblock downstream work |

Present the proposal:

```
## Proposed Phase {N}: {Theme or Phase Name}

Issues (6):
  1. PROJ-1  — User authentication [Low] (WP-1: Foundation)
  2. PROJ-2  — Core data model [Medium] (WP-1: Foundation)
  3. PROJ-3  — Basic search [Medium] (WP-2: Search)
  4. PROJ-4  — Search filters [Low] (WP-2: Search)
  5. PROJ-5  — Record detail view [Medium] (WP-2: Search)
  6. PROJ-6  — Admin dashboard [Low] (WP-3: Admin)

Milestones touched: WP-1 (2/4 issues), WP-2 (3/5 issues), WP-3 (1/6 issues)
Complexity: 3 Low, 3 Medium, 0 High
Dependencies: PROJ-3 depends on PROJ-2 (both in phase — OK)

Not included (blocked):
  - PROJ-7 — Advanced search (blocked by PROJ-3)
  - PROJ-8 — Export reports (blocked by PROJ-5)

Remaining On Deck: 4 issues for future phases

Approve this phase? (y/n/edit)
```

#### Step 4 — Promote Issues

On approval:

1. Move selected issues from "On Deck" to "Needs Spec" via `mcp__linear-server__save_issue`:
   - `stateId`: Needs Spec state ID from `method.config.md`
2. If On Deck is now depleted, promote issues from "Future Phases" to "On Deck" for the next phase pipeline
3. Post a Linear comment on each promoted issue: `"Assigned to Phase {N}. Ready for /light-spec."`

#### Step 5 — Write PHASES.md

Create or update `.vbw-planning/PHASES.md`:

```markdown
# Phases

## Current Phase: Phase {N}
- **Started:** {date}
- **Theme:** {theme or phase name}
- **Milestone(s):** {list}
- **Issues:**
  - PROJ-1 — User authentication [Needs Spec]
  - PROJ-2 — Core data model [Needs Spec]
  - PROJ-3 — Basic search [Needs Spec]
  - PROJ-4 — Search filters [Needs Spec]
  - PROJ-5 — Record detail view [Needs Spec]
  - PROJ-6 — Admin dashboard [Needs Spec]

## Next Phase (proposed)
- **Issues (On Deck):** PROJ-9, PROJ-10, PROJ-11, PROJ-12
- **Blocked until Phase {N} completes:** PROJ-7, PROJ-8

## Completed Phases
(none yet)
```

#### Step 6 — Summary

```
## Phase {N} Planned

Issues promoted to "Needs Spec": {N}
On Deck refilled: {N} issues promoted from Future Phases

Next steps:
  - /roadmap-review — validate the phase before speccing
  - /light-spec PROJ-1 — start speccing the first issue
  - /phase-plan --status — check progress anytime
```

---

### `--status`: Phase Progress Dashboard

1. Read `.vbw-planning/PHASES.md` for current phase composition
2. Fetch current status of each phase issue from Linear
3. Display:

```
## Phase {N} Status — {date}

| Issue | Title | Status | Days in Status |
|-------|-------|--------|---------------|
| PROJ-1 | User authentication | Done | — |
| PROJ-2 | Core data model | Building | 2d |
| PROJ-3 | Basic search | Specced | 1d |
| PROJ-4 | Search filters | Needs Spec | 3d |
| PROJ-5 | Record detail view | UAT | 0d |
| PROJ-6 | Admin dashboard | Approved | 1d |

Progress: 1/6 Done (17%)
Pipeline: 1 Needs Spec → 1 Specced → 1 Approved → 1 Building → 1 UAT → 1 Done

Alerts:
  - PROJ-4 has been in "Needs Spec" for 3 days — run /light-spec PROJ-4
  - PROJ-2 has been in "Building" for 2 days — check progress

Phase started: {date} ({N} days ago)
```

---

### `--next`: Plan the Next Phase

1. Archive the current phase to "Completed Phases" in PHASES.md
2. Run the default phase planning flow (Steps 1-6)
3. Include a brief retrospective:

```
## Phase {N-1} Retrospective

Completed: {date} ({N} days)
Issues: {done}/{total} completed
  - {failed} failed (returned to Approved)

Complexity accuracy:
  - Low estimates: averaged {X}h (target: 2-4h)
  - Medium estimates: averaged {X}h (target: 6-10h)
```

---

### `--rebalance`: Adjust Current Phase

1. Show current phase composition
2. Options:
   - **Add issues:** Move from On Deck → Needs Spec, add to PHASES.md
   - **Remove issues:** Move from Needs Spec → On Deck (only if not yet started), remove from PHASES.md
   - **Replace:** Remove one, add another
3. Validate dependencies after rebalance
4. Update PHASES.md

---

## Rules

- **Target 3-8 issues per phase.** Fewer is fine for a first phase or complex work. More than 8 creates coordination overhead.
- **Dependencies within the phase should be satisfiable.** If PROJ-3 depends on PROJ-2, both should be in the phase (or PROJ-2 should already be Done).
- **Prefer completing milestones over splitting them.** Split only when the WP is too large (>8 issues) or has mixed priorities.
- **On Deck is the staging area.** Issues move: Future Phases → On Deck → Needs Spec. `/phase-plan` manages the On Deck → Needs Spec promotion. Refilling On Deck from Future Phases happens automatically.
- **PHASES.md is the phase registry.** Linear tracks individual issue status. PHASES.md tracks phase composition and history.
- **Human decides phase composition.** Present a recommendation with rationale, but the user approves.

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Overloading a phase** → Keep to 3-8 issues. Larger phases create coordination overhead and hide priorities.
- **Including blocked issues optimistically** → Only include issues whose blockers are Done. Planning on hope leads to stalled phases.
- **Splitting a milestone across many phases** → If you're splitting across 4+ phases, the milestone itself may be too big — consider breaking it up in Linear.
- **Stale issues in "Needs Spec"** → If an issue has been in "Needs Spec" for >3 days, investigate. Either spec it or swap it out for something ready.

## Next-step output

After phase planning completes, emit an inline `➜ Next:` line in your terminal output pointing to the highest-leverage first `/01-light-spec` call. Include why that issue was picked, what parallelizes after it, and what's blocked until it lands. Do **not** write a `NEXT.md` file — v2 retired the mirror; `pk next` reads "what's next?" live from Linear.

## Related

- `/roadmap-create` — previous step: creates the roadmap and populates Linear
- `/roadmap-review` — run after phase planning to validate before speccing
- `/light-spec` — next step: spec the first issue in the phase
- `/work` — executes specced issues (uses milestones for gating, not phases)
- `pk status` / `pk next` — quick board view (complementary to `--status`)
