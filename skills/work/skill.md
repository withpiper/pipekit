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
- `/work <ISSUE-ID> --backend=vbw|native` — override the project's default backend for this invocation only
- "work on RS-30" / "let's do PIP-123"

## Required preconditions

1. You are inside a worktree on a feature branch (not `dev`, not `main`, not `beta`, not `master`). Check with `git branch --show-current`. If on an integration branch, refuse with: `Run pk branch <ID> first to create the worktree.`
2. The issue ID is passed as an argument or inferred from the current branch name (regex `[A-Z]+-[0-9]+`).
3. `method.config.md` is readable in the repo root.

## Step 0 — Verify preconditions

Run:

```bash
CURRENT=$(git branch --show-current)
case "$CURRENT" in
  dev|main|master|beta) echo "ERROR: /work must run on a feature branch. Run 'pk branch <ID>' first." >&2; exit 1 ;;
esac
```

If `<ISSUE-ID>` not passed, extract from `$CURRENT`:

```bash
ISSUE=$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)
[ -z "$ISSUE" ] && { echo "ERROR: no issue ID in branch name and none provided." >&2; exit 1; }
```

## Step 1 — Read configuration

Read these values from `method.config.md` (use `bin/pk pk_config "<Key>" "<default>"` semantics, or grep the rows directly):

| Key | Default |
|---|---|
| Backend | `vbw` |
| Default deep flag | `false` |
| Require QA review | `false` |
| Strategy docs path | `Strategy/` |

Resolve the effective `--deep` (CLI flag OR `Default deep flag: true`).

Resolve the effective backend in this order (first match wins):

1. `--backend=vbw` or `--backend=native` passed on the invocation
2. `Backend` row in `method.config.md`
3. Default: `vbw`

If `--backend=` is passed with any value other than `vbw` or `native`, refuse: `Unknown backend '<value>'. Valid: vbw, native.`

Print one line for the user:

```
Work: <ISSUE-ID>  ·  Backend: <vbw|native>  ·  Deep: <yes|no>
```

## Step 2 — Fetch the spec from Linear

Use the Linear MCP tool `mcp__linear-server__get_issue` with the issue ID. Capture:

- `title`
- `description` (the spec body)
- `state.name` (must be `In Progress` or `Building`; if `Approved`, refuse — the user forgot `pk branch`)
- `labels`

Validate the description contains either `## Light Spec` or `## Acceptance Criteria`. If neither:

- **Without `--deep`:** print a warning, print the description's first 30 lines, ask: `Continue planning with this vague spec? (y/N)`. Default N.
- **With `--deep`:** refuse: `Spec missing required sections. Run /light-spec <ID> first, OR pk delegate <ID> "draft a Light Spec for this issue against {project} conventions" to invoke Linear Agent.`

## Step 3 — Plan

### `--deep` path: parallel grounding

Send these three Agent invocations **in a single message** (parallel execution):

1. **Spec validator subagent.** Use Task tool with:
   - `subagent_type: "general-purpose"` (or `"spec-validator"` if a project-local subagent of that name exists)
   - `description: "Validate spec for <ISSUE-ID>"`
   - Prompt template:
     ```
     You are a spec validator. The Linear issue <ISSUE-ID> has this description:

     <full description>

     Validate against this rubric:
     - Has a Goal section (1 sentence)
     - Has explicit Acceptance Criteria (≥3 testable items)
     - File paths and line refs are concrete (not "the auth module")
     - Dependencies are listed (if any)
     - No open questions remaining

     Return:
     **Pass** — all rubric items met.
     **Concerns** — list specific gaps with line refs.
     **Block** — fundamental gap that prevents planning (missing AC, etc.)

     Be terse. ≤200 words.
     ```

2. **Codebase explorer subagent.** Use Task tool with:
   - `subagent_type: "Explore"`
   - `description: "Survey code areas for <ISSUE-ID>"`
   - Prompt template:
     ```
     The Linear issue <ISSUE-ID> says it will touch these areas:

     <extract file paths, table names, package names from spec>

     For each, read the current state and report:
     - File/module purpose (1 line)
     - Key types/functions present
     - Patterns the rest of the codebase uses (so the new work fits)

     Be terse. ≤300 words.
     ```

3. **(VBW backend only) `vbw:vbw-scout` for deep research.** Use Task tool with:
   - `subagent_type: "vbw:vbw-scout"`
   - `description: "Research <ISSUE-ID>"`
   - Prompt template: (delegate research per VBW conventions; pass the spec)

When all three return, synthesize their outputs into a written plan in step 3b.

### Default path: plan inline

Read the spec. Read project context: `CLAUDE.md`, any `Strategy/*` files referenced in the spec. Plan directly.

### Step 3b — Write the plan (both paths)

Format (single screen — keep tight):

```
## Plan: <ISSUE-ID> — <title>

**Goal:** <1 sentence>

**Approach:** <2–4 sentences — the technical strategy>

**Files to touch:**
- `path/to/file1.ts` — <one-line what changes>
- `path/to/file2.ts` — <one-line>
- `supabase/migrations/<N>_<name>.sql` — <one-line>

**Tests:**
- <test scenario 1>
- <test scenario 2>

**Risks / open questions:**
- <empty list — if non-empty, the spec is not ready, go back to step 2>
```

## Step 4 — Verdict gate

Print the plan, then ask exactly:

```
Verdict?
  proceed                  — execute the plan as written
  revise: <feedback>       — edit and re-present
  abort                    — stop, do nothing
```

Wait for user input. Branch:

- **`proceed`** → step 5
- **`revise: <feedback>`** → integrate feedback into the plan, re-print, re-ask. Track revision count locally.
- **`abort`** → exit cleanly. Do not change any state.

**Hard limit:** 3 revisions. If the user revises a 4th time, refuse:

```
Plan has been revised 3 times. The spec is likely the problem, not the plan.
Stopping to prevent waste.

Recommendation: pk delegate <ISSUE-ID> "the plan keeps revising on <area>. Refine the spec to clarify <X>." Then restart /work.
```

## Step 5 — Execute

### vbw backend

Use Task tool with:
- `subagent_type: "vbw:vbw-dev"`
- `description: "Execute plan for <ISSUE-ID>"`
- Prompt template:
  ```
  Execute this plan. Make atomic commits per task (one logical change = one commit).
  After each commit, run the project's test command if relevant.
  Stop and surface immediately if you hit:
    - Permission denial (EditPermissionDenied)
    - Pre-commit hook failure you can't fix
    - Type errors that contradict the plan's assumptions
    - A blocker that wasn't visible at planning time

  Do NOT loop on failures. Do NOT modify the plan unilaterally — surface and ask.

  Plan:
  <full plan from step 3b>

  Spec:
  <full spec from step 2>
  ```

Wait for the subagent to return.

### native backend

Heuristic: dispatch a subagent if the plan touches >3 files OR includes any unfamiliar package OR includes a schema migration. Else execute inline (Edit/Write/Bash directly).

**Subagent path** — use Task tool with:
- `subagent_type: "general-purpose"`
- `description: "Execute plan for <ISSUE-ID>"`
- Prompt template:
  ```
  Execute this plan in the current worktree. The branch is already created.

  Discipline:
  - Make atomic commits — one logical change per commit
  - Use conventional commits format (feat/fix/refactor/docs)
  - Run the test command after each significant change (read § Pre-Deploy Gate from method.config.md)
  - Stop and surface if you hit a blocker — do not loop

  Plan:
  <full plan from step 3b>

  Spec:
  <full spec from step 2>

  Project conventions: read CLAUDE.md and any Strategy/* docs the spec references.
  ```

Wait for the subagent to return.

**Inline path** — work through the plan directly using Edit, Write, Read, Bash. Same discipline (atomic commits, test after change, surface blockers). Use a TaskCreate with one task per "Files to touch" item to track your own progress.

## Step 6 — `--deep` security review

After dev completes (whether subagent or inline), if `--deep`:

Use Task tool with:
- `subagent_type: "security-review"` (project may have this; otherwise `"general-purpose"`)
- `description: "Security review of <ISSUE-ID> diff"`
- Prompt template:
  ```
  Review the diff on this branch (relative to origin/<integration>) for security issues.

  Specifically check:
  - SQL injection / parameterized queries
  - RLS policies (Supabase): are new tables protected?
  - Authn/authz: any auth-checking code paths added or modified?
  - Secrets: any new env vars or hardcoded values?
  - PII handling: any new user-data flows?

  Diff context:
  <output of: git diff origin/<integration-branch>...HEAD>

  Return findings ranked Critical / High / Medium / Low.
  Be terse. Cite file:line for each finding.
  ```

Print the review verbatim.

## Step 7 — Hand off, don't auto-ship

Print:

```
✓ /work complete for <ISSUE-ID>

Next:
  /verify        — run pre-deploy gate + QA review (if configured)
  pk verify      — same, from shell

Then:
  pk ship        — push, open PR, transition Linear

Stop hook will write the journal entry on session close.
```

**Do not** invoke `pk ship` or `/verify` automatically. The user paces.

## Failure model

| Failure | Behavior |
|---|---|
| On dev/main/beta at step 0 | Refuse. Print "Run pk branch <ID> first." |
| Spec missing required sections, no `--deep` | Warn, ask y/N. |
| Spec missing required sections, with `--deep` | Refuse. Recommend `/light-spec` or `pk delegate`. |
| Plan revised >3 times | Refuse. Recommend `pk delegate`. |
| Subagent returns permission denial | Stop. Print the denial. Do not retry. |
| Subagent returns ambiguous failure | Print full output. Ask user how to proceed. |
| Tests fail post-execute | Surface. Don't auto-fix — that's `/verify`. |

## What this skill does NOT do

- No tier inference (Quick/Standard/Heavy gone — use `--deep` if you want extra rigor).
- No `--auto` chain (the user is the chain).
- No PR creation (that's `pk ship`).
- No NEXT.md write (NEXT.md doesn't exist in v2).
- No session log write (Stop hook owns the journal).
- No Linear status writes during work (`pk branch` set In Progress; `pk ship` will set UAT).
- No `/end-session` invocation.

## Comparison with v1

| Concern | v1 (`/launch --auto`) | v2 (`/work`) |
|---|---|---|
| Lines of skill prose | 765 | ~330 |
| Tier system | Quick/Standard/Heavy | None (`--deep` flag) |
| Verdict loop | 3 rounds + stalemate detection | 1 screen, 3 options, 3-revision hard limit |
| Backend | VBW only | `vbw \| native` per config |
| Auto-chain | Yes (4 hidden agent invocations) | No (user paces) |
| State writes | Linear (twice), VBW STATE.md, pipeline-state JSON | None (read-only) |
