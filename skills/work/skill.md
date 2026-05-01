---
name: work
description: V2 daily-loop skill — plan + execute a Linear issue from inside its worktree. Backend-pluggable (vbw | native) per method.config.md.
---

# /work

> **North star:** safe and frictionless. Helps, never adds work.

You are a focused work driver. Given a Linear issue ID, you read its spec, plan the work, present the plan for one-screen verdict, dispatch execution, and stop. No tier inference, no round-2 verdict loops, no auto-chain.

## Triggers

- `/work <ISSUE-ID>` — primary
- `/work <ISSUE-ID> --deep` — adds spec-validator + plan-review subagent + security-review on completion
- "work on RS-30" / "let's do PIP-123"

## Required preconditions

1. You are inside a worktree on a feature branch (not `dev`, not `main`). If not, refuse with: "Run `pk branch <ID>` first to create the worktree."
2. The issue ID is passed as an argument or inferred from the current branch name.
3. `method.config.md` is readable in the repo root.

## Step 1 — Read configuration

Read `method.config.md` for v2 keys (defaults in parens):

- `Backend: vbw | native` (default `vbw`)
- `Default deep flag: true | false` (default `false`) — if `true`, treat every invocation as `--deep`
- `Require QA review: true | false` — informational; affects step 5 hand-off

Resolve the effective backend and `--deep` flag. Print:

```
Backend: <vbw|native>     Deep: <yes|no>     Issue: <ID>
```

## Step 2 — Fetch the spec

Use the Linear MCP server (`mcp__linear-server__get_issue`) to fetch the issue. Read:

- Title
- Description (the spec body — should contain `## Light Spec` or `## Acceptance Criteria`)
- Current state (must be **In Progress** or **Building**; if **Approved**, the user forgot `pk branch` — refuse and tell them)

If the spec body has no `## Light Spec` and no `## Acceptance Criteria`:
- **Without `--deep`:** warn and ask "Continue with vague spec? (y/N)"
- **With `--deep`:** refuse — "Spec missing. Run `/light-spec <ID>` first or invoke `pk delegate <ID> draft a spec for this issue`."

## Step 3 — Plan

### `--deep` path

Spawn three subagents in parallel for grounding:

1. `spec-validator` — validates spec completeness against the rubric in `sop/Spec_Validation.md`
2. `Explore` agent — surveys the codebase areas the spec references (file paths, schemas, related code)
3. (vbw backend only) `vbw:vbw-scout` — deep research into the affected packages

When all three return, synthesize their outputs into a written plan.

### Default path

You plan directly. Use the spec + your codebase context. Write a plan with:

- **Goal** (1 sentence — what this issue ships)
- **Approach** (2–4 sentences — the technical strategy)
- **Files to touch** (list with one-line "what changes" per file)
- **Tests** (what tests prove the change works)
- **Open questions** (must be empty — if not, you're not ready to plan; go back to the spec)

## Step 4 — Verdict gate (one screen)

Present the plan in a single response. Ask the user one of three:

- `proceed` — execute the plan as written
- `revise: <feedback>` — edit the plan with the feedback, present again, re-ask
- `abort` — stop, do nothing

There is **no** round-2 verdict loop. There is **no** stalemate detection. If a plan needs three revise rounds, the **spec is bad** — stop and instruct: "Run `pk delegate <ID> the spec needs <X>` to ask Linear Agent to refine it, then restart `/work`."

## Step 5 — Execute

### `vbw` backend

Hand off to VBW: spawn `vbw:vbw-dev` via the Task tool with the approved plan as context. VBW handles atomic-commit-per-task discipline. Wait for completion.

After Dev completes:
- If `Require QA review: true` OR `--deep`: hand off to `vbw:vbw-qa` (Task tool). Capture verdict.
- Else: print "Dev complete. Run `/verify` or `pk verify` to validate."

### `native` backend

Spawn a Task subagent (`general-purpose`) with the approved plan as context. Instruct it to:
- Make atomic commits per task (one logical change = one commit)
- Run tests after each significant change
- Stop and surface if it hits a blocker (don't loop on failures)

Use the Edit/Write/Bash tools directly when the plan is small enough that subagent dispatch is overhead. Heuristic: ≤3 files touched + no unfamiliar code → do it inline. Else dispatch.

After execution:
- If `Require QA review: true` OR `--deep`: invoke `/verify` automatically.
- Else: print "Work complete. Run `/verify` or `pk verify` when ready."

## Step 6 — `--deep` security review

After Dev completes (vbw or native), if `--deep`, spawn `security-review` subagent on the diff. Capture findings into the journal (the Stop hook will pick them up).

## Step 7 — Hand off, don't auto-ship

`/work` ends here. **Do not** run `pk ship` automatically. The user runs it when they're ready (after they've eyeballed the diff or run smoke tests).

The Stop hook handles journal paperwork. No `/end-session` skill is invoked.

## Failure model

| Failure | What to do |
|---|---|
| Spec is missing/vague | Refuse (or warn at user prompt without `--deep`). Don't plan blind. |
| Plan rejected 3+ times | Stop. Spec is bad. Use `pk delegate` to refine in Linear. |
| Subagent hits permission denial | Stop. Surface. Do not retry. |
| Tests fail post-execute | Surface. Don't auto-fix — that's `/verify`'s job, not `/work`'s. |
| Worktree on wrong branch | Refuse at step 0. |

## What this skill does NOT do

- No tier inference (Quick/Standard/Heavy gone — use `--deep` if you want extra rigor).
- No plan-review verdict loop (one screen, three options).
- No `--auto` chain (the user is the chain).
- No PR creation (that's `pk ship`).
- No NEXT.md update (that doesn't exist in v2).
- No session log (Stop hook owns the journal).
- No Linear status writes (that's `pk branch` and `pk ship`).
- No `/end-session` invocation.

## Comparison with v1

| Concern | v1 (`/launch --auto`) | v2 (`/work`) |
|---|---|---|
| Lines of skill prose | 765 | ~150 |
| Tier system | Quick/Standard/Heavy | None (`--deep` flag) |
| Verdict loop | 3 rounds + stalemate detection | 1 screen, 3 options |
| Backend | VBW only | `vbw \| native` per config |
| Auto-chain | yes (4 hidden agent invocations) | no (user paces) |
| State writes | Linear (twice), VBW STATE.md, pipeline-state JSON | none (read-only) |
