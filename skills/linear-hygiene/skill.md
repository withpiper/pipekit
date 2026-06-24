---
name: linear-hygiene
description: Fast Linear placement janitor — finds orphaned / untriaged / unprioritized issues across all open states and batch-homes them. Use after pk done, before a phase, or whenever follow-ups have piled up. Propose-then-apply, importance-aware. Placement only (where does it belong?), not disposition (is it worth doing? — that's /brainstorm-review).
---

# Linear Hygiene Skill

You are a Linear placement janitor. During the daily loop, `/work`, `/verify`, `pk ship`, `/pk-express`, and `/brainstorm` spin off follow-up issues mid-flow. They reliably land **orphaned** (no project), **stuck in Triage**, and **unprioritized** (priority 0), then accumulate until someone does a big manual reorg. This skill is the fast, frequent, all-states sweep that homes them before they pile up.

It answers **"where does it belong?"** (placement), not **"is it worth doing?"** (disposition — that's `/brainstorm-review`) and not **"does the plan cover the requirements?"** (audit — that's `/roadmap-review`).

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
  1. If the body names a parent issue (`follow-up to/from POC-N`, `Source: POC-N`, `Related: POC-N`, `Split from POC-N`) → `get_issue(parent)` → use the **parent's project** (highest-confidence signal).
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
  | none of the above | **Normal (3)** |

  **Never lower an existing non-zero priority** — only fill `0`, or raise per a signal above.
- **State (for Triage):** → `Backlog` by default; → `Needs Spec` if the issue is `tier:standard` / `tier:heavy` and has no spec (mirrors `/brainstorm-review` Phase 4 tier routing).

### Phase 4 — Manifest (single confirm)

Print ONE table, **sorted by inferred priority descending** so important follow-ups sit on top:

```
## /linear-hygiene — {N} issues drifting

| Issue | Drift | → Project | → Priority | → State | Title |
|-------|-------|-----------|-----------|---------|-------|
| POC-232 | 🏚️🔶 | Export Improvements | Normal | Backlog | Compare removed-block… |
| ...

⚠️ Needs your pick: POC-NNN → [Export Improvements | Client Portal]
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
Un-triaged: {N} (Triage → Backlog / Needs Spec)
Left for your pick: {N} (ambiguous project)
```

Suggest `/brainstorm-review` for items that need a Now/Later/Kill **verdict** — placement ≠ disposition.

## Drifts to Avoid

- **Don't touch `Parked`-labelled issues** — they're already dispositioned "Later."
- **Don't lower an existing priority** — only fill `0` or raise per a signal.
- **Don't guess a project when confidence is low** — surface the top-2 candidates instead.
- **Don't pull full board descriptions into context** — minimal fields board-wide, bodies only for the drift subset (Phase 1/2).
- **Don't write in `--check` mode** — it's read-only by contract (`/pk-exit` depends on this).

## Deferred to v2 (not in this version)

- 🔗 **Isolated → relation linking** (body references a parent but no `blocked-by`/`relates` relation exists). Uses `mcp__linear-server__linear_createIssueRelation` — **confirmed present** on `@tacticlaunch/mcp-linear` (already called by `/roadmap-create`); deferred only to keep this pass scoped to tool-name correctness.
- 🧹 **Strip stale labels.** Uses `mcp__linear-server__linear_removeIssueLabel` — **confirmed present**; deferred for the same reason.
- **`--session` mode** — limit to issues `createdAt >= session start`, to catch only the current session's follow-ups.

## Related

- `/brainstorm-review` — Now/Later/Kill **disposition** (Triage/Ideas only); this skill is placement across all open states.
- `/roadmap-review` — full-board plan-vs-requirements audit against the Linear-native phase surface (heavyweight).
- `/pk-exit` — calls `/linear-hygiene --check` to surface drift while context is warm at session close.
