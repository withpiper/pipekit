# Linear Configuration

> For the full development pipeline, see [method.md](../method.md).

**v2.4.3.2** — Last updated: 2026-05-14  *(doc-polish release — UAT row + transitions reference `--confirmed`, 2-tier Released clarification)*

Project-specific values (workspace, team ID, state IDs) live in your project's `method.config.md`.

---

## Linear Model

```
Initiative = VBW Phase                 <- "What phase does this ship in?"
  +-- Project = Feature Cluster        <- "What area of the product?"
       +-- Issue = Feature/Task        <- "What work needs to happen?"
            +-- Milestone = Work Package  <- "What execution batch?"

Labels = Cross-cutting metadata        <- Filterable on everything
  Domain:   [project-specific domain labels]
  Tier:     [stage-numbered tier labels]
  Type:     Feature, Bug, Improvement, Research, Tech Debt, Chore
  Flag:     Quick Win, Blocked, Hotfix, Breaking Change
  Audience: Client Request
```

### Each Layer's Job

| Layer | Audience | Question | Lifespan |
|---|---|---|---|
| **Initiative** | Partner | "What stage?" | Permanent (one per stage) |
| **Project** | Partner + You | "What feature area?" | Permanent within stage |
| **Milestone** | You + VBW | "What execution batch?" | Per-stage |
| **Issue** | You + VBW | "What feature/task?" | Permanent (work item) |
| **Labels** | Everyone | Domain? Tier? Type? | Permanent (taxonomy) |

---

## VBW <> Linear Mapping

| VBW | Linear | Notes |
|---|---|---|
| Phase | Initiative | 1:1 match |
| Feature cluster | Project | Grouped by product area |
| Work Package | Milestone | Execution batches within projects |
| Plan (phase) | -- | VBW internal only. `.vbw-planning/` |
| Task | -- | VBW internal only. `.vbw-planning/` |
| Issue (ISSUES.md) | Issue | Issue IDs shared across both systems |

**VBW is the planning engine. Linear is the view layer.** VBW pushes structure and tasks to Linear; human edits in Linear; VBW pulls changes back. The `/sync-linear` skill handles both directions.

### What Lives Where

| Content | Home | Never In |
|---------|------|----------|
| Feature specs, AC, scope | Linear issue description | VBW plans |
| Task decomposition | `.vbw-planning/` PLAN files | Linear |
| Execution status | Both (synced via `/sync-linear`) | -- |
| Code | Git | Linear or VBW |

**Never create Linear projects for VBW plans. Never create Linear issues for VBW tasks.** Features are the bridge between Linear and VBW.

---

## Workflow States

### Pipeline

```
Planned:   Triage -> Ideas -> Future Phases -> On Deck -> Needs Spec -> Specced -> Approved -> Building -> UAT -> Released -> Done
Ad-hoc:    Triage -> In Progress -> UAT -> Released -> Done                                                                -> Canceled
                                                                                                                            -> Duplicate
```

**Released** is meaningful only on 3-tier projects (`Ship environments: dev,beta,main`). On 2-tier projects (`Ship environments: dev,main`), state goes UAT → Done directly via the single `pk promote main` hop, and Released is unused — there's no need to configure a Released state ID in `method.config.md` for 2-tier projects.

### Principle

**Statuses track WHERE in the pipeline. Labels track WHAT, WHICH, and FLAGS.**

Every status maps to a pipeline position. An issue's status tells you whose turn it is and what happens next. Labels provide metadata (domain, type, tier, flags) that is orthogonal to pipeline position.

### Status Definitions

| Status | Type | Whose Turn | Pipeline Step | Purpose |
|---|---|---|---|---|
| **Triage** | triage (setting) | You | Pre-pipeline | External input: bug reports, client requests, `/brainstorm` output. Sort into the right place. Enable via Settings → Team → General, not created as a workflow state. |
| **Ideas** | backlog | -- | Pre-pipeline | Triaged items to act on at some point, but not now. Parking lot for evaluated ideas. |
| **Future Phases** | backlog | -- | Pre-pipeline | Belongs to a known future stage. Not in scope for current or next phase. |
| **On Deck** | backlog | Scanning | Pre-pipeline | Next phase's batch. Start getting eyes on these, light-spec proactively if you get ahead. |
| **Needs Spec** | backlog | You + Claude | Step 1 ready | Current phase. Needs `/light-spec` applied. |
| **Specced** | unstarted | You | Steps 2-3 | Light spec applied, agent reviewed. Awaiting your sign-off. |
| **Approved** | unstarted | VBW (queued) | Post Step 3 | Human approved. Ready for VBW when a phase batch is complete. |
| **In Progress** | started | You | Ad-hoc | Manual work outside the phase: hotfixes, quick bug fixes, chores. Not VBW-managed. |
| **Building** | started | VBW | Steps 4-7 | VBW planning + execution + QA. Current-phase execution queue only. |
| **UAT** | started | You | Step 8 | Code merged to integration env (`dev`). Your turn to accept or reject. **v2.4.3+**: `pk done` and `pk promote` exit 1 while an issue is in this state — pass `--confirmed` once UAT is signed off to bypass. |
| **Released** | started | You | Step 8.5 | Code merged to staging env (`beta`). Pre-prod validation. 3-tier projects only. |
| **Done** | completed | -- | Step 9 | Code merged to production env (`main`). Live. |
| **Canceled** | canceled | -- | -- | Won't do. |
| **Duplicate** | canceled | -- | -- | Merged into another issue. |

### Key Transitions

| From | To | Trigger | Who |
|---|---|---|---|
| Triage | Ideas / Needs Spec / In Progress | You triage it | You |
| Ideas | Future Phases / On Deck | Stage/phase assignment | You |
| Future Phases | On Deck | Promoted for next phase | You |
| On Deck | Needs Spec | Current phase begins | You |
| Needs Spec | Specced | `/light-spec` applied + agent reviewed | Claude + You |
| Specced | Needs Spec | Agent or human sends back for revision | You |
| Specced | Approved | You approve scope, decisions, priority | You |
| Approved | Building | Phase batch is ready for execution | You (or VBW pickup) |
| Building | UAT | VBW QA passes | VBW QA agent |
| UAT | Released | `pk promote beta --confirmed` (3-tier projects, after UAT sign-off) | You + `pk promote` |
| UAT | Done | `pk promote main --confirmed` (2-tier projects, single hop after UAT sign-off) | You + `pk promote` |
| Released | Done | `pk promote main` (3-tier projects; no `--confirmed` needed past UAT) | You + `pk promote` |
| UAT | Building | You reject — needs rework | You |
| Triage | In Progress | Hotfix or quick fix — you're handling it manually | You |
| In Progress | UAT | Manual fix ready for acceptance testing | You |
| In Progress | Done | Quick fix, no UAT needed | You |

### Fast-Track Paths

| Lane | Path | Managed By |
|---|---|---|
| **Planned (features)** | Ideas → Future Phases → On Deck → Needs Spec → Specced → Approved → Building → UAT → [Released →] Done | VBW |
| **Bug fix (into phase)** | Triage → Needs Spec → Specced → Approved → Building → UAT → [Released →] Done | VBW (enters the phase) |
| **Hotfix** | Triage → In Progress → UAT → [Released →] Done | You (manual fix) |
| **Quick fix** | Triage → In Progress → Done | You (no UAT needed) |

`[Released →]` is only present on 3-tier projects.

**Building** = VBW owns it. Phase-batched, trigger rules apply. Never put ad-hoc work here.
**In Progress** = You're doing it by hand, outside the phase. VBW ignores these.

### Phase Management

The backlog is ordered by **phase proximity** (furthest out → closest to execution):

```
Ideas → Future Phases → On Deck → Needs Spec
```

- **Current phase** = issues in Needs Spec + Specced + Approved + Building + UAT
- **Next phase** = issues in On Deck
- **Future** = issues in Future Phases
- **Someday** = issues in Ideas

When the current phase ships, promote On Deck → Needs Spec and refill On Deck from Future Phases.

---

## Conventions

- **No sub-issues in Linear.** Task decomposition lives in `.vbw-planning/` only. Linear stays clean — one Issue per feature.
- **Projects don't overlap.** Each issue lives in exactly one project at a time.
- **Milestones = Work Packages.** Each issue belongs to one milestone (its WP).
- **Tier labels are redundant with Initiatives** — intentional. Labels persist after stages complete.
- **Urgent priority is reserved** for hotfixes and production emergencies only.
- **VBW trigger:** VBW planning triggers when a batch of related features in a Work Package reach "Building" — not when individual features are approved.

### Ticket ID Convention

Issue IDs (e.g., `{PREFIX}-XXX`) are carried through both VBW config and commit messages:

```
feat(grid): add column definitions ({PREFIX}-42)
fix(auth): resolve session timeout ({PREFIX}-10)
```

The issue prefix is defined in your project's `method.config.md`.

---

## Standard Labels

### Type (6 labels)

| Label | Purpose |
|---|---|
| Feature | New capability |
| Improvement | Enhancement to existing feature |
| Bug | Something broken |
| Research | Investigation or evaluation needed |
| Tech Debt | Refactoring, cleanup — works but should be better |
| Chore | Infrastructure tasks: CI, tooling, config |

### Flag (4 labels)

| Label | Purpose |
|---|---|
| Quick Win | Doable in a single session |
| Blocked | Waiting on external dependency |
| Hotfix | Production emergency — fast-tracked through pipeline |
| Breaking Change | Requires migration or affects existing users |

### Audience (1 label)

| Label | Purpose |
|---|---|
| Client Request | Client/prospect asked for this |

Domain and Tier labels are project-specific — define them in your Linear workspace to match your product areas and stage structure.

---

## Issue Templates

### Brainstorm Template
For raw ideas captured via `/brainstorm`. Lands in **Triage** state.

```markdown
## Idea
What's the idea? Describe it in 1-2 sentences.

## Problem
What problem does this solve? Who has this problem?

## Rough Scope
- What would this look like if we built it?
- What's the smallest useful version?

## Questions
- What do we need to figure out before this can move forward?
- Any dependencies or blockers?

## Notes
Anything else — inspiration links, screenshots, competitor examples, etc.
```

### Development Template
For triaged issues ready for development.

```markdown
## Overview
What is this feature/fix and why does it matter?

## Scope
- [ ] Specific deliverable 1
- [ ] Specific deliverable 2
- [ ] Specific deliverable 3

## Dependencies
- What must exist before this can be built?
- Related issues: {PREFIX}-XX

## Technical Notes
Key implementation details, architecture decisions, or constraints.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Test Plan
- How should this be tested?
- Edge cases to cover?
```

---

## Key IDs

All Linear IDs (team, states, initiatives, projects) should be stored in:
1. `method.config.md` — state IDs for skill consumption
2. `.vbw-planning/linear-map.json` — full ID mapping for VBW ↔ Linear sync

See `method.config.template.md` for the template.
