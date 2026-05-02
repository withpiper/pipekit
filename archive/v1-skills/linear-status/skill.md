---
name: linear-status
description: Quick triage view of current Linear board status from the CLI
---

# Linear Status Skill

You are a board status reporter. Your job is to show a quick triage view of the current Linear board state. Read `method.config.md` for project context.

## Triggers

This skill is invoked when the user says:
- `/linear-status`
- `/board`
- "show board"
- "what's in progress"
- "linear status"

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Show Building + In Progress + UAT |
| `all` | Show all non-done states (Ideas through UAT) |
| `blocked` | Show issues with "Blocked" label |
| `project <name>` | Filter to a specific project (e.g., `Budget Editor`) |

## Execution Steps

### 1. Fetch Issues by State

Query Linear using `mcp__linear-server__list_issues` for each active state:

1. `team: "{team from method.config.md}"`, `state: "Building"`
2. `team: "{team from method.config.md}"`, `state: "In Progress"`
3. `team: "{team from method.config.md}"`, `state: "UAT"`

If `all` argument: also fetch `Approved`, `Specced`, `Needs Spec`, `On Deck`.

### 2. Display Board

Format as a clean triage view:

```markdown
## Board — {team from method.config.md} ({date})

### Building (2)
- **PROJ-88** — AG Grid Enterprise Migration [Budget Editor] P1
- **PROJ-252** — Basic Google OAuth Login [Onboarding & UX] P2

### In Progress (1)
- **PROJ-187** — Side Panel — Chrome Extension P3

### UAT (1)
- **PROJ-253** — Budget Locking & Editor Presence [Budget Editor] P2

---
Total active: 6 | Queue depth: 12 | Done this week: 3
```

### 3. Show Quick Actions

After the board, suggest actions:

```
Actions:
  /linear PROJ-88     — pick up an issue
  /task-processor     — auto-select next task
  /sync-linear        — sync VBW ↔ Linear
```

## Display Rules

- **Bold the issue identifier** for scanability
- Show project name in brackets `[Project]`
- Show priority as P0-P4 (P0=None, P1=Urgent, P2=High, P3=Normal, P4=Low)
- Sort within each state by priority (highest first)
- If an issue has the "Blocked" label, prefix with a warning marker
- Keep the output compact — no issue descriptions, just identifiers + titles + metadata

## Related

- `/linear PROJ-123` — full issue workflow
- `/task-processor` — auto-select and execute tasks
- `/linear-todo-runner` — rolling parallel agent queue for batch execution
- `/start-session` — full session setup with board context
- `/sync-linear` — bidirectional sync with VBW
