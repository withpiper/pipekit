# Pipekit

**A structured way to ship software with AI — from idea to production, with a quality gate at every stage.**

**v5.4.1** — Last updated: 2026-10-31. Release history and per-version notes: [CHANGELOG.md](CHANGELOG.md). MIT licensed.

---

## What is Pipekit?

Pipekit takes a project from a raw idea to production through a fixed sequence of stages, each with a gate the work must pass before it moves on. You run it inside [Claude Code](https://claude.ai/code); it tracks every piece of work in [Linear](https://linear.app/).

**Pipekit is the structure *around* an executor, not the executor itself.** It does not write your code directly. The build step runs on Claude Code's own Workflow primitive, and Pipekit owns everything around it: how a feature gets specified, how the work is reviewed, where a human signs off, and how the change reaches production.

| Stage | What Pipekit does |
|-------|-------------------|
| **Foundation** | Turns an idea into a roadmap (concept, definition, strategy, setup) |
| **Before a feature** | Spec, independent agent review, human sign-off |
| **During** | Plans and builds the feature, then runs a pre-deploy gate |
| **After** | UAT, ship, promote through environments, sync the docs |
| **Throughout** | Keeps Linear current so you always know what is next |

The one rule above all others: **no stage may introduce guesswork into the next stage.** A spec must be complete enough to plan from; a plan complete enough to build from. When a stage finds ambiguity, the work goes *backward* to be clarified, not forward into a guess.

Pipekit bets on enforcement, not memory. A more capable model produces more *plausible* mistakes, and one agent doing everything in a long session has no independent check on its own judgment. The gates exist for exactly that: a spec a separate reviewer must pass, a plan an independent agent stress-tests, a verify step that reads the acceptance criteria rather than the executor's narration, an antagonistic review that approaches the diff cold. A bigger context window changes how much an agent can hold; it does not change whether an agent can independently judge work it helped produce.

## Requirements

| Need | Why | Notes |
|------|-----|-------|
| **Claude Code** | Runs the skills and the executor | [claude.ai/code](https://claude.ai/code). Use a real terminal (iTerm, VS Code, tmux) — the desktop app is not built for shell workflows. |
| **A GitHub repo** + `gh` CLI, authenticated | `pk ship` / `pk ready` / `pk done` / `pk promote` work through pull requests | `gh auth login` |
| **A Linear workspace** + personal API key | The board is the source of truth for "what's next" | Settings → Security & access → Personal API keys. Free plan is fine. |
| `git`, `jq`, `curl`, `rsync`, `bash` 3.2+ | `bin/pk` and the sync script | macOS ships all of them; on Linux install `jq`. `pk` exits with a clear message if `jq` or `gh` is missing. |

Optional, used only if present: the Supabase CLI (migration checks in `pk done`), 1Password `op` + `direnv` (secrets into worktrees), Semgrep and a `CLAUDE_CODE_OAUTH_TOKEN` repo secret (the CI review templates in `templates/ci/`), [cmux](https://github.com/manaflow-ai/cmux) (orchestrating worker sessions). None of these is needed for the daily loop.

## Install — the first fifteen minutes

**1. Pull Pipekit into your repo.** No local clone needed; the script pulls from GitHub.

```bash
cd ~/Projects/my-project            # an existing repo, or `git init` a new one
mkdir -p scripts
curl -fsSL https://raw.githubusercontent.com/withpiper/pipekit/main/scripts/sync-method.sh -o scripts/sync-method.sh
chmod +x scripts/sync-method.sh
./scripts/sync-method.sh            # --dry-run to preview; --help for flags
```

This writes `.claude/skills/` (the skills), `.claude/rules/pipekit-*.md`, `.claude/workflows/`, `pipekit/` (SOPs, templates, the methodology docs), `bin/pk`, `engineering/RUNBOOK.md`, and a `method.config.md` from the template.

**2. Put `pk` on your PATH.**

```bash
./bin/pk install                    # symlinks pk into /usr/local/bin or ~/.local/bin
```

**3. Give `pk` your Linear key.** Export it, or put it in `.env.local` (gitignored):

```bash
export LINEAR_API_KEY=lin_api_…     # the variable name is configurable in method.config.md
```

**4. Create the workflow states Pipekit moves issues through.** In Linear → Settings → your team → Workflow, add these states (names matter; the full list with meanings is in [`sop/Linear_SOP.md` § Workflow States](sop/Linear_SOP.md#workflow-states)):

- Required: **Needs Spec**, **Specced**, **Approved**, **In Progress**, **UAT**, **Done**, and one **In \<Env\>** per non-production environment (e.g. **In Dev** for a `dev → main` project).
- Recommended: **Triage** (enable it in team settings), **Ideas**, **Future Initiatives**, **On Deck**, **Building**.

A stock Linear team has none of the required states; `pk doctor` lists the ones still missing.

**5. Fill in `method.config.md`, then check the setup.**

```bash
pk init                             # detects your stack and walks you through the config
pk doctor                           # deps, key, team, workflow states, the binary in use
```

`pk doctor` is green when the Linear team resolves, the states exist, and the `pk` you are running is this project's `bin/pk`.

**6. Bootstrap the project.** Inside Claude Code:

```
/startup
```

It captures the idea, writes the definition and strategy docs, chooses a stack, authors the roadmap into Linear as `i1.`, `i2.` initiatives, and queues the first batch of issues. Each step checks whether it is already done, so you can stop and resume. Adopting Pipekit on an existing codebase: `/startup --mode=brownfield` skips the concept and definition steps. Already have docs? `/concept --docs docs/ proposal/` reads them and asks only about the gaps.

From here the daily loop below takes over. `pk next` tells you what to do at any moment.

## Key terms

| Term | What it means |
|------|---------------|
| **Executor** | The thing that writes code: **native-on-Workflow**, Claude Code's first-party orchestration primitive. `/work` plans a feature, then runs it on the executor — a task list, one atomic commit per task, each verified before it integrates. |
| **The gates** | Independent checks the work must pass — `/verify`, `/security-gate`, `/prod-ready`, antagonistic PR review. This is where correctness is enforced, *not* inside the executor. |
| **The roadmap (in Linear)** | "What's next" is read live from Linear's own hierarchy. **Initiatives** named `i1.`, `i2.` are the ordered chunks of the roadmap; **Projects** under them (`I1.P1.`, `I1.P2.`) are ordered lanes of three to eight **Issues**. The number prefix sets the order. |
| **Issue** | One Linear issue moving through the pipeline — the unit `/work` builds. (Older docs say *WIT*, "work item"; same thing.) |
| **Worktree** | `pk branch <ID>` creates an isolated git worktree per issue, so work on one feature never disturbs another. |
| **Stage 0** | The one-time project bootstrap (idea → roadmap). |
| **The daily loop** | The per-issue cycle: spec → branch → work → verify → ship → promote. |

## The pipeline

### Stage 0: Foundation (run once)

A *contract* — the artifacts the dev pipeline requires — not a rigid script. Three entry modes satisfy it:

| Mode | Who it's for | Stage 0 steps run |
|------|--------------|-------------------|
| **Greenfield** | A fresh idea, no code yet | `/concept` → `/define` → `/strategy-create` → `/startup` → `/roadmap-create` → `/phase-plan` |
| **Brownfield** | Adopting Pipekit on an existing codebase | `/startup --mode=brownfield` → `/roadmap-create` → `/phase-plan` |
| **Inherited** | A new contributor on a Pipekit project | None — verify the foundation, start the daily loop |

### The daily loop (run per issue)

| # | Step | Command | What happens |
|---|------|---------|--------------|
| 1 | Spec | `/light-spec` | Write the feature spec (codebase-aware, an AI-to-AI contract); an independent agent reviews it, `/light-spec-revise` applies the feedback |
| 2 | Human review | Linear UI | You sign off on the spec → **Approved** |
| 3 | Find next | `pk next` | Reads the current initiative live from Linear and surfaces the highest-priority startable issue (skips ones with unfinished blockers) |
| 4 | Branch | `pk branch <ID>` | Worktree + branch; issue → In Progress |
| 5 | **Work** | `/work <ID>` | Plans the issue inline, then builds it on the executor — task list, atomic commit per task, verify-before-integrate |
| 6 | **Verify** | `/verify` | Pre-deploy gate: types + lint + tests, checked against the spec's acceptance criteria; writes the evidence `pk ship` requires |
| 6a | Security gate | `/security-gate` | Classifies the diff into sensitive categories (auth, payments, user input, external APIs, file storage, PII) and runs the matching checklist. A hard gate on projects with a categories file: `pk ship` refuses without its PASS sentinel. |
| 7 | Ship | `pk ship [--review]` | Push, open a **Draft** PR, issue → UAT. `--review` adds an antagonistic review. |
| 7a | Flip to Ready | `pk ready` | Draft → Ready; fires whichever reviewer workflows the repo installed. Refuses if source changed after the `/verify` that vouches for the branch. |
| 8 | UAT | Browser | You test the feature — on the PR preview before merge, on the first environment after |
| 9 | Done | `pk done <ID> [--merge]` | Confirms the merge (or merges with `--merge`), cleans up the worktree, posts commits to Linear, issue → In \<FirstEnv\> (Done on a single-tier project) |
| 9a | Prod-ready | `/prod-ready` | Once per feature, before the final promote: monitoring, secrets, rate limits, backups, flags. A hard gate on projects with a checks file. |
| 10 | Promote | `pk promote <env>` | Opens the promote PR to the next environment; `pk promote <env> --finish` advances the issues once it merges. Script-deploy projects use `pk deploy [<env>]` instead. |
| 11 | Session log | `/pk-exit` | Narrative log of the session. Run it manually as the last command of *every* session — never auto-chained. |
| 12 | Strategy sync | `/strategy-sync` | Update the strategy docs to match what shipped |

> **In a worktree?** `pk done` runs from the parent repo and deletes the worktree. Run `/pk-exit` inside the worktree session first, then leave it and run `pk done` from the parent.

### Seeing where you stand

| Command | Altitude | Answers |
|---------|----------|---------|
| `pk next` | One action | The single best next step in the current initiative — priority- and dependency-aware |
| `pk status` | The board | Every in-flight / Approved / Needs-Spec issue, grouped by project |
| `pk portfolio` | The whole map | Every initiative, the runway of actionable work across the active ones, and what has gone quiet |
| `pk doctor` | The setup | Dependencies, key, team, workflow states, which `pk` binary is running |

### Fast lanes

| Command | What it does |
|---------|--------------|
| `/pk-express "<idea>"` | Idea-to-Draft-PR autopilot for simple issues: brainstorm → spec → branch → work → verify → ship, pausing only at attention gates |
| `/pk-bug` | Bug pipeline: reproduce, failing test first, fix, ship, postmortem |
| `/pr-fix` | PR review with severity-by-confidence triage and interactive fixes |
| `/pr-security-review` | Antagonistic security review for migrations, RLS, auth and other privileged surfaces |
| `/tpm` | A weekly planning session over the board — what must ship, what waits, written to `engineering/WEEKLY_PLAN.md` (optional; `Plan path: none` in the config turns it off) |

## What is portable, and what assumes a stack

The daily loop (`pk next` → `pk done`, `/work`, `/verify`, the spec skills) needs only Claude Code, Linear and GitHub. Some of the rest was built on a Next.js + Supabase + Vercel stack and still shows it:

| Surface | Assumes |
|---------|---------|
| `/startup`'s stack step, `STARTUP.md` | Next.js, Supabase, Vercel, 1Password — adapt or skip |
| `.claude/rules/pipekit-migrations.md`, `check-migration-drift.sh` | A versioned migration system (Supabase/Postgres-shaped). `Skip rules: pipekit-migrations` in `method.config.md` drops the rule. |
| `/security-gate`, `/prod-ready`, `/repo-security-review`, `/financial-review` | Portable frameworks; the shipped example checklists lean on Supabase RLS and Vercel |
| `templates/ci/` | GitHub Actions, Semgrep, a `CLAUDE_CODE_OAUTH_TOKEN` secret |
| `.claude/rules/pipekit-cmux.md`, `sop/Cmux_Orchestration_SOP.md` | The cmux terminal. `Skip rules: pipekit-cmux` if you don't use it. |

## What syncs vs. what stays

**Synced from Pipekit** every time you run `sync-method.sh`: `.claude/skills/` (portable skills), `.claude/rules/pipekit-*.md`, `.claude/workflows/`, `.claude/agents/`, `pipekit/` (SOPs, templates, `method.md`, `GUIDE.md`, `STARTUP.md`), `bin/pk` + `bin/pk-init/`, and the *How we run* block of `engineering/RUNBOOK.md`.

**Yours, never overwritten:** `method.config.md`, `CLAUDE.md`, `.claude/rules/` (your own files), `.claude/skills/{project-specific}/`, `.claude/overrides/` (sync-safe customization of synced files — [method.md § Sync-Safe Overrides](method.md#sync-safe-overrides)), `concept-brief.md`, `project-definition.md`, `Strategy/`, the rest of `engineering/RUNBOOK.md`, and `engineering/WEEKLY_PLAN.md` once it exists.

Update with `/pipekit-update` from inside Claude Code, or `./scripts/sync-method.sh` from a terminal; restart Claude Code afterward to load the new skills. Pin a release with `./scripts/sync-method.sh vX.Y.Z` (any tag in `CHANGELOG.md`).

## Which doc to read

| You want to… | Read |
|--------------|------|
| Run the daily loop | [RUNBOOK.md](RUNBOOK.md) — the per-issue flow on one page, with the flowchart |
| Understand *why* it is shaped this way | [method.md](method.md) — the methodology: stages, principles, ownership |
| Look something up | [GUIDE.md](GUIDE.md) — the reference manual, every stage and skill |
| Bootstrap a project by hand instead of `/startup` | [STARTUP.md](STARTUP.md) |
| Do one specific thing correctly | [sop/](sop/) — Linear model, git and deployment, security gate, skills authoring, … |
| See what changed between versions | [CHANGELOG.md](CHANGELOG.md) |

## Versioning

Semver-ish: minor bumps for new capability, patch for fixes and docs. A tag is created automatically when a PR titled with a `vX.Y.Z` token merges to `main`.

## Origin and license

Extracted from a production finance platform, where the daily loop ran for the better part of a year before it was split out. MIT — see [LICENSE](LICENSE).
