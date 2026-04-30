# Pipekit

A structured AI-assisted software delivery system. Wraps [VBW](https://github.com/dnakov/claude-code-vbw) in a visibility and project management layer — from idea to production with quality gates at every stage.

## What This Is (and Isn't)

Pipekit **does not replace VBW**. VBW handles planning, execution, and QA. Pipekit adds structure around it:

| Layer | What Pipekit does | What VBW does |
|-------|-------------------|---------------|
| **Before** (steps 1-4) | Spec creation, agent review, human sign-off, gate checks | — |
| **During** (steps 5-8) | — | **Plan, execute, QA — all VBW** |
| **After** (steps 9-11) | UAT tracking, shipping, doc sync | — |
| **Around** | Linear integration for cross-issue visibility | Tracks one phase at a time |
| **Stage 0** | Project bootstrap (idea → roadmap) | Starts at "I have a task" |

VBW doesn't need the full project plan — it's designed for bounded scope. Pipekit makes sure the input going into VBW is clean and unambiguous, and tracks what comes out.

### Ownership split

To avoid drift between the two systems, the boundaries are explicit:

- **VBW owns the planning layer** — `.vbw-planning/ROADMAP.md`, `PLAN.md` files, and execution state. Pipekit reads these but does not overwrite them.
- **Pipekit owns the visibility layer** — Linear issues, `linear-map.json`, `PHASES.md`, `NEXT.md`, strategy docs, and `method.config.md`. VBW does not touch these.
- **The merge happens once**, at `/roadmap-create`. Strategy-derived requirements are added **into** VBW's phase structure; VBW's phases, goals, and success criteria are preserved.
- **Don't invoke VBW agents directly.** Use `/launch`, not `/vbw:lead` or `/vbw:dev`. `/launch` wraps VBW and keeps Linear, `PHASES.md`, and `NEXT.md` in sync. Direct VBW invocation bypasses the visibility layer.

Full ownership table and drift-risk mitigations in [method.md](method.md#vbw--pipekit-ownership-model).

## Core Principle

**No stage may introduce guesswork into the next stage.**

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

**Development Pipeline** (repeats per feature)

| # | Step | What happens |
|---|------|-------------|
| 1 | Light Spec | Spec the feature (codebase-aware, AI→AI contract) |
| 2 | Agent Review | Linear's agent reviews the spec |
| 3 | Human Review | You sign off in Linear |
| 4 | Launch | Gates checked, tier resolved (Quick/Standard/Heavy), complexity routed |
| 5 | **VBW Plan** | **VBW Lead generates PLAN.md from the spec** |
| 6 | **Plan Review** | **Plan validated for executability** |
| 7 | **VBW Execution** | **VBW Dev agents build it** |
| 8 | **VBW QA** | **VBW QA verifies against spec** |
| 9 | UAT | You test the built feature |
| 10 | Ship | Promote to production |
| 11 | Strategy Sync | Update docs to match what was built |

## Entry Modes

Pipekit projects enter the dev pipeline through one of three modes — pick the one that matches your situation before running `/startup`. Full description and skill routing in [method.md § Entry Modes](method.md#entry-modes).

| Mode | Who | Skills run | Skills skipped |
|---|---|---|---|
| **Greenfield** | Founder, fresh idea, no code yet | Full Stage 0 chain | None |
| **Brownfield** | Team adopting Pipekit on an existing codebase | `/startup --mode=brownfield`, `/vbw:init`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` |
| **Inherited** | New contributor joining a Pipekit project | None — verify foundation, jump to dev pipeline | All of Stage 0 |

`/startup` auto-detects the mode and confirms with you before proceeding. `/strategy-from-code` (auto-audit for brownfield) is deferred to v1.4.0; brownfield currently routes through `/strategy-create` with a manual-edit note.

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

**VBW** — the planning/execution engine that Pipekit wraps. Run these as two separate commands (don't paste them together):

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
- `method/` — SOPs, templates, methodology docs

**Stays in your project** (never overwritten):
- `concept-brief.md` — project concept
- `project-definition.md` — project definition
- `Strategy/` — project strategy docs (incl. Design Direction)
- `method.config.md` — project configuration (Linear IDs, environments, etc.)
- `NEXT.md` — always-current pointer to the next command (auto-regenerated by skills)
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

Tag releases when stable: `git tag v1.0`. Projects can pin to a version:

```bash
./scripts/sync-method.sh v1.0
```

## Origin

Extracted from the Piper production finance platform. See `method.md` for the full methodology and `GUIDE.md` for the complete instruction manual.
