---
name: launch-native
description: Experimental VBW-free variant of /launch. Spawns planning, dev, and QA agents directly via the native Agent tool. Use to A/B test whether VBW is still pulling its weight.
---

# Launch Native (spike)

You are the VBW-free variant of `/launch`. Same gates, same Linear transitions, same complexity routing. The difference: instead of handing planning/dev/QA off to `vbw:vbw-lead`, `vbw:vbw-dev`, and `vbw:vbw-qa`, you invoke Claude Code's native `Agent` tool with direct subagent types.

Read `method.config.md` for project context.

## Why this exists

VBW was invaluable when Claude Code didn't have Plan Mode, typed subagents, worktree isolation as a parameter, or durable TaskCreate state. As of Opus 4.7 and the current Claude Code feature set, those primitives exist natively. This skill tests whether the wrapping VBW provides is still worth the extra dependency, the `.vbw-planning/` ownership boundary, and the plugin install step.

Keep this skill alongside `/launch` during the spike. Pick one real Linear issue, run it through `/launch` on one branch and `/launch-native` on another, and compare:

- Plan quality (is the `PLAN.md` / equivalent output as useful?)
- Execution quality (same code outcome?)
- Friction (fewer moving parts? more?)
- Linear visibility (same or degraded?)

Full spike checklist in `temp/spike-notes.md`.

## Triggers

- `/launch-native PROJ-XXX`
- `/launch-native --milestone WP-1`
- `/launch-native --project "P1. Foundation Fixes"`

## Arguments

| Argument | What it does |
|----------|--------------|
| `PROJ-XXX` | Launch a single issue |
| `--milestone <name>` | Launch all ready issues in a milestone |
| `--project <name>` | Launch all ready issues in a project |
| `--dry-run` | Validate gates and show routing plan without executing |
| `--force` | Skip milestone readiness gate (use with caution) |
| `--deep` | Escalate the Dev agent from Sonnet to Opus for known-hard debugging |

---

## Model Selection

Same defaults as `/launch`, same rationale, different subagent types.

| Step | Agent (launch) | Agent (launch-native) | Default model |
|------|----------------|------------------------|----------------|
| Plan | `vbw:vbw-lead` | `Plan` (native) | `opus` |
| Plan review | `plan-reviewer` | `general-purpose` with review prompt | `opus` |
| Execute | `vbw:vbw-dev` | `general-purpose` with dev prompt + `isolation: "worktree"` | `sonnet` (or `opus` with `--deep`) |
| Verify | `vbw:vbw-qa` | `general-purpose` with QA prompt | `sonnet` |

---

## Where plans live

`/launch` writes plans to `.vbw-planning/phases/{phase-slug}/PLAN.md`. `/launch-native` writes them to `plans/{phase-slug}/PLAN.md` at the repo root. The directory is simpler and doesn't require the VBW scaffold. If the spike wins, `plans/` becomes the canonical location and the VBW scaffold goes away.

---

## Execution Steps

### Steps 1–6: identical to `/launch`

Gate validation, dependency checks, milestone readiness, complexity routing, cmux rename, and the move to Building work exactly the same. Read `skills/launch/skill.md` Steps 1–6 and follow them verbatim. This skill only diverges at the planning/execution handoff.

One divergence note: the Linear comment posted at Step 6 should read `Route: Native (no VBW)` instead of `Route: VBW`.

### Step 7a — Low Complexity: Queue for Batch Runner

Identical to `/launch`. Delegate to `/linear-todo-runner`. Done.

### Step 7b — Medium/High Complexity: Plan directly

1. Read the full issue description (spec + AC).
2. Spin up a planning agent using the native `Plan` subagent type:
   ```
   Agent(
     subagent_type: "Plan",
     model: "opus",
     description: "Plan PROJ-XXX: {title}",
     prompt: "Create an implementation plan for PROJ-XXX based on the following approved spec from Linear:

     {full issue description}

     Read CLAUDE.md for project conventions. If the spec involves UI work, read Strategy/DesignDirection.md. Write the plan to plans/{phase-slug}/PROJ-XXX.md using this structure:
       # {Title} — Plan
       ## Goal
       ## Success criteria (from AC)
       ## Tasks (atomic, with verify/done criteria each)
       ## Risks / open questions
     The spec has been human-approved. Do not change scope or decisions. Decompose into atomic tasks."
   )
   ```
3. After the plan is written, run a review agent:
   ```
   Agent(
     subagent_type: "general-purpose",
     model: "opus",
     description: "Review plan for PROJ-XXX",
     prompt: "Review the plan at plans/{phase-slug}/PROJ-XXX.md. Stress-test scope, dependencies, success criteria, and risks against the spec. Flag any task where verify/done criteria are vague. The spec is: {brief spec summary}. Return a concise list of issues, or 'no issues' if the plan is sound."
   )
   ```
4. Present the plan and the review to the user.
5. On approval, proceed to Step 8. On change requests, iterate on the plan.

### Step 8 — Execute

For each task in the approved plan:

```
Agent(
  subagent_type: "general-purpose",
  model: "sonnet",  // "opus" if --deep was passed
  description: "PROJ-XXX task N: {task title}",
  isolation: "worktree",
  prompt: "Execute task N from the plan at plans/{phase-slug}/PROJ-XXX.md.
  Read CLAUDE.md for conventions. Atomic commit per task.
  Include PROJ-XXX in all commit messages.
  Use TaskCreate to track subtasks. Mark each completed as you go."
)
```

After each task, post Linear progress:

```
**Build progress:** Task {N}/{total} complete — {task title}
```

### Step 9 — Verify

```
Agent(
  subagent_type: "general-purpose",
  model: "sonnet",
  description: "Verify PROJ-XXX: {title}",
  prompt: "Verify PROJ-XXX against the acceptance criteria in the spec. Use goal-backward methodology:
    1. Read the AC from Linear issue PROJ-XXX.
    2. For each AC item, check whether the merged code satisfies it. Don't trust agent summaries — read the actual diff.
    3. Run the pre-deploy gate: pnpm turbo run check-types && pnpm turbo run lint && pnpm turbo run test.
    4. Return a per-AC pass/fail table and overall verdict."
)
```

Pass → Step 10. Fail → re-enter Step 8 for the failing tasks with QA feedback.

### Step 10 — Move to UAT

Identical to `/launch`. Move to UAT state, post Linear comment, emit NEXT.md and inline `➜ Next:` pointing at `/g-test-vercel`.

---

## Milestone/Project Batch Mode

Identical to `/launch`. Only the per-issue execution path differs.

---

## Spike success criteria

This variant replaces `/launch` permanently if, after testing on at least 3 real Linear issues:

1. Plan quality is equivalent or better (judged by the user after reading both).
2. Execution produces equivalent code (same tests pass, same PRs clean).
3. No critical VBW-specific feature is missed (e.g., VBW's commit-per-task discipline, plan-reviewer cross-check).
4. The user prefers the reduced indirection.

If any of those fail, keep `/launch` as the default and document why in `temp/spike-notes.md`.

---

## What this skill deliberately doesn't do

- No fallback to VBW if a native agent fails. The spike is meant to produce a clean signal.
- No auto-migration of existing `.vbw-planning/` artifacts. If the spike wins, migration is a separate piece of work.
- No behavioral drift from `/launch` on Linear status transitions. Gates and transitions are identical so the comparison is apples-to-apples.
