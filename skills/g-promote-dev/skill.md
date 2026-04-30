---
name: g-promote-dev
description: Promote current feature branch to dev by creating a PR. Reads method.config.md for Linear state IDs, pre-deploy gate, and stack-specific values. Verifies pre-deploy gate, optionally pushes migrations, extracts Linear issue references, transitions issues to In Progress.
---

# Git Promote Dev

Creates a PR from the current feature/fix branch to the integration branch (typically `dev`). Two-tier flow: `feature/*` → PR to dev → (later) PR to main. Three-tier flow: same first hop; subsequent hops use `/g-promote-beta` and `/g-promote-main`.

**Portable since v1.8.1.** Reads project-specific values from `method.config.md` — does not hardcode Linear prefixes, state IDs, gate commands, or stack assumptions.

## Triggers

- `/g-promote-dev`
- "promote to dev", "open PR to dev"

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- Linear MCP available (`mcp__linear-server__*`)
- Current branch follows the pattern `feature/*`, `fix/*`, or `hotfix/*`
- Working tree clean (all changes committed)
- `method.config.md` present and parseable

## Steps

### 1. Read project config

Parse `method.config.md` once at the start. Extract:

| Variable | Source section | Default if missing |
|---|---|---|
| `ISSUE_PREFIX` | § Linear → Issue prefix | error — required |
| `IN_PROGRESS_ID` | § Linear → Workflow State IDs → In Progress | error — required |
| `INTEGRATION` | § Git Architecture (`dev` for both two-tier and three-tier) | `dev` |
| `GATE_CMD` | § Pre-Deploy Gate (joined with `&&`) | error — required |
| `HOSTING` | § Stack → Hosting | `none` |
| `DB_PUSH_CMD` | § Stack → DB push command | _(empty — skip migration push)_ |
| `MIGRATION_DIR` | § Stack → Migration dir | _(empty — skip migration detection)_ |
| `SHARED_DB` | § Stack → Shared DB across environments | `no` |

If `method.config.md` is missing or unparseable, surface a clear error and stop.

### 2. Sanity checks

```bash
CURRENT_BRANCH=$(git branch --show-current)
STATUS=$(git status --porcelain)
```

Guard:
- If `$CURRENT_BRANCH` is `main`, `dev`, or `beta`: STOP. _"Can't promote from `$CURRENT_BRANCH` — switch to a feature/fix branch first."_
- If `$STATUS` is non-empty: STOP. _"Uncommitted changes: {list}. Commit or stash before promoting."_
- If `$CURRENT_BRANCH` doesn't start with `feature/`, `fix/`, or `hotfix/`: WARN, ask user to confirm.

### 3. Pre-deploy gate

Run the gate command read from config. `$GATE_CMD` is a string of commands joined by `&&` (e.g. `pnpm typecheck && pnpm lint && pnpm test`). Bare `$GATE_CMD` would only invoke the first command and pass `&&` as a literal argument, so use `eval` so the shell parses the chain correctly:

```bash
eval "$GATE_CMD"
```

If any check fails, STOP and surface the output. Do not create a PR with a broken gate. The gate is project-defined; trust the config.

### 4. Apply migrations to shared DB (if configured)

Skip this step entirely if `DB_PUSH_CMD` or `MIGRATION_DIR` is empty.

If both are set, detect new migrations on this branch:

```bash
NEW_MIGRATIONS=$(git diff --name-only --diff-filter=A "$INTEGRATION..HEAD" -- "$MIGRATION_DIR" 2>/dev/null)
```

If migrations exist, branch on `SHARED_DB`:

**`SHARED_DB=yes`** (single DB across environments — common in pre-production projects):

```bash
echo "New migrations on this branch (not yet on $INTEGRATION):"
echo "$NEW_MIGRATIONS" | sed 's/^/  /'
echo ""
echo "WARNING: this project shares one DB across environments. Pushing here"
echo "forward-mutates the DB used by $INTEGRATION/main. If this PR is closed"
echo "without merging, you will need to manually roll back these migrations."
echo ""
read -r -p "Push to shared DB now? [y/N] " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  $DB_PUSH_CMD || {
    echo "$DB_PUSH_CMD failed. STOP. Fix the migration and retry."
    exit 1
  }
  echo "✓ Migrations applied."
else
  echo "Skipped. Migrations will be applied at /g-promote-main time. Preview"
  echo "URL UAT will not be able to exercise migration-bearing code paths."
fi
```

**`SHARED_DB=no`** (separate dev/prod DBs):

```bash
echo "New migrations on this branch (not yet on $INTEGRATION):"
echo "$NEW_MIGRATIONS" | sed 's/^/  /'
echo ""
read -r -p "Push to dev DB now? [Y/n] " confirm
if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
  $DB_PUSH_CMD || {
    echo "$DB_PUSH_CMD failed. STOP."
    exit 1
  }
  echo "✓ Migrations applied to dev DB."
fi
```

If the user declines, continue to step 5 — PR will still be created.

### 5. Push branch

```bash
git push -u origin "$CURRENT_BRANCH"
```

`-u` is idempotent — safe to use whether or not upstream tracking is already set. If push is rejected (non-fast-forward), surface the rebase command and stop: `git pull --rebase origin $CURRENT_BRANCH`.

### 6. Extract Linear issue references

Parse for `${ISSUE_PREFIX}-XXX` identifiers from:

- Branch name (e.g. `feature/RS-21-edit-delete`)
- Commit messages on this branch not yet on `$INTEGRATION`:
  ```bash
  git log --pretty=%s "$INTEGRATION..HEAD"
  ```

Collect a unique set. If none found, ask: _"No `${ISSUE_PREFIX}-XXX` references found. Link this PR to a Linear issue? (issue ID or skip)"_

### 7. Create the PR

```bash
gh pr create \
  --base "$INTEGRATION" \
  --head "$CURRENT_BRANCH" \
  --title "<title — derive from first commit subject>" \
  --body "$(cat <<EOF
## Summary
<bullets — derive from commit messages on this branch>

## Linear issues
<refs from step 6>

## Test plan
- [ ] Pre-deploy gate passes ($GATE_CMD)
- [ ] Manually verified in preview environment
- [ ] <add issue-specific tests>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Capture the PR URL from the output.

### 8. Transition Linear issues

For each referenced issue, move to `In Progress` (state ID `$IN_PROGRESS_ID`) if not already past it. Only advance forward — do not downgrade:

```
Specced | Approved → In Progress
Needs Spec | On Deck → In Progress (warn: no spec found)
Building | UAT | Done → leave as-is
```

Use `mcp__linear-server__save_issue` with `state: "In Progress"` (or the ID directly). Attach the PR as a link:

```
mcp__linear-server__save_issue({
  id: "<ISSUE_PREFIX>-NNN",
  state: "In Progress",
  links: [{ url: "<pr-url>", title: "PR: <title>" }]
})
```

### 9. Report

Output:

```
✓ PR created: <pr-url>
✓ Preview environment: (check PR comment if hosting=$HOSTING auto-posts a URL)
✓ Linear issues moved to In Progress: <list>

Next: review the PR, wait for preview build, then merge to $INTEGRATION.
On merge to $INTEGRATION: no further Linear transition (issues stay In Progress until $PROD).
```

(`$PROD` resolves to `main` for two-tier; for three-tier, `merge to beta` moves to UAT and `merge to main` moves to Done.)

## Tier reminder

After merge to `$INTEGRATION`, issues STAY `In Progress`. They only move forward when promoted further:
- **Two-tier**: merge to `main` → `Done` (use `/g-promote-main`)
- **Three-tier**: merge to `beta` → `UAT` (use `/g-promote-beta`); merge to `main` → `Done` (use `/g-promote-main`)

## Failure modes

| Symptom | Fix |
|---------|-----|
| `gh auth status` fails | Run `gh auth login` |
| Push rejected (non-fast-forward) | Rebase: `git pull --rebase origin $CURRENT_BRANCH` |
| Linear MCP not connected | Skip Linear transitions; user must move issues manually |
| Pre-deploy gate fails | Fix the issue. The gate is a hard requirement. |
| `method.config.md` missing | Run `/startup` to bootstrap project config, or copy from `method.config.template.md` |
| `$DB_PUSH_CMD` fails on a clean migration | The migration itself is broken. Fix the SQL; do not bypass. |

## See also

- `sop/Git_and_Deployment.md` — full release flow and merge strategy by hop
- `method.config.md` — project-specific values
- `/g-test-vercel` — push branch + smoke-test preview URL (use mid-feature)
- `/g-promote-main` — next promotion step (two-tier)
- `/g-promote-beta` — next promotion step (three-tier)
- `/g-deploy` — post-merge production verification

## Migration from project-local copies (rs-vault, piper)

If this skill is being installed via `/pipekit-update` to replace a project-local `.claude/skills/g-promote-dev/skill.md`, verify these `method.config.md` values are populated before running:

- § Linear → Issue prefix
- § Linear → Workflow State IDs → In Progress
- § Pre-Deploy Gate
- § Stack → Hosting, DB push command, Migration dir, Shared DB across environments

If you need to keep the old project-local version, place it at `.claude/overrides/skills/g-promote-dev/skill.md` — `sync-method.sh` will preserve the override.
