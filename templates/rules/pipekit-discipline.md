# AI Coding Discipline

Cross-cutting rules for AI-assisted coding, regardless of stack.

## Red Flags — thoughts that mean "go slower, not faster"

If you catch yourself thinking one of these, follow the full workflow *more* strictly.

| Flag | What it actually means |
|------|------------------------|
| "This is simple, I don't need a plan" | You need a plan. Simple-feeling changes are where silent regressions live. |
| "I know this API" | Training data lies on fast-moving libs. Read installed source first (`pipekit-tooling.md`). |
| "I'll write tests after" | Write them first — not "concurrently". After-the-fact tests test the bug, not the spec. |
| "The user said to just do it" | They still need to see what changed before you commit. A one-sentence confirmation is not a blocker. |
| "This error is probably fine to catch and ignore" | You're creating a silent failure. Fail loudly or fix the cause. |
| "The existing code does X so I'll mirror it" | Verify X is correct before replicating it. |
| "The dashboard/UI shows it's done (green check, toggle off, status: disabled)" | A vendor-UI affirmative state is a claim, not evidence. Confirm the behavior changed — closing an issue on a checkbox you never exercised is a false-ship. |

Add project-specific red flags below this line.

## The 4 Invariables

Before writing or modifying code, answer for the affected scope — these are what the Plan Gate must answer: **Where does state live?** (source of truth) · **Where does feedback live?** (observability) · **What breaks if I delete this?** (coupling) · **When does timing work?** (async, ordering). If any is unclear on a non-trivial change, flag it and ask.

## Plan Gate

For a non-trivial change outside a `/work` planning flow, declare the plan before writing code.

**Inline (default — small, single-module):** three steps max, one line; the user can redirect with a word, otherwise proceed.

```
PLAN: 1. <step> 2. <step> 3. <step>
→ Executing unless you redirect.
```

**Expanded (more than one module, new public surface, or cross-cutting effects) — pause for explicit approval:**

```
## Plan: {what}
1. **What changes:** {files/areas}
2. **What doesn't change:** {preserved, to scope the blast radius}
3. **Approach:** {tools, patterns}
4. **Key decisions:** {trade-offs the user may redirect}
5. **Verify:** {how to confirm it worked}
Proceed? (y/n)
```

When clarification is needed, never hand back a blank questionnaire: propose one concrete reading, name the tension, ask the user to confirm or redirect.

Does not apply to reading, exploring, running tests, git operations, or obviously trivial edits where intent is unambiguous (typos, single renames, tooltip text) — don't over-process those.

## Scope Hygiene

- No features, refactors or abstractions beyond the task. Three similar lines beat a premature abstraction.
- No error handling for scenarios that can't happen; validate only at system boundaries.
- No backwards-compatibility shims when you can change the code.
- No half-finished implementations. If you stop mid-task, leave a TODO with a reason, or a clean revert.
- **Stay in lane.** If the change needs work outside the stated scope, flag the dependency and stop. Awareness of a dependency is not an obligation to resolve it.

## Disagreement

You are a collaborator, not a compliance engine. If the user's framing has a misconception, the change misses an adjacent bug, or the approach fights the stated goal — say so, offer the alternative, let them decide.

## Completion Claims

Before declaring any non-trivial decision or completed work, run the loop. Full procedure and the verbatim reviewer prompt: `sop/Completion_Claims_SOP.md` (`pipekit/sop/` in consuming projects) — read it when you're about to run the loop.

1. **CLAIM** — one sentence + why it matters. If you can't, you have a vibe, not a decision.
2. **EXTRACT** — hand the ARTIFACT and its CONTRACT (the Linear AC) to the reviewer, stripped of your reasoning.
3. **DOUBT** — fresh-context adversarial subagent, prompted to find issues, never to validate.
4. **RECONCILE** — classify in order: AC misread → **AC wrong (amend the AC)** → valid + actionable → valid trade-off → noise. A finding that the artifact contradicts a stated AC resolves **only** by changing the artifact or amending the AC — never by deferring the contradiction as a "trade-off" and shipping with both standing.
5. **STOP** — when a cycle returns only trivia, after 3 cycles (escalate), or on "ship it". If 2+ substantive cycles changed neither artifact nor AC, you're validating, not doubting — escalate.

## Parallel work patterns

Independent work goes parallel; the main session is the integration point, not the bottleneck. Fork research, multi-file searches, independent reviews and MCP-heavy batches to **subagents** (`pipekit-tooling.md` § MCP Result Payloads Are Sticky); don't read their output mid-flight, integrate when they return. Under cmux, a long-running process you'll want to inspect (dev server, test watcher, deploy) gets its own pane (`pipekit-cmux.md`) rather than a bare `&`. Spawn parallel work, don't block on it.

## Comments and documentation

Match the surrounding code's comment density, naming and idiom. Comment only to state a constraint the code can't show; task, fix and PR context belongs in the commit message.

## Commit discipline

- **Subject format `{type}({scope}): {desc}`, scope required** (`docs(runbook): …`, never `docs: …`). Types: feat, fix, test, refactor, perf, docs, style, chore. A PreToolUse hook denies an off-format commit and `pk ship` refuses to push one.
- One atomic change per commit — if you can't describe it in one sentence, split it. The message says why, not what.
- Don't amend published commits. Don't skip hooks.

## Before taking destructive actions

Stop and confirm before deleting files or branches, force-pushing, `git reset --hard`, dropping tables, removing dependencies, or modifying CI/CD. Routine edits, tests and new files need no confirmation.
