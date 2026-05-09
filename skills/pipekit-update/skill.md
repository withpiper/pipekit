---
name: pipekit-update
description: Pull the latest Pipekit skills, SOPs, and templates from GitHub into the current project
---

# Pipekit Update Skill

You are a method sync coordinator. Your job is to pull the latest Pipekit content from GitHub into the current project — skills, SOPs, and templates — without touching project-specific files.

## Triggers

- `/pipekit-update`
- `/update-method`
- "update pipekit"
- "sync pipekit"
- "pull method updates"

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Sync from main |
| `v1.0` | Sync from a specific tag |
| `--dry-run` | Show what would change without applying |
| `--push` | Push improvements back to the method repo (requires local clone — see Phase 4) |

## Execution Steps

### Phase 1 — Ensure Sync Script Exists

Check if `scripts/sync-method.sh` exists in the current project.

- **If it exists:** proceed to Phase 2.
- **If not:** fetch it from GitHub:

```bash
mkdir -p scripts
curl -fsSL https://raw.githubusercontent.com/withpiper/pipekit/main/scripts/sync-method.sh -o scripts/sync-method.sh
chmod +x scripts/sync-method.sh
```

No local clone of Pipekit is needed — the sync script pulls directly from GitHub.

### Phase 2 — Pull Updates

Run the sync script:

```bash
./scripts/sync-method.sh ${tag_or_branch}
```

The sync script clones the Pipekit repo from GitHub to a temp directory, copies content into the project, and cleans up automatically.

Show what changed:
- New skills added
- Skills updated
- SOPs updated
- Templates updated

If `method.config.md` doesn't exist, warn: _"No method.config.md found. Run `/startup` to configure."_

### Phase 3 — Changelog

The sync script writes a changelog to `pipekit/.sync-changelog.md` that captures what changed. **Read this file first** — it's the source of truth for what needs reconciliation.

1. **Read `pipekit/.sync-changelog.md`** — it contains:
   - New skills added (with descriptions from their `skill.md`)
   - Updated skills (content changed)
   - Possibly removed/renamed skills
   - Updated method docs
   - New config fields in the template that aren't in the project's `method.config.md`

2. **For updated skills, read the actual diffs** to understand *what* changed in behavior. For each updated skill:
   - Read the new `skill.md`
   - Summarize the behavioral changes (not just "file changed" — what's *different* for the user)

3. **Present a human-readable changelog to the user:**

```
## What Changed

### Skills
- 🆕 `/new-skill` — {description, when to use it}
- 🔄 `/updated-skill` — {what changed in behavior}
- ➡️ `/old-name` renamed to `/new-name`

### Method Docs
- {doc name}: {summary of what changed}

### Config
- New field: `{field name}` in method.config.md — needs a value
```

If `pipekit/.sync-changelog.md` doesn't exist (e.g., older sync script), fall back to `git diff` on the synced paths.

### Phase 4 — Reconcile

This is the critical phase — bring the project into alignment with what was updated. Walk through each change that requires action.

**4a. Config alignment**

Compare `method.config.template.md` (just synced) against the project's `method.config.md`:

1. Check for **new fields** in the template that don't exist in the project config
2. Check for **removed fields** that are no longer in the template
3. Check for **structural changes** (renamed sections, moved fields)

For each new field:
- Explain what it's for
- Ask the user for the value (or derive it from existing project context)
- Write it to `method.config.md` immediately

For removed/renamed fields:
- Migrate the value to the new location
- Remove the old field

_"Your `method.config.md` is missing these fields that were added in this update: {list}. Let's fill them in."_

**4b. Skill onboarding**

For each **new skill**:
1. Read the skill's `skill.md` to understand its purpose and triggers
2. Explain to the user in 2-3 sentences: what it does, when to use it, and how it fits into the pipeline
3. If the skill requires any setup (config values, MCP tools, etc.), walk through it now

For each **renamed skill**:
- Tell the user the new command
- Check if any project-specific files reference the old name (CLAUDE.md, rules, scripts) and offer to update them

For each **skill with changed behavior**:
- Summarize what's different
- If the change affects existing project artifacts (e.g., a template format changed), ask if the user wants to update existing docs to match

**4c. SOP alignment**

For each updated SOP, check if the project is already following the new conventions:

- **Linear SOP changed?** → Check if the project's Linear workspace matches (states, labels, conventions)
- **Git SOP changed?** → Check if the project's branching model aligns
- **Code Quality SOP changed?** → Check if the pre-deploy gate in `method.config.md` matches

Flag any misalignment: _"The Code Quality SOP now recommends X, but your pre-deploy gate doesn't include it. Want to update?"_

**4d. Startup tracker alignment**

If a `{folder-name}-startup.md` exists:
1. Check if any completed steps have new requirements in the updated skills
2. Flag steps that may need re-running: _"Step 4 (Infrastructure) has new Linear setup instructions. Your Linear config looks complete, so no action needed."_
3. Or: _"Step 3 (Tech Stack) now records git architecture in method.config.md, but yours is empty. Want to fill it in now?"_

**4e. Summary and next steps**

```
## Reconciliation Complete

Config fields added: {N}
New skills onboarded: {N}
SOPs aligned: {N} checked, {M} actions taken
Startup tracker: {aligned | N items flagged}

Action items remaining:
  - {any deferred items the user said "later" to}

Restart Claude Code to load updated skills.
```

### Phase 5 — Push Improvements Back (--push only)

When invoked with `--push`, this mode captures improvements made to portable skills *in the current project* and pushes them back to the method repo.

**Requires a local clone** at `~/Projects/pipekit/` (or wherever `METHOD_REPO_LOCAL` points). If no local clone exists, explain:

_"The `--push` flag requires a local clone of Pipekit to stage changes. Run:"_
```bash
git clone https://github.com/withpiper/pipekit.git ~/Projects/pipekit
```

If a local clone exists:

1. Compare each portable skill in `.claude/skills/` against the method repo version at `~/Projects/pipekit/skills/`
2. For each skill that differs:
   - Show the diff
   - Ask: _"Push this change back to pipekit? (y/n/edit)"_
3. For approved changes:
   - Copy the updated skill to `~/Projects/pipekit/skills/`
   - Stage the changes in the method repo
4. Also check for changes to:
   - `pipekit/sop/` → `~/Projects/pipekit/sop/`
   - `pipekit/templates/` → `~/Projects/pipekit/templates/`
   - `pipekit/method.md` → `~/Projects/pipekit/method.md`
   - `pipekit/STARTUP.md` → `~/Projects/pipekit/STARTUP.md`
5. After all changes are staged, offer to commit and push:
   ```
   {N} files updated in pipekit.

   Commit and push? (y/n)
   ```
6. If yes: commit with message `feat(method): sync improvements from {project name}` and push to origin main

**Never push project-specific content** (method.config.md, .claude/rules/, project-specific skills) to the method repo.

## What Gets Synced (Pull)

| Source (GitHub) | Destination (this project) | Notes |
|-----------------|---------------------------|-------|
| `skills/*/` | `.claude/skills/*/` | Only portable skills — won't delete project-specific skills |
| `sop/` | `pipekit/sop/` | Full replace |
| `templates/` | `pipekit/templates/` | Full replace |
| `method.md` | `pipekit/method.md` | Full replace |
| `GUIDE.md` | `pipekit/GUIDE.md` | Full replace |
| `STARTUP.md` | `pipekit/STARTUP.md` | Full replace |

## What Never Gets Synced

| File | Why |
|------|-----|
| `method.config.md` | Project-specific — your Linear IDs, team name, etc. |
| `.claude/rules/` | Project coding conventions |
| `.claude/skills/{project-specific}/` | Stack-specific skills |
| `.vbw-planning/` | Project state |
| `CLAUDE.md` | Project-specific |

## Related

- `/startup` — initial project bootstrap (runs sync as part of setup)
- `scripts/sync-method.sh` — the underlying sync script
- Pipekit repo: [github.com/withpiper/pipekit](https://github.com/withpiper/pipekit)
