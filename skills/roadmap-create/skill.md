---
name: roadmap-create
description: Build a staged roadmap from strategy docs and populate Linear with issues, projects, milestones. Use as Stage 0 step 6 after /strategy-create. Use when bootstrapping the Linear hierarchy for a new project. Merges with VBW phases without overwriting.
---

# Roadmap Create Skill

You are a roadmap builder. Your job is to extract requirements from strategy docs and the project definition, create a structured ROADMAP.md, and populate Linear with the initial issue hierarchy. Read `method.config.md` for project context.

## Triggers

- `/roadmap-create`
- "create the roadmap"
- "set up the roadmap"

## Prerequisites

- `project-definition.md` must exist (output of `/define`)
- `Strategy/` docs should exist (output of `/strategy-create`)
- `.vbw-planning/` directory should be scaffolded (run `/vbw:init` first)
- `method.config.md` should exist with Linear configuration
- Linear MCP server must be connected (`mcp__linear-server__*` tools available)

If `.vbw-planning/` doesn't exist, warn: _"Run `/vbw:init` first to scaffold the planning directory."_

## Purpose

Bridge the gap between "here's what the product does" (strategy docs) and "here are the work items" (Linear board). Every requirement in the roadmap traces back to a strategy doc section. Every Linear issue traces to a roadmap requirement.

## Execution Steps

### Phase 0 — Reconcile with VBW Roadmap

VBW's `/vbw:init` generates `.vbw-planning/ROADMAP.md` with phases derived from codebase analysis. If this file already exists, **reconcile — don't overwrite**.

1. Check if `.vbw-planning/ROADMAP.md` exists and has content.
2. If it does:
   - Read the existing VBW roadmap — note its phases, structure, and any requirements already captured
   - Tell the user: _"VBW has already drafted a roadmap with {N} phases from codebase analysis. I'll merge strategy-derived requirements into those phases rather than replace them. Proceed?"_
   - Use VBW's phases as the canonical phase structure
   - Add strategy-derived requirements to the appropriate phases
   - Preserve any VBW-specific notes or structure
3. If it doesn't exist (fresh project, no VBW init yet):
   - Proceed with full generation from scratch
   - Recommend the user run `/vbw:init` first for a richer starting point

### Phase 1 — Extract Requirements

1. Read `project-definition.md` for stage breakdown, exit criteria, and workflows
2. Read all Strategy docs listed in `method.config.md`'s Strategy Docs table
3. **If VBW roadmap exists**: map its phases to the project definition stages. They should align — if they don't, flag the discrepancy to the user and resolve before proceeding.
4. For each stage/phase:
   - Extract features, capabilities, and requirements from the strategy docs
   - Each requirement should be:
     - **Concrete** — "User can search properties by criteria" not "search functionality"
     - **Independent** — can be specced and built as a single Linear issue
     - **Traceable** — references the strategy doc section it comes from
   - Identify dependencies between requirements

5. Group requirements into **feature clusters** — logical groupings that will become Linear Projects:
   - e.g., "Data Foundation", "Search & CRUD", "Auth & Permissions", "Reports"
   - Each cluster should be cohesive (related features) and focused (not a catch-all)

### Phase 2 — Draft ROADMAP.md

**Important:** VBW's `/vbw:init` uses a different schema than Pipekit's original format:
- **VBW schema:** phase-based with `goal`, `requirements` (free-text), `success_criteria`
- **Pipekit schema:** stage-based with `REQ-IDs`, `feature clusters`, `dependencies`

These overlap but aren't identical. The canonical merged format below keeps both.

**If merging with a VBW-generated roadmap (most common):**

Preserve VBW's phase names, goals, and success criteria. Add Pipekit's requirement detail as subsections within each phase. Use the merged schema:

```markdown
# Roadmap

**Project:** {project name}
**Last updated:** {date}
**Source:** VBW codebase analysis + project-definition.md + Strategy/ docs

## Phase 1: {VBW's phase name}

**Goal:** {VBW's phase goal}
**Success Criteria:** {VBW's success criteria — preserve as-is}

### Requirements
- REQ-001: {requirement from strategy docs} — ref: {Strategy doc §section}
- REQ-002: {requirement} — ref: {Strategy doc §section}

### Feature Clusters
- Data Foundation: REQ-001, REQ-002
- Auth & Permissions: REQ-003

### Dependencies
- REQ-003 blocked by REQ-001 (needs data model before CRUD)

## Phase 2: {VBW's phase name}
...
```

**If writing from scratch (no VBW roadmap yet — rare):**

Use the same merged schema but fill in phase names/goals from `project-definition.md` stages. Recommend running `/vbw:init` first next time.

```markdown
# Roadmap

**Project:** {project name}
**Last updated:** {date}
**Source:** project-definition.md + Strategy/ docs

## Phase 1: {Stage Name} (MVP)

**Goal:** {from project definition}
**Success Criteria:** {from project definition exit criteria}

### Requirements
- REQ-001: {requirement} — ref: {Strategy doc §section}

### Feature Clusters
- {cluster name}: REQ-001, REQ-002

### Dependencies
- REQ-003 blocked by REQ-001

## Future (Parking Lot)
- REQ-100: {deferred item} — target: later phase
```

**Write the file to `.vbw-planning/ROADMAP.md` and point the user to it** (per the "Documents, not terminal walls" rule from `/startup`). Tell them:

_"Written merged roadmap to `.vbw-planning/ROADMAP.md`. Preserved VBW's N phases, added M requirements across K feature clusters with D dependencies. Review in your editor and let me know what to change."_

### Phase 3 — Linear Setup

**Preflight: check Linear MCP connection.** Try calling `mcp__linear-server__list_teams` or `list_issues`. If it fails:

_"Linear MCP isn't connected. I can't create issues without it. Options:"_
1. _"Reconnect now — run `claude mcp add --transport http --scope user linear-server https://mcp.linear.app/mcp` in terminal, restart Claude Code, then resume with `/roadmap-create --verify` to pick up where we stopped."_
2. _"Continue without Linear — I'll write the roadmap and skip Linear population. You can re-run `/roadmap-create` later once Linear is connected."_

**Do not fabricate Linear IDs.** If MCP is down, set all `linear_id` fields in `linear-map.json` to `null` and note "Linear population pending" in the final summary.

Once Linear MCP is confirmed working, determine what can be automated vs. what needs manual setup.

**Automate via MCP (do these):**

1. **Create Issues** — for each requirement, via `mcp__linear-server__save_issue`:
   - `team`: from `method.config.md`
   - `title`: requirement title
   - `description`: requirement detail + strategy doc reference
   - `state`: Stage 1 → "On Deck" | Stage 2+ → "Future Phases" | Parking lot → "Ideas"
   - `priority`: 0 (None) — triage sets real priority

2. **Set Dependency Relations** — for each dependency in the roadmap:
   - Use `mcp__linear-server__save_issue` to set `blocked_by` relations

3. **Apply Labels** — for each issue:
   - Type label (Feature, Improvement, Research, etc.)
   - Domain label (project-specific, based on feature cluster)

4. **Create Milestones (Work Packages)** — for each feature cluster that has >3 issues:
   - Group issues into work packages of 3-8 issues
   - Assign issues to their milestone

**Instruct manually (tell the user to do these):**

Some Linear operations may not be available via MCP. For each, give explicit instructions:

```
## Manual Linear Setup Required

The following must be done in the Linear UI:

1. **Create Initiatives** (Settings → Initiatives):
   - "{Stage 1 Name}" — maps to Stage 1
   - "{Stage 2 Name}" — maps to Stage 2

2. **Create Projects** (within each Initiative):
   Stage 1:
     - "{Feature Cluster 1}" — contains: {issue list}
     - "{Feature Cluster 2}" — contains: {issue list}
   Stage 2:
     - "{Feature Cluster 3}" — contains: {issue list}

3. **Verify Workflow States** match method.config.md:
   - If states are not yet configured, follow sop/Linear_SOP.md

After completing manual setup, run `/roadmap-create --verify` to check everything.
```

### Phase 4 — Write linear-map.json

Create `.vbw-planning/linear-map.json` mapping roadmap IDs to Linear IDs:

```json
{
  "stages": {
    "stage-1": {
      "name": "Stage 1: MVP",
      "initiative_id": null,
      "clusters": {
        "data-foundation": {
          "project_id": null,
          "issues": {
            "REQ-001": { "linear_id": "XXX-1", "title": "..." },
            "REQ-002": { "linear_id": "XXX-2", "title": "..." }
          }
        }
      }
    }
  }
}
```

Fields with `null` are populated after manual Linear setup or on subsequent runs.

### Phase 5 — Verify (also available as `--verify`)

Run a completeness check:

1. Every roadmap requirement has a Linear issue
2. Every Linear issue has the correct state for its stage
3. Dependency relations are set in Linear
4. Labels are applied
5. Milestones are assigned
6. `linear-map.json` has no null IDs (if manual setup is done)

Report:

```
## Roadmap Verification

Requirements: {N} total
Linear issues created: {N}
Dependencies set: {N}
Milestones created: {N}

Gaps:
  - {N} Initiative IDs missing (manual setup needed)
  - {N} Project assignments missing (manual setup needed)

Run /roadmap-review for a full health check.
```

### Phase 6 — Summary

```
## Roadmap Created

File: .vbw-planning/ROADMAP.md
Issues created: {N} across {M} feature clusters

Stage 1: {N} requirements → {M} issues (On Deck)
Stage 2: {N} requirements → {M} issues (Future Phases)
Parking lot: {N} items (Ideas)

Dependencies: {N} relations set
Milestones: {N} work packages created

Manual setup needed: {list of manual steps}

Next steps:
  - Complete manual Linear setup (see instructions above)
  - /phase-plan — select the first execution phase
  - /roadmap-review — validate everything before speccing
```

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Full roadmap creation flow |
| `--verify` | Run verification only (Phase 5) — useful after manual Linear setup |
| `--dry-run` | Draft the roadmap without creating Linear issues |

## Rules

- **Requirements, not tasks.** Each roadmap item is a feature or capability (WHAT), not an implementation step (HOW). Implementation decomposition happens in `/light-spec` and VBW planning.
- **Trace everything.** Every requirement references a strategy doc section. Untraced requirements are orphans — they need a strategy doc home or they shouldn't be in the roadmap.
- **Automate what you can.** Create issues, set relations, apply labels via MCP. Give clear manual instructions for the rest.
- **Human approves the roadmap before Linear population.** Don't create issues until the roadmap structure is approved.
- **Stage 1 issues go to On Deck.** Not "Needs Spec" — that happens when `/phase-plan` selects them for the first phase.

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Vague requirements** → If a requirement is too vague to be an issue, it's too vague for the roadmap. Push it back to strategy docs or split it into concrete deliverables.
- **Deferring dependencies** → Map dependencies during roadmap creation, not after. Dependencies set after the fact tend to miss relationships that were obvious during planning.
- **Untraceable requirements** → Every requirement should trace to a strategy doc section. If it doesn't, either the strategy docs need updating or the requirement is an orphan.
- **Flat issue lists** → Create the full Linear hierarchy (Initiatives/Projects/Milestones). Issues without structure become unsortable quickly.

## Next-step output

After roadmap creation completes, emit an inline `➜ Next:` line in your terminal output pointing to `/roadmap-review` (for validation) or `/phase-plan` (if validation already passed). Do **not** write a `NEXT.md` file — v2 retired the mirror; `pk next` reads "what's next?" live from Linear.

## Related

- `/define` — previous step: creates the project definition
- `/strategy-create` — creates the strategy docs this skill reads
- `/vbw:init` — scaffolds `.vbw-planning/` (run before this skill)
- `/phase-plan` — next step: select issues for the first execution phase
- `/roadmap-review` — validates the roadmap after creation
- This skill IS the Linear seeding step (no separate seed skill needed)
