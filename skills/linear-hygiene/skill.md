---
name: linear-hygiene
description: Fast Linear placement janitor — finds orphaned / untriaged / unprioritized issues across all open states and batch-homes them. Use after pk done, before a phase, or whenever follow-ups have piled up. Propose-then-apply, importance-aware. Placement only (where does it belong?), not disposition (is it worth doing? — that's /brainstorm-review).
---

# Linear Hygiene Skill

You are a Linear placement janitor. During the daily loop, `/work`, `/verify`, `pk ship`, `/pk-express`, and `/brainstorm` spin off follow-up issues mid-flow. They reliably land **orphaned** (no project), **stuck in Triage**, and **unprioritized** (priority 0), then accumulate until someone does a big manual reorg. This skill is the fast, frequent, all-states sweep that homes them before they pile up.

It answers **"where does it belong?"** (placement), not **"is it worth doing?"** (disposition — that's `/brainstorm-review`) and not **"does the plan cover the requirements?"** (audit — that's `/roadmap-review`). Routing a Triage item to `Needs Spec` vs `Backlog` by its priority is still placement — it files an already-open (already worth-doing) issue into the right lane by the importance signal it carries. It never renders a Now/Later/Kill verdict, never Parks, never Cancels; that stays with `/brainstorm-review`.

**Run from the parent project root**, not from inside a `pk branch` worktree.

## Triggers

- `/linear-hygiene` · "tidy linear" · "sweep orphans" · "clean up the board"

## Modes

- **default** — propose + apply (Phases 1–6).
- **`--check`** — detect-only. Run Phases 1–4, print the manifest, **make zero writes**. This is what `/pk-exit` calls; it honors the same no-Linear-writes rule.

## Tooling notes (read before building against this)

- Targets **`@tacticlaunch/mcp-linear`** — the Linear MCP server both consuming projects register as `linear-server`. Tool names are camelCase: `mcp__linear-server__{linear_searchIssues, linear_getIssueById, linear_updateIssue, linear_getProjects}` — the same tools every other Linear-using skill calls. **One `linear_updateIssue` carries `projectId` + `priority` + `stateId` together** (verified live on SiteLine, 2026-06-19).
- **Not the official remote.** The first-party `mcp.linear.app` server uses snake_case (`list_issues`, `update_issue`) and lacks the initiative / label-create / issue-relation tools pipekit skills rely on. Pipekit's Linear skills assume the tacticlaunch surface; a project on a different Linear MCP server needs the tool names remapped.

## Execution Steps

### Phase 1 — Fetch (payload-safe)

1. Read `method.config.md` → Team ID, Workflow State IDs, and the project's **open-state set** (everything except Done / Canceled / Duplicate — typically `Triage, Backlog, Needs Spec, Approved, In Progress, In Dev, UAT`).
2. `mcp__linear-server__linear_searchIssues` across those open states, requesting a **minimal field set** (`identifier, title, state, priority, project, labels, createdAt`). Do **not** pull descriptions board-wide.
   > **Payload watch-out (learned the hard way):** a board-wide `linear_searchIssues` with full descriptions can exceed a single context (~158K chars on a ~48-issue board). Page by state or have a subagent digest a saved tool-result if the board is large. Only fetch bodies for the drift subset (Phase 2).
3. `mcp__linear-server__linear_getProjects` once → cache `{name, description, id}` for inference.
4. **Exclude** any issue carrying the `Parked` *label* (already dispositioned "Later" by `/brainstorm-review`).

### Phase 2 — Classify (an issue can hit several)

- 🏚️ **Orphan** — `project == null`.
- 🔶 **Stuck in Triage** — `state == Triage`.
- ⚪ **Unprioritized** — `priority == 0`.

Pull `mcp__linear-server__linear_getIssueById` (with `includeRelations: true`) **only for the drift subset** — the issues that hit at least one class above — to read the body (for parent-project inference) and relations.

### Phase 3 — Infer the fix per issue

- **Project (for orphans):**
  1. If the body names a parent issue (`follow-up to/from <ID>`, `Source: <ID>`, `Related: <ID>`, `Split from <ID>`, where `<ID>` is any Linear identifier `[A-Z]+-N` — match every prefix, not just the workspace's current one: a prefix migration leaves older bodies citing the old prefix) → `get_issue(parent)` → use the **parent's project** (highest-confidence signal).
  2. Else keyword-match title/body against the cached project **names + descriptions** (derive candidates dynamically — never hardcode a keyword→project map; that's what keeps it portable).
  3. If still ambiguous → leave unhomed; present the **top-2 candidates** for a human pick in the manifest.
- **Priority (importance ranking — the load-bearing part).** Map these label *roles* to your project's actual label names (defaults shown; override in `method.config.md` if your labels differ). Linear priority ints: Urgent 1, High 2, Normal 3, Low 4.

  | Signal on the issue | Floor |
  |---|---|
  | `Client Request` label | **High (2)** |
  | `Bug` + `Client Request` | **High (2)** |
  | declares it **blocks** another open issue | inherit the blocked issue's priority, min **Normal (3)** |
  | `Bug` (alone) | **Normal (3)** |
  | `Feature` / `Improvement`, no urgency signal | **Low (4)** |
  | none of the above | **Low (4)** |

  **Never lower an existing non-zero priority** — only fill `0`, or raise per a signal above. The catch-all floor is **Low**, not Normal: an item with no importance signal is *Low until proven otherwise*, so it doesn't get slated for speccing (and surfaced by `pk next`) just for existing. `Normal+` should mean "a signal said this matters."
- **State (for Triage), by the priority resolved above — importance, not difficulty:** `Normal (3)` or higher → **`Needs Spec`** (important enough to slate for speccing, so `pk next` surfaces it); `Low (4)` → **`Backlog`** (homed and prioritized, but not on the spec lane yet). `tier:*` no longer routes state — an important item must not wait in Backlog for lack of a size label, and a low one must not jump the queue for having one. **Exception — bundles:** if the body visibly packs several distinct asks (raw feedback often does: "grid lines + header parity + column-hide + logo"), route it to **`Backlog`** regardless of priority and flag `/brainstorm-review` to split + disposition first — `Needs Spec` is for one spec-able thing, not a four-ask pile.

### Phase 4 — Manifest (single confirm)

Print ONE table, **sorted by inferred priority descending** so important follow-ups sit on top:

```
## /linear-hygiene — {N} issues drifting

| Issue | Drift | → Project | → Priority | → State | Title |
|-------|-------|-----------|-----------|---------|-------|
| POC-232 | 🏚️🔶 | I2.P1. Export Improvements | Normal | Needs Spec | Compare removed-block… |
| POC-241 | 🔶⚪ | I1.P3. Client Portal | Low | Backlog | Tidy footer spacing… |
| ...

⚠️ Needs your pick: POC-NNN → [I2.P1. Export Improvements | I1.P3. Client Portal]
Say "go" to apply all, or redirect any line.
```

**In `--check` mode, stop here** — print the manifest (or "✓ board is tidy — no drift") and make no writes.

### Phase 5 — Apply (on `go`, default mode only)

- One `mcp__linear-server__linear_updateIssue` per issue combining `projectId` + `priority` + `stateId`.
- Batch independent calls in parallel.
- Skip any line the user redirected to a manual pick that they didn't resolve.

### Phase 6 — Summary

```
## /linear-hygiene complete

Homed: {N} orphans → projects
Prioritized: {N} (filled priority 0 / raised per signal)
Un-triaged: {N} (Triage → Needs Spec if Normal+, else Backlog; bundles → Backlog)
Left for your pick: {N} (ambiguous project)
```

Suggest `/brainstorm-review` for items that need a Now/Later/Kill **verdict** — placement ≠ disposition.

## Drifts to Avoid

- **Don't touch `Parked`-labelled issues** — they're already dispositioned "Later."
- **Don't lower an existing priority** — only fill `0` or raise per a signal.
- **Don't guess a project when confidence is low** — surface the top-2 candidates instead.
- **Don't pull full board descriptions into context** — minimal fields board-wide, bodies only for the drift subset (Phase 1/2).
- **Don't write in `--check` mode** — it's read-only by contract (`/pk-exit` depends on this).
- **Don't infer or apply a phase-visualization label from a re-homed `projectId`.** When you set an orphan's project (Phase 3/5), **never** add a `Roadmap: Phase X` / `Roadmap: Continuous` label (or this project's equivalent, per `method.config.md § Phase Label Layer`) just because the target project belongs to a phase arc. **Project membership ≠ phase-label membership** — a phase-arc project routinely holds a mix of phase-labeled work and non-phase work. Phase-label placement is owned by `/roadmap-review`'s Phase-Label Layer pass (drift-checked against `ROADMAP.md`), not by this placement janitor. This skill mutates `projectId` / `priority` / `stateId` only — it must not touch `Roadmap: *` labels at all. *(Anchor: SiteLine POC-382 was re-parented into a Phase-A project during a placement pass and silently picked up a stray `Roadmap: Phase A` label, but `ROADMAP.md` places it under Continuous.)*

## Deferred to v2 (not in this version)

- 🔗 **Isolated → relation linking** (body references a parent but no `blocked-by`/`relates` relation exists). Uses `mcp__linear-server__linear_createIssueRelation` — **confirmed present** on `@tacticlaunch/mcp-linear` (already called by `/roadmap-create`); deferred only to keep this pass scoped to tool-name correctness.
- 🧹 **Strip stale labels.** Uses `mcp__linear-server__linear_removeIssueLabel` — **confirmed present**; deferred for the same reason.
- **`--session` mode** — limit to issues `createdAt >= session start`, to catch only the current session's follow-ups.

## Related

- `/brainstorm-review` — Now/Later/Kill **disposition** (Triage/Ideas only); this skill is placement across all open states.
- `/roadmap-review` — full-board plan-vs-requirements audit against the Linear-native initiative surface (heavyweight).
- `/pk-exit` — calls `/linear-hygiene --check` to surface drift while context is warm at session close.
