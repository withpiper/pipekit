---
name: review-plan
description: Run the plan-reviewer agent against a VBW-generated PLAN.md before execution. Independent gate that catches scope drift, atomicity failures, test gaps, and risk-coverage holes Lead's self-review can't see.
---

# Review Plan Skill

> **Fresh-chat check.** If this conversation ran `/vbw:vibe --plan` or watched the plan get drafted, start a new conversation. The reviewer must be independent of the planner. See `method.md` § Fresh-Chat Discipline.

You are a plan-review coordinator. Your job is to invoke the `plan-reviewer` agent against a `PLAN.md` produced by VBW Lead, present the structured review back to the user, and recommend a path forward (proceed to execute, route back to Lead for revision, or escalate).

This skill is part of Pipekit Tier 1 (Option 3): Pipekit owns the plan-review gate; VBW owns plan generation, execution, and verification. Run this **between** `/vbw:vibe --plan` and `/vbw:vibe --execute`.

## Triggers

- `/review-plan` — auto-detect most recent phase
- `/review-plan {phase-slug}` — review the named phase explicitly
- `/review-plan PROJ-XXX` — auto-resolve phase from Linear issue's branch mapping
- "review the plan", "run plan-reviewer"

## Purpose

VBW Lead's Stage 3 self-review covers structural correctness (requirements coverage, circular deps, same-wave file conflicts, task counts, skill refs). It cannot see:

- **Scope drift** vs the approved spec
- **Framing errors** (solving the wrong problem)
- **Confirmation bias** in Lead's own judgment calls
- **Atomicity failures** between same-wave tasks
- **Test meaningfulness** — verify steps that say "tests pass" without naming what
- **Domain risk coverage** — RLS bypass traps, migration ordering, JWT scoping
- **Strategic fit** with future-phase plans

The `plan-reviewer` agent fills that gap. This skill orchestrates the call.

## Prerequisites

- A `PLAN.md` exists in `.vbw-planning/phases/{phase-slug}/` (produced by `/vbw:vibe --plan` or directly by `vbw:vbw-lead`)
- The approved Light Spec is available — either as the description of a Linear issue tied to the current branch, or readable from a known location
- `.claude/agents/plan-reviewer.md` is installed (Pipekit ships this; if missing, run `bash scripts/sync-method.sh`)

## Execution Steps

### Step 1 — Resolve the phase dir

Determine which `PLAN.md`(s) to review:

1. **Explicit phase slug** (`/review-plan phase-1-data-foundation`) — use directly
2. **Linear issue ID** (`/review-plan PROJ-123`) — resolve via `.vbw-planning/linear-map.json` or by reading the current git branch (`feature/proj-123-*` → look up phase containing this plan)
3. **No argument** — auto-detect: read `.vbw-planning/STATE.md` for the active phase; if ambiguous, list phases with un-reviewed PLAN.md and ask the user to pick

Find every `*-PLAN.md` in the phase dir:

```bash
ls .vbw-planning/phases/{phase-slug}/*-PLAN.md
```

If the phase dir uses non-VBW-native layout (e.g., nested `rs-N-slug/PLAN.md` rather than flat `01-N-PLAN.md`), still find every `PLAN.md` in the dir tree and pass the list to the agent — the agent reviews plan content, not filename structure.

### Step 2 — Resolve the approved spec

The plan-reviewer agent compares the plan against the approved spec. Find the spec via this priority:

1. **Linear issue tied to current branch** — extract `PROJ-XXX` from `git branch --show-current` (matches `feature/proj-xxx-*`, `fix/proj-xxx-*`, `hotfix/proj-xxx-*`); fetch via `mcp__linear-server__get_issue` with `includeRelations: true`; extract the `## Light Spec` and `## Acceptance Criteria` (or equivalent) sections from the description
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
and let you review manually. Note this is the same fallback /launch
used to take when plan-reviewer was a phantom dependency.
```

### Step 4 — Spawn the plan-reviewer agent

Use the Agent tool with `subagent_type: "plan-reviewer"`. Pin model to `opus` — review has to catch what planning missed; same reasoning budget as Lead.

```
Agent(
  subagent_type: "plan-reviewer",
  model: "opus",
  description: "Review {phase-slug} plan",
  prompt: "Independent review of VBW Lead's plan(s) for {phase-slug} before execution.

  Plan path(s):
    {list of *-PLAN.md absolute paths}

  Approved spec (verbatim from {Linear PROJ-XXX | local spec file}):
  <<<SPEC
  {full Light Spec + Acceptance Criteria from the issue description}
  SPEC

  Project context:
  - CLAUDE.md at repo root
  - method.config.md at repo root
  - .vbw-planning/PHASES.md (if present)
  - .vbw-planning/codebase/CONCERNS.md (if present)

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
| **Pass** | "Plan is execution-safe. Run `/vbw:vibe --execute {phase}` when ready." |
| **Revise** (non-blocking only) | "Plan can proceed but here are improvements to apply during execution: {list}. Run `/vbw:vibe --execute {phase}` when you've decided which to address." |
| **Block** | "Do not execute. Route the Fast Path items back to Lead via `/vbw:vibe --plan {phase}` or amend the spec via `/02-light-spec-revise PROJ-XXX` if scope/framing is wrong. Specifically: {list of blocking issues}." |

Always quote the agent's own Fast Path to Pass section verbatim — those are the concrete moves the user has to make.

### Step 7 — NEXT.md update (with VBW active-plan deferral)

Per the SOP `NEXT.md` schema in `sop/Skills_SOP.md`. Compose the intended file content with timestamp `{YYYY-MM-DD HH:MM local}` and writer `/review-plan`.

Pointer logic:

- **Pass** → `/vbw:vibe --execute {phase-slug}`
- **Revise** → `/vbw:vibe --execute {phase-slug}` (with note about non-blocking improvements)
- **Block** → either `/vbw:vibe --plan {phase-slug}` (if Lead-revise scope) or `/02-light-spec-revise PROJ-XXX` (if spec/framing scope)

Inline `➜ Next:` is **always emitted** to the terminal. The file write may be deferred — see below.

#### Deferral check (v1.6.0+)

Before writing `NEXT.md`, run the active-plan scope detection from `sop/Skills_SOP.md` § Deferral mechanism. `/review-plan` is the canonical case for deferral: it runs *inside* VBW's active-plan scope (the plan it just reviewed is the active plan), so VBW's file-guard hook will block a direct `NEXT.md` write unless the consuming project has adopted the `always_allow` allowlist (#12 Option B, upstream-coordinated).

```bash
ACTIVE_PLAN=""
for plan in .vbw-planning/phases/*/[0-9]*-PLAN.md; do
  [ -f "$plan" ] || continue
  if grep -qE "^(files_modified:|## files_modified)" "$plan" 2>/dev/null; then
    ACTIVE_PLAN="$plan"
    break
  fi
done

DEFER_NEXT_MD=0
if [ -n "$ACTIVE_PLAN" ] && ! grep -q "NEXT\.md" "$ACTIVE_PLAN"; then
  DEFER_NEXT_MD=1
fi
```

If `DEFER_NEXT_MD=1`: resolve `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)`, `mkdir -p "$STATE_DIR"`, write the queue file at `$STATE_DIR/pending-next-md.json` with the schema in the SOP. Mention briefly in your output: `"NEXT.md write deferred (VBW scope) — will apply on /end-session."`

If `DEFER_NEXT_MD=0`: write `NEXT.md` directly at the project root.

Inline `➜ Next:` and the eventual NEXT.md contents (whether written directly or via the queue) must match.

#### Pipeline state file (v1.6.0+)

After the verdict is delivered, resolve `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)`, `mkdir -p "$STATE_DIR/pipeline-state"`, and write `$STATE_DIR/pipeline-state/<issue-id>.json` per the SOP schema (`stage: "review-plan"`, verdict, next_command, cwd, timestamp). Issue ID resolution mirrors Step 2's spec resolution; if no Linear ID, use the phase slug. The path is out-of-repo (v1.7.0+) so no hook block; write should always succeed.

---

## Red Flags

Thoughts that mean "slow down on the review." Paired with `.claude/rules/pipekit-discipline.md` for the portable set.

| Flag | What it actually means |
|------|------------------------|
| "The plan is small, skip the review" | Small plans hide framing errors most easily — there's less surface for Lead's self-review to catch issues. Run review regardless. |
| "Lead self-reviewed, that's enough" | Lead's Stage 3 covers structural correctness only. The class of errors plan-reviewer catches (scope drift, atomicity, test meaningfulness) is structurally invisible to Lead. Don't conflate. |
| "I'll just eyeball it myself" | Probably you'll catch the same things Lead missed — confirmation bias works on humans too. The agent is a fresh pair of eyes. |
| "The spec was clear so the plan must be right" | Spec clarity doesn't guarantee plan fidelity. Lead can correctly understand a spec and still produce a plan that quietly expands scope. |
| "Block verdict but the issue seems minor" | Blocking issues are blocking by definition. If you disagree, push back on the plan-reviewer agent's framing — don't override the verdict. |

---

## Common Drifts to Avoid

- **Skipping the spec resolution** → reviewing a plan without the approved spec means the agent can't catch scope drift. Always pass the spec verbatim.
- **Summarizing the spec for the agent** → the agent needs the AC section as written. Summary loses the testable conditions.
- **Running review against partial PLAN.md** → wait for `/vbw:vibe --plan` to complete before reviewing. Partial plans return inflated Block verdicts.
- **Treating Revise as Pass** → non-blocking improvements are not free; they accumulate technical debt if always deferred. Address each one or explicitly accept the trade-off.

---

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/launch` | Validates Linear gates, then user runs `/vbw:vibe --plan`, then `/review-plan`. `/launch` no longer spawns plan-reviewer directly (Tier 1 / Option 3 split). |
| `/vbw:vibe --plan` | Produces the `PLAN.md` this skill reviews. |
| `/vbw:vibe --execute` | Next step after Pass / Revise. |
| `/02-light-spec-revise` | Route here when plan-reviewer's Block verdict points at spec-level issues (framing, missing AC, scope ambiguity). |
| `plan-reviewer` agent | The actual review work happens here; this skill orchestrates the invocation. |

---

## Example Session

```
User: /review-plan rs-14-login-routes

## Resolving phase…
- Phase dir: .vbw-planning/phases/phase-1-data-foundation/rs-14-login-routes
- Plans: PLAN.md (single)
- Linear issue: RS-14 (resolved from current branch feature/rs-14-login-routes)
- Spec: 187 lines including Light Spec + Acceptance Criteria

## Verifying plan-reviewer agent…
✓ .claude/agents/plan-reviewer.md installed

## Spawning plan-reviewer (opus)…

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
proceed to Dev with these two improvements applied during execution.

---

➜ Next: /vbw:vibe --execute rs-14-login-routes
   (apply the two non-blocking improvements during execution; verify-step
   sharpening can land in the same task commit)

NEXT.md updated.
```
