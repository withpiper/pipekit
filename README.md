# Pipekit

**v4.6.0** — Last updated: 2026-06-23  *(Pipekit 4.6: **`pk deploy [<env>]`** — a first-class deploy verb for script-deploy projects (FTP/rsync/custom uploader): resolves `<env>` to the configured `Deploy command` in `method.config.md` and runs it (bare/`prod` → `Deploy command`, `pk deploy dev` → `Deploy command dev`; args after `--` pass through), a thin delegate that leaves confirmation + safety to the script. Carries 4.5: **projects carry their initiative number in the phase surface** — a Linear project under `i1.` is now `I1.P2. label`, not bare `P2.`; `bin/pk` accepts both `I{N}.P{N}.` and legacy `P{N}.`, and `/roadmap-create` + `/phase-plan` author the new form. Carries 4.4: **`/security-gate`** — a feature-scoped security gate at the Building → UAT seam (after `/verify`, before `pk ship`) that classifies the feature diff into sensitive categories (auth, payments, user-input, external-APIs, file-storage, PII) and runs the matching checklist; none matched → instant PASS. Advisory. Carries 4.3: **`/prod-ready`** — a production-readiness gate beside `/verify`, run once per feature before the final `pk promote` (monitoring, secrets-in-bundle, rate limits, backups, flags, dashboard). Advisory. Carries 4.2: **VBW plugin decoupled** — no longer required; its one functional dependency, the advisory commit-format hook, is re-homed as a Pipekit-owned hook (`.claude/hooks/validate-commit.sh`, synced + registered by `sync-method.sh`). A legacy VBW planning layer (`.vbw-planning/` ROADMAP/PLAN/execution state) still exists for projects that used direct VBW; no Pipekit skill depends on it, and it is slated for a separate, later retirement. Carries 4.1: **Linear-native phase surface** — Initiatives named `i{N}.` (phases) → Projects named `I{N}.P{N}.` (sub-phases) → Issues, ordered by the name-prefix number; `PHASES.md`/`linear-map.json` are retired (read-only fallback). Carries 4.0: native-on-Workflow is the **sole** executor (the `vbw` backend and `--backend=` flag are removed; a stale `Backend: vbw` refuses with a migration message). Plus 3.x's ownership split + distribution-layer hardening and the v2.8.x substrate)*

A structured AI-assisted software delivery system — from idea to production with quality gates at every stage. The executor is **native-on-Workflow** (Claude Code's first-party orchestration primitive); the pluggable VBW execution backend was removed in v4.0.0, and as of v4.2.0 the [VBW](https://github.com/yidakee/vibe-better-with-claude-code-vbw) plugin is no longer required at all. A legacy VBW planning layer remains for projects that used direct VBW, slated for a separate retirement.

## What This Is (and Isn't)

Pipekit is the **structure around an executor** — spec creation, independent review, human sign-off, quality gates, Linear visibility, and promotion. It is **not** itself a planner or code executor: it runs the build step on the native-on-Workflow executor and owns everything around it.

As of **3.0**, the executor is **native-on-Workflow** — `/work` plans the issue inline (parallel codebase grounding), then executes on Claude Code's first-party Workflow primitive: a task DAG, an atomic commit per task, verify-before-integrate. As of **4.0**, it is the **sole** executor: the pluggable `vbw` backend was removed (deprecated in v3.2.0 after carrying 0/30 of recent production work). As of **4.1**, [VBW](https://github.com/yidakee/vibe-better-with-claude-code-vbw) is no longer part of Stage 0 either — `/roadmap-create` authors the roadmap directly into Linear as the native phase surface (`i{N}.` Initiatives → `I{N}.P{N}.` Projects → Issues). As of **4.2**, the VBW plugin is no longer required at all — its one functional dependency, the advisory commit-format hook, is re-homed as a Pipekit-owned hook (`.claude/hooks/validate-commit.sh`). A legacy VBW planning layer (`.vbw-planning/` ROADMAP/PLAN/execution state) still exists for projects that used direct VBW; no Pipekit skill depends on it, and it is slated for a separate, later retirement.

| Stage | What Pipekit handles |
|-------|----------------------|
| **Stage 0** | Project bootstrap — idea → roadmap |
| **Before** (steps 1–4) | Spec creation, agent review, human sign-off, gate checks |
| **During** (steps 5–8) | `/work` (plan inline + execute) and `/verify` (pre-deploy gate) |
| **After** (steps 9–13) | UAT tracking, shipping, promotion, doc sync |
| **Around** | Linear for cross-issue visibility (VBW tracks one phase at a time) |

The deep-analysis safety net is the **gate layer** — `/financial-review`, `/pr-security-review`, antagonistic PR review — which runs independent of the executor. The executor is not where correctness is enforced; the gates are. (Validated head-to-head on hard financial work: native matched VBW-the-full-system on first-pass correctness at a fraction of the wall-clock and tokens — see `CHANGELOG.md` v3.0.0-rc1.)

### Ownership split

To avoid drift between the two systems, the boundaries are explicit:

- **The legacy `.vbw-planning/` directory** holds `ROADMAP.md` plus the `PLAN.md` files produced in direct VBW planning use. No Pipekit skill depends on it; it survives only for projects that used direct VBW and is slated for separate retirement. `/work` (native) writes its per-issue plan to `.pk-work/<ID>-PLAN.md` instead.
- **Pipekit owns the visibility layer** — Linear issues, the **phase surface** (Linear Initiatives `i{N}.` → Projects `I{N}.P{N}.` → Issues), strategy docs, and `method.config.md`. "What's next?" is read live from Linear via `pk next` (derives the current phase from the initiative/project hierarchy); v2 retired the `NEXT.md` mirror, v4.1.0 retired `PHASES.md`/`linear-map.json`.
- **The roadmap is authored directly into Linear**, at `/roadmap-create` — the `i{N}.`/`I{N}.P{N}.` hierarchy *is* the roadmap. There is no merge into a VBW phase skeleton.
- **Don't invoke VBW agents directly.** Use `/work`, not `/vbw:lead` or `/vbw:dev`. `/work` executes on the native-on-Workflow backend (the sole executor as of v4.0.0) and keeps Linear and the `pk *` state machine in sync. Direct VBW invocation bypasses the visibility layer.

Full ownership table and drift-risk mitigations in [method.md](method.md#vbw--pipekit-ownership-model).

## Core Principle

**No stage may introduce guesswork into the next stage.**

## Why Enforcement, Not Memory

Frontier models keep getting better at holding context. Larger windows and native memory mean an agent can carry a whole project in its head and remember what it did last session. That erodes the value of tools whose main job was persistence: tracking what to do next, storing state between runs, re-priming a forgetful model.

Pipekit does not bet on persistence. It bets on enforcement.

The failure mode that grows with model capability is not forgetting. It is confident-wrong output. A more capable model produces more plausible mistakes, and one agent doing everything in a single long session has no independent check on its own judgment. The gates exist for exactly that: a spec a separate reviewer must pass, a plan an independent agent stress-tests, a verify step that reads the goals rather than the executor's narration, an antagonistic review that approaches the diff cold.

A bigger context window changes how much an agent can hold. It does not change whether an agent can independently judge work it helped produce. That constraint is what Pipekit is built around, and it does not relax as models improve. If anything, it matters more.

## The Pipeline

**Stage 0: Foundation** (a contract — see [Entry Modes](#entry-modes) for greenfield/brownfield/inherited routing)

| Step | Skill | Output |
|------|-------|--------|
| Concept | `/concept` | `concept-brief.md` |
| Define | `/define` | `project-definition.md` |
| Strategy | `/strategy-create` | `Strategy/` docs (incl. Design Direction) |
| Setup | `/startup` | Repo, DB, deploy, Linear workspace |
| Roadmap | `/roadmap-create` | Linear `i{N}.`/`I{N}.P{N}.` hierarchy (Initiatives → Projects → Issues) |
| Phase Plan | `/phase-plan` | First sub-phase's issues in "Needs Spec" |

**Development Pipeline — the v2 daily loop** (repeats per issue)

| # | Step | Command | What happens |
|---|------|---------|-------------|
| 1 | Light Spec | `/light-spec` | Spec the feature (codebase-aware, AI→AI contract) |
| 2 | Agent Review | `/light-spec-revise` | Linear's agent reviews; surgical revisions applied |
| 3 | Human Review | (Linear UI) | You sign off in Linear |
| 4 | Find next | `pk next` | Phase-aware: derives the current phase from the Linear-native surface (`i{N}.` → `I{N}.P{N}.`), groups issues by status |
| 5 | Branch | `pk branch <ID>` | Worktree + branch + Linear → In Progress |
| 6 | **Work** | **`/work <ID>`** | **Plan inline + execute on native-on-Workflow (task DAG + atomic commits, verify-before-integrate). Sole executor as of v4.0.0.** |
| 7 | **Verify** | **`/verify`** | **Pre-deploy gate (types + lint + test).** |
| 7a | Security gate | `/security-gate [<ID>]` | (v4.4.0) Classify the feature diff into sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII); a match runs that category's checklist, none matched → instant PASS. **Advisory** — doesn't block `pk ship`. |
| 8 | Ship | `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` triggers antagonistic review. |
| 8a | Flip to Ready | `pk ready [<ID>]` | (v2.6.0+) Flip Draft → Ready; fires outside reviewers (Semgrep + claude-review per `templates/ci/`). |
| 9 | UAT | (Linear UI / browser) | You test the built feature — on the PR preview pre-merge, on the first deploy env post-merge. |
| 10 | Done | `pk done <ID> [--merge]` | Verify merged (or `--merge` runs `gh pr merge` first), cleanup worktree, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls integration + writes VBW SUMMARY + flips PLAN status. |
| 10a | Prod-ready | `/prod-ready [<ID>]` | (v4.3.0) Once per feature, before the final `pk promote` (or the merge to `main` on 1-tier): six operational checks — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, flag on risky paths, dashboard chart. **Advisory** — doesn't block `pk promote`. |
| 11a | Promote — open | `pk promote <env>` | **Phase 1** (v2.6.0+): opens promote PR. WITs stay in source state. 2-tier: no arg picks the only hop. `--confirmed` bypasses the UAT gate after env-UAT signoff. |
| 11b | Promote — finish | `pk promote <env> --finish` | **Phase 2** (v2.6.0+): after the promote PR merges, transitions WITs → `In <Env>` (intermediate) or → `Done` (final). |
| 11′ | Deploy (script projects) | `pk deploy [<env>]` | (v4.6.0) The script-deploy analog of `pk promote`, for projects that ship by script not branch promotion. Runs the configured `Deploy command` for `<env>` (bare/`prod` → `Deploy command`; `pk deploy dev` → `Deploy command dev`; args after `--` pass through). Thin delegate — the script owns confirmation + safety. |
| 12 | Session log | `/pk-exit` | Narrative log to `Logs/Sessions/<date>_<HHMM>.md`. **Per-session, not per-issue** — run manually as the last command of every Claude Code session regardless of where the current issue stands. Never auto-chained from another skill. |
| 13 | Strategy Sync | `/strategy-sync` | Update docs to match what was built (post-ship) |

**Fast lanes over the loop:**

| Skill | What it does |
|-------|--------------|
| `/pk-express <ISSUE-ID>` | Idea-to-Draft-PR autopilot for simple WITs (Quick/Standard tier). Chains spec, branch, work, verify, and ship in one hands-off pass, pausing only at five attention gates. |
| `/pk-bug` | Bug pipeline with regression-test-first discipline: reproduce, write a failing test, fix, ship, postmortem. |
| `/pr-fix` | Pluggable-engine PR review (pr-review-toolkit specialists, or a dependency-free builtin fallback) with two-axis severity-by-confidence triage and interactive fixes. |
| `/pr-security-review` | Security-focused antagonistic review for migrations, RLS, SECURITY DEFINER, GRANT/REVOKE, and auth surfaces. |

## Entry Modes

Pipekit projects enter the dev pipeline through one of three modes — pick the one that matches your situation before running `/startup`. Full description and skill routing in [method.md § Entry Modes](method.md#entry-modes).

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` |
| **Inherited** | New contributor joining a Pipekit project | None — verify foundation, jump to dev pipeline | All of Stage 0 |

`/startup` auto-detects the mode and confirms with you before proceeding. `/strategy-from-code` (auto-audit for brownfield) is deferred — brownfield currently routes through `/strategy-create` with a manual-edit note. The skill was originally promised for v1.4.0 but hasn't shipped; track in the brainstorm/Linear backlog if you need it.

## Getting Started

> **Use a terminal.** Pipekit involves running shell commands alongside Claude Code. Use a terminal or terminal emulator — iTerm, VS Code's integrated terminal, Cursor, tmux, etc. The Claude desktop app isn't designed for shell workflows.

### Step 1: Install Claude Code

Anthropic's CLI tool — this is what runs everything. Install it from [claude.ai/code](https://claude.ai/code).

### Step 2: Set up your project

**Starting a brand new project:**

```bash
mkdir ~/Projects/my-project
cd ~/Projects/my-project
git init
```

**Already have a project folder:**

```bash
cd ~/Projects/my-project
```

### Step 3: Pull Pipekit into your project

```bash
# Fetch the sync script from GitHub
mkdir -p scripts
curl -fsSL https://raw.githubusercontent.com/withpiper/pipekit/main/scripts/sync-method.sh -o scripts/sync-method.sh
chmod +x scripts/sync-method.sh

# Run it — pulls skills, templates, and SOPs into your project
./scripts/sync-method.sh
```

No local clone of Pipekit needed — the sync script pulls directly from GitHub.

The sync script creates a `method.config.md` file in your project — this is where your project-specific settings go (Linear workspace IDs, environments, etc.). You'll fill this in during setup.

### Step 4: Connect Linear (and, optionally, VBW)

Open Claude Code **in your project directory** and install the dependencies:

**VBW (optional)** — As of **v4.2.0**, the VBW plugin is **not required** at all. Stage 0 authors the roadmap directly into Linear (`/roadmap-create` — no `/vbw:init` scaffold), the executor is native-on-Workflow (built into Claude Code, nothing to install), and VBW's one functional dependency — the advisory commit-format hook — is now a Pipekit-owned hook installed by `sync-method.sh`. Install the VBW plugin only if you want its optional direct-use planning layer (`/vbw:*` agents, `.vbw-planning/` PLAN/SUMMARY artifacts) — a legacy layer slated for a separate retirement. If you do, run these as two separate commands (don't paste them together):

```
/plugin marketplace add yidakee/vibe-better-with-claude-code-vbw
```

```
/plugin install vbw@vbw-marketplace
```

To update later: `/vbw:update`. See the [VBW repo](https://github.com/yidakee/vibe-better-with-claude-code-vbw) for details.

**Linear** — the issue tracker Pipekit uses for visibility **and the phase surface** (Initiatives `i{N}.` → Projects `I{N}.P{N}.`).

> **Which Linear MCP server to use.** Pipekit's interactive skills target **`@tacticlaunch/mcp-linear`** (registered as `linear-server`, camelCase `linear_*` tools) — it exposes the initiative + relation tools the native phase surface and `/roadmap-create` rely on, which the first-party `mcp.linear.app` remote lacks. Register your chosen server as `linear-server` in the project's committed `.mcp.json` (so it's visible inside `pk branch` worktrees). The first-party OAuth remote below is the quickest to connect for basic issue work, but if `pk status` shows no Roadmap section on a project that has `i{N}.` initiatives, you're on the leaner remote — switch `linear-server` to `@tacticlaunch/mcp-linear`. Full tool-name mapping and the snake_case-remote caveat are in [`sop/Linear_SOP.md`](sop/Linear_SOP.md#linear-mcp-server). (`bin/pk`'s daily loop hits the Linear REST API directly via `LINEAR_API_KEY` and is unaffected by which MCP you pick.)

To connect the first-party OAuth remote, close Claude Code, then run in your terminal:

```bash
claude mcp add --transport http --scope user linear-server https://mcp.linear.app/mcp
```

Reopen Claude Code and run `/mcp` to complete the OAuth authorization flow. If you don't have a Linear workspace yet, create a free one at [linear.app](https://linear.app/) first.

Linear's MCP server is remotely hosted — no API keys or local servers needed. OAuth handles auth automatically.

### Step 5: Run the startup orchestrator

In Claude Code, type:

```
/startup
```

This walks you through everything interactively:
- Captures your project idea (`/concept`)
- Distills it into a structured definition (`/define`)
- Generates strategy docs (`/strategy-create`)
- Helps you choose a tech stack and set up infrastructure
- Configures your Linear workspace (team, workflow states, labels, state IDs)
- Creates a roadmap and populates Linear (`/roadmap-create`)
- Selects your first batch of work (`/phase-plan`)

Each step checks if it's already done, so you can stop and resume anytime.

**If you already have docs** (proposals, research, notes), point the concept step at them:

```
/concept --docs docs/ proposal/
```

It reads everything and only asks about gaps — you don't have to re-explain what's already written.

### Updating Pipekit

From inside Claude Code, run:

```
/pipekit-update
```

Or from your terminal:

```bash
cd ~/Projects/my-project
./scripts/sync-method.sh
```

Either way, this pulls the latest skills, SOPs, and templates from GitHub. It never touches your project-specific files (strategy docs, config, plans, etc.). Restart Claude Code after updating to load the new skills.

## What's Included

```
pipekit/
  GUIDE.md                         # Complete instruction manual (start here)
  method.md                        # The methodology — pipeline, principles, tooling
  method.config.template.md        # Project config template (copied per project)
  STARTUP.md                       # Reference guide for project bootstrap
  RUNBOOK.md                       # Per-issue step-by-step (the practical loop)
  sop/                             # Standard operating procedures
    Code_Quality.md                #   Quality standards and pre-deploy gates
    Database_SOP.md                #   Migration discipline, frozen-file invariant
    Git_and_Deployment.md          #   Branch strategy, release flow, worktrees
    Linear_SOP.md                  #   Linear workspace model and workflow states
    Skills_SOP.md                  #   Skill inventory and enforcement model
    Hooks_SOP.md                   #   Claude Code hooks — per-machine install, not synced
    Production_Readiness_SOP.md    #   /prod-ready gate — operational preconditions
    Security_Gate_SOP.md           #   /security-gate — feature-scoped security gate
    Anthropic - Prompting best practices.md  #   Prompt engineering reference
    Session_Management_SOP.md     #   How to manage sessions, context, compaction
  templates/                       # Templates used by skills
    CLAUDE.md.template             #   Project CLAUDE.md scaffold (synced to consumers)
    concept-brief.md               #   Project concept brief
    project-definition.md          #   Full project definition
    light_spec_template.md         #   Light spec structure
    linear_guidance.md             #   Linear agent configuration
    spec_review_skill.md           #   Spec review rubric
    overrides-manifest.template.md #   Sync-safe override manifest scaffold
    financial-review-checks.template.md  #   /financial-review project checks scaffold
    prod-readiness-checks.template.md    #   /prod-ready project checks scaffold
    security-categories.template.md      #   /security-gate category signals scaffold
    tier-quick.md / tier-standard.md / tier-heavy.md  #   Per-tier gate templates
    strategy/                      #   Strategy doc templates
      conceptual-overview.md
      technical-architecture.md
      design-direction.md          #     Visual style + inspiration for build agents
      permissions.md
      data-model.md
      workflow-examples.md
      ux-reference.md
    rules/                         #   Portable rule templates for .claude/rules/
      README.md                    #     Hub-and-spoke model explanation
      pipekit-discipline.md        #     Red Flags, Ad-hoc Plan Gate, scope hygiene
      pipekit-tooling.md           #     Verify Library API, package manager, pre-deploy gate
      pipekit-security.md          #     Secrets, boundary validation, OWASP, explicit auth
      pipekit-migrations.md        #     Frozen-file invariant, hardening discipline
      pipekit-cmux.md              #     cmux pane/surface discipline
    hooks/                         #   Pipekit-owned hooks (synced + registered)
      validate-commit.sh           #     Advisory commit-format hook (re-homed from VBW)
    ci/                            #   CI workflow templates (Semgrep, claude-review, Linear)
  skills/                          # Portable Claude Code skills
  scripts/
    sync-method.sh                 # Pull method into a consuming project
    drift-check.sh                 # Detect stale references in documentation
```

## What Gets Synced vs. What Stays

**Synced from Pipekit** (updated when you re-run `sync-method.sh`):
- `.claude/skills/` — portable skills
- `pipekit/` — SOPs, templates, methodology docs

**Stays in your project** (never overwritten):
- `concept-brief.md` — project concept
- `project-definition.md` — project definition
- `Strategy/` — project strategy docs (incl. Design Direction)
- `method.config.md` — project configuration (Linear IDs, environments, etc.)
- `notepad.md` — gitignored personal scratch space (seeded by `pk init`); v2 retired the `NEXT.md` mirror — `pk next` reads "what's next?" live from Linear
- `{folder-name}-startup.md` — startup tracker (created by `/startup`)
- `.claude/rules/` — project coding conventions
- `.claude/skills/{project-specific}/` — skills tied to your stack
- `.claude/overrides/` — sync-safe customization of synced skills, SOPs, and method.md (see [method.md § Sync-Safe Overrides](method.md#sync-safe-overrides))
- `.vbw-planning/` — legacy VBW planning state (ROADMAP, plans), for projects that used direct VBW; slated for separate retirement

## Documentation

- **[GUIDE.md](GUIDE.md)** — Complete instruction manual (start here)
- **[method.md](method.md)** — The methodology: pipeline, principles, tooling
- **[STARTUP.md](STARTUP.md)** — Reference guide for project bootstrap
- **[RUNBOOK.md](RUNBOOK.md)** — Per-issue step-by-step (the practical loop you'll run most often)
- **[sop/](sop/)** — Standard operating procedures

## Versioning

Tag releases when stable. Projects can pin to a specific version:

```bash
./scripts/sync-method.sh v4.6.0   # or any tag listed in CHANGELOG.md
```

Versioning is semver-ish — minor bumps for new capability, patch for fixes/docs only. Tags are created automatically on merge to `main` via `.github/workflows/auto-tag-release.yml` when the PR title contains a `vX.Y.Z` token.

## Origin

Extracted from the Piper production finance platform. See `method.md` for the full methodology and `GUIDE.md` for the complete instruction manual.
