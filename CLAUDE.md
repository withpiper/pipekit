# CLAUDE.md

**v3.0.0-rc2** — Last updated: 2026-06-09  *(**Pipekit 3.0 — native-on-Workflow is the default executor; VBW is now an optional backend.** rc2 adds bug-workflow + review-layer fixes (no daily-flow change): `/pk-bug` branches early — Phases 3+ run in the worktree, not the shared integration checkout, so it no longer blocks concurrent agents; and the Linear review layer (`templates/linear_guidance.md` + `templates/spec_review_skill.md`, v5.2) is backend-agnostic — it reviews for "the planner" upstream of backend dispatch, not for VBW specifically. `/work` defaults `Backend:` to `native` when unset. Reframes the backend dispatch + fixes the doc-drift that called `Backend: vbw` the "full vbw-lead/dev/qa pipeline" — it only ever spawns `vbw-dev`; planning is `/work`'s inline step regardless of backend. Justified by the round-2 head-to-head (POC-48, tier:heavy financial parity): native matched-or-beat VBW-the-full-system on first-pass correctness at ~1/5 wall-clock and a fraction of the tokens — see `experiments/poc-48-roundtwo/`. The deep-analysis safety net is the gate layer (`/financial-review`, `/pr-security-review`), which both backends run. Carries v2.8.0 (rc1–rc3): `/financial-review` + checks-file split & config keys; `/security-review` finding-stage coverage + adversarial verification pass; CI reviewer-trigger hardening (`synchronize` self-heal + workflow-validation 401 warning); `/pk-bug` checkout guard; and v2.7.x: enforcement-substrate hardening, `/pk-express`, `/pr-fix` pluggable engine, merge-driven Linear transition)*

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is **Pipekit** — a portable, structured AI-assisted software delivery system. It is NOT a software project itself. It contains methodology docs, SOPs, templates, and Claude Code skills that get synced into consuming projects via `scripts/sync-method.sh`.

Origin: extracted from the Piper production finance platform.

## Core Principle

**No stage may introduce guesswork into the next stage.** Specs must be planning-safe. Plans must be execution-safe. When ambiguity is detected, work goes backward, not forward.

## Pipeline

```
Stage 0: Foundation (a contract — see Entry Modes)
  /concept → /define → /strategy-create → /startup → /vbw:init → /roadmap-create → /phase-plan

Stages 1-5: Development — the v2 daily loop (repeats per issue)
  pk next → pk branch → /work → /verify → pk ship (Draft) → pk ready → [PR review + preview UAT] → pk done [--merge] → [dev UAT] → pk promote <env> → (PR merges) → pk promote <env> --finish → /pk-exit
```

Stage 0 is a **contract** (a set of artifacts the dev pipeline requires), not a script. Three entry modes satisfy the contract: greenfield (full chain), brownfield (skip /concept and /define), inherited (verify and proceed). `/startup` auto-detects mode and confirms with the user. The v2 daily loop replaces v1's `/branch → /launch → /verify → /launch --close` chain — see `RUNBOOK.md` for the one-page flowchart. Full Entry Modes table in `method.md`.

## Repo Structure

- `method.md` — The full methodology (Stage 0 + 12-step pipeline, principles, tooling)
- `method.config.template.md` — Template for project-specific config (Linear IDs, strategy docs, environments, pre-deploy gate)
- `STARTUP.md` — Reference guide for project bootstrap (use `/startup` for the interactive flow)
- `RUNBOOK.md` — Per-issue practical walkthrough (the loop you run most often)
- `sop/` — Standard operating procedures (Code Quality, Git + Deployment, Hooks, Linear, Session Management, Skills, VBW)
- `templates/` — Concept brief, project definition, strategy doc, and spec templates
- `templates/strategy/` — Templates for each strategy doc type (conceptual overview, technical architecture, etc.)
- `skills/` — Portable Claude Code skills (synced into consuming projects as `.claude/skills/`)
- `scripts/sync-method.sh` — The sync script that pulls this repo's content into consuming projects

## How Consuming Projects Work

Projects pull from this repo using `sync-method.sh`. The sync copies `skills/`, `sop/`, `templates/`, and `method.md` into the project. It never touches project-specific files (`method.config.md`, `.claude/rules/`, `.vbw-planning/`, project-specific skills).

**Sync-safe overrides:** projects can override synced skills/SOPs/method.md without forking by writing to `.claude/overrides/`. The sync script applies overrides after the upstream copy and surfaces drift warnings when upstream changes a file you override. See `method.md` § Sync-Safe Overrides.

## VBW / Pipekit Ownership

Pipekit wraps VBW — it does not replace VBW's planning layer. The boundary is explicit:

- **VBW owns** `.vbw-planning/ROADMAP.md`, `PLAN.md` files, and execution state.
- **Pipekit owns** Linear issues, `linear-map.json`, `PHASES.md`, strategy docs, and `method.config.md`. "What's next?" is read live from Linear via `pk next` (phase-aware as of v2.1.0); v2 retired the `NEXT.md` mirror file.
- **The two merge once**, at `/roadmap-create` — Pipekit adds strategy-derived requirements into VBW's phase structure without overwriting VBW's phases, goals, or success criteria.
- **Don't invoke VBW agents directly in Pipekit projects.** Use `/work`, not `/vbw:lead` or `/vbw:dev`. `/work` dispatches to the configured backend (`vbw` or `native` per `method.config.md`) and keeps Linear, `PHASES.md`, and the `pk *` state in sync. Direct VBW invocation bypasses Pipekit's visibility layer and causes drift.

Full ownership model in `method.md` (§ VBW / Pipekit Ownership Model).

## Editing Skills

Skills live in `skills/{name}/skill.md` with YAML frontmatter (`name`, `description`). Portable skills must read `method.config.md` for project-specific values — never hardcode Linear IDs, team names, or paths. Skills that reference `skill.json` use it for metadata only.

## Three-Layer Enforcement Model

| Layer | Purpose |
|-------|---------|
| `CLAUDE.md` (in consuming project) | Conventions for VBW agents |
| CI / Hooks | Hard enforcement — blocks merges |
| Skills (this repo) | Interactive shortcuts for hands-on sessions |

VBW agents don't call skills — they read the consuming project's CLAUDE.md directly.

## Key Skills

**Stage 0 (Foundation):**

| Skill | Purpose |
|-------|---------|
| `/concept` | Project-level ideation — concept brief from ideas + existing docs |
| `/define` | Distill concept into project definition (phases, roles, workflows) |
| `/strategy-create` | Bootstrap strategy docs from project definition |
| `/startup` | Full bootstrap orchestrator — chains all Stage 0 + setup steps |
| `/roadmap-create` | Create ROADMAP.md and populate Linear |
| `/phase-plan` | Select execution phases, track progress |

**Development Pipeline (v2 daily loop):**

| Command | Purpose |
|---------|---------|
| `pk next` | Phase-aware: reads `## Current Phase:` from `PHASES.md`, queries Linear, groups by status (In Progress / Approved / Needs Spec) with per-group hints. Replaces v1's `cat NEXT.md`. |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent). |
| `/work <ID>` | Plan + execute in-session. `/work` plans inline (parallel `Agent` grounding) regardless of backend, then dispatches the **executor** per `method.config.md`: `Backend: native` (**default** — materializes a task DAG to `.pk-work/<ID>-PLAN.md`, executes on the **Workflow primitive**, atomic commit per task with verify-before-integrate), `Backend: vbw` (**optional** — dispatches the `vbw-dev` subagent to execute the inline plan; note: it does *not* spawn `vbw-lead`/`vbw-qa`), or `Backend: auto` (routes per plan complexity — ≤3 files + no migration → native, else → vbw). Per-invocation override via `--backend=`. |
| `/verify` | Pre-deploy gate. |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` invokes the antagonistic reviewer. |
| `pk ready [<ID>]` | Flip Draft PR to Ready (v2.6.0+). Fires `ready_for_review` → outside reviewers (Semgrep + claude-review per `templates/ci/`) run. No Linear state change. |
| `pk done <ID> [--merge]` | Verify merged (or `--merge` runs `gh pr merge` first), cleanup worktree+branch, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls integration branch and writes `.vbw-planning/.../SUMMARY.md` + flips PLAN status to complete (skipped silently when no VBW). |
| `pk promote <env>` | **Phase 1** (v2.6.0+): opens promote PR along `Ship environments`. WITs stay in source state. Refuses if any bundled issue is in `UAT`; `--confirmed` bypasses after env-UAT signoff. |
| `pk promote <env> --finish` | **Phase 2** (v2.6.0+): after the promote PR merges, transitions bundled WITs → `In <Env>` (intermediate) or → `Done` (final). |
| `/pk-exit` | Narrative session log to `Logs/Sessions/<date>_<HHMM>.md`. **Run manually as the last command of every Claude Code session** — never auto-chained from `/work`, `/verify`, or any other skill. |

**Orthogonal skills (unchanged in v2):**

| Skill | Purpose |
|-------|---------|
| `/light-spec` | Generates structured specs as AI-to-AI contracts |
| `/light-spec-revise` | Applies Spec Review Agent feedback surgically; detects stalemate loops |
| `/spec-preflight` | Empirical pre-flight checks on a Linear issue's spec — verifies file paths, line refs, phase-detect baseline, Linear status, dependencies against reality. Read-only. |
| `/pr-fix` | Pluggable-engine PR review (`pr-review-toolkit` agents by default, built-in fallback) with two-axis severity×confidence triage, interactive discussion, and targeted remediation. |
| `/pr-security-review` | Security-focused antagonistic PR review for migrations, RLS, SECURITY DEFINER, GRANT/REVOKE, auth, and Server Actions on privileged tables. |
| `/pk-bug` | Bug pipeline — intake, reproduce, regression-test-first, fix, ship, postmortem. Wraps `/work` and `pk ship` with discipline gates. |
| `/pk-express` | Idea→Draft-PR autopilot for **simple** WITs — chains `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify+ship), stopping only at attention gates (not-Now, tier:heavy, spec stalemate, verify flags, Draft PR). Quick/Standard tier only. |
| `/pipekit-help` | Reads project state, recommends the next pipeline step. |
| `/strategy-sync` | Updates Strategy docs post-ship to match what was actually built. |
| `/release-changelog` | Generates draft CHANGELOG entry from git commits between tags. |
| `/pipekit-update` | Pull latest Pipekit from GitHub into project (supports `--push`). |

Full skill list in `sop/Skills_SOP.md`.
