---
name: branch
description: Start any unit of work — creates worktree + branch + optional Linear link
---

# Branch Skill

You are a branch and worktree manager. Your job is to create worktree-based branches for the project. Read `method.config.md` for the worktree prefix and project name. You handle features, fixes, and hotfixes.

## Triggers

- `/branch`
- "start a branch"
- "new branch"
- "start a feature"
- "start a fix"
- "start a hotfix"

## Command Options

```
/branch <name>              -> feature/ branch from dev
/branch --fix <name>        -> fix/ branch from dev
/branch --hotfix <name>     -> hotfix/ branch from main
/branch --linear PROJ-XX     -> link to Linear issue
/branch finish              -> clean up current worktree + branch
/branch list                -> show active worktrees
```

## Branch Type and Base Branch Logic

| Flag | Branch Prefix | Base Branch | Use Case |
|------|---------------|-------------|----------|
| (default) | `feature/` | `dev` | New features |
| `--fix` | `fix/` | `dev` | Bug fixes |
| `--hotfix` | `hotfix/` | `main` | Production hotfixes (skip dev/beta) |

## Steps

### 1. Parse Input

- Determine branch type from flags (default: feature)
- Extract name from remaining arguments
- Convert to kebab-case: lowercase, spaces to hyphens, strip special characters
- Check for `--linear PROJ-XX` flag

Example parsing:
- `/branch smart-add-panel` -> `feature/smart-add-panel` from `dev`
- `/branch --fix login-redirect` -> `fix/login-redirect` from `dev`
- `/branch --hotfix auth-crash` -> `hotfix/auth-crash` from `main`

#### Slug derivation when `--linear` is passed (v1.8.0+)

When the user passes only `--linear PROJ-XX` (no explicit name argument), derive the slug from the Linear issue title — but **short** (issue ID + 2-3 meaningful words), not the verbose `gitBranchName` field Linear returns.

Algorithm:
1. Fetch Linear title (already fetched in Step 3 — reuse it).
2. Lowercase the title.
3. Strip stopwords: `with`, `and`, `the`, `for`, `of`, `to`, `in`, `on`, `a`, `an`, `change`, `tracking`, `record` (the last three are common Linear filler — extend the list as patterns surface).
4. Strip punctuation; split on whitespace.
5. Take first 2–3 remaining words.
6. Kebab-case them; prefix with the Linear ID.

Result format: `<PREFIX>-<NN>-<word1>-<word2>[-<word3>]`

Examples (real Linear titles):
- `RS-21 — Record edit + delete with change tracking` → `RS-21-edit-delete`
- `RS-19 — Sales results grid (AG Grid Community)` → `RS-19-sales-results`
- `RS-22 — Server-side audit logging` → `RS-22-audit-logging`

If the user passes both `--linear PROJ-XX` and an explicit name, the explicit name wins (use the user's name as the slug; still prefix with the Linear ID for traceability: `<PREFIX>-<NN>-<user-name>`).

This is **deterministic** — same Linear title always yields the same slug.

### 2. Ensure Base Branch Is Current

```bash
# Determine base branch
BASE_BRANCH="dev"  # or "main" for --hotfix

git checkout "$BASE_BRANCH" 2>/dev/null || true
git pull origin "$BASE_BRANCH"
```

### 3. Pre-Check Linear Status (when `--linear` is passed)

If `--linear PROJ-XX` was specified, **before any worktree creation**, fetch the Linear issue and inspect its current status. This catches issues that have already been shipped, canceled, or duplicated and prevents wasted setup time.

```
1. mcp__linear-server__get_issue identifier=PROJ-XX
2. Inspect status name:
   - Done / Canceled / Duplicate
       → AskUserQuestion:
         "PROJ-XX is already {status}. Create worktree anyway?"
         Options: ["Abort" (default), "Create anyway"]
         If user picks Abort: stop here, no worktree, no symlinks.
         If user picks Create anyway: proceed to Step 4 (worktree creation).
   - In Progress / Building
       → Print warning: "⚠ PROJ-XX is already {status} — someone else may
         be working on it. Proceeding."
         Continue without prompting.
   - Any other status (Approved, Specced, Needs Spec, On Deck, etc.)
       → Proceed silently.
3. Only after this status check passes, continue to worktree creation.
```

If `--linear` was not passed, skip this step entirely (no Linear API call, no behavior change).

This is the **only** Linear API call before worktree creation. Do not re-query Linear later in the flow — Step 6 (Linear status transition) reuses what we know from this check.

### 4. Create Worktree

```bash
WORKTREE_PATH="{worktree prefix from method.config.md}{kebab-name}"

# Create worktree with new branch
git worktree add "$WORKTREE_PATH" -b {prefix}{kebab-name}
```

### 5. Symlink Shared Config Files

Only symlink files that actually exist -- skip any that are missing without error.

```bash
MAIN_REPO="$(git rev-parse --show-toplevel)"

# MCP servers
ln -sf "$MAIN_REPO/.mcp.json" "$WORKTREE_PATH/.mcp.json"

# Environment variables
ln -sf "$MAIN_REPO/.env" "$WORKTREE_PATH/.env"

# App-specific env
[ -f "$MAIN_REPO/apps/web/.env.local" ] && \
  mkdir -p "$WORKTREE_PATH/apps/web" && \
  ln -sf "$MAIN_REPO/apps/web/.env.local" "$WORKTREE_PATH/apps/web/.env.local"

# Sentry CLI config
[ -f "$MAIN_REPO/.sentryclirc" ] && \
  ln -sf "$MAIN_REPO/.sentryclirc" "$WORKTREE_PATH/.sentryclirc"

# Claude Code local settings
[ -f "$MAIN_REPO/.claude/settings.local.json" ] && \
  ln -sf "$MAIN_REPO/.claude/settings.local.json" "$WORKTREE_PATH/.claude/settings.local.json"
```

### 6. Transition Linear to In Progress

If `--linear PROJ-XX` was specified and the user did not abort in Step 3, update the Linear issue status to "In Progress" via `mcp__linear-server__save_issue`.

This preserves the prior post-creation behavior. The pre-check in Step 3 only inspects status; the transition happens here once the worktree exists.

### 7. Rename cmux Workspace

Rename the current cmux workspace so it reflects the new work context:

```bash
bash ~/.claude/scripts/cmux-workspace-name.sh "{kebab-name}"
```

This sets the workspace title to `{project} - {kebab-name}` (read project name from `method.config.md`). Skip silently if cmux is unavailable.

### 8. Confirm

```
Branch: {prefix}{kebab-name}
Worktree: {worktree prefix from method.config.md}{kebab-name}
Base: dev (or main for hotfix)

To start working:
  cd {worktree prefix from method.config.md}{kebab-name} && claude --dangerously-skip-permissions

When done:
  /branch finish
```

## Finish Subcommand

`/branch finish` cleans up the current worktree and branch.

### Steps

1. Detect current worktree context
2. Check branch status:
   - Uncommitted changes -> warn and ask to commit or stash
   - Unpushed commits -> warn and ask to push
   - Open PR -> show PR status
   - Merged -> safe to clean up
3. Offer cleanup options:
   - Delete worktree + local branch + remote branch (if merged)
   - Keep branch but remove worktree
   - Cancel
4. Execute cleanup:
   ```bash
   # From main repo (not the worktree being deleted)
   git worktree remove "$WORKTREE_PATH"
   git branch -d {branch-name}  # only if merged
   git push origin --delete {branch-name}  # only if merged and remote exists
   ```

## List Subcommand

`/branch list` shows all active worktrees:

```bash
git worktree list
```

## Error Handling

- Branch already exists: offer to check it out in a new worktree
- Worktree path already exists: warn and suggest a different name
- Not on expected base branch: warn but proceed
