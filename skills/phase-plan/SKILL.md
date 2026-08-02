---
name: phase-plan
description: Advance the current initiative on the Linear-native surface — derive the active i{N}./P{N}., cut new lanes from the backlog, promote issues to Needs Spec, roll the pointer forward. Use when a lane is spent or an initiative is closing.
---

# Phase Plan Skill

You are an initiative manager. Your job is to confirm which initiative is current, promote its issues into the spec
pipeline, and advance the initiative pointer when it closes. Read `method.config.md § Initiative Surface` for the
naming-convention contract. **Initiative state lives in Linear, not a file** — there is no `PHASES.md`.

## Triggers

- `/phase-plan`
- `/phase-plan --next`
- `/phase-plan --status`
- `/phase-plan --rebalance`

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Confirm the current initiative; promote its issues to Needs Spec |
| `--cut` | **Cut a new lane** — batch 3–8 issues out of the Area backlog into a fresh `I{N}.P{M}.` project |
| `--next` | Advance the phase pointer: close the current sub-phase, open the next |
| `--status` | Current-phase progress dashboard (derived live from Linear) |
| `--rebalance` | Move issues between projects (re-scope the current sub-phase) |
| `--dry-run` | Show what would change without writing to Linear |

## Prerequisites

- Linear board populated with the native initiative surface (run `/roadmap-create` first)
- `method.config.md` with Linear state IDs and `§ Initiative Surface`

## Phase Model (Linear-native)

| Concept | Linear construct | Naming | Role |
|---------|-----------------|--------|------|
| **Initiative / release phase** | Initiative | `i{N}. label` | Ordered and **completable**. Status `Active`/`Planned`/`Completed`. |
| **Lane / execution batch** | Project | `I{N}.P{N}. label` (v4.5.0+; legacy bare `P{N}.` still parses) | A **completable batch of 3–8 issues**. State `started`/`planned`/`completed`. |
| **Theme** | Initiative, unprefixed | `label` | A long-running strand; allowed to never complete. Ignored by the walk. |
| **Uncut backlog** | Issue, no project | identifier | The default resting state, classified by an `Area:` label. |
| **Work item** | Issue | identifier | Moves On Deck → Needs Spec → … → Done. |
| **Milestone** (optional) | Milestone | free | Intra-project gating, orthogonal to phases. |

Projects carry their initiative number as a leading `I{N}.` prefix (`I1.P2. label`) so the phase reads at
the project level — the unit you navigate in Linear. The `P{N}` number still sets sub-phase order; `bin/pk`
accepts both `I{N}.P{N}.` and legacy bare `P{N}.`.

**The current initiative is *derived*, not declared.** Current initiative = lowest `i{N}` initiative whose status
≠ `Completed`; current sub-phase = lowest `P{N}` project in it whose state ∉ {`completed`,`canceled`}.
This is exactly what `pk next` / `pk status` compute — this skill is the human-facing tool for the same
surface. Order is the prefix number (numeric), never Linear `sortOrder`.

---

## Execution Steps

### Default: Confirm the current phase and promote its issues

#### Step 1 — Derive current state from Linear

1. Fetch initiatives + their projects (with `status`/`state`). The current initiative/sub-phase fall out of
   the rule above. Cross-check with `pk status` (its Roadmap section shows the same walk).
2. Fetch the current project's issues from Linear, grouped by status (On Deck, Needs Spec, Specced,
   Approved, Building, UAT, Done).
3. Report the derived position:

```
Current initiative: i1. Foundation   [Active]
Current sub-phase:  I1.P2. Auth & Permissions   [started]
  On Deck:     PROJ-3, PROJ-4, PROJ-5
  Needs Spec:  PROJ-6
  In flight:   PROJ-2 (Building)
  Done:        PROJ-1
```

If the current project's issues are **all Done**, this sub-phase is complete — recommend `--next`.

#### Step 2 — Promote this sub-phase's issues to Needs Spec

The project membership *is* the batch (set at `/roadmap-create`). This skill moves that batch into the
spec pipeline. On confirmation:

1. Move the current project's `On Deck` issues → `Needs Spec` via `mcp__linear-server__linear_updateIssue`
   (`stateId` from `method.config.md`). Skip issues blocked by an unfinished issue outside the project.
2. Post a Linear comment on each: `"Promoted in {i{N}. initiative} / {P{N}. sub-phase}. Ready for /light-spec."`
3. Do **not** write any file. The Linear state change *is* the record.

#### Step 3 — Summary

```
## Initiative confirmed: i1. Foundation / I1.P2. Auth & Permissions

Promoted to Needs Spec: {N}
Held (blocked):         {M}  — {ids + blockers}

Next steps:
  - /roadmap-review   — validate before speccing
  - /light-spec PROJ-3 — start the first issue
  - pk next            — same view, anytime
```

---

### `--cut`: Cut a new lane out of the backlog

**This is the operation that keeps the board walkable.** Uncut work sits project-less with an `Area:` label; the `i{N}.`→`P{N}.` walk cannot see it. Cutting turns a slice of that backlog into a completable lane the walk *can* see. It is a deliberate planning act — always propose the full lane and get confirmation before writing.

1. **Pick the target initiative** — normally the current one. Read `method.config.md § Initiative Surface → Area Labels` for the Area label set and `Lane size` (default `3-8`).
2. **Survey the candidates.** Fetch open project-less issues, filtered to one `Area:` label, minimal fields only. Propose a slice that is **coherent** (one theme a human would call a batch) and **completable** (the lane can be called done when these are done). If a natural batch exceeds the `Lane size` upper bound, cut two lanes rather than one big one — an oversized lane is a pool with a lane's name.
3. **Name it `I{N}.P{M}.`** where `{N}` is the initiative number and `{M}` is the next free project number in that initiative. Numbers are never reused within an initiative, and gaps are fine.
4. **Write the serialization notes into `content`, not `description`.** Linear's project `description` **hard-caps at 255 characters**; long notes silently belong in the markdown `content` body. Keep `description` a trimmed one-line summary. Record which issues must run in sequence (and why — usually shared files or migration ordering) and which are parallel-safe. Real intra-lane ordering is `blockedBy` relations; the notes explain them, they don't replace them.
5. **Stamp the run order** on each issue's `sortOrder`, ascending in intended execution order, stepped (`-2,000,000` upward in `1000` steps leaves room to insert). The project view under *Manual* ordering then reads top-to-bottom as the run sequence.
   - **Display settings are settable via the API** — `viewPreferencesCreate(input: {type: organization, viewType: project, projectId: …, preferences: {"issueGrouping": "none", "viewOrdering": "manual"}})`. A wrong key or value **stores fine and silently does nothing**, and project-scoped rows have no API read surface, so verify one in the browser after the first use. See `sop/Linear_SOP.md` § API gotchas.
   - **The stamp is authoritative for queued issues only.** A workflow-state change re-ranks `sortOrder`, so once an issue enters the pipeline its position is its state, not its stamp. Don't re-stamp in-flight work to "fix" the order.
6. **Create and populate.** `linear_createProject` (with `initiativeId`, and `state`: `started` if this is the lane you're starting now, else `planned`), then one `linear_updateIssue` per member setting `projectId` **and** `sortOrder` together, and verify the echo.
   - **Issues in a Triage-type state are invisible in project views and excluded from project scope counts.** Triage them out first, or the lane will render short and read as half-empty. (Anchor: SiteLine PIPER-559.)
   - **Leave `Area:` labels alone** — they persist through the cut. That's what keeps the backlog views honest.
7. **Sanity-gate before the first write.** Count the candidate set, then re-survey it fresh and compare (tolerance ±5). A batch board mutation that starts from a stale survey is very hard to unwind.

Report the lane, its members in run order, and the serialization notes. Then offer the default flow to promote its issues.

**Closing an initiative.** When the last lane in an initiative completes, set the initiative `Completed` and deal with the tail explicitly — never let it vanish:

- Issues already **spec-approved** but unbuilt → a named close-out lane at the head of the *next* initiative (`I{N+1}.P0. <Prev> close-out`).
- **Unspecced** leftovers → back to project-less + their `Area:` label. They rejoin the backlog and get cut again later.
- If the next initiative has no live work yet, it needs a **placeholder** lane (description containing the literal word `placeholder`), or the walk reads it as finished and skips it.

**Number reuse at the boundary.** The current initiative must be the *lowest* non-`Completed` `i{N}`. If a long-running strand is squatting on a low number, de-prefix it to a theme (freeing the integer) or renumber it **highest** — a parallel strand that never gates the arc belongs at `i8.`, not unprefixed: high keeps it inside the walk (so its work stays visible) while guaranteeing it never becomes "current" ahead of the real arc. Completed initiatives keep their prefixes as history.

---

### `--next`: Advance the phase pointer

Close the current sub-phase and open the next. Order is by `P{N}.`, then by `i{N}.` at an initiative boundary.

1. **Confirm the current sub-phase is done** (all its issues Done/Canceled). If not, warn and require
   explicit confirmation to advance anyway.
2. Set the current project's state → `completed` (`linear_updateProject`).
3. **Find the next live sub-phase:**
   - Next `P{N}.` project in the same initiative (by number) that isn't completed → set it `started`.
   - If none remain, the **initiative** is done: set the current initiative `Completed`, set the next `i{N}.`
     initiative `Active`, and `started` on its first `P{N}.` project.
4. Run the default flow (Steps 1–3) on the newly-current sub-phase to promote its issues.
5. Brief retrospective:

```
## i1.P1 (Data Foundation) closed
Issues: {done}/{total} Done   ({failed} returned to Approved)
Advanced to: i1. Foundation / P2. Auth & Permissions
```

---

### `--status`: Initiative Progress Dashboard (derived from Linear)

1. Derive current initiative/sub-phase from Linear (the rule above).
2. Fetch each current-project issue's status.
3. Display:

```
## i1. Foundation / P2. Auth & Permissions — {date}

| Issue  | Title               | Status     | Days in status |
|--------|---------------------|------------|----------------|
| PROJ-1 | Login / session     | Done       | —              |
| PROJ-2 | Roles + RLS         | Building   | 2d             |
| PROJ-3 | Permission UI       | Needs Spec | 3d             |

Sub-phase progress: 1/3 Done
Roadmap:  i1[Active] → P2(current) → P3 …   |   i2[Planned] …

Alerts:
  - PROJ-3 in "Needs Spec" 3d — run /light-spec PROJ-3
```

(`pk status` shows the cross-initiative roadmap walk; `--status` zooms into the current sub-phase.)

---

### `--rebalance`: Re-scope the current sub-phase

Move issues between projects in Linear (the membership *is* the batch):

1. Show the current project's issues + adjacent projects' On Deck issues.
2. **Add:** reassign an issue's `projectId` to the current project (`linear_updateIssue`), then promote.
3. **Remove:** reassign an issue out to a later `P{N}.` project (only if not yet started).
4. Validate dependencies after the move (no issue left blocked by one outside its phase).

---

## Rules

- **The current initiative is derived, never declared.** Don't write a "Current Initiative" anywhere — read it
  from Linear initiative/project state.
- **Order is the prefix number.** `P2` before `P10`; `i1` before `i2`. Never Linear `sortOrder`.
- **A project is a completable lane, never a standing pool.** Keep it to `Lane size` (default 3–8) issues.
  A project that keeps accepting work is invisible to the walk — `pk status` will point at some idle lane
  while the real work hides inside the pool. If a lane outgrows the bound, cut a second lane (`--cut`);
  don't let it grow. `/linear-hygiene` Phase 2b flags the overflow as pool smell.
- **Lanes are supposed to finish.** Complete a lane the moment its last issue is Done — an open lane with
  zero open issues stays "current" forever.
- **Empty placeholder lanes are load-bearing**, not clutter. An initiative whose projects are all completed
  reads as done to the walk and gets skipped. Never clean these up.
- **Dependencies within the sub-phase should be satisfiable** (blocker Done, or in the same project).
- **Advance deliberately.** `--next` only closes a sub-phase the human confirms is done.
- **No files.** Initiative state is Linear state. Never write `PHASES.md` / `linear-map.json`.

## Common Drifts to Avoid

- **Declaring a "current initiative"** → it's derived. If `pk next` and this skill disagree, a prefix is
  malformed or a Linear state is stale — fix the Linear state, don't add a pointer file.
- **Advancing with issues unfinished** → only `--next` past a sub-phase whose issues are Done. Planning
  on hope leaves stalled phases.
- **Over-stuffing a project** → keep ~3–8 issues. Re-scope via `--rebalance`, or cut a second lane (`--cut`).
- **Creating a project to hold "everything about X"** → that's a pool, and the walk can't see into it. The
  home for uncut work is *no project* plus an `Area:` label. (Anchor: SiteLine, 2026-08-02 — 98 of 162 open
  issues sat in three pool projects; `pk status` pointed at a lane idle since 07-17 while 100% of live work
  was invisible, and the real execution order had migrated into a gitignored notes file.)
- **Deleting an empty placeholder lane** → it's the thing stopping the walk from skipping that initiative.

## Next-step output

After initiative work, emit an inline `➜ Next:` line pointing to the highest-leverage first `/01-light-spec`
call. Do **not** write a `NEXT.md` — `pk next` reads "what's next?" live from Linear.

## Related

- `/roadmap-create` — previous step: authors the Linear Initiative→Project→Issue hierarchy
- `/roadmap-review` — validate the hierarchy before speccing
- `/light-spec` — next step: spec the first promoted issue
- `pk status` / `pk next` — the same derived initiative surface, from the CLI
- `method.config.md § Initiative Surface` — the naming-convention contract
