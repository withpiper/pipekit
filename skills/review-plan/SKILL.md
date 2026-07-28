---
name: review-plan
description: Run plan-reviewer agent against a PLAN.md before execution. Use after /work plan phase and before approving execution. Use when you need an independent gate catching scope drift, atomicity failures, test gaps. Requires a fresh chat.
---

# Review Plan Skill

> **Fresh-chat check.** If this conversation drafted the plan (e.g. ran `/work`'s planning phase) or watched it get drafted, start a new conversation. The reviewer must be independent of the planner. See `method.md` § Fresh-Chat Discipline.

You are a plan-review coordinator. Your job is to invoke the `plan-reviewer` agent against a `PLAN.md` before execution, present the structured review back to the user, and recommend a path forward (proceed to execute, route back for plan revision, or escalate). The plan comes from `/work`'s inline planning, filed at `.pk-work/<ID>-PLAN.md` (native-on-Workflow is the sole executor as of v4.0.0).

This skill is Pipekit's plan-review gate — an independent stress-test between planning and execution. Native `/work` runs per-task verify-before-integrate, which is its own plan-safety mechanism, so upfront review matters most when a plan is **large or high-risk** — reach for `/review-plan` against `.pk-work/<ID>-PLAN.md` before kicking off execution in those cases.

## Triggers

- `/review-plan PROJ-XXX` — review the plan `/work` filed at `.pk-work/PROJ-XXX-PLAN.md`
- `/review-plan` — auto-detect the most recent plan
- `/review-plan {phase-slug}` — legacy fallback: review a named phase under `.vbw-planning/phases/` (un-migrated projects)
- "review the plan", "run plan-reviewer"

## Purpose

`/work`'s inline planning covers structural correctness (requirements coverage, circular deps, same-wave file conflicts, task counts, skill refs). It cannot see:

- **Scope drift** vs the approved spec
- **Framing errors** (solving the wrong problem)
- **Confirmation bias** in the planner's own judgment calls
- **Atomicity failures** between same-wave tasks
- **Test meaningfulness** — verify steps that say "tests pass" without naming what
- **Domain risk coverage** — RLS bypass traps, migration ordering, JWT scoping
- **Strategic fit** with future-phase plans

The `plan-reviewer` agent fills that gap. This skill orchestrates the call.

## Prerequisites

- A `PLAN.md` to review. With native `/work` the plan is filed at `.pk-work/<ID>-PLAN.md` — point this skill at that path. (Legacy VBW-planned phases keep `PLAN.md` under `.vbw-planning/phases/{phase-slug}/`; this skill still reviews those.)
- The approved Light Spec is available — either as the description of a Linear issue tied to the current branch, or readable from a known location
- `.claude/agents/plan-reviewer.md` is installed (Pipekit ships this; if missing, run `bash scripts/sync-method.sh`)

## Execution Steps

### Step 1 — Resolve the plan path

Determine which plan(s) to review:

1. **Linear issue ID** (`/review-plan PROJ-123`) — native `/work` files the plan at `.pk-work/<ID>-PLAN.md`; point this skill there. Resolve the ID from the current git branch (`feature/proj-123-*`) when not passed explicitly.
2. **Explicit phase slug** (`/review-plan phase-1-data-foundation`) — legacy fallback for un-migrated projects whose plans still live under `.vbw-planning/phases/{phase-slug}/`; use directly.
3. **No argument** — auto-detect: look for a recent `.pk-work/<ID>-PLAN.md`; if none and a legacy `.vbw-planning/STATE.md` exists, read it for the active phase. If ambiguous, list plans with no review and ask the user to pick.

For the native path, the plan is a single file:

```bash
ls .pk-work/<ISSUE-ID>-PLAN.md
```

For the legacy-fallback path, find every `*-PLAN.md` in the phase dir:

```bash
ls .vbw-planning/phases/{phase-slug}/*-PLAN.md
```

If a legacy phase dir uses a non-flat layout (e.g., nested `rs-N-slug/PLAN.md`), still find every `PLAN.md` in the dir tree and pass the list to the agent — the agent reviews plan content, not filename structure.

### Step 2 — Resolve the approved spec

The plan-reviewer agent compares the plan against the approved spec. Find the spec via this priority:

1. **Linear issue tied to current branch** — extract `PROJ-XXX` from `git branch --show-current` (matches `feature/proj-xxx-*`, `fix/proj-xxx-*`, `hotfix/proj-xxx-*`); fetch via `mcp__linear-server__linear_getIssueById` with `includeRelations: true`; extract the `## Light Spec` and `## Acceptance Criteria` (or equivalent) sections from the description
2. **User provides issue ID** — same fetch path with the explicit ID
3. **No Linear context** — ask the user to paste the approved spec, or provide a path to a local spec file

The full spec text passes to the agent verbatim. Do not summarize.

### Step 3 — Verify plan-reviewer agent is installed

```bash
test -f .claude/agents/plan-reviewer.md && echo "installed" || echo "missing"
```

If missing, surface a clear message and offer to sync:

```
plan-reviewer agent not found at .claude/agents/plan-reviewer.md.
Run `bash scripts/sync-method.sh` to install canonical Pipekit agents,
or manually copy from your Pipekit checkout (templates/agents/plan-reviewer.md
in older syncs, agents/plan-reviewer.md in current).

Falling back to direct presentation: I'll show the PLAN.md structure
and let you review manually.
```

### Step 4 — Spawn the plan-reviewer agent

Use the Agent tool with `subagent_type: "plan-reviewer"`. Pin the **plan-review / adversarial** tier per `method.config.md § Model Policy` (default `opus`, effort `xhigh`) — review has to catch what planning missed; give it at least the reasoning budget planning had.

```
Agent(
  subagent_type: "plan-reviewer",
  model: "{plan-review tier — default opus}",
  description: "Review {phase-slug} plan",
  prompt: "Independent review of the plan(s) for {phase-slug} before execution.

  Plan path(s):
    {list of *-PLAN.md absolute paths}

  Approved spec (verbatim from {Linear PROJ-XXX | local spec file}):
  <<<SPEC
  {full Light Spec + Acceptance Criteria from the issue description}
  SPEC

  Project context:
  - CLAUDE.md at repo root
  - method.config.md at repo root
  - .vbw-planning/PHASES.md (legacy fallback, if present)
  - .vbw-planning/codebase/CONCERNS.md (legacy fallback, if present)

  Follow the Review Protocol in your agent definition. Return the
  structured markdown output (Verdict / Readiness Score / Blocking Issues
  / Non-Blocking Improvements / Scope Fidelity / Atomicity / Testability
  / Risk Coverage / Fast Path to Pass / Final Recommendation).

  If you return Block or Revise, the orchestrator will relay your
  Fast Path to Pass items back to the user; do not attempt to rewrite
  the plan yourself."
)
```

### Step 5 — Present the review verdict

Display the agent's structured output verbatim, then add a one-line summary line at the top so the user can scan the verdict in one beat:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan Review Verdict: {Pass | Revise | Block} — {Readiness Score}/10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{full agent output below this line}
```

### Step 6 — Recommend a path forward

Based on the verdict:

| Verdict | Recommendation |
|---------|----------------|
| **Pass** | "Plan is execution-safe. Proceed to execution when ready." |
| **Revise** (non-blocking only) | "Plan can proceed but here are improvements to apply during execution: {list}. Proceed to execution when you've decided which to address." |
| **Block** | "Do not execute. Re-run `/work`'s planning to address the Fast Path items, or amend the spec via `/02-light-spec-revise PROJ-XXX` if scope/framing is wrong. Specifically: {list of blocking issues}." |

Always quote the agent's own Fast Path to Pass section verbatim — those are the concrete moves the user has to make.

### Step 7 — Next-step output

Emit an inline `➜ Next:` line in your terminal output. Pointer logic:

- **Pass** → proceed to execution (`/work`)
- **Revise** → proceed to execution (`/work`) (with note about non-blocking improvements)
- **Block** → re-plan via `/work` (if plan-revise scope) or `/02-light-spec-revise PROJ-XXX` (if spec/framing scope)

Do **not** write a `NEXT.md` file — v2 retired the mirror; `pk next` reads "what's next?" live from Linear.

### Step 8 — Pipeline state file

After the verdict is delivered, resolve `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)`, `mkdir -p "$STATE_DIR/pipeline-state"`, and write `$STATE_DIR/pipeline-state/<issue-id>.json` per the SOP schema (`stage: "review-plan"`, verdict, cwd, timestamp). Issue ID resolution mirrors Step 2's spec resolution; if no Linear ID, use the phase slug. The path is out-of-repo so no hook block; write should always succeed.

---

## Red Flags

Thoughts that mean "slow down on the review." Paired with `.claude/rules/pipekit-discipline.md` for the portable set.

| Flag | What it actually means |
|------|------------------------|
| "The plan is small, skip the review" | Small plans hide framing errors most easily — there's less surface for Lead's self-review to catch issues. Run review regardless. |
| "The plan was already self-reviewed, that's enough" | `/work`'s planning covers structural correctness only. The class of errors plan-reviewer catches (scope drift, atomicity, test meaningfulness) is structurally invisible to the planner. Don't conflate. |
| "I'll just eyeball it myself" | Probably you'll catch the same things the planner missed — confirmation bias works on humans too. The agent is a fresh pair of eyes. |
| "The spec was clear so the plan must be right" | Spec clarity doesn't guarantee plan fidelity. The planner can correctly understand a spec and still produce a plan that quietly expands scope. |
| "Block verdict but the issue seems minor" | Blocking issues are blocking by definition. If you disagree, push back on the plan-reviewer agent's framing — don't override the verdict. |

---

## Common Drifts to Avoid

- **Skipping the spec resolution** → reviewing a plan without the approved spec means the agent can't catch scope drift. Always pass the spec verbatim.
- **Summarizing the spec for the agent** → the agent needs the AC section as written. Summary loses the testable conditions.
- **Running review against partial PLAN.md** → wait for planning to complete before reviewing. Partial plans return inflated Block verdicts.
- **Treating Revise as Pass** → non-blocking improvements are not free; they accumulate technical debt if always deferred. Address each one or explicitly accept the trade-off.

---

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/work` (native) | Plans **inline** and files the plan at `.pk-work/<ID>-PLAN.md`; run `/review-plan` against it before execution, then proceed to execution. `/work` does not spawn plan-reviewer directly. |
| `/02-light-spec-revise` | Route here when plan-reviewer's Block verdict points at spec-level issues (framing, missing AC, scope ambiguity). |
| `plan-reviewer` agent | The actual review work happens here; this skill orchestrates the invocation. |

---

## Example Session

```
User: /review-plan RS-14

## Resolving plan…
- Plan: .pk-work/RS-14-PLAN.md (native, single file)
- Linear issue: RS-14 (resolved from current branch feature/rs-14-login-routes)
- Spec: 187 lines including Light Spec + Acceptance Criteria

## Verifying plan-reviewer agent…
✓ .claude/agents/plan-reviewer.md installed

## Spawning plan-reviewer (plan-review tier: opus)…

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan Review Verdict: Revise — 7/10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Verdict
Revise

### Readiness Score
7/10

### Blocking Issues
(none)

### Non-Blocking Improvements
- **[C2]** Verify step on AC-9 ("login flow works") relies on "tests pass" without naming the test file or a specific assertion. Suggested fix: name `apps/web/src/app/(auth)/login/__tests__/login.test.ts` and the assertion that the redirect URL matches `next` query param.
- **[D2]** RLS-bypass risk on the OAuth callback path is unaddressed in plan body. Lead should annotate: "callback uses server-side `supabase.auth.getSession()` which bypasses anon-key RLS; if a future task introduces direct DB access from this route, RLS must be re-engaged."

### Scope Fidelity
Matches spec.

### Atomicity Assessment
All tasks atomic.

### Test Meaningfulness
Verify step on AC-9 is perfunctory (see Non-Blocking #1).

### Risk Coverage
Missed: OAuth-callback-server-bypass note.

### Fast Path to Pass
1. Annotate Task 3's verify with the specific test file + assertion (5 min)
2. Add Task 0.5 or Task 4 note: "RLS bypass acknowledged on callback path" (5 min)

### Final Recommendation
proceed to execution with these two improvements applied.

---

➜ Next: proceed to execution (RS-14)
   (apply the two non-blocking improvements during execution; verify-step
   sharpening can land in the same task commit)
```
