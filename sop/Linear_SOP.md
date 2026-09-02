# Linear Configuration

> For the full development pipeline, see [method.md](../method.md).

**v4.30.0** — Last updated: 2026-08-05  *(**v4.30.0 — the legacy planning layer is gone.** `bin/pk`'s read-only fallback to a committed phase file + ID map (phase context and `PLAN.md` finalize) is removed, along with the vestigial `Backend` config key and its whole chain — `pk-init`'s detector, the `render.sh` substitution, the `/work` refusal, and the `pk doctor` echo. Nothing read `Backend` for behavior, and the fallback needed *both* legacy files to fire — no live consumer had either. `/spec-preflight` loses its permanently-dead `phase-detect` probe (four claim categories, not five) and `/review-plan` loses its phase-slug path. Linear is the only initiative surface.)*

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

> **`getIssueById` is a full-content read — sticky and expensive.** It returns the description **and the entire comment thread**, which then rides every subsequent turn as input tokens (see `.claude/rules/pipekit-tooling.md` § MCP Result Payloads Are Sticky). For an issue's *state / merge / PR* status use `pk issue show <ID>` (a lean field-scoped read — `bin/pk`, v4.19.0+; comments off by default), `pk next` / `pk status`, filtered `linear_searchIssues`, or `git` / `gh` — reserve `getIssueById` for a genuine full-body read, and run batches of many reads/writes in a subagent so the payloads stay out of the main thread.

> **Not the official remote.** Linear's first-party `mcp.linear.app` server uses **snake_case** names (`list_issues`, `get_issue`, `update_issue`, `create_comment`) and a leaner ~21-tool surface that **lacks** the initiative-CRUD, label-create, and issue-relation tools these skills rely on. A project that points `linear-server` at the official remote (or any other Linear MCP) must remap the tool names in its synced skills — they are not drop-in compatible.

> Per `.claude/rules/pipekit-tooling.md`, this server **must** be declared in the committed `.mcp.json` (not the per-path block of `~/.claude.json`) so it's visible inside the `pk branch` worktrees where `/work` and the interactive skills run.

**Note on the daily loop:** `pk ship` / `pk done` / `pk promote` do **not** use MCP — they hit Linear's REST API directly via `LINEAR_API_KEY`. Only the interactive skills above use `mcp__linear-server__*`.

### API gotchas (incident-anchored; read before any batch board mutation)

All verified live during the SiteLine board reorg, 2026-08-02.

**Silent-data-loss class — these accept your write and quietly do something else:**

- **Project / initiative `description` hard-caps at 255 characters.** Longer text is not an error. Put long-form content (lane serialization notes, scope rationale) in the markdown **`content`** body and keep `description` a trimmed summary.
- **A workflow-state change re-ranks the issue's `sortOrder`** — Linear moves it to the top of its new column. Any deliberate run-order stamp is destroyed by ordinary pipeline motion (`pk branch` → In Progress, `pk ship` → UAT are both state changes). Consequences: set `cycleId` **and** `sortOrder` in one `issueUpdate` and verify the echo; re-assert order after any state fix; and treat a stamp as authoritative for **queued issues only** — once an issue is in flight, its position is its state.
- **Adding a Backlog issue to a cycle auto-moves it out of Backlog** (observed landing in `Needs Spec`), which then triggers the re-rank above.
- **Issues in a Triage-type state are invisible in project views and excluded from project scope counts.** An issue "added to a project" while in Triage won't render, and the project reads short. Triage it out first. (Anchor: SiteLine PIPER-559.)
- **View preferences accept unknown keys silently.** `viewPreferencesCreate(input: {type: organization, viewType: project|customView, projectId|customViewId, preferences: {"issueGrouping": "none", "viewOrdering": "manual"}})` does work — keys come from the typed `ViewPreferencesValues` type but values are free-form strings, so a wrong one stores fine and does nothing. Verify by reading back the resolved `CustomView.viewPreferencesValues` oracle; **project-scoped rows have no API read surface** — check one in the browser. Org-scoped rows act as the shared default and personal in-app tweaks overlay them.

**MCP gaps — fall back to GraphQL:**

- **`archiveInitiative` returns "Entity not found"** for a valid initiative. GraphQL `initiativeArchive` succeeds.
- **There is no MCP label-delete tool.** Deletion is GraphQL `issueLabelDelete(id:)` only.
- **`updateProject` to any paused/backlog-type status 500s** on plan-tier workspaces. `started` / `planned` / `completed` are safe.
- Label **groups** create fine via MCP (a parent group plus children works).
- `linear_createSavedView` uses the undocumented internal **`filterData` DSL** — read an existing view first and copy its shape.

**Query complexity:** Linear rejects queries scoring over **10k**. A nested all-projects × all-issues read (~100 × 50) scores ~11k and fails outright. Filter server-side — e.g. the wrong-closure sweep is `projects(filter:{status:{type:{in:["completed","canceled"]}}})` each with `issues(filter:{state:{type:{nin:["completed","canceled"]}}})`, never the unfiltered cross-product.

**Sanity-gate before the first write of any batch mutation:** enumerate the target set, then re-survey fresh and compare counts (tolerance ±5) before mutating. A batch that starts from a stale survey is very hard to unwind.

*(Cosmetic, harmless: Linear auto-links bare `table.column` tokens in `content` markdown.)*

### Rate limits — one shared, per-User quota (incident-anchored)

Linear meters requests **per User**, not per key or per process: its docs state that requests by the same user share quota across different API keys. An API key gets **2,500 req/hr**, an OAuth app 5,000, refilled as a **leaky bucket** at `LIMIT/PERIOD` (~42 req/min on a key). Complexity is metered separately (object 1 pt, property 0.1, a connection multiplies its children by the pagination arg; the 10k single-query cap above), so one large page is one request but not a cheap one.

Why this bites Pipekit specifically: **every Claude session spawns its own `mcp-linear` server, 1:1**, and every session is the same user. Worktree workers, the parent-repo session, and a board sweep all draw from one bucket. Anchor: SiteLine 2026-08-31 — three concurrent `/linear-hygiene` sweeps paging 250 exhausted the quota, blocked the board for ~1h, and starved four active worktree workers.

Rules, for any skill or session that reads or writes the board:

- **Never fan out parallel subagents at `linear-server`.** One subagent, serial calls. Batch writes go one at a time.
- **Page in chunks of ~50**, not 250+.
- **On rate-limit: wait once, retry once, then STOP and report partial.** Retry loops re-arm the MCP server's flat 60s backoff indefinitely — at ~42 req/min refill, 60s buys back ~42 requests, so a big burst resuming on that timer overdraws instantly and never drains.
- **The error is HTTP 400 with a `RATELIMITED` code, not 429** — a 429 check misses it.
- **`isBlocked: false` plus one successful small call is NOT proof the quota recovered.** `linear_getRateLimitStatus` reports only the local cooldown, never remaining quota (Linear's `X-RateLimit-Requests-Remaining` header is not surfaced). It proves "not blocked this instant" only.
- **Run whole-board sweeps when no `/work` sessions are live.** Check with `pgrep -f 'bin/mcp-linear' | wc -l`.

---

## Linear Model

**The Linear hierarchy is the Initiative surface — the source of truth for roadmap order.** There is no committed phase file; `pk next`/`pk status` derive the current initiative live from this hierarchy. `/roadmap-create` authors it; `/phase-plan` advances it.

```
Initiative "i{N}. label" = ordered, COMPLETABLE release phase  <- "Which phase ships this?"
  +-- Project "I{N}.P{N}. label" = a LANE of 3-8 issues    <- "Which completable batch?"
       +-- Issue = work item                              <- "What work needs to happen?"
            +-- Milestone = Work Package (optional)        <- "What intra-project batch?"

Initiative "label" (unprefixed) = long-running THEME        <- allowed never to complete
Issue with no project           = uncut BACKLOG             <- classified by an Area: label

Labels = Cross-cutting metadata        <- Filterable on everything
  Area:     [domain classification for uncut backlog work]
  Domain:   [project-specific domain labels]
  Tier:     [stage-numbered tier labels]
  Type:     Feature, Bug, Improvement, Research, Tech Debt, Chore
  Flag:     Quick Win, Blocked, Hotfix, Breaking Change
  Audience: Client Request
```

**Completability is the load-bearing property, and it lives at the project level.** A project holding 60 open issues is a *pool*, and the `i{N}.`→`P{N}.` walk structurally cannot see into a pool — so `pk status` points at some idle lane while the live work hides. Eternity belongs at the theme/label level: a long-running strand is an unprefixed initiative or an `Area:` label, never a standing project. A project is created only for work that has been **cut** into a lane. (Anchor: SiteLine, 2026-08-02 — 98 of 162 open issues sat in three pool projects, `In Progress` read 0, and the real execution order had migrated into a gitignored notes file. Full reorg rationale in `method.config.md § Initiative Surface`.)

### Ordering is the numeric name prefix — never Linear `sortOrder`

Initiative and sub-phase order is read from the **integer in the name prefix**, parsed numerically (so `P2` sorts before `P10`). Linear's internal `sortOrder` field is an unreliable drag-rank and is **never** used to order initiatives.

- **Initiative `i{N}. label`** = an ordered roadmap **initiative**. The `i{N}.` prefix is the roadmap opt-in: only prefixed initiatives are delivery initiatives. **Unprefixed initiatives are strategic themes** and are ignored by `pk next`.
- **Project `I{N}.P{N}. label`** = an ordered **sub-phase** within an initiative. Issues live in projects. The project carries its initiative number (v4.5.0+: `I1.P2. label`) so the initiative reads at the project level — the navigable unit in Linear. `bin/pk` accepts both `I{N}.P{N}.` and legacy bare `P{N}.`; the `P{N}` number sets order either way.
- **Issue** = a work item.

**Current initiative** = the lowest `i{N}` initiative whose status is not `Completed`. **Current sub-phase** = the lowest `P{N}` project whose state is not `completed` or `canceled`.

### Board shapes

Two shapes are supported. The `i{N}.`/`I{N}.P{N}.` naming contract is **identical** in both; they differ only in what a *phase* maps to. A project picks one — its `method.config.md` records which.

| Shape | Phase ≡ | Ordering lives in | Use when |
|---|---|---|---|
| Lanes **(default)** | one initiative, 1:1 | the `i{N}.`/`P{N}.` prefixes + `blockedBy` relations | Almost always. `/roadmap-create` authors this. |
| Phase-spans-projects | several projects | the prefixes **plus** the opt-in phase-label layer | A phase genuinely spans multiple projects, so no single project *is* a phase. |

**Never run both.** Two ordering mirrors of the same work drift independently — that is the failure the lanes model exists to remove, and it is why a lanes-model board must not adopt the phase-label layer.

How a skill tells them apart: the project's `method.config.md` has a filled-in `§ Area Labels` section (lanes) or a filled-in `§ Phase Label Layer` table (phase-spans-projects). Neither → treat as lanes and no-op the shape-specific checks.

**Retiring the phase-label layer** (moving an opted-in board to lanes) is order-sensitive:

1. **Comment out the `### Phase Label Layer` config table first.** `/roadmap-review` Phase 3.5 gates on the filled-in values, so while they are live it re-scaffolds whatever you delete next.
2. Then delete the `Roadmap: *` / `Order: *` labels and their saved views.
3. **Keep the `Roadmap source` key live** — Phase 2.5's checkbox↔`Done` reconciliation reads it independently of the layer, so it belongs *outside* the commented block.
4. Real `blockedBy` relations stay; on the lanes model they carry all intra-lane ordering.

### Each Layer's Job

| Layer | Audience | Question | Lifespan |
|---|---|---|---|
| **Initiative** (`i{N}.`) | Partner | "Which release phase?" | **Completable** — closes when its last lane does |
| **Initiative** (unprefixed) | Partner | "Which long-running theme?" | Eternal by design; outside the walk |
| **Project** (`I{N}.P{N}.`) | Partner + You | "Which lane?" | **Completable** — 3–8 issues, then done |
| **Milestone** (optional) | You | "What intra-project batch?" | Per-project |
| **Issue** | You | "What work item?" | Permanent (work item) |
| **Labels** | Everyone | Area? Domain? Tier? Type? | Permanent (taxonomy) |

Read the two *completable* rows as the rule: if a layer can never finish, it's the wrong layer for that content.

The **Milestone = Work Package** layer is an optional intra-project grouping, orthogonal to the Initiative surface — use it to batch issues within a single project when useful, or skip it entirely.

---

## Initiative Surface Mapping

The roadmap's initiative order lives in the **Linear hierarchy** (Initiative `i{N}.` / Project `P{N}.`), not in a committed file. There is no phase-file mirror and no committed ID map.

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

### Area (a label *group*; project-named — the lanes model's backlog axis)

On the lanes model, uncut work carries **no project**, so `Area:` is the one axis that keeps it navigable. Configure the group and its children in `method.config.md § Initiative Surface → Area Labels`; the names below are illustrative, not a contract.

| Label | Purpose |
|---|---|
| `Area: <domain>` | What domain this issue belongs to, independent of which batch it's in |

- **Area and lane membership are orthogonal, and inference in *either* direction is a bug.** An issue keeps its Area label when it's cut into a lane (that's what keeps the `Area: * — backlog` views honest), and a lane may legitimately mix areas — so never derive one from the other. `/linear-hygiene` applies Area labels; it must never rewrite one because a project changed.
- One `Area: * — backlog` saved view per label renders the uncut work per domain.
- **`Parked` is a label, not a workflow state.** A Parked *state* hides work from every state-based query, including the hygiene sweep's own fetch. Park by moving to `Backlog` and applying the label.

### Tier (3 labels)

Tier shapes *which gates apply* to an issue. `/work` and `/verify` infer the tier from these labels but **always confirm with the human** before proceeding — automatic escalation/de-escalation is disallowed by design.

| Label | Purpose |
|---|---|
| `tier:quick` | 1–3 stories, single PR, AC fits in head. Skips spec review, plan review, and evidence-gated verify. |
| `tier:standard` | Default. Normal feature work, full gate stack. |
| `tier:heavy` | Multi-phase, security-sensitive, or cross-strategy-doc. Adds security review + mandatory `/strategy-sync` before close. **`/pk-express` refuses `tier:heavy`** — heavy work needs the full planning + antagonistic gates. |

Per-project tier configuration lives in `method.config.md` § Tiers (a tier can be disabled by removing its row; Standard is the non-removable fallback).

Domain labels are project-specific — define them in your Linear workspace to match your product areas.

### Roadmap (optional — the phase-label layer)

Projects that opt into the **phase-label layer** (`method.config.md § Phase Label Layer`, v4.14.0) carry two more label families that mirror `ROADMAP.md`'s build order onto the board — for roadmaps whose phases span multiple `I{N}.P{N}.` projects, so no single project *is* a phase. **Optional and project-named** — read the exact names from config; the values below are illustrative.

| Label | Purpose |
|---|---|
| `Roadmap: Phase A` / `B` / `C` … | The sequenced roadmap phase an issue belongs to. A *label* (not a project) carries phase membership because phases cross project boundaries. One per issue; `sortOrder` mirrors the roadmap's top-to-bottom order within the phase. |
| `Roadmap: Continuous` | The standing pool — items the roadmap names but doesn't sequence. **Named-items-only**, never bulk-applied to a whole project. |
| `Order: Any` | The issue has no intra-phase dependency — safe to run anytime / in parallel. Sequential order uses real `blockedBy` relations, never this label. |

`/roadmap-review` Phase 3.5 owns these — it scaffolds/bootstraps them onto the board and drift-checks them against `ROADMAP.md`. **`/linear-hygiene` must never infer or apply them** from a re-homed `projectId` (project membership ≠ phase-label membership). Full convention: `method.config.md § Phase Label Layer`.

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

See `method.config.template.md` for the template.
