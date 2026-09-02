---
name: work
description: V2 daily-loop skill — plan + execute a Linear issue from inside its worktree. Use after pk branch opens a worktree. Use when an Approved Linear issue is ready for implementation. Native-on-Workflow is the sole executor.
---

# /work

> **North star:** safe and frictionless. Helps, never adds work.

You drive one Linear issue from spec to verified commits. Read the spec, infer the tier from Linear labels, plan, present the plan for a verdict, execute the plan on the `pk-execute` workflow, self-check, and roll over to `/verify`. Tier shapes which gates run. The human paces the loop; you do not chain past it.

## Triggers

- `/work <ISSUE-ID>` — primary (tier from the Linear `tier:*` label, default Standard)
- `/work <ISSUE-ID> --deep` — Standard-tier shortcut to spec-validator + code survey + security review; no-op on Quick, already forced on Heavy
- `/work <ISSUE-ID> --resume` — continue an execution that stopped (see § Resume)
- `/work <ISSUE-ID> --no-rollover` — build, but do not auto-run `/verify`
- "work on RS-30" / "let's do PIP-123"

## Preconditions

1. Either you are inside a worktree on a feature branch (not `dev`, `main`, `beta`, `master`), or `<ISSUE-ID>` is passed so Step 0 can auto-branch.
2. `method.config.md` is readable in the repo root.

## Step 0 — Verify or create the worktree

From an integration branch with an explicit `<ISSUE-ID>`, create the worktree via `pk branch` and `cd` into it. Run this exactly:

```bash
CURRENT=$(git branch --show-current)

case "$CURRENT" in
  dev|main|master|beta)
    if [ -z "$1" ]; then
      echo "ERROR: /work invoked from integration branch '$CURRENT' with no <ISSUE-ID>." >&2
      echo "Pass an ID (e.g. /work RS-123) or run 'pk branch <ID>' yourself first." >&2
      exit 1
    fi
    ISSUE="$1"
    echo "→ Auto-branching: pk branch $ISSUE"
    pk branch "$ISSUE" || { echo "ERROR: pk branch failed for $ISSUE" >&2; exit 1; }
    WORKTREE=$(git worktree list --porcelain | awk -v id="$ISSUE" '
      /^worktree / { wt=$2 }
      /^branch / && index($0, id) { print wt; exit }
    ')
    [ -z "$WORKTREE" ] && { echo "ERROR: could not locate worktree for $ISSUE" >&2; exit 1; }
    cd "$WORKTREE" || exit 1
    CURRENT=$(git branch --show-current)
    ;;
esac

ISSUE=${ISSUE:-$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)}
[ -z "$ISSUE" ] && { echo "ERROR: no issue ID in branch name and none provided." >&2; exit 1; }
```

## Step 1 — Read configuration

Read values with `pk config <key> [default]`, never by grepping the markdown table (the table format is unreliable to parse inline; the subcommand is `pk config`, not the internal `pk_config`).

```bash
DEEP_FLAG=$(pk config "Default deep flag" "false")
QA_REVIEW=$(pk config "Require QA review" "false")
STRATEGY_PATH=$(pk config "Strategy docs path" "Strategy/")
INTEGRATION=$(pk config "Integration branch" "dev")
```

The effective `--deep` is the CLI flag OR `Default deep flag: true`. Print one line: `Work: <ISSUE-ID>  ·  Deep: <yes|no>`.

## Step 2 — Fetch the spec from Linear

Call `mcp__linear-server__linear_getIssueById` once and capture `title`, `description`, `state.name`, and `labels`. Expected states: `In Progress`, `Building`, or `Approved` (Step 0's auto-branch transitions it). On `Backlog` / `Todo` without a just-completed auto-branch, refuse.

**Read once.** This is the one full-content read `/work` needs. The payload carries the whole comment thread and is sticky (re-billed every turn, `pipekit-tooling.md` § MCP Result Payloads Are Sticky). For any later state check use `pk issue show <ID>`, `pk status`, `git`, or `gh`.

The description must contain `## Light Spec` or `## Acceptance Criteria`. If neither: without `--deep`, warn, print the first 30 lines, ask `Continue planning with this vague spec? (y/N)`, default N. With `--deep`, refuse: `Spec missing required sections. Run /light-spec <ID> first, OR pk delegate <ID> "draft a Light Spec for this issue against {project} conventions".`

## Step 2.5 — Label the session and terminal

Best-effort, never blocking:

```bash
[ -x "$HOME/.claude/scripts/set-topic.sh" ] && "$HOME/.claude/scripts/set-topic.sh" "<ISSUE-ID> — <title>"
printf '\033]0;%s\007' "<ISSUE-ID>"
```

## Step 2.6 — Infer tier from Linear labels

Take the first of `tier:quick`, `tier:standard`, `tier:heavy` in `labels`; default **Standard**. Print `Tier: <quick|standard|heavy>`. Per-tier semantics are canonical in `pipekit/templates/tier-{quick,standard,heavy}.md`.

- **Quick**: light by design. `--deep` is ignored. Mention once that `/06-linear-todo-runner` batches several Quick issues in parallel.
- **Heavy**: `--deep` behaviour is forced, the security review is forced at Step 6, and `/strategy-sync` is required before the initiative closes (after this issue merges, not before its `pk done`). Say so up front so the human can plan.

## Step 3 — Plan

| Tier | Path | Subagents |
|------|------|-----------|
| Quick | inline, forced | none |
| Standard | `--deep` if set, else inline | spec validator + code survey when `--deep` |
| Heavy | `--deep` grounding, forced | spec validator + code survey |

### `--deep` path: parallel grounding

Send both `Agent` calls in one message. Each prompt opens with the intent line, because a grounded reviewer does better work when it knows why the issue exists:

> Linear issue `<ISSUE-ID>` — `<title>`. Goal: `<one sentence from the spec>`.

1. **Spec validator.** `subagent_type: "general-purpose"` (or a project-local `spec-validator`), on the plan-review tier per `method.config.md § Model Policy` (default `opus` / `xhigh`). Prompt: the full description, then the rubric — a one-sentence Goal; at least three testable Acceptance Criteria; concrete file paths and line refs rather than "the auth module"; dependencies listed; no open questions. Return **Pass**, **Concerns** (specific gaps with refs), or **Block** (a gap that prevents planning). Conclusions only.
2. **Code survey.** `subagent_type: "Explore"`, on the grounding tier (default `haiku` / `low`). Prompt: the file paths, tables, and packages the spec names; for each, its purpose, the key types and functions present, and the patterns the surrounding code uses so new work fits. Conclusions only.

Synthesize both into the plan.

### Inline path

Read the spec, `CLAUDE.md`, and any `Strategy/*` files the spec cites. Plan directly.

### Step 3b — Write the plan (both paths)

One screen:

```
## Plan: <ISSUE-ID> — <title>

**Goal:** <1 sentence>

**Approach:** <2–4 sentences — the technical strategy>

**Files to touch:**
- `path/to/file1.ts` — <what changes>
- `supabase/migrations/<N>_<name>.sql` — <what changes>

**Tests:**
- <scenario>

**Risks / open questions:**
- <empty — if non-empty, the spec is not ready; go back to Step 2>
```

## Step 4 — Verdict gate

**Quick:** print the plan and ask once, `Plan looks right? (y/n)`. `y` proceeds; `n` exits with `Aborted. Refine the AC in Linear and rerun /work <ISSUE-ID>.` No revision loop: on Quick the AC is the plan, so a wrong plan means a wrong AC.

**Standard / Heavy:** print the plan, then ask exactly:

```
Verdict?
  proceed                  — execute the plan as written
  revise: <feedback>       — edit and re-present
  abort                    — stop, do nothing
```

`proceed` → Step 5. `revise:` → fold the feedback in, re-print, re-ask, counting revisions. `abort` → exit without changing state. After three revisions refuse a fourth: `Plan has been revised 3 times. The spec is likely the problem, not the plan. Stopping to prevent waste.` and recommend `pk delegate <ISSUE-ID> "the plan keeps revising on <area>. Refine the spec to clarify <X>."`

## Step 5 — Execute

The executor contract is: a PLAN artifact, one atomic commit per task with verify before commit, and a SUMMARY trail. Nothing else — no UAT, no known-issue registry, no sprint state. The full Pre-Deploy Gate runs once at the end, inside `/verify`.

### Step 5.0 — Materialize the PLAN artifact

Convert the plan into a task DAG at `.pk-work/<ISSUE-ID>-PLAN.md` (`.pk-work/` is gitignored; `mkdir -p .pk-work` first). This is the contract the workflow consumes and `/review-plan` reads.

```
# PLAN — <ISSUE-ID> <title>
Goal: <one line — why this issue exists and who it serves>
Mode: <inline|workflow>  ·  Generated: <date>

## T1 — <short imperative title>
- deps: <none | T-ids this task requires>
- files: `path/a`, `path/b`        # the exact file set this task writes
- change: <one line — the logical change>
- verify: <task-scoped check — a test command, a grep, a type-check>
- done: <observable condition that proves the AC slice is met>

## T2 — ...
```

DAG rules:

- One logical change per task, one atomic commit. If `change:` needs two sentences, split the task.
- `deps` encodes order. `files` encodes conflict: two tasks may run concurrently only when their `files` sets are disjoint.
- Every task has a `verify` that runs in isolation. A task with no meaningful verify gets folded into a sibling or gains a real check.
- **The task authors the tests the AC implies; running the existing suite is necessary, never sufficient.** A security- or correctness-critical path shipped without a new test that proves it is an incomplete task. Prefer test-first. (The native-executor pilot, SiteLine POC-57 2026-06-07, built a correct security guard and shipped it unverified for exactly this reason.)
- If the AC names a test command verbatim, tasks use it verbatim; ad-hoc invocations cost retries re-discovering package scripts and filter syntax. Otherwise the project's § Pre-Deploy Gate command is the fallback.

### Step 5.1 — Choose the mode

- **Inline** — at most 2 tasks, at most 2 files, no migration. Execute directly with Edit/Write/Bash: change, run the task's `verify`, commit only on pass, surface a failure without looping.
- **Workflow** — everything else. Step 5.2.

Record the mode in the PLAN header.

### Step 5.2 — Run the `pk-execute` workflow

The saved workflow `pk-execute` (`.claude/workflows/pk-execute.js`, synced by Pipekit) holds the execution loop, so this session's context holds only the result. Invoke it with the `Workflow` tool by name. The user opted in by typing `/work`; the first run in a project may ask once for approval of the named workflow.

Build `args` from the PLAN — the script has no filesystem access, so the DAG travels as data:

```
{
  "issue": "<ISSUE-ID>", "title": "<title>", "goal": "<Goal line from the PLAN>",
  "integration": "<INTEGRATION>",
  "baseSha": "<git rev-parse HEAD>",
  "worktreePath": "<pwd>",
  "testCommand": "<the AC-named test command, else the pre-deploy gate command>",
  "parallel": <true|false — see below>, "maxParallel": 3,
  "model": "<execution-tier model or null>", "effort": "<execution-tier effort or null>",
  "tasks": [ { "id": "T1", "title": "...", "deps": [], "files": ["..."], "change": "...", "verify": "...", "done": "...", "spec": "<the AC lines this task covers>" } ]
}
```

**Model and effort** come from the execution tier in `method.config.md § Model Policy` (default `sonnet` / `medium`). Pass them explicitly so a frontier-model session does not silently run every task at frontier cost. When the project has measured that the session model at `low` or `medium` effort costs less per completed task, it sets the execution-tier row to blank and the fields are passed as null to inherit. A task that genuinely needs deeper reasoning is surfaced to the human, not escalated unilaterally.

**Parallelism.** Tasks at one dependency level with disjoint `files` may run concurrently, each in its own harness-managed worktree, followed by an integration step that cherry-picks the wave onto the feature branch and re-runs each verify on the integrated tree. Set `parallel: true` only when both hold, and say which one failed when it is false:

```bash
# 1. The harness must branch subagent worktrees from THIS worktree's HEAD, not from origin's default branch.
jq -r '.worktree.baseRef // "fresh"' .claude/settings.json 2>/dev/null   # must print: head
# 2. Subagent worktrees must not show up as untracked files.
git check-ignore -q .claude/worktrees/                                   # exit 0
```

Otherwise `parallel: false` runs every task sequentially in this worktree — the production-validated path, and the right default on a rate-capped plan where a wide fan-out only queues behind the API limit. Task agents never spawn agents of their own.

**What the workflow does** (read `.claude/workflows/pk-execute.js` if in doubt): orders tasks by `deps`; runs each task agent with only its task slice, the intent line, and the discipline (author tests, verify, commit only on pass, stay inside the file set, report grounded); threads the expected HEAD sha from task to task so an agent that finds a different HEAD refuses to edit; stops at the first task that is not `done` and returns `{ status: "complete" | "stopped", headSha, results }`.

**When it returns**, write `.pk-work/<ISSUE-ID>-SUMMARY.md` from `results` — the session does this deterministically, task agents do not append to it:

```
# SUMMARY — <ISSUE-ID>
Workflow run: <runId from the tool result>  ·  Base: <baseSha>  ·  Head: <headSha>  ·  Status: <complete|stopped>

| Task | Mode | Status | Commit | Verify | Tests authored | Notes |
|------|------|--------|--------|--------|----------------|-------|
| T1 | sequential | done | <sha> | pass | tests/x.test.ts | — |
```

On `stopped`: print the failing task's `summary`, `verifyTail`, and `notes` verbatim, and stop. Do not revise the plan or retry on your own; the human decides (fix and `/work --resume`, or `revise` the plan).

**Fallbacks, both loud.** If `.claude/workflows/pk-execute.js` is absent, print `pk-execute workflow not found — run /pipekit-update, running sequential Agent fallback` and dispatch one `Agent` per task in dependency order with the same prompt contract the script uses (task slice, intent line, expected HEAD check, verify-before-commit, structured result). If the `Workflow` tool itself is unavailable, do the same and say so. Never collapse to a single agent with the whole plan.

## Step 6 — Security review

| Tier | Runs |
|------|------|
| Quick | never (rely on `/pr-security-review` post-ship for sensitive Quick changes) |
| Standard | when `--deep` |
| Heavy | always |

Spawn one `Agent` (`subagent_type: "security-review"` if the project has it, else `general-purpose`) on the adversarial tier (default `opus` / `xhigh`) with the diff against `origin/<INTEGRATION>` and this brief: SQL injection and parameterization; RLS on new tables; authn/authz paths added or changed; new env vars or hardcoded secrets; new user-data flows. Findings ranked Critical / High / Medium / Low with `file:line`. Print the review verbatim.

## Step 6.5 — Behavioral self-check before declaring complete

Tests passing and the gate green are necessary, not sufficient (rs-vault RS-63/64, 2026-05-02: every check passed, the running app was 60% broken).

**UI changes:** run the app (or use the running dev server) and exercise the changed surface. If the spec says "Save persists notes", click Save and confirm the round-trip. Diff against the design source in `resources/` if one exists and note deviations in the hand-off.

**Integration changes:** if the spec promised "X replaces Y", grep the integration site for both — the new symbol present, the old one absent. An un-integrated predecessor handoff is the RS-64 miss in concrete form; do not ship over it.

### Self-reference grep — run these exactly

```bash
# 1. Every reference to the current ticket — placeholders, TODOs, scaffolded handoffs
git grep -nE '<ISSUE-ID>' -- 'src/' ':(exclude)*.test.*' ':(exclude)*.md'

# 2. Placeholder-shape strings
git grep -nE '501|NOT_IMPLEMENTED|coming soon|placeholder|awaiting|TODO' -- 'src/' ':(exclude)*.test.*'

# 3. Every predecessor ticket ID the spec body names
git grep -nE '<PREDECESSOR-IDS>' -- 'src/' ':(exclude)*.test.*'
```

Substitute the IDs; read the source root from `method.config.md` if it is not `src/`. **Any match outside the files you edited means the integration is not complete.** Either remove the placeholder, or name the match in the hand-off as a known un-integrated site with the reason it is intentional, and let the human decide. A test whose name carries the current ticket's ID pins the pre-ticket world and is an edit target, not a passing check. (rs-vault RS-29, 2026-05-05: a working export route, 763 tests green, and a hardcoded `coming soon (RS-29)` branch left in the UI because this step was prose rather than a command.)

### Risk-fallback follow-up — required when a documented fallback was used

If you shipped a spec's `R<N>: Mitigation` path instead of the primary implementation, file the deferred scope now with `mcp__linear-server__linear_createIssue`: title `<short noun phrase> — closes <ISSUE-ID> R<N> fallback`, state Approved, same project and milestone as the parent, description citing the parent, the `R<N>` clause, the AC numbers covered, and the deferred scope. Reference the new ID in the hand-off, and mark the AC partial in the parent spec if you can edit it. (WIT-451, 2026-05-13: a fallback shipped correctly, two follow-ups were filed by hand, and the third was found in triage a round later.)

### Flag marker for `/verify`

When this step surfaces a self-reference match outside your edits, a UI or integration gap you are shipping with, or an invoked risk fallback, write `.pk-work/<ISSUE-ID>.flags`, one plain line per flag. `/verify` Step 3.5 pauses auto-ship on any line. **Never write an empty marker** — existence means flags present. On `--resume`, overwrite rather than append. `pk done` removes it with the worktree.

### When asked about visible state during execution

If the human asks "is this right?" or "shouldn't there be X here?", re-read the relevant spec section, grep the integration site, compare, and report the gap plainly. A code comment that explains a placeholder as intentional is not evidence when the predecessor's spec promised its replacement (RS-64).

## Step 7 — Auto-rollover to `/verify`

When the last commit lands and the last command exits 0, invoke `/verify` at once by calling the `Skill` tool with `skill="verify"` and `args="--auto-ship"`. Env vars do not cross Bash subshells, so the `args` parameter is the only reliable signal. The human opted into the chain by typing `/work`; they pause it with Ctrl-C, `stop`, or `--no-rollover`.

Exactly two mechanical conditions skip the rollover, and nothing else does: the execution failed (a non-zero exit or a workflow `stopped` status), or `--no-rollover` was passed. Advisory output from Step 6.5, deviations from the spec's wording, and your own uncertainty go into the hand-off, not into a skip. Before ending your turn, check your last paragraph: if it is a hand-off that says `Required next: /verify` after a green run, you skipped on judgment — stop and invoke the Skill tool instead. (Three earlier versions of this skill listed soft skip conditions and the model paraphrased past every one of them.)

After `/verify` returns, surface its verdict block verbatim.

- **Pass:** `pk ship` already ran inside `/verify`. Print: _"Run `/pk-exit` at the end of the session to write `Logs/Sessions/<date>_<HHMM>.md`."_ On Heavy add: _"`/strategy-sync` is required before this initiative closes — run it from the integration branch after this issue merges, typically at `/phase-plan --next`."_
- **Partial / Fail:** stop. Tell the human: _"Address the failures and re-run `/verify` when ready (or `/work --resume` if execution gaps remain)."_

When the rollover is skipped, print:

```
✓ /work paused for <ISSUE-ID>

Reason: <execution-failure | --no-rollover>

Resume:
  /work <ISSUE-ID> --resume   — continue execution
  /verify                     — run the gate manually
```

## Resume

`/work <ISSUE-ID> --resume` skips Steps 3 and 4. Read the PLAN and SUMMARY, mark every task whose SUMMARY row is `done` and whose commit is reachable from HEAD (`git merge-base --is-ancestor <sha> HEAD`) as complete, and launch `pk-execute` with only the remaining tasks and the current HEAD as `baseSha`. It does not rely on the Workflow runtime's cached replay, which is same-session only and assumes nobody committed in between; a human fix between runs is the normal case. Overwrite the SUMMARY with the merged result.

## Failure model

| Failure | Behavior |
|---|---|
| On dev/main/beta at Step 0 with no ID | Refuse: `Run pk branch <ID> first.` |
| Spec missing required sections, no `--deep` | Warn, ask y/N |
| Spec missing required sections, with `--deep` | Refuse; recommend `/light-spec` or `pk delegate` |
| Plan revised more than 3 times | Refuse; recommend `pk delegate` |
| `pk` binary absent | Warn: `pk not found — run /pipekit-update to fix.` |
| `pk-execute` workflow file absent, or `Workflow` tool unavailable | Sequential `Agent` fallback, announced |
| Workflow returns `stopped` | Print the task's result verbatim; stop; no rollover |
| Task agent returns `wrong-base` | Someone moved the branch mid-run; stop and show both shas |
| Integration step fails | Picks stay in place; stop and show the conflicting files or the failing verify |
| Subagent returns a permission denial | Stop, print it, do not retry |
| Tests fail post-execute | Surface; do not auto-fix — that is `/verify`'s job |

## When NOT to use

- No Approved spec — `/light-spec` first. Executing an unapproved spec is guesswork crossing a stage boundary.
- It is a bug — `/pk-bug` has the repro gate and regression-test-first discipline this skill lacks.
- You are in the parent repo — `pk branch <ID>` first.
- Deciding whether or where an issue belongs — `/brainstorm-review` (disposition) or `/linear-hygiene` (placement).

## What this skill does NOT do

- No auto-chain past `/verify`: the human is the chain.
- No PR creation (`pk ship`), no session log (`/pk-exit`), no Linear status writes during work (`pk branch` set In Progress; `pk ship` sets UAT).
- **No `pk done`, ever.** It is a human step after PR merge and interactive UAT, neither of which this skill can observe. A worker session auto-ran it before UAT finished and wiped the worktree mid-test (WIT-451, 2026-05-13).
- **No `pk promote`, ever.** Promotion is a Stage 4 human step from the parent repo after UAT sign-off and merge.
