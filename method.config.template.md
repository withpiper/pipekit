# Method Configuration

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
**Promotion mechanism:** `pk ship` opens the feature → `dev` PR; `pk promote` opens the `dev` → `main` PR.
**Linear transitions:** `pk ship` → UAT (or In Review); merge to `main` (via `pk promote` PR) → `pk done` posts to Linear and the issue moves to Done.

### Three-Tier (dev → beta → main)

Best for: teams with QA, projects needing a stable UAT environment, regulated industries.

| Environment | Branch | Purpose |
|-------------|--------|---------|
| Production | `main` | Live |
| Beta | `beta` | Pre-release UAT, password-protected |
| Dev | `dev` | Active development |
| Preview | PR branches | Per-PR preview URLs |

**Release flow:** `feature/*` → PR to `dev` → PR to `beta` → PR to `main`
**Promotion mechanism:** `pk ship` opens the feature → `dev` PR; `pk promote` walks `dev` → `beta` and `beta` → `main` per `Ship environments` in the V2 block below.
**Linear transitions:** `pk ship` → UAT (or In Review); merge to `beta` → issues stay in UAT; merge to `main` (via `pk promote` PR) → issues move to Done.

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
| **Backend** | `vbw` \| `native` \| `auto` | `vbw` | `/work` — chooses agent dispatch path. `auto` routes per plan complexity: ≤3 files + no migration → native, otherwise → vbw |
| **Integration branch** | `dev` \| `main` | derived from § Git Architecture | `pk ship` (PR base) |
| **Promote to main** | `true` \| `false` | `true` if integration is `dev` | `pk promote` (skips if `false`) |
| **Require QA review** | `true` \| `false` | `false` | `/verify` (auto-spawns QA subagent if `true`) |
| **Default deep flag** | `true` \| `false` | `false` | `/work` (treats every issue as `--deep` if `true`) |
| **Ship environments** | comma-separated list, ordered | `dev,main` | `pk ship --env=<name>` (multi-env projects only) |
| **Linear API key env var** | name, e.g. `LINEAR_API_KEY` | `LINEAR_API_KEY` | `pk *` (Linear API access) |
| **Migration dir** | e.g. `supabase/migrations/` | (none) | `/pr-security-review` (locate migrations to audit) |
| **Spec ready state** | Linear state name | `Specced` | `pk spec-cycle` (refuses to trigger if issue is in any other state) |
| **Spec approved state** | Linear state name | `Approved` | `pk spec-cycle` (transitions issue to this state on a Pass verdict) |
| **Self-reference check** | `enabled` \| `disabled` | `disabled` | `pk verify` — runs `scripts/check-no-self-references.sh`; fails if current branch's source still references its own ticket ID (e.g. `RS-29`) in any file the branch did not edit. Catches predecessor-placeholder integration misses (RS-29 rs-vault, 2026-05-05). Bypass on a per-run basis with `AGREED_PLACEHOLDER=1 pk verify` after surfacing matches in the hand-off summary. |
| **Source root** | path | `src/` | `scripts/check-no-self-references.sh` (where to grep) |

### Example (rs-vault)

```
Backend: native
Integration branch: main
Promote to main: false
Require QA review: false
Default deep flag: false
Ship environments: main
```

### Example (Piper)

```
Backend: auto
Integration branch: dev
Promote to main: true
Require QA review: true
Default deep flag: false
Ship environments: dev,beta,main
```
