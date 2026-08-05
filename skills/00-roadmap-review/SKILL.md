---
name: roadmap-review
description: Audit roadmap health — issues, dependency order, spec coverage, doc freshness. Use when speccing a new initiative. Use when /phase-plan output looks suspicious. Use before /roadmap-create reruns.
---

# Roadmap Review Skill

**v4.15.0** — Last updated: 2026-07-14 *(add **Phase 2.5 — Roadmap Progress Reconciliation**: report-only checkbox ↔ Linear `Done` check, gated on the roadmap source using `- [ ]`/`- [x]` checkboxes (independent of the phase-label layer); flags both drift directions, never writes the human-owned roadmap file. Carries v4.14.0: the optional, config-gated **Phase-Label Layer** check — new **Phase 3.5** — mirroring `ROADMAP.md`'s per-phase build order + parallelism onto the Linear board via labels + saved views + `sortOrder` + `blockedBy`, drift-checked against `ROADMAP.md`. No-op unless that section is *filled in* (the template ships it commented out — gate on active values, not the bare heading), so it's fully portable. Carries v4.1.0: validate the Linear-native initiative surface — order lives in `i{N}.`/`I{N}.P{N}.` names per `method.config.md` § Initiative Surface, not in a committed phase file)*

You are a roadmap health auditor. Your job is to run a comprehensive health check of the overall plan. Read `method.config.md` for project context — including the **§ Initiative Surface** contract that defines the Linear-native initiative model this skill validates. Run this before speccing a new initiative to ensure the roadmap is coherent and complete.

## Triggers

- `/roadmap-review`
- "review the roadmap"
- "check the plan"
- "roadmap health"

## Purpose

Validate that:
1. **Stage 0 outputs exist** — concept, definition, strategy docs, roadmap, Linear initiative hierarchy
2. The **Linear-native initiative surface is well-formed** — `i{N}.` initiatives and `I{N}.P{N}.` projects are correctly named, ordered, and placed (see § Initiative Surface in `method.config.md`; projects carry their initiative number — bare `P{N}.` is legacy-valid but a rename candidate)
3. Every requirement is placed in an `I{N}.P{N}.` project — no orphan issues that should live in an initiative
4. Dependencies and blockers are set correctly
5. Workflow states are consistent with dependency ordering
6. Spec coverage is adequate for the next planned initiative
7. Strategy docs are flagged if stale
8. **(Optional)** The **phase-label layer mirrors `ROADMAP.md`** — if `method.config.md` has a *filled-in* `### Phase Label Layer` section, the phase/pool labels, `sortOrder`, and `blockedBy` relations on the board match the roadmap's curated order (Phase 3.5; skipped entirely when the section is absent or still commented out)
9. **(Optional)** The **roadmap's checkboxes match Linear `Done` state** — if the roadmap source uses `- [ ]` / `- [x]` progress checkboxes, they reconcile with reality (Phase 2.5; report-only, skipped when the roadmap has no checkboxes)

This is the **gate between Stage 0 (Foundation) and Stage 1 (Definition)** in the Pipekit pipeline. Run it before starting a new initiative of specs.

## Execution Steps

### Stage 0 Check — Foundation

Validate that pre-pipeline outputs exist. If any are missing, report which skill to run.

| Check | Surface | If Missing |
|-------|---------|-----------|
| Concept brief | `concept-brief.md` | Run `/concept` |
| Project definition | `project-definition.md` | Run `/define` |
| Strategy docs | `Strategy/` matching `method.config.md` manifest | Run `/strategy-create` |
| Roadmap source | the `Roadmap source` file with content (optional — strategy docs are the live source) | Run `/roadmap-create` |
| Phase initiatives | At least one Linear delivery initiative named `i{N}.` exists | Run `/roadmap-create` |
| Phase projects | The current initiative has at least one `I{N}.P{N}.` project (legacy bare `P{N}.` also counts) | Run `/roadmap-create` |
| Linear board | Issues exist, placed in `I{N}.P{N}.` projects | Run `/roadmap-create` |

The initiative surface lives in **Linear**, not in a file: an initiative named `i{N}. label` is an ordered INITIATIVE; a project named `I{N}.P{N}. label` is an ordered SUB-PHASE (it carries its initiative number; legacy bare `P{N}.` still parses); issues live in projects. There is no committed phase-file mirror — do not assert one exists.

If any Stage 0 check fails, report it prominently at the top of the health report:

```
## Stage 0: Foundation — Incomplete

Missing:
  - concept-brief.md → run /concept
  - no `i{N}.` delivery initiatives in Linear → run /roadmap-create

Complete Stage 0 before entering the spec pipeline.
```

If all Stage 0 checks pass, continue to the next check.

### Phase 1 — Gather State

Linear is the source of truth for the initiative surface. Read it live; there is no committed phase-file mirror to consult.

1. (Optional) Read the `Roadmap source` file for the strategy-derived requirements list, if present. Strategy docs are the live requirement source.
2. Fetch all initiatives via `mcp__linear-server__linear_getInitiatives`. Partition them:
   - **Delivery initiatives** = names matching `^i(\d+)\.` — these are the ordered INITIATIVES.
   - **Strategic initiatives** = unprefixed names — themes, not initiatives; carried into Phase 2's strategic-initiative check.
3. Determine the **current initiative** = the lowest `i{N}` delivery initiative whose status is not `Completed`.
4. For each delivery initiative (current + next-up), fetch projects via `mcp__linear-server__linear_getProjects`. Projects named `^P(\d+)\.` are the ordered SUB-PHASES; `{N}` orders them within the initiative.
5. Determine the **current sub-phase** = the lowest `P{N}` project (within the current initiative) whose state is not in {`completed`, `canceled`}.
6. For each project, fetch issues via `mcp__linear-server__linear_searchIssues`.

Throughout: order comes from the integer in the `i{N}.` / `P{N}.` name prefix (numeric), **never** from Linear's `sortOrder` field.

### Phase 2 — Completeness Check

Source the requirements list from the strategy docs (the live source) or, if present, the `Roadmap source` file. For each initiative (`i{N}.` initiative):

1. Extract the requirements that map to this initiative
2. Match each requirement to Linear issues by:
   - Title keyword matching
   - Project assignment (requirement area → `P{N}.` project)
   - Description cross-references
3. **Gaps:** Requirements with NO matching issue → these need issues created
4. **Orphans:** Issues with NO matching requirement → flag for review (may be valid additions from brainstorming, or may be misassigned)

Output: Completeness table per initiative (`i{N}.`).

### Phase 2.5 — Roadmap Progress Reconciliation (checkbox ↔ Linear `Done`)

**Skip this phase unless the roadmap source uses checkboxes.** Some projects track build progress with markdown checkboxes in their roadmap file — the `Roadmap source` key (`method.config.md § Initiative Surface → Roadmap source`; blank → the root `ROADMAP.md`). If that file has no `- [ ]` / `- [x]` items, no-op and proceed to Phase 3. This check is **independent of the phase-label layer** — a project can have a checkboxed roadmap without opting into the label layer, so it is *not* gated behind the `### Phase Label Layer` config, and the key deliberately lives outside that section's commented block (v4.28.0) so retiring the layer can't silently repoint this reconciliation.

When the roadmap source has checkboxes, reconcile both directions against Linear (using the issue states already fetched in Phase 1). This catches a roadmap file drifting from Linear reality — the two are edited by different hands at different times:

- **Checked but not Done** — the roadmap shows `- [x]` for an issue whose Linear state is **not** `Done` (reopened, still in flight, or the box was ticked prematurely) → flag. A checked box asserts "shipped"; if Linear disagrees, one of them is wrong.
- **Done but unchecked** — an issue is `Done` in Linear but the roadmap still shows `- [ ]` → flag; the roadmap is stale, the box wants ticking.

**Report-only — never auto-fix.** The roadmap file is **human-owned** (`method.md § Initiative Surface Ownership` — skills never write `ROADMAP.md`), and a checkbox mismatch is ambiguous about *which* side is right (a `[x]`-but-not-`Done` could mean the issue reopened, not that the box is wrong). So surface both lists and let the human resolve — tick the box, reopen the issue, or correct the state. Do **not** edit the roadmap file and do **not** flip a Linear state from a checkbox.

Output: a Roadmap Reconciliation section (Phase 8) listing each mismatch with its direction.

### Phase 3 — Initiative Surface Well-Formedness

This is the core Linear-native validation. The initiative surface (per `method.config.md` § Initiative Surface) is: delivery initiative `i{N}. label` = ordered INITIATIVE; project `P{N}. label` = ordered SUB-PHASE within its initiative; issues live in `P{N}.` projects. Validate that this structure is well-formed:

**Initiative naming & order:**

1. Every delivery initiative is named `i{N}.` where `{N}` is an integer. Flag any initiative that looks like an initiative (has delivery projects/issues under it) but is missing the `i{N}.` prefix — it would be silently treated as a strategic theme and dropped from the initiative walk.
2. The `{N}` values are **unique** across delivery initiatives (no two `i2.` initiatives) and ordered (contiguous `i1, i2, i3…` is ideal; a gap is a warning, a duplicate is an error).

**Project naming & order:**

3. Every project under a delivery initiative is named `I{N}.P{N}.` (its initiative number + an integer `P{N}`); a bare `P{N}.` is legacy-valid but a rename candidate.
4. The `{N}` values are **unique within their initiative** (no two `P3.` projects in the same `i{N}.`). Duplicates are an error; gaps are a warning.

**Issue placement:**

5. Every requirement/issue that belongs to an initiative is placed in a `P{N}.` project. Flag **orphan issues** — issues attached directly to a delivery initiative with no project, or issues in an unprefixed project under a delivery initiative — that should live in a `P{N}.` project.

**Lifecycle sanity:**

6. The **earliest non-`Completed` delivery initiative** (the current initiative, by lowest `{N}`) has status `Active`. Flag if it is still `Planned`/`Backlog` (work has nowhere to land) or if multiple delivery initiatives are simultaneously `Active`.
7. Within that current initiative, its **earliest live project** (lowest `P{N}` whose state is not `completed`/`canceled`) is `started`. Flag if the current sub-phase is still `planned`/`backlog`.

**Strategic-initiative intent:**

8. For each **unprefixed** (strategic) initiative, confirm it is *intentionally* a theme, not an accidentally-unprefixed initiative. Heuristic: a strategic initiative with active delivery projects/issues under it is suspicious — surface it and ask the user to confirm it should be ignored by the initiative walk, or rename it `i{N}.`.

**Within-issue assignment (secondary):**

9. For issues in the current and upcoming phases, verify labels are consistent (Tier label matches phase intent, Domain label matches the `P{N}.` project cluster) and flag misassignments.

**Lanes-model health** *(skip these when `method.config.md § Area Labels` is blank — the board isn't on the lanes model)*:

10. **Pool smell.** Any `I{N}.P{N}.` project holding more than the `Lane size` upper bound (default 8) open issues. A lane is a completable batch; a project that keeps accepting work is a pool, and the walk cannot see inside it — so `pk status` will name an idle lane while the live work is invisible. Report the count and the gap. *(Anchor: SiteLine, 2026-08-02 — 98 of 162 open issues in three pool projects, `In Progress` at 0.)*
11. **Spent lanes.** A project with 0 open issues whose state isn't `completed`/`canceled` — it stays "current" forever. **Exempt** any project whose `description` contains the literal word `placeholder`.
12. **Walk-skip hazard.** A non-`Completed` initiative whose projects are *all* completed/canceled and which has **no placeholder project**. The walk steps past it as though it were finished. This is the single highest-consequence lanes-model defect: an entire release phase silently disappears from `pk next`.
13. **Status drift.** Lanes holding shipped or in-flight issues while still `planned`/`backlog`; idle lanes marked `started`. Initiatives: phases before the current one `Completed`, the current one `Active`, later ones `Planned` — with the honest exception of a genuinely in-flight parallel strand, which may be `Active` alongside the arc.
    - Objective wrong-closure sweep: `projects(filter:{status:{type:{in:["completed","canceled"]}}})` each with `issues(filter:{state:{type:{nin:["completed","canceled"]}}})`. Any hit other than a `Duplicate`-state issue is rot. **Filter server-side** — an unfiltered all-projects × all-issues read exceeds Linear's 10k query-complexity cap and is rejected (`sop/Linear_SOP.md` § API gotchas → Query complexity).
14. **Unclassified backlog.** Project-less issues carrying no `Area:` label — invisible to both the walk *and* the backlog views. Route to `/linear-hygiene`.
15. **Lane serialization notes present.** Each active lane's `content` body should say what runs in sequence and what's parallel-safe. Absent notes aren't an error, but a lane with real `blockedBy` chains and no explanation is a lane only its author can run. (Notes belong in `content` — `description` caps at 255 chars.)

Output: an Initiative Surface section listing any naming/order/placement/lifecycle violations, each with the exact rename or re-parent to apply. Lanes-model findings route to `/phase-plan --cut` (pools, tails) or `/linear-hygiene` (classification) — this skill reports, it doesn't restructure.

### Phase 3.5 — Phase-Label Layer (optional; config-gated)

**Skip this phase entirely unless `method.config.md` has a *filled-in* `### Phase Label Layer` section.** The template ships that section with its config table **commented out**, so the mere heading is not the signal — gate on the *active label/view values* (e.g. an uncommented `Sequenced phase labels` row). Table commented or cells blank → no active config → no-op, proceed to Phase 4. The layer is opt-in: a *visualization mirror* of `ROADMAP.md`'s hand-curated build order onto the Linear board, for projects whose roadmap **phases span multiple `I{N}.P{N}.` projects** (so no single Linear project *is* a phase, and a plain project filter can't render "this phase, in order").

This layer is **additive**, not a replacement. It sits beside the two surfaces this skill already validates:

| Surface | Answers | Lives in |
|---|---|---|
| `i{N}.`/`I{N}.P{N}.` initiative surface (Phase 3) | "What's the current initiative / sub-phase?" | Initiative + Project names |
| **Phase-label layer (this phase)** | **"What order do I run these in — what's parallel?"** | Labels + saved views + `sortOrder` + `blockedBy` |
| `ROADMAP.md` | Human-readable narrative source of truth | A committed file |

The label layer **owns no state `ROADMAP.md` doesn't already assert** — so this phase is a drift check *of the mirror against the file*, nothing more.

**A board on the lanes model must not adopt this layer, and must not be offered the bootstrap below.** The layer exists for boards whose phases span multiple projects. On the lanes model phases ≡ initiatives, so the `i{N}.`/`P{N}.` prefixes already carry the order and these labels would encode it a second time — two mirrors of one ordering, drifting apart. That is the exact failure the lanes model removes. Detect the shape from config: `§ Area Labels` filled in → lanes model → no-op this phase regardless of anything else. (Retiring an existing layer has an order-sensitive path — comment the config table *first*, or this phase re-scaffolds what you delete; see `sop/Linear_SOP.md § Board shapes`.)

**Read the convention from config — hardcode nothing.** The `### Phase Label Layer` section names, per project:
- the **roadmap source file** — the `Roadmap source` key (`§ Initiative Surface → Roadmap source`; blank → the root `ROADMAP.md`). Read *that* file's per-phase issue lists as the source of truth; never hardcode the path. This is the same file the Stage-0 check and Phase 1 locate, so the layer and the audit stay on one roadmap. **The key lives outside this section's commented block on purpose** (v4.28.0) — Phase 2.5 reads it independently, so retiring the layer must not repoint the reconciliation.
- the **phase/pool label set** — e.g. `Roadmap: Phase A`, `Roadmap: Phase B`, `Roadmap: Continuous`. Derive the actual phase names from the roadmap source file's own headings (a project may letter phases, number milestones, use quarters — never assume "Phase A/B/C"). Config marks which labels are **sequenced phases** vs the standing **Continuous pool**.
- the **order label** — e.g. `Order: Any` — marking an issue with no intra-phase dependency (safe to run anytime / in parallel).
- the **saved-view convention** — one ungrouped, Manual-sorted saved view per label. *(Views are **created** at scaffold time — by `/roadmap-create` at authoring, or by this phase's **bootstrap** on an existing board — but are **not drift-checked** once they exist: this phase verifies label membership, `sortOrder`, and relations against the roadmap, not the ongoing state of a view. A later deleted/renamed view won't flag.)*
- the **`sortOrder` step** — the `sortOrder` step key (default 1,000): the numeric gap between adjacent issues, leaving slack to insert later without a full renumber.

**Materialization check — is the layer scaffolded yet? (the retrofit path).** Before drift-checking, determine whether the layer's infrastructure exists on the board. List the team labels and the saved views (`linear_getSavedViews`) and compare against the configured label/view set:

- **Scaffolded** — every configured phase/pool label exists as a team label and each has its saved view → skip to the drift checks (A–D).
- **Un-scaffolded** — none of the configured labels exist and there are no matching views → this is a **first-time retrofit**: rolling the layer onto an *existing* board (the rs-vault / Piper case — a project that already has a roadmap but never had the layer). Offer to **bootstrap** it (below).
- **Partial** — some labels/views exist, some don't → bootstrap **only the missing infrastructure** (the absent labels + views, steps 1 & 5 below). Leave membership, `sortOrder`, and relations to the drift checks (A/B/D): a partially-populated board needs *reconciliation* (adds **and** removes), which is what A–D do — not the blind all-creates that only make sense on a from-nothing board.

**Bootstrap — one-time scaffold onto an existing board.** This is the same create path `/roadmap-create` Phase 3.5 runs at initial authoring, re-homed here so an *established* board can adopt the layer without hand-building it (the layer was originally hand-built on SiteLine; this closes that gap). It has its **own explicit confirm** — present a **scaffold plan**, apply on `go` — because it's a distinct one-time operation that includes writes (view creation, `sortOrder` seeding) the end-of-skill drift prompt doesn't cover. The full six-step create below runs on a fully **un-scaffolded** board (all-creates, one `go`); on a **partial** board bootstrap runs only steps 1 & 5 (missing labels + views) and the drift checks own the rest. On `go`:

1. **Create missing labels** — `linear_createTeamLabel` for each sequenced phase label, the Continuous pool label, and `Order: Any` (only the ones that don't already exist).
2. **Apply membership** — label each issue by the phase the roadmap source places it under. Continuous is **named-items-only** (§A's rule applies — never bulk-label a whole project).
3. **Seed `sortOrder`** — set each issue's `sortOrder` to the roadmap's top-to-bottom order within its phase, stepped by the `sortOrder` step key. **A seed of an unset value applies on the bootstrap confirm** — this is distinct from check B's flag-only *reorder*: seeding a blank order from the roadmap *is* the materialization; rewriting an already-curated order is the human-intent call B guards. Only seed issues whose `sortOrder` isn't already meaningfully set.
4. **Create relations** — a `blockedBy` relation for each intra-phase dependency the roadmap names (§D).
5. **Create views** — one ungrouped saved view per label (`linear_createSavedView`; read an existing view's `filterData` first — §Tooling).
6. **Hand-off step (not optional to report):** tell the human to toggle each new view to **Manual sort** in the Linear UI — it's not settable over MCP, and until they do, the seeded `sortOrder` won't render. Report this as a *pending human step*, never as "views done."

After bootstrap the drift checks below are a no-op on a freshly-scaffolded board; on a partial one they reconcile whatever bootstrap didn't create. A project whose phases map 1:1 to projects shouldn't be here at all — it has no `### Phase Label Layer` config, so Phase 3.5 already no-opped.

Run these checks (all report-only — fixes fold into the end-of-skill fix prompt):

**A. Membership drift.** For each phase/pool `ROADMAP.md` names, diff the issue identifiers it lists against current Linear label membership (`linear_searchIssues` filtered by the label). Report:
- **Missing label** — `ROADMAP.md` lists the issue under a phase but the issue lacks the label → propose add.
- **Stray label** — the issue carries the label but `ROADMAP.md` doesn't list it under that phase → propose remove. *(This is the Bug-1 failure mode: a `Roadmap: Phase X` label picked up as a side effect of a re-parent, not asserted by the roadmap — see the `/linear-hygiene` guardrail. Project membership ≠ phase-label membership.)*
- **Continuous is named-items-only.** Only issues `ROADMAP.md` names by identifier get the pool label. **Never** propose labeling every open issue in the pool's projects — a phase-arc project deliberately holds a mix of phase-labeled work and unitemized capacity-fill the roadmap leaves unordered. Labeling the whole project would invent priority the roadmap doesn't assert.

**B. `sortOrder` monotonicity.** Within each label, verify `sortOrder` is monotonic in `ROADMAP.md`'s top-to-bottom listed order. **Flag out-of-order pairs — do NOT auto-fix.** Reordering is a human-intent call; surface it and let the user confirm before any `linear_updateIssue` rewrites `sortOrder`.

**C. Exclusivity + dependency consistency.**
- No issue carries **two** `Roadmap: Phase *` labels — an issue lives in one sequenced phase (or the pool), not two. Flag conflicts.
- No issue carries **both** `Order: Any` **and** an unresolved `blockedBy` relation — "any order" and "blocked by X" contradict. Flag; the human resolves which is true.

**D. Dependencies are relations, not prose.** Intra-phase sequential order must be real `blockedBy` relations, never prose in a description (nothing enforces or surfaces prose). If `ROADMAP.md` narrates "X before Y" within a phase but no `blockedBy` relation exists, flag the missing relation. *(This overlaps Phase 4 — if Phase 4 already caught it, report it once, don't double-count.)*

**Propose-then-apply.** Two confirm surfaces, kept separate:
- **Bootstrap** (materialization on an un-scaffolded / partial board) has its **own** scaffold-plan confirm inside this phase — it creates labels + views, seeds `sortOrder`, and applies membership + relations in one `go`.
- **Drift** (A–D on an already-scaffolded board) folds into the skill's existing "Want me to fix any of these now?" prompt (`linear_addIssueLabel` / `linear_removeIssueLabel` / `linear_createIssueRelation`).

`sortOrder` handling differs by surface: **seeding** an unset order during bootstrap applies on the bootstrap confirm; **reordering** an already-set order (check B) stays **proposal-only** — never auto-applied.

> **Tooling (verify against your installed MCP — a fast-moving, partly-undocumented surface, exactly what `pipekit-tooling.md`'s verify-installed-API rule is for):**
> - Add/remove issue label: `mcp__linear-server__linear_addIssueLabel` / `linear_removeIssueLabel`. Create a missing phase label: `linear_createTeamLabel` (`teamId`, `name`, `color`).
> - Saved views: `linear_createSavedView` uses an **undocumented internal `filterData` DSL** — **read an existing saved view first** (`linear_getSavedViews`) to confirm the current shape before authoring one. Example label filter: `{"and":[{"labels":{"and":[{"or":[{"name":{"eq":"Roadmap: Phase A"}}]}]}}]}`.
> - `sortOrder` is a plain number on `linear_updateIssue` (lower sorts first) but **only renders in a view's Manual sort mode**, which a human must toggle in the Linear view UI — it is **not** settable over MCP. This skill sets labels + `sortOrder` *values*; the Manual-sort toggle is a one-time human step, so say so rather than reporting the view "done."
> - Relations: `linear_createIssueRelation` (`blockedBy` / `blocks`).
> - **Payload watch-out (same as `/linear-hygiene`):** a `linear_searchIssues` sweep across a project's several phase-arc projects can exceed one context. Dispatch a grounding-tier subagent (per `method.config.md § Model Policy`, default `haiku`, effort `low`) to digest and return a condensed `{identifier, phase-label, sortOrder}` table rather than pulling raw payloads into the skill context.

### Phase 4 — Dependency Validation

1. Read light specs for issues that have them — extract dependency contracts (e.g., "PROJ-8 is a hard blocker for PROJ-7")
2. Read the WP dependency graph from `pipekit/sop/Linear SOP.md` (Dependency Graph section)
3. For each declared dependency:
   - Fetch the issue via `mcp__linear-server__linear_getIssueById` with `includeRelations: true`
   - Check that `blockedBy`/`blocks` relations exist in Linear
4. Flag missing dependency links with the exact relation to add
5. Flag circular dependencies

### Phase 5 — Ordering Validation

For each issue that has blockers:

1. Fetch blocker issue status
2. Apply ordering rules:
   - If blocker is in Ideas/Future Phases/On Deck/Needs Spec → blocked issue should NOT be in Approved/Building/In Progress
   - If blocker is in Done → the blocked issue is free to progress
   - If blocker is in Canceled → flag for review (is the dependency still relevant?)
3. Flag ordering violations with recommended state changes

### Phase 6 — Spec Coverage

For the next planned initiative (issues in On Deck/Needs Spec/Specced in the current `i{N}.` initiative's live `P{N}.` projects):

1. List all issues that would enter the pipeline
2. For each issue, check spec status:
   - **No spec:** description is bare or uses old template format
   - **Has light spec:** description contains `## Light Spec` header
   - **Agent reviewed:** description contains `## Agent Review` with a verdict
   - **Agent passed:** Agent Review verdict is "Pass"
   - **Human approved:** issue is in Approved (past Specced)
3. Calculate readiness:
   - Total issues in phase
   - Issues with specs
   - Issues with passing agent review
   - Issues ready for planning (specced + approved)
4. List issues needing specs before the initiative can start

### Phase 7 — Doc Freshness (Light Check)

1. Read `method.config.md` to get the strategy doc manifest
2. Read version headers from all listed strategy docs to find the oldest update date
3. Query Linear for issues in Done state
4. Count features shipped since the oldest Strategy doc was last updated
5. If significant features shipped (>3) without a doc update, flag as stale
6. List which docs are most affected by shipped features
7. Recommend `/strategy-sync` if stale

### Phase 8 — Report

Present a summary dashboard:

```markdown
## Roadmap Health — YYYY-MM-DD

### Initiative Surface (Linear-native)
| Check | Result |
|-------|--------|
| Delivery initiatives named `i{N}.` | X/Y |
| Initiative `{N}` unique & ordered | OK / gaps / DUPLICATE |
| Projects named `I{N}.P{N}.` (bare `P{N}.` = rename candidate) | X/Y |
| Project `{N}` unique within initiative | OK / DUPLICATE |
| Orphan issues (not in a `P{N}.` project) | X |
| Current initiative `i{N}.` is `Active` | OK / FLAG |
| Current sub-phase `P{N}.` is `started` | OK / FLAG |
| Unprefixed initiatives confirmed strategic | X (Y need confirmation) |

**Violations:**
- Initiative "Onboarding" has delivery issues but no `i{N}.` prefix → rename to `i4. Onboarding` or confirm it is a strategic theme
- PROJ-176: attached to initiative `i2.` with no project → re-parent into a `P{N}.` project

### Lanes Health  *(only if `§ Area Labels` is filled in — otherwise omit this block)*

| Check | Result |
|---|---|
| Lanes within `Lane size` (3–8 open) | X/Y — **N pools** |
| Spent lanes (0 open, not completed) | X (placeholders exempt) |
| Initiatives at walk-skip risk (all projects done, no placeholder) | X |
| Project status mirrors reality | OK / N drifting |
| Project-less issues carrying an `Area:` label | X/Y |
| Active lanes with serialization notes in `content` | X/Y |

**Findings:**
- `I3.P4. DB hygiene batch` — 23 open (bound 8) → **pool**; `/phase-plan --cut` into 3 lanes
- `i5. Produce Ledger` — every project completed, no placeholder → **the walk will skip this entire phase**
- `I3.P2. Access truth` — 3 issues shipped, project still `planned` → set `started`
- 11 project-less issues with no `Area:` label → `/linear-hygiene`

### Phase-Label Layer  *(only if the `### Phase Label Layer` config is filled in — otherwise omit this block)*

**State:** `scaffolded` — drift-check below. *(Or `un-scaffolded → bootstrap offered` / `partial → bootstrap missing pieces + drift-check` — show the scaffold plan instead of, or alongside, the drift table.)*

**When un-scaffolded (retrofit) — scaffold plan:**
```
Bootstrap the phase-label layer onto this board? Will create:
  Labels:     Roadmap: Phase A, Roadmap: Phase B, Roadmap: Continuous, Order: Any   (4 new)
  Membership: 18 issues labelled per ROADMAP.md
  sortOrder:  seed 18 issues (step 1000)
  Relations:  3 blockedBy (intra-phase deps ROADMAP.md names)
  Views:      4 saved views (1 per label)
  ⚠ After: toggle each view to Manual sort in Linear (not settable over MCP)
Say "go" to scaffold, or redirect any line.
```

**When scaffolded — drift table + drift list:**
| Label | ROADMAP issues | Linear members | Missing | Stray | sortOrder |
|-------|----------------|----------------|---------|-------|-----------|
| Roadmap: Phase A | 7 | 7 | 0 | 1 | monotonic |
| Roadmap: Phase B | 5 | 4 | 1 | 0 | monotonic |
| Roadmap: Continuous | 6 | 6 | 0 | 0 | n/a (pool) |

**Drift:**
- PROJ-410: listed under Phase B in `ROADMAP.md`, missing `Roadmap: Phase B` → add label
- PROJ-382: carries `Roadmap: Phase A` but `ROADMAP.md` places it under Continuous → remove `Roadmap: Phase A` (stray — likely from a re-parent; see `/linear-hygiene` guardrail)
- Phase A order: PROJ-390 sorts before PROJ-388 but `ROADMAP.md` lists PROJ-388 first → **proposal only**, confirm reorder
- PROJ-415: carries both `Order: Any` and `blockedBy PROJ-412` → contradiction, resolve

### Completeness
| Phase | Requirements | Issues | Gaps | Orphans |
|-------|-------------|--------|------|---------|
| i1    | 3           | 3      | 0    | 0       |
| i2    | 18          | 81     | 2    | 5       |
| i3    | 22          | 0      | 22   | 0       |
| ...   |             |        |      |         |

**Gaps (requirements without issues):**
- i2: "Persistent AI Memory (mem0)" — no matching issue
- i2: "Slash Command Palette" — no matching issue

**Orphans (issues without matching requirements):**
- PROJ-176: "Entities blocked from 2 budgets with same name" — bug, not in roadmap

### Roadmap Reconciliation  *(only if the roadmap source uses checkboxes — otherwise omit this block)*

Report-only — the roadmap file is human-owned; resolve each by hand.

**Checked but not `Done`** (box says shipped, Linear disagrees):
- PROJ-402: `- [x]` in `ROADMAP.md` but Linear state is `In Progress` → reopened, or ticked early — reconcile

**`Done` but unchecked** (roadmap is stale):
- PROJ-388: `Done` in Linear but `ROADMAP.md` shows `- [ ]` → tick the box

*(If both lists are empty: "✓ roadmap checkboxes match Linear.")*

### Assignment
- X issues verified in correct `i{N}.` → `P{N}.` placement
- Y misassignments found (list with corrections)

### Dependencies
- X dependency relations verified
- Y missing relations (list with exact `blockedBy` to add)
- Z ordering violations (list with recommended state changes)

### Spec Coverage (next initiative: [initiative name])
| Status | Count | % |
|--------|-------|---|
| No spec | X | X% |
| Has spec | X | X% |
| Agent passed | X | X% |
| Planning-ready | X | X% |

**Issues needing specs:**
- PROJ-XXX: [title]
- PROJ-XXX: [title]

### Parked Items (trigger check)

Parked items are brainstorm dispositions marked "Later" with parseable triggers. Check if any triggers have fired.

**Step 1 — Fetch parked items:**
Use `mcp__linear-server__linear_searchIssues` filtered by the `Parked` label. For each, read the latest comment matching the parseable prefix `**Parked:** Revisit when ...`. If a parked issue has no such comment (older disposition, pre-grammar), flag it for manual review and continue.

**Step 2 — Parse the trigger per the grammar** (authored by `/brainstorm` Phase 2):

| Regex pattern | Evaluation |
|---------------|------------|
| `(\w+-\d+) ships` | Fetch that issue; trigger fires if state is `Done` |
| `Stage (\d+) UAT passes` | Fetch all issues in Stage N; trigger fires if all are past UAT (state in {UAT, Done} for the entire set) |
| `Phase (\d+) ships` | Fetch all issues in Phase N; trigger fires if all are `Done` |
| `date: (\d{4}-\d{2}-\d{2})` | Trigger fires when today ≥ the date |
| `manual` | Never auto-fires; always show under "Manual-review parked" |

**Step 3 — Present the report:**

```
### Parked Items

**Triggered (ready for re-disposition):**
| Issue | Title | Trigger | Why it fired |
|-------|-------|---------|--------------|
| PROJ-18 | AI matching | `PROJ-3 ships` | PROJ-3 moved to Done on 2026-04-20 |
| PROJ-25 | Export to PDF | `Phase 2 ships` | All Phase 2 issues Done as of 2026-04-22 |

**Not yet triggered:**
| Issue | Title | Trigger | Status |
|-------|-------|---------|--------|
| PROJ-22 | Real-time collab | `Stage 1 UAT passes` | 3 Stage 1 issues still in Building |

**Manual-review parked (no auto-trigger):**
| Issue | Title | Notes |
|-------|-------|-------|
| PROJ-30 | Gmail agent | No fit with current roadmap yet |

**Trigger parse errors (fix these):**
| Issue | Comment snippet | Action |
|-------|-----------------|--------|
| PROJ-40 | "Revisit when auth is solid" | Prose trigger — ask user for a parseable form |
```

**Triggered items** need re-disposition: either add to the current initiative via `/phase-plan --rebalance`, or revisit in `/brainstorm-review` for full Now/Later/Kill re-evaluation. Either way, the `Parked` label should be removed once the item is re-dispositioned.

**Parse errors** indicate a parked issue was disposed before the grammar was enforced or with a prose trigger. Prompt the user to update the comment to a parseable form, or accept "manual" if no concrete trigger exists.

### Strategy Doc Freshness
| Doc | Version | Last Updated | Features Since |
|-----|---------|-------------|----------------|
| {doc name from config} | vX.X.X | YYYY-MM-DD | X |
| {doc name from config} | vX.X.X | YYYY-MM-DD | X |
| ... | | | |
- **Recommendation:** Run `/strategy-sync` if any doc has >3 unsynced features

### End-to-End Check — `pk status` Roadmap walk

Run `pk status` and confirm its **Roadmap** section renders the `i{N}.` → current `P{N}.` walk correctly (current initiative, current sub-phase project, and the next issues underneath). This is the integration test for the whole initiative surface: if `pk status` resolves the current initiative to a different `i{N}.`/`P{N}.` than this audit computed, the naming/order/lifecycle is inconsistent somewhere above — reconcile before proceeding.

| Source | Current phase | Current sub-phase |
|--------|---------------|-------------------|
| This audit (lowest non-Completed `i{N}.` / lowest live `P{N}.`) | i2 | P3 |
| `pk status` Roadmap section | i2 | P3 |

A mismatch is a hard flag — fix the surface, don't proceed to spec.

### Action Items (Priority Order)
1. [Most critical action]
2. [Next action]
...
```

Ask the user: _"Want me to fix any of these issues now? I can create missing issues, rename/re-parent phase initiatives and projects, set dependency links, add/remove phase-labels to match `ROADMAP.md`, or flag items for spec generation."_ (Phase-label `sortOrder` reorders stay proposal-only — I'll list them but won't apply without your confirm.)

## Cadence

Run at these moments:
- **Before speccing a new initiative** — ensures the plan is sound before you invest in specs
- **At the start of a new initiative (`i{N}.` / `P{N}.`)** — validates the Linear initiative surface is well-formed before work lands
- **Monthly** — routine health check
- **After major scope changes** — re-validate after adding/removing features

## Related

- See `method.md` — the overall pipeline this validates
- See `sop/Linear_SOP.md` — dependency graph and workflow states
- `/strategy-sync` — runs after shipping to update Strategy docs (this skill flags staleness)
- `/light-spec` — generates specs for issues flagged as needing them
- `/linear-hygiene` — the placement janitor; it owns re-homing but **not** phase-label placement (that's Phase 3.5 here) — its guardrail keeps the two from colliding
- `method.config.md § Phase Label Layer` — the opt-in convention Phase 3.5 reads (label names, order label, saved-view + `sortOrder` conventions)
