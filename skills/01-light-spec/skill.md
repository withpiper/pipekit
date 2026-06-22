---
name: light-spec
description: Structured spec generation with auto-cycled agent review + tier auto-derive (v2.7.0-rc1+). Use when a Linear issue moves to spec stage. Use when writing/refining a feature spec before /work. Use when /spec-validator flags gaps.
---

# Light Spec Skill

Draft a structured, plan-ready specification for a Linear issue. Bridges the gap between raw brainstorms and full PLAN.md files.

## Triggers

- `/light-spec` — start from scratch or provide an issue ID
- `/light-spec PROJ-123` — spec an existing issue

## Purpose

Create a **light spec** — enough structure for VBW to generate a plan, but fast enough to draft in one pass. Optionally delegate to Linear's agent for refinement before pulling into planning mode.

## Core Principle

A light spec is an **AI→AI contract**: Generator → Reviewer → Planner. You are not guiding a human — you are constraining an AI. Every rule in this spec must be:

- **Explicit** — no implied behavior
- **Unambiguous** — one interpretation only
- **Enforceable** — a downstream agent can validate compliance

**Controlled incompleteness is allowed.** Light specs are intentionally lightweight. Brevity, `[TBD]` markers, and limited context are fine. Hidden assumptions and implicit behavior are not. The line is: _can the planner work without guessing?_

## Inputs

| Input | Source | Required |
|-------|--------|----------|
| Issue ID (e.g., `PROJ-123`) | Argument or prompt | No — creates new issue if omitted |
| Idea description | User prompt | Yes, if no issue ID |

## Execution Steps

### Phase 1 — Capture

1. **If issue ID provided**: Fetch via `mcp__linear-server__linear_getIssueById` (with `includeRelations: true`). Extract title, description, existing labels, project, and any sub-issues.
2. **If raw idea**: Ask the user for a 1-2 sentence description of what they want and why.

### Phase 2 — Technical Context

Explore the codebase to understand what exists and what's needed.

**When to use the Explore subagent (required — Opus 4.7 defaults to direct tool calls):**

This phase MUST spawn an Explore subagent rather than calling Grep/Read directly. Two reasons:
1. The exploration produces lots of intermediate output (file listings, pattern matches) that you only need the conclusion from. Keeping it in the subagent's context protects the main session from rot.
2. Codebase-wide exploration benefits from parallel search across multiple conventions/locations, which the subagent handles.

Do NOT inline the exploration into the main session even if you think "I can just grep for this quickly." The decision is about context hygiene, not capability.

1. Use the `Explore` agent (subagent_type: Explore, thoroughness: medium) to answer:
   - What existing code/infrastructure is relevant?
   - What patterns does the codebase already use for similar features?
   - What database tables, APIs, or UI components are involved?
   - Are there any obvious constraints or blockers?
2. Identify the issue's **phase context** from Linear: which `i{N}.` initiative (phase) and `I{N}.P{N}.` project (sub-phase) its Linear project belongs to. Derive it live (the issue's Linear project, or `pk next`) — there is no `linear-map.json` or `PHASES.md` to read. This anchors the spec to the right phase without guessing.

### Phase 3 — Draft Light Spec

Write the spec using the **Light Spec Template** below. Fill in every section.

**Decision discipline:** All behavior-affecting decisions should be either defined or marked `[TBD]`. A decision left implicit (not mentioned at all) means the planner will guess, and guesses compound. `[TBD]` is only valid if it does **not** block task decomposition. If a `[TBD]` would force the planner to guess at task boundaries, resolve the decision before the spec is ready.

**Scope discipline:** Specs define WHAT, not HOW. Litmus test: if a statement can be rewritten as "change X line" or "use Y syntax," it is implementation detail — remove it. If a statement can be rewritten as "the system should [observable behavior]," it belongs in the spec. Do not include file paths to create, function signatures, or implementation patterns — VBW planning agents own the HOW.

**Acceptance Criteria discipline (behavioral, not presence-only):** Every AC must verify *observable behavior*, not *element presence*. A spec that ships ACs like "component X exists" / "function Y is called" lets implementations pass tests without actually working — surfaced 2026-05-02 by RS-63/64 in rs-vault, where tests + 7-check gate + antagonistic review all passed but the running app was 60% broken (search bar non-functional, panel didn't animate, Notes save unwired, History tab placeholder, integration step skipped).

Bad → Better examples:

| ❌ Presence-only AC | ✅ Behavioral AC |
|---|---|
| "Component `<Search>` exists" | "Given /page renders, when user types 'SW3' in the search input, then results filter to addresses containing 'SW3' within 300ms" |
| "Save button calls `onSave`" | "Given user clicks Save, when fetch resolves, then DB row contains the value AND UI shows 'saved' state AND reloading the page shows the persisted value" |
| "Tabs render" | "Given drawer is open, when user clicks each of the 4 tabs, then each tab renders its real content (not 'coming soon' placeholder)" |
| "Token `--color-x` exists in globals.css" | "Given page renders at 1440px viewport, when computed style of `.foo` is read, then `background-color` resolves to `var(--color-x)`" |
| "Animation duration matches `--duration-base`" | "Given user clicks toggle, when panel transitions, then `getAnimations()` reports duration ≈ 180ms AND visual state changes from collapsed to expanded" |

For UI surfaces, **at least one AC must be a visual or computed-style assertion** — not just unit-test presence. If the spec is design-driven, reference the figma source explicitly and require pixel-diff or computed-style verification.

**Cross-spec handoff awareness:** If this spec references another issue with phrases like *"X will replace…"*, *"X consumes…"*, *"X provides…"*, that's a load-bearing handoff promise. Either:
- Include the handoff *itself* as an AC in the predecessor's spec ("The integration in file Y is updated to use the new component, replacing the placeholder"), OR
- Mark it explicitly in the successor's spec as a required integration step ("This issue must update file Y to consume…").

Don't leave handoff promises buried in prose. Today's miss (RS-64) shipped because RS-63 said "RS-64 will replace the placeholder" but RS-64's AC didn't include the integration step. Both passed; the app was broken.

### Phase 3.5 — Planning Readiness Check

Before presenting to the user, audit every section:

1. **Identify every point where VBW would need to guess** — scan for implicit assumptions, undefined behaviors, and missing decision points
2. **For each guessing point**, do one of:
   - Convert it into a **Decision** (defined or `[TBD]`)
   - Clarify the **Scope** to eliminate the ambiguity
   - Move it to **Risks & Open Questions** if it can't be resolved now
3. **Validate:** the spec is only ready when no guessing is required for task decomposition. `[TBD]` is acceptable; implicit assumptions are not.

### Phase 3.6 — Derive tier label from Complexity (v2.7.0-rc1+)

The spec's `**Complexity:**` field is the source of truth for the issue's tier. Parse it and compute the matching `tier:*` Linear label so the downstream `/work` and `/verify` skills get a consistent gate signal — no manual labeling step required.

**Mapping:**

| Complexity in spec body | Tier label | Why this tier |
|---|---|---|
| `Trivial`, `Low (~2-4h)` | `tier:quick` | `/work` uses inline planning, single-issue mode, light gates. |
| `Medium (~6-10h)` | `tier:standard` | Default tier. Full /work pipeline, evidence layer, opt-in antagonistic review (auto-fires on sensitive-path diffs). |
| `High (~12-20h+)`, `Very High`, `Critical` | `tier:heavy` | Mandatory antagonistic review, `/strategy-sync` reminder at hand-off, full evidence pipeline. |

**Extraction logic:**

1. Read the line matching `**Complexity:**` from the spec body.
2. Match the **first named complexity token** present (case-insensitive): `Trivial | Low | Medium | High | Very High | Critical`. Ignore everything else (hour ranges, parentheticals).
3. Map per the table above. If no token matches but an hour range is present (e.g., `~8h`), infer: `≤4h → quick`, `5-11h → standard`, `≥12h → heavy`.
4. If the Complexity line is missing or ambiguous, surface a one-line confirmation prompt before publishing: `Complexity not parseable — apply 'tier:standard' (Recommended) or 'tier:heavy' / 'tier:quick'?` Default `standard`.

**Why this is a Phase 3.6 step, not a Phase 5 inline action:** the user gets one final read-through (Phase 4) before publish. Surfacing the derived tier alongside the spec gives them a redirect window if the auto-derivation looks wrong. The tier choice ships in Phase 5's label payload as a normal part of the save.

Print the derived tier in the Phase 4 spec re-presentation as a one-liner near the Complexity field:

```
Derived tier: tier:heavy  (from "Complexity: High (~16-22h)")
```

### Phase 3.7 — Migration Plan gate (schema-touching specs)

If this spec changes the **database schema**, it is not planning-ready until it carries a **Migration Plan**. Phase 2's Explore already surfaced the involved tables — use that to decide.

1. **Detect schema change.** The spec touches schema if it adds/alters tables, columns, types, constraints, indexes, RLS policies, functions, or triggers. Signals: the `Database:` line names a new/changed table; Requirements or AC imply persisted state that doesn't exist yet; Phase 2 found "new tables needed."
2. **If no schema change:** delete the `### Migration Plan` section from the spec. Done — skip to Phase 4.
3. **If schema changes:** the `### Migration Plan` section is **mandatory**. Fill all six fields (schema objects, migration tool + dir from `method.config.md § Migration dir`, forward intent, rollback intent, data backfill, authorization). The change MUST land as a **migration file** — never an ad-hoc `ALTER` or a hand-edited schema dump. The AI still writes all the DDL; only the artifact is constrained. See `sop/Database_SOP.md`.
4. **Validate concreteness.** A Migration Plan with "TBD" on rollback or authorization that would force the planner to guess is a blocker — resolve it now or mark it in Risks & Open Questions for the Phase 4 walk-through. "Irreversible — data loss on revert" is a *valid* rollback answer; an empty one is not.

This is the spec-time half of gap #1's artifact rule. The Spec Review Agent (`templates/spec_review_skill.md` § Migration Rule) independently blocks a schema-touching spec that reaches review without a concrete plan, and `/verify` runs a migration-review subagent on the diff — but catching it here, before publish, saves a review round-trip.

### Phase 4 — Present and Iterate

1. Show the draft spec to the user.
2. **If the spec has any items in `## Risks & Open Questions`** — walk through them interactively before publishing:

   ```
   This spec has N open question(s). Walk through with recommendations? (default Y)
   ```

   If yes (default), **for each open question**, call the `AskUserQuestion` tool — one question per call so each gets its own dialog. Structure:

   - `header`: short chip (≤12 chars) summarizing the question topic — e.g., "Save view"
   - `question`: the full question, ending with `?`
   - `options`: 2–4 mutually-exclusive choices. **First option is your recommendation** with `(Recommended)` suffix on the label. Each option's `description` carries the reasoning + trade-off (1–2 sentences).
   - The "Other" option is auto-provided by the tool — do not include manually.

   Standard option set per question (adapt as needed):

   | Label | Description |
   |---|---|
   | `<recommended action> (Recommended)` | Why this is the best fit + the trade-off the user accepts by picking it. |
   | `Keep as TBD` | Leave in Risks & Open Questions; defer to planning or implementation. |
   | `Drop / out of scope` | Remove from this spec entirely. Use when the question reveals the item shouldn't ship in this issue. |

   Add a fourth option only when there's a genuinely distinct alternative to the recommendation (e.g., "Persist now" vs "Persist later") — don't pad to four.

   **After the user answers**, edit the spec inline:
   - **Recommended / different answer:** move the question from Risks & Open Questions to Decisions, with the chosen path as the resolution
   - **Keep as TBD:** leave it in Risks & Open Questions; mark `[TBD]`
   - **Drop / out of scope:** remove the related Requirements/AC entries; note in Notes that the item was dropped

3. Re-present the updated spec (one final read-through) with the new Decisions section visible.
4. Ask: _"Want to refine anything else before I push this to Linear?"_
5. Iterate until the user approves.

**Why interactive walk-through:** open questions left in the spec body get visually skimmed and silently shipped as "implicit." Forcing each through `AskUserQuestion` turns every TBD into a deliberate decision (committed / deferred / dropped) — same lesson family as the behavioral-AC discipline above. No question gets lost in prose.

### Phase 5 — Publish to Linear

1. **Update or create** the Linear issue via `mcp__linear-server__linear_updateIssue` (existing) or `mcp__linear-server__linear_createIssue` (new):
   - `team`: `{team from method.config.md}`
   - `title`: concise spec title (prefix with domain if useful, e.g., "Budget: Multi-currency support")
   - `description`: the full light spec (markdown)
   - `state`: the configured **`Spec ready state`** — read it with `pk config "Spec ready state" "Specced"` (default `Specced`). This is the state `pk spec-cycle` requires on entry (Phase 6), so publishing to it keeps the interlock intact on **any** board. Projects whose Linear workflow has no `Specced` column set `Spec ready state` to a state they *do* have (e.g. `Needs Spec`); hardcoding `Specced` here would try to set a nonexistent state and break the cycle.
   - `priority`: ask user (default 0/None if unsure)
   - `project`: suggest based on Phase 2 findings, confirm with user
   - `labels`: **merged list**: `[...existing_labels_minus_old_tier, 'spec', '<tier-from-Phase-3.6>']`
     - Pull `existing_labels` from Phase 1's `linear_getIssueById` payload (new issues → empty list).
     - Strip any pre-existing `tier:quick | tier:standard | tier:heavy` label — the Phase 3.6 derivation replaces it. Other labels (`Feature`, `Finance`, domain tags, etc.) are preserved.
     - Linear's `linear_updateIssue` replaces the labels list wholesale; passing the full merged set is required.
2. Store the issue ID for reference.

**Why the merge:** `linear_updateIssue` doesn't support add/remove deltas — pass it the desired final state. Pulling the existing label list in Phase 1 and merging here means custom human-applied labels (e.g., `Finance`, `Customer-impact`) survive the publish. Stale `tier:*` labels are explicitly stripped so the Phase 3.6 derivation is authoritative — if the user re-runs `/light-spec PROJ-XXX` after raising the Complexity, the tier label updates accordingly.

### Phase 6 — Spec Review Cycle (automated)

Enter the cycle automatically once Phase 5 publishes. Do **not** prompt the user before pass 1 — the cycle is the whole point of `/01-light-spec`. The cycle calls `pk spec-cycle`, which owns the agent trigger, the polling, and the state transition on Pass — so this skill never posts the `@linear` comment directly.

The user can opt out only by interrupting (Ctrl-C). Confirmation prompts appear on passes 2 and 3 inside the loop below — that is the designed bail-out point.

**Cycle (max 3 passes):**

```
pass = 1
loop:
  bash: pk spec-cycle PROJ-XXX
  read pk's last "VERDICT: <X>" line and exit code

  case VERDICT:
    Pass       → done. pk has set the issue state to the configured
                 "Spec approved state" (default: Approved). Tell the user:
                   "✓ Spec approved on pass {pass}. ➜ next: pk branch PROJ-XXX"
                 EXIT.

    Revise     → invoke /02-light-spec-revise PROJ-XXX.

                 Pass-aware confirmation:
                   - pass == 1: auto-invoke. No prompt.
                   - pass >= 2: show the agent's blocker count and readiness
                     score, then prompt: "Continue to /02? [Y/n/o]"
                       Y → invoke /02
                       n → exit, leave issue in the spec-ready state
                       o → invoke /02 with override directive (the user wants
                           to override the agent verdict, not patch the spec)

                 After /02 returns, increment pass and loop.

    Stalemate  → pk's 3-comment guard fired before triggering. Tell the user:
                   "Agent already reviewed 3x — likely stalemate. Run
                    /02-light-spec-revise PROJ-XXX with the override path."
                 EXIT.

    Timeout    → no agent response in 5 min. Tell the user:
                   "Agent didn't respond. Inspect Linear UI; rerun
                    /01-light-spec PROJ-XXX when ready."
                 EXIT.

    Malformed  → tell the user the agent comment couldn't be parsed and
                 point them at Linear UI. EXIT.

  if pass == 3 and verdict was Revise:
    Tell the user: "3 passes complete. /02 has the override path if the
    agent is stuck — rerun /02-light-spec-revise PROJ-XXX."
    EXIT.

  pass += 1
```

**Why `pk spec-cycle` and not an inline MCP comment:** centralizes the Linear-agent trigger format in one place (so a Linear product change is one fix, not many), keeps the polling out of Claude's context window, and matches the rest of the `pk` CLI surface.

**State preconditions:** `pk spec-cycle` refuses to run if the issue is not in the configured "Spec ready state" (default: `Specced`). Phase 5 of this skill sets that state, so the precondition holds on entry.

### Phase 7 — VBW Ingestion Pointer

Tell the user how to proceed:

> **Next steps:**
> - To flesh this out into a full VBW plan: enter planning mode and reference this issue
> - To batch-process with other specced issues: `/linear-todo-runner` (requires Acceptance Criteria section)
> - To refine further: `/light-spec PROJ-XXX` to iterate

---

## Light Spec Template

Read the canonical template from `templates/light_spec_template.md` in the method repo (or `pipekit/templates/light_spec_template.md` in consuming projects). Use that template structure for all specs.

---

## How This Connects to VBW

The light spec is designed so VBW's planning agents can consume it directly:

| Light Spec Section | VBW Plan Section |
|--------------------|-----------------|
| Problem + Goal | `<objective>` |
| Proposed Solution | `<objective>` approach description |
| Scope | Plan scope boundaries + `forbidden_commands` |
| Decisions | `must_haves.truths` (defined) or research tasks (TBD) |
| Requirements | `must_haves.truths` |
| Acceptance Criteria | `<verify>` + `<done>` per task, `<success_criteria>` |
| Technical Context + Authority | `<context>` + `files_modified` |
| Risks & Open Questions | Research tasks (`type: research`) in the plan |
| Complexity | `effort_override` (Low→expedited, Med→standard, High→thorough) |

When entering planning mode, reference the issue:
> "Plan PROJ-XXX using the light spec in its description. Resolve open questions, break into tasks, and generate a PLAN.md."

The VBW lead agent will read the Linear issue, extract the spec, and use it as the foundation for task decomposition.

---

## Complexity Guidelines

Same as `/brainstorm`, but with planning implications. Phase 3.6 maps these to `tier:*` Linear labels automatically.

| Complexity | Planning implication | Auto-derived tier (v2.7.0-rc1+) |
|---|---|---|
| **Trivial** | Single-step change, no decomposition. Often a typo/copy/rename. | `tier:quick` |
| **Low (~2-4h)** | Can skip full VBW planning — spec is sufficient for `/linear-todo-runner` to pick up directly if AC section is complete. | `tier:quick` |
| **Medium (~6-10h)** | Benefits from a single VBW plan (1 PLAN.md). The light spec provides enough for the lead agent to generate tasks. | `tier:standard` |
| **High (~12-20h+)** | Likely needs multiple VBW plans across a phase. The light spec seeds the architect agent's phase decomposition. | `tier:heavy` |
| **Very High / Critical** | Cross-phase, cross-team, or migrates load-bearing infrastructure. Always heavy. | `tier:heavy` |

The auto-derived tier feeds into:
- `/work` Steps 3/4/6/7 (plan strictness, security review, hand-off behavior — per v2.6.0 tier reinstatement)
- `/verify` Step 0.5 dispatch (evidence layer + reality-check for tier ≥ standard; verify-complete sentinel on PASS for every tier, quick a minimal virtual one)
- `/verify` Step 5 (mandatory antagonistic review on heavy; auto-fires on sensitive-path diffs for standard)
- `pk ship` verify-complete.md gate (hard-fail on any tier without a verify-complete.md whose sha matches HEAD)

If you disagree with the auto-derivation, change the Complexity field in the spec body and re-run `/light-spec PROJ-XXX` — the tier label will refresh on the next publish.

## Red Flags

Thoughts that mean "slow down and widen scope." Paired with `.claude/rules/pipekit-discipline.md`.

| Flag | What it actually means |
|------|------------------------|
| "The AC is short because the feature is simple" | Short AC = high risk of planning-time ambiguity. Simple features are where "obvious" behavior diverges between spec author and planner. Be explicit. |
| "The user said they want X, so I'll just write that" | The spec has to be decomposable without guessing. If you'd have to guess a decision, mark it `[TBD]` and ask — don't paper over. |
| "The POC shows the answer already" | POC is reference, not spec. Translate observable behaviors into testable requirements; don't assume the planner reads POC code. |
| "Authority is obvious from context" | It isn't. Specs without an explicit authoritative layer (DB, utils, API) are the #1 cause of spec revision. Name it. |
| "I'll skip the review agent, the spec is clear" | Clear-seeming specs fail planning review most often — the clarity is in your head, not on the page. Run the review. |
| "AC says `<Component> exists` and that's enough" | Presence ≠ behavior. The thing under test is what the user sees and does. Replace with behavioral AC: input → expected output, observable in the running app. |
| "AC says `onSave callback fires`" | Mock-tests are not user-tests. Add an end-to-end AC: data persists, UI reflects, page reload shows it. |
| "Integration into `<other-file>` is implied" | Implicit integration steps were the RS-64 miss. If the spec touches one component but requires updating another to use it, name the second update as an explicit AC. |
| "Visual matches figma" (without measurable check) | Unmeasurable. Replace with: pixel-diff threshold (e.g. < 5% at 1440px), or computed-style assertions on key tokens, or both. |

---

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Skipping codebase exploration** → When uncertain whether exploration is needed, explore. Assumptions about what exists are wrong more often than right.
- **Leaving authority implicit** → Define it explicitly. Ambiguous authority is the #1 cause of spec revision.
- **Vague acceptance criteria** → Apply the litmus test: can the planner verify each criterion without guessing what "works correctly" or "handles properly" means? Every criterion needs a concrete, observable outcome.
- **Implicit decisions** → Put it in the Decisions section (defined or `[TBD]`). Context is not a contract — downstream agents can't read your mind.
- **Assuming API behavior** → Check the installed version. Training data may not reflect the project's actual dependencies.

## Next-step output

After the spec is drafted and posted to Linear, emit an inline `➜ Next:` line in your terminal output pointing to `pk branch {issue-id}` if the spec is approved (the user will then `/work {issue-id}` from inside the worktree), or the next spec to draft if this one is still pending human review. Do **not** write a `NEXT.md` file — v2 retired the mirror; `pk next` reads "what's next?" live from Linear.

## Related Skills

- `/brainstorm` — lighter: feasibility-only, no structured spec
- `/sync-linear` — syncs VBW ↔ Linear after plans exist
- `/linear-todo-runner` — executes specced issues in parallel (requires AC section)
- `/spec-validator` — validates full Strategy docs (heavier than light specs)
