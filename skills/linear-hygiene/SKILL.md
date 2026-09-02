---
name: linear-hygiene
description: Linear placement janitor — batch-classifies unclassified/untriaged/unprioritized issues, flags board-shape drift (pool smell, spent lanes) and postmortem debt on closed bugs, propose-then-apply. Use after pk done or when follow-ups pile up. Placement only; disposition is /brainstorm-review.
---

# Linear Hygiene Skill

You are a Linear placement janitor. During the daily loop, `/work`, `/verify`, `pk ship`, `/pk-express`, and `/brainstorm` spin off follow-up issues mid-flow. They reliably land **unclassified** (no project *and* no `Area:` label), **stuck in Triage**, and **unprioritized** (priority 0), then accumulate until someone does a big manual reorg. This skill is the fast, frequent, all-states sweep that homes them before they pile up.

**On the lanes model, "no project" is the correct resting state for uncut work** — an issue is homed when it carries the right `Area:` label, not when it has been filed into some project. Filing for the sake of filing is what grows the standing pools this skill also learned to detect (Phase 2b). Read `method.config.md § Initiative Surface` for the board's shape before assuming either.

It answers **"where does it belong?"** (placement), not **"is it worth doing?"** (disposition — that's `/brainstorm-review`) and not **"does the plan cover the requirements?"** (audit — that's `/roadmap-review`). Routing a Triage item to `Needs Spec` vs `Backlog` by its priority is still placement — it files an already-open (already worth-doing) issue into the right lane by the importance signal it carries. It never renders a Now/Later/Kill verdict, never Parks, never Cancels; that stays with `/brainstorm-review`.

**Run from the parent project root**, not from inside a `pk branch` worktree.

## Triggers

- `/linear-hygiene` · "tidy linear" · "sweep orphans" · "clean up the board"

## Modes

- **default** — propose + apply (Phases 1–6).
- **`--check`** — detect-only. Run Phases 1–4, print the manifest, **make zero writes**. This is what `/pk-exit` calls; it honors the same no-Linear-writes rule.

## Tooling notes (read before building against this)

- Targets **`@tacticlaunch/mcp-linear`** — the Linear MCP server both consuming projects register as `linear-server`. Tool names are camelCase: `mcp__linear-server__{linear_searchIssues, linear_getIssueById, linear_updateIssue, linear_getProjects}` — the same tools every other Linear-using skill calls. **One `linear_updateIssue` carries `projectId` + `priority` + `stateId` together** (verified live on SiteLine, 2026-06-19).
- **Rate-limit discipline — Linear's quota is one shared, per-User bucket** (canonical, with the numbers and the anchor, in `sop/Linear_SOP.md` § Rate limits; this skill reads the *whole board*, so every rule there applies here): one subagent with serial calls, never a parallel fan-out at `linear-server`; page in chunks of ~50; on rate-limit wait once, retry once, then stop and report partial; the error is HTTP 400 `RATELIMITED`, not 429; `isBlocked: false` proves "not blocked this instant", never "quota recovered". Prefer running when no `/work` sessions are live (`pgrep -f 'bin/mcp-linear' | wc -l`). Anchor: SiteLine 2026-08-31 — three concurrent sweeps paging 250 blocked the board ~1h and starved four worktree workers.
- **Not the official remote.** The first-party `mcp.linear.app` server uses snake_case (`list_issues`, `update_issue`) and lacks the initiative / label-create / issue-relation tools pipekit skills rely on. Pipekit's Linear skills assume the tacticlaunch surface; a project on a different Linear MCP server needs the tool names remapped.

## Execution Steps

### Phase 1 — Fetch (payload-safe)

1. Read `method.config.md` → Team ID, Workflow State IDs, and the project's **open-state set** (everything except Done / Canceled / Duplicate — typically `Triage, Backlog, Needs Spec, Approved, In Progress, In Dev, UAT`). Also read **`§ Initiative Surface → Area Labels`** (the `Area` label group, its labels, and `Lane size`). If that section is blank, the board isn't on the lanes model — skip the Area routing in Phase 3 and the board-shape checks in Phase 2b, and behave exactly as before.
2. `mcp__linear-server__linear_searchIssues` across those open states, requesting a **minimal field set** (`identifier, title, state, priority, project, labels, createdAt`). Do **not** pull descriptions board-wide.
   > **Payload watch-out (learned the hard way):** a board-wide `linear_searchIssues` with full descriptions can exceed a single context (~158K chars on a ~48-issue board). Page by state or have a subagent digest a saved tool-result if the board is large. Only fetch bodies for the drift subset (Phase 2).
3. `mcp__linear-server__linear_getProjects` once → cache `{name, description, id, state}` for inference **and** for the board-shape checks. Derive each project's open-issue count from the Phase 1.2 result — do **not** issue a per-project issue query (see `sop/Linear_SOP.md` § API gotchas → Query complexity: an all-projects × all-issues nested read exceeds Linear's 10k cap and is rejected outright).
4. **Exclude** any issue carrying the `Parked` *label* (already dispositioned "Later" by `/brainstorm-review`).

### Phase 2 — Classify (an issue can hit several)

- 🏚️ **Orphan** — `project == null`. **On the lanes model this is only drift if the issue also lacks an `Area:` label** — a project-less issue *with* an Area label is correctly-filed uncut backlog, not an orphan. Reclassify it as ⬛ below.
- ⬛ **Unclassified** *(lanes model only)* — `project == null` **and** no `Area:` label. This is the lanes-model orphan: the fix is a label, usually not a project.
- 🔶 **Stuck in Triage** — `state == Triage`.
- ⚪ **Unprioritized** — `priority == 0`.
- 🅿️ **Parked-as-state** — the issue sits in a Parked-*type* workflow state rather than carrying the `Parked` label. A Parked state hides work from every state-based query (including this skill's own Phase 1 fetch, if the state isn't in the open-state set). Fix: move to `Backlog` + apply the `Parked` label.

Pull `mcp__linear-server__linear_getIssueById` (with `includeRelations: true`) **only for the drift subset** — the issues that hit at least one class above — to read the body (for parent-project inference) and relations.

### Phase 2b — Board-shape checks (lanes model only; report, never auto-fix)

Skip entirely when `§ Area Labels` is blank. These are **project-level** findings, and every one of them is resolved by a human planning act in `/phase-plan` — this skill surfaces them and stops. Never create, cut, or complete a project here.

- 🪣 **Pool smell** — a non-theme `I{N}.P{N}.` project holding more than the `Lane size` upper bound (default 8) open issues. A lane is a *completable batch*; a project that keeps accepting work is a pool, and the `i{N}.`→`P{N}.` walk cannot see into it, so `pk status` will point somewhere idle while the real work hides. Report the count and recommend `/phase-plan --cut`.
- 🫗 **Spent lane** — a project with **0 open issues** whose state isn't `completed`/`canceled`. Lanes are supposed to finish; leaving one open makes it the walk's "current sub-phase" forever. Recommend completing it.
  - **Exempt placeholders:** a project whose `description` contains the literal word `placeholder` is *correct* when empty — it exists so an initiative with no live work yet doesn't read as "all projects done" and get skipped by the walk. Never flag these, and never propose deleting them.
- ⚠️ **Walk-skip hazard** — a non-`Completed` initiative whose projects are *all* `completed`/`canceled` **and** which has no placeholder project. The walk will step past this initiative as though it were finished. Recommend adding a placeholder lane.
- 📛 **Status drift** — a lane holding shipped or in-flight issues while still marked `planned`/`backlog`, or an idle lane marked `started`. Project status is read by humans scanning the board; when it stops mirroring reality the board stops being the execution authority.
  - Objective wrong-closure sweep: query projects filtered server-side to `status.type ∈ {completed, canceled}`, each with issues filtered to `state.type ∉ {completed, canceled}`. Any hit other than a `Duplicate`-state issue is rot. **Filter server-side** — see the 10k complexity note in Phase 1.

**Optional cycle hygiene** (only if the team uses cycles): the active cycle should hold in-flight issues plus the head of each active lane, nothing else. Flag off-lane stragglers.

> **What "head of lane" means, precisely.** A lane's run order is stamped in issue `sortOrder` (see `/phase-plan --cut`), but **a workflow-state change re-ranks `sortOrder`** — Linear moves the issue to the top of its new column. Since `pk branch` and `pk ship` are state changes, ordinary pipeline motion perturbs the stamp. So the stamp is authoritative for **queued issues only**: once an issue has entered the pipeline its position *is* its state, not its stamp. Compute the head as *the first issue by stamp among the lane's not-yet-started issues*, and treat anything already in flight as legitimately holding a slot regardless of where its stamp now sits. A check that compares cycle membership against raw `sortOrder` will false-positive after every normal transition.

### Phase 2c — Postmortem debt (report, never auto-fix)

Unlike Phase 2b, this check is **not** lanes-gated — run it whether or not `§ Area Labels` is populated. Phase 1 deliberately fetches **open states only**, so every finding below is invisible to it. This check needs its own query — which is why it is scoped as tightly as it is.

`/pk-bug` Phase 8 makes a postmortem mandatory for priority ≤ 3 (Urgent / High / Medium), and adds a reviewer sign-off for Urgent. Neither is enforceable by workflow state: `pk ship` puts the issue ID at the front of the PR title, so where Linear's GitHub integration transitions on merge, the issue reaches `Done` at Phase 6 — before the postmortem phase runs at all. **A closed bug with no postmortem is the default outcome, not an anomaly**, which is exactly why it needs a sweep rather than a gate.

1. One additional `mcp__linear-server__linear_searchIssues`, filtered **server-side** and scoped hard: `label = Bug`, `state.type = completed`, `priority` in 1–3, `completedAt` within the last 30 days. On a normal board that is single digits. (If the configured Linear MCP surface won't filter on `completedAt`, filter it client-side but keep the label + state + priority filters server-side — see the 10k complexity note in Phase 1.)
2. For **that set only**, read comments and look for a `# Postmortem` heading:
   - 🧾 **Postmortem debt** — no `# Postmortem` comment. Report identifier, priority, and completion date. Recommend `/pk-bug <ID>`: its resume routing sends a `statusType=completed` issue with no postmortem straight into Phase 8.
   - ✍️ **Unsigned postmortem** *(Urgent only)* — a `# Postmortem` comment whose `Reviewer:` / `Approved:` lines are still blank. The postmortem exists; the human gate on it never closed.

**Cap the window, and say so in the output.** Thirty days is a deliberate bound, not full coverage — an older debt will not appear. Print the window alongside the findings so "no findings" cannot be misread as "nothing is owed" (`pipekit-tooling.md` § no silent caps).

### Phase 3 — Infer the fix per issue

- **Home (for orphans / unclassified).** On the lanes model the default home is **no project**, not a project. Work through this ladder in order and stop at the first hit:

  1. **An existing lane — only if the issue is inside that lane's completable scope.** "It's the same domain" is not scope; the test is whether the lane could still be called *done* with this issue in it. If the body names a parent issue (`follow-up to/from <ID>`, `Source: <ID>`, `Related: <ID>`, `Split from <ID>`, where `<ID>` is any Linear identifier `[A-Z]+-N` — match every prefix, not just the workspace's current one: a prefix migration leaves older bodies citing the old prefix) → `get_issue(parent)` → the **parent's project** is the highest-confidence candidate, but still apply the scope test before proposing it.
  2. **Otherwise: no project + the right `Area:` label.** Keyword-match title/body against the configured Area labels. This is the correct terminal state for uncut work — the issue is homed the moment it carries an Area label, and stays there until a human cuts it into a lane via `/phase-plan --cut`.
  3. If the Area is ambiguous → present the **top-2 candidates** for a human pick in the manifest.

  **Never file into a pool-shaped project, and never create a project.** Filing an issue into a project just to get it out of the orphan list is what grows a pool — the exact drift Phase 2b flags. A project is created only by a deliberate lane cut.

  On a board with no `§ Area Labels` config (not the lanes model), fall back to the pre-v4.28.0 behavior: infer the project from the parent, else keyword-match project names + descriptions (derive candidates dynamically — never hardcode a keyword→project map; that's what keeps it portable), else leave unhomed with top-2 candidates.
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

| Issue | Drift | → Home | → Priority | → State | Title |
|-------|-------|--------|-----------|---------|-------|
| POC-232 | ⬛🔶 | (no project) · Area: Security | Normal | Needs Spec | Compare removed-block… |
| POC-241 | 🔶⚪ | (no project) · Area: Platform | Low | Backlog | Tidy footer spacing… |
| POC-244 | 🏚️ | I3.P2. Access truth — in lane scope | Normal | Needs Spec | Admin scope check… |
| POC-250 | 🅿️ | Backlog + `Parked` label | — | Backlog | Deferred export idea… |
| ...

⚠️ Needs your pick: POC-NNN → [Area: Security | Area: Budget Editor]
```

Then, **only if Phase 2b found anything**, a second block — advisory, not part of the "go":

```
## Board shape — {N} findings (no writes; these are /phase-plan work)

| Project | Finding | Detail | Recommended |
|---------|---------|--------|-------------|
| I3.P4. DB hygiene batch | 🪣 pool smell | 23 open (lane size 3-8) | /phase-plan --cut |
| I2.P3. Export Improvements | 🫗 spent lane | 0 open, state `started` | complete it |
| i5. Produce Ledger | ⚠️ walk-skip | all projects completed, no placeholder | add a placeholder lane |
| I3.P2. Access truth | 📛 status drift | 3 shipped, state `planned` | set `started` |

Say "go" to apply the issue table above, or redirect any line.
```

Then, **only if Phase 2c found anything**, a third block — also advisory, also not part of the "go":

```
## Postmortem debt — {N} findings (window: last 30 days)

| Issue | Finding | Priority | Closed | Recommended |
|-------|---------|----------|--------|-------------|
| PIPER-766 | ✍️ unsigned postmortem | Urgent | 2026-08-25 | reviewer sign-off owed |
| PIPER-741 | 🧾 postmortem debt | High | 2026-08-19 | /pk-bug PIPER-741 |
```

**In `--check` mode, stop here** — print every block (or "✓ board is tidy — no drift") and make no writes.

### Phase 5 — Apply (on `go`, default mode only)

- One `mcp__linear-server__linear_updateIssue` per issue combining `projectId` + `priority` + `stateId`; add the `Area:` label in the same call where one was inferred.
- **Issue the updates serially, not in parallel.** These are writes against a rate-limited API (see `sop/Linear_SOP.md` § Rate limits); a fan-out here is the single easiest way to blow the quota mid-apply and leave the board half-updated.
- Skip any line the user redirected to a manual pick that they didn't resolve.
- **Apply nothing from the board-shape block** — it is advisory output only.
- **Re-assert lane run order after any state change.** A workflow-state change re-ranks the issue's `sortOrder`, so a Triage→`Needs Spec` fix or a Parked-state fix silently moves that issue to the top of its lane's stamped order. If the issue belongs to a lane, restore its `sortOrder` in the same `linear_updateIssue` call and verify the echo. (`sop/Linear_SOP.md` § API gotchas — the silent-data-loss class.)

### Phase 6 — Summary

```
## /linear-hygiene complete

Classified: {N} → Area labels (uncut backlog, correctly project-less)
Homed:      {N} → lanes (in-scope only)
Prioritized: {N} (filled priority 0 / raised per signal)
Un-triaged: {N} (Triage → Needs Spec if Normal+, else Backlog; bundles → Backlog)
Un-parked:  {N} (Parked state → Backlog + label)
Left for your pick: {N} (ambiguous Area)

Board shape: {N} findings for /phase-plan (not applied)
Postmortem debt: {N} closed bugs missing a postmortem or sign-off (last 30d, not applied)
```

Suggest `/brainstorm-review` for items that need a Now/Later/Kill **verdict** — placement ≠ disposition.

## Drifts to Avoid

- **Don't touch `Parked`-labelled issues** — they're already dispositioned "Later."
- **Don't lower an existing priority** — only fill `0` or raise per a signal.
- **Don't guess a project when confidence is low** — surface the top-2 candidates instead.
- **Don't pull full board descriptions into context** — minimal fields board-wide, bodies only for the drift subset (Phase 1/2).
- **Don't write in `--check` mode** — it's read-only by contract (`/pk-exit` depends on this).
- **Don't couple `Area:` labels to lane membership — in either direction.** Area says *what domain this is*; the project says *which batch it's in*. They are orthogonal, and each inference is wrong on its own:
  - **Never remove or change an `Area:` label because of a lane move.** Area classification persists through project membership — an issue cut into a lane keeps the label it was triaged with, and that's what makes the `Area: * — backlog` views honest.
  - **Never infer an `Area:` label from the lane an issue sits in.** A lane can legitimately mix areas.
  *(This rule's predecessor guarded the `Roadmap: *` phase labels, which the lanes model doesn't have. Anchor for why the class of bug matters: SiteLine POC-382 was re-parented into a Phase-A project during a placement pass and silently picked up a stray `Roadmap: Phase A` label that contradicted `ROADMAP.md`. Same shape — placement quietly writing a classification it doesn't own.)*
- **Don't infer or apply a phase-visualization label from a re-homed `projectId`** *(boards on the phase-spans-projects shape — `method.config.md § Phase Label Layer` filled in)*. **Project membership ≠ phase-label membership** — a phase-arc project routinely holds a mix of phase-labeled and non-phase work. Phase-label placement is owned by `/roadmap-review`'s Phase-Label Layer pass, not by this placement janitor.
- **Don't create a project, ever.** Not to home an orphan, not to hold a leftover. Projects are cut deliberately in `/phase-plan`; a project created by a janitor is a pool by construction.
- **Don't act on the board-shape block.** Pool smell, spent lanes, walk-skip hazards and status drift are reported for a human to route to `/phase-plan`. Completing a lane or cutting one is a planning decision with roadmap consequences.

## Deferred to v2 (not in this version)

- 🔗 **Isolated → relation linking** (body references a parent but no `blocked-by`/`relates` relation exists). Uses `mcp__linear-server__linear_createIssueRelation` — **confirmed present** on `@tacticlaunch/mcp-linear` (already called by `/roadmap-create`); deferred only to keep this pass scoped to tool-name correctness.
- 🧹 **Strip stale labels.** Uses `mcp__linear-server__linear_removeIssueLabel` — **confirmed present**; deferred for the same reason.
- **`--session` mode** — limit to issues `createdAt >= session start`, to catch only the current session's follow-ups.

## Related

- `/brainstorm-review` — Now/Later/Kill **disposition** (Triage/Ideas only); this skill is placement across all open states.
- `/roadmap-review` — full-board plan-vs-requirements audit against the Linear-native initiative surface (heavyweight).
- `/pk-exit` — calls `/linear-hygiene --check` to surface drift while context is warm at session close.
