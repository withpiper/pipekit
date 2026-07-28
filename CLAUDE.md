# CLAUDE.md

**v4.21.0** — Last updated: 2026-07-28  *(**v4.21.0 — context rightsizing, phase 1.** This stamp returns to its spec'd one-line form — release history lives in `CHANGELOG.md`, not in an always-loaded preamble re-billed every turn (per Anthropic's Claude 5 context-engineering guidance, 2026-07-24: keep always-on files to repo purpose + non-obvious gotchas). Also: `pipekit-discipline.md § Comments and documentation` rewritten from prescriptive bullets to judgment form, and `sync-method.sh` gains a config-gated `Skip rules` opt-out so consumers stop auto-loading canonical rules that don't apply (cmux without cmux, migrations without a migration system). No `bin/pk` behavior change — smoke 133.)*

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

Skills live in `skills/{name}/skill.md` with YAML frontmatter (`name`, `description`). Portable skills must read `method.config.md` for project-specific values — never hardcode Linear IDs, team names, paths, or **model names**: subagent model + effort comes from the `method.config.md § Model Policy` roles (v4.13.0+), cited as "role per § Model Policy, default `X`" so the skill still works when the section is absent. Skills that reference `skill.json` use it for metadata only.

## Three-Layer Enforcement Model

| Layer | Purpose |
|-------|---------|
| `CLAUDE.md` (in consuming project) | Conventions for the executor (native-on-Workflow) |
| CI / Hooks | Hard enforcement — blocks merges |
| Skills (this repo) | Interactive shortcuts for hands-on sessions |

The executor doesn't call skills — it reads the consuming project's CLAUDE.md directly during execution.

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
| `pk next` | Initiative-aware: derives the current initiative live from the Linear-native surface (`i{N}.` initiative → `I{N}.P{N}.` project, by numeric name prefix; bare `P{N}.` and legacy `PHASES.md`/`linear-map.json` fall back), queries Linear, groups by status (In Progress / Approved / Needs Spec) with per-group hints. Replaces v1's `cat NEXT.md`. |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent). |
| `/work <ID>` | Plan + execute in-session. `/work` plans inline (parallel `Agent` grounding), then materializes a task DAG to `.pk-work/<ID>-PLAN.md` and executes on the **Workflow primitive** — atomic commit per task with verify-before-integrate. Native-on-Workflow is the **sole executor** as of v4.0.0; the pluggable `vbw` backend and `--backend=` flag were removed (a stale `Backend: vbw`/`--backend=vbw` now refuses with a migration message). |
| `/verify` | Pre-deploy gate. |
| `/security-gate [<ID>]` | **v4.4.0+** feature-scoped security gate (gap #3). Runs at the Building → UAT seam — after `/verify`, before `pk ship`. Classifies the feature diff into six sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII); none matched → instant PASS, a match → category checklist vs the diff → PASS/FAIL report + Linear comment. **Hard gate v4.17.0** — PASS writes a sha-matched `secgate-complete.md`; `pk ship` refuses without one matching HEAD on any project with a categories file (`--force` / `PK_SECGATE_BYPASS=1` escape). Distinct from `/security-review` (repo-wide audit) and `/pr-security-review` (PR-scoped). Portable framework, project signals in `resources/security-categories.md`. No-op without a categories file. |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` invokes the antagonistic reviewer. |
| `pk ready [<ID>]` | Flip Draft PR to Ready (v2.6.0+). Fires `ready_for_review` → outside reviewers (Semgrep + claude-review per `templates/ci/`) run. No Linear state change. |
| `pk done <ID> [--merge]` | Verify merged (or `--merge` runs `gh pr merge` first), cleanup worktree+branch, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls integration branch; for un-migrated projects it writes a legacy `.vbw-planning/.../SUMMARY.md` + flips PLAN status (skipped silently otherwise — always, for native projects). |
| `/prod-ready [<ID>]` | **v4.3.0+** production-readiness gate. Run **once** before the final `pk promote` (the last `Ship environments` entry; the merge to `main` on 1-tier). Verifies operational preconditions `/verify` doesn't — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, flag on risky paths, dashboard chart. PASS/FAIL report + Linear comment. **Hard gate v4.17.0** — PASS writes a `prodready-complete.md` sentinel (source-branch sha); `pk promote <final-env>` refuses without it on any project with a checks file (`--force` / `PK_PRODREADY_BYPASS=1`; 1-tier projects have no promote seam — advisory there). Portable framework, project checks in `resources/prod-readiness-checks.md`. No-op without a checks file. |
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
| `/linear-hygiene` | Fast Linear placement janitor — batch-homes orphaned / untriaged / unprioritized issues across all open states (placement, not disposition). Propose-then-apply; `--check` is read-only and is what `/pk-exit` calls. |
| `/pipekit-help` | Reads project state, recommends the next pipeline step. |
| `/strategy-sync` | Updates Strategy docs post-ship to match what was actually built. |
| `/release-changelog` | Generates draft CHANGELOG entry from git commits between tags. |
| `/pipekit-update` | Pull latest Pipekit from GitHub into project (supports `--push`). |

Full skill list in `sop/Skills_SOP.md`.
