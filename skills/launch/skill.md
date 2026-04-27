---
name: launch
description: Open + close gate for a specced Linear issue. Validates readiness, transitions Linear status, hands off to VBW for plan/execute/verify, and transitions to UAT on close.
---

# Launch Skill

> **Fresh-chat check.** If this conversation already ran `/light-spec`, `/light-spec-revise`, or any prior pipeline stage, start a new conversation before continuing. See `method.md` § Fresh-Chat Discipline.

You are a launch gate controller. Your job is to:

1. **Open** — validate readiness gates on a human-approved Linear issue, route by complexity, transition Linear to Building, hand off to VBW for plan + execute + verify
2. **Close** — when the user returns post-verify, transition Linear to UAT and surface promotion options

Tier 1 / Option 3 architecture (2026-04-25): `/launch` is a thin gate layer. Pipekit owns Linear status transitions; VBW owns plan / execute / verify via `/vbw:vibe`. The plan-review gate runs as a separate Pipekit skill (`/review-plan`).

Read `method.config.md` for project context.

## Triggers

- `/launch PROJ-XXX` — open a single issue
- `/launch PROJ-XXX --close` — close after the user has run the VBW pipeline and confirmed verify passed
- `/launch --milestone WP-1` — open all ready issues in a milestone
- `/launch --project "P1. Foundation Fixes"` — open all ready issues in a project

## Arguments

| Argument | What it does |
|----------|--------------|
| `PROJ-XXX` | Open a single issue: validate gates, transition to Building, hand off to VBW |
| `PROJ-XXX --close` | Close: transition to UAT after VBW pipeline complete + verify passed |
| `--milestone <name>` | Open all ready issues in a milestone (per-issue gate validation) |
| `--project <name>` | Open all ready issues in a project |
| `--dry-run` | Validate gates and show routing plan without executing |
| `--force` | Skip milestone readiness gate (use with caution) |
| `--tier {quick\|standard\|heavy}` | Override tier inference. Always confirmed with the user before proceeding. |
| `--deep` | (Deprecated — no-op; use `/vbw:vibe --execute --effort=max` instead) |

---

## Model Selection

Tier 1 (Option 3) refactor removed all direct agent spawns from `/launch`. The skill is now pure gate-and-handoff — no `Agent(subagent_type: ...)` calls.

**Where models are still pinned:**
- `vbw:vbw-lead` — pinned in `/vbw:vibe --plan` per VBW's config (`/vbw:config effort=...`)
- `plan-reviewer` — pinned by `/review-plan` skill at `model: opus`
- `vbw:vbw-dev` — pinned in `/vbw:vibe --execute` per VBW's config
- `vbw:vbw-qa` — pinned in `/vbw:vibe --verify` per VBW's config

`/launch` itself doesn't spawn agents, so it has no model decisions to make. Configure VBW's effort profile via `/vbw:config effort={fast|balanced|thorough|max}` for cost/quality tradeoffs.

**`--deep` flag (deprecated):** previously escalated Dev to opus when `/launch` orchestrated the chain. Now a no-op; emit a one-line warning recommending `/vbw:vibe --execute --effort=max` instead.

---

## Gate Model: Hybrid (Option C)

All issues in the same milestone must be at least **Specced** (agent-reviewed) before any issue in that milestone can be launched. Human approval can happen rolling — you can launch approved issues while siblings are still in human review.

**Rationale:** Ensures no issue is launched blind. A later spec could change assumptions that affect earlier work. The spec gate catches this before execution starts.

---

## Execution Steps

### Step 1 — Fetch and Validate Issue

1. Fetch the issue via `mcp__linear-server__get_issue` with `includeRelations: true`
2. Validate the issue has:
   - A `## Light Spec` or `## Acceptance Criteria` section in the description
   - Status is **Approved** ({Approved state ID from method.config.md}) or **Specced** with human approval noted
3. If no spec/AC found: stop and report `"PROJ-XXX has no spec or AC. Run /light-spec PROJ-XXX first."`
4. If status is before Approved: stop and report `"PROJ-XXX is in {status}. Move to Approved in Linear before launching."`

### Step 1.5 — Determine Tier (always confirm; never auto-pick)

Tiers shape which gates apply. Tier is **orthogonal** to complexity (which routes execution): an issue can be Quick complexity but Heavy tier (e.g., a 2-hour change to billing logic). Tier inference is advisory — the human always confirms before any gate runs.

1. Resolve tier in this order:
   - `--tier {quick|standard|heavy}` flag, if provided
   - Issue label `tier:quick`, `tier:standard`, or `tier:heavy`
   - Inferred default (see heuristic below)
2. **Inference heuristic** (used only as a starting point for the confirmation prompt):
   - Default to **standard**
   - Suggest **quick** if: complexity is Low AND issue has no milestone AND description has `## Acceptance Criteria` with ≤5 bullets AND no `tier:standard` or `tier:heavy` label
   - Suggest **heavy** if: any of these are true → labels include `security`, `auth`, `payments`, `pii`, `compliance`, `breaking-change`; or the spec mentions schema migration, RLS, or external API contract change
3. **Always print the inference and ask for explicit confirmation**, even when a flag or label was provided. Wording:
   ```
   Tier resolved: {tier} (source: {flag|label|inference})
   Reason: {one-line summary}
   Proceed with {tier} tier? (y / change-to {alt} / abort)
   ```
4. Once confirmed, load `method/templates/tier-{tier}.md` and treat its gate table as the active gate list for the remainder of `/launch`. The default flow below is **standard**; deviations are noted inline with `[Quick: ...]` and `[Heavy: ...]` markers.

If `method.config.md` has removed a tier from its `## Tiers` table, treat that tier as disallowed and require the user to pick one of the remaining tiers.

### Step 1.6 — VBW Phase-State Awareness (informational gate)

After the Linear gate-check passes and tier is resolved, read VBW's phase state to surface any unresolved conditions that may interact with the issue being launched. **Read-only — Pipekit never writes to VBW state.** This implements the cross-system awareness called out in `method.md` § VBW / Pipekit Ownership Model.

```bash
# Read VBW state (read-only, never writes).
# Resolve phase-detect.sh in this order:
#   1. PATH (consumer override or VBW bin)
#   2. .vbw-planning/scripts/phase-detect.sh (project-local override or wrapper)
#   3. VBW plugin cache: ~/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/phase-detect.sh
#      (canonical install path; latest version wins via alphabetic glob expansion)
PHASE_DETECT=""
if command -v phase-detect.sh >/dev/null 2>&1; then
  PHASE_DETECT="phase-detect.sh"
elif [ -x ".vbw-planning/scripts/phase-detect.sh" ]; then
  PHASE_DETECT=".vbw-planning/scripts/phase-detect.sh"
else
  for c in "$HOME"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/phase-detect.sh; do
    [ -x "$c" ] && PHASE_DETECT="$c"
    # Don't break — alphabetic glob expansion means later iterations
    # overwrite with higher-versioned VBW installs (e.g., 1.36.0 wins over 1.35.1).
  done
fi

if [ -n "$PHASE_DETECT" ]; then
  "$PHASE_DETECT" > /tmp/pipekit-vbw-state.txt 2>/dev/null
  PHASE_DETECT_RC=$?
else
  PHASE_DETECT_RC=127  # treat as unavailable; downstream non-blocking warning fires
fi
```

Parse the output for any of these warning conditions:

- `qa_status=failed` on any phase
- `qa_status=pending` on a phase already marked shipped
- `has_unverified_phases=true`
- `next_phase_state=needs_qa_remediation`
- `next_phase_state=needs_uat_remediation`

**If `phase-detect.sh` exits non-zero or is unavailable** (`PHASE_DETECT_RC != 0`): print a one-line note `"⚠ VBW state unavailable — proceeding without phase-state awareness."` and continue. This is **non-blocking** — Pipekit must still function in projects that don't use VBW or have a non-standard VBW install.

**If any warning condition is met**, surface a single AskUserQuestion with the unresolved state listed:

```
⚠ VBW reports the following unresolved state:
  - Phase 01 (slug): qa_status=failed
  - Phase 02 (slug): unverified

This launch may interact with phase-level work in flight.

Options:
  (a) Continue — this issue is independent of phase state  [default]
  (b) Address VBW first — run /vbw:vibe to enter remediation
  (c) Abort
```

Default action: **(a) Continue.** The warning is informational, not blocking — the canonical case (no warnings) is unchanged. If user picks (b), exit with a pointer to `/vbw:vibe`; if (c), exit silently. If (a), proceed to Step 2 (Check Dependencies).

This gate runs **before** the Linear status transition to Building (Step 6), so an aborted/redirected launch leaves Linear state untouched.

### Step 2 — Check Dependencies

1. Read `blocked_by` relations from the issue
2. For each blocker, check its status via `mcp__linear-server__get_issue`
3. If any blocker is NOT in **Done** ({Done state ID from method.config.md}): stop and report `"PROJ-XXX is blocked by PROJ-YYY ({status}). Resolve blockers first."`

### Step 3 — Milestone Readiness Gate

[Quick: skip this gate entirely — Quick tier does not require sibling readiness.]

1. Identify the issue's milestone (if any) via the issue's milestone field
2. If the issue belongs to a milestone:
   - Fetch all sibling issues in that milestone via `mcp__linear-server__list_issues` filtered by milestone
   - Check that ALL sibling issues are at least in **Specced** ({Specced state ID from method.config.md}) or later state
   - If any sibling is in Needs Spec, On Deck, or earlier: stop and report:
     ```
     Milestone gate failed: {milestone name}
     
     Not yet specced:
       - PROJ-YYY — {title} ({status})
       - PROJ-ZZZ — {title} ({status})
     
     All issues in a milestone must be at least Specced before any can launch.
     Run /light-spec on the above issues, or use --force to bypass.
     ```
3. If `--force` is passed, skip this gate with a warning: `"Milestone gate bypassed. Proceeding at your discretion."`
4. If the issue has no milestone, skip this gate.

### Step 4 — Determine Complexity and Route

[Quick: route is forced to `/linear-todo-runner` regardless of complexity. Skip the complexity field check.]
[Heavy: route is forced to full VBW Lead → plan-review → Dev → QA regardless of complexity. Batch runner is disallowed.]

1. Read the `## Light Spec` section and extract the `**Complexity:**` field
2. Route based on complexity (Standard tier only):

| Complexity | Route | What happens |
|-----------|-------|--------------|
| **Low** (~2-4h) | `/linear-todo-runner` | Issue queued for batch execution. AC is the plan. |
| **Medium** (~6-10h) | VBW Lead → Dev → QA | Full planning cycle with PLAN.md |
| **High** (~12-20h+) | VBW Lead → Dev → QA | Full planning cycle, likely multi-task |

3. If no complexity field found, ask the user: `"No complexity rating found. Route as Low (batch runner) or Medium/High (VBW planning)?"`

### Step 5 — Rename cmux Workspace

Rename the current cmux workspace to reflect the launched issue:

```bash
bash ~/.claude/scripts/cmux-workspace-name.sh "PROJ-XXX"
```

This sets the workspace title to `{project} - PROJ-XXX` (read project name from `method.config.md`). Skip silently if cmux is unavailable.

### Step 6 — Move to Building

1. Move issue to **Building** ({Building state ID from method.config.md}) via `mcp__linear-server__save_issue`
2. Post a Linear comment via `mcp__linear-server__save_comment`:
   ```
   **Launch:** Execution started.
   - Route: {VBW | Batch Runner}
   - Complexity: {Low | Medium | High}
   - Gates passed: spec ✓, dependencies ✓, milestone ✓
   ```

### Step 7a — Low Complexity: Queue for Batch Runner

1. Confirm the issue has a complete `## Acceptance Criteria` section
2. Inform the user: `"PROJ-XXX queued for batch execution. Run /linear-todo-runner to process, or it will be picked up on next runner invocation."`
3. **Done.** The `/linear-todo-runner` skill handles execution from here.

### Step 7b — Medium/High Complexity: Hand Off to VBW

Pipekit owns the Linear gate. **VBW owns planning, execution, and verification.** Pipekit no longer spawns `vbw:vbw-lead` directly — `/vbw:vibe --plan` is the canonical path. The plan-review gate now runs as a separate Pipekit skill (`/review-plan`).

#### 7b.0 — VBW absorption check (closeout-style routing)

Before emitting the canonical handoff, re-read `phase-detect.sh` (or reuse the output from Step 1.6 if still in scope) and inspect whether VBW has a phase that can absorb this issue:

- **Canonical case** — `next_phase_state` indicates an unbuilt phase that matches the issue context (no plan written yet, slug aligns with the issue's scope). → Emit the canonical handoff in 7b.1 below. **Behavior unchanged from prior versions.**
- **Closeout case** — `next_phase_state=all_done`, no matching unbuilt phase, or VBW reports no phases at all. The issue is "closeout-style" (migration, hygiene, doc update, infra cutover) and does not naturally slot into VBW's "next unbuilt phase" model. → Run the routing prompt below; never auto-route.

**Routing prompt (closeout case only):**

```
VBW has no unbuilt phase that can absorb PROJ-XXX.
  next_phase_state: {all_done | none}

This is closeout-style work — choose how to plan it:

  (1) Add a new VBW phase first
        Run:  /vbw:vibe --add <slug>     (creates the phase)
        Then: /vbw:vibe --plan N          (N is the new phase number)
        Use this when the issue is sizeable enough to deserve its own
        VBW phase entry and you want VBW's plan/execute/verify cadence.

  (2) Skip VBW pipeline — author plan manually
        Write PLAN.md by hand at the project's chosen path, then run:
          /review-plan <path-to-PLAN.md>
        /review-plan accepts a path argument (not just a phase slug)
        and runs the plan-reviewer agent standalone. Standard tier's
        plan-review gate is satisfied. Execute manually or by spawning
        a worktree agent yourself.
        Use this for one-off closeout work too small for a VBW phase.

  (3) Abort and escalate
        Stop here. The user resolves the routing question (e.g., add
        the phase to ROADMAP.md first, or reclassify the issue).

Pick (1), (2), or (3):
```

Always confirm — never auto-route. If the user picks (1) or (2), exit `/launch` with a pointer to the chosen command; do not write `NEXT.md` for the canonical 7b.1 sequence (Linear has already transitioned to Building per Step 6, so the user picks up wherever VBW lands them or wherever they author the manual plan). If (3), no further action.

**Note on `/vbw:vibe --plan` accepting slugs vs phase numbers:** the recurring friction in rs-vault was that `/launch` emitted `/vbw:vibe --plan <slug>` while VBW expected a phase number. The canonical handoff in 7b.1 still emits a phase slug because the canonical case has a phase already in VBW's index where the slug resolves. The closeout case is exactly when slug-resolution fails — handle it via this prompt instead of emitting a broken command.

#### 7b.1 — Canonical handoff (when VBW can absorb the issue)

**Hand off to the user** with the full sequence laid out so they can run it without coming back between phases:

```
## Linear gate passed — handing off to VBW

PROJ-XXX is in Building. Run this sequence:

  1. /vbw:vibe --plan {phase-slug}      ← VBW Lead writes PLAN.md
  2. /review-plan {phase-slug}           ← Pipekit's plan-review gate
                                            (calls plan-reviewer agent)
  3. (read review verdict — proceed only on Pass or Revise)
  4. /vbw:vibe --execute {phase-slug}    ← VBW Dev builds with atomic commits
  5. /vbw:vibe --verify {phase-slug}     ← VBW QA (see "Verify path" note below)
  6. /launch PROJ-XXX --close            ← Pipekit transitions Linear to UAT

If plan-review returns Block: route to `/vbw:vibe --plan` for Lead-revise,
or `/02-light-spec-revise PROJ-XXX` if the issue is spec-level (framing, scope).

If verify reports failures: re-run `/vbw:vibe --execute` with fix scope. Linear
stays in Building. Don't run `/launch --close` until verify passes.
```

**Verify path note** (informational; Pipekit doesn't enforce):

```
/vbw:vibe --verify expects VBW-native phase layout (.vbw-planning/phases/NN-slug/
with NN-MM-PLAN.md and NN-MM-SUMMARY.md per plan).

If your project uses a non-native layout (Linear-per-issue nested, etc.) and
phase-detect returns phase_count=0, /vbw:vibe --verify will fail at its guard.
Fall back to project precedent — typically Dev self-verification + /g-test-vercel
preview URL + manual UAT — and run /launch --close once you're satisfied.

This is a project-VBW coupling concern, not a Pipekit concern. Pipekit's gate
ran at /launch open and runs again at /launch --close.
```

While the user is in the VBW pipeline, do not spawn any VBW agents yourself. If they ask for progress, read `.vbw-planning/STATE.md` and any `*-SUMMARY.md` files in the phase dir.

**Permission-denial protocol for any agent you do spawn (now or in future variants of this skill):** if you ever invoke `Agent()` from inside `/launch`, include the following instruction in the agent's task description so hook-driven blocks surface immediately rather than burning turns:

```
If any Edit/Write call fails with a permission denial (EditPermissionDenied,
HookFeedbackBlocked, or similar), STOP IMMEDIATELY and report in your final
summary. Do not retry. Include: the denied path, the intended change verbatim,
why it was needed (which task / which AC). The orchestrator will surface the
denial for manual resolution.
```

This pattern protects against silent agent failures when project hooks guard canonical files (e.g., `.claude/rules/*`). See `sop/Skills_SOP.md` § Canonical-file protection.

### Step 8 — Wait for User to Return with `--close`

Pipekit pauses after Step 7b. The user runs the VBW sequence (`--plan` → `/review-plan` → `--execute` → `--verify`) on their own pace. Pipekit re-enters when they invoke `/launch PROJ-XXX --close`.

**While paused:**
- If user asks "is the plan good?" — point them at `/review-plan {phase-slug}`
- If user asks "what's the build status?" — read `.vbw-planning/STATE.md` and the latest `*-SUMMARY.md`
- If user asks "did verify pass?" — read `*-VERIFICATION.md` if VBW-native; otherwise ask them to confirm based on their project's precedent

Do **not** auto-advance to `--close`. The user must explicitly invoke it. This is the second judgment-role pause (the first was Linear gate at Step 1).

### Step 9 — Close: Move to UAT (`/launch PROJ-XXX --close`)

Invoked when the user returns with verify confirmed (either via `/vbw:vibe --verify` passed, or via project-precedent self-verification on non-VBW-native layouts).

[Heavy: before transitioning, verify all close-gate artifacts are present:
- QA report exists and is passing
- Security review report exists at the path defined in `method.config.md`
- `/strategy-sync` last-run timestamp is after this issue's last build commit
- No `.pipekit/pending-strategy-sync` marker exists

If any check fails, refuse to close with a list of missing artifacts and stop. Do not transition Linear status.]

**Idempotent + comment-on-presence** (since v1.4.0): `--close` is safe to invoke regardless of how the issue moved past UAT. PR-merge automation, label-driven Linear automation, and `/linear-todo-runner` may transition the issue past UAT before the user runs `--close`. The close-summary comment is the audit trail and must always be posted exactly once.

1. **Read current Linear status** via `mcp__linear-server__get_issue`.
2. **Status transition logic:**
   - If status is `<= Building` (Approved, Specced, Building, In Progress) → transition to **UAT** ({UAT state ID from method.config.md}) via `mcp__linear-server__save_issue`. This is the canonical path.
   - If status is `>= UAT` (UAT, Done, Canceled, Duplicate) → status transition is a **no-op**. Skip silently. Do not error.
3. **Comment-on-presence** (independent of status, runs every invocation):
   - List existing comments via `mcp__linear-server__list_comments` for the issue.
   - Scan each comment body for the marker `**Build complete.**` (the literal bolded phrase at the start of any comment line).
   - **If the marker is absent** → post the close-summary comment described below.
   - **If the marker is present** → skip silently. Re-running `--close` is idempotent: no duplicate comment, no error.
4. **Close-summary comment** (posted only when marker absent):
   ```
   **Build complete.** Moved to UAT.
   - Plan reviewed: {Pass | Revise — see /review-plan output} 
   - Execution: complete (per VBW or project precedent)
   - Verification: {VBW-native via /vbw:vibe --verify | project precedent — Dev self-verification + /g-test-vercel}
   - Pre-deploy gate: ✓
   - Branch: {branch name}
   
   Ready for human acceptance testing.
   ```
5. **Inform the user.** Adapt the promotion-options block to the project's git architecture (read from `method.config.md` → `## Git Architecture`):

   **Two-tier projects (`dev` → `main`):**
   ```
   PROJ-XXX is ready for UAT.
   
   Test with: /g-test-vercel (pushes branch, returns preview URL)
   Accept with: move to Done in Linear, then /g-promote-dev
   Reject with: describe what's wrong and I'll re-enter execution
   
   Promotion options:
     - Ship now:   /g-promote-dev → /g-promote-main
     - Batch:      /g-promote-dev now, then work on next issue;
                   /g-promote-main when 2-5 dev-landed issues are ready
     - Hold:       leave in UAT for extended testing before any promote
   
   Decision criteria — pick batch unless one of these is true:
     - This is a hotfix (security, data, payment, auth) → ship now
     - High-blast-radius migration (column rename, table drop) → ship alone
     - Pre-deploy gate flipped yellow on dev → investigate before adding
     - 5+ issues already on dev awaiting main → ship the batch now
     - 1+ week since last main promotion → ship now to keep changes fresh
   
   See sop/Git_and_Deployment.md § Batch vs Per-Issue Promotion for the
   full decision tree, DB-migration timing, and rollback procedures.
   ```

   **Three-tier projects (`dev` → `beta` → `main`):**
   ```
   PROJ-XXX is ready for UAT.
   
   Test with: /g-test-vercel (pushes branch, returns preview URL)
   Accept with: move to Done in Linear, then /g-promote-dev
   Reject with: describe what's wrong and I'll re-enter execution
   
   Promotion options:
     - Ship now:   /g-promote-dev → /g-promote-beta → (beta UAT) → /g-promote-main
     - Batch:      /g-promote-dev now; /g-promote-beta when 2-5 dev-landed
                   issues are UAT-ready; /g-promote-main after beta UAT passes
                   on the whole batch
     - Hold:       leave in UAT for extended testing before any promote
   
   Decision criteria at each boundary — see sop/Git_and_Deployment.md
   § Batch vs Per-Issue Promotion. In particular: don't promote partial
   beta — if any issue fails beta UAT, hold the whole batch or cherry-
   pick the working issues forward.
   ```

   **Migration-bearing issues:** if this issue includes Supabase migrations, also include this note before the promotion options:

   ```
   ⚠ Migration timing
   This issue includes a DB migration. When migrations apply depends on
   your project's setup. Read sop/Git_and_Deployment.md § DB Migration
   Timing to determine whether dev preview tests against the migrated
   schema. If your /g-promote-dev does not run `supabase db push`, the
   migration only takes effect at /g-promote-main — plan UAT accordingly.
   ```

---

## Milestone/Project Batch Mode

When invoked with `--milestone` or `--project`:

1. Fetch all issues in the milestone/project
2. Filter to **Approved** status only
3. Sort by priority (P1 first), then by dependency order
4. Run Steps 1-3 for each issue, collecting gate results
5. Present a launch plan:
   ```
   ## Launch Plan: WP-1 Foundation Fixes
   
   Ready to launch (3 issues):
     1. PROJ-200 — Design tokens [Low] → Batch Runner
     2. PROJ-201 — Supabase types [Low] → Batch Runner
     3. PROJ-202 — Calculation tests [Medium] → VBW
   
   Blocked (1 issue):
     - PROJ-203 — Realtime strategy (blocked by PROJ-200)
   
   Not approved (2 issues):
     - PROJ-204 — AI cost monitoring (Specced, awaiting approval)
     - PROJ-205 — Cache strategy (Needs Spec)
   
   Proceed? (y/n)
   ```
6. On confirmation, launch each ready issue sequentially (VBW) or queue all Low issues for the runner

---

## Linear Status Transitions

The `/launch` skill owns these transitions:

| Event | Status Change | Linear State ID |
|-------|--------------|-----------------|
| Launch starts | Approved → Building | {Building state ID from method.config.md} |
| Build + QA complete | Building → UAT | {UAT state ID from method.config.md} |
| QA fails | Stays in Building | — |
| Gate fails | Stays in Approved | — |

Downstream transitions (not owned by `/launch`):
- UAT → Done: `/g-promote-main` (after human acceptance + production release)
- UAT → Building: user rejects in UAT, re-enters execution

---

## Error Handling

- **No spec:** Stop. Direct to `/light-spec`.
- **Dependencies not met:** Stop. List blockers and their statuses.
- **Milestone gate fails:** Stop. List unspecced siblings. Offer `--force`.
- **VBW agent timeout:** Flag as stalled in Linear comment. Do not auto-kill.
- **Pre-deploy gate failure:** QA agent attempts fix. If unfixable after one retry, report failure and keep in Building.
- **Linear MCP unavailable:** Stop with clear error. Do not execute without status tracking.

---

## Red Flags

Thoughts that mean "go slower, not faster." If you catch yourself thinking one of these, follow the full gate sequence *more* strictly, not less. Paired with `.claude/rules/pipekit-discipline.md` for the portable set.

| Flag | What it actually means |
|------|------------------------|
| "This launch is straightforward, skip the gate check" | The gates exist because past issues shipped broken without them. Run them. |
| "The spec is obvious enough" | Obvious specs hide [TBD]-blocking ambiguity. If planning would require guessing, route back to `/light-spec-revise`. |
| "I'll skip the plan-reviewer just this once" | Never. Plan-reviewer catches the class of mistake Lead structurally cannot see in its own work. |
| "Low complexity, no need for QA" | Every shipped change lands on users. Run the pre-deploy gate regardless of complexity tier. |
| "This issue has been sitting, just push it through" | Staleness is not a gate override. Re-validate the spec against current codebase state before launch. |

---

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Launching without a passing gate** → Specs that don't pass the gate go back to `/light-spec`, not forward to execution.
- **Skipping the milestone gate** → The gate exists because later specs can change assumptions that affect earlier work. Only bypass with `--force` when the user explicitly requests it.
- **Low complexity without AC** → The batch runner needs acceptance criteria to execute. Every issue needs verifiable criteria regardless of complexity.
- **Launching despite unresolved blockers** → Blockers should be Done before launching. If a blocker looks ready but isn't marked Done, flag it for the user rather than proceeding.
- **Estimating complexity from the title** → Read the spec to determine complexity. Title-based estimates are unreliable.

---

## NEXT.md Output

Tier 1 / Option 3 has two `/launch` invocations per issue: open and `--close`. Each one writes `NEXT.md` so the user's next action survives session close.

| Invocation | Outcome | `NEXT.md` should point to |
|------------|---------|----------------------------|
| `/launch PROJ-XXX` (open) | Linear gate passed, status to Building | `/vbw:vibe --plan {phase-slug}` (or the full handoff sequence in Step 7b) |
| `/launch PROJ-XXX --close` | Linear status to UAT | Next action — see logic below |

**Close-time NEXT.md logic** (priority order):

1. Next Specced issue in current phase → `/launch {next issue}`
2. If `.pipekit/pending-strategy-sync` marker exists → `/strategy-sync`
3. If phase complete and synced → `/phase-plan`
4. Otherwise → `/g-test-vercel` for the just-shipped issue

Inline `➜ Next:` and `NEXT.md` contents must match. See SOP schema in `sop/Skills_SOP.md` (Routing Pointers → NEXT.md). Use the `YYYY-MM-DD HH:MM local` timestamp format.

**Note:** Pipekit no longer writes NEXT.md between phases (between `--plan`, `--execute`, `--verify`). Those are VBW's pause points; if the user wants context recovery there, they consult `.vbw-planning/STATE.md` directly. Pipekit's NEXT.md tracks the **issue lifecycle**, not the build lifecycle.

---

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/light-spec` | Produces the spec that `/launch` consumes. Run before `/launch`. |
| `/linear-todo-runner` | `/launch` queues Low-complexity issues for the runner. |
| `/branch` | VBW agents use `isolation: "worktree"` internally, not `/branch`. |
| `/g-test-vercel` | Used after `/launch` completes to test the built feature. |
| `/g-promote-dev` | Next step after UAT passes. |
| `/roadmap-review` | Run before `/launch` to validate the big picture. |

---

## Example Session

```
User: /launch PROJ-200

## Gate Check: PROJ-200 — Apply Design Tokens

  Spec: ✓ Light spec with AC (7 criteria)
  Dependencies: ✓ No blockers
  Milestone: ✓ WP-1 Foundation Fixes — all 5 siblings specced
  Complexity: Low (~2-4h)
  Route: Batch Runner

Moving to Building...
PROJ-200 queued for batch execution.
Run /linear-todo-runner to process.

---

User: /launch PROJ-88

## Gate Check: PROJ-88 — AG Grid Enterprise Migration

  Spec: ✓ Light spec with AC (12 criteria)
  Dependencies: ✓ PROJ-200 (Done), PROJ-201 (Done)
  Milestone: ✓ WP-2 AG Grid Migration — all 4 siblings specced
  Complexity: High (~16h)
  Route: VBW

Moving to Building... done.

Run this sequence:
  1. /vbw:vibe --plan ag-grid-migration
  2. /review-plan ag-grid-migration
  3. /vbw:vibe --execute ag-grid-migration
  4. /vbw:vibe --verify ag-grid-migration
  5. /launch PROJ-88 --close

➜ Next: /vbw:vibe --plan ag-grid-migration
NEXT.md updated.

---

[User runs the VBW sequence on their own pace]

---

User: /launch PROJ-88 --close

## Closing PROJ-88

  Verifying state... issue in Building, branch ahead of dev: ✓
  
  Moving to UAT...
  Linear updated. Comment posted.

## PROJ-88 Build Complete — Moved to UAT

  Plan reviewed: Pass (Readiness 9/10)
  Execution: complete
  Verification: passed via /vbw:vibe --verify
  Branch: feature/wit-88-ag-grid

  Test with: /g-test-vercel (preview URL)
  
  Promotion options:
    - Ship now:   /g-promote-dev → /g-promote-main
    - Accumulate: /g-promote-dev, then work on next issue
    - Hold:       leave in UAT for extended testing

➜ Next: /launch PROJ-89 (next Specced issue in WP-2)
NEXT.md updated.

---

User: /launch --milestone "WP-1: Foundation Fixes"

## Launch Plan: WP-1 Foundation Fixes

Ready to launch (4 issues):
  1. PROJ-200 — Design tokens [Low] → Batch Runner
  2. PROJ-201 — Supabase types [Low] → Batch Runner
  3. PROJ-202 — Calculation tests [Low] → Batch Runner
  4. PROJ-203 — Realtime strategy [Medium] → VBW

Not approved (1 issue):
  - PROJ-204 — AI cost monitoring (Specced)

Proceed? (y/n)
```
