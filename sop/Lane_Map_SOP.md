# Lane Map SOP

> For the full development pipeline, see [method.md](../method.md).

**v4.29.1** — Last updated: 2026-08-03  *(Snapshot-vs-live softened from a binary choice to a decision with a documented hybrid option: curation stays authored, a live overlay can reconcile onto it loudly (append+flag uncurated-active, fold uncurated-done, mark curated-but-gone stale) instead of the map picking a side — this is also the staleness signal for free, no timestamp check needed. Plus an artifact gotcha: declaring `mcp` on a publicly-shared artifact 422s; un-share first via the claude.ai UI, no tool-level path. Sourced from SiteLine's `Pipekit_Handover_LaneMap_Live_2026.08.03_v1.md`.)*

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

**Gotcha: declaring `mcp` on a publicly-shared artifact fails (422).** There's no tool-level way to un-share from here — un-sharing is a claude.ai UI action on the artifact's own page. If a lane map was ever shared publicly (even before it needed a live capability), un-share it first, then declare `mcp`.

## Snapshot vs. live is a decision, not a TODO

A curated snapshot — rendered on demand, not continuously refreshed — is the deliberate default. Curation (parallel-safe groupings, collision notes, which lanes count toward the frontier) is a judgment call a live re-render can't reconstruct from the board alone, and that fact doesn't change. Don't read "not yet live" in a project's lane-map skill as an unfinished feature unless that project's own notes say otherwise.

That said, "curated vs. live" is not strictly a fork in the road. A project can keep curation authored while merging live board state on top of it at render time — see § Reconciling live against curated below. Treat that as a documented option a project can opt into deliberately, not a more-finished successor to the snapshot default; most projects should still start with the snapshot.

### Reconciling live against curated (optional)

If a project's lane map does merge live Linear state onto authored curation (keyed on issue identifier), don't let the two silently diverge — reconcile loudly instead of picking one side as truth. Three cases:

- **Live issue not in the curated lane's flow, still active** → render it appended and visibly marked *uncurated*, and count it toward the frontier regardless of the flag. An issue that's already in flight can't be allowed to go invisible just because no one curated it yet — that's the specific failure mode the old uncurated pools had.
- **Live issue not in the curated flow, already done/duplicate/canceled** → fold it silently into the done-stack. Shipped-and-forgotten curation isn't a safety issue.
- **Curated flow entry no longer found live** → render a *stale* marker instead of silently dropping or silently keeping it.

This reconciliation is also the staleness signal a separate "is the lane map older than the board" check would otherwise need to compute by timestamp comparison — it falls out for free once live and curated data sit side by side and get diffed on every render, so don't build that check separately if a project already reconciles this way.

## Render conventions (loose, not a template)

These are available patterns, not a required visual spec — a project's map should look like the project, not like a generic Pipekit artifact:

- **Done-collapse** — completed lanes/issues fold to a compact row rather than taking full chip space.
- **Priority badges** — a small visual marker on chips carrying elevated priority, distinct from the collision register.
- **Initiative dropdown** — lets the viewer switch the rendered initiative without republishing a new artifact per initiative.
- **Collision register** — a function/file-level table naming where two active lanes touch the same code, so a viewer can see parallel-safety at a glance without reading both diffs.

Brand tokens, icon fonts, and exact layout are project-owned — the scaffolded skill is where those live, not this SOP.
