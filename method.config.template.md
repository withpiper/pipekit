# Method Configuration

**v4.31.0** — Last updated: 2026-08-07  *(**v4.31.0 — five keys for `/repo-security-review`** (renamed from `/security-review`, genericized this release). `Repo security areas` points at the project audit-area file — the substance the skill used to hardcode; `Repo security report path` sets where the periodic report lands. The three artifact keys — `Security architecture doc`, `Public security page`, `Security scan host` — are **optional by design**: blank means the step reports `n/a`, never that it passed, and the skill never invents a path the project didn't configure. `Security scan host` is its own key rather than a read of § Environments, which carries no `| **Key** |` row and so can't be cited by a skill. Carries v4.30.0 — the legacy planning layer is gone (`bin/pk`'s phase-file/ID-map fallback, the `Backend` key and its whole chain, `/spec-preflight`'s dead `phase-detect` probe, `/review-plan`'s phase-slug path). Linear is the only initiative surface.)*

Project-specific values that portable skills read at runtime. Copy this file to your project root as `method.config.md` and fill in your values.

## Project

| Key | Value |
|-----|-------|
| **Project name** | `your-project` |
| **Project display name** | `Your Project` |
| **Worktree prefix** | `~/Projects/your-project-` |
| **Session logs path** | `Logs/Sessions/` |
| **Strategy docs path** | `Strategy/` |
| **Changelog path** | _(optional: path to in-app changelog JSON)_ |

## Linear

| Key | Value |
|-----|-------|
| **Workspace slug** | `your-workspace` |
| **Team name** | `YourTeam` |
| **Team ID** | `00000000-0000-0000-0000-000000000000` |
| **Issue prefix** | `XXX` |

> **`Team ID` and `Workspace slug` also pin `pk`'s write guard.** Before any Linear
> mutation, `pk` verifies the resolved token belongs to this workspace and refuses on a
> confirmed mismatch — so a stale or cross-project token can't write to the wrong board.
> Set at least one (Team ID is the strongest pin); with neither set the guard is skipped
> with a one-time warning.

### Workflow State IDs

Skills use these IDs to transition issues. Get them from Linear API or the Linear UI (Settings > Workflow).

| State | ID |
|-------|-----|
| Triage | `` |
| Ideas | `` |
| Future Phases | `` |
| On Deck | `` |
| Needs Spec | `` |
| Specced | `` |
| Approved | `` |
| Building | `` |
| In Progress | `` |
| UAT | `` |
| Released | `` |
| Done | `` |
| Canceled | `` |
| Duplicate | `` |

## Initiative Surface (Linear-native)

The roadmap's initiative order lives in **Linear**, not a committed file. `pk next` and `pk status`
derive the current initiative live from the Linear hierarchy; `/roadmap-create` authors it and
`/phase-plan` advances it. There is no `PHASES.md` or `linear-map.json` to keep in sync.

**The naming convention is the contract** (ordering comes from the name prefix, never Linear's
`sortOrder` — that field is an internal drag-rank and does not track initiative sequence):

| Level | Linear construct | Naming | Meaning |
|-------|-----------------|--------|---------|
| Initiative | **Initiative** | `i{N}. label` (e.g. `i1. Foundation`) | An ordered, **completable** release phase. `pk next` walks these by `{N}`. |
| Lane / sub-phase | **Project** | `I{N}.P{N}. label` (e.g. `I1.P2. Budget Editor`) | A **completable batch of ~3–8 issues** cut from the backlog. Issues live here. |
| Theme | **Initiative**, unprefixed | `label` (no `i{N}.`) | A long-running strand allowed to never complete. Ignored by `pk next`/`pk status`. |
| Backlog | **Issue**, no project | (Linear identifier) | The default for **uncut** work, classified by an `Area:` label (below). |
| Work item | **Issue** | (Linear identifier) | The unit `/work` builds. |

- **Project names carry their initiative number** (v4.5.0+): a project under `i1.` is `I1.P2. label`, not bare `P2.` — initiatives sit above projects in Linear and get buried, so the initiative reads at the project level (the unit you navigate). `bin/pk` accepts **both** `I{N}.P{N}.` and legacy bare `P{N}.`; the `P{N}` number sets sub-phase order either way. Author the `I{N}.P{N}.` form.
- **Order** = the integer in the prefix, parsed numerically (`P2` before `P10`).
- **Current initiative** = lowest `i{N}` initiative whose status ≠ `Completed`.
- **Current sub-phase** = lowest `P{N}` project in it whose state ∉ {`completed`, `canceled`}.
- **Roadmap opt-in** = the `i{N}.` prefix. Unprefixed initiatives (strategic themes) are ignored
  by `pk next`/`pk status` — no config list needed.
- **Milestones** (Work Packages) remain an optional intra-project grouping, orthogonal to phases.

**Completability is the load-bearing property.** A project holding 60 open issues is a *pool*, not a
lane — and the `i{N}.`→`P{N}.` walk structurally cannot see into a pool, so `pk status` will point at
some idle lane while all the live work sits invisible. (Anchor: SiteLine, 2026-08-02 — 98 of 162 open
issues sat in three pool projects; `In Progress` read 0 and the real execution order had migrated into
a gitignored notes file.) The rule that prevents it: **completability lives at the project level,
eternity lives at the theme/label level.** A project is created only for work that has been *cut* into
a lane — never as a standing bucket to file things into.

- **Placeholder lanes are deliberate, not clutter.** An initiative whose projects are all completed
  reads as "done" to the walk and gets skipped prematurely. A downstream initiative with no live work
  yet needs one empty `I{N}.P1.` project whose **description contains the literal word `placeholder`**.
  Skills exempt those from empty-project nagging by that convention — there is no config list to keep
  in sync.
- **`Parked` is a label, not a workflow state** — a Parked *state* hides work from every state-based
  query. Move such issues to `Backlog` and label them.
- **A parallel strand that never gates the arc gets the *highest* number**, not no number: `i8.` rather
  than unprefixed. It stays inside the walk (so its work is visible) while being guaranteed never to
  become "current" ahead of the real arc.

### Board shapes

The naming contract above is identical for both shapes; they differ in what a *phase* maps to.

| Shape | Phase ≡ | Ordering lives in | Use when |
|---|---|---|---|
| Lanes **(default)** | one initiative, 1:1 | the `i{N}.`/`P{N}.` prefixes + `blockedBy` relations | Almost always. `/roadmap-create` authors this. |
| Phase-spans-projects | several projects | the prefixes **plus** the opt-in Phase Label Layer below | A phase genuinely spans multiple projects, so no single project *is* a phase. |

Pick one. Running both means two ordering mirrors encoding the same order and drifting independently —
which is the failure the lanes model exists to remove.

> **Canonical explanation: `sop/Linear_SOP.md § Board shapes`** (that file is synced to every project;
> this one is not, so skills cite the SOP). The summary here is for filling in the config below.

### Area Labels (recommended on the lanes model)

Uncut backlog work carries **no project**, so it needs one classification axis to stay navigable. Use a
real Linear **label group** whose children name your domains. Fill in your own; the values below are
illustrative.

| Key | Value |
|-----|-------|
| **Area label group** | `Area` |
| **Area labels** | `Area: Security`, `Area: Budget Editor`, `Area: Platform` |
| **Lane size** | `3-8` _(advisory; `/linear-hygiene` flags a project over the upper bound as pool smell)_ |

- **Area classification persists through lane moves.** An issue keeps its `Area:` label when it is cut
  into a lane — the label says *what domain this is*, the project says *which batch it's in*.
- **Never infer Area from a lane** — a lane can legitimately mix areas.
- One `Area: * — backlog` saved view per label renders the uncut work.
- Leave this section blank to skip the convention; skills that read it no-op when it's empty.

> **Legacy fallback:** projects not yet migrated to `i{N}.`-prefixed initiatives fall back to the
> Rename your delivery initiatives with `i{N}.` prefixes to switch a project to the native surface,
> then the files can be deleted. New projects are native from `/roadmap-create`.

### Phase Label Layer (optional — the phase-spans-projects shape only)

An **opt-in visualization mirror** of `ROADMAP.md`'s build order onto the Linear board, for projects
whose roadmap **phases span multiple `I{N}.P{N}.` projects** (so no single Linear project *is* a phase,
and a plain project filter can't render "this phase, in order"). It answers *"what order do I run these
in, what's parallel?"* — a question the `i{N}.`/`I{N}.P{N}.` surface above does **not** answer.
`/roadmap-review` Phase 3.5 drift-checks it against `ROADMAP.md`; `/roadmap-create` Phase 3.5 scaffolds it.

**A board on the lanes model must not adopt this layer.** There, phases ≡ initiatives and the prefixes
already carry the order, so the labels would be a second mirror of it — the two-mirror drift the lanes
model exists to remove.

**The config table below ships commented out — that's the opt-out.** The skills gate on the *filled-in
values*, not this heading: with the table commented (or its cells blank) there's no active config, so
`/roadmap-review` Phase 3.5 no-ops and an un-opted project sees zero behavior change. **To opt in:**
uncomment the block and replace the example label/view names with your own (drawn from *your*
`ROADMAP.md`'s phase names — letters, numbered milestones, quarters, whatever it uses). If your phases
map 1:1 to projects, you don't need this layer — the initiative surface already answers "what order."

<!-- OPT IN by uncommenting this block and filling your values:
| Key | Value |
|-----|-------|
| **Sequenced phase labels** | `Roadmap: Phase A`, `Roadmap: Phase B`, `Roadmap: Phase C` |
| **Continuous pool label** | `Roadmap: Continuous` |
| **Order label** | `Order: Any` |
| **Saved view per label** | one ungrouped view per label; Manual sort is set by hand in the Linear view UI (not settable over MCP) |
| **`sortOrder` step** | `1000` (gap between adjacent issues; leaves slack to insert without a renumber) |

- **Phase labels come from your own `ROADMAP.md` phase names** — the values above are SiteLine-shaped examples, not a contract.
- **Continuous is named-items-only:** only issues `ROADMAP.md` names by identifier get the pool label — never every open issue in the pool's projects.
- **Order = real `blockedBy` relations**, never description prose. `Order: Any` marks issues with no intra-phase dependency (safe to run anytime / in parallel).
- One issue carries **at most one** `Roadmap: Phase *` label (or the pool label) — never two, and never both `Order: Any` and an unresolved `blockedBy`.
-->

### Roadmap source (independent of the layer above)

| Key | Value |
|-----|-------|
| **Roadmap source** | `ROADMAP.md` |

The file whose per-phase issue lists the label layer mirrors — *and* the file `/roadmap-review`
Phase 2.5 reconciles checkboxes against. **Phase 2.5 is not gated on the Phase Label Layer**, so this
key lives outside the commented block: a project can have a checkboxed roadmap without ever adopting
the layer, and retiring the layer must not silently repoint the reconciliation. Blank → skills fall
back to the root `ROADMAP.md`.

**Retirement path** (migrating an opted-in board to the lanes model — order matters; canonical copy in
`sop/Linear_SOP.md § Board shapes`):

1. **Comment out the Phase Label Layer table first.** `/roadmap-review` Phase 3.5 gates on the
   filled-in values, so while they are live it will re-scaffold whatever you delete next.
2. Then delete the `Roadmap: *` / `Order: *` labels and their saved views.
3. **Leave `Roadmap source` above untouched** — Phase 2.5 reads it independently and still works.
4. Real `blockedBy` relations stay — on the lanes model they carry all intra-lane ordering.

## Slack (optional)

| Key | Value |
|-----|-------|
| **Session channel ID** | _(channel for end-session posts)_ |

## Git Architecture

Choose a branching model during `/startup`. This decision determines your environments, promotion skills, and release flow.

**Model:** `two-tier` | `three-tier`

> **Note:** `/startup` will fill in your chosen model below and remove the other option. Both are shown here as a template reference.

### Two-Tier (dev → main)

Best for: solo dev, small teams, projects where preview URLs replace a staging environment.

| Environment | Branch | Purpose |
|-------------|--------|---------|
| Production | `main` | Live |
| Dev | `dev` | Active development |
| Preview | PR branches | Per-PR preview URLs |

**Release flow:** `feature/*` → PR to `dev` → PR to `main`
**Promotion mechanism:** `pk ship` opens the feature → `dev` PR as Draft (v2.6.0+; `pk ready` flips to Ready). `pk promote main` opens the `dev` → `main` PR (Phase 1, no state change); `pk promote main --finish` after the merge transitions WITs to `Done` (Phase 2).
**Linear transitions (v2.6.0+):** `pk ship` → `UAT` (PR open as Draft on preview); `pk done` → `In Dev` (merge confirmed, on dev) + auto-pull; `pk promote main --finish` → `Done` (after the promote PR merges; two-phase, not optimistic). `pk done` runs *after* the PR is merged (or pass `--merge` and let pk run `gh pr merge` for you).

### Three-Tier (dev → beta → main)

Best for: teams with QA, projects needing a stable UAT environment, regulated industries.

| Environment | Branch | Purpose |
|-------------|--------|---------|
| Production | `main` | Live |
| Beta | `beta` | Pre-release UAT, password-protected |
| Dev | `dev` | Active development |
| Preview | PR branches | Per-PR preview URLs |

**Release flow:** `feature/*` → PR to `dev` → PR to `beta` → PR to `main`
**Promotion mechanism:** `pk ship` opens the feature → `dev` PR as Draft (v2.6.0+; `pk ready` flips to Ready). `pk promote <env>` walks one hop per invocation (`pk promote beta` then `pk promote main`); each hop is two-phase — Phase 1 opens the PR, Phase 2 (`--finish`) transitions Linear states after merge.
**Linear transitions (v2.6.0+):** `pk ship` → `UAT` (PR open as Draft on preview); `pk done` → `In Dev` (merge confirmed) + auto-pull; `pk promote beta --finish` → `In Beta` (after promote PR merges); `pk promote main --finish` → `Done`. Each `pk promote` is two-phase — WITs stay in source state until `--finish` after the merge.

### Environments

Fill in URLs after deployment setup.

| Environment | URL | Branch |
|-------------|-----|--------|
| Production | | `main` |
| | | |

## Strategy Docs

Define which strategy docs this project maintains. `/strategy-create` generates initial versions; `/strategy-sync` keeps them current after features ship.

| Doc | File | Purpose | Audience |
|-----|------|---------|----------|
| Conceptual Overview | `Strategy/ConceptualOverview.md` | What the product does in plain language | Stakeholders |
| Technical Architecture | `Strategy/TechnicalArchitecture.md` | System design, schema, APIs, patterns | Developers |

Add rows as needed. Common additions:

| Doc | File | Purpose | Audience |
|-----|------|---------|----------|
| Design Direction | `Strategy/DesignDirection.md` | Visual style, inspiration, anti-patterns for build agents | Developers, AI Agents |
| Permissions | `Strategy/Permissions.md` | Auth, roles, RLS, access control | Developers, Admins |
| UX Reference | `Strategy/UXReference.md` | UI patterns, shortcuts, onboarding | Developers, Support |
| Workflow Examples | `Strategy/WorkflowExamples.md` | Step-by-step user scenarios | All |
| Data Model | `Strategy/DataModel.md` | Schema, relationships, calculations | Developers |

## Tiers

Tiers shape which gates apply to an issue. `/work` infers the tier from issue labels (`tier:quick`, `tier:standard`, `tier:heavy`) but **always confirms with the human before proceeding** — automatic tier escalation/de-escalation is disallowed by design.

| Tier | Default? | Use for | Skipped gates | Added gates |
|------|----------|---------|---------------|-------------|
| **Quick** | No (opt-in) | 1–3 stories, single PR, AC fits in head | Spec review, milestone-readiness, plan-review | — |
| **Standard** | Yes (default) | Normal feature work | — | — |
| **Heavy** | No (opt-in) | Multi-phase, security-sensitive, cross-strategy-doc | — | Security review, mandatory `/strategy-sync` before close |

Per-tier templates live at `pipekit/templates/tier-{quick,standard,heavy}.md`.

To disable a tier in this project, remove its row above. Removing **Standard** is not allowed — it is the fallback.

## Model Policy

Which model and effort tier each **agent role** runs on. Portable skills reference roles, never
model names — when a new model generation ships, re-point a row here and every skill follows.
This section is **optional**: if it's absent (or a role has no row), skills use the defaults below,
so un-migrated projects see no behavior change.

| Role | Used by | Default model | Default effort |
|------|---------|---------------|----------------|
| **Grounding / lookup** | read-only fact sweeps: Explore/scout-type subagents spawned by skills | `haiku` | `low` |
| **Execution** | native Workflow task agents, batch runners, mechanical file-shaping subagents, gate classifiers (`/security-gate`, `/prod-ready`) | `sonnet` | `medium` |
| **Verification** | `/verify` QA review subagent | `sonnet` | `high` |
| **Plan review / adversarial** | `plan-reviewer` (`/review-plan`), antagonistic reviewer (`/verify --review`), spec reviewers | `opus` | `xhigh` |

- **The rubric behind the rows: a tier is earned by the cost of a silent miss, not by task
  difficulty.** Work whose failure ships invisibly — a verification pass that quietly misses, an
  adversarial review that validates instead of doubting, a sign-off gate — gets the top tiers,
  because nothing downstream catches it. Spec'd execution fails loudly (verify, tests, and review
  all sit behind it), so the middle tier is enough even when the task is hard. Mechanical lookups
  whose errors surface immediately on use run cheapest. When adding a role or re-pointing a row at
  the next model generation, derive from this rubric rather than from how demanding the work feels.
- **The session model is not configured here** — that's whatever the human runs Claude Code on.
  Roles govern *spawned subagents* only.
- Model values are harness aliases (`haiku` / `sonnet` / `opus`), which resolve to the current
  generation automatically. Pin an exact model ID only when you have a specific reason.
- Effort defaults follow current Anthropic guidance (`high` as the general default, `xhigh` for
  the hardest review work, `low` sufficient for mechanical lookups on current-generation models).
  Effort calibration shifts between model generations — re-validate rather than assuming the
  mapping ports unchanged.
- **The execution row may be left blank to inherit the session model.** On current frontier models,
  `low` / `medium` effort on the session model can cost less *per completed task* than a smaller
  model at `medium` (fewer retries, fewer verify failures). Measure before flipping — the silent-miss
  rubric still decides the tier; this only says which model to put on the scale.

## Pre-Deploy Gate

Commands that must pass before any deployment. Adjust per project stack.

```bash
pnpm turbo run check-types
pnpm turbo run lint
pnpm turbo run test
```

## V2 keys

Keys consumed by `bin/pk` and the `/work` + `/verify` skills. All have sensible defaults — leave blank if the default fits.

| Key | Value | Default | Used by |
|-----|-------|---------|---------|
| **Integration branch** | `dev` \| `main` | derived from § Git Architecture | `pk ship` (PR base) |
| **Promote to main** | `true` \| `false` | `true` if integration is `dev` | `pk promote` (skips if `false`) |
| **Deploy command** | shell command | (none) | `pk deploy` / `pk done` — for **script-deploy** projects (deploy is a script, not branch promotion). `pk deploy` (or `pk deploy prod`) runs this command; `pk done` also surfaces it after merge as a "merged ≠ deployed" reminder. Advisory; never auto-run. Leave blank for branch-per-env projects that use `pk promote`. |
| **Deploy command `<env>`** | shell command | (none) | `pk deploy <env>` — per-environment override (key is **space-suffixed**, e.g. `Deploy command dev`, because `pk_config` splits on the first colon). `pk deploy dev` runs `Deploy command dev`; `pk deploy` / `pk deploy prod` fall back to the bare `Deploy command`. Add one row per env you deploy to (`dev`, `staging`, …). |
| **Require QA review** | `true` \| `false` | `false` | `/verify` (auto-spawns QA subagent if `true`) |
| **Default deep flag** | `true` \| `false` | `false` | `/work` (treats every issue as `--deep` if `true`) |
| **Ship environments** | comma-separated list, ordered | `dev,main` | `pk ship --env=<name>` (multi-env projects only) |
| **Linear API key env var** | name, e.g. `LINEAR_API_KEY` | `LINEAR_API_KEY` | `pk *` (Linear API access) |
| **Method repo** | git URL | `https://github.com/withpiper/pipekit.git` | `pk doctor` (upstream-staleness check); also overridable via the `METHOD_REPO` env var. Only forks on a non-standard remote need to set this. |
| **Migration dir** | e.g. `supabase/migrations/` | (none) | `/pr-security-review` (locate migrations to audit); `/spec-preflight` Probe 3.6d (migration data-shape); `scripts/check-migration-drift.sh` + `templates/ci/migration-drift.yml` (v4.18.0 drift detection — no value → clean skip) |
| **Platform** | `managed-supabase` \| `self-hosted-postgres` \| `none` | `none` | `/spec-preflight` Probe 3.6b — refuses GUC-based prod-safety designs on managed-supabase (handoff #20, verified at WIT-450) |
| **Spec ready state** | Linear state name | `Specced` | `pk spec-cycle` (refuses to trigger if issue is in any other state) |
| **Spec approved state** | Linear state name | `Approved` | `pk spec-cycle` (transitions issue to this state on a Pass verdict) |
| **Self-reference check** | `enabled` \| `disabled` | `disabled` | `pk verify` — runs `scripts/check-no-self-references.sh`; fails if current branch's source still references its own ticket ID (e.g. `RS-29`) in any file the branch did not edit. Catches predecessor-placeholder integration misses (RS-29 rs-vault, 2026-05-05). Bypass on a per-run basis with `AGREED_PLACEHOLDER=1 pk verify` after surfacing matches in the hand-off summary. |
| **Source root** | path | `src/` | `scripts/check-no-self-references.sh` (where to grep) |
| **Financial review WIT** | Linear issue id, or blank | (blank) | `/financial-review` — recurring WIT moved In Progress → In Review → Done each cycle; **blank disables the Linear lifecycle** (run + report only). Finance/calculation-heavy projects only. |
| **Financial review checks** | path | `resources/financial-review-checks.md` | `/financial-review` — project checks file (test cmd, calc files, DB-integrity SQL, parity formulas). Scaffold from `pipekit/templates/financial-review-checks.template.md`. |
| **Prod-ready checks** | path | `resources/prod-readiness-checks.md` | `/prod-ready` — project checks file (build command, secret prefixes, monitoring, rate-limit middleware, backups, flags, dashboards). Scaffold from `pipekit/templates/prod-readiness-checks.template.md`. The skill guards the **last** entry in `Ship environments` (the production env). |
| **Prod-ready report path** | path | `Reports/` | `/prod-ready` — where the readiness report is written (`Production_Readiness_<ID>_<date>.md`). |
| **Security categories** | path | `resources/security-categories.md` | `/security-gate` — project category-definitions file (per-category path globs, keywords, correct patterns for auth/payments/user-input/external-APIs/file-storage/PII). Scaffold from `pipekit/templates/security-categories.template.md`. The gate runs at the Building → UAT seam (before `pk ship`). |
| **Security gate report path** | path | `Reports/` | `/security-gate` — where the gate report is written (`Security_Gate_<ID>_<date>.md`). |
| **Repo security areas** | path | `resources/repo-security-areas.md` | `/repo-security-review` — project audit-area definitions (per-area path globs, the repo's actual auth/middleware/policy **primitives**, and checks). Scaffold from `pipekit/templates/repo-security-areas.template.md`. One area = one parallel audit agent; no file → the skill scaffolds and stops. |
| **Repo security report path** | path | `Reports/` | `/repo-security-review` — where the periodic review report is written (`Security_Review_<date>.md`). |
| **Security architecture doc** | path | (blank) | `/repo-security-review` — internal security-architecture doc, read as the claimed architecture and refreshed when findings change it. **Blank → the step is skipped and reported `n/a`**, never invented. |
| **Public security page** | path | (blank) | `/repo-security-review` — public-facing security page refreshed after the review (posture, doc version, any claim the audit couldn't evidence). **Blank → skipped**. |
| **Security scan host** | hostname | (blank) | `/repo-security-review` — host for live external scans (header grading, Lighthouse). **Blank → live scans skipped and reported `n/a`**, never as a pass. Kept as its own key rather than read from § Environments so a project can scan a host it doesn't promote to. |
| **Portfolio staleness days** | integer | `14` | `pk portfolio` — a project sub-phase whose newest issue hasn't been touched (Linear `updatedAt`) in more than this many days is flagged `⚠ Nd idle` in the runway. |
| **Lane map URL** | artifact URL | (none) | `/lane-map` — published board-map artifact; blank until the project runs `/lane-map` once and publishes it (see `sop/Lane_Map_SOP.md`). One map can serve multiple repos sharing a Linear board — set the same URL in each. |

<!-- Optional (v4.21.0+) — uncomment the row below to stop syncing canonical
     .claude/rules/ files that don't apply to this project. Rules are
     auto-loaded into every session turn, so a rule that opens "if the project
     doesn't use X, this rule is informational" still costs input tokens on
     every turn it doesn't apply to. Skip-listed rules are not synced and are
     removed from .claude/rules/ if previously synced; clearing the key
     restores them on next sync. README.md is not skippable; unknown names
     warn and are ignored. Ships commented out so a verbatim template copy
     never accidentally drops a rule. NOTE: keep this row indented while
     commented — the sync's key parser anchors on column-0 `| **Key**` rows,
     so indentation is what keeps a verbatim copy inert. To opt in, copy the
     row into the table above WITHOUT the leading spaces.
     | **Skip rules** | `pipekit-cmux, pipekit-migrations` | (none — all five rules sync) | `scripts/sync-method.sh` (v4.21.0+) — canonical-rule opt-out; see `.claude/rules/README.md` § Opting out |
-->

### Example (rs-vault)

```
Integration branch: main
Promote to main: false
Require QA review: false
Default deep flag: false
Ship environments: main
```

### Example (Piper)

```
Integration branch: dev
Promote to main: true
Require QA review: true
Default deep flag: false
Ship environments: dev,beta,main
```

### Example (script-deploy — e.g. an FTP-from-`main` project)

Single trunk, no branch promotion: each env is a deploy *script*, run with `pk deploy <env>`.

```
Integration branch: main
Promote to main: false
Ship environments: dev,main
Deploy command: ./scripts/deploy/deploy-prod.sh
Deploy command dev: ./scripts/deploy/deploy-dev.sh
```
