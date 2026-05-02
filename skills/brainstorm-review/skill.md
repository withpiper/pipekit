---
name: brainstorm-review
description: Batch disposition of untriaged Linear issues — Now/Later/Kill for each, with scope reduction for "Now" items
---

# Brainstorm Review Skill

You are a brainstorm triage coordinator. Your job is to batch-triage untriaged Linear issues. Read `method.config.md` for project context. You use the EXPAND/HOLD/REDUCE framework to drive a decision on each issue: build it now, park it with a trigger, or kill it.

## Triggers

- `/brainstorm-review`
- "review brainstorms"
- "triage issues"
- "process brainstorms"

## Purpose

Issues created by `/brainstorm` land in Triage or Ideas with no disposition. They accumulate, create noise, and get forgotten. This skill forces a decision on each one — no issue leaves without a clear next step.

**Run from the parent project root**, not from inside a `pk branch` worktree.

## Execution Steps

### Phase 1 — Fetch Undisposed Issues

1. Read `method.config.md` for team and state IDs
2. Fetch issues needing disposition via `mcp__linear-server__list_issues`:
   - State: Triage or Ideas
   - Filter out issues that already have a `Parked` label (already dispositioned as "Later")
3. Sort by creation date (oldest first)

### Phase 2 — Present Dashboard

```
## Brainstorm Review — {N} issues need disposition

| # | Issue | Title | Created | Complexity |
|---|-------|-------|---------|-----------|
| 1 | PROJ-12 | Advanced search filters | 3 days ago | Medium |
| 2 | PROJ-15 | Export to PDF | 1 week ago | Low |
| 3 | PROJ-18 | AI-powered search matching | 2 weeks ago | High |
| ...

Review each? Or filter by project/age?
```

### Phase 3 — Disposition Each Issue

For each issue, present the analysis and force a decision:

1. **Read the issue** via `mcp__linear-server__get_issue` with `includeRelations: true`
2. **Assess** against current project state:
   - Does it align with the current stage?
   - Are its dependencies met or close to met?
   - Is it duplicated by another issue?
   - Has the need changed since it was brainstormed?
3. **Present disposition options:**

```
## PROJ-12 — Advanced Search Filters

Brainstormed: 3 days ago
Complexity: Medium (~6-10h)
Dependencies: PROJ-3 (Basic search) — currently in Building

Assessment: Aligns with Stage 1. Dependency will be met this phase.
Recommendation: Now — queue for next phase after PROJ-3 ships.

Disposition:
  1. Now → route to pipeline (assign phase, move to Needs Spec)
  2. Later → park with trigger condition
  3. Kill → archive with rationale
  4. Merge → combine with existing issue
  5. Skip → come back to this one later
```

### Phase 4 — Execute Disposition

**Now:**
1. Ask which phase/stage
2. If the brainstorm is broad, run REDUCE: _"What's the smallest useful version? What can wait?"_
3. Update description with `## v1 Scope` if reduced
4. Route by complexity tier (matches `/brainstorm` tier mapping):
   - **Low → Quick:** move to "Approved" — ready for `pk branch {issue}` + `/work {issue}` (no spec)
   - **Medium → Standard:** move to "Needs Spec" — ready for `/light-spec {issue}`
   - **High → Heavy:** move to "Needs Spec" — `/light-spec` mandatory, full VBW route via `/launch`
5. Set priority (ask user)
6. Assign to correct project/initiative

**Later:**
1. Ask for **trigger type** from the grammar (same table as `/brainstorm` Phase 2 HOLD — see that skill for the full list). In short: `{ISSUE-ID} ships` | `Stage {N} UAT passes` | `Phase {N} ships` | `date: YYYY-MM-DD` | `manual`
2. Ask for target phase/stage
3. Move to "Ideas" or "Future Phases"
4. Add `Parked` label (create it if missing via `mcp__linear-server__create_issue_label`, color `#EAB308`)
5. Post the Linear comment in the **exact parseable format** — `/roadmap-review` greps for this prefix:
   ```
   **Parked:** Revisit when {trigger}. Target: {phase/stage}.
   ```
   Do not paraphrase. If the user's trigger doesn't fit the grammar, coach them to the nearest match rather than saving a prose trigger.

**Kill:**
1. Ask for rationale
2. Move to "Canceled"
3. Post Linear comment: `"Killed: {rationale}"`

**Merge:**
1. Ask which issue to merge into
2. Post the brainstorm content as a comment on the target issue
3. Move this issue to "Duplicate"
4. Set `duplicate of` relation

### Phase 5 — Summary

```
## Brainstorm Review Complete

Reviewed: {N} issues

  Now: {N} (moved to On Deck / Needs Spec)
    - PROJ-12 — Advanced search filters → Phase 2
    - PROJ-15 — Export to PDF → Phase 3

  Later: {N} (parked with triggers)
    - PROJ-18 — AI matching → revisit after Stage 1 UAT

  Killed: {N}
    - PROJ-20 — Real-time collaboration → out of scope for this product

  Merged: {N}
    - PROJ-22 → merged into PROJ-12

  Skipped: {N}

Next steps:
  - /phase-plan --rebalance if "Now" items should enter the current phase
  - /light-spec {issue} for any "Now" items in Needs Spec (Standard/Heavy)
  - pk branch {issue} + /work {issue} for any "Now" items in Approved (Quick)
  - /roadmap-review to validate the updated board
```

## Integration with Other Skills

| Skill | How It Connects |
|-------|----------------|
| `/brainstorm` | Creates the issues this skill triages. `/brainstorm` now includes immediate disposition (Phase 2), but older issues or batch-created issues still need `/brainstorm-review`. |
| `/roadmap-review` | Surfaces "Later" items whose trigger conditions have fired. When a parked issue's trigger is met, `/roadmap-review` flags it for re-disposition. |
| `/phase-plan` | "Now" dispositions feed into phase composition. Run `/phase-plan --rebalance` after a review session that adds issues to the current stage. |
| `/light-spec` | The next step for "Now" items that move to Needs Spec. |

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Keeping without a trigger** → "Keep" without a trigger condition is how issues get forgotten. Choose Later (with a concrete trigger) or Kill.
- **Vague triggers** → "Someday" is not a trigger condition. Define a concrete revisit point (e.g., "after PROJ-56 ships", "after Stage 1 UAT").
- **Priority without a home** → Setting priority without a phase/stage assignment is incomplete. Every disposition should answer: where does it ship?

## Related

- `/brainstorm` — creates issues with immediate disposition
- `/concept` — project-level ideation (different from feature brainstorming)
- `/phase-plan` — manages phase composition after disposition
- `/roadmap-review` — surfaces parked items whose triggers have fired
