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

1. Either (a) you are inside a worktree on a feature branch (not `dev`, `main`, `beta`, or `master`), OR (b) `<ISSUE-ID>` is passed as an argument so `/work` can auto-branch into a fresh worktree.
2. If neither (a) nor (b) holds, refuse.
3. `method.config.md` is readable in the repo root.

## Step 0 — Verify or create the worktree

`/work` auto-branches when invoked from an integration branch with an explicit `<ISSUE-ID>` — creating worktree + branch via `pk branch` and `cd`-ing into it before continuing. This removes the manual `pk branch` step that v2.0–v2.2 required.

```bash
CURRENT=$(git branch --show-current)

case "$CURRENT" in
  dev|main|master|beta)
    # Integration branch — auto-branch path.
    if [ -z "$1" ]; then
      echo "ERROR: /work invoked from integration branch '$CURRENT' with no <ISSUE-ID>." >&2
      echo "Pass an ID (e.g. /work RS-123) or run 'pk branch <ID>' yourself first." >&2
      exit 1
    fi
    ISSUE="$1"
    echo "→ Auto-branching: pk branch $ISSUE"
    pk branch "$ISSUE" || { echo "ERROR: pk branch failed for $ISSUE" >&2; exit 1; }
    # pk branch creates the worktree and prints its path on the last line.
    # Resolve and cd into it so the rest of /work runs in the right place.
    WORKTREE=$(git worktree list --porcelain | awk -v id="$ISSUE" '
      /^worktree / { wt=$2 }
      /^branch / && index($0, id) { print wt; exit }
    ')
    [ -z "$WORKTREE" ] && { echo "ERROR: could not locate worktree for $ISSUE" >&2; exit 1; }
    cd "$WORKTREE" || exit 1
    CURRENT=$(git branch --show-current)
    ;;
esac
```

If `<ISSUE-ID>` not passed and `$CURRENT` is a feature branch, extract from `$CURRENT`:

```bash
ISSUE=${ISSUE:-$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)}
[ -z "$ISSUE" ] && { echo "ERROR: no issue ID in branch name and none provided." >&2; exit 1; }
```

## Step 1 — Read configuration

Read these values from `method.config.md` using `pk config <key> [default]` — do not grep the file directly, as the markdown table format (bold keys, backtick values) is unreliable to parse inline. (`pk_config` is the internal shell function inside `bin/pk`; the subcommand exposed to skill bodies is `pk config`. Using `bin/pk pk_config` would exit 1 with "Unknown subcommand: pk_config" — surfaced 2026-05-14 canary, fixed v2.4.3.3.)

```bash
BACKEND=$(pk config "Backend" "vbw")
DEEP_FLAG=$(pk config "Default deep flag" "false")
QA_REVIEW=$(pk config "Require QA review" "false")
STRATEGY_PATH=$(pk config "Strategy docs path" "Strategy/")
```

Resolve the effective `--deep` (CLI flag OR `Default deep flag: true`).

Resolve the effective backend in this order (first match wins):

1. `--backend=vbw`, `--backend=native`, or `--backend=auto` passed on the invocation
2. `Backend` row in `method.config.md` (read via `pk config` above)
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
- `state.name` (expected: `In Progress` or `Building`. `Approved` is also fine — Step 0's auto-branch will have transitioned it. If `Backlog`/`Todo` and Step 0 did not just auto-branch, refuse.)
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

### Test command discipline (applies to every execute path)

If the spec's Acceptance Criteria names a specific test command verbatim — e.g., `pnpm turbo run test --filter=@piper/web` — **use that command verbatim before improvising.** Spec-stated commands are pre-tested and known to work; ad-hoc invocations (`pnpm vitest run <path>`, `pnpm <pkg> test <abs-path>`, etc.) routinely cost two-to-three retries while you re-discover package-script naming, monorepo path conventions, and filter syntax. Surfaced 2026-05-14 canary (F7); fixed v2.4.3.3.

If the AC doesn't name a test command, fall back to the project's § Pre-Deploy Gate in `method.config.md`.

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

### Self-reference grep — RUN THESE EXACTLY (do not paraphrase)

Before printing the hand-off, run **all three** of the following commands and surface every match in the hand-off summary. Do not skip, summarize, or "trust" the spec instead. Predecessors leave placeholder branches that the spec cannot enumerate; the only reliable way to find them is to grep your own ticket ID in the codebase.

```bash
# 1. Every reference to the current ticket — placeholders, TODOs, scaffolded handoffs
git grep -nE '<ISSUE-ID>' -- 'src/' ':(exclude)*.test.*' ':(exclude)*.md'

# 2. Placeholder-shape strings — coming soon, NOT_IMPLEMENTED, 501, awaiting, TODO
git grep -nE '501|NOT_IMPLEMENTED|coming soon|placeholder|awaiting|TODO' -- 'src/' ':(exclude)*.test.*'

# 3. Every reference to predecessor ticket IDs called out in the spec body
git grep -nE '<PREDECESSOR-IDS>' -- 'src/' ':(exclude)*.test.*'
```

(Substitute `<ISSUE-ID>` with the current ticket ID, e.g. `RS-29`; substitute `<PREDECESSOR-IDS>` with any ticket IDs the spec body references in `<issue id=…>` blocks or "RS-NN will replace…" prose. Adjust the path scope from `src/` to whatever the project's source root is — read it from `method.config.md` if needed.)

**Rule: if any match exists *outside* the file you just edited, you have not completed the integration. Do not declare complete.** Either:
1. Make the change to remove the placeholder/integration site, or
2. Surface the match explicitly in the hand-off summary as a known un-integrated site, name *why* it's intentional to leave it, and let the user decide.

Why this is mandatory: RS-29 (rs-vault, 2026-05-05) shipped a working JPG export route, all 763 tests passing, full pre-deploy gate green, Vercel preview returning valid bytes — but the report builder UI still had a hardcoded `if (res.status === 501) /* show "coming soon (RS-29)" */` branch from RS-27. The placeholder hint literally said "until RS-29 ships" and `/work` missed it because Step 6.5 was prose, not a command. A single `git grep -n RS-29 src/` would have surfaced the integration site in 30 seconds.

### Pinned-broken-behavior tests

Tests whose names contain the *current* ticket's ID — especially predecessor tests that asserted the placeholder behavior was correct — are **almost always known-edit targets**, not bystanders. A green test for a placeholder is a TODO disguised as a check. When grep #1 above surfaces test names, do not read "the test passes" as confirmation; read it as "the test pins the world before this ticket shipped, and ought to be updated to assert the new behavior."

### Risk-fallback follow-up filing — MANDATORY when a Risk-fallback was invoked

If you used a documented Risk-fallback (`R<N>: Mitigation` clause from the spec body) during this run — i.e. you shipped the documented "if X is too hard, do Y instead" path — you MUST file the deferred work as a new Linear WIT before declaring complete. Do not bundle it into the hand-off summary as a "partial AC" footnote and hope the user files it later; they won't, and the follow-up rots.

For each invoked fallback:

1. Identify the AC the fallback covers and the deferred scope (the "proper" implementation the fallback is standing in for).
2. Call `mcp__claude_ai_Linear__save_issue` to file a new WIT, scoped tightly to closing the fallback:
   - **Title:** `<short noun phrase> — closes <ISSUE-ID> R<N> fallback`
   - **State:** `Approved` (the design decisions are inherited from the original spec; the new WIT is execution-only)
   - **Description:** Cite the parent ISSUE-ID + the specific R<N> clause + the AC numbers the fallback covers + the deferred scope spelled out
   - **Project / Milestone:** Match the parent issue
3. Reference the new WIT-ID in the hand-off summary.
4. Update the original spec body (if you have permission to edit it post-implementation) to mark the AC as "partial per R<N>; full coverage tracked in <NEW-WIT-ID>".

Why mandatory: WIT-451 canary 2026-05-13 shipped via the R4 documented fallback (NOTE editable only via Edit modal, not inline). The session correctly used the fallback but only filed 2 follow-up WITs and missed the dual-field inline editor; that one was caught later in triage. If R-fallback follow-ups had been automatic, the canary closeout would have been one round faster.

If something fails this self-check, **surface it in the hand-off summary** — don't paper over. The user paces; they decide whether to ship-with-known-gap or revise.

### Cross-skill flag marker (F6 — load-bearing for /verify Step 3.5)

When this Step 6.5 surfaces *any* of the following, you MUST also write a flag marker file so `/verify` can pause the auto-ship chain:

- Self-reference grep #1, #2, or #3 returned a match outside the file you just edited
- Behavioral self-check found a UI/integration gap and you're shipping anyway with the gap documented
- A documented Risk-fallback was invoked during this run (the same trigger as the mandatory follow-up WIT)

Write the marker as `.pk-work/<ISSUE-ID>.flags`, one human-readable line per flag:

```bash
mkdir -p .pk-work
{
  # one line per surfaced flag — examples:
  echo "self-ref match: <FILE:LINE> contains '<ISSUE-ID>' outside edited file"
  echo "behavioral gap: <component> renders but <affordance> not wired (shipping with gap)"
  echo "risk-fallback R<N> invoked: <deferred scope> — follow-up WIT <NEW-WIT-ID>"
} > .pk-work/${ISSUE_ID}.flags
```

`.pk-work/` is gitignored at the repo root (see `.gitignore`). Marker is per-issue so concurrent worktrees on different issues don't collide. `/verify` reads this file in its Step 3.5 flag enumeration and pauses auto-ship if any line is present.

**Do not write an empty marker** — `/verify` treats file existence as "flags present." If Step 6.5 found nothing surface-worthy, do not create the file.

**Marker lifecycle:** the file is consumed by `/verify` (read-only) and cleaned up by `pk done` when the worktree is removed. If you re-run `/work --resume <ISSUE-ID>`, overwrite the marker — don't append to a stale one.

### Anti-rationalization guard

If the user asks during execution about visible state — *"is this correct?"*, *"why does it look like this?"*, *"shouldn't there be X here?"* — and provides a screenshot or describes what they see:

**Default behavior: skepticism + verification, not defense.**

1. **Re-read the relevant section of the spec** (don't paraphrase from memory)
2. **Grep the integration site** (don't infer from comments)
3. **Compare what's shown to what the spec says**
4. **Surface any gap honestly**, even if a comment in the code "explains" the current state as intentional (placeholder comments are load-bearing only when the predecessor's spec doesn't promise replacement)

Do **not** generate plausible-sounding rationale that fits the visible artifact. RS-64's miss got worse because Claude pattern-matched on a placeholder comment header and explained the missing integration as "wiring harness for something to come later" — when in fact RS-63's spec said "RS-64 will replace the placeholder." The integration was promised; the comment was misleading; rationalizing made the user trust a broken state.

When in doubt, default to: *"Let me check the spec and the integration site before I answer."*

## Step 7 — Auto-rollover to /verify (mandatory)

**Rollover is mandatory.** When Step 6 finishes — last commit lands, last shell command exits 0 — invoke `/verify` immediately. Do not deliberate. Do not weigh whether the user "might want" to inspect first. Do not interpret implementation notes, Step 6.5 advisory output, or surfaced deviations as a pause signal. The user opted into the chain by typing `/work`; they will type Ctrl-C, `stop`, or pass `--no-rollover` if they want to pause.

This rule exists because three prior versions of this skill listed soft skip conditions ("explicit stop", "deviation pending user input", "behavioral gap surfaced") and the model paraphrased past every one of them — turning the v2 loop into a manual chain. Rollover is the loop. If you skip it on agent judgment, you broke the loop.

### Mechanical skip conditions (the only ones)

Skip rollover only when **a deterministic, non-judgmental signal** holds. There are exactly two:

1. **Execution failed.** The last shell command in Step 6 exited non-zero, or a Bash tool call returned an error you could not auto-recover. This is checkable: `if (last_exit_code != 0)`. No interpretation.
2. **`--no-rollover` flag.** Passed on the original `/work <ISSUE-ID> --no-rollover` invocation. The user said "build but don't auto-verify." This is checkable: scan the invocation args.

Nothing else skips. Not "the user might want to inspect." Not "implementation deviated from spec wording." Not "Step 6.5 listed gaps." Not "I'm uncertain." Those produce *advisory output in the hand-off summary*, not skips.

### Procedure

1. Print: `✓ /work complete for <ISSUE-ID> — auto-running /verify`
2. Invoke `/verify` by calling the Skill tool with `skill="verify"` and `args="--auto-ship"`. The `--auto-ship` arg signals `/verify` that this invocation is part of the auto-flow and authorises `pk ship` on Pass. **Do not** try to set environment variables before invoking — env vars don't propagate across separate Bash subshells, so the only reliable signal is the Skill tool's `args` parameter.
3. Surface `/verify`'s verdict block to the user verbatim.
4. After `/verify` returns:
   - **Pass:** `pk ship` will already have run inside `/verify`'s rollover. Print: _"Run `/pk-exit` at the end of the session to write `Logs/Sessions/<date>_<HHMM>.md`."_
   - **Partial / Fail:** STOP. The verdict block already showed the per-AC table; do not invoke `pk ship`. Tell the user: _"Address the failures and re-run `/verify` when ready (or `/work --resume` if execution gaps remain)."_

### When the rollover IS skipped (one of the two mechanical conditions)

Print the legacy hand-off:

```
✓ /work paused for <ISSUE-ID>

Reason: <execution-failure | --no-rollover>

Resume:
  /work <ISSUE-ID>          — continue execution
  /verify                   — run gate manually if you want to inspect first
```

### Self-check before declaring complete

Before printing the hand-off, ask yourself: "Did the last shell command exit 0?" If yes, **the rollover MUST run.** If you find yourself drafting a hand-off with `Required next: /verify` (the legacy form) when execution succeeded, **stop and invoke the Skill tool instead.** That hand-off line is reserved for the mechanical-skip case. Printing it after a green run means you skipped on judgment, which is forbidden.

## Failure model

| Failure | Behavior |
|---|---|
| On dev/main/beta at step 0 | Refuse. Print "Run pk branch <ID> first." |
| Spec missing required sections, no `--deep` | Warn, ask y/N. |
| Spec missing required sections, with `--deep` | Refuse. Recommend `/light-spec` or `pk delegate`. |
| Plan revised >3 times | Refuse. Recommend `pk delegate`. |
| `--backend=` with unknown value | Refuse: `Unknown backend '<value>'. Valid: vbw, native, auto.` |
| `pk` (or `bin/pk`) binary absent | Warn: `pk not found — cannot read Backend from config. Defaulting to vbw. Run /pipekit-update to fix.` |
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
- **No `pk done` invocation, ever.** `pk done` is a deliberate human step after PR merge AND interactive UAT — neither of which `/work` has signal for. The WIT-451 canary 2026-05-13 surfaced this: a worker session auto-ran `pk done` before the human finished UAT and wiped the worktree mid-test. Stage 3's UAT gate is non-skippable from inside this skill. If you complete an auto-rollover successfully, the hand-off line ends at `/pk-exit`, never at `pk done`.
- **No `pk promote` invocation, ever.** Same rationale — promotion is a Stage 4 human step that runs from the parent repo after the user has signed off on UAT and merged. A worker session has no business advancing the workflow past its own scope.

## Comparison with v1

| Concern | v1 (`/launch --auto`) | v2 (`/work`) |
|---|---|---|
| Lines of skill prose | 765 | ~330 |
| Tier system | Quick/Standard/Heavy | None (`--deep` flag) |
| Verdict loop | 3 rounds + stalemate detection | 1 screen, 3 options, 3-revision hard limit |
| Backend | VBW only | `vbw \| native` per config |
| Auto-chain | Yes (4 hidden agent invocations) | No (user paces) |
| State writes | Linear (twice), VBW STATE.md, pipeline-state JSON | None (read-only) |
