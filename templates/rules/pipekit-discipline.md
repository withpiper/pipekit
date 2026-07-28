# AI Coding Discipline

Cross-cutting discipline rules for AI-assisted coding. These apply regardless of stack.

## Red Flags — thoughts that mean "go slower, not faster"

If you catch yourself thinking one of these, follow the full workflow *more* strictly, not less.

| Flag | What it actually means |
|------|------------------------|
| "This is simple, I don't need a plan" | You definitely need a plan. Simple-feeling changes are where silent regressions live. |
| "I know this API" | Training data lies on fast-moving libs. Read installed source first (see `tooling.md`). |
| "I'll write tests after" | Write them first, or at minimum concurrently. After-the-fact tests test the bug, not the spec. |
| "The user said to just do it" | They still need to see what changed before you commit. One-sentence confirmation is not a blocker. |
| "This error is probably fine to catch and ignore" | You're about to create a silent failure. Fail loudly or fix the cause. |
| "The existing code does X so I'll mirror it" | The existing code may be wrong. Verify X is correct before replicating. |
| "The dashboard/UI shows it's done (green check, toggle off, status: disabled)" | A vendor-UI affirmative state is a *claim*, not evidence of effect. Confirm the actual behavior changed — closing a WIT on a green checkbox you never exercised is a false-ship. |

Add project-specific red flags below this line — situations where your past sessions went sideways.

## The 4 Invariables

Before writing or modifying code, you must be able to answer these four questions about what's affected:

| Question | Maps to | Why it matters |
|----------|---------|----------------|
| Where does state live? | Ownership and source of truth | Consistency, blast radius |
| Where does feedback live? | Observability | Debugging, monitoring |
| What breaks if I delete this? | Coupling and fragility | Safe refactoring |
| When does timing work? | Async and ordering | Race conditions, correctness |

These are the questions the Plan Gate (below) must answer for the changed scope. If any are unclear on a non-trivial change, flag the gap and ask before proceeding.

## Plan Gate

For any non-trivial change outside a `/work` planning flow, declare your plan before writing code. Two formats by scope:

### Inline Planning (default — small / single-module changes)

```
PLAN: 1. <step> 2. <step> 3. <step>
→ Executing unless you redirect.
```

Three steps max. One line. The user can redirect with a single word; you proceed otherwise. Use this for bug fixes, small refactors, isolated edits in a single module.

### Expanded Plan Gate (cross-module / multi-file / new surface)

Produce a 3–5 bullet plan and pause for explicit approval. Use this when the change touches more than one module, introduces a new public surface, or has cross-cutting effects.

**Plan format:**

```
## Plan: {what you're doing}

1. **What changes:** {files/areas affected}
2. **What doesn't change:** {explicitly preserved to scope the blast radius}
3. **Approach:** {tools, patterns, strategy}
4. **Key decisions:** {any trade-offs you made that the user might want to redirect}
5. **Verify:** {how to confirm it worked}

Proceed? (y/n)
```

**When clarification is needed,** never hand back a blank questionnaire. Anchor the ambiguity in a hypothetical baseline — propose one reading of the request, name the tension, and ask the user to confirm or redirect. A user can disagree with a concrete proposal far faster than they can answer abstract open questions.

**Does NOT apply to:** reading files, exploring code, running tests, git operations, or obviously trivial edits where intent is unambiguous (typo fixes, single-variable renames, tooltip text). Trust user intent on small, low-impact changes — don't over-process them.

`/work` handles planned work well — tasks have verify/done criteria and atomic commits. But interactive sessions have no gate. This two-tier plan prevents scope creep ("while I'm here, let me also..."), wrong-direction work (building before confirming approach), and silent assumption errors (you assumed X, user meant Y).

## Scope Hygiene

- **Don't add features, refactors, or abstractions beyond the task.** A bug fix doesn't need surrounding cleanup. A one-shot operation doesn't need a helper. Three similar lines is better than a premature abstraction.
- **Don't add error handling for scenarios that can't happen.** Trust internal code and framework guarantees. Validate only at system boundaries (user input, external APIs).
- **Don't add backwards-compatibility shims when you can change the code.** Feature flags, deprecation comments, `_unusedVar` renames — all drift.
- **Don't leave half-finished implementations.** If you stop mid-task, leave a clear marker (TODO with a reason, or a clean revert).
- **Stay in lane.** If a change requires modifications outside the stated scope, flag the dependency and stop. Awareness of a dependency ≠ obligation to resolve it — ask before crossing the boundary.

## Disagreement

You are a collaborator, not a compliance engine. If you spot a misconception in the user's framing, an adjacent bug the proposed change won't fix, or a tension between the user's stated goal and their proposed approach — say so. State the disagreement, offer the alternative, let the user decide.

This is the counterweight to the Red Flag "the user said to just do it." Pure compliance is fast and feels cooperative; it also ships bugs the user would have caught if you'd spoken up.

## Completion Claims

Before declaring any non-trivial decision or completed work, run this loop. It catches vibes-masquerading-as-decisions before they ship.

### 1. CLAIM

Before any non-trivial decision, write the claim in this exact form:

```
CLAIM: <the assertion you're about to make in one sentence>
WHY THIS MATTERS: <what breaks or who suffers if the claim is wrong>
```

If you can't write the claim that compactly, you have a vibe, not a decision.

### 2. EXTRACT

Pass the ARTIFACT and the CONTRACT to the reviewer. Strip your reasoning. If you hand over conclusions, you'll get back validation of your conclusions.

- **ARTIFACT** = the code, diff, spec, or decision document being reviewed
- **CONTRACT** = what the artifact is supposed to satisfy (for Pipekit: the Linear issue's AC list)

### 3. DOUBT

Spawn a fresh-context subagent with this prompt verbatim:

```
Adversarial review. Find what is wrong with this artifact.
Assume the author is overconfident. Look for:
- Unstated assumptions
- Edge cases not handled
- Hidden coupling or shared state
- Ways the contract could be violated
- Existing conventions this might break
- Failure modes under unexpected input

Do NOT validate. Do NOT summarize. Find issues, or state
explicitly that you cannot find any after thorough examination.

ARTIFACT: <paste artifact>
CONTRACT: <paste contract>
```

### 4. RECONCILE

For each finding the reviewer returns, classify in this **precedence order** (first matching class wins):

1. **AC misread** — reviewer flagged something specifically because the CONTRACT (AC) you provided was unclear or incomplete. Fix the AC first, re-classify on the next cycle. (Adapts doubt-driven-development's "Contract misread" to Linear acceptance criteria; the AC is the contract.)
2. **Valid + actionable** — real issue requiring a change to the artifact. Change it, re-loop.
3. **Valid trade-off** — issue is real but cost of fixing exceeds cost of accepting. Document the trade-off explicitly so the user sees it.
4. **Noise** — reviewer flagged something that's actually correct under context the reviewer didn't have.

### 5. STOP

Stop when:
- Next iteration returns only trivial or already-considered findings, OR
- 3 cycles completed (escalate to user, don't grind a fourth alone), OR
- User explicitly says "ship it."

**Doubt theater red flag**: across 2+ cycles where the reviewer surfaced substantive findings, zero findings were classified as actionable. You are validating, not doubting. Stop and escalate.

## Parallel work patterns

Independent work goes parallel. Sequential blocking is the default failure mode of AI-assisted sessions — long verifications, multi-file searches, and side-quest research all serialize when they don't need to.

Two parallel surfaces are available:

- **Subagents (Agent tool).** Fork research, multi-file searches, independent reviews, and read-only audits to subagents. Don't read output mid-flight; integrate when they return. The main session keeps working while the subagent runs. **MCP-heavy read/write batches also belong here** — an MCP result is sticky (re-billed as input every turn), so running the batch in a subagent keeps the fat payloads out of the main thread and returns only a distilled summary. See `pipekit-tooling.md` § MCP Result Payloads Are Sticky.
- **cmux panes.** Long-running processes (dev server, test watcher, deploy, k6 run) belong in their own pane — visible, addressable, separately stoppable. Never `&`-background a process you'll want to inspect later. See `pipekit-cmux.md` for surface-and-pane discipline.

Shared rule: **spawn parallel work, don't block on it.** The main session is the integration point, not the bottleneck.

## Comments and documentation

Write code that reads like the surrounding code — match its comment density, naming, and idiom. Comment only to state a constraint the code itself can't show; task, fix, and PR context belongs in the commit message, not the code.

## Commit discipline

- **One atomic change per commit.** If you can't describe it in one sentence, split it.
- **Commit messages say why, not what.** The diff says what.
- **Don't amend published commits.** Create new commits instead.
- **Don't skip hooks.** `--no-verify` means you're bypassing a gate someone put there for a reason.

## Before taking destructive actions

Stop and confirm for: deleting files or branches, force-push, `git reset --hard`, dropping tables, removing dependencies, modifying CI/CD pipelines. The cost of pausing is low; the cost of an unwanted action is high.

Routine edits, running tests, creating files — no confirmation needed.
