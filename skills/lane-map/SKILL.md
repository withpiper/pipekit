---
name: lane-map
description: Render the current initiative's board as a private web artifact — frontier of run-order heads, one row per lane, optional collision register. Scaffolded once on first sync, then owned by this project; conventions live in sop/Lane_Map_SOP.md, curation lives here.
---

# Lane Map Skill

Renders the board as a private web [Artifact](https://claude.ai) — a "start now" frontier plus one row per lane. This file was seeded once from Pipekit's upstream template and is now **owned by this project**: sync will never overwrite it again. Edit it freely, including this instruction body.

**Conventions — read before rendering:** `sop/Lane_Map_SOP.md` has the frontier rule, the board-first-then-map principle, read discipline, artifact constraints, and the snapshot-vs-live decision. This file does not restate them.

## Triggers

- `/lane-map` · "map the board" · "show the lanes"

## Configuration

Artifact URL: `method.config.md § Lane map URL`. Blank until this skill has published once — on first run, publish via the `Artifact` tool, then add the returned URL to `method.config.md` yourself so later runs redeploy the same page instead of minting a new one.

## Execution steps

1. **Read the current initiative's board.** Per-initiative query, lean fields only — never `linear_getIssueById` (see SOP § Read discipline).
2. **Reconcile before rendering.** Check for misfiled follow-ups, stale run-order stamps, or wrong cycle membership against the current initiative — fix these in Linear first, don't render around them.
3. **Compute the frontier.** One chip per active lane's run-order head (SOP § Frontier rule; `sop/Linear_SOP.md § Board shapes` for what a head is — don't restate that rule here). Flag any head that isn't build-ready.
4. **Apply this project's curation** (below) — parallel-safe groupings, collision notes, icon assignments.
5. **Publish.** Load the `artifact-design` skill (and `artifact-capabilities` if wiring the live `mcp` path) before writing HTML. Redeploy to the URL configured above rather than minting a new one; keep the favicon stable across republishes.

## Project curation — edit freely, sync will never touch this file

> Fill these in for this project. None of this can be derived from the board — it comes from reading the codebase.

**Lane → icon map:**
_(none yet — add as lanes are created)_

**Parallel-safe groupings:**
_(none yet)_

**Collision register** (function/file-level, active lanes only):
_(none yet)_

**Chip note conventions used here** (e.g. `waits for <issue>`, `⚠ <issue> · <file>`):
_(none yet)_

**Project-specific gotchas:**
_(none yet — e.g. a custom icon font path, brand tokens, or an initiative this project excludes from the map)_
