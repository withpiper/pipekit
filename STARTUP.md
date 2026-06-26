# Project Startup Guide

**v4.11.0** — Last updated: 2026-06-26  *(**v4.11.0 — terminology aligned to Linear.** Roadmap-phase prose now reads *initiative* and the **Phase Surface** concept is the **Initiative Surface** across the active docs/skills/SOPs; `sub-phase` (the Project level), the `/phase-plan` skill name, and the `Future Phases` Linear state are deliberately kept. Carries v4.5.0: phase surface — projects carry their initiative number: `I{N}.P{N}.`-prefixed SUB-PHASES (e.g. `I1.P2. Search`), so the phase reads at the project level (the navigable unit in Linear). `bin/pk` accepts both `I{N}.P{N}.` and legacy bare `P{N}.`. Carries v4.2.0: VBW plugin decoupled — the VBW plugin is no longer required to bootstrap a Pipekit project; the roadmap is authored directly into Linear at `/roadmap-create`, with no `/vbw:init` scaffold. A legacy VBW planning layer (`.vbw-planning/`) remains for direct-VBW projects, slated for separate, later retirement. Carries v4.1.0's Linear-native phase surface; `/vbw:init` is not part of Stage 0. The roadmap's phase order lives in Linear — `i{N}.` initiatives are PHASES, `I{N}.P{N}.` projects are SUB-PHASES, issues live in projects, ordering is by the integer name prefix. Carries v4.0.0's native-only Backend row — the `vbw` executor was removed — and the v2.7.0 Step 3 `method.config.md` key reference: `Spec ready state` / `Spec approved state` as the `/light-spec` ↔ `pk spec-cycle` interlock)*

> **Reference document.** For the interactive flow, use `/startup` — it orchestrates the full bootstrap process, chaining `/concept`, `/define`, `/strategy-create`, `/roadmap-create`, `/phase-plan`, and infrastructure setup. This document provides background context and detailed checklists that the skills reference.

A walkthrough for bootstrapping a new project using Pipekit. Covers goal definition, tech stack decisions, environment setup, and skill creation.

**Audience:** You (the developer), working with Claude Code.

---

## Step 1: Define the Project

Before touching any code, answer these questions. They inform every decision downstream.

### 1.1 Project Identity

| Question | Example (Project A) | Example (Project B) |
|----------|-----------------|-------------------|
| What is this? (one sentence) | Production finance platform for event professionals | Internal tool for team data management |
| Who uses it? | Producers, accountants, project managers | End users (~40) |
| What problem does it solve? | Spreadsheet budgets don't scale, can't collaborate, no audit trail | Shared Excel leaks data, corrupts formulas, no search |
| How many users at launch? | 10-50 | ~40 |
| Revenue model? | SaaS subscription | Annual hosting fee + future success-based pricing |

### 1.2 Scope & Stages

Break the build into stages. Each stage should be independently deployable and testable.

| Decision | Notes |
|----------|-------|
| What ships in Stage 1 (MVP)? | The smallest version that proves value |
| What's Stage 2? | The features that make it sticky |
| What's deferred? | Everything else — write it down so you don't forget, but don't build it |

**Output:** A `Strategy/` directory with at minimum:
- `ConceptualOverview.md` — what the product does in plain language
- `DesignDirection.md` — visual style, inspiration, and anti-patterns (if project has a UI)
- Stage breakdown with scope boundaries

### 1.3 Linear Setup Decisions

| Decision | Options | Notes |
|----------|---------|-------|
| **Workspace name** | New workspace or add a team to existing | Separate workspace = cleaner. Same workspace = shared labels/views. |
| **Team name** | e.g., `MyProject`, `Acme` | Determines issue prefix (PROJ-1, ACME-1) |
| **Issue prefix** | e.g., `PROJ`, `ACME` | Short, unique, used in commit messages and branch names |
| **Workflow states** | Use the method standard (13 states) or simplify | Recommendation: start with the full set. You can always skip states, but adding them later means migrating issues. |
| **Initiatives** | `i{N}.`-prefixed INITIATIVES | Each is an ordered initiative (e.g., `i1. Foundation`, `i2. Search`). Ordering is the integer in the name prefix, parsed numerically (`i2` before `i10`); Linear `sortOrder` is never used. |
| **Projects** | `I{N}.P{N}.`-prefixed SUB-PHASES within an initiative | Issues live in projects (e.g., `I1.P1. Data Foundation`, `I1.P2. Search & CRUD`). The project carries its initiative number (v4.5.0+) so the initiative reads at the project level — the navigable unit in Linear. Ordering is the `P{N}` integer; `bin/pk` accepts legacy bare `P{N}.` too. |

This `i{N}.` initiative → `I{N}.P{N}.` project → issue hierarchy **is** the initiative surface — `pk next` / `pk status` derive the current initiative live from it, not from a committed file.
| **Labels** | Domain, Type, Flag, Tier | Domain labels are project-specific. Type/Flag labels are standard. |

**Action:** Create the workspace/team, set up states, create initial initiatives and projects.

---

## Step 2: Choose the Tech Stack

Every choice here has downstream implications for skills, deployment, and conventions.

### 2.1 Core Decisions

| Decision | Options to Evaluate | Example Choice | Notes |
|----------|-------------------|----------------|-------|
| **Framework** | Next.js, Remix, SvelteKit, Astro | Next.js 15 (App Router) | Determines routing, SSR, component model |
| **Language** | TypeScript, JavaScript | TypeScript (strict) | Always TypeScript for anything non-trivial |
| **Database** | Supabase, PlanetScale, Neon, Turso, Firebase | Supabase (Postgres + Auth + RLS) | Determines auth, RLS, migration workflow |
| **Auth** | Supabase Auth, Clerk, Auth0, NextAuth | Supabase Auth | Bundled with DB = simpler. Clerk = better UI out of box. |
| **Deployment** | Vercel, Netlify, Railway, Fly.io | Vercel | Determines preview URLs, CI/CD, edge functions |
| **Monorepo?** | Turborepo, Nx, single app | Turborepo + pnpm workspaces | Only if you need shared packages. Single app is simpler. |
| **CSS** | Tailwind, CSS Modules, styled-components | Tailwind + shadcn/ui | shadcn gives you headless components to customize |
| **Data grid** | AG Grid, TanStack Table, custom | AG Grid Enterprise | Only if you need a spreadsheet-like grid |
| **Testing** | Vitest, Jest, Playwright | Vitest + Playwright | Vitest for unit, Playwright for E2E |
| **Error tracking** | Sentry, LogRocket, Highlight | Sentry | Free tier is generous |
| **AI/LLM** | Claude API, OpenAI, none | Claude + Langfuse | Only if the product has AI features |

### 2.2 Hosting & Infrastructure Decisions

| Decision | Options | Notes |
|----------|---------|-------|
| **Environments** | How many? (dev, beta, prod) | Minimum: dev + prod. Beta is valuable for UAT. |
| **Domain** | Production domain | Buy early, configure DNS |
| **DB per environment** | Shared dev/beta or separate | Example: sharing dev/beta on one Supabase project — simpler but riskier for migrations |
| **CI/CD** | GitHub Actions, Vercel built-in | Vercel auto-deploys on merge. GitHub Actions for DB migrations. |
| **Secrets management** | Vercel env vars, Doppler, .env | Vercel env vars synced via `vercel env pull` |

### 2.3 Stack-Driven Skill Requirements

Pipekit v2 covers most of the daily delivery loop via `pk ship` (push + open PR + Linear → UAT) and `pk promote` (dev → main). Vercel preview/prod fires automatically on PR open / main merge. So in v2, the project-specific skill list is much shorter than in v1 — most stacks need none.

| If you use... | What you need |
|---------------|---------------|
| Vercel | Nothing — Vercel hooks handle preview/prod on PR open + main merge. |
| Supabase | A GitHub Actions migration workflow (`db-migrate.yml` + `db-pr-check.yml`); the rs-vault repo has a working pair you can lift. No Pipekit skill needed. |
| Any DB with test users | `reset-user` (project-specific skill — clears a user + their data for testing). |
| Monorepo with shared UI | `component` (project-specific skill — scaffolds a shared component). |
| Multi-env beyond dev/main | Set `Ship environments: dev,beta,main` in `method.config.md`; `pk promote` walks the chain. |

---

## Step 3: Set Up the Stack

Execute in order. Each step unlocks the next.

### 3.1 Repository

```
[ ] Create GitHub repo (private)
[ ] Clone locally
[ ] Initialize framework (e.g., `npx create-next-app@latest`)
[ ] Set up TypeScript strict mode
[ ] Add .gitignore, .env.example  (recommended entry: .pk-work/ — transient /work marker files)
[ ] Create initial CLAUDE.md (project overview, stack, conventions)
[ ] Set up branch protection (main: require PR + CI)
```

### 3.2 Monorepo (if applicable)

```
[ ] Initialize Turborepo or equivalent
[ ] Create workspace packages (e.g., packages/ui, packages/utils)
[ ] Configure shared tsconfig
[ ] Configure shared ESLint
[ ] Verify `pnpm turbo run build` works
```

### 3.3 Database

```
[ ] Create Supabase project(s) or equivalent
[ ] Initialize local development (e.g., `supabase init`)
[ ] Create initial schema migration
[ ] Enable RLS on all tables
[ ] Set up auth (if using Supabase Auth)
[ ] Verify local `supabase db reset` works
[ ] Document connection strings in .env.example
```

### 3.4 Deployment

```
[ ] Link project to Vercel (or equivalent)
[ ] Configure environment variables per environment
[ ] Set up custom domains
[ ] Verify preview deployments work (push a branch)
[ ] Set up CI pipeline (GitHub Actions for DB migrations if needed)
[ ] Verify production deploy works
[ ] Add health check endpoint (/api/health)
[ ] Verify smoke tests pass
```

### 3.5 Tooling

```
[ ] ESLint configured and passing
[ ] Vitest configured with at least one test
[ ] Playwright configured (if E2E needed)
[ ] Pre-deploy gate works: check-types + lint + test
[ ] Sentry configured (if using)
[ ] Langfuse configured (if using AI features)
```

### 3.6 MCP Servers

```
[ ] GitHub MCP (PRs, issues, code search)
[ ] Linear MCP (issue tracking)
[ ] Supabase MCP — dev (full access)
[ ] Supabase MCP — prod (read-only, if applicable)
[ ] Vercel MCP (deploy logs, metadata)
[ ] Sentry MCP (error tracking, if using)
[ ] Chrome DevTools MCP (browser debugging)
[ ] Playwright MCP (E2E testing)
```

Configure in `.mcp.json` with `${VAR}` interpolation for secrets.

### 3.7 Sync the Method

```
[ ] Fetch sync script:
    mkdir -p scripts
    curl -fsSL https://raw.githubusercontent.com/withpiper/pipekit/main/scripts/sync-method.sh -o scripts/sync-method.sh
    chmod +x scripts/sync-method.sh
[ ] Run: ./scripts/sync-method.sh
[ ] Fill in method.config.md with project-specific values (see V2 keys below)
[ ] Commit synced method files
```

**V2 `method.config.md` keys the `pk` daily loop reads.** Copy these from `method.config.template.md` and set each one — the daily loop and portable skills read them at runtime:

| Key | What it controls |
|-----|------------------|
| `Integration branch` | The base `pk ship` opens PRs against (`dev` or `main`). |
| `Promote to main` | Whether `pk promote` is enabled (`false` for single-tier projects). |
| `Ship environments` | The chain `pk promote` walks (`prod`, `dev,main`, `dev,beta,main`, …). |
| `Spec ready state` | **Load-bearing.** The Linear state `/light-spec` publishes to and `pk spec-cycle` requires on entry. Must name a state your workflow actually has (e.g. `Specced`, or `Needs Spec` on two-state boards). A mismatch breaks the spec cycle. |
| `Spec approved state` | The state `pk spec-cycle` transitions to on a Pass verdict (default `Approved`). |
| `Migration dir` | Where migrations live; drives `/verify`'s migration self-review. |
| `Require QA review` | Whether `/verify` spawns the QA subagent. |
| `Deploy command` | Script-deploy projects only: the command `pk done` reminds you to run after merge. |
| `Linear API key env var` | Name of the env var holding the Linear token (`pk` reads it from the shell). |

`Spec ready state` and `Spec approved state` are not optional cosmetics — they are the interlock between `/light-spec` and `pk spec-cycle`. If they don't match your Linear workflow's state names exactly, speccing fails. See `method.config.template.md` for the full key list with examples.

---

## Step 4: Create Project-Specific Skills

In v2, the daily delivery loop (push, PR, promote, migrate) is covered by `pk *` commands, Vercel hooks, and GitHub Actions. Project-specific skills are limited to things that **truly** depend on your domain, schema, or infrastructure — not generic delivery plumbing.

### 4.1 What v2 already gives you (don't rebuild these)

| You don't need a skill for... | Because v2 handles it via... |
|---|---|
| Open PR feature → dev | `pk ship` (Draft by default v2.6.0+; `pk ready` flips to Ready) |
| Promote one hop along Ship environments | **Phase 1**: `pk promote <env>` (e.g. `pk promote beta`) — opens promote PR, WITs stay in source state. **Phase 2**: `pk promote <env> --finish` after the PR merges — transitions WITs → `In <Env>` or → Done by chain position. |
| Push branch + get Vercel preview | Vercel auto-fires on PR open |
| Apply Supabase migrations to prod | GitHub Actions `db-migrate.yml` (lift from rs-vault) on merge to main |
| Validate migrations before merge | GitHub Actions `db-pr-check.yml` against ephemeral postgres on PR open |
| Linear status transitions | `pk ship` → `UAT` (PR open as Draft on preview, v2.6.0+); `pk done` → `In <FirstEnv>` (e.g. `In Dev` — merge confirmed; v2.6.0+ also auto-pulls the integration branch); `pk promote <env> --finish` → `In <Env>` (intermediate) or → Done (final hop). Two-phase since v2.6.0 — Phase 1 (`pk promote <env>`) opens the PR without state change. |

### 4.2 Skills that are still legitimately project-specific

| Skill | When to build | What it does |
|-------|--------------|--------------|
| `reset-user` | If you have auth + a user system | Removes a user + their FK-related rows for testing. DEV ONLY. |
| `component` | If you have a monorepo with shared UI | Scaffolds a shared component (`.tsx`, `.test.tsx`, `index.ts`) in your shared package. |
| `seed-data` | If you need repeatable test data | Loads fixtures into the dev DB. |
| `export-schema` | If you share schema with non-Pipekit consumers | Generates ERD or TypeScript types from the live DB. |
| `onboard-user` | If you regularly test multi-role user flows | Creates a test user with specific roles/permissions. |
| `backup-db` | If data is precious and you do risky ops | Snapshots current state before destructive operations. |

For each one you build: trigger name, one-sentence description, and the project-specific decisions it bakes in (what tables, what conventions, what naming). Keep them small.

---

## Step 5: Configure CLAUDE.md

Your `CLAUDE.md` is the single document the executor (native-on-Workflow) and Claude Code sessions read to understand your project. Build it up as the project grows.

### Minimum viable CLAUDE.md

```markdown
# {Project Name}

{One-line description}

## Stack
- Framework: ...
- Language: ...
- Database: ...
- Deployment: ...

## Structure
App code lives in `src/`. Project root is for Pipekit files, config, and scripts.
{Directory layout}

## Common Commands
{Build, test, lint, dev server}

## Environments
{Table of environments, URLs, branches}

## Branch Strategy
{Same as method: feature/* → dev → beta → main}
```

### Grow it over time

Add sections as patterns emerge:

| Section | Add when... |
|---------|------------|
| Database Conventions | First migration |
| API Route Pattern | First API endpoint |
| Component Conventions | First shared component |
| Data Layer (React Query) | First server state hook |
| Security Rules | First RLS policy or auth check |
| AI Layer | First LLM integration |

### Create `.claude/rules/` files

Split conventions into focused rule files that auto-load every session:

| File | Content |
|------|---------|
| `security.md` | RLS rules, auth patterns, env var security |
| `naming.md` | File naming, code naming, DB naming |
| `patterns.md` | Data layer, API routes, mutations, migrations |
| `file-structure.md` | Directory layout, package purity rules |
| `tooling.md` | Commands, CI, pre-deploy gate, testing |

---

## Step 6: Validate the Setup

Before writing any feature code, verify the full v2 daily loop works end-to-end:

```
[ ] Create a test issue in Linear (e.g., "Add health check endpoint")
[ ] /light-spec on it; sign off in Linear (Approved)
[ ] pk next                     (should surface the issue, initiative-aware)
[ ] pk branch <ID>              (worktree + branch + Linear → In Progress)
[ ] cd .worktrees/<ID>-<slug> && claude --dangerously-skip-permissions
[ ] /work <ID>                  (plan + execute; verdict gate before code)
[ ] /verify                     (pre-deploy gate runs to green)
[ ] pk ship                     (push, open PR as Draft v2.6.0+, Linear → UAT; verify preview deploys)
[ ] pk ready                    (flip Draft → Ready when shipping; fires outside reviewers)
[ ] Merge PR (rebase or merge-commit); verify dev deployment
[ ] pk done <ID> [--merge]      (cleanup worktree+branch; Linear UAT → In <FirstEnv>)
[ ] pk promote <env>            (Phase 1 v2.6.0+: open promote PR; WITs stay in source state)
[ ] pk promote <env> --finish   (Phase 2 v2.6.0+: after promote PR merges; → In <Env> for intermediate, → Done for final)
[ ] /pk-exit                    (writes session log to Logs/Sessions/<date>_<HHMM>.md)
```

If all steps work, the pipeline is ready. Start building.

---

## Decision Checklist (Copy This)

### Project Definition
- [ ] One-sentence description written
- [ ] Target users identified
- [ ] Stage 1 (MVP) scope defined
- [ ] Stage 2+ deferred and documented

### Tech Stack
- [ ] Framework chosen
- [ ] Database chosen
- [ ] Auth approach chosen
- [ ] Deployment platform chosen
- [ ] Monorepo vs single app decided
- [ ] CSS/UI library chosen
- [ ] Testing tools chosen

### Linear
- [ ] Workspace/team created
- [ ] Workflow states configured (13 standard states)
- [ ] Issue prefix chosen
- [ ] Initial initiatives created (`i{N}.`-prefixed INITIATIVES)
- [ ] Initial projects created (`I{N}.P{N}.`-prefixed SUB-PHASES; issues live in projects)
- [ ] Labels configured (Domain, Type, Flag)
- [ ] State IDs copied into method.config.md

### Infrastructure
- [ ] GitHub repo created
- [ ] Vercel project linked
- [ ] Supabase project(s) created
- [ ] Custom domain configured
- [ ] Environment variables set per environment
- [ ] Branch protection enabled

### Developer Experience
- [ ] CLAUDE.md written
- [ ] .claude/rules/ created (at least security.md, naming.md)
- [ ] MCP servers configured (.mcp.json)
- [ ] Method synced (./scripts/sync-method.sh)
- [ ] method.config.md filled in
- [ ] Pre-deploy gate passing

### Skills (v2 — most projects need none beyond what Pipekit ships)
- [ ] `pk doctor` clean (config + Linear API + worktree dir all OK)
- [ ] GitHub Actions migration workflows in `.github/workflows/` if using Supabase (db-migrate.yml + db-pr-check.yml)
- [ ] **Outside reviewer workflows in `.github/workflows/`** — lift `pipekit/templates/ci/semgrep.yml` + `pipekit/templates/ci/claude-review.yml`; edit the `branches:` list to match `method.config.md` `Ship environments`. See `pipekit/templates/ci/README.md` for the Draft-PR lifecycle.
- [ ] Project-specific skills built only if they survive the "would v2 not cover this?" test (e.g., `reset-user`, `component`)
- [ ] Pipeline validated end-to-end (test issue through full cycle per Step 6)

---

## Quick Start (TL;DR)

1. **Define:** Write down what you're building and for whom
2. **Decide:** Pick your stack (framework, DB, deployment, auth)
3. **Create:** GitHub repo + Vercel project + Supabase project + Linear workspace
4. **Sync:** `./scripts/sync-method.sh` to pull in portable skills and SOPs; then `pk init` + `pk doctor`
5. **Configure:** Fill in `method.config.md`, write `CLAUDE.md`, create `.claude/rules/`
6. **Add infra (if applicable):** GitHub Actions migration workflows for Supabase; outside-reviewer workflows from `pipekit/templates/ci/`; project-specific skills only if v2 doesn't cover it
7. **Validate:** Push a test issue through the full v2 daily loop (Step 6)
8. **Ship:** Start building features
