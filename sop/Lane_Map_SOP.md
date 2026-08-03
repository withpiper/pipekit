# Lane Map SOP

> For the full development pipeline, see [method.md](../method.md).

**v4.29.0** — Last updated: 2026-08-03  *(New: canonical conventions for `/lane-map`, the first scaffold-once skill — seeded from an upstream template once, then owned by the project. This file is the portable half of that split; the scaffolded `.claude/skills/lane-map/SKILL.md` is the instance half. Sourced from SiteLine's `Pipekit_Handover_LaneMap_2026.08.03_v1.md`.)*

---

## What a lane map is

A lane map is a private web artifact that mirrors the current initiative's board: a "start now" frontier of run-order heads, one row per lane with chips in stamped order, and — optionally — a collision register and an all-initiatives arc rail. It is the visual read of exactly the surface `/phase-plan --cut` and `/linear-hygiene` mutate. See `Linear_SOP.md § Board shapes` for what a lane and a run-order head actually are — **this SOP does not restate that definition**; see § Why this is split for why.

## Why this is split

The map has two halves that change at different rates and are owned by different parties:

| Half | Owns | Changes when |
|---|---|---|
| **Conventions** (this file, synced always) | Pipekit | The frontier rule, board-shape semantics, or a read-discipline gotcha needs fixing everywhere at once |
| **Curation** (`.claude/skills/lane-map/SKILL.md`, scaffolded once) | The project | Parallel-safe groupings, the collision register, chip notes (`waits for 517`, `⚠ 546 · menu.js`), the artifact URL, lane→icon assignments |

The curation cannot be derived from the board — it comes from reading the codebase. A portable skill can carry render conventions; it can never carry the curation. That is why `/lane-map` is **scaffold-once**, not fully portable: seeded from the upstream template on first sync if `.claude/skills/lane-map/` is absent, never touched again once it exists. See `Skills_SOP.md § Syncing Portable Skills` for the general mechanism.

A map is also **per-board, not per-repo** — two repos on one Linear workspace (e.g. an initiative whose work runs in a sibling repo) must not each publish a diverging snapshot of the same board. The artifact URL therefore lives in `method.config.md § Lane map URL`, never as a constant in the skill body, so one map can serve N repos that share a board.

## Frontier rule

The frontier is **run-order heads only** — one chip per active lane, flagged when the head issue is not build-ready. Queued-approved work is named in the lane's caption, not promoted into the frontier strip; promoting it would imply a parallel-startability the run order doesn't support. For what makes an issue the "head" of its lane, and why cycle membership cannot substitute for it, see `Linear_SOP.md § Board shapes` and `/linear-hygiene`. Don't restate that rule here or in the scaffolded skill — a fact restated in prose across files survives "fixed everywhere" commits that a line-anchored grep can't catch (`.claude/rules/pipekit-tooling.md` § Enumerate the Surface Before Claiming Behavior, PIPER-486 anchor).

## Board first, then the map

The map mirrors the board and never asserts something the board does not say. Reconcile first — misfiled follow-ups, stale stamps, wrong cycle — then render. A map that renders ahead of reconciliation just gives the drift a nicer face.

## Read discipline

A map read touches every lane in the current initiative, which makes it exactly the shape `.claude/rules/pipekit-tooling.md § MCP Result Payloads Are Sticky` warns about. Read with lean GraphQL, never `linear_getIssueById` — it drags the full description plus the entire comment thread per issue. Query per-initiative, not all-projects × all-issues; Linear's complexity cap makes the wide query fail outright before it makes it slow (see `Linear_SOP.md` for MCP gaps that fall back to GraphQL).

## Artifact constraints

The published page cannot call Linear directly: the CSP blocks external hosts, and no credential may ever be embedded in it. The only supported live path is the `mcp` runtime capability against a claude.ai connector, viewer-credentialed — load the `artifact-capabilities` skill before declaring that capability. Publish to a stable URL (redeploy the same file path on updates, don't mint a new one) and keep the favicon identical across republishes, so the map stays the same tab for a returning viewer.

## Snapshot vs. live is a decision, not a TODO

A curated snapshot — rendered on demand, not continuously refreshed — is the deliberate default. A live feed buys freshness and spends the curation that justifies the map in the first place: parallel-safe groupings and collision notes are judgment calls a live re-render can't reconstruct from the board alone. Don't read "not yet live" in a project's lane-map skill as an unfinished feature unless that project's own notes say otherwise.

## Render conventions (loose, not a template)

These are available patterns, not a required visual spec — a project's map should look like the project, not like a generic Pipekit artifact:

- **Done-collapse** — completed lanes/issues fold to a compact row rather than taking full chip space.
- **Priority badges** — a small visual marker on chips carrying elevated priority, distinct from the collision register.
- **Initiative dropdown** — lets the viewer switch the rendered initiative without republishing a new artifact per initiative.
- **Collision register** — a function/file-level table naming where two active lanes touch the same code, so a viewer can see parallel-safety at a glance without reading both diffs.

Brand tokens, icon fonts, and exact layout are project-owned — the scaffolded skill is where those live, not this SOP.
