# Pipekit

**v3.0.0** — Last updated: 2026-06-10  *(Pipekit 3.0 final: native-on-Workflow is the default executor, VBW reframed as an optional backend. Carries the rc2 rewrite of the "wraps VBW" thesis + ownership split and the v2.8.x substrate)*

A structured AI-assisted software delivery system — from idea to production with quality gates at every stage. The default executor is **native-on-Workflow** (Claude Code's first-party orchestration primitive); [VBW](https://github.com/yidakee/vibe-better-with-claude-code-vbw) remains an optional backend.

## What This Is (and Isn't)

Pipekit is the **structure around an executor** — spec creation, independent review, human sign-off, quality gates, Linear visibility, and promotion. It is **not** itself a planner or code executor: it dispatches the build step to a configured backend and owns everything around it.

As of **3.0**, the default backend is **native-on-Workflow** — `/work` plans the issue inline (parallel codebase grounding), then executes on Claude Code's first-party Workflow primitive: a task DAG, an atomic commit per task, verify-before-integrate. [VBW](https://github.com/yidakee/vibe-better-with-claude-code-vbw) is now an **optional** backend, not a dependency — set `Backend: vbw` to dispatch the `vbw-dev` executor instead. Either way `/work` does the planning; the backend only changes who executes.

| Stage | What Pipekit handles |
|-------|----------------------|
| **Stage 0** | Project bootstrap — idea → roadmap |
| **Before** (steps 1–4) | Spec creation, agent review, human sign-off, gate checks |
| **During** (steps 5–8) | `/work` (plan inline + execute) and `/verify` (pre-deploy gate) |
| **After** (steps 9–13) | UAT tracking, shipping, promotion, doc sync |
| **Around** | Linear for cross-issue visibility (VBW tracks one phase at a time) |

The deep-analysis safety net is the **gate layer** — `/financial-review`, `/pr-security-review`, antagonistic PR review — which runs regardless of backend. The executor is not where correctness is enforced; the gates are. (Validated head-to-head on hard financial work: native matched VBW-the-full-system on first-pass correctness at a fraction of the wall-clock and tokens — see `CHANGELOG.md` v3.0.0-rc1.)

### Ownership split

To avoid drift between the two systems, the boundaries are explicit:

- **VBW owns the `.vbw-planning/` directory** — `ROADMAP.md` (the roadmap, written at Stage 0) plus the `PLAN.md`/execution-state files the `vbw` backend produces. The native backend writes its per-issue plan to `.pk-work/<ID>-PLAN.md` instead. Pipekit reads these but does not overwrite them.
- **Pipekit owns the visibility layer** — Linear issues, `linear-map.json`, `PHASES.md`, strategy docs, and `method.config.md`. VBW does not touch these. "What's next?" is read live from Linear via `pk next` (phase-aware as of v2.1.0); v2 retired the old `NEXT.md` mirror file.
- **The merge happens once**, at `/roadmap-create`. Strategy-derived requirements are added **into** VBW's phase structure; VBW's phases, goals, and success criteria are preserved.
- **Don't invoke VBW agents directly.** Use `/work`, not `/vbw:lead` or `/vbw:dev`. `/work` dispatches to the configured backend (`vbw` or `native` per `method.config.md`) and keeps Linear and the `pk *` state machine in sync. Direct VBW invocation bypasses the visibility layer.

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
| VBW Init | `/vbw:init` | `.vbw-planning/` scaffold |
| Roadmap | `/roadmap-create` | `ROADMAP.md` + Linear issues |
| Phase Plan | `/phase-plan` | First phase in "Needs Spec" |

**Development Pipeline — the v2 daily loop** (repeats per issue)

| # | Step | Command | What happens |
|---|------|---------|-------------|
| 1 | Light Spec | `/light-spec` | Spec the feature (codebase-aware, AI→AI contract) |
| 2 | Agent Review | `/light-spec-revise` | Linear's agent reviews; surgical revisions applied |
| 3 | Human Review | (Linear UI) | You sign off in Linear |
| 4 | Find next | `pk next` | Phase-aware: groups by status from Linear + `PHASES.md` |
| 5 | Branch | `pk branch <ID>` | Worktree + branch + Linear → In Progress |
| 6 | **Work** | **`/work <ID>`** | **Plan inline + execute. Default backend is `native` (Workflow primitive); `vbw` optional per `method.config.md`.** |
| 7 | **Verify** | **`/verify`** | **Pre-deploy gate (types + lint + test).** |
| 8 | Ship | `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` triggers antagonistic review. |
| 8a | Flip to Ready | `pk ready [<ID>]` | (v2.6.0+) Flip Draft → Ready; fires outside reviewers (Semgrep + claude-review per `templates/ci/`). |
| 9 | UAT | (Linear UI / browser) | You test the built feature — on the PR preview pre-merge, on the first deploy env post-merge. |
| 10 | Done | `pk done <ID> [--merge]` | Verify merged (or `--merge` runs `gh pr merge` first), cleanup worktree, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls integration + writes VBW SUMMARY + flips PLAN status. |
| 11a | Promote — open | `pk promote <env>` | **Phase 1** (v2.6.0+): opens promote PR. WITs stay in source state. 2-tier: no arg picks the only hop. `--confirmed` bypasses the UAT gate after env-UAT signoff. |
| 11b | Promote — finish | `pk promote <env> --finish` | **Phase 2** (v2.6.0+): after the promote PR merges, transitions WITs → `In <Env>` (intermediate) or → `Done` (final). |
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
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield`, `/vbw:init`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` |
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

### Step 4: Install VBW and connect Linear

Open Claude Code **in your project directory** and install the dependencies:

**VBW** — an optional execution backend. Pipekit's default executor is native-on-Workflow (built into Claude Code, nothing to install), but Stage 0's `/vbw:init` still uses VBW to scaffold the `.vbw-planning/` roadmap directory, and `Backend: vbw` stays available as a per-issue executor — so install it once during setup. Run these as two separate commands (don't paste them together):

```
/plugin marketplace add yidakee/vibe-better-with-claude-code-vbw
```

```
/plugin install vbw@vbw-marketplace
```

To update later: `/vbw:update`. See the [VBW repo](https://github.com/yidakee/vibe-better-with-claude-code-vbw) for details.

**Linear** — the issue tracker Pipekit uses for visibility. Close Claude Code, then run in your terminal:

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
- Initializes VBW (`/vbw:init`)
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
  VBW_COMMANDS.md                  # VBW command reference
  sop/                             # Standard operating procedures
    Code_Quality.md                #   Quality standards and pre-deploy gates
    Git_and_Deployment.md          #   Branch strategy, release flow, worktrees
    Linear_SOP.md                  #   Linear workspace model and workflow states
    Skills_SOP.md                  #   Skill inventory and enforcement model
    Hooks_SOP.md                   #   Claude Code hooks — per-machine install, not synced
    VBW_Help.md                    #   VBW planning engine reference
    Anthropic - Prompting best practices.md  #   Prompt engineering reference
    Session_Management_SOP.md     #   How to manage sessions, context, compaction
  templates/                       # Templates used by skills
    concept-brief.md               #   Project concept brief
    project-definition.md          #   Full project definition
    light_spec_template.md         #   Light spec structure
    linear_guidance.md             #   Linear agent configuration
    spec_review_skill.md           #   Spec review rubric
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
- `.vbw-planning/` — all project state (ROADMAP, PHASES, plans)

## Documentation

- **[GUIDE.md](GUIDE.md)** — Complete instruction manual (start here)
- **[method.md](method.md)** — The methodology: pipeline, principles, tooling
- **[STARTUP.md](STARTUP.md)** — Reference guide for project bootstrap
- **[RUNBOOK.md](RUNBOOK.md)** — Per-issue step-by-step (the practical loop you'll run most often)
- **[VBW_COMMANDS.md](VBW_COMMANDS.md)** — VBW command reference
- **[sop/](sop/)** — Standard operating procedures

## Versioning

Tag releases when stable. Projects can pin to a specific version:

```bash
./scripts/sync-method.sh v3.0.0-rc2   # or any tag listed in CHANGELOG.md
```

Versioning is semver-ish — minor bumps for new capability, patch for fixes/docs only. Tags are created automatically on merge to `main` via `.github/workflows/auto-tag-release.yml` when the PR title contains a `vX.Y.Z` token.

## Origin

Extracted from the Piper production finance platform. See `method.md` for the full methodology and `GUIDE.md` for the complete instruction manual.
