---
name: linear-todo-runner
description: Rolling parallel agent queue across isolated worktrees. Use when batching multiple Approved Linear issues for parallel execution. Use when phase has independent issues with no shared blockers. Up to 4 workers, dependency-aware.
---

# Linear Todo Runner

You are a batch execution coordinator. Your job is to run a rolling parallel agent queue that processes Linear issues. Read `method.config.md` for project context. You fetch issues, validate acceptance criteria, spawn up to 4 worker agents in isolated worktrees, and refill slots as agents complete. Dependency-aware scheduling ensures blocked issues wait until their blockers are Done.

## Triggers

This skill is invoked when the user says:
- `/linear-todo-runner`
- "run the queue"
- "batch process issues"
- "start the runner"

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Run with defaults: Approved, max 4 agents |
| `--dry-run` | Show queue and dependency graph without spawning agents |
| `--limit N` | Process at most N issues total, then stop |
| `--max-agents N` | Override max concurrent agents (default: 4, max: 4) |
| `--project <name>` | Filter to a specific project (e.g., `Budget Editor`) |
| `--cycle <name>` | Filter to a specific cycle/work-package (e.g., `WP-1`) |
| `--prep` | Generate draft AC for issues that lack it (no agents spawned) |

## Prerequisites

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` should be set to `"1"` in `.claude/settings.json` under `env`
- Linear MCP server should be connected (`mcp__linear-server__*` tools available)
- Issues need `## Acceptance Criteria` in their description (issues without AC are skipped)
- The orchestrator creates one real `git worktree add` per agent before spawning. Do NOT rely on the Agent tool's `isolation: "worktree"` parameter — empirically a no-op on current harnesses, which collapses all "parallel" agents into the same checkout and causes sibling branch switches to silently discard each other's uncommitted work. If you cannot run `git worktree add` from the orchestrator, run the queue with `--max-agents 1` (sequential) instead.

## Linear State IDs

Read all state IDs from your project's `method.config.md` under "Workflow State IDs". The table maps state names (Building, UAT, Done, etc.) to Linear state UUIDs specific to your workspace.

---

## Execution Phases

### Phase 1 — Queue Assembly

1. **Fetch candidate issues** from Linear using `mcp__linear-server__linear_searchIssues`:
   - Primary: `team: "{team from method.config.md}"`, `state: "Approved"`
   - Overflow: `team: "{team from method.config.md}"`, `state: "{Spec ready state from method.config.md — default Specced; never hardcode, two-state boards use Needs Spec}"`
   - Apply `--project` or `--cycle` filters if provided
   - **Paginate**: if `hasNextPage` is true, fetch subsequent pages using the `cursor` parameter until all issues are retrieved
   - **Filter out archived issues**: skip any issue where `archivedAt` is non-null
2. **Sort** by priority (P1 Urgent first → P4 Low last), then by cycle assignment (current cycle first)
3. **Build dependency graph** — for each issue, check `blocked_by` relations via `mcp__linear-server__linear_getIssueById`
4. **Filter to ready issues** — only issues whose blockers are ALL in "Done" state
5. **Apply `--limit`** if provided
6. **Output** the ordered queue:

```
## Queue (12 issues ready, 3 blocked)

Ready:
  1. PROJ-88  — AG Grid Enterprise Migration [Budget Editor] P1
  2. PROJ-252 — Basic Google OAuth Login [Onboarding & UX] P2
  3. PROJ-253 — Budget Locking & Editor Presence [Budget Editor] P2
  ...

Blocked (waiting on dependencies):
  - PROJ-260 — Smart Edit Panel (blocked by PROJ-88)
  - PROJ-265 — Intro Tour (blocked by PROJ-255)
  ...
```

If `--dry-run` is set, display the queue and stop here.

### Prep Mode (`--prep`)

When `--prep` is passed, the runner generates draft acceptance criteria for issues that lack them. No worker agents are spawned.

**For each issue in the queue that does NOT have a `## Acceptance Criteria` section:**

1. Read the full description via `mcp__linear-server__linear_getIssueById`
2. Analyze the description to extract verifiable criteria from:
   - `## Scope` or `**Scope:**` sections
   - `## What This Covers` sections
   - POC file references (e.g., `src_poc/app/js/auth.js`)
   - Spec file references (e.g., `Strategy/Specs/PROJ-24-Smart-Import.md`)
   - Architecture decisions and constraints mentioned
3. Generate a draft `## Acceptance Criteria` as a markdown checklist:
   - Each criterion must be **concrete and verifiable** (not "works well" — instead "Google OAuth sign-in creates a session and redirects to /dashboard")
   - Include functional criteria (what the feature does)
   - Include technical criteria where the description implies them (RLS policies, migrations, strict TS)
   - Include a UI/design criterion for any issue with a visual component: "UI uses project design system tokens and components (colors, typography, spacing)"
   - Reference specific POC functions to port if mentioned in the description
   - Keep to 5-10 criteria — enough to define "done", not a full test plan
4. Post the draft AC as a **Linear comment** on the issue via `mcp__linear-server__linear_createComment`:

```markdown
## Draft Acceptance Criteria (generated by runner)

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...

> Review and copy into the issue description under `## Acceptance Criteria` to enable processing.
```

5. **Move issue to Approved** via `mcp__linear-server__linear_updateIssue` with `stateId: {Approved state ID from method.config.md}`
6. Log the issue: `"PROJ-XXX — draft AC posted, moved to Approved. Review in Linear."`

**Issues that already have `## Acceptance Criteria` are moved to Approved (if not already) and skipped with:** `"PROJ-XXX — AC already present, moved to Approved, ready for queue."`

**After all drafts are posted, prompt for approval:**

For each issue with draft AC, ask the user:

```
PROJ-XXX — {title}
  Draft AC: {number} criteria posted as comment
  Approve and write to description? (y/n/edit)
```

- **y** — Append the `## Acceptance Criteria` section to the issue description via `mcp__linear-server__linear_updateIssue` (append to existing description, do not overwrite)
- **n** — Skip, leave as comment only for manual editing
- **edit** — Show the draft AC inline, let the user modify, then write the edited version to the description

**Output at completion:**

```
## Prep Complete

Draft AC posted: 8 issues
Approved & written to description: 6 issues
Skipped (user declined): 1 issue
Skipped (empty description): 0 issues
Already have AC: 1 issue

Next steps:
  1. Review any declined issues in Linear
  2. Run /linear-todo-runner to process the queue
```

After prep, stop. Do not continue to Phase 2.

### Phase 2 — Acceptance Criteria Gate

For each issue at the front of the queue (up to max-agents):

1. **Read full description** via `mcp__linear-server__linear_getIssueById`
2. **Extract acceptance criteria** — look for `## Acceptance Criteria` section
3. **If no AC found:** skip the issue, log: `"PROJ-XXX skipped — no acceptance criteria. Add AC in Linear and re-run."`
4. **Store AC** as the verification checklist for the worker agent

### Phase 3 — Agent Spawn & Lifecycle

**Subagent mandate for this skill:** spawn parallel worktree agents even though Opus 4.7 defaults to fewer subagents. The whole point of `/linear-todo-runner` is fanning out independent work across isolated worktrees. A single-session sequential loop would defeat the purpose. Spawn up to `max-agents` in the same turn when the dependency graph permits; don't serialize them.

**Worktree isolation is the orchestrator's job, not the Agent tool's.** Each agent gets a real `git worktree add` before it spawns, and is told via its prompt to `cd` into that worktree as its first action and verify (`pwd` + `git rev-parse --show-toplevel`) before any edits. The Agent tool itself currently exposes no working-directory parameter — `isolation: "worktree"` is a no-op on current harnesses (see Prerequisites), and there is no `cwd` parameter. The prompt-level `cd` + verification is the actual containment mechanism, so it is NOT optional.

For each issue that passes the AC gate (up to max-agents concurrently):

1. **Move issue to Building** via `mcp__linear-server__linear_updateIssue` with `stateId: {Building state ID from method.config.md}`
2. **Compute identifiers:**
   - `BASE` = current checked-out branch in the orchestrator's repo (`git rev-parse --abbrev-ref HEAD`). All worker branches fork from this.
   - `BRANCH_NAME` = `feature/<issue-id-lowercase>-<slugified-title>` (e.g., `feature/proj-88-ag-grid-enterprise`). Use the project's existing branch-naming convention from `method.config.md` if specified.
   - `REPO_BASENAME` = `basename` of the orchestrator's repo root.
   - `WORKTREE_PATH` = `../<REPO_BASENAME>-<issue-id-lowercase>` (sibling to the main checkout, NOT inside `.worktrees/` — keeps the parallel runner separate from `pk branch`'s interactive trees).
3. **Preflight:** if `<WORKTREE_PATH>` already exists OR `<BRANCH_NAME>` already exists, FAIL LOUDLY for this issue — skip it, log the collision, move the issue back to Approved, post a Linear comment with the conflict. Do NOT reuse existing paths or branches; that's how today's blended diffs happen.
4. **Create the worktree:**
   ```bash
   git worktree add <WORKTREE_PATH> -b <BRANCH_NAME> <BASE>
   ```
   If this fails (e.g., dirty index, lock contention), skip the issue, move it back to Approved, post the git error in a Linear comment, and continue with the next queue item. Do NOT spawn an agent without a worktree.
5. **Verify the worktree:** run `git worktree list` and confirm `<WORKTREE_PATH>` appears with the expected branch. If not, treat as Step 4 failure.
6. **Post a Linear comment**: `"Runner: spawning agent in worktree {WORKTREE_PATH} on branch {BRANCH_NAME}."`
7. **Spawn a worker agent** using the `Agent` tool with `run_in_background: true`. The Agent tool does NOT support a `cwd` parameter and `isolation: "worktree"` is a no-op — DO NOT pass either. Instead, the worker prompt's first instruction must be `cd <WORKTREE_PATH>` followed by `pwd` and `git rev-parse --show-toplevel` verification (see Worker Agent Prompt Template). Pass `<WORKTREE_PATH>` and `<BRANCH_NAME>` as concrete values inside the prompt — do not leave placeholders:

```
Agent(
  description: "PROJ-XXX: {issue title}",
  run_in_background: true,
  mode: "bypassPermissions",
  prompt: <Worker Agent Prompt Template with WORKTREE_PATH and BRANCH_NAME interpolated>
)
```

8. **Track the agent** in an internal slot table:
   - Slot number (1-4)
   - Issue identifier (PROJ-XXX)
   - Agent ID/name
   - Status: `spawned` → `running` → `done` / `failed`
   - Worker branch name (`BRANCH_NAME`)
   - Worktree path (`WORKTREE_PATH`) — needed by Phase 4 cleanup

### Phase 4 — Rolling Refill

When any background agent completes:

**On success (agent reports all AC met + pre-deploy gate passed):**
1. Move issue to "UAT" via `mcp__linear-server__linear_updateIssue` with `stateId: {UAT state ID from method.config.md}`
2. Post a Linear comment with: branch name, worktree path, commit summary, pre-deploy gate results
3. Log the branch for PR creation
4. **Clean up the worktree:** run `git worktree remove <WORKTREE_PATH>` from the orchestrator's repo. The branch stays — it has the committed work and needs to remain for PR creation. If `git worktree remove` reports the worktree is dirty (the worker committed but left untracked files), use `git worktree remove --force <WORKTREE_PATH>` and note it in the dashboard. Do NOT delete the branch.
5. **Write pipeline state file:** resolve `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)` and write `$STATE_DIR/pipeline-state/<issue-id>.json` per `sop/Skills_SOP.md` § Pipeline state file with `stage: "linear-todo-runner"`, `verdict: "Pass"`, `cwd`, `timestamp`. Path is out-of-repo so no hook block; write should always succeed.

**On failure (agent reports errors or AC not met):**
1. Move issue back to "Approved" via `mcp__linear-server__linear_updateIssue` with `stateId: {Approved state ID from method.config.md}`
2. Post a Linear comment with the failure reason, any partial progress, AND the preserved worktree path (so the user can `cd` into it for inspection)
3. **Do NOT remove the worktree on failure.** It may contain uncommitted diagnostic state from the worker. Leave both the worktree and the branch in place — the user cleans up manually after triage (`git worktree remove <path>` and `git branch -D <branch>` once they're done).
4. Log as failed
5. **Write pipeline state file:** `$STATE_DIR/pipeline-state/<issue-id>.json` (with `STATE_DIR` resolved as above) with `stage: "linear-todo-runner"`, `verdict: "Fail"`, `cwd`, `timestamp`. The Linear comment from step 2 captures the diagnosis; the next-action recommendation is rendered by `/pipekit-help` against the failed-state record, not pre-baked into the file.

**Then refill:**
1. Re-evaluate the queue — check if any previously-blocked issues are now unblocked (their blockers may have just completed)
2. Pick the next ready issue from the queue
3. Run Phase 2 (AC gate) + Phase 3 (spawn) for it
4. Continue until queue is exhausted or `--limit` reached

### Phase 5 — Status Dashboard

After each agent completion event, display a compact status table:

```
## Runner Status

| Slot | Issue | Title | Status | Branch |
|------|-------|-------|--------|--------|
| 1 | PROJ-88 | AG Grid Enterprise Migration | Done | worktree/wit-88-ag-grid |
| 2 | PROJ-252 | Basic Google OAuth Login | Running | worktree/wit-252-oauth |
| 3 | PROJ-253 | Budget Locking & Editor Presence | Running | worktree/wit-253-locking |
| 4 | — | — | Idle | — |

Queue: 8 remaining | Done: 3 | Failed: 0 | Skipped (no AC): 1
```

**At completion** (queue empty + all agents done), produce a final summary:

```
## Runner Complete

Processed: 12 | Done: 10 | Failed: 1 | Skipped: 1
Duration: ~45 min

Branches ready for PR:
  - feature/wit-88-ag-grid
  - feature/wit-252-oauth
  - feature/wit-253-locking
  ...

Failed (needs manual attention):
  - PROJ-260 — Smart Edit Panel: type-check failed (see Linear comment)

Next steps:
  - Create PRs for completed branches
  - Fix failed issues manually with `/linear PROJ-260`
  - Re-run `/linear-todo-runner` for any remaining queue
```

---

## Worker Agent Prompt Template

Each spawned worker receives a self-contained prompt (outer fence uses 4 backticks so the inner ```bash verification block nests correctly):

````
You are implementing a Linear issue inside a dedicated git worktree. You share a filesystem with sibling agents, but you DO NOT share a working directory — every shell command you run MUST run inside your own worktree, or you will trample other agents' uncommitted work.

## Worktree (READ THIS FIRST — non-negotiable)
- **Worktree path:** {WORKTREE_PATH}
- **Branch:** {BRANCH_NAME}

Your FIRST action, before any reads, edits, or other shell commands, is:

```bash
cd {WORKTREE_PATH}
pwd                                    # must print {WORKTREE_PATH}
git rev-parse --show-toplevel          # must also print {WORKTREE_PATH}
git rev-parse --abbrev-ref HEAD        # must print {BRANCH_NAME}
git worktree list                      # confirm {WORKTREE_PATH} appears
```

If ANY of those four checks does not match exactly, STOP. Do not run any further commands, do not edit any files, and report the mismatch in your final summary with the actual output you saw. A mismatch means the orchestrator's worktree setup is broken and continuing will corrupt sibling agents' work.

After verification, every subsequent Bash command in this task — including `git`, `pnpm`, file inspection, and pre-deploy gate runs — must execute from {WORKTREE_PATH}. Never `cd` out of it. Never use absolute paths into another worktree. If you need a path, build it relative to {WORKTREE_PATH}.

## Issue
- **Identifier:** PROJ-{XXX}
- **Title:** {title}
- **Project:** {project name}

## Description
{full issue description from Linear}

## Acceptance Criteria
{extracted AC checklist}

## Instructions

1. Read CLAUDE.md in the repo root for all project conventions. CLAUDE.md is the authoritative source for coding standards, naming patterns, and architectural decisions. If the issue has UI work, also read `Strategy/DesignDirection.md` for visual design guidance.
2. Implement the changes described in the issue.
3. Include `PROJ-{XXX}` in all commit messages.
   Format: `{type}({scope}): {description} (PROJ-{XXX})`
4. Before finishing, run the pre-deploy gate:
   - `pnpm turbo run check-types`
   - `pnpm turbo run lint`
   - `pnpm turbo run test`
   If any fail, fix them before reporting done.
5. Report your results:
   - Which acceptance criteria are met (checklist)
   - Worktree path and branch name (echo back what was given to you)
   - Commit hashes
   - Pre-deploy gate results (pass/fail for each)
   - Any issues or decisions you made

## Permission-denial protocol

If any Edit/Write call fails with a permission denial (EditPermissionDenied,
HookFeedbackBlocked, or similar hook-driven block), STOP IMMEDIATELY and
report in your final summary. Do not retry. Do not attempt to work around
the block by editing a different file or splitting the change. Include in
your summary:
  - The denied path
  - The intended change verbatim (the patch you would have applied)
  - Why it was needed (which task / which acceptance criterion)
The orchestrator will surface the denial for manual resolution. A single
denial is not a transient error — it indicates a project-policy mismatch
(typically a hook protecting a canonical file like .claude/rules/*) that
the user must resolve before the work can continue.
````

---

## Dependency Scheduling Notes

The runner does NOT hardcode dependency chains. It reads `blocked_by` relations from Linear issues. For Phase 2 context, the typical dependency graph is:

- WP-1 (Foundation Fixes) blocks most downstream work
- After WP-1: WP-2 (AG Grid) and WP-4 (Auth/Nav) can run in parallel
- WP-8 (Smart Edit) depends on WP-2 completion
- WP-11 (Intro Tour) depends on WP-5 (Theme system)
- Max practical parallelism: 3 tracks (Editor, Auth/Nav, AI/Polish)

Set `blocked_by` relations in Linear to enforce the correct execution order.

---

## Error Handling

- **Agent timeout:** If an agent runs longer than 30 minutes without reporting, flag it in the dashboard as `Stalled`. Do not kill it automatically — notify the user.
- **Pre-deploy gate failure:** Agent should attempt to fix. If it cannot fix after one retry, report as failed.
- **Linear MCP unavailable:** Stop the runner with a clear error. Do not spawn agents without status tracking.
- **No ready issues:** If all remaining issues are blocked, display the blocked list and exit cleanly.

## Relationship to Other Skills

- **`/task-processor`** — Single-issue interactive pickup. Use for hands-on work. The runner is for batch automation.
- **`/linear PROJ-XXX`** — Full end-to-end lifecycle for one issue. Use for failed issues that need manual attention.
- **`pk status`** / **`pk next`** — Quick board view. Run before the runner to see what's queued.
- **`/sync-linear`** — Reconcile strategy-doc / requirement drift against the Linear `i{N}.`/`I{N}.P{N}.` phase hierarchy. Run after the runner to re-home or re-place issues that drifted.
- **`pk branch`** — The runner creates its own sibling worktrees at `../<repo>-<id>` via explicit `git worktree add` (one per worker), distinct from `pk branch`'s in-repo `.worktrees/<ID>-<slug>/` pattern for interactive single-issue work. The two coexist: use `pk branch` hands-on, use the runner for parallel batches. (Prior versions of this skill claimed to use the Agent tool's `isolation: "worktree"` parameter; that parameter is a no-op on current harnesses, which is why we now create worktrees explicitly.)

---

## Example Session

```
User: /linear-todo-runner --prep --project "Onboarding & UX"

## Prep: Generating draft AC for 6 issues...

  PROJ-252 — Basic Google OAuth Login → draft AC posted as comment
  PROJ-256 — Project Creation Wizard → draft AC posted as comment
  PROJ-254 — Entity Switcher (Parity) → draft AC posted as comment
  PROJ-251 — Admin & Super Admin Section → draft AC posted as comment
  PROJ-255 — Dark/Light Theme Toggle → draft AC posted as comment
  PROJ-257 — What's New Modal → draft AC posted as comment

## Prep Complete

Draft AC posted: 6 issues
Already have AC: 0 issues

Next steps:
  1. Review draft AC in Linear for each issue
  2. Copy approved AC into the issue description
  3. Run /linear-todo-runner --project "Onboarding & UX" to process

---

User: /linear-todo-runner --dry-run

## Queue (8 issues ready, 2 blocked)

Ready:
  1. PROJ-88  — AG Grid Enterprise Migration [Budget Editor] P1
  2. PROJ-252 — Basic Google OAuth Login [Onboarding & UX] P2
  3. PROJ-253 — Budget Locking & Editor Presence [Budget Editor] P2
  4. PROJ-254 — Entity Switcher (Parity) [Onboarding & UX] P2
  5. PROJ-255 — Dark/Light Theme Toggle [Onboarding & UX] P3
  ...

Blocked:
  - PROJ-260 — Smart Edit Panel (blocked by PROJ-88)
  - PROJ-265 — Intro Tour (blocked by PROJ-255)

Actions:
  Remove --dry-run to start processing
  /linear-todo-runner --limit 4   — process first 4 only
  /linear-todo-runner --project "Budget Editor"  — filter to one project

---

User: /linear-todo-runner --limit 4

Spawning 4 agents...

## Runner Status
| Slot | Issue | Title | Status | Branch |
|------|-------|-------|--------|--------|
| 1 | PROJ-88 | AG Grid Enterprise | Running | (worktree) |
| 2 | PROJ-252 | Google OAuth | Running | (worktree) |
| 3 | PROJ-253 | Budget Locking | Running | (worktree) |
| 4 | PROJ-254 | Entity Switcher | Running | (worktree) |

Queue: 0 remaining | Done: 0 | Running: 4

[... agents complete over time, dashboard updates ...]

## Runner Complete
Processed: 4 | Done: 3 | Failed: 1
```
