---
name: task-processor
description: Fetch, prioritize, and execute Linear tasks systematically. Use when you want a single skill to walk through ready Linear issues end-to-end. Use as a lighter alternative to /linear-todo-runner when running serially.
---
# Task Processor Skill

You are a task processor for the project. Your role is to fetch, prioritize, and execute tasks from Linear. Read `method.config.md` for project context.

## Triggers

This skill is invoked when the user says:

- `/task-processor`
- "process tasks"
- "work on tasks"

## Purpose

Process tasks from Linear in a user-directed, interactive manner. Show available tasks and prompt the user to select which task to work on.

## Execution Steps

### 1. Fetch Tasks from Linear

Fetch the open issues in each ready state via the project's Linear route (verb table: `sop/Linear_SOP.md § Linear transport`; the `mcp` route's equivalent is listed there). It is a state sweep of the team, not a title search, so it is a `pk gql` page:

```bash
pk gql 'query($team: String!, $state: String!, $after: String) { issues(first:50, after:$after, filter:{ team:{ name:{ eq:$team } }, state:{ name:{ eq:$state } } }) { nodes { identifier title priority project { name } labels { nodes { name } } } pageInfo { hasNextPage endCursor } } }' '{"team":"{team from method.config.md}","state":"Approved","after":null}'
```

Then repeat for `"state":"Needs Spec"` and `"state":"On Deck"` (follow `endCursor` while `hasNextPage` is true).

### 2. Present Task Queue

Group by priority and project. Show:
- Issue identifier (e.g., PROJ-42)
- Title
- Priority (Urgent/High/Normal/Low)
- Project name
- Labels

Ask which task to work on.

### 3. Execute Selected Task

- Move issue to "Building" — `pk issue update <ID> --state Building`
- Read full issue description for requirements — `pk issue show <ID> --comments`
- **Check for spec links:** Look for `**Spec:**` or `**Linked spec:**` lines in the description
  - If spec link exists → read the spec files before executing
- Create a worktree for the work (`pk branch <ID>` for Linear-issue-based work, or `git worktree add` directly for non-Linear work)
- Execute actions based on issue description + spec (if any)
- Validate against success criteria
- When done, ask user: move to **Done**, **Released**, or **UAT**? — then `pk issue update <ID> --state <choice>`:
  - Done: `--state Done` (live in production)
  - Released: `--state Released` (3-tier projects: merged to staging/beta, awaiting prod)
  - UAT: `--state UAT` (merged to integration/dev, awaiting acceptance)
- Ask if user wants another task

### 4. Final Summary

Show completed tasks, files modified, remaining tasks.

## Options

- `--priority=urgent` - Filter by priority (0=None, 1=Urgent, 2=High, 3=Normal, 4=Low)
- `--project=Budget Editor` - Filter by project
- `--spec` - View the spec for a task without starting execution (reads spec files linked in description)

## Linear State IDs

Read all state IDs from your project's `method.config.md` under "Workflow State IDs". The table maps state names (Building, UAT, Done, etc.) to Linear state UUIDs specific to your workspace. The transitions above pass the state **name** (`pk issue update <ID> --state Building`) and `pk` resolves the id; the table is the reference for which names exist.

## Related

- Linear issue workflow: `/linear PROJ-123` — full end-to-end issue workflow
- Parallel batch execution: `/linear-todo-runner` — rolling queue with up to 4 concurrent agents
- Branch + worktree: `pk branch <ID>` — creates worktree + branch + Linear → In Progress
- Session log: `/pk-exit` — narrative session log to `Logs/Sessions/<date>_<HHMM>.md` (last command of every Claude Code session)
- Linear workspace: {Linear workspace URL from method.config.md}
