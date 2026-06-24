---
name: brainstorm
description: Analyze a feature idea, assess feasibility, file Linear issue. Use when the user shares a raw idea mid-session. Use when scoping a feature before /light-spec. Produces a triaged Linear ticket, not a full spec.
---

# Brainstorm Skill

You are a brainstorm processor. Read `method.config.md` for project context. When the user shares an idea, you analyze it, assess its feasibility, and create a Linear issue.

## Triggers

This skill is invoked when the user says:
- `/brainstorm`
- "brainstorm"
- "new brainstorm"
- "I have an idea"

## Purpose

Take a rough idea from the user, explore the codebase to understand feasibility, create a structured analysis, and capture it as a Linear issue.

**Run from the parent project root**, not from inside a `pk branch` worktree. Brainstorming inside a feature worktree muddles Linear context with the in-flight work.

## Execution Steps

### Phase 1 — EXPAND (Brainstorm)

1. **Capture** the idea from the user
2. **Explore** the codebase to assess feasibility
3. **Create structured analysis** with complexity, requirements, implementation approach
4. **Present** to user for approval
5. **Create Linear issue** via `mcp__linear-server__linear_createIssue`:
   - `team`: `{team from method.config.md}`
   - `title`: concise feature title
   - `description`: full brainstorm analysis (feasibility, complexity, approach, requirements)
   - `priority`: 0 (None) — triage sets real priority later
   - Ask user which project to assign (or leave unassigned)
   - `state`: Triage
6. **Output**: issue identifier and Linear URL

### Phase 2 — HOLD (Disposition)

Immediately after creating the issue, force a disposition decision:

> **What should happen with this idea?**
>
> 1. **Now** → Route to pipeline. Assign to a phase/stage, move to Needs Spec.
> 2. **Later** → Park with a trigger condition and target phase.
> 3. **Kill** → Archive with rationale.

**If Now:**
- Ask which stage/phase this belongs to
- Route by complexity tier (see Complexity Guidelines for tier mapping):
  - **Quick (Low)** → move to "Approved". Inform: _"Ready for `pk branch {issue}` then `/work {issue}` — no spec needed."_
  - **Standard (Medium)** → move to "Needs Spec". Inform: _"Ready for `/light-spec {issue}`, then `pk branch {issue}` + `/work {issue}`."_
  - **Heavy (High)** → move to "Needs Spec". Inform: _"Heavy tier — run `/light-spec {issue}` first; `/work` then plans inline with forced `--deep` grounding and executes on the native backend (the default)."_

**If Later:**
- Ask for a **trigger type** from the grammar below (parsable triggers are what let `/roadmap-review` auto-surface this later — prose triggers get flagged as manual-review)
- Ask for a **target phase/stage**
- Move issue to "Ideas" or "Future Phases" based on target
- Add the `Parked` label. If the label doesn't exist in the Linear workspace, create it first via `mcp__linear-server__linear_createTeamLabel` with name `Parked`, color `#EAB308` (amber).
- Post a Linear comment using the **exact parseable format** below (do not paraphrase — `/roadmap-review` greps for it):
  ```
  **Parked:** Revisit when {trigger}. Target: {phase/stage}.
  ```

**Trigger grammar (pick one):**

| Trigger form | Meaning | Example |
|--------------|---------|---------|
| `{ISSUE-ID} ships` | Fires when the referenced issue is in `Done` state | `Parked: Revisit when PROJ-56 ships. Target: Phase 4.` |
| `Stage {N} UAT passes` | Fires when all Stage N issues are past UAT | `Parked: Revisit when Stage 1 UAT passes. Target: Stage 2.` |
| `Phase {N} ships` | Fires when all Phase N issues are Done | `Parked: Revisit when Phase 3 ships. Target: Phase 4.` |
| `date: YYYY-MM-DD` | Fires on a calendar date | `Parked: Revisit when date: 2026-06-01. Target: Phase 5.` |
| `manual` | No auto-trigger; surfaced only on explicit `/brainstorm-review` | `Parked: Revisit manual. Target: icebox.` |

If the user describes a trigger that doesn't match the grammar, coach them toward the nearest match (e.g., "revisit when auth is solid" → propose "Revisit when {auth-epic-issue} ships") rather than saving a prose trigger that won't parse.

**If Kill:**
- Ask for rationale (one sentence)
- Move issue to "Canceled"
- Post a Linear comment: `"Killed: {rationale}"`

### Phase 3 — REDUCE (for "Now" items only)

If the disposition is **Now** and the brainstorm is broad, cut to v1 scope:

1. Review the brainstorm analysis
2. Ask: _"What's the smallest useful version of this? What can wait for v2?"_
3. Update the issue description with a `## v1 Scope` section that trims to essentials
4. This reduced scope is what `/light-spec` will work from

## Complexity Guidelines

Each complexity level maps to a `/work` tier. The tier determines whether a spec is required and which execution path runs.

| Complexity | `/work` Tier | Effort | Examples | Spec? |
|------------|----------------|--------|----------|-------|
| **Low** | Quick | ~2-4h | UI-only, simple CRUD, existing infrastructure | No — straight to `pk branch` + `/work` |
| **Medium** | Standard | ~6-10h | New API endpoint, combines existing systems | Yes — `/light-spec` first |
| **High** | Heavy | ~12-20+h | New infrastructure, complex logic, multiple integrations | Yes — `/light-spec`, then `/work` with forced `--deep` grounding |

## Description Template

Format the Linear issue description as:

```markdown
## Brainstorm Analysis

**Complexity:** Low / Medium / High
**Estimated Effort:** X-Y hours

### Summary
[1-2 sentence description]

### Feasibility Assessment
[What exists in the codebase, what's needed, any blockers]

### Implementation Approach
[High-level steps]

### Requirements
- [requirement 1]
- [requirement 2]

### Notes
[Any caveats, dependencies, or open questions]
```

## Red Flags

Thoughts that indicate brainstorm backlog rot is about to start. Paired with `.claude/rules/pipekit-discipline.md`.

| Flag | What it actually means |
|------|------------------------|
| "This is a good idea, just add it to Linear" | Filing without disposition = idea rots in Ideas forever. The HOLD phase (Now/Later/Kill) is not optional. |
| "More captured ideas is better" | No — more items without disposition = more backlog noise that crowds out real work. Selectivity is the feature. |
| "Later means we'll get to it eventually" | Not without a trigger condition. "Later" requires a concrete revisit signal (e.g., "when WIT-56 ships") or it becomes "never." |
| "The feasibility is obvious" | Feasibility claims made without exploring the codebase are wrong a third of the time. Explore, then estimate. |
| "This idea is too rough to file" | That's what EXPAND is for. Unfiled ideas exist only in the current session; filed-as-rough-with-disposition is always better than lost. |

---

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Skipping codebase exploration** → Ideas that feel "obviously feasible" often become surprisingly complex during speccing. Explore first, then assess.
- **Estimating without exploring** → Low means 2-4 hours of implementation. Accurate estimates require understanding the existing codebase.
- **Deferring dependency discovery** → Capture dependencies during brainstorming. Dependencies discovered during execution are far more expensive to resolve.
- **Skipping the Linear issue** → Every idea gets an issue. Ideas without issues get forgotten; issues without context get built blindly.

## Related

- `/brainstorm-review` — triage untriaged Linear issues with disposition
- `/concept` — project-level ideation (for new projects, not features)
- `/light-spec` — next step for ideas that move forward
- `/phase-plan` — "Now" dispositions feed into phase planning
