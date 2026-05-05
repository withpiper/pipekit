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
- `/work <ISSUE-ID> --backend=vbw|native|auto` — override the project's default backend for this invocation only
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

Read these values from `method.config.md` using the `bin/pk pk_config` binary — do not grep the file directly, as the markdown table format (bold keys, backtick values) is unreliable to parse inline:

```bash
BACKEND=$(bin/pk pk_config "Backend" "vbw")
DEEP_FLAG=$(bin/pk pk_config "Default deep flag" "false")
QA_REVIEW=$(bin/pk pk_config "Require QA review" "false")
STRATEGY_PATH=$(bin/pk pk_config "Strategy docs path" "Strategy/")
```

Resolve the effective `--deep` (CLI flag OR `Default deep flag: true`).

Resolve the effective backend in this order (first match wins):

1. `--backend=vbw`, `--backend=native`, or `--backend=auto` passed on the invocation
2. `Backend` row in `method.config.md` (read via `bin/pk pk_config` above)
3. Default: `vbw`

If `--backend=` is passed with any value other than `vbw`, `native`, or `auto`, refuse: `Unknown backend '<value>'. Valid: vbw, native, auto.`

When the resolved backend is `vbw` or `native`, print one line:

```
Work: <ISSUE-ID>  ·  Backend: <vbw|native>  ·  Deep: <yes|no>
```

When the resolved backend is `auto`, print:

```
Work: <ISSUE-ID>  ·  Backend: auto (routing after plan)  ·  Deep: <yes|no>
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

## Step 2.5 — Label the session and terminal

Now that you have `<ISSUE-ID>` and the issue `title`, label the work in two places so the human can find this session at a glance.

1. **Claude session topic** — set if the helper script exists:

   ```bash
   if [ -x "$HOME/.claude/scripts/set-topic.sh" ]; then
     "$HOME/.claude/scripts/set-topic.sh" "<ISSUE-ID> — <title>"
   fi
   ```

2. **Terminal / multiplexer tab title** — emit the OSC 0 escape (honored by most terminals, tmux, screen, and CMUX):

   ```bash
   printf '\033]0;%s\007' "<ISSUE-ID>"
   ```

Both are best-effort. Skip silently if either fails — never block planning on a labeling failure.

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

## Step 3c — Auto-backend routing (only when `Backend: auto`)

Skip this step entirely if the effective backend is `vbw` or `native`.

After the plan is written, evaluate these three signals from the **Files to touch** section:

| Signal | Check |
|---|---|
| File count | Count entries in "Files to touch" |
| Migration present | Any path matches `*/migrations/*` or ends in `.sql` |
| Unfamiliar package | Any package referenced in the plan is absent from `package.json` (run `node -e "require('./package.json')"` to confirm) |

**Routing decision:**

- If file count ≤ 3 AND no migration AND no unfamiliar package → resolve to `native`
- Any other combination → resolve to `vbw`

Store the resolved backend as the effective backend for Step 5.

Print one line immediately after the plan (before the verdict prompt):

```
Routing: <signal summary> → <native|vbw>
```

Examples:
- `Routing: 2 files, no migration → native`
- `Routing: 7 files → vbw`
- `Routing: migration present → vbw`

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

## Step 6.5 — Behavioral self-check before declaring complete

Before printing the hand-off, verify the work *behaviorally* — not just that tests pass. Tests-pass + 7-check-gate-green is necessary but not sufficient: see RS-63/64 in rs-vault (2026-05-02), where every check passed but the running app was 60% broken.

For UI changes — if the spec touched any user-visible surface:
- **Run the app locally** (or check the existing dev server) and verify the changed surface renders correctly.
- **Click the new affordances.** If the spec says "Save button persists notes," click Save and confirm the data round-trips. Don't trust callback-fire mocks.
- **Diff against the design source** if one exists (`resources/<handoff>/...`). Note any deviations in the hand-off summary.

For integration changes — if the spec promised "X will replace Y" or "this updates Z to consume W":
- **Grep the integration site** to verify the swap landed. Example: if the spec says "wire `<NewComponent>` into `<page.tsx>`", grep for both `<NewComponent>` (should be present) and `<OldComponent>` (should be absent).
- **Don't ship if the predecessor's promised handoff is still un-integrated.** That's the RS-64 miss in concrete form.

If something fails this self-check, **surface it in the hand-off summary** — don't paper over. The user paces; they decide whether to ship-with-known-gap or revise.

### Anti-rationalization guard

If the user asks during execution about visible state — *"is this correct?"*, *"why does it look like this?"*, *"shouldn't there be X here?"* — and provides a screenshot or describes what they see:

**Default behavior: skepticism + verification, not defense.**

1. **Re-read the relevant section of the spec** (don't paraphrase from memory)
2. **Grep the integration site** (don't infer from comments)
3. **Compare what's shown to what the spec says**
4. **Surface any gap honestly**, even if a comment in the code "explains" the current state as intentional (placeholder comments are load-bearing only when the predecessor's spec doesn't promise replacement)

Do **not** generate plausible-sounding rationale that fits the visible artifact. RS-64's miss got worse because Claude pattern-matched on a placeholder comment header and explained the missing integration as "wiring harness for something to come later" — when in fact RS-63's spec said "RS-64 will replace the placeholder." The integration was promised; the comment was misleading; rationalizing made the user trust a broken state.

When in doubt, default to: *"Let me check the spec and the integration site before I answer."*

## Step 7 — Auto-rollover to /verify

Once execution exits successfully — all tasks committed, no aborts, no deviation pending user input — auto-invoke `/verify` immediately. Do not prompt; verification is the deterministic next step in the v2 loop, and `/verify` is idempotent and read-only.

**Skip the rollover** if any of the following holds:

- `/work` was interrupted or aborted mid-execution (Ctrl-C, abort verdict, agent failure)
- A deviation was raised that the user has not yet resolved
- The user's last intent was an explicit stop — a stop signal **the user typed**, not one the agent self-issued. Examples: "stop", "let me check this manually first", "hold on", "wait", "pause", or any `--no-rollover` flag on the original `/work` invocation.

**Do NOT skip** just because Step 6.5 surfaced behavioral or visual gaps. `/verify` is idempotent and read-only — running it does not prevent later human/browser checks. The Step 6.5 gap list is *advisory output*, not a pause signal. Pre-emptively skipping `/verify` because the agent feels cautious adds a manual step against the user's expectation of the v2 loop. If the user wants to pause, they will tell you; the rule is "user-driven stop, not agent-driven stop."

Otherwise:

1. Print: `✓ /work complete for <ISSUE-ID> — auto-running /verify`
2. Invoke `/verify` by calling the Skill tool with `skill="verify"` and `args="--auto-ship"`. The `--auto-ship` arg signals `/verify` that this invocation is part of the auto-flow and authorises `pk ship` on Pass. **Do not** try to set environment variables before invoking — env vars don't propagate across separate Bash subshells, so the only reliable signal is the Skill tool's `args` parameter.
3. Surface `/verify`'s verdict block to the user verbatim.
4. After `/verify` returns:
   - If `/verify` Pass: `pk ship` will already have run inside `/verify`'s rollover (Step 4 below). Print the final hand-off line: _"Run `/pk-exit` at the end of the session to write `Logs/Sessions/<date>_<HHMM>.md`."_
   - If `/verify` Partial / Fail: STOP. The verdict block already showed the per-AC table; do not invoke `pk ship`. Tell the user: _"Address the failures and re-run `/verify` when ready (or `/work --resume` if execution gaps remain)."_

If the rollover is skipped (per the conditions above), fall back to the legacy hand-off:

```
✓ /work paused for <ISSUE-ID>

Resume:
  /work <ISSUE-ID>          — continue execution
  /verify                   — run gate manually if you want to inspect first
```

## Failure model

| Failure | Behavior |
|---|---|
| On dev/main/beta at step 0 | Refuse. Print "Run pk branch <ID> first." |
| Spec missing required sections, no `--deep` | Warn, ask y/N. |
| Spec missing required sections, with `--deep` | Refuse. Recommend `/light-spec` or `pk delegate`. |
| Plan revised >3 times | Refuse. Recommend `pk delegate`. |
| `--backend=` with unknown value | Refuse: `Unknown backend '<value>'. Valid: vbw, native, auto.` |
| `bin/pk pk_config` binary absent | Warn: `bin/pk not found — cannot read Backend from config. Defaulting to vbw. Run /pipekit-update to fix.` |
| Subagent returns permission denial | Stop. Print the denial. Do not retry. |
| Subagent returns ambiguous failure | Print full output. Ask user how to proceed. |
| Tests fail post-execute | Surface. Don't auto-fix — that's `/verify`. |

## What this skill does NOT do

- No tier inference (Quick/Standard/Heavy gone — use `--deep` if you want extra rigor).
- No `--auto` chain (the user is the chain).
- No PR creation (that's `pk ship`).
- No NEXT.md write (NEXT.md doesn't exist in v2).
- No session log write (`/pk-exit` owns the session log).
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
