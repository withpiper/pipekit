---
name: verify
description: V2 verify skill — run tests + QA review subagent on a feature branch. Returns Pass/Partial/Fail.
---

# /verify

> **North star:** safe and frictionless. Helps, never adds work.

You verify that a feature branch's work is shippable. You run the project's pre-deploy gate (tests, lint, types) and — when configured — spawn a QA review subagent that checks the diff against the issue's acceptance criteria.

## Triggers

- `/verify` — primary
- `/verify <ISSUE-ID>` — if not on a feature branch, target a specific issue (rare)
- "verify this" / "is this ready to ship?"

## Required preconditions

1. You are inside a worktree on a feature branch (or pass an explicit issue ID).
2. There are committed changes on the branch (else: nothing to verify).
3. `method.config.md` § Pre-Deploy Gate is configured (or `pk verify` has nothing to run).

## Step 1 — Read configuration

Read from `method.config.md`:

- `Require QA review: true | false` (default `false`) — controls whether the QA subagent runs by default
- `## Pre-Deploy Gate` — the bash block of test/lint/type commands

Resolve issue ID:
- If invoked with an explicit ID, use it.
- Else extract from `pk_branch_issue_id` (current branch name).
- If neither, refuse with: "Run on a feature branch or pass `<ID>` explicitly."

## Step 2 — Run the pre-deploy gate

Run the commands from § Pre-Deploy Gate. Stream output. If any command exits non-zero:

- Print **Fail (gate)**: which command + first 20 lines of output.
- Stop. Do not run QA review.

If all gates pass, continue.

## Step 3 — QA review (if required)

If `Require QA review: true` OR called with `--qa`:

Spawn a Task subagent (`general-purpose` for native; `vbw:vbw-qa` for vbw backend per `Backend` config) with this prompt:

```
You are a QA reviewer. The branch <branch-name> implements Linear issue <ID>.

Spec (from Linear): <paste full spec body>

Diff (relative to integration branch):
<output of: git diff origin/<integration>...HEAD>

Your job — goal-backward verification:
1. Read the acceptance criteria from the spec.
2. Walk each AC. For each, find the code change that fulfills it. If you can't find one, that AC is unmet.
3. Look for things the spec REQUIRED but the diff DOESN'T touch (omissions).
4. Look for things the diff DID that the spec didn't authorize (scope creep).

Return a verdict:
- Pass — every AC has a corresponding change; no omissions; no significant scope creep.
- Partial — most ACs met but specific issues found. List them.
- Fail — fundamental ACs unmet, or scope creep significant enough to block ship.

Format:
**Verdict:** Pass | Partial | Fail
**Reasoning:** <2–4 sentences>
**Per-AC table:** | AC | Status | Evidence (file:line) |
**Omissions:** <list or "none">
**Scope creep:** <list or "none">
```

Wait for the subagent to return. Print its verdict block verbatim.

## Step 4 — Hand off

Print one-line next-action depending on verdict:

| Verdict | Next |
|---|---|
| Pass (gate only, no QA) | Run `pk ship` |
| Pass (with QA) | Run `pk ship` |
| Partial | Read the per-AC table. Decide: amend the work (back to `/work`), or accept the gap (document in commit + ship). |
| Fail (gate) | Fix the gate issue, then re-run `/verify`. |
| Fail (QA) | Stop. Either expand `/work` to address ACs, or revise the spec (`pk delegate`) and start over. |

Do **not** auto-ship on Pass. The user runs `pk ship` when ready.

## What this skill does NOT do

- No `/end-session` writes — Stop hook owns the journal.
- No Linear comments — `pk ship` and `pk done` post the necessary ones.
- No round-2 verdict loop — one verdict, one decision.
- No PR creation.

## Comparison with v1

| Concern | v1 (`/vbw:vibe --verify`) | v2 (`/verify`) |
|---|---|---|
| Always-runs-QA | Yes (built into VBW vibe) | Config-gated (`Require QA review`) |
| Pre-deploy gate | Separate (`pnpm <gate>`) | Built in (reads § Pre-Deploy Gate) |
| Backend | VBW only | `vbw \| native` per config |
| Output format | VBW-shaped JSON | Markdown verdict block |
