# Project Startup Guide

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
| **Initiatives** | One per stage | Maps 1:1 to VBW phases |
| **Projects** | Feature clusters within each stage | e.g., "Data Foundation", "Search & CRUD", "Reports" |
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

Your tech stack determines which project-specific skills you need:

| If you use... | You need these skills |
|---------------|---------------------|
| Vercel | `g-test-vercel` (push + preview URL), `g-deploy` (verify deployments) |
| Supabase | `migrate` (idempotent migration workflow) |
| Any DB | `reset-user` or equivalent test data skill |
| Monorepo with shared UI | `component` (scaffold shared components) |
| Multiple environments | `g-promote-dev`, `g-promote-beta`, `g-promote-main` |
| Single environment (dev + prod only) | Simplified `promote` skill (feature → main) |

---

## Step 3: Set Up the Stack

Execute in order. Each step unlocks the next.

### 3.1 Repository

```
[ ] Create GitHub repo (private)
[ ] Clone locally
[ ] Initialize framework (e.g., `npx create-next-app@latest`)
[ ] Set up TypeScript strict mode
[ ] Add .gitignore, .env.example
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
[ ] Fill in method.config.md with project-specific values
[ ] Commit synced method files
```

---

## Step 4: Create Project-Specific Skills

These are the skills that can't be portable because they depend on your specific stack, domains, and infrastructure.

### 4.1 Required Skills (every project needs these)

#### `g-promote-dev` — PR feature branch to dev

| Field | Value |
|-------|-------|
| **Trigger** | `/g-promote-dev` |
| **What it does** | Run pre-deploy gate, create PR to `dev`, extract issue refs from commits |
| **Decisions** | What's your pre-deploy gate command? What's your default PR target branch? |
| **Template from** | The reference `g-promote-dev` — adapt target branch and gate commands |

#### `g-promote-main` — PR to production

| Field | Value |
|-------|-------|
| **Trigger** | `/g-promote-main` |
| **What it does** | Run pre-deploy gate, create PR to `main`, move Linear issues to Done post-merge |
| **Decisions** | Do you have a beta stage? If yes, also need `g-promote-beta`. If no, this goes from `dev` → `main`. |

#### `g-test-vercel` — Push branch and get preview URL

| Field | Value |
|-------|-------|
| **Trigger** | `/g-test-vercel` |
| **What it does** | Push current branch, return the Vercel preview URL |
| **Decisions** | What's your Vercel project name? Do you need to wait for build completion? |

### 4.2 Conditional Skills (depends on your stack)

#### `migrate` — Database migration workflow (if using Supabase/Postgres)

| Field | Value |
|-------|-------|
| **Trigger** | `/migrate` |
| **What it does** | Create migration file, enforce idempotent patterns, lint, test locally |
| **Decisions** | What are your idempotent rules? (See the reference `patterns.md`) |

#### `g-deploy` — Deployment verification (if complex deploy pipeline)

| Field | Value |
|-------|-------|
| **Trigger** | `/g-deploy` or `/g-deploy --check` |
| **What it does** | Verify deployments succeeded, run smoke tests, check DB migrations applied |
| **Decisions** | What are your smoke test URLs? Health check endpoint? DB verification queries? |

#### `component` — Scaffold shared component (if monorepo with shared UI)

| Field | Value |
|-------|-------|
| **Trigger** | `/component` |
| **What it does** | Create component dir with .tsx, .test.tsx, index.ts |
| **Decisions** | Where do shared components live? What's the naming convention? |

#### `reset-user` — Test data reset (if auth/user system)

| Field | Value |
|-------|-------|
| **Trigger** | `/reset-user` |
| **What it does** | Remove a user and their data for testing. DEV ONLY. |
| **Decisions** | What tables need to be cleaned? What order (FK constraints)? |

### 4.3 Optional Skills (nice to have)

| Skill | When to build | What it does |
|-------|--------------|--------------|
| `seed-data` | When you need repeatable test data | Load fixtures into dev DB |
| `export-schema` | When sharing schema with others | Generate ERD or TypeScript types from DB |
| `onboard-user` | When testing user flows | Create a test user with specific roles/permissions |
| `backup-db` | When data is precious | Snapshot current state before risky operations |

---

## Step 5: Configure CLAUDE.md

Your `CLAUDE.md` is the single document VBW agents and Claude Code sessions read to understand your project. Build it up as the project grows.

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

Before writing any feature code, verify the full pipeline works end-to-end:

```
[ ] Create a test issue in Linear (e.g., "Add health check endpoint")
[ ] Run /light-spec on it
[ ] Run /launch on it (or manually move to Building)
[ ] Implement the feature
[ ] Run the pre-deploy gate (types + lint + test)
[ ] Push and verify preview deployment
[ ] Create PR with /g-promote-dev
[ ] Merge and verify dev deployment
[ ] Promote to production (if ready)
[ ] Move issue to Done in Linear
[ ] Run /end-session to log the work
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
- [ ] Initial initiatives (stages) created
- [ ] Initial projects (feature clusters) created
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

### Skills
- [ ] g-promote-dev created
- [ ] g-promote-main created
- [ ] g-promote-beta created (if using beta environment)
- [ ] g-test-vercel created
- [ ] migrate created (if using Supabase)
- [ ] component created (if using monorepo shared UI)
- [ ] Pipeline validated end-to-end (test issue through full cycle)

---

## Quick Start (TL;DR)

1. **Define:** Write down what you're building and for whom
2. **Decide:** Pick your stack (framework, DB, deployment, auth)
3. **Create:** GitHub repo + Vercel project + Supabase project + Linear workspace
4. **Sync:** `./scripts/sync-method.sh` to pull in portable skills and SOPs
5. **Configure:** Fill in `method.config.md`, write `CLAUDE.md`, create `.claude/rules/`
6. **Build skills:** `g-promote-dev`, `g-promote-main`, `g-test-vercel`, `migrate`
7. **Validate:** Push a test issue through the full pipeline
8. **Ship:** Start building features
