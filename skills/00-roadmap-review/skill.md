---
name: roadmap-review
description: Audit roadmap health — issues, dependency order, spec coverage, doc freshness. Use when speccing a new phase. Use when /phase-plan output looks suspicious. Use before /roadmap-create reruns.
---

# Roadmap Review Skill

**v4.1.0** — Last updated: 2026-06-21 *(validate the Linear-native phase surface — phase order lives in Linear `i{N}.` initiatives / `P{N}.` projects per `method.config.md` § Phase Surface, not in `.vbw-planning/PHASES.md` or `linear-map.json`)*

You are a roadmap health auditor. Your job is to run a comprehensive health check of the overall plan. Read `method.config.md` for project context — including the **§ Phase Surface** contract that defines the Linear-native phase model this skill validates. Run this before speccing a new phase to ensure the roadmap is coherent and complete.

## Triggers

- `/roadmap-review`
- "review the roadmap"
- "check the plan"
- "roadmap health"

## Purpose

Validate that:
1. **Stage 0 outputs exist** — concept, definition, strategy docs, roadmap, Linear phase hierarchy
2. The **Linear-native phase surface is well-formed** — `i{N}.` initiatives and `I{N}.P{N}.` projects are correctly named, ordered, and placed (see § Phase Surface in `method.config.md`; projects carry their initiative number — bare `P{N}.` is legacy-valid but a rename candidate)
3. Every requirement is placed in an `I{N}.P{N}.` project — no orphan issues that should live in a phase
4. Dependencies and blockers are set correctly
5. Workflow states are consistent with dependency ordering
6. Spec coverage is adequate for the next planned phase
7. Strategy docs are flagged if stale

This is the **gate between Stage 0 (Foundation) and Stage 1 (Definition)** in the Pipekit pipeline. Run it before starting a new phase of specs.

## Execution Steps

### Stage 0 Check — Foundation

Validate that pre-pipeline outputs exist. If any are missing, report which skill to run.

| Check | Surface | If Missing |
|-------|---------|-----------|
| Concept brief | `concept-brief.md` | Run `/concept` |
| Project definition | `project-definition.md` | Run `/define` |
| Strategy docs | `Strategy/` matching `method.config.md` manifest | Run `/strategy-create` |
| Roadmap source | `.vbw-planning/ROADMAP.md` with content (optional legacy — strategy docs are the live source) | Run `/roadmap-create` |
| Phase initiatives | At least one Linear delivery initiative named `i{N}.` exists | Run `/roadmap-create` |
| Phase projects | The current initiative has at least one `I{N}.P{N}.` project (legacy bare `P{N}.` also counts) | Run `/roadmap-create` |
| Linear board | Issues exist, placed in `I{N}.P{N}.` projects | Run `/roadmap-create` |

The phase surface lives in **Linear**, not in a file: an initiative named `i{N}. label` is an ordered PHASE; a project named `I{N}.P{N}. label` is an ordered SUB-PHASE (it carries its initiative number; legacy bare `P{N}.` still parses); issues live in projects. `.vbw-planning/PHASES.md` and `linear-map.json` are **retired** — do not assert they exist or are consistent (a stale copy may linger as a `bin/pk` fallback, but no skill writes them).

If any Stage 0 check fails, report it prominently at the top of the health report:

```
## Stage 0: Foundation — Incomplete

Missing:
  - concept-brief.md → run /concept
  - no `i{N}.` delivery initiatives in Linear → run /roadmap-create

Complete Stage 0 before entering the spec pipeline.
```

If all Stage 0 checks pass, continue to the next check.

### Phase 1 — Gather State

Linear is the source of truth for the phase surface. Read it live; the retired `.vbw-planning/PHASES.md` and `linear-map.json` are not consulted.

1. (Optional legacy) Read `.vbw-planning/ROADMAP.md` for the strategy-derived requirements list, if present. Strategy docs are the live requirement source; ROADMAP.md is a legacy mirror.
2. Fetch all initiatives via `mcp__linear-server__linear_getInitiatives`. Partition them:
   - **Delivery initiatives** = names matching `^i(\d+)\.` — these are the ordered PHASES.
   - **Strategic initiatives** = unprefixed names — themes, not phases; carried into Phase 2's strategic-initiative check.
3. Determine the **current phase** = the lowest `i{N}` delivery initiative whose status is not `Completed`.
4. For each delivery initiative (current + next-up), fetch projects via `mcp__linear-server__linear_getProjects`. Projects named `^P(\d+)\.` are the ordered SUB-PHASES; `{N}` orders them within the initiative.
5. Determine the **current sub-phase** = the lowest `P{N}` project (within the current initiative) whose state is not in {`completed`, `canceled`}.
6. For each project, fetch issues via `mcp__linear-server__linear_searchIssues`.

Throughout: order comes from the integer in the `i{N}.` / `P{N}.` name prefix (numeric), **never** from Linear's `sortOrder` field.

### Phase 2 — Completeness Check

Source the requirements list from the strategy docs (the live source) or, if present, the legacy `.vbw-planning/ROADMAP.md`. For each phase (`i{N}.` initiative):

1. Extract the requirements that map to this phase
2. Match each requirement to Linear issues by:
   - Title keyword matching
   - Project assignment (requirement area → `P{N}.` project)
   - Description cross-references
3. **Gaps:** Requirements with NO matching issue → these need issues created
4. **Orphans:** Issues with NO matching requirement → flag for review (may be valid additions from brainstorming, or may be misassigned)

Output: Completeness table per phase (`i{N}.`).

### Phase 3 — Phase Surface Well-Formedness

This is the core Linear-native validation. The phase surface (per `method.config.md` § Phase Surface) is: delivery initiative `i{N}. label` = ordered PHASE; project `P{N}. label` = ordered SUB-PHASE within its initiative; issues live in `P{N}.` projects. Validate that this structure is well-formed:

**Initiative naming & order:**

1. Every delivery initiative is named `i{N}.` where `{N}` is an integer. Flag any initiative that looks like a phase (has delivery projects/issues under it) but is missing the `i{N}.` prefix — it would be silently treated as a strategic theme and dropped from the phase walk.
2. The `{N}` values are **unique** across delivery initiatives (no two `i2.` initiatives) and ordered (contiguous `i1, i2, i3…` is ideal; a gap is a warning, a duplicate is an error).

**Project naming & order:**

3. Every project under a delivery initiative is named `I{N}.P{N}.` (its initiative number + an integer `P{N}`); a bare `P{N}.` is legacy-valid but a rename candidate.
4. The `{N}` values are **unique within their initiative** (no two `P3.` projects in the same `i{N}.`). Duplicates are an error; gaps are a warning.

**Issue placement:**

5. Every requirement/issue that belongs to a phase is placed in a `P{N}.` project. Flag **orphan issues** — issues attached directly to a delivery initiative with no project, or issues in an unprefixed project under a delivery initiative — that should live in a `P{N}.` phase project.

**Lifecycle sanity:**

6. The **earliest non-`Completed` delivery initiative** (the current phase, by lowest `{N}`) has status `Active`. Flag if it is still `Planned`/`Backlog` (work has nowhere to land) or if multiple delivery initiatives are simultaneously `Active`.
7. Within that current initiative, its **earliest live project** (lowest `P{N}` whose state is not `completed`/`canceled`) is `started`. Flag if the current sub-phase is still `planned`/`backlog`.

**Strategic-initiative intent:**

8. For each **unprefixed** (strategic) initiative, confirm it is *intentionally* a theme, not an accidentally-unprefixed phase. Heuristic: a strategic initiative with active delivery projects/issues under it is suspicious — surface it and ask the user to confirm it should be ignored by the phase walk, or rename it `i{N}.`.

**Within-issue assignment (secondary):**

9. For issues in the current and upcoming phases, verify labels are consistent (Tier label matches phase intent, Domain label matches the `P{N}.` project cluster) and flag misassignments.

Output: a Phase Surface section listing any naming/order/placement/lifecycle violations, each with the exact rename or re-parent to apply.

### Phase 4 — Dependency Validation

1. Read light specs for issues that have them — extract dependency contracts (e.g., "PROJ-8 is a hard blocker for PROJ-7")
2. Read the WP dependency graph from `pipekit/sop/Linear SOP.md` (Dependency Graph section)
3. For each declared dependency:
   - Fetch the issue via `mcp__linear-server__linear_getIssueById` with `includeRelations: true`
   - Check that `blockedBy`/`blocks` relations exist in Linear
4. Flag missing dependency links with the exact relation to add
5. Flag circular dependencies

### Phase 5 — Ordering Validation

For each issue that has blockers:

1. Fetch blocker issue status
2. Apply ordering rules:
   - If blocker is in Ideas/Future Phases/On Deck/Needs Spec → blocked issue should NOT be in Approved/Building/In Progress
   - If blocker is in Done → the blocked issue is free to progress
   - If blocker is in Canceled → flag for review (is the dependency still relevant?)
3. Flag ordering violations with recommended state changes

### Phase 6 — Spec Coverage

For the next planned phase (issues in On Deck/Needs Spec/Specced in the current `i{N}.` initiative's live `P{N}.` projects):

1. List all issues that would enter the pipeline
2. For each issue, check spec status:
   - **No spec:** description is bare or uses old template format
   - **Has light spec:** description contains `## Light Spec` header
   - **Agent reviewed:** description contains `## Agent Review` with a verdict
   - **Agent passed:** Agent Review verdict is "Pass"
   - **Human approved:** issue is in Approved (past Specced)
3. Calculate readiness:
   - Total issues in phase
   - Issues with specs
   - Issues with passing agent review
   - Issues ready for planning (specced + approved)
4. List issues needing specs before the phase can start

### Phase 7 — Doc Freshness (Light Check)

1. Read `method.config.md` to get the strategy doc manifest
2. Read version headers from all listed strategy docs to find the oldest update date
3. Query Linear for issues in Done state
4. Count features shipped since the oldest Strategy doc was last updated
5. If significant features shipped (>3) without a doc update, flag as stale
6. List which docs are most affected by shipped features
7. Recommend `/strategy-sync` if stale

### Phase 8 — Report

Present a summary dashboard:

```markdown
## Roadmap Health — YYYY-MM-DD

### Phase Surface (Linear-native)
| Check | Result |
|-------|--------|
| Delivery initiatives named `i{N}.` | X/Y |
| Initiative `{N}` unique & ordered | OK / gaps / DUPLICATE |
| Projects named `I{N}.P{N}.` (bare `P{N}.` = rename candidate) | X/Y |
| Project `{N}` unique within initiative | OK / DUPLICATE |
| Orphan issues (not in a `P{N}.` project) | X |
| Current initiative `i{N}.` is `Active` | OK / FLAG |
| Current sub-phase `P{N}.` is `started` | OK / FLAG |
| Unprefixed initiatives confirmed strategic | X (Y need confirmation) |

**Violations:**
- Initiative "Onboarding" has delivery issues but no `i{N}.` prefix → rename to `i4. Onboarding` or confirm it is a strategic theme
- PROJ-176: attached to initiative `i2.` with no project → re-parent into a `P{N}.` project

### Completeness
| Phase | Requirements | Issues | Gaps | Orphans |
|-------|-------------|--------|------|---------|
| i1    | 3           | 3      | 0    | 0       |
| i2    | 18          | 81     | 2    | 5       |
| i3    | 22          | 0      | 22   | 0       |
| ...   |             |        |      |         |

**Gaps (requirements without issues):**
- i2: "Persistent AI Memory (mem0)" — no matching issue
- i2: "Slash Command Palette" — no matching issue

**Orphans (issues without matching requirements):**
- PROJ-176: "Entities blocked from 2 budgets with same name" — bug, not in roadmap

### Assignment
- X issues verified in correct `i{N}.` → `P{N}.` placement
- Y misassignments found (list with corrections)

### Dependencies
- X dependency relations verified
- Y missing relations (list with exact `blockedBy` to add)
- Z ordering violations (list with recommended state changes)

### Spec Coverage (next phase: [phase name])
| Status | Count | % |
|--------|-------|---|
| No spec | X | X% |
| Has spec | X | X% |
| Agent passed | X | X% |
| Planning-ready | X | X% |

**Issues needing specs:**
- PROJ-XXX: [title]
- PROJ-XXX: [title]

### Parked Items (trigger check)

Parked items are brainstorm dispositions marked "Later" with parseable triggers. Check if any triggers have fired.

**Step 1 — Fetch parked items:**
Use `mcp__linear-server__linear_searchIssues` filtered by the `Parked` label. For each, read the latest comment matching the parseable prefix `**Parked:** Revisit when ...`. If a parked issue has no such comment (older disposition, pre-grammar), flag it for manual review and continue.

**Step 2 — Parse the trigger per the grammar** (authored by `/brainstorm` Phase 2):

| Regex pattern | Evaluation |
|---------------|------------|
| `(\w+-\d+) ships` | Fetch that issue; trigger fires if state is `Done` |
| `Stage (\d+) UAT passes` | Fetch all issues in Stage N; trigger fires if all are past UAT (state in {UAT, Done} for the entire set) |
| `Phase (\d+) ships` | Fetch all issues in Phase N; trigger fires if all are `Done` |
| `date: (\d{4}-\d{2}-\d{2})` | Trigger fires when today ≥ the date |
| `manual` | Never auto-fires; always show under "Manual-review parked" |

**Step 3 — Present the report:**

```
### Parked Items

**Triggered (ready for re-disposition):**
| Issue | Title | Trigger | Why it fired |
|-------|-------|---------|--------------|
| PROJ-18 | AI matching | `PROJ-3 ships` | PROJ-3 moved to Done on 2026-04-20 |
| PROJ-25 | Export to PDF | `Phase 2 ships` | All Phase 2 issues Done as of 2026-04-22 |

**Not yet triggered:**
| Issue | Title | Trigger | Status |
|-------|-------|---------|--------|
| PROJ-22 | Real-time collab | `Stage 1 UAT passes` | 3 Stage 1 issues still in Building |

**Manual-review parked (no auto-trigger):**
| Issue | Title | Notes |
|-------|-------|-------|
| PROJ-30 | Gmail agent | No fit with current roadmap yet |

**Trigger parse errors (fix these):**
| Issue | Comment snippet | Action |
|-------|-----------------|--------|
| PROJ-40 | "Revisit when auth is solid" | Prose trigger — ask user for a parseable form |
```

**Triggered items** need re-disposition: either add to the current phase via `/phase-plan --rebalance`, or revisit in `/brainstorm-review` for full Now/Later/Kill re-evaluation. Either way, the `Parked` label should be removed once the item is re-dispositioned.

**Parse errors** indicate a parked issue was disposed before the grammar was enforced or with a prose trigger. Prompt the user to update the comment to a parseable form, or accept "manual" if no concrete trigger exists.

### Strategy Doc Freshness
| Doc | Version | Last Updated | Features Since |
|-----|---------|-------------|----------------|
| {doc name from config} | vX.X.X | YYYY-MM-DD | X |
| {doc name from config} | vX.X.X | YYYY-MM-DD | X |
| ... | | | |
- **Recommendation:** Run `/strategy-sync` if any doc has >3 unsynced features

### End-to-End Check — `pk status` Roadmap walk

Run `pk status` and confirm its **Roadmap** section renders the `i{N}.` → current `P{N}.` walk correctly (current phase initiative, current sub-phase project, and the next issues underneath). This is the integration test for the whole phase surface: if `pk status` resolves the current phase to a different `i{N}.`/`P{N}.` than this audit computed, the naming/order/lifecycle is inconsistent somewhere above — reconcile before proceeding.

| Source | Current phase | Current sub-phase |
|--------|---------------|-------------------|
| This audit (lowest non-Completed `i{N}.` / lowest live `P{N}.`) | i2 | P3 |
| `pk status` Roadmap section | i2 | P3 |

A mismatch is a hard flag — fix the surface, don't proceed to spec.

### Action Items (Priority Order)
1. [Most critical action]
2. [Next action]
...
```

Ask the user: _"Want me to fix any of these issues now? I can create missing issues, rename/re-parent phase initiatives and projects, set dependency links, or flag items for spec generation."_

## Cadence

Run at these moments:
- **Before speccing a new phase** — ensures the plan is sound before you invest in specs
- **At the start of a new phase (`i{N}.` / `P{N}.`)** — validates the Linear phase surface is well-formed before work lands
- **Monthly** — routine health check
- **After major scope changes** — re-validate after adding/removing features

## Related

- See `method.md` — the overall pipeline this validates
- See `sop/Linear_SOP.md` — dependency graph and workflow states
- `/strategy-sync` — runs after shipping to update Strategy docs (this skill flags staleness)
- `/light-spec` — generates specs for issues flagged as needing them
