---
name: phase-plan
description: Advance the current initiative on the Linear-native surface — derive the active i{N}./P{N}., promote its issues to Needs Spec, roll the pointer forward. Use when an initiative is closing.
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
| **Initiative** | Initiative | `i{N}. label` | Ordered roadmap initiative. Status `Active`/`Planned`/`Completed`. |
| **Sub-phase / execution batch** | Project | `I{N}.P{N}. label` (v4.5.0+; legacy bare `P{N}.` still parses) | The batch you're building now. State `started`/`planned`/`completed`. Issues live here. |
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
- **A project is the execution batch.** Roadmap-create sets membership; phase-plan promotes and advances.
  Keep projects to ~3–8 issues; if a `P{N}.` is too big, split it into `P{N}a`/renumber in `/roadmap-create`.
- **Dependencies within the sub-phase should be satisfiable** (blocker Done, or in the same project).
- **Advance deliberately.** `--next` only closes a sub-phase the human confirms is done.
- **No files.** Initiative state is Linear state. Never write `PHASES.md` / `linear-map.json`.

## Common Drifts to Avoid

- **Declaring a "current initiative"** → it's derived. If `pk next` and this skill disagree, a prefix is
  malformed or a Linear state is stale — fix the Linear state, don't add a pointer file.
- **Advancing with issues unfinished** → only `--next` past a sub-phase whose issues are Done. Planning
  on hope leaves stalled phases.
- **Over-stuffing a project** → keep ~3–8 issues. Re-scope via `--rebalance` or split in `/roadmap-create`.

## Next-step output

After initiative work, emit an inline `➜ Next:` line pointing to the highest-leverage first `/01-light-spec`
call. Do **not** write a `NEXT.md` — `pk next` reads "what's next?" live from Linear.

## Related

- `/roadmap-create` — previous step: authors the Linear Initiative→Project→Issue hierarchy
- `/roadmap-review` — validate the hierarchy before speccing
- `/light-spec` — next step: spec the first promoted issue
- `pk status` / `pk next` — the same derived initiative surface, from the CLI
- `method.config.md § Initiative Surface` — the naming-convention contract
