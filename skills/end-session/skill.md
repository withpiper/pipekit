---
name: end-session
description: End a work session by capturing reflections, committing work, and creating a session log
---

# End Session Skill

You are a session closer. Your job is to help the user close out a work session by capturing their reflections and creating a comprehensive session log. Read `method.config.md` for project context.

## Triggers

This skill is invoked when the user says:
- `/end-session`
- "end session"
- "handoff"
- "summarize session"
- "close session"

## Purpose

1. Automatically review and summarize what happened this session
2. Log session changes to `Strategy/Doc4_Changelog.md` as a running record
3. Offer a cumulative version bump (covering all work since the last version)
4. Capture the user's reflections
5. Commit and create a session log

---

## Execution Steps

### Pre-flight A — Integration-branch refusal (v1.8.0+)

Before doing anything else, check what branch we're on. If `git branch --show-current` returns the integration branch (`dev`) or production branch (`main`), **refuse with a clear error**:

```bash
CURRENT=$(git branch --show-current)
case "$CURRENT" in
  dev|main|master)
    echo "ERROR: /end-session is meant to run on a feature branch inside a worktree." >&2
    echo "  Current branch: $CURRENT" >&2
    echo "  This guard exists because writing the session log directly to" >&2
    echo "  $CURRENT would either fail (branch protection) or pollute" >&2
    echo "  integration history. Run /end-session from inside the feature" >&2
    echo "  worktree, BEFORE /launch --close opens the PR." >&2
    echo "" >&2
    echo "  See RUNBOOK.md § The loop, step 10." >&2
    exit 1
    ;;
esac
```

Rationale: starting v1.8.0 (#15), /end-session is part of the feature-branch flow. It runs *before* /launch --close so the session log + NEXT.md update ship in the same PR as the code. Running it on dev/main is either blocked by branch protection or — worse — succeeds and creates a divergent direct write.

If you genuinely need to write a session log without a feature branch (e.g., session of pure planning, no ship), commit your work first, branch off dev, then run /end-session in the new branch.

---

### Pre-flight B — Refresh NEXT.md from integration tip (v1.8.0+)

Inside the feature worktree, NEXT.md is a snapshot from when `/branch` was run. If a parallel session has shipped to `dev` since, that snapshot is stale. Before recomputing NEXT.md (Step 7b.1), pull dev's current version:

```bash
INTEGRATION="$INTEGRATION"  # resolved by Step 0a below
git fetch origin "$INTEGRATION" --quiet
if git cat-file -e "origin/$INTEGRATION:NEXT.md" 2>/dev/null; then
  git checkout "origin/$INTEGRATION" -- NEXT.md
  echo "✓ NEXT.md refreshed to origin/$INTEGRATION (parallel-session-safe base)"
fi
```

This loads only NEXT.md — no branch switch, no other state change. The recompute logic in Step 7b.1 is from-Linear-truth, so the base just affects "Last updated" and optional sections (parallelizable / blocked). Race window shrinks from "hours of work in worktree" to "minutes between /end-session and PR merge."

**Ordering note:** `$INTEGRATION` is resolved in the next sub-step (the existing Session Shutdown Preflight reads `method.config.md` § Git Architecture). In practice: read config → resolve `$INTEGRATION` → refresh NEXT.md → continue with the rest of the preflight.

---

### Step 0 — Session Shutdown Preflight

This step is **transparent and confirmatory**: it scans the workspace for everything that typically needs cleanup after a ship (feature branch, agent worktrees, stale locks, orphan branches), presents a plan, and waits for approval before executing anything destructive. No silent cleanup.

#### Step 0a — Read the project's git architecture

Read `method.config.md` → `## Git Architecture` to determine:

- **Integration branch** — where session artifacts should land. For `two-tier` or `three-tier` models this is `dev`. For projects with no `dev` branch (main-only), it's `main`.
- **Production branch** — always `main` unless the config explicitly says otherwise.

Fallback order when `method.config.md` is missing or unparseable:

```bash
INTEGRATION=$(git show-ref --verify --quiet refs/remotes/origin/dev && echo dev || echo "")
if [ -z "$INTEGRATION" ]; then
  INTEGRATION=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)
fi
```

#### Step 0b — Classify current state and scan for cleanup targets

Run these scans **silently** — output is for Step 0c:

```bash
CURRENT=$(git rev-parse --abbrev-ref HEAD)

# PR state for the current branch (if not on integration or production)
if [ "$CURRENT" != "$INTEGRATION" ] && [ "$CURRENT" != "main" ]; then
  PR_STATE=$(gh pr view --json state --jq .state 2>/dev/null || echo "UNKNOWN")
  PR_URL=$(gh pr view --json url --jq .url 2>/dev/null || echo "")
fi

# Merged feature branches (excluding integration + production)
MERGED_BRANCHES=$(git branch --merged "$INTEGRATION" 2>/dev/null \
  | sed 's/^[ *]*//' \
  | grep -v -E "^($INTEGRATION|main|master)$" \
  | grep -v -E "^worktree-agent-" || true)

# VBW agent worktrees (locked and unlocked)
AGENT_WORKTREES=$(git worktree list --porcelain 2>/dev/null \
  | awk '/^worktree / {wt=$2} /^locked/ {print wt} /^$/ {wt=""}' \
  | grep "/.claude/worktrees/agent-" || true)

# Orphan worktree-agent-* branches (left behind after worktree removal)
ORPHAN_AGENT_BRANCHES=$(git branch 2>/dev/null \
  | sed 's/^[ *]*//' \
  | grep -E "^worktree-agent-" || true)

# Uncommitted changes (affects whether we can safely switch branches)
DIRTY=$(git status --porcelain 2>/dev/null)
```

For each locked agent worktree, determine if the lock PID is alive:

```bash
# Parse lock reason for PID (format: "claude agent agent-X (pid NNNN)")
for wt in $AGENT_WORKTREES; do
  LOCK_REASON=$(git worktree list --porcelain | awk -v wt="$wt" '$2==wt {found=1} found && /^locked/ {sub(/^locked /,""); print; exit}')
  PID=$(echo "$LOCK_REASON" | grep -oE 'pid [0-9]+' | awk '{print $2}')
  if [ -n "$PID" ] && ! kill -0 "$PID" 2>/dev/null; then
    # Dead PID — safe to force-remove
    echo "$wt DEAD_PID $PID"
  fi
done
```

#### Step 0c — Present the cleanup plan

Show the user everything that was found and what the skill proposes:

```markdown
## Session Shutdown Plan

**Current state**
- Branch: `{CURRENT}`
- Integration branch: `{INTEGRATION}`
- PR: {status — e.g., "PR #14 merged" | "PR #15 open at {url}" | "no PR"}
- Uncommitted: {none | N files}

**Proposed cleanup**
{Only include sections with findings}

### Branch switch
- Switch to `{INTEGRATION}` + `git pull --ff-only`
- Delete local `{CURRENT}` (PR merged ✓)

### Merged feature branches to prune
- `feature/rs-8` (merged to dev)
- `feature/rs-16` (merged to dev)

### VBW agent worktrees (dead locks)
- `.claude/worktrees/agent-ad8b8a0e` (PID 15986 dead)
- `.claude/worktrees/agent-ff23c912` (PID 15987 dead)

### Orphan worktree branches
- `worktree-agent-ad8b8a0e`
- `worktree-agent-ff23c912`

**Choose:**
- `proceed` — run all of the above
- `selective` — approve each cleanup type individually
- `skip-cleanup` — leave the workspace as-is and continue to session log
- `cancel` — stop, I'll clean up manually
```

If there are no findings (user already ran the cleanup sequence manually, or is already on integration with a clean tree), say so and skip to Step 1:

> Workspace is clean — no branch/worktree cleanup needed. Proceeding to session log.

#### Step 0d — Handle uncommitted changes

If `DIRTY` is non-empty and the user chose to switch branches, **stop and ask**:

> You have uncommitted changes:
> ```
> {git status --short output}
> ```
> These would be carried into `{INTEGRATION}` on checkout. Commit them first, stash them, or cancel? [commit / stash / cancel]

- `commit` → ask for a message, commit on current branch, then proceed
- `stash` → `git stash push -m "end-session auto-stash {timestamp}"`, note it in the session log, proceed
- `cancel` → stop

#### Step 0e — Execute the approved plan

Run operations in this order, stopping on any failure:

```bash
# 1. Switch + pull (only if the user approved the switch)
git checkout "$INTEGRATION"
git pull --ff-only

# 2. Delete the current feature branch (only if PR was merged)
git branch -d "$FEATURE_BRANCH" 2>/dev/null || git branch -D "$FEATURE_BRANCH"

# 3. Prune other merged feature branches
for b in $MERGED_BRANCHES; do
  git branch -d "$b" 2>/dev/null || echo "skipped $b (not fully merged)"
done

# 4. Remove stale VBW agent worktrees
for wt in $DEAD_WORKTREES; do
  git worktree remove -f -f "$wt"
done

# 5. Delete orphan worktree-agent-* branches
for b in $ORPHAN_AGENT_BRANCHES; do
  git branch -D "$b"
done

# 6. Prune remote-tracking refs
git fetch --prune
```

Display a compact summary of what was actually done:

```
✓ Switched to dev (up to date at 3d6edeb)
✓ Deleted RS-9 (merged)
✓ Removed 2 stale agent worktrees
✓ Deleted 2 orphan worktree-agent-* branches
✓ Pruned remote refs
```

If the user chose `hold` or `skip-cleanup`: warn about orphan risks (session log + NEXT.md will live on the feature branch) and print the cherry-pick recipe from the old Step 0:

> `git checkout {INTEGRATION} && git checkout {CURRENT} -- Logs/Sessions/ NEXT.md && git commit -m "chore(log): preserve session artifacts"`

Then proceed to Step 1 regardless.

---

### Step 1 — Auto-Review Session Work

Without asking the user anything yet, automatically:

1. Run `git log --oneline` and compare against the last session log in `Logs/Sessions/` to identify commits made this session
2. Summarize what was built/fixed/changed in plain language
3. Present a concise session summary to the user:

```markdown
## Here's what we did this session:

**Features / Changes:**
- [item]
- [item]

**Fixes:**
- [item]

**Other:**
- [item]

---
```

This summary is used for the changelog entry and session log. Confirm with the user or let them correct anything before proceeding.

---

### Step 2 — Log Session to Doc4_Changelog.md

Read `Strategy/Doc4_Changelog.md`. Append the session's work as an **unlocked / pending entry** under a `## Pending (Not Yet Versioned)` section at the top of the file (or add to it if it already exists):

```markdown
## Pending (Not Yet Versioned)

### Session: YYYY-MM-DD
- [change 1]
- [change 2]
- [change 3]
```

This creates a running log of all work since the last version bump. Do not create a new version number — just log the session work.

---

### Step 3 — Offer Cumulative Version Bump

Read `src/app/assets/changelog.json` to get the current version. Read the `## Pending` section of Doc4 to see all accumulated work since the last version.

Ask the user:

```markdown
**Want to publish a version update?**

Current version: vX.X.X
Work accumulated since last version:
- [session 1 items]
- [session 2 items]
- [this session's items]

Say **yes** to publish v X.X.Y — I'll draft the entry and update both changelogs.
Say **no** to keep accumulating (you can publish any time by saying "bump version").
```

**If yes:** Draft the version entry:
- Suggest a version number (patch bump by default, e.g. 2.6.3 → 2.6.4)
- Suggest a release name based on the theme of accumulated changes
- Draft a summary sentence and 3-6 highlights
- Show the draft and ask for approval / edits
- On approval:
  - Update `src/app/assets/changelog.json`: set new `currentVersion`, prepend new version object
  - Update `Strategy/Doc4_Changelog.md`: move `## Pending` items into a proper versioned section, clear the Pending section
  - **Deploy:** Changelog is deployed automatically when the next promotion to main merges. No manual deploy needed.

**If no:** Skip. The pending items remain in Doc4 for next time.

---

### Step 4 — Ask for Reflections

```markdown
## Session Wrap-Up

Before we log everything, a few quick questions:

1. **What are you most pleased about from this session?**
2. **What's still on your mind or unfinished?**
3. **How are you feeling about the project?**
4. **Any insights or lessons?**

(Say "skip" to just create the technical log.)
```

---

### Step 5 — Calculate Session Duration

Get current time, recall start time, calculate difference.
Format: "Xh XXm" (e.g., "2h 15m")

---

### Step 6 — Update Linear Issues

Scan the conversation for `PROJ-{N}` references and work completed. For each referenced issue:

1. **Completed this session** → move to Done using `mcp__linear-server__save_issue` with the Done state ID from `method.config.md`
2. **Worked on but not finished** → ensure In Progress using `mcp__linear-server__save_issue` with the In Progress state ID from `method.config.md`
3. **Post a session comment** via `mcp__linear-server__save_comment` with content: `"**Session {YYYY-MM-DD}:** {brief summary of what was done, decisions made, and any next steps}"`

Read all state IDs from your project's `method.config.md` under "Workflow State IDs". The table maps state names (Done, UAT, Building, In Progress, etc.) to Linear state UUIDs specific to your workspace.

**For each WIT issue touched this session, also consider:**
- If the issue description is stale or missing detail based on what was discussed, update it via `mcp__linear-server__save_issue` with an updated `description`
- If priority changed based on session decisions, update `priority` accordingly
- Always post a comment — even if status didn't change — so there's a running session history on the issue

---

### Step 7 — Create Session Log

Create file: `Logs/Sessions/YYYY-MM-DD_HHMM.md` with personal reflections and technical summary. Include a **Linear Updates** section listing any issues updated.

---

### Step 7b — Apply queued NEXT.md updates, then refresh NEXT.md

#### Step 7b.0 — Apply any queued NEXT.md write (v1.6.0+)

Pipekit skills that ran inside VBW's active-plan scope (typically `/review-plan` and `/launch --close` mid-session) defer their `NEXT.md` writes to `$STATE_DIR/pending-next-md.json` (out-of-repo, v1.7.0+) per `sop/Skills_SOP.md` § Deferral mechanism. `/end-session` runs outside any active-plan scope (sessions end after the build is done), so this is the canonical apply point.

```bash
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
QUEUE="$STATE_DIR/pending-next-md.json"
if [ -f "$QUEUE" ]; then
  WRITER=$(jq -r '.writer' "$QUEUE")
  QUEUED_AT=$(jq -r '.queued_at' "$QUEUE")
  echo "Found deferred NEXT.md write from $WRITER at $QUEUED_AT."
fi
```

If the queue file exists:

1. Read the queued content. Compare its `next_command` against what the session has actually shipped (commits, Linear status changes, branch state).
2. **If the queued recommendation is still relevant** (queued `/vbw:vibe --execute X` and the session did not execute X) — apply atomically: write the queued `content` field to `NEXT.md` at the project root. Skip Step 7b.1 — the queued write is the truth.
3. **If the session has shipped past the queued point** (queued `/vbw:vibe --execute X` but the session ran execute, verify, and `--close`) — the queue is stale. Discard without writing. Step 7b.1 recomputes from current state.
4. **In either case, delete the queue file** after handling: `rm -f "$QUEUE"`. The queue is ephemeral; no persistent cruft.

If no queue file exists, proceed to Step 7b.1 unchanged.

#### Step 7b.1 — Recompute NEXT.md from current state

Previous `NEXT.md` likely points at the issue that just shipped. Recompute and overwrite per the schema in `sop/Skills_SOP.md` → `The NEXT.md Convention`.

Source for the next action, in priority order:

1. **Current phase has more Approved issues?** — recommend `/launch {next Approved issue}`. Pick the one whose dependency graph (via Linear `blocked_by` relations) unblocks the most downstream work. Briefly name what it unblocks in the "Why this one" field.
2. **Current phase fully shipped but has unshipped `Specced` issues?** — recommend moving the top-priority one to Approved (human review gate).
3. **Current phase fully shipped and specced?** — recommend `/strategy-sync` if there's a pending-strategy-sync marker at `$STATE_DIR/pending-strategy-sync` (resolved via `scripts/pipekit-state-dir.sh`), otherwise recommend `/phase-plan` to select the next phase.
4. **No phase active?** — recommend `/phase-plan`.

Write `NEXT.md` at the project root using the exact schema (`# Next Step` / `**Last updated:**` / `## Recommended next command` / `## Why this one` / optional parallelizable and blocked sections). Include this session's `YYYY-MM-DD_HHMM` as the timestamp and `/end-session` as the writer.

If you can't confidently pick the next action (Linear unreachable, no clear sequence), write a NEXT.md that says "Unclear — run `/phase-plan --status` to see state" rather than leaving the file stale.

---

### Step 8 — Git Commit & Push

Check for uncommitted changes and confirm with the user before committing.

Commit the session log **and** the refreshed NEXT.md together so they move as a unit:

```bash
git add "Logs/Sessions/YYYY-MM-DD_HHMM.md" NEXT.md
# Include Strategy/Doc4_Changelog.md if it was updated in Step 2 or 3
git commit -m "chore(log): session YYYY-MM-DD (duration)"
git push
```

---

### Step 9 — Post to Slack

Post a brief summary to the project's Slack channel (configure channel ID in `method.config.md`):

```
mcp__slack__conversations_add_message(
  channel_id: "{slack_channel_id from method.config.md}",
  content_type: "text/markdown",
  payload: "
**Session Ended** — [duration]

*Accomplishments:*
- [key things completed this session]

*Next Steps:*
- [what's queued for next session]

_Log: `Logs/Sessions/YYYY-MM-DD_HHMM.md`_
"
)
```

---

### Step 10 — Confirm Session End

Show: duration, tasks completed, files modified, commits pushed, Slack status.

If version was bumped, confirm that `changelog.json` was deployed (it should have been deployed in Step 3).

---

## Related

- Start Session skill (`/start-session`) - captures intentions at session start
- Session logs: `Logs/Sessions/YYYY-MM-DD_HHMM.md`
- In-app changelog: `src/app/assets/changelog.json`
- Strategy changelog: `Strategy/Doc4_Changelog.md`
