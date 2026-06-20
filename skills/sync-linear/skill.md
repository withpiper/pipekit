---
name: sync-linear
description: Bidirectional sync between VBW planning files and Linear. Use when .vbw-planning/ and Linear have drifted. Use after manual edits to either side. Keeps planning state coherent between the two surfaces.
---

# Sync Linear Skill

You are a planning synchronization coordinator. Your job is to maintain bidirectional sync between VBW planning files (`.vbw-planning/`) and the Linear workspace. Read `method.config.md` for project context. VBW is the planning engine; Linear is the view layer where the user reviews and edits plans.

## Triggers

This skill is invoked when the user says:
- `/sync-linear`
- "sync linear"
- "update linear"
- "pull from linear"
- "push to linear"

## Modes

The skill supports three modes, selected by argument or inferred from context:

| Mode | Command | What it does |
|------|---------|--------------|
| **push** | `/sync-linear push` | VBW → Linear: push ROADMAP content, plan tasks, and status updates into Linear |
| **pull** | `/sync-linear pull` | Linear → VBW: pull edits made in Linear back into VBW files |
| **sync** | `/sync-linear` (default) | Both directions: push first, then pull, reporting any conflicts |
| **promote** | `/sync-linear promote` | Analyze project completion and recommend status promotions for the next batch of issues |

## Data Sources

### VBW files (source of truth for structure)
- `.vbw-planning/ROADMAP.md` — Phase definitions, goals, requirements, success criteria
- `.vbw-planning/STATE.md` — Current phase status, progress, decisions
- `.vbw-planning/phases/*/PLAN.md` — Detailed task plans per phase
- `.vbw-planning/linear-map.json` — ID mapping between VBW entities and Linear objects

### Linear objects (view layer for review and editing)
- **Initiatives** = VBW Phases (6 total)
- **Projects** = Feature clusters within phases (25 total)
- **Issues** = Individual tasks/requirements from VBW plans

## ID Mapping

All VBW ↔ Linear relationships are stored in `.vbw-planning/linear-map.json`. This file contains:
- Team ID and workflow state IDs
- Initiative IDs mapped to VBW phase slugs
- Project IDs mapped to feature cluster slugs
- Issue ID mappings (populated as plans create tasks)

**Never hardcode Linear IDs in skill logic.** Always read from `linear-map.json`.

## Execution Steps

### Push Mode (VBW → Linear)

1. **Read** `.vbw-planning/linear-map.json` for all ID mappings
2. **Read** `.vbw-planning/ROADMAP.md` for phase content
3. **For each initiative:**
   - Read current Linear initiative description via `mcp__linear-server__linear_getInitiativeById`
   - Compare with ROADMAP content for that phase
   - If VBW content is newer or different, update via `mcp__linear-server__linear_updateInitiative`
4. **For each project:**
   - Read current Linear project description via `mcp__linear-server__linear_getProjectById`
   - Compare with plan content for that feature cluster
   - If VBW content is newer, update via `mcp__linear-server__linear_updateProject`
5. **For VBW plan tasks** (when plans exist in `.vbw-planning/phases/*/PLAN.md`):
   - Check if a matching Linear issue exists (by title match or stored ID in linear-map.json)
   - If no issue exists → create via `mcp__linear-server__linear_createIssue` with correct project assignment
   - If issue exists but status differs → update status
   - Store new issue IDs back into `linear-map.json`
6. **Report** what was pushed (created/updated/unchanged counts)

### Pull Mode (Linear → VBW)

1. **Read** `.vbw-planning/linear-map.json` for all ID mappings
2. **For each initiative:**
   - Fetch current description from Linear via `mcp__linear-server__linear_getInitiativeById`
   - Compare with ROADMAP.md content
   - If Linear description was edited (differs from last push), extract changes
   - Present diff to user for approval before updating ROADMAP.md
3. **For each project:**
   - Fetch current description from Linear via `mcp__linear-server__linear_getProjectById`
   - Compare with stored content
   - If Linear description was edited, present diff to user
4. **For issues:**
   - Fetch issues in each project via `mcp__linear-server__linear_searchIssues`
   - Check for new issues created directly in Linear (not via VBW push)
   - Check for status changes on existing issues
   - Report new Linear issues that need to be added to VBW plans
   - Report status changes that should update VBW task state
5. **Present a sync report** showing all detected changes, asking for confirmation before applying

### Sync Mode (default)

1. Run **Push** first
2. Run **Pull** second
3. If conflicts found (both sides changed the same content), present both versions to user and ask which to keep
4. Update `linear-map.json` with new `last_synced` timestamp

### Promote Mode

Analyzes project completion status and recommends moving the next batch of issues up a workflow status level. Runs automatically as part of sync mode, or standalone via `/sync-linear promote`.

#### Workflow Status Ladder

```
Future Phases → On Deck → Needs Spec → Specced → Approved → In Progress → Building → UAT → [Released →] Done
```

State IDs are stored in `linear-map.json` under `states.*`. Always read from there — never hardcode.

#### Logic

1. **Read** `linear-map.json` for state IDs and project mappings
2. **For each Stage 2 project** (active stage), in order (P1 → P10):
   - Fetch all issues via `mcp__linear-server__linear_searchIssues`
   - Classify by status bucket:
     - **Done bucket:** Done, Canceled, Duplicate
     - **Active bucket:** In Progress, Building, UAT, Approved, Specced, Needs Spec
     - **Waiting bucket:** On Deck, Future Phases, Triage, Ideas
   - Determine project completion: all non-canceled issues in Done bucket
3. **Find the promotion boundary:**
   - Walk projects in order. The **leading project** is the highest-numbered project where ALL issues are Done.
   - The **active project** is the next project (being specced/built).
   - The **on-deck project** is the one after that.
   - The **next-up project** is the one after on-deck (candidates for Future Phases → On Deck).
4. **Recommend promotions** for the next-up project's issues:
   - Issues in `Future Phases` → recommend `On Deck`
   - Issues in `Triage` or `Ideas` → recommend `On Deck` (they're in a project, so they're real)
5. **Present the recommendation** as a table showing issue ID, title, current status, and proposed status
6. **Ask for confirmation** before executing. On approval, batch-update all issues via `mcp__linear-server__linear_updateIssue`

#### Parallel Track Awareness

Stage 2 has two tracks (from ROADMAP):
- **Critical path:** WP-1 → WP-2 → WP-3 (Foundation → AG Grid → Editor Parity)
- **Parallel track:** WP-4 → WP-5 → WP-6/WP-7 (Auth → Nav → Dashboard/Notifications)

The promote logic treats each track independently. A project on the parallel track can promote independently of the critical path. Map projects to tracks using the `wp` field in `linear-map.json`:
- Critical path: `wp` 1, 2, 3
- Parallel track: `wp` 4, 5, 6, 7, 11
- Independent: `wp` 8, 9, 10 (can promote when their dependencies are met)

#### Edge Cases

- **Project with mixed statuses:** If a project has some Done and some In Progress issues, it's still active — don't promote the next project yet.
- **Skipped projects:** If a project has 0 issues, skip it in the chain.
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

## Conflict Resolution

When both VBW and Linear have changes to the same entity:
- **Show both versions** side by side
- **Ask the user** which version to keep (or merge manually)
- **Never auto-resolve conflicts** — the user always decides

## Output Format

After sync, display a summary table:

```
## Sync Report (2026-03-29)

### Push (VBW → Linear)
| Type | Created | Updated | Unchanged |
|------|---------|---------|-----------|
| Initiatives | 0 | 2 | 4 |
| Projects | 0 | 3 | 22 |
| Issues | 5 | 1 | 10 |

### Pull (Linear → VBW)
| Type | Changes Detected | Applied |
|------|-----------------|---------|
| Initiative descriptions | 1 | 1 |
| Project descriptions | 0 | 0 |
| New issues (Linear-only) | 2 | pending |
| Status changes | 3 | 3 |

### Conflicts: None
```

## Linear MCP Tools Used

- `mcp__linear-server__linear_getInitiativeById` — read initiative details
- `mcp__linear-server__linear_createInitiative` / `linear_updateInitiative` — create/update initiatives
- `mcp__linear-server__linear_getProjectById` — read project details
- `mcp__linear-server__linear_createProject` / `linear_updateProject` — create/update projects
- `mcp__linear-server__linear_searchIssues` — list/filter issues in a project
- `mcp__linear-server__linear_getIssueById` — read issue details
- `mcp__linear-server__linear_createIssue` / `linear_updateIssue` — create/update issues
- `mcp__linear-server__linear_getWorkflowStates` — get workflow states

## Important Notes

- **Initiative descriptions** use Markdown format with `## Phase N: Name`, `### Scope`, `### Success Criteria` headers
- **Project descriptions** use Markdown format with `## Project Name`, `### Scope`, `### Success Criteria` headers
- The user edits in Linear's rich text editor, which converts Markdown to its internal format — when pulling back, normalize formatting
- Always update `linear-map.json` after any sync operation
- Include `PROJ-{number}` in commit messages when completing tasks linked to Linear issues
