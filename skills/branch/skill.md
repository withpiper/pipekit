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

`/branch finish` cleans up a worktree and its branch.

### Where to run it (v1.8.0.5+)

**Run from the parent repo** (`~/Projects/<repo>`), not from inside the worktree being removed. `git worktree remove` fails if you're inside the directory it's deleting.

Typical sequence after the feature PR is rebase-merged:

```bash
# Inside the worktree:
exit                          # leave claude (drops to shell)

# Back at the parent shell:
cd ~/Projects/<repo>          # if not already there
claude                        # or attach to your existing parent session

# In parent claude:
/branch finish RS-XX-edit-delete    # explicit arg = unambiguous
# or:
/branch finish                       # no arg = auto-detect merged worktrees
```

### Steps

#### 1. Resolve which worktree to finish

In priority order:

1. **Explicit slug arg** (`/branch finish RS-XX-edit-delete`) — match against `git worktree list` paths. If found, use it. If not, error: "no worktree matches `RS-XX-edit-delete`."
2. **Currently inside a worktree (not the parent repo)** — use the current worktree, but **error and instruct the user to `exit` and re-run from the parent**:
   > "Detected /branch finish run from inside the worktree at <path>. Re-run from the parent repo at <repo-root> — `git worktree remove` can't delete the directory you're sitting in."
3. **No arg, in the parent repo** — list `git worktree list` worktrees that are NOT the parent. For each, check:
   - Is the branch merged to dev/main on `origin`? (`git branch -r --merged origin/dev | grep <branch>`)
   - If exactly one worktree's branch is merged → that's the candidate. Confirm with user before removing.
   - If multiple worktrees are merged → list them, ask user to pick.
   - If none merged → list active worktrees, ask "which one to finish?"

#### 2. Check branch status (after target worktree resolved)

- Uncommitted changes in the target worktree → warn and ask to commit or stash (cannot stash from outside the worktree; user must cd in, stash, cd back).
- Unpushed commits → warn and ask to push.
- Open PR → show PR status; default action is "wait for PR to merge first."
- Merged → safe to clean up.

#### 3. Offer cleanup options

- **Delete worktree + local branch** (default if merged). Auto-delete on remote already handled if `delete_branch_on_merge=true` is set on the repo (v1.7.0+ recommendation).
- Keep branch but remove worktree.
- Cancel.

#### 4. Execute cleanup

```bash
# Run from the parent repo (this is where /branch finish executes):
git worktree remove "$WORKTREE_PATH"
git branch -d "$BRANCH_NAME"          # only if merged
# Note: with delete_branch_on_merge=true, the remote branch is already gone.
# Only run the next line if for some reason it isn't:
# git push origin --delete "$BRANCH_NAME"
```

If `git branch -d` fails ("not fully merged" — happens after squash-merge because squash creates a new commit on dev that doesn't match the feature branch's commits in ancestry), use `git branch -D` (force-delete). Squash-merge is the correct case for `-D`; the content is on dev, the commit objects are not.

## List Subcommand

`/branch list` shows all active worktrees:

```bash
git worktree list
```

## Error Handling

- Branch already exists: offer to check it out in a new worktree
- Worktree path already exists: warn and suggest a different name
- Not on expected base branch: warn but proceed
