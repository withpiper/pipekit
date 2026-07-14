# CLAUDE.md

**v4.14.0** — Last updated: 2026-07-14  *(**v4.14.0 — Roadmap Phase-Label Layer: render `ROADMAP.md`'s build order onto the Linear board.** The `i{N}.`/`I{N}.P{N}.` surface answers "what's the current initiative/sub-phase" but not "what order do I run these N issues in, what's parallel" — and a roadmap **phase** routinely spans multiple `I{N}.P{N}.` projects, so no single Linear project *is* a phase. New optional, config-gated `### Phase Label Layer`: a **label** (not a project) carries phase/pool membership (`Roadmap: Phase A/B/C` + `Roadmap: Continuous`), one ungrouped Manual-sorted saved view per label renders order, `sortOrder` mirrors the roadmap's top-to-bottom order, `Order: Any` + real `blockedBy` relations encode parallelism/sequence. `/roadmap-review` gains **Phase 3.5** (a materialization check → **bootstrap** the layer onto an existing board on retrofit, then drift-check vs `ROADMAP.md`: membership adds/removes, `sortOrder` seed-on-bootstrap / reorder-flag-only, one-phase-label exclusivity, `Order: Any` ⊥ `blockedBy`); `/roadmap-create` gains a Phase 3.5 scaffold; `/linear-hygiene` gains a hard guardrail — the placement janitor must **never** infer a `Roadmap: *` label from a re-homed `projectId` (project membership ≠ phase-label membership; SiteLine POC-382 anchor). `method.config.template.md` ships a commented-out `### Phase Label Layer` block. No-op without the config section — zero behavior change for un-opted projects; no `bin/pk` behavior change (smoke unchanged). Carries **v4.13.0 — Model Policy: skills reference model roles, not model names.** New optional `method.config.md § Model Policy` — a role → model + effort table (grounding/lookup `haiku`/`low`, execution `sonnet`/`medium`, verification `sonnet`/`high`, plan-review/adversarial `opus`/`xhigh`). Portable skills cite the role with its default inline (absent section = same defaults, zero behavior change), so the next model generation is a one-row config edit, not a docs-wide sweep — the no-hardcoded-values rule applied to the time-varying axis. Inline `model:` pins swept in `/review-plan`, `/verify`, `/security-gate`, `/prod-ready`, and all four `/work` spawn sites (task agents → execution tier, explorer → grounding/haiku, spec validator + security review → plan-review tier — nothing inherits the session model); Opus-4.7-era prose de-staled; `Session_Management_SOP` effort guidance re-anchored (`high` session default, sweep downward on upgrades). No `bin/pk` behavior change — smoke 95→98 (riders: two commit-hook false-positive fixes — cmd-subst heredoc `-m`, markdown-backtick doc prose — + merge-aware `pk done` hints in `/pk-exit` + the pipeline line). Carries **v4.11.0 — terminology aligned to Linear.** The docs-wide "phase" → "initiative" sweep deferred by v4.10.0: roadmap-phase prose now reads *initiative* and the **Phase Surface** concept is the **Initiative Surface** across every active doc, skill, and SOP (~280 in-place swaps, 27 files). Kept: the `/phase-plan` skill name, `phase-detect`/`phase-slug` identifiers, the `Future Phases` Linear **state** name, `sub-phase` (the Project level), spec-preflight "Phase 3.6", generic skill-process "phases", and dated history. No `bin/pk`/output change — smoke 89/89. Carries **v4.7.0 — VBW fully retired.** The last release completes the VBW retirement begun in v4.0.0 (executor removed), v4.1.0 (Linear-native phase surface), and v4.2.0 (plugin decoupled). Docs, skills, SOPs, templates, and `bin/pk` are debranded: no `/vbw:*` commands, no `vbw` backend / `--backend=` selection, no VBW/Pipekit ownership-boundary framing — Pipekit owns the whole Linear-native phase surface. The `pk_vbw_*` helpers are renamed `pk_legacy_*`. The **only** remaining VBW reference is a read-only `bin/pk` fallback (legacy `.vbw-planning/PHASES.md`/`linear-map.json` + `PLAN.md` finalize) for un-migrated projects — never the normal path. The VBW plugin is uninstalled from the machine; `archive/`, `experiments/`, `Logs/`, and dated changelogs keep their history as written. Smoke 63/63. Carries v4.6.0 — `pk deploy [<env>]`, a first-class deploy verb for script-deploy projects. **Carries v4.5.0 — projects carry their initiative number in the phase surface.** A Linear project under `i1.` is now `I1.P2. label`, not bare `P2.` — the phase reads at the project level (the navigable unit in Linear). `bin/pk` accepts both `I{N}.P{N}.` and legacy `P{N}.`; `/roadmap-create` + `/phase-plan` author the new form. **Carries v4.4.0 — `/security-gate`, the feature-scoped security gate (gap #3).** A per-feature gate at the Building → UAT seam (after `/verify`, before `pk ship`): it classifies the feature diff into six sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII) and, on a match, runs that category's checklist against the diff — none matched → instant PASS. PASS/FAIL report + Linear comment; advisory this release. Distinct from `/security-review` (repo-wide) and `/pr-security-review` (PR-scoped). Portable framework (`skills/security-gate/`), project signals in `resources/security-categories.md`, new `sop/Security_Gate_SOP.md`, two `method.config.md` keys. Two per-feature gates now bracket the lifecycle — `/security-gate` entering UAT, `/prod-ready` entering production. Carries v4.3.1 — heredoc-aware commit hook (hook-only). **Carries v4.3.0 — `/prod-ready`, the production-readiness gate (gap #2).** A second gate beside `/verify`: `/verify` proves the code is correct in isolation (per task, at ship); `/prod-ready` proves production can absorb it safely (once per feature, before the final `pk promote` / the merge to `main` on 1-tier). Six operational checks — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, a flag on risky paths, a dashboard chart; portable framework (`skills/prod-ready/`) with project checks in `resources/prod-readiness-checks.md`, new `sop/Production_Readiness_SOP.md`, two `method.config.md` keys. Advisory this release (report + Linear comment, no `pk promote` block); a hard sentinel gate is a documented fast-follow. **Carries v4.2.0 — VBW plugin decoupled, no longer required.** Its one functional dependency — the advisory commit-format hook — is re-homed as a Pipekit-owned hook (`.claude/hooks/validate-commit.sh`, source `templates/hooks/`, synced + registered by `sync-method.sh`); the dead executor references `VBW_COMMANDS.md` + `sop/VBW_Help.md` retire to `archive/`. The legacy `.vbw-planning/` planning layer remains (no Pipekit skill depends on it), slated for a separate retirement. **Carries v4.1.0 — Linear-native phase surface.** The roadmap's phase order lives in Linear: Initiatives named `i{N}.` (phases) → Projects named `P{N}.` (sub-phases) → Issues, ordered by the name-prefix number (Linear `sortOrder` is an unreliable drag-rank). `pk next`/`pk status` derive the current phase live; `/roadmap-create` authors the hierarchy and `/phase-plan` advances it; `PHASES.md`/`linear-map.json` are retired to a read-only fallback; Stage 0.5 `/vbw:init` is dropped from the contract. The `i{N}.`/`P{N}.` convention is the contract — `method.config.md § Phase Surface`. Validated live against a production Linear workspace. **The phase surface is now Linear-native; what remains of the VBW planning layer** — `.vbw-planning/` execution state, `/vbw:init`'s scaffold, `/review-plan`, and the `pk_vbw_*` PLAN/SUMMARY helpers — still stands; retiring it is a separate, later effort. **Carries v4.0.0 — VBW executor removed:** native-on-Workflow is the **sole** executor; the pluggable `vbw` backend, `--backend=` selection, and `vbw-dev`/`vbw-scout` dispatch are gone (the `auto` router went in v3.2.0); a stale `Backend: vbw`/`auto` now **refuses** with a migration message. The deep-analysis safety net remains the gate layer (`/financial-review`, `/pr-security-review`), which native runs. **Carries Pipekit 3.0–3.2:** native-on-Workflow executor; distribution-layer hardening (`bin/pk` smoke suite + CI gate, global `--help` guard, `pipekit/.local-skills` manifest, `pk doctor` upstream-staleness warning); v2.8.0's `/financial-review` + `/security-review` substrate; v2.7.x: `/pk-express`, `/pr-fix` pluggable engine, merge-driven Linear transition)*

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

Projects pull from this repo using `sync-method.sh`. The sync copies `skills/`, `sop/`, `templates/`, and `method.md` into the project. It never touches project-specific files (`method.config.md`, `.claude/rules/`, legacy `.vbw-planning/`, project-specific skills).

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
| `/security-gate [<ID>]` | **v4.4.0+** feature-scoped security gate (gap #3). Runs at the Building → UAT seam — after `/verify`, before `pk ship`. Classifies the feature diff into six sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII); none matched → instant PASS, a match → category checklist vs the diff → PASS/FAIL report + Linear comment. **Advisory** (doesn't block `pk ship`); distinct from `/security-review` (repo-wide audit) and `/pr-security-review` (PR-scoped). Portable framework, project signals in `resources/security-categories.md`. No-op without a categories file. |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` invokes the antagonistic reviewer. |
| `pk ready [<ID>]` | Flip Draft PR to Ready (v2.6.0+). Fires `ready_for_review` → outside reviewers (Semgrep + claude-review per `templates/ci/`) run. No Linear state change. |
| `pk done <ID> [--merge]` | Verify merged (or `--merge` runs `gh pr merge` first), cleanup worktree+branch, post commits to Linear, transition Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls integration branch; for un-migrated projects it writes a legacy `.vbw-planning/.../SUMMARY.md` + flips PLAN status (skipped silently otherwise — always, for native projects). |
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
