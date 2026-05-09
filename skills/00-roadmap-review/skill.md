---
name: roadmap-review
description: Validate roadmap health — issue completeness, dependency ordering, spec coverage, and doc freshness
---

# Roadmap Review Skill

You are a roadmap health auditor. Your job is to run a comprehensive health check of the overall plan. Read `method.config.md` for project context. Run this before speccing a new phase to ensure the roadmap is coherent and complete.

## Triggers

- `/roadmap-review`
- "review the roadmap"
- "check the plan"
- "roadmap health"

## Purpose

Validate that:
1. **Stage 0 outputs exist** — concept, definition, strategy docs, roadmap, phase
2. Every ROADMAP requirement has corresponding Linear issues
3. Issues are in the correct stage/project
4. Dependencies and blockers are set correctly
5. Workflow states are consistent with dependency ordering
6. Spec coverage is adequate for the next planned phase
7. Strategy docs are flagged if stale

This is the **gate between Stage 0 (Foundation) and Stage 1 (Definition)** in the Pipekit pipeline. Run it before starting a new phase of specs.

## Execution Steps

### Stage 0 Check — Foundation

Validate that pre-pipeline outputs exist. If any are missing, report which skill to run.

| Check | File | If Missing |
|-------|------|-----------|
| Concept brief | `concept-brief.md` | Run `/concept` |
| Project definition | `project-definition.md` | Run `/define` |
| Strategy docs | `Strategy/` matching `method.config.md` manifest | Run `/strategy-create` |
| VBW scaffold | `.vbw-planning/` directory | Run `/vbw:init` |
| Roadmap | `.vbw-planning/ROADMAP.md` with content | Run `/roadmap-create` |
| Linear board | Issues exist for roadmap requirements | Run `/roadmap-create` |
| Phase defined | `.vbw-planning/PHASES.md` with current phase | Run `/phase-plan` |

If any Stage 0 check fails, report it prominently at the top of the health report:

```
## Stage 0: Foundation — Incomplete

Missing:
  - concept-brief.md → run /concept
  - .vbw-planning/PHASES.md → run /phase-plan

Complete Stage 0 before entering the spec pipeline.
```

If all Stage 0 checks pass, continue to the next check.

### Phase 1 — Gather State

1. Read `.vbw-planning/ROADMAP.md` for requirements by stage
2. Read `.vbw-planning/linear-map.json` for ID mappings
3. Read `.vbw-planning/STATE.md` for current progress
4. Read `.vbw-planning/PHASES.md` for current phase composition
5. Fetch all initiatives via `mcp__linear-server__list_initiatives`
6. For each active and next-up initiative, fetch projects via `mcp__linear-server__list_projects`
7. For each project, fetch issues via `mcp__linear-server__list_issues`

### Phase 2 — Completeness Check

For each stage in ROADMAP.md:

1. Extract the requirements list from the stage section
2. Match each requirement to Linear issues by:
   - Title keyword matching
   - Project assignment (requirement area → project cluster)
   - Description cross-references
3. **Gaps:** Requirements with NO matching issue → these need issues created
4. **Orphans:** Issues with NO matching requirement → flag for review (may be valid additions from brainstorming, or may be misassigned)

Output: Completeness table per stage.

### Phase 3 — Assignment Validation

For each issue in the active and upcoming stages:

1. Verify it belongs to the correct initiative (stage)
2. Verify it belongs to a project within that initiative
3. Verify it has a milestone (work package) if applicable
4. Verify labels are consistent (Tier label matches Initiative, Domain label matches Project)
5. Flag misassignments

### Phase 4 — Dependency Validation

1. Read light specs for issues that have them — extract dependency contracts (e.g., "PROJ-8 is a hard blocker for PROJ-7")
2. Read the WP dependency graph from `pipekit/sop/Linear SOP.md` (Dependency Graph section)
3. For each declared dependency:
   - Fetch the issue via `mcp__linear-server__get_issue` with `includeRelations: true`
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

For the next planned phase (issues in On Deck/Needs Spec/Specced for the active stage):

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

### Completeness
| Stage | Requirements | Issues | Gaps | Orphans |
|-------|-------------|--------|------|---------|
| 01    | 3           | 3      | 0    | 0       |
| 02    | 18          | 81     | 2    | 5       |
| 03    | 22          | 0      | 22   | 0       |
| ...   |             |        |      |         |

**Gaps (requirements without issues):**
- Stage 02: "Persistent AI Memory (mem0)" — no matching issue
- Stage 02: "Slash Command Palette" — no matching issue

**Orphans (issues without matching requirements):**
- PROJ-176: "Entities blocked from 2 budgets with same name" — bug, not in ROADMAP

### Assignment
- X issues verified in correct stage/project
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
Use `mcp__linear-server__list_issues` filtered by the `Parked` label. For each, read the latest comment matching the parseable prefix `**Parked:** Revisit when ...`. If a parked issue has no such comment (older disposition, pre-grammar), flag it for manual review and continue.

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

### Action Items (Priority Order)
1. [Most critical action]
2. [Next action]
...
```

Ask the user: _"Want me to fix any of these issues now? I can create missing issues, set dependency links, or flag items for spec generation."_

## Cadence

Run at these moments:
- **Before speccing a new phase** — ensures the plan is sound before you invest in specs
- **At the start of a new stage** — validates stage setup is complete
- **Monthly** — routine health check
- **After major scope changes** — re-validate after adding/removing features

## Related

- See `method.md` — the overall pipeline this validates
- See `sop/Linear_SOP.md` — dependency graph and workflow states
- `/strategy-sync` — runs after shipping to update Strategy docs (this skill flags staleness)
- `/light-spec` — generates specs for issues flagged as needing them
