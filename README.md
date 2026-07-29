# Pipekit

**A structured way to ship software with AI — from idea to production, with a quality gate at every stage.**

**v4.11.0** — Last updated: 2026-06-26. For release history and per-version notes, see [CHANGELOG.md](CHANGELOG.md).

---

## What is Pipekit?

Pipekit takes a project from a raw idea all the way to production through a fixed sequence of stages. Each stage has a gate the work must pass before it can move forward. You run the whole thing inside [Claude Code](https://claude.ai/code), and it uses [Linear](https://linear.app/) to track what is happening across every piece of work.

The thing to understand first: **Pipekit is the structure *around* an executor, not the executor itself.** It does not write your code directly. It runs the build step on Claude Code's built-in Workflow primitive, and it owns everything around that step — how a feature gets specified, how the work gets reviewed, where a human signs off, and how the change reaches production.

In short, Pipekit handles:

| Stage | What Pipekit does |
|-------|-------------------|
| **Foundation** | Turns an idea into a roadmap (concept, definition, strategy, setup) |
| **Before a feature** | Spec creation, independent agent review, human sign-off |
| **During** | Plans and builds the feature, then runs a pre-deploy gate |
| **After** | Tracks UAT, ships, promotes through environments, syncs docs |
| **Throughout** | Keeps Linear current so you always know what is next |

## Why it works this way

### One rule above all others

**No stage may introduce guesswork into the next stage.**

A spec must be complete enough to plan from. A plan must be complete enough to build from. When a stage finds ambiguity, the work goes *backward* to be clarified, not forward into a guess.

### Enforcement, not memory

Frontier models keep getting better at holding context. Larger windows and native memory mean an agent can carry a whole project in its head and remember what it did last session. That erodes the value of tools whose main job was persistence — tracking what to do next, storing state between runs, re-priming a forgetful model.

Pipekit does not bet on persistence. It bets on enforcement.

The failure mode that grows with model capability is not forgetting. It is confident-wrong output. A more capable model produces more *plausible* mistakes, and one agent doing everything in a single long session has no independent check on its own judgment. The gates exist for exactly that: a spec a separate reviewer must pass, a plan an independent agent stress-tests, a verify step that reads the goals rather than the executor's narration, an antagonistic review that approaches the diff cold.

A bigger context window changes how much an agent can hold. It does not change whether an agent can independently judge work it helped produce. That constraint is what Pipekit is built around, and it does not relax as models improve.

## Key terms

The rest of this README (and the deeper docs) lean on a handful of terms. Here they are in one place.

| Term | What it means |
|------|---------------|
| **Executor** | The thing that actually writes code. In Pipekit this is **native-on-Workflow** — Claude Code's first-party orchestration primitive. `/work` plans a feature, then runs it on the executor: a task list, one atomic commit per task, each verified before it integrates. |
| **The gates** | Independent checks the work must pass — `/verify`, `/security-gate`, `/prod-ready`, antagonistic PR review. This is where correctness is enforced, *not* inside the executor. |
| **Linear** | The issue tracker Pipekit uses, for two jobs: cross-issue visibility, and reading the roadmap (below). |
| **The roadmap (in Linear)** | Pipekit reads "what's next" live from Linear's own hierarchy — same words Linear uses. **Initiatives** named `i1.`, `i2.` are the ordered chunks of the roadmap; **Projects** under them (`I1.P1.`, `I1.P2.`) are the ordered sub-chunks that hold the **Issues**. The number prefix sets the order. `pk next` finds the current initiative; `pk portfolio` shows the whole map. |
| **WIT** | A work item — a single Linear issue moving through the pipeline. |
| **Worktree** | `pk branch <ID>` creates an isolated git worktree for each issue, so work on one feature never disturbs another. |
| **Stage 0** | The one-time project bootstrap (idea → roadmap). |
| **The daily loop** | The per-issue cycle you run over and over: spec → branch → work → verify → ship → promote. |

## The pipeline

### Stage 0: Foundation (run once)

Stage 0 is a *contract* — a set of artifacts the dev pipeline requires — not a rigid script. Three [entry modes](#entry-modes) satisfy it depending on where you start.

| Step | Command | Output |
|------|---------|--------|
| Concept | `/concept` | `concept-brief.md` |
| Define | `/define` | `project-definition.md` |
| Strategy | `/strategy-create` | `Strategy/` docs (including Design Direction) |
| Setup | `/startup` | Repo, database, deploy, Linear workspace |
| Roadmap | `/roadmap-create` | Linear `i{N}.` / `I{N}.P{N}.` hierarchy |
| Phase plan | `/phase-plan` | First Project's issues, queued in "Needs Spec" |

### The daily loop (run per issue)

| # | Step | Command | What happens |
|---|------|---------|--------------|
| 1 | Spec | `/light-spec` | Write the feature spec (codebase-aware, an AI-to-AI contract) |
| 2 | Agent review | `/light-spec-revise` | An independent agent reviews; surgical revisions applied |
| 3 | Human review | Linear UI | You sign off on the spec |
| 4 | Find next | `pk next` | Reads the current initiative live from Linear, groups issues by status, surfaces the highest-priority startable issue (skips ones with unfinished blockers) |
| 5 | Branch | `pk branch <ID>` | Creates a worktree + branch, moves the issue to In Progress |
| 6 | **Work** | `/work <ID>` | Plans the issue inline, then builds it on the executor — task list, atomic commit per task, verify-before-integrate |
| 7 | **Verify** | `/verify` | Pre-deploy gate: types + lint + tests, checked against the spec's acceptance criteria |
| 7a | Security gate | `/security-gate` | Classifies the diff into sensitive categories (auth, payments, user input, external APIs, file storage, PII); runs the matching checklist, or passes instantly if none match. *Advisory.* |
| 8 | Ship | `pk ship [--review]` | Push, open a **Draft** PR, move the issue to UAT. `--review` adds an antagonistic review. |
| 8a | Flip to Ready | `pk ready` | Flip the Draft PR to Ready; fires whichever reviewer workflows the repo installed (`templates/ci/` ships Semgrep + claude-review) |
| 9 | UAT | Linear / browser | You test the built feature — on the PR preview before merge, on the first deploy environment after |
| 10 | Done | `pk done <ID> [--merge]` | Confirms the merge (or merges with `--merge`), cleans up the worktree, posts commits to Linear, advances the issue's state |
| 10a | Prod-ready | `/prod-ready` | Once per feature, before the final promote: monitoring, no secrets in the bundle, rate limits, backups, flags, dashboard. *Advisory.* |
| 11 | Promote | `pk promote <env>` | Opens a promote PR to the next environment; `--finish` advances the issues once it merges |
| 11′ | Deploy | `pk deploy [<env>]` | For projects that ship by script (FTP/rsync/custom) instead of branch promotion |
| 12 | Session log | `/pk-exit` | Narrative log of the session. Run it manually as the last command of *every* session — it is per-session, not per-issue, and is never auto-chained from another skill. |
| 13 | Strategy sync | `/strategy-sync` | Update the strategy docs to match what actually shipped |

> **Working in a worktree?** `pk done` runs from the parent repo and deletes the worktree. So inside a worktree session, run `/pk-exit` first, then leave the worktree and run `pk done` from the parent.

### Seeing where you stand

Three commands answer "what now?" at three altitudes — all read live from Linear, nothing to maintain:

| Command | Altitude | Answers |
|---------|----------|---------|
| `pk next` | One action | The single best next step in your current initiative — priority- and dependency-aware. |
| `pk status` | The board | Every in-flight / Approved / Needs-Spec issue, grouped by Project. |
| `pk portfolio` | The whole map | Every `i{N}.` Initiative (active ones marked `← active`), then a **runway** of actionable work across all active Initiatives — grouped by `I{N}.P{N}.` Project, ordered priority-first, with a blocked item's blocker pulled up right above it, and a `⚠ Nd idle` flag on any sub-phase that's gone quiet. |

`pk portfolio` is the zoom-out. When your head is deep in the code, it's the one screen that shows which Initiatives are live, what's next in each, and what's gone cold — exactly the part of project-managing-yourself that slips when you're heads-down.

### Fast lanes over the loop

| Command | What it does |
|---------|--------------|
| `/pk-express <ID>` | Idea-to-Draft-PR autopilot for simple issues. Chains spec → branch → work → verify → ship in one hands-off pass, pausing only at attention gates. |
| `/pk-bug` | Bug pipeline with regression-test-first discipline: reproduce, write a failing test, fix, ship, postmortem. |
| `/pr-fix` | PR review with severity-by-confidence triage and interactive fixes. |
| `/pr-security-review` | Security-focused antagonistic review for migrations, RLS, auth, and other privileged surfaces. |

## Where correctness is enforced

The executor is not where Pipekit guarantees a change is right. **The gates are.** They run independent of the executor and approach the work without its assumptions:

- `/verify` proves the code is correct in isolation, against the spec's acceptance criteria.
- `/security-gate` and `/pr-security-review` catch sensitive-surface mistakes.
- `/prod-ready` proves production can absorb the change safely.
- Antagonistic PR review reads the diff cold.

This separation — a permissive executor wrapped in strict, independent gates — is the whole design. (Validated head-to-head on hard financial work; see `CHANGELOG.md`, v3.0.0-rc1.)

## Entry modes

Pick the mode that matches your situation before running `/startup`. It auto-detects and confirms with you. Full routing is in [method.md § Entry Modes](method.md#entry-modes).

| Mode | Who it's for | Stage 0 steps run | Steps skipped |
|------|--------------|-------------------|---------------|
| **Greenfield** | A fresh idea, no code yet | Full Stage 0 chain | None |
| **Brownfield** | A team adopting Pipekit on an existing codebase | `/startup --mode=brownfield`, `/roadmap-create`, `/phase-plan` | `/concept`, `/define` |
| **Inherited** | A new contributor joining a Pipekit project | None — verify the foundation, jump to the daily loop | All of Stage 0 |

## Getting started

> **Use a terminal.** Pipekit runs shell commands alongside Claude Code. Use a real terminal — iTerm, VS Code's integrated terminal, Cursor, tmux. The Claude desktop app is not built for shell workflows.

### 1. Install Claude Code

This is what runs everything. Install from [claude.ai/code](https://claude.ai/code).

### 2. Set up your project

Brand new:

```bash
mkdir ~/Projects/my-project
cd ~/Projects/my-project
git init
```

Existing folder: just `cd` into it.

### 3. Pull Pipekit into your project

```bash
# Fetch the sync script from GitHub
mkdir -p scripts
curl -fsSL https://raw.githubusercontent.com/withpiper/pipekit/main/scripts/sync-method.sh -o scripts/sync-method.sh
chmod +x scripts/sync-method.sh

# Run it — pulls skills, templates, and SOPs into your project
./scripts/sync-method.sh
```

No local clone needed; the script pulls directly from GitHub. It creates a `method.config.md` file where your project-specific settings go (Linear IDs, environments, and so on). You fill that in during setup.

### 4. Connect Linear

Linear is the only external dependency. The executor is built into Claude Code, the roadmap is authored straight into Linear, and the commit-format hook is installed by the sync script.

To connect Linear's first-party OAuth server, close Claude Code and run:

```bash
claude mcp add --transport http --scope user linear-server https://mcp.linear.app/mcp
```

Reopen Claude Code and run `/mcp` to finish authorization. No workspace yet? Create a free one at [linear.app](https://linear.app/) first.

> **A note on which Linear server to use.** Pipekit's interactive skills target [`@tacticlaunch/mcp-linear`](https://www.npmjs.com/package/@tacticlaunch/mcp-linear) (registered as `linear-server`). It exposes the initiative and relation tools the initiative surface relies on, which the first-party remote lacks. The OAuth remote above is quickest for basic issue work, but if `pk status` shows no Roadmap section on a project that *has* `i{N}.` initiatives, switch `linear-server` to the tacticlaunch server. Register your choice in the project's committed `.mcp.json` so it is visible inside worktrees. Details in [`sop/Linear_SOP.md`](sop/Linear_SOP.md#linear-mcp-server).

### 5. Run the startup orchestrator

```
/startup
```

This walks you through everything interactively — capturing your idea, distilling it into a definition, generating strategy docs, choosing a stack, configuring Linear, building a roadmap, and selecting your first batch of work. Each step checks whether it is already done, so you can stop and resume anytime.

Already have docs (proposals, research, notes)? Point the concept step at them:

```
/concept --docs docs/ proposal/
```

It reads everything and only asks about the gaps.

### Updating Pipekit

From inside Claude Code:

```
/pipekit-update
```

Or from your terminal:

```bash
./scripts/sync-method.sh
```

Either way pulls the latest skills, SOPs, and templates. It never touches your project-specific files. Restart Claude Code afterward to load the new skills.

## What syncs vs. what stays

**Synced from Pipekit** (refreshed every time you run `sync-method.sh`):

- `.claude/skills/` — the portable skills
- `pipekit/` — SOPs, templates, methodology docs

**Stays in your project** (never overwritten):

- `concept-brief.md`, `project-definition.md`, `Strategy/` — your project's foundation docs
- `method.config.md` — project configuration (Linear IDs, environments, gates)
- `.claude/rules/` — your project's coding conventions
- `.claude/skills/{project-specific}/` — skills tied to your stack
- `.claude/overrides/` — sync-safe customization of synced files (see [method.md § Sync-Safe Overrides](method.md#sync-safe-overrides))

## Documentation

| Doc | Read it for |
|-----|-------------|
| [GUIDE.md](GUIDE.md) | The complete instruction manual — start here |
| [method.md](method.md) | The full methodology: pipeline, principles, tooling |
| [RUNBOOK.md](RUNBOOK.md) | The per-issue daily loop, on one page |
| [STARTUP.md](STARTUP.md) | Project bootstrap reference |
| [sop/](sop/) | Standard operating procedures (code quality, Git, Linear, security, hooks) |
| [CHANGELOG.md](CHANGELOG.md) | Release history and per-version notes |

## Versioning

Tag releases when stable. Projects can pin to a specific version:

```bash
./scripts/sync-method.sh v4.9.0   # or any tag listed in CHANGELOG.md
```

Versioning is semver-ish — minor bumps for new capability, patch for fixes and docs. Tags are created automatically on merge to `main` when a PR title contains a `vX.Y.Z` token.

## Origin

Extracted from the Piper production finance platform. See [method.md](method.md) for the full methodology and [GUIDE.md](GUIDE.md) for the complete instruction manual.
