---
name: verify
description: V2 verify skill — run pre-deploy gate + optional QA review subagent on a feature branch. Returns Pass/Partial/Fail with per-AC table.
---

# /verify

> **North star:** safe and frictionless. Helps, never adds work.

You verify that a feature branch's work is shippable. You run the project's pre-deploy gate (tests, lint, types) and — when configured or invoked with `--qa` — spawn a QA review subagent that checks the diff against the issue's acceptance criteria.

## Triggers

- `/verify` — primary; uses current branch's issue ID
- `/verify <ISSUE-ID>` — explicit
- `/verify --qa` — force QA review even if `Require QA review: false`
- "verify this" / "is this ready to ship?"

## Required preconditions

1. You are inside a worktree on a feature branch (or pass an explicit issue ID).
2. There are committed changes on the branch (else: nothing to verify).
3. `method.config.md` § Pre-Deploy Gate is configured (else `pk verify` exits with a clear "configure your gate" message).

## Step 0 — Verify preconditions

```bash
CURRENT=$(git branch --show-current)
ISSUE="${1:-}"
[ -z "$ISSUE" ] && ISSUE=$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)
[ -z "$ISSUE" ] && { echo "ERROR: pass an issue ID or run on a feature branch." >&2; exit 1; }

# Need at least one commit ahead of integration
INTEGRATION=$(grep -oE 'Integration branch.*\| `[^`]+`' method.config.md | grep -oE '`[^`]+`' | tr -d '`' || echo "dev")
COMMITS_AHEAD=$(git rev-list --count "origin/$INTEGRATION..HEAD" 2>/dev/null || echo 0)
[ "$COMMITS_AHEAD" = "0" ] && { echo "ERROR: no commits ahead of $INTEGRATION — nothing to verify." >&2; exit 1; }
```

## Step 1 — Read configuration

Read from `method.config.md`:

- `Require QA review` (default `false`) — controls whether QA subagent runs by default
- `Backend` (default `vbw`) — used for QA subagent type selection
- `## Pre-Deploy Gate` — bash code block of test/lint/type commands

Resolve `--qa`:
- Explicit `--qa` flag → run QA
- `Require QA review: true` in config → run QA
- Else → skip QA

Print one line:

```
Verify: <ISSUE-ID>  ·  Gate: yes  ·  QA: <yes|no>
```

## Step 2 — Run the pre-deploy gate

Extract the bash block from the config's § Pre-Deploy Gate section. Execute each line. Stream output. Capture exit code per command.

Implementation:

```bash
# Read the bash block between ```bash and ``` after the "## Pre-Deploy Gate" heading
awk '/^## Pre-Deploy Gate/,/^## /' method.config.md | awk '/^```bash/,/^```$/' | grep -v '^```' > /tmp/pk-gate.sh
chmod +x /tmp/pk-gate.sh
bash /tmp/pk-gate.sh
GATE_RC=$?
```

If `GATE_RC != 0`:

```
✗ Pre-deploy gate FAILED.

The first failing command's last 30 lines:
<output>

Next: fix the gate failure, then re-run /verify (idempotent).
```

Stop. Do **not** run QA review on a failed gate.

If `GATE_RC == 0`, print:

```
✓ Pre-deploy gate PASSED (<command list>).
```

Continue to step 3 only if QA is enabled.

## Step 3 — QA review subagent (if QA enabled)

### Step 3a — Fetch the spec for AC reference

Use Linear MCP `mcp__linear-server__get_issue` with `<ISSUE-ID>`. Capture the full description.

### Step 3b — Compute the diff

```bash
INTEGRATION=$(grep -oE 'Integration branch.*\| `[^`]+`' method.config.md | grep -oE '`[^`]+`' | tr -d '`' || echo "dev")
git diff --stat "origin/$INTEGRATION...HEAD"
git diff "origin/$INTEGRATION...HEAD"
```

### Step 3c — Spawn the QA subagent

Backend-pluggable:

- **vbw** backend: use `subagent_type: "vbw:vbw-qa"` (project must have VBW installed)
- **native** backend: use `subagent_type: "general-purpose"`

Use Task tool with:

- `description: "QA review of <ISSUE-ID>"`
- Prompt template:
  ```
  You are a QA reviewer doing goal-backward verification.

  Linear issue: <ISSUE-ID>
  Branch: <CURRENT>

  Spec (from Linear):
  <full description from step 3a>

  Diff (relative to origin/<INTEGRATION>):
  <output of git diff --stat>
  <output of git diff>

  Your job:
  1. Read the spec's Acceptance Criteria.
  2. Walk each AC. For each, find the diff line(s) that fulfills it. If you cannot find one, the AC is unmet.
  3. Look for things the spec REQUIRED but the diff DOESN'T touch (omissions).
  4. Look for things the diff DID that the spec didn't authorize (scope creep).
  5. Note any obvious bugs you can see (logic errors, missing null checks in financial math, RLS bypasses).

  Return verdict in this exact format:

  **Verdict:** Pass | Partial | Fail
  **Reasoning:** <2–4 sentences>

  **Per-AC table:**
  | # | AC summary | Status | Evidence |
  |---|---|---|---|
  | 1 | <text> | Met / Unmet / Partial | <file:line or "no change found"> |

  **Omissions:** <list of spec requirements not addressed in diff, or "none">

  **Scope creep:** <list of diff changes not authorized by spec, or "none">

  **Bugs noticed:** <list of obvious bugs, or "none observed">

  Verdict rules:
  - Pass — every AC has Met evidence; no omissions; no significant scope creep; no bugs noticed
  - Partial — most ACs Met but specific gaps exist (Partial ACs allowed; minor scope creep allowed if defensible)
  - Fail — fundamental ACs Unmet, OR scope creep significant enough to block ship, OR bugs noticed
  ```

Wait for the subagent to return. Print its verdict block verbatim — no editorializing.

## Step 4 — Hand off

Based on verdict, print the next-action:

| Verdict | Next |
|---|---|
| Pass (gate only) | `pk ship` |
| Pass (gate + QA) | `pk ship` |
| Partial | Read the per-AC table. Decide: amend with `/work` (if gap is real), or ship anyway with `git commit --amend` documenting the gap. Then `pk ship`. |
| Fail (gate) | Fix the failing command, then re-run `/verify` (idempotent). |
| Fail (QA) | Stop. Either: expand `/work <ID>` to address Unmet ACs; OR `pk delegate <ID> "the spec needs <X>"` to refine spec; OR override consciously with documented decision. |

Do **not** auto-ship on Pass. The user runs `pk ship` when ready.

## Failure model

| Failure | Behavior |
|---|---|
| No commits ahead of integration | Refuse with clear message. |
| Pre-Deploy Gate not configured | Print: "Configure § Pre-Deploy Gate in method.config.md, then re-run." |
| Gate command fails | Stop. Print failing command + last 30 lines. Don't run QA. |
| QA subagent type missing (e.g., `vbw:vbw-qa` not installed) | Fall back to `general-purpose`. Warn. |
| Spec has no AC | QA subagent should report "AC missing" as Fail; user gets clear next-action. |

## What this skill does NOT do

- No session-log writes — `/pk-exit` owns the session log.
- No Linear status updates — `pk ship` and `pk done` post the necessary ones.
- No PR creation — `pk ship` is separate.
- No re-running of failed tests — fix and re-invoke (idempotent).

## Comparison with v1

| Concern | v1 (`/vbw:vibe --verify`) | v2 (`/verify`) |
|---|---|---|
| Always-runs-QA | Yes (built into VBW vibe) | Config-gated (`Require QA review`) |
| Pre-deploy gate | Separate (`pnpm <gate>`) | Built in (reads § Pre-Deploy Gate) |
| Backend | VBW only | `vbw \| native` per config |
| Output format | VBW-shaped JSON | Markdown verdict block |
| AC traceability | Implicit | Explicit per-AC table |
