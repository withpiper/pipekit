---
name: pk-exit
description: Write the session log to Logs/Sessions/<date>_<HHMM>.md before /exit. Captures narrative — what shipped, decisions, lessons, outstanding work. Run as the last command of every Claude session in a Pipekit project.
---

# /pk-exit Skill

You write a **narrative session log** before the user closes the Claude Code session. This replaces the v2.0–v2.1 bash Stop hook (which was retired because Stop fires on every assistant turn and bash can't write narrative anyway).

The log lives in `Logs/Sessions/<YYYY-MM-DD>_<HHMM>.md`, a persistent human-readable archive. Per-branch journals (`.pipekit/journal/`) are deleted in this design — `pk done` reads commits directly from `git log` for its Linear close comment.

## When to use

Run `/pk-exit` as the **last command of every Claude Code session** in a Pipekit project, immediately before typing `/exit`. Two-keystroke discipline: `/pk-exit` → `/exit`.

If you forget, you forget — no auto-trigger. The user accepted that tradeoff for simplicity.

## Workflow

1. **Determine the log path.** Compute current date + HH:MM (24h, local). Path is `Logs/Sessions/<YYYY-MM-DD>_<HHMM>.md` from the **repo root** (not the worktree — write into the parent's `Logs/Sessions/` so logs accumulate in one place even when you work across worktrees).

   Resolve repo root with `git rev-parse --show-toplevel`. If you're in a worktree, walk up to the parent's main checkout: `git worktree list --porcelain | grep -A1 '^worktree' | head -1` gives the primary worktree path.

   Create `Logs/Sessions/` if it doesn't exist.

2. **Write the narrative.** Use the template below. Fill from session memory + git state. Never fabricate — if a section has nothing to say, write "—" or omit it.

3. **Confirm to the user** with the absolute path. Tell them to type `/exit` next.

## Template

```markdown
# Session Log — <YYYY-MM-DD> (<morning|afternoon|evening|late>)

**Branch flow:** `<starting-branch>` → … → `<ending-branch>`
**Session topic:** <one-line — issue ID + short description, or freeform if not issue-driven>
**Duration:** <approximate, e.g. "~2h">

## Summary

<2-5 sentences. What got done, what's the headline outcome. Read this in 10 seconds and know what shipped.>

## Commits shipped

<List commits made this session as `- <hash> <subject>`. Get from `git log --oneline <session-start-ref>..HEAD` if you can identify the start ref; otherwise list commits touched.>

## Decisions / findings (worth remembering)

<Numbered list of non-obvious things learned this session. Examples:
1. Why a particular approach was rejected
2. A library quirk discovered the hard way
3. A user preference clarified mid-session
4. An assumption that turned out wrong

If the session was pure execution with no decisions, write "—".>

## Outstanding / next session

<Bulleted list of what's left. Loose ends, deferred work, follow-ups. Be specific (issue IDs, file paths) so future-you can pick up cold.>

## QA / verification trail

<Only include if non-trivial. For most sessions: "—". For sessions with multiple QA rounds, plan revisions, or remediation cycles, capture the trail like the v1 logs did:

| Round | Outcome | Notes |
|---|---|---|
| ... | ... | ... |
>

## Linear updates

<List any Linear state transitions, comments posted, issues created. Otherwise "—".>
```

## What NOT to write

- **Don't pad.** A 5-line session deserves a 5-line log. Resist the urge to fill template sections that have no signal.
- **Don't repeat the diff.** Commits + commit subjects are the source of truth. Don't paraphrase what `git show` already says.
- **Don't summarize the user's instructions back at them.** Capture *outcomes* and *decisions*, not the request log.
- **Don't include secrets.** Never paste API responses, env values, or anything matching `lin_api_*`, `sk-*`, `eyJ*`, etc.

## Edge cases

- **No commits this session.** Still write a log — it captures the conversation/decision history. Just leave "Commits shipped" as "—".
- **Worktree session.** Write to the **parent repo's** `Logs/Sessions/`, not the worktree's. Logs are a project-wide archive, not branch-scoped.
- **Two `/pk-exit` calls in one minute.** Same filename collision. Append a `_2` suffix (`<date>_<HHMM>_2.md`) rather than overwriting.
- **Pre-existing v1 `Logs/Sessions/` archive.** Keep writing into the same directory — date-prefixed filenames sort chronologically and the v1 entries remain valid history.

## Calibration notes

- The v1 `/end-session` skill (now archived) was the prior art. This skill restores its core function (narrative session log) without the v1 baggage (NEXT.md updates, branch-status orchestration — those moved to `pk next` / `pk done`).
- The bash Stop hook was retired because: (a) Stop fires on every assistant turn, producing duplicate commit-list entries; (b) bash can't write narrative; (c) `pk done` doesn't need a journal cache — it reads `git log` directly.
- This skill writes one file per session. It does not update Linear (that's `pk done`'s job at issue-close) and does not update PHASES.md (that's `phase-plan`'s job).
