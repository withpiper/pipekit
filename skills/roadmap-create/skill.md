---
name: roadmap-create
description: Build a staged roadmap from strategy docs and author it directly into Linear as the native initiative surface — Initiatives (i{N}. initiatives), Projects (P{N}. sub-phases), and Issues. Use as Stage 0 step 6 after /strategy-create, when bootstrapping the Linear hierarchy for a new project.
---

# Roadmap Create Skill

You are a roadmap builder. Your job is to extract requirements from strategy docs and the project definition and author them into **Linear** as the native initiative surface. Read `method.config.md` for project context — especially **§ Initiative Surface**, which defines the naming convention this skill must apply.

## Triggers

- `/roadmap-create`
- "create the roadmap"
- "set up the roadmap"

## Prerequisites

- `project-definition.md` must exist (output of `/define`)
- `Strategy/` docs should exist (output of `/strategy-create`)
- `method.config.md` should exist with Linear configuration (and `§ Initiative Surface`)
- Linear MCP server must be connected (`mcp__linear-server__*` tools available)

> **No `/vbw:init` step.** The initiative surface is now Linear itself — there is no `.vbw-planning/`
> scaffold, `PHASES.md`, or `linear-map.json` to create. The Linear Initiative→Project→Issue
> hierarchy *is* the roadmap. (Existing projects with legacy `.vbw-planning/` files keep working via
> bin/pk's fallback; this skill no longer writes them.)

## Purpose

Bridge "here's what the product does" (strategy docs) and "here are the work items" (Linear board).
Every requirement traces to a strategy doc section; every Linear issue traces to a requirement. The
output is a **live, ordered Linear hierarchy** that `pk next` / `pk status` read directly — no mirror
file to drift.

## The initiative surface (read `method.config.md § Initiative Surface` first)

| Roadmap concept | Linear construct | Naming | Ordering |
|-----------------|-----------------|--------|----------|
| Stage / initiative | **Initiative** | `i{N}. label` (e.g. `i1. Foundation`) | by `{N}`, numeric |
| Feature cluster / sub-phase | **Project** | `I{N}.P{N}. label` (e.g. `I1.P2. Search`) | by the `P{N}` number, numeric, within its initiative |
| Requirement | **Issue** | (Linear identifier) | priority / state |
| Work Package (optional) | **Milestone** | (free) | orthogonal grouping inside a project |

- **The `i{N}.` / `I{N}.P{N}.` prefixes are mandatory** — they carry order *and* mark which initiatives are
  delivery phases. Linear's `sortOrder` is NOT used (it's an unreliable drag-rank).
- **Projects carry their initiative number** (v4.5.0+): a project under `i1.` is named `I1.P2. label`, not
  bare `P2.` — initiatives sit above projects in Linear and get buried, so the initiative reads at the project
  level (the unit you navigate). `bin/pk` accepts both `I{N}.P{N}.` and legacy bare `P{N}.`; the `P{N}`
  number still sets sub-phase order. **Author the `I{N}.P{N}.` form.**
- Number phases and sub-phases by execution order. Leave gaps if useful (`i1, i2, i3`).
- Strategic / north-star initiatives that aren't delivery initiatives: **do not** give them an `i{N}.`
  prefix — they'll be correctly ignored by the roadmap walk.

## Execution Steps

### Phase 1 — Extract Requirements

1. Read `project-definition.md` for stage breakdown, exit criteria, and workflows.
2. Read all Strategy docs listed in `method.config.md`'s Strategy Docs table.
3. Map the project-definition **stages → Initiatives** (`i{N}.`). Stage 1 = `i1.`, Stage 2 = `i2.`, etc.
4. For each stage, extract requirements. Each requirement should be:
   - **Concrete** — "User can search properties by criteria", not "search functionality"
   - **Independent** — buildable as a single Linear issue
   - **Traceable** — references the strategy doc section it comes from
   - Note dependencies between requirements.
5. Group each stage's requirements into **feature clusters → Projects** (`I{N}.P{N}.`), ordered by execution
   priority within the stage. Each cluster is cohesive (related features) and focused (not a catch-all):
   - e.g. `i1.` Foundation → `I1.P1. Data Foundation`, `I1.P2. Auth & Permissions`, `I1.P3. Search & CRUD`.

### Phase 2 — Draft the roadmap for approval

Present the proposed hierarchy as a tree for the human to approve **before** creating anything in Linear:

```
i1. Foundation (Stage 1 — MVP)
  I1.P1. Data Foundation
    - REQ-001 Core data model            ← Strategy/DataModel §2
    - REQ-002 Migrations + RLS baseline   ← Strategy/Permissions §1
  I1.P2. Auth & Permissions
    - REQ-003 Login / session             ← Strategy/Permissions §3  (blocked by REQ-001)
  I1.P3. Search & CRUD
    - REQ-004 Record list + detail        ← Strategy/UXReference §4

i2. Reporting (Stage 2)
  I2.P1. Dashboards
    - REQ-010 ...
```

Optionally also write a human-readable narrative `ROADMAP.md` at the project root (per the curated-roadmap
doctrine in `method.md` — a legitimate *optional* artifact). **Do not** write `linear-map.json` or
`.vbw-planning/PHASES.md` — those are retired; the Linear hierarchy is the source of truth. Tell the user:

_"Proposed {K} initiatives (i1–i{K}) with {M} sub-phases (projects) and {N} requirements. Approve before I
create them in Linear? (y/n/edit)"_

### Phase 3 — Author the hierarchy in Linear

**Preflight: check the Linear MCP connection** (`mcp__linear-server__linear_getTeams` or `linear_getProjects`). If it fails, tell the user how to reconnect and stop — **do not fabricate IDs**.

On approval, create top-down. Apply the naming convention exactly.

1. **Initiatives** — one per stage, named `i{N}. label`:
   - If your MCP exposes an initiative-create tool (e.g. `mcp__linear-server__linear_createInitiative`),
     use it. Otherwise create them in the Linear UI (Settings → Initiatives) with the `i{N}.` prefix and
     tell the user exactly which to make. Set initiative status: current stage → `Active`, later stages →
     `Planned`.
   - **Verify the tool name against your installed MCP** — initiative create/update support varies by
     server. Naming carries the order regardless, so manual UI creation is always a valid fallback.
2. **Projects** (sub-phases) — within each initiative, named `I{N}.P{N}. label` (the initiative number then
   the project number, e.g. `I1.P2. Search`), via `linear_createProject` (set its `initiativeId`/parent
   initiative, and `state`: current → `started`, else `planned`/`backlog`).
3. **Issues** — for each requirement, via `mcp__linear-server__linear_createIssue`:
   - `team`: from `method.config.md`; `project`: the `I{N}.P{N}.` project it belongs to
   - `title`, `description` (+ strategy doc reference)
   - `state`: Stage 1 → `On Deck` | later stages → `Future Phases`
   - `priority`: 0 (None) — triage sets real priority
4. **Dependency relations** — `linear_createIssueRelation` for each `blocked_by`.
5. **Labels** — type label (Feature/Improvement/Research) + domain label per feature cluster.
6. **Milestones (optional)** — only for a project with >6 issues that benefits from intra-project gating.

### Phase 4 — Verify the surface

Confirm the native initiative surface is well-formed (this is what `pk next` will read):

1. Every delivery initiative is named `i{N}.` with a unique, ordered `{N}`.
2. Every project is named `I{N}.P{N}.` — its initiative number, then a unique `P{N}` within that initiative (e.g. `I1.P1.`, `I1.P2.`).
3. Every requirement has an issue, placed in the right `P{N}.` project.
4. The earliest non-`Completed` initiative is `Active`; its earliest live project is `started`.
5. Run `pk status` — the **Roadmap** section should list your `i{N}.` initiatives in order with the
   current `P{N}.` project for each. If it's empty, a prefix is missing or malformed.

### Phase 5 — Summary

```
## Roadmap Created (Linear-native)

Phases (initiatives):   i1–i{K}
Sub-phases (projects):  {M}
Requirements (issues):  {N}  ({Stage 1} → On Deck, later → Future Phases)
Dependencies:           {N} relations

Verify:  pk status   (Roadmap section shows i1 → current P{N}.)

Next steps:
  - /roadmap-review — validate the hierarchy before speccing
  - /phase-plan     — confirm the current phase and promote its first issues to Needs Spec
```

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Full roadmap creation flow |
| `--verify` | Run Phase 4 only — re-check the Linear surface (useful after manual initiative creation) |
| `--dry-run` | Draft + present the tree (Phases 1–2) without creating anything in Linear |

## Rules

- **The naming convention is non-negotiable.** `i{N}.` initiatives, `P{N}.` projects, numeric order.
  A delivery initiative without an `i{N}.` prefix is invisible to `pk next`.
- **Requirements, not tasks.** Each issue is a feature/capability (WHAT), not an implementation step.
  Decomposition happens in `/light-spec` and `/work`.
- **Trace everything.** Every requirement references a strategy doc section. Untraced = orphan.
- **Human approves the tree before Linear population.** Don't create issues until the structure is approved.
- **Stage 1 issues go to On Deck** — not "Needs Spec" (that's `/phase-plan`'s job).
- **No mirror files.** Never write `linear-map.json` or `.vbw-planning/PHASES.md`. The Linear hierarchy is the truth.

## Common Drifts to Avoid

- **Unprefixed delivery initiatives** → if it's an initiative, it gets an `i{N}.`; if it's a strategic theme, it doesn't. Mixing them up makes `pk next` either skip an initiative or surface a non-initiative.
- **Relying on Linear `sortOrder`** → never. Order is the prefix number, parsed numerically. Drag-order in the UI is cosmetic.
- **Vague requirements** → too vague to be an issue = too vague for the roadmap. Push back to strategy docs.
- **Flat issue lists** → create the full Initiative→Project hierarchy so `pk next`/`pk status` can scope.

## Next-step output

After roadmap creation, emit an inline `➜ Next:` line pointing to `/roadmap-review` (validation) or
`/phase-plan`. Do **not** write a `NEXT.md` or `linear-map.json` — `pk next` reads "what's next?" live
from Linear.

## Related

- `/define` — previous step: creates the project definition
- `/strategy-create` — creates the strategy docs this skill reads
- `/phase-plan` — next step: confirm the current initiative, promote its first issues to Needs Spec
- `/roadmap-review` — validates the Linear hierarchy after creation
- `method.config.md § Initiative Surface` — the naming-convention contract this skill applies
