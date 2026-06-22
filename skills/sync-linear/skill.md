---
name: sync-linear
description: Reconcile strategy-doc / requirement drift against the Linear board's i{N}./I{N}.P{N}. phase hierarchy. Use when issues are mis-placed across projects, or initiatives/projects drift from the naming convention (projects are named I{N}.P{N}.; bare P{N}. is legacy-valid). Linear is the source of truth; there is no PHASES.md/linear-map.json to sync.
---

# Sync Linear Skill

**v4.1.0** — Last updated: 2026-06-21 *(Linear-native phase surface — no PHASES.md/linear-map.json to sync. The phase order and Initiative→Project→Issue hierarchy live entirely in Linear; this skill reconciles strategy-doc and requirement drift against that board, not against committed phase files.)*

You are a Linear hierarchy reconciliation coordinator. Your job is to keep the Linear board's phase hierarchy coherent with the project's strategy docs and requirements. Read `method.config.md` for project context — specifically `## Phase Surface`, which defines the canonical model.

**Linear is the source of truth for the phase surface.** There is no planning-file mirror to push to or pull from. Phase order is encoded directly in Linear object names, not in a file and not in Linear's `sortOrder`.

## Canonical Model (Phase Surface)

Per `method.config.md` § Phase Surface:

| Linear object | Role | Order |
|---------------|------|-------|
| **Initiative** `i{N}. label` | ordered **PHASE** | integer `{N}` in the name prefix |
| **Project** `I{N}.P{N}. label` | ordered **SUB-PHASE** | the `P{N}` integer in the name prefix |
| **Issue** | individual requirement/task | lives inside the right `I{N}.P{N}.` project |

Order is the **numeric prefix** in the object name (`i1.`, `i2.`, … / the `P{N}` number). Linear's `sortOrder` is **never** used to determine phase order — always parse the name prefix. **Projects carry their initiative number** (v4.5.0+: `I1.P2. label`) so the phase reads at the project level; legacy bare `P{N}.` is still valid (`bin/pk` accepts both) — treat a bare `P{N}.` as a rename candidate, not an error.

**Retired surfaces** — this skill never reads or writes them; they exist only as a `bin/pk` fallback for un-migrated projects:
- `.vbw-planning/PHASES.md`
- `.vbw-planning/linear-map.json`

`.vbw-planning/ROADMAP.md` may still exist as **optional legacy narrative**. It is not synced state — treat it as a human-readable reference only, never as a source or target of reconciliation.

## Triggers

This skill is invoked when the user says:
- `/sync-linear`
- "sync linear"
- "reconcile linear"
- "check linear hierarchy"
- "are issues in the right phase?"

## What This Skill Reconciles

It detects and proposes fixes for **drift between the project's strategy docs / requirements and the Linear board's phase hierarchy**:

1. **Naming-convention drift** — initiatives not named `i{N}. label`, projects not named `I{N}.P{N}. label` (a bare `P{N}.` is legacy-valid but a rename candidate; flag it as such, not as an error), duplicate or gapped prefixes (`i1, i3` with no `i2`), an `I{N}.` prefix that disagrees with the project's parent initiative, or out-of-order numbering.
2. **Placement drift** — issues sitting in the wrong `I{N}.P{N}.` project (or no project at all) given what the strategy docs say belongs in that sub-phase.
3. **Coverage drift** — strategy-doc requirements with no corresponding Linear issue, or Linear issues that no longer map to any documented requirement.

It does **not** reconcile a planning-file mirror — there is none. All reconciliation targets are live Linear objects.

## Modes

| Mode | Command | What it does |
|------|---------|--------------|
| **check** | `/sync-linear` (default) | Read-only audit: report naming, placement, and coverage drift against the board. Proposes no writes. |
| **fix** | `/sync-linear fix` | Propose-then-apply: present the drift report, ask for confirmation, then apply approved renames/re-placements/issue creations to Linear. |
| **promote** | `/sync-linear promote` | Analyze sub-phase completion and recommend status promotions for the next batch of issues. |

## Reading the Board

To reconcile, build a live picture of the hierarchy from Linear (never from a map file):

1. **List initiatives** via `mcp__linear-server__linear_getInitiatives` (or search) — these are the phases. Parse `i{N}.` from each name to get phase order.
2. **List projects** under each initiative via `mcp__linear-server__linear_getProjects` — these are the sub-phases. Parse `P{N}.` from each name to get sub-phase order.
3. **List issues** in each project via `mcp__linear-server__linear_searchIssues` — these are the requirements/tasks.
4. **Read the strategy docs** named in `method.config.md` — these define what *should* exist and where. This is the requirement side of the reconciliation.

The Linear team ID and workflow state IDs come from `method.config.md` (or are resolved live via `mcp__linear-server__linear_getTeams` / `linear_getWorkflowStates`). **Never hardcode Linear IDs** and never read them from `linear-map.json` — that file is retired.

## Execution Steps

### Check Mode (default, read-only)

1. **Read** `method.config.md` § Phase Surface for the convention and the Linear team/state references.
2. **Read** the strategy docs listed in `method.config.md`.
3. **Build the live hierarchy** from Linear (initiatives → projects → issues) per *Reading the Board* above.
4. **Detect naming-convention drift:**
   - Each initiative name matches `i{N}. label`; each project name matches `P{N}. label`.
   - Prefixes are contiguous and non-duplicated within their scope.
5. **Detect placement drift:**
   - Every issue lives in exactly one `P{N}.` project.
   - Issue subject matter matches the sub-phase the strategy docs assign it to.
6. **Detect coverage drift:**
   - Each strategy-doc requirement maps to at least one Linear issue.
   - Each Linear issue maps to a documented requirement (or is flagged as undocumented).
7. **Present a drift report** (see *Output Format*). Propose no writes in check mode.

### Fix Mode (propose-then-apply)

1. Run **Check Mode** to produce the drift report.
2. **Present each proposed change** as a table (rename / re-place / create), grouped by drift type.
3. **Ask for confirmation.** Never auto-apply.
4. On approval, apply only the approved changes:
   - Rename initiatives via `mcp__linear-server__linear_updateInitiative`.
   - Rename / re-parent projects via `mcp__linear-server__linear_updateProject`.
   - Move issues into the correct project, or create missing issues, via `mcp__linear-server__linear_updateIssue` / `linear_createIssue`.
5. **Re-run Check Mode** after applying to confirm the drift cleared. Report residual drift, if any.

### Promote Mode

Analyzes sub-phase completion status and recommends moving the next batch of issues up a workflow status level. Runs standalone via `/sync-linear promote`.

#### Workflow Status Ladder

```
Future Phases → On Deck → Needs Spec → Specced → Approved → In Progress → Building → UAT → [Released →] Done
```

Workflow state IDs come from `method.config.md` or are resolved live via `mcp__linear-server__linear_getWorkflowStates`. Never hardcode them and never read them from `linear-map.json`.

#### Logic

1. **Read** workflow state references from `method.config.md` (or resolve live).
2. **List the `P{N}.` projects** in numeric-prefix order for the active phase initiative.
3. **For each project, in order (P1 → Pn):**
   - Fetch all issues via `mcp__linear-server__linear_searchIssues`.
   - Classify by status bucket:
     - **Done bucket:** Done, Canceled, Duplicate
     - **Active bucket:** In Progress, Building, UAT, Approved, Specced, Needs Spec
     - **Waiting bucket:** On Deck, Future Phases, Triage, Ideas
   - Determine project completion: all non-canceled issues in the Done bucket.
4. **Find the promotion boundary:**
   - Walk projects in numeric-prefix order. The **leading project** is the highest-numbered `P{N}.` where ALL issues are Done.
   - The **active project** is the next one (being specced/built).
   - The **on-deck project** is the one after that.
   - The **next-up project** is the one after on-deck (candidates for Future Phases → On Deck).
5. **Recommend promotions** for the next-up project's issues:
   - Issues in `Future Phases` → recommend `On Deck`.
   - Issues in `Triage` or `Ideas` → recommend `On Deck` (they're in a project, so they're real).
6. **Present the recommendation** as a table showing issue ID, title, current status, and proposed status.
7. **Ask for confirmation** before executing. On approval, batch-update via `mcp__linear-server__linear_updateIssue`.

#### Edge Cases

- **Project with mixed statuses:** If a `P{N}.` project has some Done and some In Progress issues, it's still active — don't promote the next project yet.
- **Skipped projects:** If a `P{N}.` project has 0 issues, skip it in the chain.
- **Already promoted:** If the next-up project's issues are already On Deck or higher, report "already promoted" and look further ahead.
- **Multiple promotions:** If several projects have completed since last check, recommend promoting multiple batches. Present each separately for confirmation.

#### Output Format

```
## Promote Check

### Project Status
| Project | Total | Done | Active | Waiting | Status |
|---------|-------|------|--------|---------|--------|
| P1. Foundation Fixes | 7 | 7 | 0 | 0 | Complete |
| P2. Budget Editor | 15 | 0 | 2 | 13 | Active (speccing) |
| P3. Auth & Account | 12 | 0 | 0 | 12 | On Deck |
| P4. Navigation & Layout | 8 | 0 | 0 | 8 | Waiting |

### Recommended Promotions
| Issue | Title | Current | Proposed |
|-------|-------|---------|----------|
| PROJ-XXX | ... | Future Phases | On Deck |

Approve? (y/n)
```

## Resolution Discipline

When a proposed change is ambiguous (e.g., an issue plausibly belongs in two sub-phases, or a requirement maps to no obvious project):

- **Show the options** with the evidence from the strategy docs.
- **Ask the user** which placement to apply — never auto-resolve a judgment call.
- Apply only what the user approves.

## Output Format

After a check or fix, display a drift summary:

```
## Linear Hierarchy Report (2026-06-21)

### Naming-convention drift
| Object | Current name | Expected | Action |
|--------|--------------|----------|--------|
| Initiative | Foundation | i1. Foundation | rename |
| Project | Budget Editor | P2. Budget Editor | rename |

### Placement drift
| Issue | Currently in | Belongs in | Action |
|-------|--------------|------------|--------|
| PROJ-XXX | (none) | P3. Auth & Account | move |

### Coverage drift
| Requirement (strategy doc) | Linear issue | Action |
|----------------------------|--------------|--------|
| OAuth token refresh | (missing) | create in P3. |
| PROJ-YYY | (undocumented) | flag for review |

### Clean: naming ✓  placement ✓  coverage ✓   (only sections with drift are shown)
```

In **check** mode the Action column is advisory only. In **fix** mode each row is presented for approval before any write.

## Linear MCP Tools Used

- `mcp__linear-server__linear_getInitiatives` / `linear_getInitiativeById` — list/read initiatives (phases)
- `mcp__linear-server__linear_updateInitiative` — rename an initiative to the `i{N}.` convention
- `mcp__linear-server__linear_getProjects` / `linear_getProjectById` — list/read projects (sub-phases)
- `mcp__linear-server__linear_updateProject` — rename / re-parent a project to the `P{N}.` convention
- `mcp__linear-server__linear_searchIssues` — list/filter issues in a project
- `mcp__linear-server__linear_getIssueById` — read issue details
- `mcp__linear-server__linear_createIssue` / `linear_updateIssue` — create or re-place an issue
- `mcp__linear-server__linear_getWorkflowStates` — resolve workflow state IDs (when not in `method.config.md`)

## Important Notes

- **Linear is the phase surface.** Parse phase/sub-phase order from the `i{N}.` / `P{N}.` name prefix — never from `sortOrder`, never from a planning file.
- **`linear-map.json` and `PHASES.md` are retired** — this skill never reads or writes them. Resolve Linear IDs from `method.config.md` or live MCP queries.
- **`ROADMAP.md`, if present, is optional legacy narrative** — read it for human context only; it is not a reconciliation source or target.
- **Initiative/project descriptions** use Markdown (`## Phase`, `### Scope`, `### Success Criteria`); normalize formatting when reading edits made in Linear's rich-text editor.
- Include `PROJ-{number}` in commit messages when completing tasks linked to Linear issues.
