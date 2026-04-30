---
name: start-session
description: Begin a work session by reviewing past progress and capturing intentions
---

# Start Session Skill

You help the user begin a new work session by reviewing past progress and capturing their intentions for the current session.

## Triggers

This skill is invoked when the user says:
- `/start-session`
- "start session"
- "what did we do last time"
- "review previous sessions"

## Purpose

1. Review recent session logs to provide context
2. Ask the user for their goals and intentions for this session
3. Capture their mindset to build a personal work diary over time

## Execution Steps

### Pre-flight — Refresh NEXT.md from integration tip (v1.8.0.1+)

`/start-session` runs in two contexts:

1. **Project root on `dev`/`main`** — "what should I work on?" Surfaces NEXT.md and pending markers as-is. No refresh needed; you're already on the integration branch.
2. **Inside a feature worktree** — "orient me on the issue I just /branch'd into." NEXT.md in the worktree is the snapshot from when /branch ran, possibly stale if a parallel session shipped to dev since. Refresh it.

```bash
# Resolve integration branch (same fallback chain as /end-session Step 0a).
# Prefer method.config.md § Git Architecture if available; otherwise fall back
# to origin/dev or origin's default HEAD.
INTEGRATION=$(git show-ref --verify --quiet refs/remotes/origin/dev && echo dev || echo "")
if [ -z "$INTEGRATION" ]; then
  INTEGRATION=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)
fi
CURRENT=$(git branch --show-current)

case "$CURRENT" in
  "$INTEGRATION"|main|master)
    : # On integration — no refresh needed
    ;;
  *)
    # On a feature branch — refresh NEXT.md from origin/<integration>
    git fetch origin "$INTEGRATION" --quiet
    if git cat-file -e "origin/$INTEGRATION:NEXT.md" 2>/dev/null; then
      git checkout "origin/$INTEGRATION" -- NEXT.md
      echo "✓ NEXT.md refreshed to origin/$INTEGRATION (parallel-session-safe view)"
    fi
    ;;
esac
```

This makes /start-session symmetric with /end-session: both refresh NEXT.md from `origin/<integration>` before reading/writing it. /start-session never refuses to run (unlike /end-session) — both contexts are valid.

---

### 1. Note the Start Time

Record the current timestamp for duration tracking.

### 2. Read and Display NEXT.md

Check if `NEXT.md` exists at the project root. If it does, read and display it prominently at the top of the session — this tells the user what they were about to do before closing the last session.

Format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Picking up where you left off
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{Contents of NEXT.md — render as-is}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `NEXT.md` doesn't exist (fresh project or before the first pipeline step completes), skip this step silently and proceed.

### 2b. Check Pending Strategy Sync Marker

Resolve `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)` and check if `$STATE_DIR/pending-strategy-sync` exists. It is written by `scripts/pipekit-post-archive.sh` after VBW archives a milestone. (v1.7.0+: location moved out-of-repo to evade VBW's file-guard.) When present, surface it before session planning:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pending: strategy sync
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Milestone {milestone_slug} archived on {timestamp} (tag: {tag}).
Strategy docs may be out of date. Run `/strategy-sync` when ready.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Do not auto-run `/strategy-sync` — the user decides when. The marker is cleared by `/strategy-sync` on completion.

### 3. Review Recent Sessions

List and read recent session logs from `Logs/Sessions/`.

### 4. Query Linear Status

Use `mcp__linear-server__list_issues` with:
- `team`: `"{team from method.config.md}"`
- `state`: `"Building"` — then repeat for `"In Progress"`, `"UAT"`, and `"Approved"`

Also pull the current phase's WIT issues from `.vbw-planning/STATE.md` to show what's queued for the active phase.

Display as a **Linear Status** block:

```markdown
## Linear Status

**Building:**
- PROJ-42 — Feature title (priority, project)
- ...

**In Progress:**
- PROJ-38 — Feature title (ad-hoc/manual)
- ...

**UAT:**
- PROJ-39 — Feature title
- ...

**Current Phase (from STATE.md):**
- Phase 1 — Repo Setup: PROJ-160, PROJ-161, PROJ-162
  - PROJ-160: [status]
  - PROJ-161: [status]
  - PROJ-162: [status]
```

If no issues are in progress or review, note that — it means the queue is clear.

### 5. Present Recent Activity

Show the user a concise summary combining: last session log + board status + Linear status.

### 6. Rename cmux Workspace

After the user states their intentions, rename the cmux workspace to reflect the current work context:

```bash
bash ~/.claude/scripts/cmux-workspace-name.sh
```

If the user mentioned a specific Linear issue or task, pass it as an argument:

```bash
bash ~/.claude/scripts/cmux-workspace-name.sh "PROJ-XXX"
```

Skip silently if cmux is unavailable.

### 7. Ask for Session Intentions

Prompt the user:
1. What are you hoping to accomplish this session?
2. How are you feeling about the project right now?
3. Anything on your mind that might affect today's work?

### 8. Record Their Response

Acknowledge their intentions and store for end-of-session reflection.

### 9. Offer to fire the recommended next command (v1.8.0.2+)

If NEXT.md surfaced a `/launch <ID>` recommendation AND the current branch is a feature branch matching that issue (i.e., user already ran `/branch --linear`), offer to fire the command. **Default the offered form to `--auto`** for Standard-tier issues — that's the canonical happy path:

```
Ready when you are. Say `go` and I'll run /launch RS-XX --auto
(or run a specific variant: `/launch RS-XX` without --auto, or `/launch RS-XX --close` if you've already finished and just need to close).
```

**Tier handling:**
- Standard tier (the common case) → offer `--auto`
- Heavy tier (security review + mandatory `/strategy-sync`) → offer plain `/launch RS-XX` (without `--auto`); `/launch --auto` rejects Heavy
- Quick tier → offer `/06-linear-todo-runner` (or `/launch` plain — runner handles the queue)

If you don't know the tier from NEXT.md or the spec, default to `--auto` and let `/launch` reject and route appropriately if it's Heavy.

If the current branch is NOT the feature branch for the recommended issue (e.g., user is still on dev), offer the issue but defer firing — point them to `/branch --linear RS-XX` first.

## Related

- End Session skill (`/end-session`) - captures reflections at session end
- Session logs: `Logs/Sessions/YYYY-MM-DD_HHMM.md`
