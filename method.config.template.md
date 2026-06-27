# Method Configuration

**v4.12.0** — Last updated: 2026-06-27  *(**v4.12.0** — `Team ID` / `Workspace slug` now also pin `pk`'s **write guard**: `bin/pk` refuses a Linear mutation when the resolved token's workspace doesn't match these pins (fail-closed on a confirmed mismatch; skipped with a warning if neither is set). Carries v4.11.0: the `## Phase Surface` section is now **`## Initiative Surface`** and roadmap-phase prose reads *initiative* (Sub-phase still maps to a Linear **Project**, not "sub-initiative"). Carries v4.10.0: `Portfolio staleness days` key (default 14) documents the `pk portfolio` `⚠ Nd idle` momentum threshold (v4.10.0). Carries v4.6.0: `Deploy command` + per-env `Deploy command <env>` keys and a script-deploy example document the `pk deploy [<env>]` verb. Carries v4.5.0: § Phase Surface — projects now carry their initiative number: `I{N}.P{N}. label` (e.g. `I1.P2.`), so the phase reads at the project level (the navigable unit in Linear). `bin/pk` accepts both `I{N}.P{N}.` and legacy bare `P{N}.`. Carries v4.4.0: `Security categories` + `Security gate report path` keys for `/security-gate` (gap #3). Carries v4.3.0: `Prod-ready checks` + `Prod-ready report path` keys for `/prod-ready`. Carries v4.1.0: Linear-native phase surface replaces `PHASES.md`/`linear-map.json`)*

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
| Initiative | **Initiative** | `i{N}. label` (e.g. `i1. Foundation`) | An ordered roadmap initiative. `pk next` walks these by `{N}`. |
| Sub-phase | **Project** | `I{N}.P{N}. label` (e.g. `I1.P2. Budget Editor`) | An ordered batch within an initiative. Issues live here. |
| Work item | **Issue** | (Linear identifier) | The unit `/work` builds. |

- **Project names carry their initiative number** (v4.5.0+): a project under `i1.` is `I1.P2. label`, not bare `P2.` — initiatives sit above projects in Linear and get buried, so the initiative reads at the project level (the unit you navigate). `bin/pk` accepts **both** `I{N}.P{N}.` and legacy bare `P{N}.`; the `P{N}` number sets sub-phase order either way. Author the `I{N}.P{N}.` form.
- **Order** = the integer in the prefix, parsed numerically (`P2` before `P10`).
- **Current initiative** = lowest `i{N}` initiative whose status ≠ `Completed`.
- **Current sub-phase** = lowest `P{N}` project in it whose state ∉ {`completed`, `canceled`}.
- **Roadmap opt-in** = the `i{N}.` prefix. Unprefixed initiatives (strategic themes) are ignored
  by `pk next`/`pk status` — no config list needed.
- **Milestones** (Work Packages) remain an optional intra-project grouping, orthogonal to phases.

> **Legacy fallback:** projects not yet migrated to `i{N}.`-prefixed initiatives fall back to the
> legacy `.vbw-planning/PHASES.md` + `linear-map.json` automatically — `bin/pk` reads them read-only.
> Rename your delivery initiatives with `i{N}.` prefixes to switch a project to the native surface,
> then the files can be deleted. New projects are native from `/roadmap-create`.

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
**Linear transitions (v2.6.0+):** `pk ship` → `UAT` (PR open as Draft on preview); `pk done` → `In Dev` (merge confirmed, on dev) + auto-pull (legacy `.vbw-planning/` SUMMARY/PLAN-flip for un-migrated projects only); `pk promote main --finish` → `Done` (after the promote PR merges; two-phase, not optimistic). `pk done` runs *after* the PR is merged (or pass `--merge` and let pk run `gh pr merge` for you).

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
**Linear transitions (v2.6.0+):** `pk ship` → `UAT` (PR open as Draft on preview); `pk done` → `In Dev` (merge confirmed) + auto-pull (legacy `.vbw-planning/` SUMMARY/PLAN-flip for un-migrated projects only); `pk promote beta --finish` → `In Beta` (after promote PR merges); `pk promote main --finish` → `Done`. Each `pk promote` is two-phase — WITs stay in source state until `--finish` after the merge.

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
| **Migration dir** | e.g. `supabase/migrations/` | (none) | `/pr-security-review` (locate migrations to audit); `/spec-preflight` Probe 3.6d (migration data-shape) |
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
| **Portfolio staleness days** | integer | `14` | `pk portfolio` — a project sub-phase whose newest issue hasn't been touched (Linear `updatedAt`) in more than this many days is flagged `⚠ Nd idle` in the runway. |

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
