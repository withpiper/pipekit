# CLAUDE.md

**v4.4.0** — Last updated: 2026-06-22  *(**v4.4.0 — `/security-gate`, the feature-scoped security gate (gap #3).** A per-feature gate at the Building → UAT seam (after `/verify`, before `pk ship`): it classifies the feature diff into six sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII) and, on a match, runs that category's checklist against the diff — none matched → instant PASS. PASS/FAIL report + Linear comment; advisory this release. Distinct from `/security-review` (repo-wide) and `/pr-security-review` (PR-scoped). Portable framework (`skills/security-gate/`), project signals in `resources/security-categories.md`, new `sop/Security_Gate_SOP.md`, two `method.config.md` keys. Two per-feature gates now bracket the lifecycle — `/security-gate` entering UAT, `/prod-ready` entering production. Carries v4.3.1 — heredoc-aware commit hook (hook-only). **Carries v4.3.0 — `/prod-ready`, the production-readiness gate (gap #2).** A second gate beside `/verify`: `/verify` proves the code is correct in isolation (per task, at ship); `/prod-ready` proves production can absorb it safely (once per feature, before the final `pk promote` / the merge to `main` on 1-tier). Six operational checks — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, a flag on risky paths, a dashboard chart; portable framework (`skills/prod-ready/`) with project checks in `resources/prod-readiness-checks.md`, new `sop/Production_Readiness_SOP.md`, two `method.config.md` keys. Advisory this release (report + Linear comment, no `pk promote` block); a hard sentinel gate is a documented fast-follow. **Carries v4.2.0 — VBW plugin decoupled, no longer required.** Its one functional dependency — the advisory commit-format hook — is re-homed as a Pipekit-owned hook (`.claude/hooks/validate-commit.sh`, source `templates/hooks/`, synced + registered by `sync-method.sh`); the dead executor references `VBW_COMMANDS.md` + `sop/VBW_Help.md` retire to `archive/`. The legacy `.vbw-planning/` planning layer remains (no Pipekit skill depends on it), slated for a separate retirement. **Carries v4.1.0 — Linear-native phase surface.** The roadmap's phase order lives in Linear: Initiatives named `i{N}.` (phases) → Projects named `P{N}.` (sub-phases) → Issues, ordered by the name-prefix number (Linear `sortOrder` is an unreliable drag-rank). `pk next`/`pk status` derive the current phase live; `/roadmap-create` authors the hierarchy and `/phase-plan` advances it; `PHASES.md`/`linear-map.json` are retired to a read-only fallback; Stage 0.5 `/vbw:init` is dropped from the contract. The `i{N}.`/`P{N}.` convention is the contract — `method.config.md § Phase Surface`. Validated live against a production Linear workspace. **The phase surface is now Linear-native; what remains of the VBW planning layer** — `.vbw-planning/` execution state, `/vbw:init`'s scaffold, `/review-plan`, and the `pk_vbw_*` PLAN/SUMMARY helpers — still stands; retiring it is a separate, later effort. **Carries v4.0.0 — VBW executor removed:** native-on-Workflow is the **sole** executor; the pluggable `vbw` backend, `--backend=` selection, and `vbw-dev`/`vbw-scout` dispatch are gone (the `auto` router went in v3.2.0); a stale `Backend: vbw`/`auto` now **refuses** with a migration message. The deep-analysis safety net remains the gate layer (`/financial-review`, `/pr-security-review`), which native runs. **Carries Pipekit 3.0–3.2:** native-on-Workflow executor; distribution-layer hardening (`bin/pk` smoke suite + CI gate, global `--help` guard, `pipekit/.local-skills` manifest, `pk doctor` upstream-staleness warning); v2.8.0's `/financial-review` + `/security-review` substrate; v2.7.x: `/pk-express`, `/pr-fix` pluggable engine, merge-driven Linear transition)*

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
  pk next → pk branch → /work → /verify → pk ship (Draft) → pk ready → [PR review + preview UAT] → pk done [--merge] → [dev UAT] → pk promote <env> → (PR merges) → pk promote <env> --finish

Per session (NOT part of the issue chain): /pk-exit — the last command of whatever session you're in.
  pk done runs from the parent repo and deletes the worktree, so in a worktree session: /pk-exit first, THEN leave the worktree and run pk done from the parent.
```

Stage 0 is a **contract** (a set of artifacts the dev pipeline requires), not a script. Three entry modes satisfy the contract: greenfield (full chain), brownfield (skip /concept and /define), inherited (verify and proceed). `/startup` auto-detects mode and confirms with the user. The v2 daily loop replaces v1's `/branch → /launch → /verify → /launch --close` chain — see `RUNBOOK.md` for the one-page flowchart. Full Entry Modes table in `method.md`.

## Repo Structure

- `method.md` — The full methodology (Stage 0 + 12-step pipeline, principles, tooling)
- `method.config.template.md` — Template for project-specific config (Linear IDs, strategy docs, environments, pre-deploy gate)
- `STARTUP.md` — Reference guide for project bootstrap (use `/startup` for the interactive flow)
- `RUNBOOK.md` — Per-issue practical walkthrough (the loop you run most often)
- `sop/` — Standard operating procedures (Code Quality, Git + Deployment, Hooks, Linear, Session Management, Skills)
- `templates/` — Concept brief, project definition, strategy doc, and spec templates
- `templates/strategy/` — Templates for each strategy doc type (conceptual overview, technical architecture, etc.)
- `skills/` — Portable Claude Code skills (synced into consuming projects as `.claude/skills/`)
- `scripts/sync-method.sh` — The sync script that pulls this repo's content into consuming projects

## How Consuming Projects Work

Projects pull from this repo using `sync-method.sh`. The sync copies `skills/`, `sop/`, `templates/`, and `method.md` into the project. It never touches project-specific files (`method.config.md`, `.claude/rules/`, `.vbw-planning/`, project-specific skills).

**Sync-safe overrides:** projects can override synced skills/SOPs/method.md without forking by writing to `.claude/overrides/`. The sync script applies overrides after the upstream copy and surfaces drift warnings when upstream changes a file you override. See `method.md` § Sync-Safe Overrides.

## VBW / Pipekit Ownership

The VBW plugin is no longer required (v4.2.0): the executor was removed in v4.0.0, and its one functional dependency — the advisory commit-format hook — is now a Pipekit-owned hook. A legacy VBW planning layer may still be present for direct-VBW projects (no Pipekit skill depends on it), slated for a separate retirement. The ownership boundary:

- **VBW (legacy) owns** `.vbw-planning/ROADMAP.md`, `PLAN.md` files, and execution state — present for direct-VBW projects, slated for a separate retirement.
- **Pipekit owns** Linear issues, the **phase surface** (Linear Initiatives `i{N}.` → Projects `P{N}.` → Issues, v4.1.0), strategy docs, and `method.config.md`. "What's next?" is read live from Linear via `pk next` (derives the current phase from the initiative/project hierarchy); v2 retired the `NEXT.md` mirror, v4.1.0 retired `PHASES.md`/`linear-map.json` (read-only fallback only).
- **The roadmap is authored directly into Linear**, at `/roadmap-create` — the `i{N}.`/`P{N}.` hierarchy *is* the roadmap; there is no merge into a VBW phase skeleton.
- **Don't invoke VBW agents directly in Pipekit projects.** Use `/work`, not `/vbw:lead` or `/vbw:dev`. `/work` executes on the native-on-Workflow backend (the sole executor as of v4.0.0) and keeps Linear and the `pk *` state in sync. Direct VBW invocation bypasses Pipekit's visibility layer and causes drift.

Full ownership model in `method.md` (§ VBW / Pipekit Ownership Model).

## Editing Skills

Skills live in `skills/{name}/skill.md` with YAML frontmatter (`name`, `description`). Portable skills must read `method.config.md` for project-specific values — never hardcode Linear IDs, team names, or paths. Skills that reference `skill.json` use it for metadata only.

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
| `pk next` | Phase-aware: derives the current phase live from the Linear-native surface (`i{N}.` initiative → `P{N}.` project, by numeric name prefix; legacy `PHASES.md`/`linear-map.json` fall back), queries Linear, groups by status (In Progress / Approved / Needs Spec) with per-group hints. Replaces v1's `cat NEXT.md`. |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent). |
| `/work <ID>` | Plan + execute in-session. `/work` plans inline (parallel `Agent` grounding), then materializes a task DAG to `.pk-work/<ID>-PLAN.md` and executes on the **Workflow primitive** — atomic commit per task with verify-before-integrate. Native-on-Workflow is the **sole executor** as of v4.0.0; the pluggable `vbw` backend and `--backend=` flag were removed (a stale `Backend: vbw`/`--backend=vbw` now refuses with a migration message). |
| `/verify` | Pre-deploy gate. |
| `/security-gate [<ID>]` | **v4.4.0+** feature-scoped security gate (gap #3). Runs at the Building → UAT seam — after `/verify`, before `pk ship`. Classifies the feature diff into six sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII); none matched → instant PASS, a match → category checklist vs the diff → PASS/FAIL report + Linear comment. **Advisory** (doesn't block `pk ship`); distinct from `/security-review` (repo-wide audit) and `/pr-security-review` (PR-scoped). Portable framework, project signals in `resources/security-categories.md`. No-op without a categories file. |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` invokes the antagonistic reviewer. |
| `pk ready [<ID>]` | Flip Draft PR to Ready (v2.6.0+). Fires `ready_for_review` → outside reviewers (Semgrep + claude-review per `templates/ci/`) run. No Linear state change. |
| `pk done <ID> [--merge]` | Verify merged (or `--merge` runs `gh pr merge` first), cleanup worktree+branch, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls integration branch and writes `.vbw-planning/.../SUMMARY.md` + flips PLAN status to complete (skipped silently when no VBW). |
| `/prod-ready [<ID>]` | **v4.3.0+** production-readiness gate. Run **once** before the final `pk promote` (the last `Ship environments` entry; the merge to `main` on 1-tier). Verifies operational preconditions `/verify` doesn't — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, flag on risky paths, dashboard chart. PASS/FAIL report + Linear comment. **Advisory** (doesn't block `pk promote`); portable framework, project checks in `resources/prod-readiness-checks.md`. No-op without a checks file. |
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
