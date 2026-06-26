# Linear Configuration

> For the full development pipeline, see [method.md](../method.md).

**v4.5.0** — Last updated: 2026-06-22  *(Initiative surface — projects carry their initiative number: Project `I{N}.P{N}.` = sub-phase (e.g. `I1.P2. label`), so the initiative reads at the project level (the navigable unit in Linear); `bin/pk` accepts both `I{N}.P{N}.` and legacy bare `P{N}.`. Carries v4.1.0's Linear-native Initiative surface — Initiative `i{N}.` = initiative, ordered by name prefix. The roadmap's initiative order lives in Linear, not a committed file; `pk next`/`pk status` derive the current initiative live. The legacy `.vbw-planning/PHASES.md` and `linear-map.json` are retired (`bin/pk` reads them only as a read-only fallback for un-migrated projects). Carries the **Linear MCP Server** section — pipekit's interactive Linear skills target `@tacticlaunch/mcp-linear`'s camelCase tools; the `tier:quick`/`tier:standard`/`tier:heavy` labels — including `/pk-express`'s tier:heavy refusal — the config-driven `Spec ready state`, and v2.6.0's two-phase `pk promote` + Draft-by-default model)*

Project-specific values (workspace, team ID, state IDs) live in your project's `method.config.md`.

---

## Linear MCP Server

Pipekit's interactive Linear skills (`/linear`, `/sync-linear`, `/roadmap-create`, `/linear-hygiene`, `/light-spec`, `/brainstorm`, …) talk to Linear through an **MCP server registered as `linear-server`** in the project's version-controlled `.mcp.json`. The skills call tool names of the form `mcp__linear-server__<tool>`.

**The skills assume `@tacticlaunch/mcp-linear`** — the server both reference consuming projects (SiteLine, Piper) run. Its tools are **camelCase** with a `linear_` prefix:

| Purpose | Tool |
|---|---|
| List / filter issues | `linear_searchIssues` (filtered) · `linear_getIssues` (recent, connectivity test) |
| Read one issue | `linear_getIssueById` |
| Create / update issue | `linear_createIssue` · `linear_updateIssue` (one call carries `projectId` + `priority` + `stateId`) |
| Comment | `linear_createComment` · `linear_getComments` |
| Projects | `linear_getProjects` · `linear_getProjectById` · `linear_createProject` · `linear_updateProject` |
| Initiatives | `linear_getInitiatives` · `linear_getInitiativeById` · `linear_createInitiative` · `linear_updateInitiative` |
| Workflow states | `linear_getWorkflowStates` |
| Labels | `linear_createTeamLabel` · `linear_addIssueLabel` · `linear_removeIssueLabel` |
| Relations | `linear_createIssueRelation` |

> **Not the official remote.** Linear's first-party `mcp.linear.app` server uses **snake_case** names (`list_issues`, `get_issue`, `update_issue`, `create_comment`) and a leaner ~21-tool surface that **lacks** the initiative-CRUD, label-create, and issue-relation tools these skills rely on. A project that points `linear-server` at the official remote (or any other Linear MCP) must remap the tool names in its synced skills — they are not drop-in compatible.

> Per `.claude/rules/pipekit-tooling.md`, this server **must** be declared in the committed `.mcp.json` (not the per-path block of `~/.claude.json`) so it's visible inside the `pk branch` worktrees where `/work` and the interactive skills run.

**Note on the daily loop:** `pk ship` / `pk done` / `pk promote` do **not** use MCP — they hit Linear's REST API directly via `LINEAR_API_KEY`. Only the interactive skills above use `mcp__linear-server__*`.

---

## Linear Model

**The Linear hierarchy is the Initiative surface — the source of truth for roadmap order.** There is no committed phase file; `pk next`/`pk status` derive the current initiative live from this hierarchy. `/roadmap-create` authors it; `/phase-plan` advances it.

```
Initiative "i{N}. label" = ordered roadmap INITIATIVE       <- "Which initiative ships this?"
  +-- Project "I{N}.P{N}. label" = ordered SUB-PHASE   <- "Which sub-phase within the phase?"
       +-- Issue = work item                           <- "What work needs to happen?"
            +-- Milestone = Work Package (optional)     <- "What intra-project batch?"

Labels = Cross-cutting metadata        <- Filterable on everything
  Domain:   [project-specific domain labels]
  Tier:     [stage-numbered tier labels]
  Type:     Feature, Bug, Improvement, Research, Tech Debt, Chore
  Flag:     Quick Win, Blocked, Hotfix, Breaking Change
  Audience: Client Request
```

### Ordering is the numeric name prefix — never Linear `sortOrder`

Initiative and sub-phase order is read from the **integer in the name prefix**, parsed numerically (so `P2` sorts before `P10`). Linear's internal `sortOrder` field is an unreliable drag-rank and is **never** used to order initiatives.

- **Initiative `i{N}. label`** = an ordered roadmap **initiative**. The `i{N}.` prefix is the roadmap opt-in: only prefixed initiatives are delivery initiatives. **Unprefixed initiatives are strategic themes** and are ignored by `pk next`.
- **Project `I{N}.P{N}. label`** = an ordered **sub-phase** within an initiative. Issues live in projects. The project carries its initiative number (v4.5.0+: `I1.P2. label`) so the initiative reads at the project level — the navigable unit in Linear. `bin/pk` accepts both `I{N}.P{N}.` and legacy bare `P{N}.`; the `P{N}` number sets order either way.
- **Issue** = a work item.

**Current initiative** = the lowest `i{N}` initiative whose status is not `Completed`. **Current sub-phase** = the lowest `P{N}` project whose state is not `completed` or `canceled`.

### Each Layer's Job

| Layer | Audience | Question | Lifespan |
|---|---|---|---|
| **Initiative** (`i{N}.`) | Partner | "Which roadmap initiative?" | Permanent (one per initiative) |
| **Project** (`I{N}.P{N}.`) | Partner + You | "Which sub-phase?" | Permanent within phase |
| **Milestone** (optional) | You | "What intra-project batch?" | Per-project |
| **Issue** | You | "What work item?" | Permanent (work item) |
| **Labels** | Everyone | Domain? Tier? Type? | Permanent (taxonomy) |

The **Milestone = Work Package** layer is an optional intra-project grouping, orthogonal to the Initiative surface — use it to batch issues within a single project when useful, or skip it entirely.

---

## Initiative Surface Mapping

The roadmap's initiative order lives in the **Linear hierarchy** (Initiative `i{N}.` / Project `P{N}.`), not in a committed file. The legacy initiative-source files `.vbw-planning/PHASES.md` and `.vbw-planning/linear-map.json` are **retired** — no skill writes them; `bin/pk` reads them only as a read-only fallback for un-migrated projects.

| Concept | Linear | Notes |
|---|---|---|
| Roadmap initiative | Initiative `i{N}. label` | Ordered by the `i{N}` name prefix. The source of truth for initiative order. |
| Sub-phase | Project `I{N}.P{N}. label` | Ordered by the `P{N}` name prefix, within an initiative. Issues live here. (Legacy bare `P{N}.` still parses.) |
| Work Package (optional) | Milestone | Optional intra-project batch within a project. |
| Issue | Issue | The work item. |

**The Linear hierarchy is the source of truth for initiative order.** Task decomposition lives in the execution plan (`.pk-work/<ID>-PLAN.md`), authored and run by `/work` on the native-on-Workflow executor; Linear stays clean — one issue per feature.

### What Lives Where

| Content | Home | Never In |
|---------|------|----------|
| Feature specs, AC, scope | Linear issue description | The execution plan |
| Task decomposition | `.pk-work/<ID>-PLAN.md` | Linear |
| Execution status | Linear (the source of truth) | -- |
| Code | Git | Linear |

**Never create Linear projects or issues for individual plan tasks.** Features are the unit Linear tracks; task decomposition stays in the execution plan.

---

## Workflow States

### Pipeline

```
Planned:   Triage -> Ideas -> Future Initiatives -> On Deck -> Needs Spec -> Specced -> Approved -> Building -> UAT -> In <FirstEnv> -> [In <Env> ->]* Done
Ad-hoc:    Triage -> In Progress -> UAT -> In <FirstEnv> -> [In <Env> ->]* Done                                                                -> Canceled
                                                                                                                                                -> Duplicate
```

**State / environment mapping** (v2.5.0): one state per env in `Ship environments`. For 3-tier (`dev,beta,main`): `UAT` (PR open on preview) → `In Dev` (merged to dev) → `In Beta` (promoted to beta) → `Done` (promoted to main). For 2-tier (`dev,main`): `UAT` → `In Dev` → `Done`. For 1-tier (`main`): `UAT` → `Done` (no intermediate state). The status name itself tells you which env the code currently lives on. `Released` from v2.3.0–v2.4.x is retired — replaced by env-specific `In <Env>` states.

### Principle

**Statuses track WHERE in the pipeline. Labels track WHAT, WHICH, and FLAGS.**

Every status maps to a pipeline position. An issue's status tells you whose turn it is and what happens next. Labels provide metadata (domain, type, tier, flags) that is orthogonal to pipeline position.

### Status Definitions

| Status | Type | Whose Turn | Pipeline Step | Purpose |
|---|---|---|---|---|
| **Triage** | triage (setting) | You | Pre-pipeline | External input: bug reports, client requests, `/brainstorm` output. Sort into the right place. Enable via Settings → Team → General, not created as a workflow state. |
| **Ideas** | backlog | -- | Pre-pipeline | Triaged items to act on at some point, but not now. Parking lot for evaluated ideas. |
| **Future Initiatives** | backlog | -- | Pre-pipeline | Belongs to a known future stage. Not in scope for current or next initiative. |
| **On Deck** | backlog | Scanning | Pre-pipeline | Next initiative's batch. Start getting eyes on these, light-spec proactively if you get ahead. |
| **Needs Spec** | backlog | You + Claude | Step 1 ready | Current initiative. Needs `/light-spec` applied. |
| **Specced** | unstarted | You | Steps 2-3 | Light spec applied, agent reviewed. Awaiting your sign-off. **Config-driven (v2.7.0+):** this is the default `Spec ready state`, but the state `/light-spec` publishes to and `pk spec-cycle` requires is whatever `method.config.md` § `Spec ready state` names. Two-state boards with no `Specced` state set it to `Needs Spec`. |
| **Approved** | unstarted | `/work` (queued) | Post Step 3 | Human approved. Ready for execution when an initiative batch is complete. |
| **In Progress** | started | You | Ad-hoc | Manual work outside the initiative: hotfixes, quick bug fixes, chores. Not initiative-managed. |
| **Building** | started | `/work` | Steps 4-7 | Plan + native `/work` execution + `/verify` QA. Current-initiative execution queue only. |
| **UAT** | started | You | Step 8a | PR open on preview branch (pre-merge — v2.6.0+ opens as Draft; `pk ready` flips to Ready to fire outside reviewers). Code review + preview-URL acceptance testing happens here. **v2.4.3+**: `pk promote` (Phase 1) refuses if any bundled issue is still in UAT (PR not merged) — pass `--confirmed` to bypass after env-UAT signoff. |
| **In `<FirstEnv>`** (e.g. `In Dev`) | started | You | Step 8b | Code merged to first deploy env. Interactive UAT in progress, or signed-off-awaiting-promote. Set by `pk done` after merge confirmation. |
| **In `<Env>`** (e.g. `In Beta`) | started | You | Step 8c+ | Code promoted to a non-final env. One state per non-final env in `Ship environments`. **v2.6.0+**: set by `pk promote <env> --finish` (Phase 2, after the promote PR merges) — replaces the pre-v2.6.0 optimistic-at-PR-open transition. |
| **Done** | completed | -- | Step 9 | Code promoted to the final env in `Ship environments` (`main` / `production` / etc.). Live. |
| **Canceled** | canceled | -- | -- | Won't do. |
| **Duplicate** | canceled | -- | -- | Merged into another issue. |

### Key Transitions

| From | To | Trigger | Who |
|---|---|---|---|
| Triage | Ideas / Needs Spec / In Progress | You triage it | You |
| Ideas | Future Initiatives / On Deck | Stage/initiative assignment | You |
| Future Initiatives | On Deck | Promoted for next initiative | You |
| On Deck | Needs Spec | Current initiative begins | You |
| Needs Spec | Specced | `/light-spec` applied + agent reviewed | Claude + You |
| Specced | Needs Spec | Agent or human sends back for revision | You |
| Specced | Approved | You approve scope, decisions, priority | You |
| Approved | Building | Initiative batch is ready for execution | You (or `/work` pickup) |
| Building | UAT | `/verify` QA passes + `pk ship` | `/verify` QA + you |
| UAT | In `<FirstEnv>` | `pk done` after PR merge (or `pk done --merge`) | You + `pk done` |
| UAT | Done | `pk done` on 1-tier project (first env IS final env) | You + `pk done` |
| In `<Env>` | In `<NextEnv>` | `pk promote <NextEnv>` opens PR (no state change); `pk promote <NextEnv> --finish` after merge transitions (v2.6.0+) | You + `pk promote` |
| In `<Env>` | Done | `pk promote <FinalEnv>` opens PR; `pk promote <FinalEnv> --finish` after merge transitions (final hop) | You + `pk promote` |
| UAT | Building | You reject — needs rework | You |
| Triage | In Progress | Hotfix or quick fix — you're handling it manually | You |
| In Progress | UAT | Manual fix ready for acceptance testing | You |
| In Progress | Done | Quick fix, no UAT needed | You |

### Fast-Track Paths

| Lane | Path | Managed By |
|---|---|---|
| **Planned (features)** | Ideas → Future Initiatives → On Deck → Needs Spec → Specced → Approved → Building → UAT → In `<FirstEnv>` → [In `<Env>` →]* Done | Initiative pipeline (`/work`) |
| **Bug fix (into initiative)** | Triage → Needs Spec → Specced → Approved → Building → UAT → In `<FirstEnv>` → [In `<Env>` →]* Done | Initiative pipeline (enters the initiative) |
| **Hotfix** | Triage → In Progress → UAT → In `<FirstEnv>` → [In `<Env>` →]* Done | You (manual fix) |
| **Quick fix** | Triage → In Progress → Done | You (no UAT needed) |

`[In <Env> →]*` is one state per non-final env in `Ship environments`. 3-tier (`dev,beta,main`): `In Dev → In Beta → Done`. 2-tier (`dev,main`): `In Dev → Done`. 1-tier (`main`): `UAT → Done` (no intermediate `In <Env>`).

**Building** = initiative-managed (`/work` plans and executes the batch). Initiative-batched, trigger rules apply. Never put ad-hoc work here.
**In Progress** = You're doing it by hand, outside the initiative. The initiative pipeline ignores these.

### Initiative Management

**Which initiative an issue belongs to is defined by the Linear hierarchy** — the `i{N}.` initiative (initiative) and `P{N}.` project (sub-phase) it sits under, ordered by name prefix. `pk next`/`pk status` resolve the current initiative live from that hierarchy (lowest non-`Completed` `i{N}` initiative). `/roadmap-create` authors the hierarchy; `/phase-plan` advances it. The workflow states below track *pipeline position within* the current initiative, not initiative membership.

Within the active initiative, the backlog is ordered by **pipeline proximity** (furthest out → closest to execution):

```
Ideas → Future Initiatives → On Deck → Needs Spec
```

- **In-flight (current initiative)** = issues in Needs Spec + Specced + Approved + Building + UAT + any In `<Env>` state
- **Queued (next initiative)** = issues in On Deck
- **Future** = issues in Future Initiatives
- **Someday** = issues in Ideas

When the current initiative ships, promote On Deck → Needs Spec and refill On Deck from Future Initiatives.

---

## Conventions

- **No sub-issues in Linear.** Task decomposition lives in the execution plan (`.pk-work/<ID>-PLAN.md`) only. Linear stays clean — one Issue per feature.
- **Projects (`I{N}.P{N}.`) don't overlap.** Each issue lives in exactly one sub-phase project at a time.
- **Milestones = Work Packages (optional).** When used, a milestone is an intra-project batch; an issue belongs to at most one. Orthogonal to the Initiative surface — skip it entirely when not useful.
- **Tier labels are redundant with initiatives** — intentional. Labels persist after initiatives complete.
- **Urgent priority is reserved** for hotfixes and production emergencies only.
- **Execution trigger:** initiative execution triggers when a batch of related features in a Work Package reach "Building" — not when individual features are approved.

### Ticket ID Convention

Issue IDs (e.g., `{PREFIX}-XXX`) are carried through the work plan and commit messages:

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

### Tier (3 labels)

Tier shapes *which gates apply* to an issue. `/work` and `/verify` infer the tier from these labels but **always confirm with the human** before proceeding — automatic escalation/de-escalation is disallowed by design.

| Label | Purpose |
|---|---|
| `tier:quick` | 1–3 stories, single PR, AC fits in head. Skips spec review, plan review, and evidence-gated verify. |
| `tier:standard` | Default. Normal feature work, full gate stack. |
| `tier:heavy` | Multi-phase, security-sensitive, or cross-strategy-doc. Adds security review + mandatory `/strategy-sync` before close. **`/pk-express` refuses `tier:heavy`** — heavy work needs the full planning + antagonistic gates. |

Per-project tier configuration lives in `method.config.md` § Tiers (a tier can be disabled by removing its row; Standard is the non-removable fallback).

Domain labels are project-specific — define them in your Linear workspace to match your product areas.

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

The **Linear hierarchy itself is the source of truth** for the roadmap's initiative order (Initiative `i{N}.` / Project `P{N}.`, ordered by name prefix) — there is no committed phase file to keep in sync. Skills resolve initiatives and projects live by their name prefixes.

Linear IDs that skills consume directly:
1. `method.config.md` — team ID and state IDs for skill consumption (see the § Initiative Surface contract).

The legacy `.vbw-planning/linear-map.json` is **retired**: no skill writes it, and it is no longer the ID map. `bin/pk` reads it only as a read-only fallback for un-migrated projects.

See `method.config.template.md` for the template.
