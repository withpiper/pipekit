# CLAUDE.md

**v4.22.0** — Last updated: 2026-07-28  *(**v4.22.0 — context rightsizing, phase 2 (mechanical batch).** `skills/*/skill.md` → `SKILL.md` (canonical case; sync gains an explicit case-migration step), CLAUDE.md Key Skills tables compressed to current-behavior one-liners, Completion Claims loop demand-loaded to `sop/Completion_Claims_SOP.md`, and 10 oversized skill descriptions compressed. No `bin/pk` behavior change — smoke 133.)*

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is **Pipekit** — a portable, structured AI-assisted software delivery system. It is NOT a software project itself. It contains methodology docs, SOPs, templates, and Claude Code skills that get synced into consuming projects via `scripts/sync-method.sh`.

Origin: extracted from the Piper production finance platform.

## Core Principle

**No stage may introduce guesswork into the next stage.** Specs must be planning-safe. Plans must be execution-safe. When ambiguity is detected, work goes backward, not forward.

## Pipeline

```
Stage 0: Foundation (a contract — see Entry Modes)
  /concept → /define → /strategy-create → /startup → /roadmap-create → /phase-plan

Stages 1-5: Development — the v2 daily loop (repeats per issue)
  pk next → pk branch → /work → /verify → pk ship (Draft) → pk ready → [PR review + preview UAT → merge] → pk done → [dev UAT] → pk promote <env> → (PR merges) → pk promote <env> --finish

pk done runs AFTER the merge and verifies it. --merge is the exception (pk runs gh pr merge for you) — never suggest it for an already-merged PR.

Per session (NOT part of the issue chain): /pk-exit — the last command of whatever session you're in.
  pk done runs from the parent repo and deletes the worktree, so in a worktree session: /pk-exit first, THEN leave the worktree and run pk done from the parent.
```

Stage 0 is a **contract** (a set of artifacts the dev pipeline requires), not a script. Three entry modes satisfy the contract: greenfield (full chain), brownfield (skip /concept and /define), inherited (verify and proceed). `/startup` auto-detects mode and confirms with the user. The v2 daily loop replaces v1's `/branch → /launch → /verify → /launch --close` chain — see `RUNBOOK.md` for the one-page flowchart. Full Entry Modes table in `method.md`.

## How Consuming Projects Work

Projects pull from this repo using `sync-method.sh`. The sync copies `skills/`, `sop/`, `templates/`, and `method.md` into the project. It never touches project-specific files (`method.config.md`, `.claude/rules/`, legacy `.vbw-planning/`, project-specific skills). Exception: the five `pipekit-*` canonical rule files in `.claude/rules/` are sync-owned; a `Skip rules` key in `method.config.md` opts a project out of canonical rules that don't apply to it (v4.21.0+).

**Sync-safe overrides:** projects can override synced skills/SOPs/method.md without forking by writing to `.claude/overrides/`. The sync script applies overrides after the upstream copy and surfaces drift warnings when upstream changes a file you override. See `method.md` § Sync-Safe Overrides.

## Initiative Surface Ownership

VBW is fully retired: the executor went in v4.0.0 (native-on-Workflow is the sole executor), the plugin was decoupled in v4.2.0, and the initiative surface became Linear-native in v4.1.0. Pipekit owns the whole surface:

- **Pipekit owns** Linear issues, the **initiative surface** (Linear Initiatives `i{N}.` → Projects `I{N}.P{N}.` → Issues; v4.1.0, project `I{N}.` prefix added v4.5.0), strategy docs, and `method.config.md`. "What's next?" is read live from Linear via `pk next` (derives the current initiative from the initiative/project hierarchy); v2 retired the `NEXT.md` mirror, v4.1.0 retired `PHASES.md`/`linear-map.json`.
- **The roadmap is authored directly into Linear**, at `/roadmap-create` — the `i{N}.`/`I{N}.P{N}.` hierarchy *is* the roadmap.
- **`/work` is the only executor entry point.** It plans inline (parallel `Agent` grounding) and executes on the native-on-Workflow backend, keeping Linear and the `pk *` state in sync. There is no backend selection.
- **Legacy read-only fallback:** `bin/pk` still reads a legacy `.vbw-planning/PHASES.md`/`linear-map.json` (and legacy `PLAN.md` finalize) *only* for un-migrated projects that haven't moved to the Linear-native surface. Never the normal path.

Full initiative model in `method.md` (§ Initiative Surface Ownership).

## Editing Skills

Skills live in `skills/{name}/SKILL.md` with YAML frontmatter (`name`, `description`). Portable skills must read `method.config.md` for project-specific values — never hardcode Linear IDs, team names, paths, or **model names**: subagent model + effort comes from the `method.config.md § Model Policy` roles (v4.13.0+), cited as "role per § Model Policy, default `X`" so the skill still works when the section is absent. Skills that reference `skill.json` use it for metadata only.

## Three-Layer Enforcement Model

| Layer | Purpose |
|-------|---------|
| `CLAUDE.md` (in consuming project) | Conventions for the executor (native-on-Workflow) |
| CI / Hooks | Hard enforcement — blocks merges |
| Skills (this repo) | Interactive shortcuts for hands-on sessions |

The executor doesn't call skills — it reads the consuming project's CLAUDE.md directly during execution.

## Key Skills

**Stage 0 (Foundation):** `/concept` → `/define` → `/strategy-create` → `/startup` (orchestrates the chain, auto-detects entry mode) → `/roadmap-create` (authors the roadmap into Linear) → `/phase-plan` (selects the next execution phase).

**Development Pipeline (v2 daily loop):**

| Command | Purpose |
|---------|---------|
| `pk next` | What's next, read live from Linear — derives the current initiative, groups issues by status with per-group hints. |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent). |
| `/work <ID>` | The sole executor: plans inline, materializes a task DAG to `.pk-work/<ID>-PLAN.md`, executes on the Workflow primitive — atomic commit per task, verify-before-integrate. |
| `/verify` | Pre-deploy gate. |
| `/security-gate [<ID>]` | Feature-scoped security gate, between `/verify` and `pk ship`. Hard gate on projects with a categories file: `pk ship` refuses without a sha-matched PASS sentinel (`--force-secgate` / `PK_SECGATE_BYPASS=1` to waive; plain `--force` does NOT). |
| `pk ship [--review] [--ready]` | Push, open Draft PR, Linear → UAT. |
| `pk ready [<ID>]` | Flip Draft PR to Ready; outside reviewers run. No Linear state change. |
| `pk done <ID> [--merge]` | Verify the merge happened, clean up worktree+branch, post commits to Linear, transition UAT → `In <FirstEnv>` (→ Done on 1-tier). |
| `/prod-ready [<ID>]` | Production-readiness gate, run once before the final `pk promote`. Hard gate on projects with a checks file: the final promote refuses without its sentinel (`--force` / `PK_PRODREADY_BYPASS=1` to waive). |
| `pk promote <env>` | Opens the promote PR along `Ship environments`; refuses if a bundled issue is still in UAT (`--confirmed` after env-UAT signoff). After it merges, `pk promote <env> --finish` transitions issues → `In <Env>` / Done. |
| `/pk-exit` | Narrative session log to `Logs/Sessions/`. Run manually as the last command of every session — never auto-chained. |

**Orthogonal:**

| Skill | Purpose |
|-------|---------|
| `/light-spec`, `/light-spec-revise` | Structured specs as AI-to-AI contracts; revise applies review feedback surgically. |
| `/spec-preflight` | Read-only empirical checks of a spec against reality (paths, symbol/line refs, deps). |
| `/pr-fix` | PR review with severity×confidence triage and targeted remediation. |
| `/pr-security-review` | Antagonistic security review of a PR diff (migrations, RLS, auth). |
| `/pk-bug` | Bug pipeline: reproduce → regression-test-first → fix → ship → postmortem. |
| `/pk-express` | Idea→Draft-PR autopilot for Quick/Standard-tier WITs; stops at attention gates. |
| `/linear-hygiene` | Batch-homes orphaned/untriaged issues (placement, not disposition). |
| `/pipekit-help` | Recommends the next pipeline step from project state. |
| `/strategy-sync` | Updates Strategy docs post-ship to match what shipped. |
| `/release-changelog` | Draft CHANGELOG entry from commits between tags. |
| `/pipekit-update` | Pull latest Pipekit into a consuming project. |

Full skill list + authoring conventions in `sop/Skills_SOP.md`; daily-loop flowchart in `RUNBOOK.md`.
