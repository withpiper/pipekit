# CLAUDE.md

**v4.31.0** — Last updated: 2026-08-07  *(**v4.31.0 — `/security-review` → `/repo-security-review`, genericized.** The canonical skill carried SiteLine's audit verbatim (PHP endpoints, `api-auth.php`/`cors.php`/`rate-limiter.php`, `.htaccess`, `Security/`, `src/marketing/security.html`), so every consumer inherited another repo's checklist and audited primitives it doesn't have. Audit areas + primitives now come from a project areas file (`Repo security areas`); the three artifact paths are optional keys that report `n/a` when blank rather than being invented. Renamed because `security-review` collided with Claude Code's own built-in of that name. The load-bearing machinery — coverage-before-filtering, grounded reads, adversarial verification — moved verbatim. Smoke 200, unchanged. Carries v4.30.0 — the legacy planning layer is gone (`bin/pk`'s phase-file/ID-map fallback, the `Backend` key and its whole chain, `/spec-preflight`'s dead `phase-detect` probe, `/review-plan`'s phase-slug path). Linear is the only initiative surface.)*

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

Projects pull from this repo using `sync-method.sh`. The sync copies `skills/`, `sop/`, `templates/`, and `method.md` into the project. It never touches project-specific files (`method.config.md`, `.claude/rules/`, project-specific skills). Exception: the five `pipekit-*` canonical rule files in `.claude/rules/` are sync-owned; a `Skip rules` key in `method.config.md` opts a project out of canonical rules that don't apply to it (v4.21.0+).

**Sync-safe overrides:** projects can override synced skills/SOPs/method.md without forking by writing to `.claude/overrides/`. The sync script applies overrides after the upstream copy and surfaces drift warnings when upstream changes a file you override. See `method.md` § Sync-Safe Overrides.

## Initiative Surface Ownership

Native-on-Workflow is the sole executor and the initiative surface is Linear-native. Pipekit owns the whole surface:

- **Pipekit owns** Linear issues, the **initiative surface** (Linear Initiatives `i{N}.` → Projects `I{N}.P{N}.` → Issues; v4.1.0, project `I{N}.` prefix added v4.5.0), strategy docs, and `method.config.md`. "What's next?" is read live from Linear via `pk next` (derives the current initiative from the initiative/project hierarchy); v2 retired the `NEXT.md` mirror, v4.1.0 retired `PHASES.md`/`linear-map.json`.
- **The roadmap is authored directly into Linear**, at `/roadmap-create` — the `i{N}.`/`I{N}.P{N}.` hierarchy *is* the roadmap.
- **Both levels are completable** (v4.28.0, the lanes model): an initiative is a release phase, a project is a **lane of ~3–8 issues**, and uncut work rests with **no project plus an `Area:` label**. The walk reads *into* a project but never *inside* one, so a project that keeps accepting work hides its contents from `pk next`/`pk status`. Completability lives at the project level; eternity lives at the theme/label level.
- **`/work` is the only executor entry point.** It plans inline (parallel `Agent` grounding) and executes on the native-on-Workflow backend, keeping Linear and the `pk *` state in sync. There is no backend selection.

Full initiative model in `method.md` (§ Initiative Surface Ownership).

## Editing Skills

**Edit the source, then run `scripts/dogfood-sync.sh`.** Claude Code loads skills and rules from `.claude/`, but in this repo those are *generated mirrors* of `skills/`, `templates/rules/`, and `agents/` — gitignored, and refreshed only by that script (consuming projects get theirs from `sync-method.sh`). Editing `.claude/` directly changes nothing that ships and is silently reverted on the next refresh. A stale mirror means your own `/verify`, `/work`, etc. are running old code: measured 2026-07-31, every mirrored skill had drifted, six were missing, and `.claude/skills/verify/SKILL.md` still carried a gate bug the same release had fixed. `tests/pk-smoke.sh` fails on drift locally and skips on CI, where the mirrors don't exist.

Skills live in `skills/{name}/SKILL.md` with YAML frontmatter (`name`, `description`). Portable skills must read `method.config.md` for project-specific values — never hardcode Linear IDs, team names, paths, or **model names**: subagent model + effort comes from the `method.config.md § Model Policy` roles (v4.13.0+), cited as "role per § Model Policy, default `X`" so the skill still works when the section is absent. Skills that reference `skill.json` use it for metadata only.

## Three-Layer Enforcement Model

| Layer | Purpose |
|-------|---------|
| `CLAUDE.md` (in consuming project) | Conventions for the executor (native-on-Workflow) |
| CI / Hooks | Hard enforcement — blocks merges |
| Skills (this repo) | Interactive shortcuts for hands-on sessions |

The executor doesn't call skills — it reads the consuming project's CLAUDE.md directly during execution.

## Key Skills

**Stage 0 (Foundation):** `/concept` → `/define` → `/strategy-create` → `/startup` (orchestrates the chain, auto-detects entry mode) → `/roadmap-create` (authors the roadmap into Linear) → `/phase-plan` (selects the next execution phase; `--cut` batches backlog issues into a new lane).

**Development Pipeline (v2 daily loop):**

| Command | Purpose |
|---------|---------|
| `pk next` | What's next, read live from Linear — derives the current initiative, groups issues by status with per-group hints. |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent). |
| `/work <ID>` | The sole executor: plans inline, materializes a task DAG to `.pk-work/<ID>-PLAN.md`, executes on the Workflow primitive — atomic commit per task, verify-before-integrate. |
| `/verify` | Pre-deploy gate. |
| `/security-gate [<ID>]` | Feature-scoped security gate, between `/verify` and `pk ship`. Hard gate on projects with a categories file: `pk ship` refuses without a sha-matched PASS sentinel (`--force-secgate` / `PK_SECGATE_BYPASS=1` to waive; plain `--force` does NOT). |
| `pk ship [--review] [--ready]` | Push, open Draft PR, Linear → UAT. |
| `pk ready [<ID>] [--force]` | Flip Draft PR to Ready; outside reviewers run. No Linear state change. Refuses if source or a migration changed after the `/verify` that vouches for the branch, or if the verified sha is unreachable after a rebase (`pk ship`'s gate is point-in-time; post-ship commits went unchecked). `--force` flips anyway and logs a Linear comment. |
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
| `/repo-security-review` | Periodic **whole-repo** security audit — area sweep, adversarial verification, score report. Portable framework; audit areas in `resources/repo-security-areas.md`. Renamed from `/security-review` in v4.31.0 (built-in collision). |
| `/pk-bug` | Bug pipeline: reproduce → regression-test-first → fix → ship → postmortem. |
| `/pk-express` | Idea→Draft-PR autopilot for Quick/Standard-tier WITs; stops at attention gates. |
| `/linear-hygiene` | Classifies unclassified/untriaged issues (placement, not disposition) and flags board-shape drift — pool smell, spent lanes, walk-skip hazards. Never creates a project. |
| `/pipekit-help` | Recommends the next pipeline step from project state. |
| `/strategy-sync` | Updates Strategy docs post-ship to match what shipped. |
| `/release-changelog` | Draft CHANGELOG entry from commits between tags. |
| `/pipekit-update` | Pull latest Pipekit into a consuming project. |

Full skill list + authoring conventions in `sop/Skills_SOP.md`; daily-loop flowchart in `RUNBOOK.md`.
