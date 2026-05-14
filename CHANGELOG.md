# Changelog

All notable Pipekit releases. Versioning follows semver-ish — minor bumps for new capability, patch for fixes/docs only.

Pin to a specific version: `./scripts/sync-method.sh v1.8.2`.

---

## Release Checklist

Every `chore(release): vX.Y.Z` PR must complete the following before merging to `main`:

- [ ] Bump `PK_VERSION` in `bin/pk`.
- [ ] Add a new `## vX.Y.Z — YYYY-MM-DD` section to `CHANGELOG.md` (this file).
- [ ] **Stamp every doc you actually edited in this release.** Don't bump stamps on untouched docs — the version gap between an older stamp and the current release is the drift signal we keep them for. The stamped doc set lives in the table below. If you add a new top-level doc or SOP, stamp it and add it to that table.
- [ ] If `method.md` / `RUNBOOK.md` / `GUIDE.md` were edited, also bump their stamps to `vX.Y.Z` with today's date (these three are the "constitutional" docs — they describe current behavior and should always carry the latest version).
- [ ] Update `RUNBOOK.md` line 14 (`./scripts/sync-method.sh vX.Y.Z` example) to the new tag.
- [ ] PR title contains `vX.Y.Z` so the `auto-tag-release` workflow can tag the merge commit (see `.github/workflows/auto-tag-release.yml`).
- [ ] Skip-check: leave historical `vX.Y.Z` references in prose alone (e.g., "as of v2.3.0" describes when a behavior shipped — that's intentional, not drift).

### Stamped docs (maintained list)

Every doc below carries a `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(blurb)*` line right after its H1. The stamp's `vX.Y.Z` is the release **the doc is calibrated to**, not the release we last touched typography in. When a release modifies a doc, bump its stamp to the new version + today's date. Otherwise, leave it alone so the gap surfaces drift.

| Doc | Role |
|-----|------|
| `method.md` | Constitutional — deep methodology |
| `RUNBOOK.md` | Constitutional — one-page daily flow |
| `GUIDE.md` | Constitutional — full instruction manual |
| `README.md` | Public-facing repo intro |
| `CLAUDE.md` | Guidance for Claude Code sessions in this repo |
| `STARTUP.md` | Project bootstrap reference |
| `VBW_COMMANDS.md` | VBW `/vbw:help` snapshot |
| `method.config.template.md` | Project-config template |
| `sop/Code_Quality.md` | SOP — coding conventions |
| `sop/Git_and_Deployment.md` | SOP — branches, merges, release flow |
| `sop/Hooks_SOP.md` | SOP — Claude Code hooks |
| `sop/Linear_SOP.md` | SOP — Linear model, states, labels |
| `sop/Session_Management_SOP.md` | SOP — Claude Code session hygiene |
| `sop/Skills_SOP.md` | SOP — skill anatomy, sync, overrides |

Format (copy verbatim): `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(one-line release blurb)*`. The three constitutional docs additionally carry an `HH:MM` suffix on the date to disambiguate same-day patch releases (e.g., `2026-05-13 21:04`).

Why this list exists: v2.4.0 through v2.4.3.1 all shipped with stale `v2.3.0` header stamps because release PRs edited prose at specific line numbers without touching the "Last updated" line. The header tells humans and AI sessions which version the doc describes — when it lies, every reader after that ships against the wrong contract.

---

## v2.4.3.2 — 2026-05-14

> **Doc-polish release.** No code behavior changes. Brings every constitutional doc + SOP into alignment with the v2.4.3 code gate, establishes a stamped-docs inventory + release checklist, and closes drift that accumulated across v2.4.0 through v2.4.3.1.

### What changed

**Stamped-docs inventory (new).** Every top-level doc and SOP now carries a `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(blurb)*` line right after its H1. The version on each stamp is the release the doc is **calibrated to** — when a release modifies a doc, bump its stamp; otherwise leave it alone so the gap between stamped version and current release surfaces drift. 14 docs are covered; the maintained list lives in the Release Checklist section above.

**Release Checklist (new).** Top of `CHANGELOG.md` now carries a checklist that every `chore(release): vX.Y.Z` PR must complete before merging — bump `PK_VERSION`, add CHANGELOG entry, stamp edited docs, update RUNBOOK sync example, ensure PR title carries `vX.Y.Z` for the auto-tag workflow. The root cause this closes: v2.4.0 through v2.4.3.1 all shipped with stale `v2.3.0` header stamps because release PRs edited prose at specific lines without touching the "Last updated" line.

**Content polish across 10 docs.**

- **`method.md`, `RUNBOOK.md`, `GUIDE.md`** — `--confirmed` flag now appears on every `pk done` / `pk promote` row in the daily-loop tables and cheat sheets. `Backend: auto` listed alongside `vbw` / `native` in the config table. Three-layer enforcement model (CLAUDE.md / CI+hooks / skills) called out in method.md Overview. `/strategy-from-code` deferral reworded — was "deferred to v1.4.0" (a version that already shipped 2026-04-27 without the skill); now "deferred; originally promised for v1.4.0 but never built."
- **`CLAUDE.md`** — daily-loop sequence shows the full v2.4.3 chain with `[--confirmed]` modifiers and `pk promote`; `/pk-exit` flagged as manual-invocation-only (never auto-chained from another skill); `Backend: auto` listed; `sop/` list expanded to include all seven SOPs.
- **`README.md`** — `pk done` / `pk promote` rows updated; `/pk-exit` per-session emphasis; versioning example refreshed from `v1.0` to `v2.4.3.2`.
- **`sop/Code_Quality.md`** — stack-agnostic note (was implicitly TypeScript-only); `/verify` named as canonical pre-deploy gate runner.
- **`sop/Git_and_Deployment.md`** — Release Flow now explicitly describes optimistic state transitions at PR-open, the merge as source-of-truth anchor, and the v2.4.3 `--confirmed` gate semantics.
- **`sop/Linear_SOP.md`** — UAT row + transitions reference `--confirmed`; 2-tier clarification that Released state is unused.
- **`sop/Session_Management_SOP.md`** — `/pk-exit` added as explicit session bookend in the session pattern table.
- **`sop/Skills_SOP.md`** — skill-author guidance now says "Dispatch heavy work through `/work`" (which routes to vbw/native/auto backends) rather than "Use VBW agents directly"; `/pipekit-help` usage hint added.

**`PK_VERSION`** 2.4.3.1 → 2.4.3.2.

### Why

The methodology is correct; the docs were lagging. Stamping every doc with its calibration version makes drift legible (you can see a doc is "v2 minor releases behind current" at a glance), and the checklist forces future releases to keep the stamps honest. Cutting v2.4.3.2 instead of leaving the polish on main without a tag lets Piper and other consumers `./scripts/sync-method.sh v2.4.3.2` to pin a known-good doc set.

### Migration

None. Re-run `/pipekit-update` or `./scripts/sync-method.sh v2.4.3.2` in consumer projects. Consumers already on v2.4.3 / v2.4.3.1 see only doc changes (no behavior changes).

---

## v2.4.3.1 — 2026-05-13

> Patch: doc reconciliation for v2.4.3. The v2.4.3 code shipped with `method.md` and `RUNBOOK.md` still describing only the v2.4.2 *prose* UAT gate — neither mentioned that the binary now refuses with `exit 1`. Closes the doc lag.

### What changed

- **`method.md` Stage 3 (line 219)** — Interactive UAT paragraph appended: "v2.4.3 added code-level enforcement as a belt-and-braces backstop: `pk done` and `pk promote` now refuse with `exit 1` when Linear state is `UAT` (or any bundled issue is in `UAT` for `pk promote`). Pass `--confirmed` once UAT is signed off to bypass."
- **`method.md` Stage 4 (lines 236-237)** — `pk done <ID>` and `pk promote <env>` step descriptions updated with the `[--confirmed]` flag and the UAT-refusal clause.
- **`method.md` Tooling table (lines 435-436)** — `pk done <ID> [--confirmed]` and `pk promote <env> [--confirmed]` rows updated.
- **`RUNBOOK.md` `[5e]` box** — extra line: "v2.4.3+ enforces this in code: pk done / pk promote refuse with exit 1 when Linear state is UAT. Pass --confirmed once UAT is signed off to bypass."
- **`PK_VERSION`** 2.4.3 → 2.4.3.1.

### Why

v2.4.3's code-level UAT refusal is the load-bearing change of the day, but the prose docs still implied "this is a discipline rule, not enforced." Users (and AI sessions) reading `method.md` would think the gate is advisory when it now exits 1. Doc rot starts within hours of the code shipping; closing it the same night while the context is fresh.

### Migration

None. Re-run `/pipekit-update v2.4.3.1` in consumer projects (or in the Pipekit clone itself — same command, auto-detects mode).

---

## v2.4.3 — 2026-05-13

> Patch: code-level enforcement of the v2.4.2 UAT-gate doc, plus a `pk install` lag fix surfaced when the v2.3.3 state-ladder gate failed to fire because the user's installed `pk` was at v2.3.2. Five fixes, one bundled PR.

### What changed

- **`bin/pk cmd_done`** — refuses with `exit 1` when the issue is in Linear state `UAT` unless `--confirmed` is passed. v2.4.2's doc gate told future sessions not to chain `pk done` past UAT; this is the belt-and-braces. Doc gates rely on the model reading prose; code gates rely on `exit 1` and don't lie. Anchor: WIT-451 worker session 2026-05-13, where auto-merge → auto `pk done` wiped the worktree mid-UAT.
- **`bin/pk cmd_promote`** — same shape, narrower trigger: refuses when any bundled issue (scanned from `git log <target>..<source>`) is in `UAT`. Released / Done bundles still pass through (re-promote is fine). Approved-or-earlier is already caught by the v2.3.3 ladder leap-frog refusal in `pk_linear_set_state`, so no double-emit. `--confirmed` opt-out.
- **`bin/pk pk_linear_get_state`** — new helper: fetches the current workflow-state name for a Linear issue by identifier. Returns empty string on lookup failure so callers can treat absence as "don't know" rather than aborting. Used by both UAT refusals above.
- **`bin/pk cmd_install`** — `--force` now always re-links, even when the existing target already points at `$src`. Previously the `existing == src` short-circuit returned 0 before `--force` was evaluated, so `pk install --force` was a silent no-op against valid symlinks (anchor: Pendragon 2026-05-13). Reports `Re-linked: …` instead of `Installed: …` when the re-link was forced. Adjacent design question — should `pk install` default to symlinking the global `~/Projects/pipekit/bin/pk` clone instead of the calling project's `bin/pk`? — left for a future cycle; not in scope for v2.4.3.
- **`scripts/sync-method.sh`** — after each sync, compares the synced `bin/pk` content against `~/.local/bin/pk` and `/usr/local/bin/pk` via `cmp -s` (follows symlinks). If they differ, warns with the `pk install --force` remediation. New `--auto-install` flag invokes `pk install --force` automatically post-sync for unattended sync paths (CI, batch scripts). Closes the lag-bug anchor: PR #270 ran the v2.3.3 state-ladder gate code path… except it didn't, because `~/.local/bin/pk` was at `pk 2.3.2` while the synced `bin/pk` was 2.4.2. WIT-275 got falsely transitioned Approved → Done and had to be reverted manually.
- **`sop/Git_and_Deployment.md` § Hotfix Procedure**  — new sub-section "When the explicit beta cherry-pick is needed (three-tier)". The standard three-tier hotfix flow files three branches (`hotfix/*-main`, `*-cherrypick-dev`, `*-cherrypick-beta`), but the explicit beta cherry-pick is redundant when a `dev → beta` promote is imminent — the dev cherry-pick sweeps to beta via the next promote. Filing it anyway leaves an orphan branch. Anchor: WIT-455, 2026-05-13 — `hotfix/margin-cherrypick-beta` orphaned because the dev cherry-pick swept to beta via PR #268 the same day.
- **`scripts/test-pk-v2.4.3.sh`** — new test harness covering: `pk install --force` re-links a valid symlink, `pk_linear_get_state` helper presence, `cmd_done` / `cmd_promote` `--confirmed` arg parsing, and end-to-end UAT-refusal trigger + bypass via a stubbed `pk_linear_get_state`. 9 assertions, network-free (Linear lookups stubbed inside subshells).
- **`bin/pk cmd_help`** — adds `--confirmed` to the `pk done` and `pk promote` synopsis lines.
- **`skills/pipekit-update/skill.md`** — new Phase 0 auto-detects upstream vs downstream mode by `git remote get-url origin` + sentinel files (`method.md` + `CHANGELOG.md` + `bin/pk`). Upstream mode (running inside the Pipekit repo itself) does `git fetch --tags && git checkout <tag>` + `pk install --force`; downstream mode keeps the existing `sync-method.sh` flow. Same `/pipekit-update v2.4.3` command works on both: a machine where `~/.local/bin/pk` symlinks to a consumer project's `bin/pk` AND a machine where it symlinks to the Pipekit clone itself. `--push` refuses in upstream mode (incoherent). Closes the multi-machine update divergence — every machine runs the same incantation.
- **`PK_VERSION`** 2.4.2 → 2.4.3.

### Why

The v2.4.2 doc gate (Stage 3 + RUNBOOK [5e] + `/work`/`pk-exit` "does NOT do") is the right gate for normal use, but the empirical failure mode is an LLM session auto-chaining past prose. Doc gates rely on the model reading and respecting natural language; code gates rely on `exit 1`. Belt-and-braces. The same week the v2.4.2 doc gate landed, the v2.3.3 state-ladder gate (a code gate that DID exist) silently bypassed itself because the user's installed `pk` was old — surfacing the lag-bug that `sync-method.sh` now warns on. Both classes of failure now have explicit code-level guards.

### Migration

None for consumers. Re-run `./scripts/sync-method.sh v2.4.3` in consumer projects. After sync:

- `pk version` returns `2.4.3`
- `pk done <ID>` refuses with a clear message when the issue is in UAT — pass `--confirmed` once UAT is signed off
- `pk promote <env>` refuses when any bundled issue is in UAT — pass `--confirmed` to override
- `pk install --force` always re-links, even on valid symlinks (no more silent no-op)
- `./scripts/sync-method.sh` warns when `~/.local/bin/pk` differs from the synced `bin/pk`; add `--auto-install` for unattended sync

### What this fixes (anchor incidents from 2026-05-13)

- **WIT-451 worker auto-firing `pk done` mid-UAT** → `cmd_done` UAT refusal
- **Same root, narrower** → `cmd_promote` UAT refusal on bundled issues
- **PR #270 / WIT-275 false transition: state-ladder gate didn't fire because installed `pk` was v2.3.2** → `sync-method.sh` install-lag warning + `--auto-install`
- **Pendragon `pk install --force` silent no-op** → `cmd_install` force/symlink fix
- **WIT-455 orphaned `hotfix/margin-cherrypick-beta` branch** → `sop/Git_and_Deployment.md` hotfix nuance

### Tests

```
bash scripts/test-pk-promote.sh   # 25 assertions (v2.3.3 ladder + missing-target guard)
bash scripts/test-pk-config.sh    # 14 assertions (pk_config parsing)
bash scripts/test-pk-v2.4.3.sh    #  9 assertions (v2.4.3 additions)
```

---

## v2.4.2 — 2026-05-13

> Patch: daily-loop discipline polish. Five doc-only fixes from the WIT-451 canary that ran today against Piper. Closes the "implicit UAT gate" and "auto-cascade past UAT" failure modes, plus two `/spec-preflight` Phase 3.6 false-positive reductions and a `/work` rule that auto-files follow-up WITs when a documented Risk-fallback is invoked.

### What changed

- **`method.md` Stage 3 + Stage 4** — Stage 3 renamed "Verify + Ship + UAT" so the UAT step is named, not implied. Adds the gate-clause: `pk done` and `pk promote` MUST NOT run until UAT signs off AND the PR merges. Stage 4 reframes both as "Deliberate human step — must NOT be auto-invoked by `/work`, `/verify`, `/pk-exit`, or any session-automation skill." Both anchor on the WIT-451 canary 2026-05-13 ("the worker session auto-fired `pk done` mid-test and wiped the worktree").
- **`RUNBOOK.md` flowchart** — new explicit `[5e] Interactive UAT` box between PR review and merge, with the no-auto-chain rule inline so future readers don't need to re-derive it from `method.md`.
- **`skills/work/skill.md` "What this skill does NOT do"** — adds two explicit bullets: "No `pk done` invocation, ever" and "No `pk promote` invocation, ever." Names the WIT-451 canary as the anchor incident. Tightens what the worker session is allowed to do at completion.
- **`skills/pk-exit/skill.md`** — new "What this skill does NOT do" section with the same two bullets + "No Linear state writes." Closes the secondary path the worker session could have used to chain past UAT.
- **`skills/work/skill.md` Step 6.5 Risk-fallback follow-up filing** — MANDATORY clause when a documented `R<N>: Mitigation` clause was invoked during implementation. Worker now must (1) identify the deferred scope, (2) `mcp__claude_ai_Linear__save_issue` to file the follow-up WIT in Approved state, (3) reference the new WIT-ID in the hand-off, (4) update parent spec's AC to mark as "partial per R<N>; tracked in <NEW-WIT-ID>". Closes WIT-451's R4 follow-up-rot pattern (dual-field inline NOTE editor only got filed in triage, not at ship time).
- **`skills/spec-preflight/skill.md` Step 3a explicit-NEW marker** — file-paths probe now recognizes `**NEW**`, `(NEW)`, `, NEW`, `(new file)`, "Files to create" section heading, `NEW: <path>` prefix. NEW-marked paths record as `🆕 expected-new` instead of `✗ missing`. Verdict category treats them as `✓`. Eliminates the over-statement false positive on every WIT that legitimately introduces files (WIT-348, WIT-451 each hit this 2-3 times).
- **`skills/spec-preflight/skill.md` Probe 3.6a Strategy-citation downgrade** — Canonical-doc cross-check now scans for inline Strategy citations (`Strategy/Doc<N>`, `Strategy/Doc<N> §<section>`, or an "Authority hierarchy" table naming a Strategy file). If ≥1 inline citation, downgrades `⚠ Cross-check Strategy` → `✓ Canonical docs: cross-check performed in-spec`. Probe still emits `⚠` when POC is mentioned but no inline Strategy citation exists. WIT-451's revised spec was the canonical example that motivated this — fully cited, still drew `⚠`.
- **`PK_VERSION`** 2.4.1 → 2.4.2.

### Why

The WIT-451 canary 2026-05-13 against Piper ran the full v2 daily loop end-to-end and surfaced three procedural gaps. Listed from highest impact down:

1. **No interactive UAT gate.** Stage 3's "Human performs UAT" line was prose-only. The worker session shipped PR #265, auto-merged on green CI, then auto-fired `pk done` and `pk promote beta` in the same ~60-second window while the user was still in the middle of UAT on `dev.withpiper.ai`. The worktree got wiped mid-test. Stage 3 now names UAT as the gate, names `pk done` and `pk promote` as deliberate human steps, and explicitly forbids `/work` and `/pk-exit` from chaining past them.
2. **Worker sessions auto-firing `pk done` / `pk promote`.** Symptom of (1). Both skills now carry explicit "no pk done, ever / no pk promote, ever" bullets that name the anchor incident.
3. **Risk-fallback follow-up rot.** WIT-451's spec documented R4 ("if the dual-field inline cell editor proves brittle, fall back to NOTE-via-modal-only"). The worker correctly invoked the fallback but only filed 2 follow-up WITs, missing the dual-field editor — that one got caught later in triage and became WIT-454. Step 6.5 of `/work` now makes the follow-up filing mandatory when an `R<N>: Mitigation` clause is invoked.

Two adjacent Phase 3.6 probe-polish items also surfaced:

4. **NEW-file false positives.** WIT-348 (3 NEW files) and WIT-451 (3 NEW files) each drew `⚠ File paths: N/M exist (missing: ...)` warnings on paths the spec explicitly marked NEW. Verdict noise that erodes signal.
5. **Strategy-citation false positives on Probe 3.6a.** WIT-451's revised spec cited Strategy/Doc6 §2.1, §3.3, and Doc2 §3.3.1 throughout, with an explicit Authority hierarchy table — and the probe still emitted `⚠ Cross-check spec claims against Strategy` because the trigger fired blindly. Downgrade closes the false positive.

All five are docs-only, low-blast-radius. A deeper code-level guard for (1) and (2) — `pk done` refuses when Linear state is `UAT` and a `--confirmed` flag isn't passed — is deliberately deferred to v2.4.3, after the doc gate has run in practice.

### Migration

None. Re-run `./scripts/sync-method.sh v2.4.2` in consumer projects. After sync:

- `pk version` returns `2.4.2`
- `method.md` Stage 3 / Stage 4 + `RUNBOOK.md` flowchart reflect the named UAT gate
- `/work` and `/pk-exit` carry explicit "no pk done / no pk promote" bullets
- `/spec-preflight` Phase 1 + Probe 3.6a emit fewer false positives on real specs

### What this fixes (canary findings)

- **WIT-451 canary finding "implicit UAT gate"** → method.md Stage 3 + Stage 4 + RUNBOOK.md [5e]
- **WIT-451 canary finding "worker session auto-fired pk done / pk promote"** → /work + /pk-exit "does NOT do" sections
- **WIT-451 canary finding "R-fallback follow-up filed only at triage time"** → /work Step 6.5 mandatory clause
- **WIT-451 + WIT-348 finding "NEW-file false positives"** → /spec-preflight Step 3a
- **WIT-451 finding "Strategy cited inline but probe still warned"** → /spec-preflight Probe 3.6a downgrade

### Deferred to v2.4.3

- Code-level guard in `bin/pk cmd_done`: refuse when Linear state is `UAT` unless `--confirmed` flag passed. Belt-and-suspenders with the v2.4.2 doc gate.
- Same for `cmd_promote` when source-branch issues are still in UAT.

---

## v2.4.1 — 2026-05-13

> Patch: `/linear-todo-runner` creates real worktrees explicitly. Closes the empirically-observed "Agent isolation:`worktree` parameter is a no-op" failure mode where 4 parallel agents collapsed into one shared checkout and trampled each other's uncommitted work via branch switches.

### What changed

- **`skills/06-linear-todo-runner/skill.md` Phase 3 worktree creation** — the orchestrator now runs `git worktree add <path> -b <branch> <BASE>` before each Agent spawn. Worktree path is interpolated into the worker prompt as a concrete value (the Agent tool exposes no `cwd` parameter).
- **Worker first-action verification** — the spawned worker must `cd <WORKTREE_PATH>` then run a 4-way check (`pwd`, `git rev-parse --show-toplevel`, `git rev-parse --abbrev-ref HEAD`, `git worktree list`). Any mismatch halts the worker before any edits and reports the actual output — prompt-level `cd` + verification is now the actual containment mechanism, not optional.
- **Preflight against path/branch collision** — refuses to start a worker if `WORKTREE_PATH` or `BRANCH_NAME` already exist; logs the collision in a Linear comment, moves the issue back to Approved, continues with the next queue item. Eliminates the "blended diff" failure mode where re-runs trampled prior partial work.
- **Phase 4 cleanup asymmetry** — on success, `git worktree remove <path>` clears the worktree (with `--force` documented for cases where the worker leaves untracked files); the branch stays for PR creation. On failure, both the worktree and the branch are preserved for forensic inspection; the user cleans up after triage.
- **Worker prompt template** — outer fence now uses 4 backticks so the inner `` ```bash `` verification block nests cleanly. Worktree path and branch name passed as concrete values, not placeholders.
- **Prerequisites + Related Skills sections updated** — explicitly document that `isolation: "worktree"` is a no-op on current harnesses; runner uses sibling `../<repo>-<id>` worktree paths, distinct from `pk branch`'s in-repo `.worktrees/<ID>-<slug>/` pattern, so the two coexist without fighting over paths.
- **`PK_VERSION`** 2.4.0 → 2.4.1.

### Why

Empirically observed on 2026-05-13 while running `/linear-todo-runner` against rs-vault: 4 parallel agents spawned with `isolation: "worktree"` collapsed into one shared checkout. Sibling branch switches inside that shared checkout silently discarded each other's uncommitted work — the workers produced a "blended diff" where each agent's final state contained fragments of every sibling's work overlaid by the last branch switch.

Root cause: the Agent tool's `isolation: "worktree"` parameter is accepted but does not honor on current harnesses — there's no actual worktree provisioned, just the shared parent cwd that the workers race over. The Agent tool also exposes no `cwd` parameter, so neither path of "containment" the original skill assumed actually exists. The fix moves containment to the orchestrator's pre-spawn `git worktree add` plus a worker prompt that fails loudly when verification doesn't match.

### Migration

None. Re-run `./scripts/sync-method.sh v2.4.1` in consumer projects. After sync:

- `pk version` returns `2.4.1`
- `/linear-todo-runner` creates real worktrees via `git worktree add` before each agent spawn
- Workers refuse to proceed if the 4-way first-action verification doesn't match — preventing the silent-corruption failure mode
- Failed worker runs preserve both the worktree and the branch for forensic inspection (`git worktree remove <path>` and `git branch -D <branch>` are the manual cleanup once triaged); successful runs clean up the worktree but keep the branch for PR creation
- Preflight collision refusal protects against re-running the same queue across leftover worktrees from prior failed runs

### What this fixes (empirical findings)

- **2026-05-13 rs-vault 4-agent collapse** — Agent tool `isolation: "worktree"` parameter is a no-op → orchestrator now creates real worktrees explicitly and the worker verifies before any edits. Memory entry "Agent isolation:'worktree' broken" anchors this in cross-session context.

### Related notes

If you cannot run `git worktree add` from the orchestrator (e.g., the orchestrator's repo state is non-trivial), the skill now documents `--max-agents 1` (sequential) as the safe fallback. Sequential is slower but immune to the parallel-collapse failure mode.

---

## v2.4.0 — 2026-05-13

> Minor: `/spec-preflight` Phase 3.6 — project signal probing. Closes the "environmental blindness" class of bug surfaced by the WIT-348 Gate 3 canary. Four new probes: canonical-doc cross-check, platform capability, tooling availability, migration data shape.

### What changed

- **`skills/spec-preflight/skill.md`** — new Step 3.6 ("Project signal probes") between Steps 3 and 4. Steps 1–3 verify claims the spec explicitly makes; Step 3.6 probes claims the spec implies by referencing a tool, proposing a platform-specific mechanism, drafting a migration, or anchoring to a non-canonical source. Four probes:
  - **3.6a — Canonical-doc cross-check (#21)** — when the spec body references POC and `Strategy docs path` resolves to an existing dir, surfaces Strategy docs + section hints for cross-check. `⚠` warning (ambiguous; human decides).
  - **3.6b — Platform capability (#20)** — detects GUC patterns (`ALTER DATABASE`, `current_setting`, `app.X`). Hard-fails on managed-supabase (the postgres role lacks `SET DATABASE` privilege even as DB owner). Reads new `Platform` V2 key.
  - **3.6c — Tooling availability (#22)** — detects test runner / quality tool names in ACs (Playwright, Cypress, Jest, Vitest, Storybook, Lighthouse, ESLint, Prettier, MSW, Testing Library). Greps repo-root + workspace `package.json` files for the corresponding package names. Hard-fails when AC requires a tool that isn't in `dependencies` or `devDependencies`. Auto-downgrades to warning when the same AC text acknowledges the gap ("to be added", "follow-up", "next phase").
  - **3.6d — Migration data shape (#24)** — scans cited migration SQL for new `CHECK`, `NOT NULL`, type-narrowing, and column renames. Builds inverse-predicate `SELECT COUNT(*)` queries. Executes against the parent project via any bound `mcp__supabase-*__execute_sql` tool (read-only); otherwise surfaces the query templates. `⚠` warning with the violator counts (or templates).
- **`skills/spec-preflight/skill.md` `--accept` flag** — downgrade Phase 3.6 hard-fails (`✗`) to warnings (`⚠`) for accepted-risk cases. Findings still appear; only the blocking verdict softens. Phase 1–3 hard-fails remain blocking (`--accept` does not bypass empirical claim divergence).
- **`skills/spec-preflight/skill.md` verdict block** — now sectioned: "Empirical claims (Phase 1–3)" and "Project signal probes (Phase 3.6)". New output examples include the WIT-348 canary pattern (Strategy cross-check + Playwright tooling miss + migration data-shape probes firing simultaneously).
- **`method.config.template.md`** — new `Platform` V2 key (values: `managed-supabase`, `self-hosted-postgres`, `none`; default `none`). `Migration dir` "Used by" column extended to call out `/spec-preflight` Probe 3.6d.
- **`PK_VERSION`** 2.3.3 → 2.4.0.

### Why

The v2.3.x recovery established that Pipekit had two distinct classes of "trust but never verify" bug. v2.3.2 fixed parser blindness (`pk_config` returned defaults silently); v2.3.3 fixed promote-chain blindness (target branch and Linear ladder). v2.4.0 fixes the remaining class: environmental blindness — the spec is internally coherent and passes the Spec Review Agent, but it references tooling that isn't installed, a platform mechanism the deployment doesn't support, or a column model that contradicts the project's canonical Strategy docs. Every downstream gate (plan-reviewer, `/verify`, QA subagent) reads the spec body as ground truth; none of them re-check spec-vs-reality at the surroundings layer. The Gate 3 canary surfaced all four probe gaps in a single WIT (WIT-348):

- **#21 (Strategy cross-check)** — spec claimed 5 lifecycle date fields with "parity with POC" framing. Strategy/Doc1 §3.1 + Strategy/Doc2 §3.2.3 define **6** fields with engagement-default scoping. Without the canonical-doc probe, `/light-spec` and every downstream gate would have shipped the wrong column set.
- **#22 (Tooling)** — an AC required Playwright; `@playwright/test` was not in `package.json`. The AC was unsatisfiable as written; the `/work` agent had to invent a Vitest substitution mid-execution.
- **#20 (Platform)** — WIT-450's prod-safety mechanism used `ALTER DATABASE postgres SET app.is_prod`; managed Supabase blocked the write with `42501: permission denied` at deploy-time, forcing a redesign to a sentinel-table pattern. The capability mismatch was knowable from the platform fact alone.
- **#24 (Migration data shape)** — per-PR branch DBs run with `with_data: false`, so the migration's chronological `CHECK` constraint passed CI three times. At apply-time against populated piper-dev, 1 row violated `show_end_date <= onsite_end_date` because `end_date → show_end_date` and `wrap_date → onsite_end_date` reversed the natural project-closure ordering.

All four are "the project has the answer; the toolchain didn't apply it." Phase 3.6 puts the probes at the earliest gate (`/spec-preflight`) so the spec author resolves divergence once, before downstream agents lock in.

### Migration

Optional. Re-run `./scripts/sync-method.sh v2.4.0` in consumer projects to pick up the updated `spec-preflight` skill and template. After sync:

- `pk version` returns `2.4.0`
- `/spec-preflight PROJ-XXX` emits a Phase 3.6 section in the verdict block. Probes that don't match the spec content render as `n/a` — projects with no GUC patterns / no Strategy dir / no migrations see the same flow they had pre-v2.4.0 plus four `n/a` lines.
- Optional `Platform: managed-supabase` (or `self-hosted-postgres`) in `method.config.md` enables hard-fails on platform-incompatible GUC designs. Leave blank for projects without DB or with non-Postgres backends.
- `/spec-preflight PROJ-XXX --accept` downgrades Phase 3.6 hard-fails to warnings (for tooling intentionally absent / to be bootstrapped later). Phase 1–3 hard-fails remain blocking.

### What this fixes (loop-notes references)

- **#20** Managed-Supabase blocks GUC parameter writes → Probe 3.6b refuses GUC-based prod-safety designs at spec time (reads `Platform` config key)
- **#21** `/spec-preflight` doesn't cross-check `Strategy/*` canonical docs → Probe 3.6a surfaces Strategy docs + section hints when spec references POC
- **#22** `/spec-preflight` doesn't probe test-runner / tooling availability → Probe 3.6c grep `package.json` for every tool mentioned in an AC; hard-fails when absent
- **#24** Per-PR branch DBs lack production data; migrations pass CI then fail at apply-time → Probe 3.6d scans migration SQL for CHECK/NOT NULL/rename/narrowing, builds inverse-predicate SELECT COUNT(*) queries, runs them via Supabase MCP when bound

### Deferred to future patches

Piper-side infra items (#23 dev migration CI, #26 branch protection, #27 SessionStart `gh auth` hook) are tracked downstream in the Piper repo — they are project-specific operational hardening, not Pipekit upstream changes.

---

## v2.3.3 — 2026-05-13

> Patch: `pk promote` correctness. Refuses when the target branch is missing on origin instead of exiting 128 silently; respects the Linear workflow ladder instead of force-transitioning every bundled WIT to the env's mapped state.

### What changed

- **`bin/pk` `cmd_promote` missing-target guard** — runs `git ls-remote --exit-code origin refs/heads/$target` after target validation. On miss, refuses with an actionable error containing the exact `gh api -X POST repos/<owner>/<repo>/git/refs` recovery command (owner/repo derived from the origin URL). New `--bootstrap` flag auto-recreates the branch at `origin/<source>` tip via `gh api`.
- **`bin/pk` `pk_state_rank`** (new helper) — ranks Linear workflow states along the canonical ladder (`Triage` < `Ideas` < `Future Phases` < `On Deck` < `Needs Spec` < `Specced` < `Approved` < `Building` < `In Progress` < `UAT` < `Released` < `Done`). Unknown states return 0 (preserves current behavior for projects with custom workflows); `Canceled` / `Duplicate` outrank `Done` (never promote forward).
- **`bin/pk` `pk_linear_set_state` ladder gate** — opt-in `mode="advance"` argument. When set, refuses backward transitions (logs "already at <state> (skip backward transition)") and refuses Approved-or-earlier → Released/Done leap-frogs (logs a loud warning to stderr; commits made it into a promote bundle without UAT verification).
- **`bin/pk` `cmd_promote` issue-loop** — passes `"advance"` mode to `pk_linear_set_state`. Bundled WITs only move forward along the ladder; the audit trail stays monotonic across cycles.
- **`scripts/test-pk-promote.sh`** (new) — fixture-based bash harness. Asserts pairwise ladder ordering, unknown-state fallback, terminal-off-ladder behavior, `git ls-remote --exit-code` semantics, and owner/repo extraction from both https and ssh origin URLs. 25 assertions; run with `bash scripts/test-pk-promote.sh`.
- **`PK_VERSION`** 2.3.2 → 2.3.3.

### Why

The v2.3.1 recovery Gate 3 canary (WIT-348, closed 2026-05-13) surfaced 8 new findings. Two were direct regressions of the promote chain that v2.3.2 was supposed to stabilize:

- **#25** — `pk promote beta` exited 128 with zero diagnostic output when `origin/beta` was missing. Root cause: `git fetch origin beta --quiet || true` swallowed the "couldn't find remote ref" message and masked the non-zero exit; the downstream `git log origin/beta..origin/dev` then exited 128 on the unknown revision. Without `bash -x`, the failure mode is essentially undebuggable. (The branch went missing because GitHub's repo-level auto-delete-on-merge removed it when a previous beta→main PR merged — handoff finding #26, fixed Piper-side via branch protection.)
- **#28** — `pk promote beta` force-transitioned every WIT mentioned in commit messages to the env's mapped state, regardless of current Linear state. In the canary, this pulled 3 already-Done WITs backward to Released and leap-frogged 1 Approved WIT straight to Released, skipping Building/In Progress/UAT entirely. Audit-trail integrity loss compounds per cycle — the next `pk promote main` would have force-moved the Released WITs back to Done, producing a "shipped → unreleased → shipped" lifecycle on three issues that never actually un-shipped.

Both regressions fired on the first real canary use. v2.3.2 happened to have `origin/beta` bootstrapped, so #25 (a direct regression of canary 3's loop-note #16) was deprioritized as parallel-track; v2.3.3 folds it in.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.3` in consumer projects. After sync:

- `pk version` returns `2.3.3`
- `pk promote <env>` refuses loudly when the target branch is missing on origin (instead of exiting 128 silently)
- `pk promote <env> --bootstrap` recreates the missing target branch at the source tip via `gh api`
- `pk promote <env>` only transitions Linear issues forward along the workflow ladder; backward and leap-frog attempts log and skip without mutating Linear state
- `bash scripts/test-pk-promote.sh` exits 0 (25 assertions)

### What this fixes (loop-notes references)

- **#25** `pk promote` silent exit 128 on missing target branch → fixed (`git ls-remote` guard + `--bootstrap` flag)
- **#28** `pk promote` force-transitions bundled WITs ignoring Linear state → fixed (ladder gate in `pk_linear_set_state` via opt-in `mode="advance"`)

### Deferred to a future patch

The Gate 3 canary also flagged `/spec-preflight` capability gaps (#20 managed-Supabase GUC probe, #21 canonical `Strategy/` cross-check, #22 test-runner/tooling availability, #24 migration data-shape probe) and three Piper-side infra items (#23 dev migration CI, #26 branch protection, #27 SessionStart `gh auth` hook). The `/spec-preflight` Phase 3.6 capability-probing extension lands in a separate Pipekit PR; the Piper-side items are tracked downstream.

---

## v2.3.2 — 2026-05-12

> Patch: closes the v2.3.1 canary cascade. `pk_config` reads the actual code-block config format; `pk config` subcommand exposed; `/verify` skill stops self-terminating; `pk done` no longer destroys its own CWD.

### What changed

- **`bin/pk` `pk_config` parser** — accepts plain `Key: Value` inside fenced code blocks (the format every consumer actually uses, per `method.config.template.md` lines 162-180) in addition to the legacy markdown-table form. Code-block matched first; table is the fallback. Restores correct values for `Backend`, `Integration branch`, `Ship environments`, `Require QA review`, and every other V2 key.
- **`bin/pk config <key>` subcommand** — added. Plain-value output for `$(pk config K)` substitution. No-arg form dumps all known V2 keys + resolved values. `pk cfg` is an alias. Skills now have one place to read config.
- **`bin/pk` sourceability** — bottom-of-file `main "$@"` guarded with `[ "${BASH_SOURCE[0]}" = "${0}" ]` so test harnesses can `source bin/pk` to exercise helpers directly.
- **`scripts/test-pk-config.sh`** (new) — fixture-based bash harness. Asserts `pk_config` against code-block style (Piper, rs-vault), legacy markdown-table, missing-key + default, and malformed blank-value. 14 assertions; run with `bash scripts/test-pk-config.sh`.
- **`skills/verify/skill.md`** — Step 0 + Step 3b replace the markdown-table `grep` for Integration branch with `pk config "Integration branch"` (one source of truth). Step 2's awk gate-extractor no longer self-terminates: the start regex uses `next` so the end pattern only evaluates on subsequent lines, restoring the bash block extraction that v2.3.1 silently broke.
- **`bin/pk` `cmd_done` worktree refusal** — prefix-matches CWD against the worktree path via `pwd -P`, refusing for *any* nesting level (subdirs included), and runs before posting Linear comments or computing diffs so refused runs leave no side effects.
- **`PK_VERSION`** 2.3.1 → 2.3.2.

### Why

The v2.3.1 canary (WIT-280 in Piper, closed 2026-05-12) surfaced 19 findings. One root cause — `pk_config` matched only markdown-table rows, never the `Key: Value` code-block format documented in `method.config.template.md` — silently returned defaults for every V2 key in every consumer project. `pk promote beta` refused with "not a valid target" because `Ship environments` read as the default `dev,main` instead of Piper's `dev,beta,main`. `Backend: auto` read as `vbw`. `Require QA review: true` read as `false`. `pk ship` and `pk branch` accidentally kept working because `pk_integration_branch` had a separate fallback chain.

Three downstream findings rode the same parser blind spot: `/verify` Step 0's Integration-branch grep (#3) and Step 2's awk gate-extractor (#4) — the awk used `/^## Pre-Deploy Gate/,/^## /` which self-terminated on its own start line, emitting an empty gate. And `pk done`'s late, exact-match CWD check (#13/#14) destroyed the running Claude session's working directory when called from inside the worktree's subdirectories.

This patch closes the cascade plus adds a test harness so the silent-default class of bug cannot recur unnoticed.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.2` in consumer projects. After sync:

- `pk version` returns `2.3.2`
- `pk config Backend` returns the actual configured value (e.g. `auto`) in projects that use the code-block V2-key format
- `pk promote <env>` works for any project with a multi-env `Ship environments` chain
- `pk done` from inside the worktree (or any subdirectory of it) refuses with a clear error instead of destroying the CWD

### What this fixes (loop-notes references)

- **#15** `pk_config` parser blind to code-block format → fixed
- **#2** No `pk config` subcommand → added (with `cfg` alias)
- **#3** `/verify` Step 0 Integration-branch parser → routed through `pk config`
- **#4** `/verify` Step 2 awk self-terminates on start line → corrected (`next` after start match)
- **#13** `pk done` exact-match CWD check skipped subdirs → prefix-match via `pwd -P`
- **#14** `pk done` side-effect ordering destroyed CWD partway through cleanup → refusal moved above side effects

---

## v2.3.1 — 2026-05-09

> Patch: `RUNBOOK.md` is now synced into consumer projects.

### What changed

- **`scripts/sync-method.sh`** — adds `RUNBOOK.md` to the synced doc set alongside `method.md`, `GUIDE.md`, and `STARTUP.md`. Three edits: header comment listing what syncs, `sync_file` invocation, and the post-sync changelog comparison loop. Consumer projects now get `pipekit/RUNBOOK.md` populated and kept up-to-date on each sync.
- **`PK_VERSION`** 2.3.0 → 2.3.1.

### Why

`RUNBOOK.md` exists in pipekit's main repo as the one-page operational doc — the canonical daily-loop flowchart. Until v2.3.1 it was never synced, so consumer projects had `pipekit/method.md` (deep methodology, ~700 lines) and `pipekit/GUIDE.md` (full manual, ~1200 lines) but no one-pager for daily reference. Surfaced during Piper's v2.3.0 sync canary (PR #242 on piper).

`method.md` line 5 self-describes the relationship: "RUNBOOK is the canonical one-page operational doc; this document is the deeper methodology." Both have distinct, non-overlapping roles. Adding RUNBOOK to the sync gives consumers the daily-use surface.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.1` and `pipekit/RUNBOOK.md` lands in your project's `pipekit/` folder.

---

## v2.3.0 — 2026-05-09

> State machine maps 1:1 to environment. New `Released` Linear state for 3-tier projects. `pk promote` walks `Ship environments` one hop per call. `pk done` is cleanup-only.

### What changed

- **`bin/pk` cmd_promote rewritten** (PR #76) — `pk promote <env>` walks `Ship environments` one hop per invocation. Validates target against the chain, derives source from chain position, opens source→target PR, transitions matching issues optimistically at PR-open time. Position-based state mapping: last env in chain → **Done**, any non-final → **Released**. 2-tier backwards-compat: `pk promote` with no arg auto-picks the only hop. Preserves `--stash` / `--take-remote` conflict handling.
- **`bin/pk` cmd_done strip-down** (PR #76) — removed the `pk_linear_set_state ... "Done"` call. `pk done` is now **pure cleanup**: removes worktree, deletes branch, posts commits + diffstat to Linear. State movement is owned entirely by `pk ship` (→ UAT) and `pk promote` (→ Released / → Done). A worktree closing does not mean the issue is shipped.
- **`bin/pk` v2.2.2 fixes folded in** (PR #75) — `pk verify` parser rewrite (awk section-extractor; removes gate-must-be-last constraint and the silent 10-command truncation cap); `pk doctor` Linear error surfacing (parses `userPresentableMessage` / `.message` from GraphQL responses; falls through to truncated body snippet; distinct "no response" branch for network failures); `pk branch` honors `Worktree prefix` from `method.config.md` (defaults to `${root}/.worktrees/`; trailing char in prefix value controls join style).
- **Help text + headers** — `bin/pk` header comment block, `cmd_help` table, and inline `pk` echo strings all updated to reflect new transitions and the `pk promote <env>` target-arg form.
- **`method.config.template.md`** — Released row added to Workflow State IDs table. Two-tier and three-tier release-flow sections rewritten with new transition semantics. (PR #76 + #78.)
- **`sop/Linear_SOP.md`** — pipeline diagrams (Planned + Ad-hoc), state-meaning table, key transitions, and fast-track paths updated to include Released. Explicit note: `pk done` is cleanup-only and does NOT transition state. (PR #76.)
- **`sop/Git_and_Deployment.md`** — Step 5/6 docs use `pk promote <env>` (primary). Linear-transitions lines for both 2-tier and 3-tier rewritten. Pre-deploy gate sub-section updated. (PR #78.)
- **`sop/Skills_SOP.md`** — `pk done` and `pk promote` rows updated. (PR #77.)
- **Constitutional docs aligned** — `method.md`, `RUNBOOK.md`, `GUIDE.md`, `STARTUP.md`: version stamps bumped from v2.1.2 → v2.3.0; pipeline tables, flowcharts, and walkthroughs reflect Released state and the new pk done / pk promote semantics. (PRs #77, #78, #79.)
- **Templates** (`templates/tier-{quick,standard,heavy}.md`) — close-path lines rewritten to reflect cleanup-only `pk done` and target-arg `pk promote <env>`. (PR #78.)
- **Skills updated** — `skills/linear/skill.md` (Phase 4 step 3 documents 2-tier vs 3-tier transitions); `skills/sync-linear/skill.md` (workflow status ladder includes Released); `skills/task-processor/skill.md` (adds Released as a state option); `skills/pr-fix/skill.md` (visibility-gap description includes Released). (PR #78.)
- **`PK_VERSION` 2.1.3 → 2.2.2 → 2.3.0** — caught a pre-existing version drift (PR #75) and bumped through to current.

### Why

The v1 → v2 daily loop validated end-to-end on Piper (May 2026 migration), but two structural problems surfaced during the canary:

1. **`pk done` was 3-tier-blind** — it transitioned issues to Done unconditionally on merge to the integration branch (e.g. `dev`). For 3-tier projects (Piper, any team-with-QA project), this lied about issue status: the code was still on `dev`, awaiting beta and main promotions. Workaround was a manual revert to UAT after every `pk done`. Filed as Loop-Notes finding #6.
2. **`pk promote` was hardcoded single-hop** — opened `--base main --head $integration` directly, skipping any intermediate environments. For 3-tier projects, `pk promote` was effectively a no-op for `dev → beta` and a misuse risk for `dev → main`. Filed as Loop-Notes finding #8.

Both problems share a root cause: the v2 design hadn't fully committed to "state tracks WHERE in the pipeline." With state mapped 1:1 to environment (UAT = on dev, Released = on beta, Done = on main), Linear's state always reflects reality. No more "Done then revert" pingpong on intermediate hops. `pk done`'s pre-v2.3.0 state-transition responsibility evaporates — state movement belongs entirely to `pk ship` (the one transition into the deploy chain) and `pk promote` (each subsequent hop).

This is the load-bearing simplification: `cmd_done` shrinks, `cmd_promote` carries all promotion-state logic, and the contract becomes legible — "the command's invocation is the trigger; state moves at PR-open optimistically; `pk done` is just cleanup."

### What this fixes

- **3-tier `pk done` lying about status** — gone. State stays UAT through any number of intermediate hops; `pk promote main` is the only command that can mark Done.
- **3-tier `pk promote` skipping environments** — gone. `pk promote <env>` walks one hop, validates against `Ship environments`, refuses skip-ahead.
- **State-machine ambiguity** — Linear's state and the deploy reality now diverge only when a promote PR is closed without merging (rare, recoverable by manual state revert).
- **Project portability** — position-based state mapping (last hop → Done, else → Released) means projects can use any env names, not just `dev,beta,main`. `develop,staging,production` works identically.

### What this breaks

**Backwards-compat preserved for 2-tier projects.** `pk promote` with no arg still works there — auto-picks the only hop in `Ship environments`, transitions directly to Done. Released is unused on 2-tier.

**3-tier projects must:**
1. Add a **Released** Linear state (type: `started`) between UAT and Done. Capture the state UUID.
2. Add the UUID to `method.config.md` Workflow State IDs.
3. Switch from `pk promote` (no arg) to explicit `pk promote <env>` invocations.

If a 3-tier project syncs v2.3.0 before adding Released, intermediate `pk promote <env>` calls fail-soft per issue: "Released state not configured — add it via Linear UI + method.config.md, then re-run." Final-hop promotes (`pk promote main` → Done) continue working unchanged.

### Migration

Per consuming project:
1. Add `Released` state via Linear UI (type `started`, position between UAT and Done). Capture state UUID.
2. Update `method.config.md` Workflow State IDs table — add `| Released | <uuid> |` row.
3. Run `./scripts/sync-method.sh v2.3.0`.
4. (3-tier only) Update consumer-side SOPs that reference `/g-promote-*` or single-hop `pk promote` to use `pk promote <env>` form.
5. First canary: `pk promote beta` on the next real Linear issue.

### Cross-references

- PR #75: v2.2.2 — `pk verify` / `pk doctor` / `pk branch` fixes
- PR #76: v2.3.0 — `cmd_promote` rewrite + `cmd_done` strip + Released state
- PR #77: docs alignment pass 1 (constitutional docs + Skills_SOP)
- PR #78: docs alignment pass 2 (Git_and_Deployment + templates + skills)
- PR #79: RUNBOOK final-mile alignment

---

## v2.2.1 — 2026-05-09

> Patch: stop wiping project-local agents on sync.

### What changed

- **`scripts/sync-method.sh` agents sync** — replaced `sync_dir --delete` with per-file `sync_file` over upstream agent files. Project-local agents in `.claude/agents/` (e.g., `code-reviewer.md`, `supabase-reviewer.md`, `{library}-pitfalls.md`) now persist across syncs.

### Why

Surfaced during Piper's v2 canary (PR #235): `rsync --delete` on `.claude/agents/` would have deleted 8 Piper-local agents because upstream pipekit ships only `plan-reviewer.md`. Patched manually in PR #235 by restoring from HEAD; this is the permanent fix. Mirrors the canonical-rules pattern (`README.md`, `pipekit-*.md`), which uses `sync_file` for the same reason — consumers extend `.claude/rules/` and `.claude/agents/` with project-specific files that must survive sync.

### Migration

None. Re-run `./scripts/sync-method.sh v2.2.1` and project-local agents are preserved.

---

## v2.2.0 — 2026-05-09

> Two paired changes: **synced-folder rename** (`method/` → `pipekit/`) and **squash retirement** (merge-commit-only on `main`, squash disabled repo-wide). Breaking changes for consumers — see Migration section.

### What changed — folder rename

- **Sync target folder renamed `method/` → `pipekit/`.** All consumer-side synced content (`sop/`, `templates/`, `method.md`, `GUIDE.md`, `STARTUP.md`, `.sync-changelog.md`) now lands under `pipekit/` instead of `method/`. This Pipekit source repo's layout is unchanged — only the destination path on the consumer side moves.
- **Updated:** `scripts/sync-method.sh` (sync targets, snapshot path, override target paths), `scripts/drift-check.sh` (path filter regex), and all skill docs and templates that reference consumer-side paths (`pipekit-update`, `00-roadmap-review`, `01-light-spec`, `startup`, `templates/overrides-manifest.template.md`, `templates/rules/README.md`, `GUIDE.md`, `README.md`, `method.config.template.md`, `method.md`).
- **Unchanged:** `method.config.md` filename (still at consumer repo root), Pipekit source layout (`sop/`, `templates/`, `method.md` at root of this repo), all override paths under `.claude/overrides/`, `bin/pk`, all skills and agents.

### What changed — merge strategy

- **`scripts/pipekit-configure-repo.sh` rewritten** — repo-level `allow_squash_merge=false`; new `pipekit-main-merge-only` ruleset enforces `allowed_merge_methods=["merge"]` on PRs targeting main. The legacy `pipekit-main-squash-only` ruleset is auto-deleted on re-run.
- **`sop/Git_and_Deployment.md` § Merge Strategy by Hop** — table rewritten. Squash row removed; merge-commit is the enforced strategy for dev → main. Rebase or merge-commit are both fine for feature → dev.
- **`bin/pk` reminders updated** — `pk ship` no longer tells you to squash on main; `pk promote` PR body and prompt updated to "Create a merge commit."
- **`RUNBOOK.md`, `method.md`, `STARTUP.md`, `GUIDE.md`** — all "squash" references updated to reflect the new policy.

### Why — folder rename

`method/` was generic and confusing — both Pipekit and consumer projects used "method" interchangeably, with no signal about ownership. Renaming the synced folder to `pipekit/` makes ownership immediately legible: `pipekit/` is upstream content (don't hand-edit; gets overwritten on sync). Pairs cleanly with whatever the consumer chooses to name its own engineering workspace folder (e.g., `engineering/` for piper, `local/` for rs-vault).

The rename also eliminates a long-standing collision risk for consumers with a pre-existing `method/` folder (notably Piper, which had Piper-flavored v1 method docs there from the era when Pipekit was extracted from Piper). Sync now writes to a fresh `pipekit/` and leaves any pre-existing `method/` alone for manual dissolution.

### Why — merge strategy

v1.7.0 banned merge-commits everywhere. v1.8.0.6 reversed: rebase/merge for feature → dev, squash for dev → main. **Both schemes hit phantom conflicts in production.** Piper's `nebula-piper-migration-handoff.md:282` documents the v1.8.0.6 failure ("GitHub squash ruleset breaks parent linking. Every promote re-conflicts on files added on both sides"); rs-vault hit the identical trap on PR #173 / #175 in May 2026.

The misdiagnosis: prior versions believed "merge-commits on main cause phantom conflicts." Squash on main causes them — by collapsing N atomic dev commits into one orphan commit on main, the next promote's merge-base finds two divergent histories that both modified the same files relative to the common ancestor. Merge-commits prevent the divergence: dev's atomic commits flow onto main with stable SHAs.

The cleanup-via-squash use case (collapse messy WIP commits) doesn't apply: Pipekit's discipline rules already enforce "one atomic change per commit," and vbw-dev makes atomic commits per task. Squash was throwing away useful bisect/blame information for an aesthetic linear-history preference. `git log main --first-parent` gives the squash-equivalent view (one entry per merged PR) without the cost.

### What this fixes

- **Phantom conflicts on `pk promote`** — gone. Same SHAs flow feature → dev → main.
- **`git bisect` and `git blame` on main** — newly useful. Today main is a series of squash-mega-commits attributed to whoever clicked the merge button.
- **`git branch -d` after `pk done`** — would now succeed (latent improvement; `pk done` still uses `-D` for safety).

### Migration (consuming projects)

After `./scripts/sync-method.sh v2.2.0`:

```bash
# 1. Folder rename — sync creates pipekit/ alongside any existing method/.
#    - Verify pipekit/ has the canonical content (sop/, templates/, method.md, etc.).
#    - Move any project-specific content out of method/ to its appropriate home
#      (engineering/, .claude/overrides/, Strategy/_decisions/, etc.).
#    - Re-point references in CLAUDE.md, skills, and docs from method/* to pipekit/*.
#    - rm -rf method/ once empty.
#    - method.config.md filename unchanged — no action needed there.

# 2. Merge strategy — re-run the configure script. It will:
#    - Set allow_squash_merge=false at the repo level
#    - Delete the legacy pipekit-main-squash-only ruleset
#    - Create the new pipekit-main-merge-only ruleset
bash scripts/pipekit-configure-repo.sh
```

If you have an open dev → main PR that's hitting a phantom conflict from the prior squash policy, resolve it once with a merge-commit (or close + reopen as a no-ff merge); subsequent promotes will be clean.

For consumers with extensive `method/` customization, see Piper's worked example at `engineering/Pipekit-Migration-Plan.md` for a phased dissolution approach.

---

## v2.1.2 — 2026-05-03

> Session-log redesign: bash Stop hook retired, narrative `/pk-exit` skill restored.

### What changed

- **`/pk-exit` skill (new)** — writes a narrative session log to `Logs/Sessions/<YYYY-MM-DD>_<HHMM>.md` before `/exit`. Captures summary, commits shipped, decisions/findings, outstanding work, optional QA trail. Restores the v1 `/end-session` artifact shape without the v1 baggage. User runs as the last command of every Claude Code session; no auto-trigger (forget = no log, accepted tradeoff).
- **Bash Stop hook retired (`scripts/pipekit-journal-hook.sh` deleted)** — fired on every assistant turn, dumped duplicate commit-list entries to `.pipekit/journal/<branch>.md`, couldn't write narrative anyway. The per-branch journal cache it produced is no longer used.
- **`pk done` reads commits directly from `git log`** for its Linear close comment (was: read from `.pipekit/journal/<branch>.md`). Same Linear output, simpler source of truth, no cache to drift.
- **`pk log` repointed** at `Logs/Sessions/` — shows the latest session log instead of the per-branch journal cat.
- **`pk init` / `pk doctor`** create/verify `Logs/Sessions/` and flag stale Stop-hook artifacts (`scripts/pipekit-journal-hook.sh`, Stop block in `.claude/settings.json`, `.pipekit/journal/`) so consuming projects can clean up post-upgrade.
- **`templates/v2/settings-snippet.json` deleted** — no Stop hook to wire anymore. `pk init` setup steps reduced from 7 to 6.
- **`method.config.template.md`** drops the `Journal in repo` config key (no longer used).
- **`RUNBOOK.md`** updated end-to-end: setup step removed, flowchart shows `/pk-exit → /exit` as the close-of-session sequence, recovery row covers "forgot to run /pk-exit", v1↔v2 table maps `/end-session → /pk-exit`.

### Why

The v2.0 bash Stop hook was structurally wrong on three axes: (1) Stop fires on *every* assistant turn, producing 4-10 duplicate entries per session with the same commit list — see `chore-v2.0.0-cleanup.md` from 2026-05-02 with identical commit blocks 4 times; (2) bash can't write narrative, so the entry was just `git log -5` repeated, missing the decisions/lessons/QA-trail content that made v1 session logs actually useful; (3) the per-branch journal it wrote was a cache of git log, and `pk done` was the only consumer — repointing at `git log` directly removed the entire cache without losing anything.

The v1 `/end-session` skill's session-log shape (compare `rs-vault/Logs/Sessions/2026-04-26_1555.md` vs `.pipekit/journal/chore-v2.0.0-cleanup.md`) was strictly better as a human archive. `/pk-exit` restores that artifact while keeping the v2 simplifications (no NEXT.md write, no branch-status orchestration — `pk next` and `pk done` own those).

### Migration (consuming projects)

After `./scripts/sync-method.sh v2.1.2`:

```
# Remove the Stop hook block from .claude/settings.json (pk doctor will flag it).
# Delete the retired hook script:
rm scripts/pipekit-journal-hook.sh
# Existing .pipekit/journal/ is gitignored and harmless — dies with branches on `pk done`.
# Run pk doctor to confirm Logs/Sessions/ exists; pk init creates it if not.
```

End every Claude session with `/pk-exit` → `/exit`.

---

## v2.1.1 — 2026-05-02

> Notepad convention: replaces retired v1 NEXT.md.

### What changed

- **`pk init` seeds a gitignored `notepad.md`** if one doesn't already exist, and ensures `.gitignore` excludes it. Free-form personal scratch space; never committed.
- **`.gitignore` (pipekit's own)** adds `notepad.md` for pipekit-side development.
- **`method.md` documents the convention** — NEXT.md is officially retired; consuming projects should delete any committed NEXT.md and rely on `pk next` for canonical "what's next?".
- **`pk init` flags stale NEXT.md** if found, suggesting the cleanup command (does not auto-delete — user's call).

### Why

v1's `NEXT.md` was machine-readable state. v2's `pk next` (phase-aware as of v2.1.0) replaces that role. Consuming projects kept editing `NEXT.md` manually as a personal notepad, which created git-status churn + drift from any auto-source. `notepad.md` (gitignored) is the right shape for that use case.

---

## v2.1.0 — 2026-05-02

> Three improvements surfaced during rs-vault Phase 2.5 execution. Same-day v2.0.0 → v2.1.0.

### What changed

- **`/pr-security-review` skill** (new) — security-focused antagonistic PR review for migrations, RLS policies, SECURITY DEFINER functions, GRANT/REVOKE, auth code, and Server Actions on privileged tables. 30+ rubric items across 6 surface categories. Different from `/security-review` (periodic repo audit) and `/pr-fix` (broad PR review). Surfaced by RS-74 (rs-vault saved_searches migration) where neither existing skill fit the security-focused PR-diff need.
- **Phase-aware `pk next`** — reads `## Current Phase:` from `.vbw-planning/PHASES.md`, matches to `linear-map.json` project entry via `Phase X.Y` prefix (handles em-dash vs colon separator drift), groups Linear results by status: In Progress / Approved / Needs Spec, with per-group next-action hints. Surfaces "Other phases: N Approved outside" footer. Falls back to legacy global behaviour when no phase context is available. Surfaced by Phase 2.5 having 6 Needs Spec issues + RS-63 In Progress while old `pk next` reported nothing.
- **Mid-loop Linear visibility for `pk ship --review` + `/pr-fix`** — `pk ship --review` now posts a Linear comment flagging the review-in-flight; `/pr-fix` Phase 6.6 posts a triage-complete summary with fixed/rejected/deferred counts. Closes the gap where Linear sees `In Progress → UAT → Done` but no record of the review/fix cycle's findings.

### v2.1 backlog still open (deferred to v2.1.x or v2.2)

- `resources/` vs `temp/` portable convention + `pk branch` worktree resource sync
- Cross-spec handoff verification at flowchart level (skill prose already shipped in v2.0; flowchart promotion deferred)
- Visual + functional verification step in flowchart (Playwright + diff infra — too big for same-day cut)
- "Defended status quo" guardrail at flowchart level (already in `/work` prose; flowchart promotion deferred)
- `/ship` skill auto-dispatch (subagent boundary — see `temp/ship-skill-spec.md`)

---

## v2.0.0 — 2026-05-02

> Cut to v2 after RS-63 proved the v2 ↔ VBW handshake on a Heavy spike (rs-vault). v1 daily-loop skills retired to `archive/v1-skills/`. v2 is now the canonical Pipekit.

### What changed at the cut

- **`bin/pk` is the dispatcher.** All daily-loop work goes through `pk next / pk branch / pk ship / pk done / pk promote`. Idempotent against Linear+git ground truth.
- **`/work` + `/verify`** replace the v1 launch chain. `/work --backend=vbw|native` chooses execution backend per-invocation.
- **`RUNBOOK.md`** is now the v2 one-page flowchart (was `V2_RUNBOOK.md`). Old runbooks archived.
- **`method.md`** carries a v2 transition banner; full rewrite queued for v2.0.1.

### v1 retirement (skills moved to `archive/v1-skills/`)

`/branch`, `/launch`, `/launch-native`, `/start-session`, `/end-session`, `/linear-status`, `/g-promote-dev`. All replaced by `pk` subcommands or the Stop hook (journal). Stage 0 skills (`/concept`, `/define`, `/strategy-create`, `/startup`, `/roadmap-create`, `/phase-plan`) and orthogonal skills (`/light-spec`, `/brainstorm`, `/pr-fix`, `/sync-linear`, etc.) are unchanged — v2 only retires the daily loop.

### Validation

- rs-vault Phase 1 closeout (RS-25, RS-30, RS-60, RS-61, RS-62) shipped on the v2 loop
- RS-63 (Phase 2.5 Foundation + Search redesign) — Heavy spike, vbw backend, antagonistic review, /pr-fix triage all worked end-to-end
- DB migration auto-apply workflow (`db-migrate.yml` + `db-pr-check.yml`) shipped, secrets verified via dry-run

### Known gaps (v2.0.1)

- `method.md` still references v1 paths (banner added, rewrite queued)
- `sync-method.sh` may copy v1 skill paths — needs audit
- See `RUNBOOK.md § Backlog` for alpha.15-style improvements that didn't land at the cut: phase-aware `pk next`, `resources/` vs `temp/` portable convention, `/ship` skill auto-dispatch

---

## v2.0.0-alpha — 2026-05-01 → 2026-05-02

> Pre-cut development. 14 alphas across two days. v2/main long-running branch.

### What v2 is

A `pk` shell dispatcher + `/work` and `/verify` skills replace the heavy multi-step v1 launch chain. The daily loop is `pk next → pk branch <ID> → /work <ID> → pk ship → pk done → pk promote`. Idempotent at every step; runs from a worktree.

### Highlights across 13 alphas

- **`bin/pk`** — daily-loop dispatcher (next, status, branch, ship, done, verify, promote, log, doctor, delegate). Idempotent + safe to re-run.
- **`/work`** — plan + execute a Linear issue from inside its worktree. Backend-pluggable (`vbw` | `native`), now overridable per-invocation via `--backend=`.
- **`/verify`** — pre-ship validation skill paired with `pk ship --review` for antagonistic code review.
- **Worktree pk-sync** — `pk branch` copies the parent's `bin/pk` into the worktree so feature work always uses the project's pinned dispatcher version (alpha.12).
- **Stop hook** — `scripts/pipekit-journal-hook.sh` writes a per-feature branch journal on every Claude Code Stop event.
- **Short slugs** — `pk_slug` strips stop words and trims to 3 tokens, keeping worktree paths and status bars sane.
- **REST fallback** — `pk_gh_pr_view` and `pk_gh_pr_create` fall through to GitHub REST when GraphQL is rate-limited (alpha.13). Caught the friction of GraphQL exhaustion silently misreading as "PR not found."
- **Linear robustness** — single-line GraphQL queries, minimal field selections, `.env.local` fallback for the API key, team-name filtering on state transitions.

### Alpha.14 (latest)

- `pk install` global installer — symlinks pk onto `$PATH` (`/usr/local/bin` or `~/.local/bin`); idempotent through the installed symlink
- `pk done` richer Linear comment — commits, diffstat, session count, PR link (replaces raw 50-line journal head dump)
- `pk promote --stash` / `--take-remote` flags — resolve local-edit conflicts with incoming dev (today's friction pattern)

### Alpha.13

- gh REST fallback for `pr view` / `pr create` — initially fallback-only, then **inverted to REST-first** after a session-wide GraphQL exhaustion proved the fallback wasn't enough. REST has its own quota bucket; pk no longer burns GraphQL on normal operation
- `/work --backend=vbw|native` per-invocation override
- Brainstorm skills updated for v2 tier routing (`/brainstorm`, `/brainstorm-review`)
- This consolidated changelog entry

### Carried into beta candidates

- Multi-env `pk ship --env=` for Piper-style multi-environment delivery
- Automated subagent dispatch from `pk ship --review` (currently prints invocation)
- `pk done` richer Linear comments from journal highlights
- `pk install` global installer
- Skills directory reorg: `skills/{loop,stage0,orthogonal}/`
- GitHub Actions `pr-review.yml` (CI-side antagonistic review)

### Notes

- v2 is **not** synced via `sync-method.sh` yet — the script's v2 paths exist but consuming projects pull `bin/pk` and the new skills directly.
- The full v2 design rationale lives in `archive/v2-design-2026-05-01/` (5 design docs from the redesign session).

---

## v1.8.2 — 2026-04-30

### Fixes

Four bugs surfaced in the v1.8 code review (v1.7.0..v1.8.1). All Quick-tier fixes, no behavior changes for the happy path.

- **`/start-session`** — Pre-flight `INTEGRATION` resolver was a literal `$(...)` placeholder. The skill couldn't run end-to-end on a feature worktree. Inlined the same fallback chain `/end-session` Step 0a uses.
- **`/end-session`** — Pre-flight B used a no-op `INTEGRATION="$INTEGRATION"` self-assignment with a forward reference to Step 0a. Inlined the resolver so Pre-flight B is self-contained; Step 0a still refines from `method.config.md` afterward.
- **`/g-promote-dev` Step 3** — Bare `$GATE_CMD` only invoked the first command in an `&&` chain; `&&` became a literal arg. Wrapped in `eval` so the shell parses the chain.
- **`/g-promote-dev` Step 5** — Removed misleading "drop the `-u`" advice. `-u` is idempotent; the actual non-fast-forward case was already documented correctly in the next sentence.

### Filed for v1.9.0

Three issues drafted from the same review, deferred:

- `pipekit-configure-repo.sh` hardening — Rulesets PUT preserves bypass actors, auth/admin precheck, error surfacing
- `/g-promote-dev` Linear-state ownership — three skills now transition the same issue; canonical ownership map needed
- `/launch --auto` refactor — define stalemate overlap precisely, fix Revise default ordering, consider state-machine restructure

Drafts in `temp/issue-v1.9-*.md`.

---

## v1.8.1 — 2026-04-30

### What's New

**`/g-promote-dev` ported from project-local copies into Pipekit.** First skill in the `/g-*` port (v1.8.1–v1.8.5). Eliminates divergence between rs-vault's and piper's project-local copies; bug fixes propagate via `/pipekit-update`.

#### `skills/g-promote-dev/skill.md` (NEW)

Parameterized via `method.config.md`. Reads:

- § Linear → Issue prefix (e.g. `RS`, `PROJ`)
- § Linear → Workflow State IDs → In Progress
- § Git Architecture → Integration branch (`dev`)
- § Pre-Deploy Gate
- § Stack → Hosting (`vercel` | `none`), DB push command (e.g. `supabase db push`), Migration dir, Shared DB across environments

Skips capabilities gracefully when stack values are missing (no Vercel? No DB? Skill still works for the PR-only path).

The migration push step (was hardcoded for rs-vault's shared Supabase) is now config-driven:
- If `DB_PUSH_CMD` empty → skip migration step entirely
- If `SHARED_DB=yes` → warn about forward-mutation, default-no on push prompt
- If `SHARED_DB=no` → default-yes on push prompt (separate dev/prod DBs make this safe)

#### `method.config.template.md` — § Stack section (NEW)

New keys for skill parameterization:

| Key | Used by |
|---|---|
| Hosting (`vercel` \| `none`) | `/g-test-vercel`, `/g-deploy` |
| DB push command | `/g-promote-dev` |
| Migration dir | `/g-promote-dev` |
| Production smoke URL | `/g-deploy` |
| Shared DB across environments (`yes` \| `no`) | `/g-promote-dev` |

### Migration

For rs-vault and other consumers with project-local `/g-promote-dev`:

```bash
./scripts/sync-method.sh v1.8.1
```

Pipekit's parameterized `g-promote-dev` will replace the project-local copy. Before running, verify your `method.config.md` has:
- § Linear → Issue prefix ✓
- § Linear → State IDs → In Progress ✓
- § Pre-Deploy Gate ✓
- § Stack section populated (NEW — copy from `method.config.template.md`)

For rs-vault specifically: Stack section should set `Hosting=vercel`, `DB push command=supabase db push`, `Migration dir=supabase/migrations/`, `Shared DB across environments=yes` to preserve current behavior.

If you need to keep the project-local version (e.g. piper hasn't migrated yet), place it at `.claude/overrides/skills/g-promote-dev/skill.md` — sync-method.sh will preserve the override.

### Open items deferred to v1.8.2 – v1.8.5

- v1.8.2: `/g-promote-main` port
- v1.8.3: `/g-test-vercel` port
- v1.8.4: `/g-deploy` port
- v1.8.5: `/g-promote-beta` port (three-tier flows; piper-relevant)

---

## v1.8.0.6 — 2026-04-30 (patch)

### What changed

**Per-branch merge enforcement via GitHub Rulesets.** Earlier patches (v1.7.0–v1.8.0.5) disallowed merge-commits at the repo level to prevent the phantom-conflict trap on `main`. That's machine-safe but blunt — also bans merge bubbles on `dev`, which some users prefer for feature-branch readability in GitKraken / git-log.

v1.8.0.6 switches to per-branch enforcement:

- **Repo level**: all three merge methods enabled (rebase + squash + merge-commit).
- **`pipekit-main-squash-only` ruleset**: enforces squash-only on `main`. UI dropdown will only show "Squash and merge" for PRs targeting main.
- **Net effect**: feature → dev gets the user's choice (rebase or merge-commit). dev → main is squash, machine-enforced. Mistakes on the dangerous hop are impossible.

`scripts/pipekit-configure-repo.sh` extended to handle both — repo-flag PATCH plus ruleset create-or-update via `POST/PUT /repos/<org>/<repo>/rulesets`. Idempotent. The ruleset name is `pipekit-main-squash-only` so re-runs find and update the existing rule rather than creating duplicates.

### Touched

- `scripts/pipekit-configure-repo.sh` — full rewrite. 2 steps: repo-level flags + ruleset.
- `RUNBOOK.md` § One-time setup — updated table; recommends rulesets-based config.
- `sop/Git_and_Deployment.md` § Merge Strategy by Hop — explains the per-branch model + why the change.

### Migration

`./scripts/sync-method.sh v1.8.0.6` then `bash scripts/pipekit-configure-repo.sh <org>/<repo>`. The script will:
1. Re-enable `allow_merge_commit` at the repo level (was disabled by v1.7.0–v1.8.0.5).
2. Create the `pipekit-main-squash-only` ruleset.

If you want to keep the v1.8.0.5 behavior (merge-commits disallowed globally), just don't run the configure script.

---

## v1.8.0.5 — 2026-04-30 (patch)

### What changed

**`/branch finish` clarified — accepts explicit slug arg, auto-detects merged worktrees.** Live RS-59 observation: RUNBOOK step 13 said "exit + /branch finish" but didn't make clear that /branch finish runs from the parent repo (not from inside the worktree being removed), and the skill itself didn't define how it would identify the right worktree if multiple existed.

This patch:

- **`skills/branch/skill.md`** — Finish subcommand now documents the run-from-parent contract explicitly and adds a 3-tier resolution algorithm: (1) explicit slug arg matches a worktree path; (2) running from inside a worktree errors with a clear "exit and re-run from parent" message; (3) no-arg in parent auto-detects merged-on-origin worktrees, confirms the unambiguous one, or asks user to pick from multiple.
- **`RUNBOOK.md`** — step 13 split into Part A (exit) + Part B (cd to parent, run /branch finish). Notes that squash-merge breaks `git branch -d`'s ancestry check; `-D` is the correct response.

### Migration

`./scripts/sync-method.sh v1.8.0.5`. Pure documentation + skill-prose change; no behavior change unless you were relying on `/branch finish` running from inside the worktree (which fails today regardless).

---

## v1.8.0.4 — 2026-04-30 (patch)

### What changed

**QA-Pass default is now `pause-for-end-session`, not `close-now`.** Live RS-59 observation: /launch --auto's QA-Pass prompt still recommended `close` as the default action, which routes through the v1.7.0 cherry-pick path and defeats v1.8.0's "one PR per issue" model.

The recommended flow on QA Pass is:

1. `pause-for-end-session` (new default) — exit cleanly so the user can run `/end-session` (writes log + NEXT.md to the feature branch), then `/launch --close` (opens the single bundled PR). One PR. No cherry-pick.
2. `close-now` (legacy, preserved) — old v1.7.0 behavior; closes immediately, requires cherry-pick of the session log later.

Touched: `skills/launch/skill.md` auto-chain mode step 6 prose. Fail/Partial defaults unchanged (`pause-here`).

### Migration

`./scripts/sync-method.sh v1.8.0.4`. No breaking changes — `close-now` is still available for users who prefer the v1.7.0 flow.

---

## v1.8.0.3 — 2026-04-30 (patch)

### What changed

**`/launch --auto` no longer auto-advances on Revise.** Live RS-21 observation: plan-reviewer returned Revise, Lead applied the fixes, and `--auto` proceeded straight to Dev — without re-spawning plan-reviewer to validate the revised plan. The user did not approve skipping re-review. The "verdict gate" was effectively a no-op for Revise.

Root cause: skills/launch/skill.md treated Revise as a soft-pass — `proceed on Pass / Revise; abort on Block`. That's wrong. Revise's whole purpose is "fix and re-review."

v1.8.0.3 implements round-2 plan-review on Revise:

1. Round 1 Revise → spawn Lead to apply blocking fixes
2. **Re-spawn plan-reviewer with the revised PLAN.md (NEW)**
3. Round-2 verdict: Pass → Dev; Revise → loop to round 3; Block → abort
4. **Stalemate detection at round 3+**: if round 3's Revise verdict overlaps with round 2's blocking items, pause and surface to user. No auto-loop on round 4.

An explicit override `proceed-without-re-review` exists for the rare case where the user genuinely wants to skip re-review. The override is logged to the pipeline state file (`override: "skip-plan-review-round-2"`).

### Touched

- `skills/launch/skill.md` — auto-chain mode step 3 expanded with round-2 logic; "proceed on Pass / Revise" wording removed in 3 places
- `RUNBOOK.md` — plan-review verdict decision-point table updated with new defaults

### Migration

`./scripts/sync-method.sh v1.8.0.3`. No behavior change in Pass or Block paths. Revise now defaults to `apply-fixes-and-re-review` instead of `proceed`. If you rely on the old soft-pass behavior, use the explicit `proceed-without-re-review` option.

---

## v1.8.0.2 — 2026-04-30 (patch)

### What changed

**Default `/launch` recommendations to `--auto`.** Live test on RS-21 surfaced that /start-session offered "say `/launch RS-21` (or `go` and I'll fire it)" — without `--auto`. The bare form skips the auto-chain orchestration that's the whole point of v1.6.0+. Default should match the canonical Standard-tier path.

Three skill prose updates:

- **`/start-session`** — new step 9 explicitly offers the next command in `--auto` form (Standard tier). Tier handling: Standard → `--auto`, Heavy → plain `/launch` (since `--auto` rejects Heavy), Quick → `/06-linear-todo-runner`.
- **`/end-session`** — NEXT.md recompute writes `/launch RS-XX --auto` instead of bare `/launch RS-XX`. Same tier exceptions.
- **`/launch --close`** — close-time NEXT.md logic emits `/launch {next issue} --auto`. Same tier exceptions.

### Migration

`./scripts/sync-method.sh v1.8.0.2`. No behavior change in the auto-chain itself; only what gets recommended in NEXT.md and what /start-session offers to fire.

---

## v1.8.0.1 — 2026-04-30 (patch)

### What changed

**`/start-session` paired with `/end-session` inside the worktree.** v1.8.0 left an asymmetry: /start-session ran in the parent on dev, /end-session ran in the worktree on the feature branch. They didn't bracket the same scope, and /start-session's NEXT.md view could go stale before the user even got to the worktree.

v1.8.0.1 moves /start-session into the worktree as the kickoff command (after `/branch` and entering the worktree). It now refreshes NEXT.md from `origin/<integration>` tip the same way /end-session does — so both ends of the session see current state.

The parent-on-dev case is preserved: /start-session still works there as a "what should I work on?" view (no refresh, since you're already on integration). The pre-flight only triggers on a feature branch.

### Touched

- `skills/start-session/skill.md` — Pre-flight section added (NEXT.md refresh on feature branch; pass-through on integration)
- `RUNBOOK.md` — loop reordered to 13 steps. Step 0 is now lightweight issue-picking in parent; step 3 is /start-session in worktree (paired with step 9's /end-session). Quick Index TOC updated. Decision tree updated to show the parent/worktree boundary clearly.

### Migration

`./scripts/sync-method.sh v1.8.0.1` pulls the updated /start-session + RUNBOOK. No breaking changes — old order still works, but the new one pairs cleanly.

---

## v1.8.0 — 2026-04-30

### What's New

**One-PR-per-issue release.** Three coupled fixes that close the cherry-pick friction observed during RS-22 work and tighten the per-issue loop. Closes #15, #16, #17.

#### `/end-session` re-orders before `/launch --close` (closes #15)

The biggest day-to-day friction in v1.6.0/v1.7.0: /end-session ran *after* /launch --close, so the session log + NEXT.md update landed on a feature branch *after* PR merge — orphaned unless cherry-picked. The runbook documented a workaround that cost one extra PR (5-min gate-check tax) per issue.

v1.8.0 reverses the order: **/end-session runs first, /launch --close second.** Both inside the worktree, on the feature branch. The session log + NEXT.md update commit to the feature branch *before* the PR opens; /launch --close then bundles everything into the single PR. **One PR per issue. No cherry-pick.**

Two coupled changes inside /end-session:

1. **Integration-branch refusal.** /end-session refuses to run if the current branch is `dev` or `main`. Pre-flight A added; clear error message points to RUNBOOK.md § The loop step 10. Prevents accidental direct-to-integration writes.
2. **NEXT.md base refresh.** Inside the feature worktree, NEXT.md is a snapshot from when `/branch` ran. If a parallel session has shipped to dev since, the snapshot is stale. Pre-flight B fetches `origin/<integration>` and `git checkout`s NEXT.md to the current dev tip *before* recomputing. Race window shrinks from "hours of work in worktree" to "minutes between /end-session and PR merge."

#### Short branch names from `/branch --linear` (closes #16)

`/branch --linear RS-21` used to produce `feature/ethan/rs-21-record-edit-delete-with-change-tracking` (40+ chars, awkward in TUIs and PR titles, derived from Linear's verbose `gitBranchName`).

v1.8.0 derives a short slug from the Linear title: **`feature/RS-21-edit-delete`** (issue ID + 2-3 meaningful words). Algorithm is deterministic — same Linear title always yields the same slug. Stopwords (`with`, `and`, `the`, `for`, `of`, `to`, `in`, `on`, `a`, `an`, `change`, `tracking`, `record`) are stripped before picking the first 2-3 words.

The printed spawn hint also updates: `cd .worktrees/<branch> && claude --dangerously-skip-permissions` — saves a manual flag every time.

#### Recommended merge strategy: rebase feature→dev, squash dev→main (closes #17)

Squash-merging *everything* (v1.7.0's recommendation) flattens atomic per-task commits on dev — unreadable in GitKraken/git-log, useless for `git blame` per task, breaks `git bisect`. Squash-merging dev → main is correct (kills phantom-conflict topology), but feature → dev should preserve atomic commits.

v1.8.0 documents the right combination:

| Hop | Strategy |
|---|---|
| feature/* → dev | **Rebase** (preserves atomic commits as a linear sequence) |
| dev → main | **Squash** (one release commit; kills merge-commit topology) |
| Anything → merge-commit | **Disabled** (creates phantom conflicts on subsequent promotes) |

New `scripts/pipekit-configure-repo.sh` flips all four GitHub repo settings idempotently in one shot:

```bash
bash scripts/pipekit-configure-repo.sh <org>/<repo>
```

Updated: `RUNBOOK.md` § One-time setup, `sop/Git_and_Deployment.md` § Merge Strategy by Hop. The actual flip is per-consumer (Pipekit doesn't enforce repo settings — it recommends).

### Migration

For consuming projects on v1.7.0:

1. `./scripts/sync-method.sh v1.8.0` — pulls updated `/branch`, `/end-session`, `/launch` skills, `Git_and_Deployment.md`, `RUNBOOK.md`, and the new `scripts/pipekit-configure-repo.sh` helper.
2. **Configure your repo's merge strategy:**
   ```bash
   bash scripts/pipekit-configure-repo.sh <org>/<repo>
   ```
3. **New per-issue loop** — see `RUNBOOK.md` § The loop. The order is now: `/end-session` → `/launch --close` → rebase-merge PR → `/branch finish`. The cherry-pick workaround documented in v1.7.0 is removed.
4. No config / template / state-ID changes. Old per-issue flow (`/launch --close` first, /end-session after, cherry-pick log) still works if invoked in that order — but strongly prefer the new order.

### Open items deferred to v1.8.1

- **Port `/g-promote-dev`, `/g-promote-main`, `/g-test-vercel`, `/g-deploy`, `/g-promote-beta`** from rs-vault/piper into Pipekit with parameterization via `method.config.md`. Currently these are project-local copies, diverged between consumers. Folding them into Pipekit closes the per-issue + promotion loop end-to-end.

### Open items deferred to v1.9.0

- `/pipekit-resume` — state-file consumer for cross-session resumption (carried forward).
- Diagnostic gate output (no more bare `REMEDIATION_REQUIRED`).
- Orchestrator-side permission-denial detection (carried since v1.4.0).

---

## v1.7.0 — 2026-04-30

### What's New

**Bug-fix release closing the silent-drop gap left in v1.6.0.** Single observation from rs-vault RS-22 (real-time, 2026-04-29 → 2026-04-30) drove the whole release: the v1.6.0 NEXT.md defer mechanism only worked for non-VBW-scoped writers, exactly the case it was *not* meant to fix.

#### Pipekit machine-local state moved out of repo (closes #13)

v1.6.0 placed the deferred-NEXT.md queue and pipeline-state records inside the repo at `<repo>/.pipekit/`. VBW's file-guard hook blocks any in-repo write that isn't in the active plan's `files_modified` field. The queue file written to dodge the original block hit the same wall — net result: continued silent audit-trail loss, just one level deeper.

The fix: relocate Pipekit's machine-local state to `${XDG_CACHE_HOME:-~/.cache}/pipekit/<repo-basename>/`, resolved consistently by the new `scripts/pipekit-state-dir.sh` helper. VBW's file-guard never inspects paths outside the repo, so writes succeed unconditionally — no more best-effort, no more silent drops.

```bash
# Resolve the path
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)

# Pipekit's directory layout (per consuming project):
#   ${XDG_CACHE_HOME:-~/.cache}/pipekit/<repo-basename>/
#     ├── pending-next-md.json     (NEXT.md defer queue)
#     ├── pending-strategy-sync    (post-archive marker)
#     └── pipeline-state/<issue-id>.json
```

Touched: `sop/Skills_SOP.md`, `method.md`, `VBW_COMMANDS.md`, `templates/tier-heavy.md`, seven skills (`/review-plan`, `/launch`, `/end-session`, `/06-linear-todo-runner`, `/start-session`, `/10-strategy-sync`, `/pipekit-help`), `scripts/pipekit-post-archive.sh` (with inline fallback for mid-upgrade safety), `scripts/verify-next-md-defer.sh` (asserts STATE_DIR is outside repo). The verify script's round-trip dogfood passes against the new path.

#### Sync script reliability fixes

- `--dry-run` now survives the self-update re-exec path (prior shift-based parser silently dropped the flag) — `fix(sync): preserve --dry-run across self-update re-exec` (47e0f9d).
- `diff -rq` exit-1-on-difference no longer kills `--dry-run` under `set -o pipefail` — `fix(sync): tolerate diff -rq exit 1 in --dry-run pipelines` (2b400ef).

These two latent bugs surfaced once `--dry-run` actually started running.

#### Repo URL update

Pipekit moved from `ethan-piper/pipekit` to `withpiper/pipekit`. Updated `METHOD_REPO` default, README/GUIDE/STARTUP install instructions, and `/pipekit-update` + `/startup` curl URLs (417c266). Old URL still redirects, so existing consumers don't break — but pin to v1.7.0+ to pick up the canonical reference.

### Migration

For consuming projects on v1.6.0:

1. `./scripts/sync-method.sh v1.7.0` — pulls updated skills, SOPs, the new `scripts/pipekit-state-dir.sh` helper, and the relocated `verify-next-md-defer.sh`.
2. **One-shot move existing state out of repo** (skip if `.pipekit/` is empty or absent):
   ```bash
   STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
   mkdir -p "$STATE_DIR"
   mv .pipekit/* "$STATE_DIR/" 2>/dev/null
   rmdir .pipekit 2>/dev/null
   ```
   Files are ephemeral; a clean wipe (`rm -rf .pipekit`) is also fine — queue and state files self-recreate on next write.
3. Optionally remove `.pipekit/` from `.gitignore` — Pipekit no longer writes there. Harmless to leave.
4. No config / template / state-ID changes. No breaking API changes.

### Open items deferred to v1.8.0

- `/pipekit-resume` — state-file consumer skill for cross-session resumption (carried forward from v1.6.0/v1.7.0).
- Orchestrator-side permission-denial detection (carried forward from v1.4.0).
- /end-session writes session log onto the merged feature branch (orphan unless cherry-picked) — friction observation from RS-19 + RS-22 closes; right fix is for /end-session to write to integration directly.

---

## v1.6.0 — 2026-04-29

### What's New

**Workflow-friction release.** Two issues closing observations from rs-vault RS-19 (real-time, 2026-04-29). Together they cut per-issue Standard-tier human input count from 6+ down to 3, while fixing a silent audit-trail loss at the Pipekit/VBW boundary. Order matters: #12 ships first because reliable NEXT.md and state-file writes are the substrate #11 builds on.

#### `/launch --auto` auto-chains non-decision pipeline transitions (closes #11)

New `--auto` flag on `/launch` (Standard tier only) orchestrates the full pipeline — `vbw:vbw-lead` → `plan-reviewer` → `vbw:vbw-dev` → `vbw:vbw-qa` → `--close` — pausing only at the two real decision points: the plan-review verdict and the QA verdict. Total human inputs drop from 6+ command re-types (per stage) to 3 (tier confirm + plan-review verdict + QA verdict). The actual cost reduction isn't keystrokes — it's the 5–120 minute resumption tax when the user walks away mid-pipeline and has to context-load on return.

```
/launch RS-19 --auto    # Standard tier
/launch RS-19           # unchanged — manual chaining still supported
```

Each pipeline stage runs as a **fresh Task-spawned subagent**, so the fresh-chat discipline (`method.md` § Fresh-Chat Discipline) is preserved by construction: the orchestrator's conversation context never bleeds into Lead, plan-reviewer, Dev, or QA reasoning. Agents see prior stage output as documents (PLAN.md, REVIEW.md, VERIFICATION.md), not as recalled conversation. This is the load-bearing constraint — no plan-review skip on "trivial" plans, no QA skip on "low-risk" specs. Auto-chain reduces transition friction; it does not lower the gate bar.

Tier handling: Quick → delegates to `/linear-todo-runner` (already auto-chained); Standard → runs the orchestration; Heavy → rejected with a clear message (security review + mandatory `/strategy-sync` gates intentionally human-paced). Permission-denial protocol from v1.4.0 is carried into the spawned Dev task description so hook-driven blocks surface immediately rather than burning turns.

#### NEXT.md write defers under VBW active-plan scope (closes #12)

Real-time observation during rs-vault RS-19's plan-review: VBW's file-guard hook blocked `/review-plan`'s `NEXT.md` write because NEXT.md was not in the active plan's `files_modified` field. The verdict was delivered correctly above the hook error; the audit-trail write was lost silently. Per `method.md` § VBW / Pipekit Ownership Model, NEXT.md is unambiguously Pipekit's — but VBW's hook can't tell that.

The fix (Option A in #12, Pipekit-side, ships in v1.6.0): Pipekit skills that update NEXT.md inside potential VBW-scoped contexts (`/review-plan`, `/launch --close` mid-session, etc.) now run a deferral check. If active-plan scope is detected and NEXT.md is not whitelisted in the plan's `files_modified`, the write is queued to `.pipekit/pending-next-md.json` instead. `/end-session` applies the queue atomically on next session-end, then deletes the queue file (no persistent cruft, per AC).

The inline `➜ Next:` line is **not** deferred — the user still sees their next-command in terminal output of the current skill. Only the file write defers. If/when VBW lands an upstream `always_allow` allowlist for the file-guard hook (Option B in #12, parallel track), the queue mechanism becomes redundant but does not break — both paths coexist gracefully.

A new helper, `scripts/verify-next-md-defer.sh`, dogfoods the round-trip end-to-end against an ephemeral fake project tree. Re-run after any future edit to the deferral mechanism.

#### Pipeline state file (supports `--auto` and future resumption)

Pipeline skills (`/launch` open + `--close`, `/review-plan`, `/linear-todo-runner`) now write a small JSON record to `.pipekit/pipeline-state/<issue-id>.json` at each meaningful state transition: `stage`, `verdict`, `next_command`, `cwd`, `timestamp`. Schema documented in `sop/Skills_SOP.md` § Pipeline state file. Consumed by `/launch --auto` for chain-progress tracking; the state-file writes lay the substrate for `/pipekit-resume` (deferred to v1.7.0) to recover cross-session.

State-file writes that hit a hook block during VBW active-plan scope are best-effort — skip silently rather than failing the skill. The orchestrator reconstructs from VBW state where needed.

### Migration

For consuming projects on v1.5.0:

1. `./scripts/sync-method.sh v1.6.0` — pulls updated `launch`, `review-plan`, `end-session`, `06-linear-todo-runner` skills, plus `Skills_SOP.md`, `method.md`, and the new `scripts/verify-next-md-defer.sh` helper. The new `.pipekit/pipeline-state/` directory is created lazily on first write — no upfront scaffold needed.
2. **Add `.pipekit/` to `.gitignore`** if not already present. The directory holds ephemeral, per-machine state (queue file, pipeline-state records, strategy-sync marker) and must not be committed.
3. No config changes. No template changes. No new state IDs.
4. No breaking changes. Existing `/launch` invocations without `--auto` behave identically to v1.5.0. NEXT.md writes outside VBW active-plan scope behave identically (the deferral check returns `DEFER_NEXT_MD=0` and the direct write proceeds as before).

### Open items deferred to v1.7.0

- **`/pipekit-resume`** — state-file consumer skill that reads `.pipekit/pipeline-state/<issue-id>.json` to resume an interrupted `/launch --auto` chain across Claude Code session boundaries. The state file is written now so the data exists when the consumer ships.
- **Orchestrator-side permission-denial detection** — carried forward from v1.4.0 → v1.5.0 → v1.6.0. The agent-side stop instruction is now in v1.6.0's `--auto` Dev spawn; the orchestrator-side proactive surfacing (without depending on agent compliance) remains open.
- **Option B (VBW-side `always_allow` allowlist)** — upstream coordination required. When it lands, supersedes the v1.6.0 queue mechanism for projects that adopt the VBW config. Both paths coexist safely in the meantime.

---

## v1.5.0 — 2026-04-28

### What's New

**Productivity skills release.** Two new portable skills closing recurring friction observed across the v1.4.x release cycle (rs-vault Phase 1 closeout, four Pipekit releases shipped 2026-04-27). Both are read-only by design and slot cleanly into existing pipeline positions — no behavioral changes to `/launch`, `/light-spec`, or any prior skill. Clean sync from v1.4.1 (no breaking changes, no config migration).

#### `/spec-preflight` automates empirical pre-flight checks on specs (closes #9)

New skill that verifies a Linear issue's spec against reality before `/launch`. Parses file paths, line citations, phase-detect baselines, Linear status, and dependency claims from the spec body and confirms each against the actual project state. Slots between Spec Review Agent (which reviews narrative coherence) and `/launch` (which validates gates).

```
/light-spec → Spec Review Agent → human approval → /spec-preflight → /launch
```

Catches the empirical-drift class of defect agent review structurally cannot see — stale baselines (the recurring failure mode where a spec passed agent review with `phase_count=0` while reality was `1`), renamed files cited in §Technical Context, blockers that re-opened post-approval, etc.

Read-only: never modifies the spec, never transitions Linear status, never writes any project file. Output goes to stdout. Graceful degradation when `phase-detect.sh` or Linear MCP is unavailable — infrastructure flake produces `⚠ unverified` markers, not failures, so a single dropped tool doesn't block the rest of the report. For Quick-tier issues that skip agent review entirely, this is the only automated check before `/launch`.

#### `/release-changelog` generates draft CHANGELOG entry from commits (closes #10)

New skill that parses git commits between two refs, buckets by conventional commit type (`feat` → What's New, `fix` → Fix, `docs` → Documentation, others → Other Changes), and renders a draft CHANGELOG entry mirroring this file's existing format. Output to stdout — human edits the narrative lead and migration sections, then commits. Auto-detects new skill directories in the range to seed the migration bullet.

```
/release-changelog --version v1.6.0
/release-changelog --version v1.6.0 --from v1.5.0
/release-changelog --version v1.6.0 --from v1.5.0 --to HEAD
```

`--version` is required (validated against `vX.Y.Z[-suffix]`); `--from` defaults to the latest tag; `--to` defaults to `HEAD`. Edge cases: no prior tag → error requesting explicit `--from`, empty range → exit 0 with `"no changes since <prev>"`, misformatted commits → bucket gracefully into Other Changes with the full original subject. Read-only on git state and on `CHANGELOG.md`; the human's editing pass is load-bearing and explicitly preserved.

This release dogfooded the skill: the entry above was drafted by hand-running the algorithm on the four commits in the v1.4.1..HEAD range, then expanded with narrative.

### Migration

For consuming projects on v1.4.1:

1. `./scripts/sync-method.sh v1.5.0` — pulls two new skill directories: `skills/spec-preflight/` and `skills/release-changelog/`. Also pulls updated `sop/Skills_SOP.md` and `method.md` skill tables.
2. No config changes required. No template changes. No new state IDs.
3. No breaking changes. Existing pipelines run unchanged. The new skills are additive — projects can adopt `/spec-preflight` selectively (or always) before `/launch`; `/release-changelog` is Pipekit-internal release tooling and consumers may or may not have a use for it depending on their own changelog conventions.

### Open items deferred to v1.6.0

- **Orchestrator-side denial detection** — carried forward from v1.4.0. The "lighter-fix" path landed in v1.4.0 (subagent-side stop instruction); the orchestrator-side detection that surfaces denials proactively without depending on agent compliance remains open.

---

## v1.4.1 — 2026-04-27

### Fix

**`/launch` Step 1.6 resolves `phase-detect.sh` from VBW plugin cache (closes #8).** Hit immediately on first v1.4.0 consumer sync. Step 1.6's lookup checked PATH and `.vbw-planning/scripts/` but didn't know VBW installs `phase-detect.sh` at `~/.claude/plugins/cache/vbw-marketplace/vbw/<VERSION>/scripts/`. Consumers had to write a wrapper script to make Step 1.6 work. Now /launch resolves the canonical install path automatically; if multiple VBW versions are installed, the highest version wins via alphabetic glob expansion.

PATH and project-local lookups still take precedence (preserves override capability). Behavior on no-phase-detect-anywhere is unchanged from v1.4.0 — graceful degradation with non-blocking warning.

### Migration

Patch release. `./scripts/sync-method.sh v1.4.1` — single skill file updated (`launch/skill.md`). No config changes. Consumer wrapper scripts at `.vbw-planning/scripts/phase-detect.sh` continue to work (they take precedence over the plugin-cache fallback).

---

## v1.4.0 — 2026-04-27

### What's New

**Friction-fix release.** Five fixes closing the observations from v1.3.x real-world use (rs-vault Phase 1 closeout, sessions across 2026-04-27). No new capability — all five are behavioral tightenings that close silent-failure modes and cross-system gaps observed in production. Clean sync from v1.3.0 (no breaking changes, no config migration).

#### `/branch` pre-checks Linear status before worktree creation (closes #5)
When `--linear PROJ-XX` is passed, `/branch` now fetches the Linear issue **before** creating the worktree. Done/Canceled/Duplicate prompts confirmation (default abort); In Progress/Building warns and proceeds; other states proceed silently. Linear transition to In Progress still happens after worktree creation (preserves prior behavior). Catches "the work was already shipped" before the user wastes setup time.

#### `/launch --close` is idempotent + comment-on-presence (closes #4)
`--close` no longer silently no-ops when the issue has already moved past UAT (PR-merge automation, label-driven Linear automation, `/linear-todo-runner`, etc.). The status transition and the close-summary comment are now decoupled:
- status `<= Building` → transition to UAT (canonical path)
- status `>= UAT` → status transition is a no-op
- always: scan existing comments for the `**Build complete.**` marker; post the close-summary if absent, skip silently if present

Re-running `--close` is safe: idempotent on the comment, idempotent on the status. Audit trail survives all closeout-style flows.

#### Subagent permission-denial-stop instruction + canonical-file pattern doc (closes #6)
Spawned worker agents in `/linear-todo-runner` (and any future agent spawn from `/launch`) now include an explicit permission-denial protocol in the task description: stop on first `EditPermissionDenied` / `HookFeedbackBlocked`, do not retry, surface denied path + intended change + rationale. Prevents agents from burning turns retrying against hook-protected canonical files. The canonical-file-protection pattern (`.claude/rules/*` as agent-write-locked) is now documented in `sop/Skills_SOP.md` so projects intentionally protect their canonical files.

Orchestrator-side denial detection deferred to v1.5.0 per the issue's lighter-fix path.

#### `/launch` surfaces VBW phase-state warnings (closes #7)
New Step 1.6 reads `phase-detect.sh` (read-only) after the Linear gate-check and surfaces unresolved VBW state — `qa_status=failed`, `qa_status=pending` on shipped phases, `has_unverified_phases`, `next_phase_state=needs_qa_remediation` / `needs_uat_remediation`. User can continue (default), address VBW state first, or abort. `phase-detect.sh` failure is non-blocking. Closes the read-only awareness gap between Pipekit and VBW called out in `method.md` § VBW / Pipekit Ownership Model. Ownership boundary unchanged — Pipekit never writes VBW state.

#### `/launch` handoff routing for closeout-style work (closes #3)
`/launch` now runs a VBW absorption check inside Step 7b before emitting the canonical handoff. If `next_phase_state=all_done` or no matching unbuilt phase exists, the user gets a three-way routing prompt: (1) add a new VBW phase first, (2) skip VBW and author plan manually + `/review-plan <path>`, or (3) abort and escalate. Always confirms; never auto-routes. The manual-plan path explicitly documents that `/review-plan` accepts a path argument (not just a phase slug) so Standard-tier's plan-review gate is satisfied without VBW. Fixes the recurring friction where `/launch` emitted `/vbw:vibe --plan <slug>` against a closed VBW state, producing a broken command for closeout work.

### Migration

For consuming projects on v1.3.0:

1. `./scripts/sync-method.sh v1.4.0` — pulls the updated `branch`, `launch`, `06-linear-todo-runner` skills and `Skills_SOP.md`.
2. No config changes required. No template changes. No new state IDs.
3. If your project has agents that edit canonical files via Pipekit-spawned skills, the new permission-denial protocol will surface hook denials immediately rather than silently — review any prior partial-progress reports against the new behavior.

No breaking changes. The five fixes are all backward-compatible: canonical paths (open VBW phase, in-pipeline issue, fresh `--close` on Building, `/branch` without `--linear`) behave identically to v1.3.0.

---

## v1.3.0 — 2026-04-26

### What's New

**Stage 0 reframed as a contract; entry-mode routing.** Stage 0 is no longer documented as a script you "run once per project" — it's the *contract* (a set of artifacts) that the dev pipeline consumes. Three legitimate entry modes (greenfield, brownfield, inherited) are now first-class, replacing the implicit greenfield-only assumption.

#### Foundation Contract section in `method.md`
A new section enumerates every artifact the dev pipeline (Stages 1-5) requires, with paths and consuming skills. The contract is presence-only — `[TBD]` content is fine; missing files are not. `/roadmap-review` remains the gate that verifies the contract before speccing.

#### Entry-mode tables (parity in `method.md`, `README.md`, `GUIDE.md`)
The greenfield/brownfield/inherited table now appears prominently in all three docs, with `method.md` as the canonical source. Each mode lists who it's for, which skills run, and which are skipped.

#### `/startup --mode={greenfield,brownfield,inherited}` flag
- `--mode=greenfield` — existing 12-step flow, no behavioral change.
- `--mode=brownfield` — skips `/concept` and `/define`, prompts for project metadata, routes through `/strategy-create` with a manual-edit note. Tech-stack and infrastructure steps populate `method.config.md` from the existing project rather than scaffolding.
- `--mode=inherited` — runs the new Foundation Check subroutine (presence audit of every contract artifact) and exits with a next-step recommendation. Does not modify state.

When `--mode=` is absent, `/startup` auto-detects from project state and **always confirms with the user** (mirrors `/launch` Step 1.5 tier resolution — never auto-pick).

#### Foundation Check subroutine in `/startup`
Verifies every foundation-contract artifact, suggests retrofit paths for missing ones, and reports the current phase from `PHASES.md` when the contract is intact. Used internally by `--mode=inherited` and callable standalone whenever you want a foundation audit. No new skill — keeps the skill count steady.

#### Mode-aware Rule #1 in `/pipekit-help`
The single "Stage 0 not complete → run /startup" rule is replaced with four sub-rules:
- Empty project → greenfield → `/startup`
- Code present, no foundation → brownfield → `/startup --mode=brownfield`
- Foundation present, no recent activity → returning/inherited → `/start-session`
- Partial foundation → diagnose via `/startup --mode=inherited`

All other rules are unchanged.

### Migration

For consuming projects on v1.2.0:

1. `./scripts/sync-method.sh v1.3.0` — pulls the updated `method.md`, `/startup` skill, and `/pipekit-help` state rules.
2. No config changes required. Existing greenfield projects continue to behave identically.
3. New contributors joining an existing Pipekit project can now run `/startup --mode=inherited` to verify the foundation contract before picking up work.

No breaking changes.

### Open items deferred to v1.4.0

- **`/strategy-from-code`** — auto-audit skill that would generate strategy docs by inspecting an existing codebase. Brownfield mode currently routes through `/strategy-create` with a banner instructing the user to manually edit the generated docs against reality. Auto-audit is the v1.4.0 follow-up.
- **Brownfield tracker bootstrap from `package.json`** — `/startup --mode=brownfield` currently prompts for project metadata; v1.4.0 will infer name, stack, and deployment from existing project files where possible.

---

## v1.2.0 — 2026-04-26

### What's New

**BMAD-inspired upgrade pack.** Four discrete steals from [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) that strengthen Pipekit without touching the parts that already work — Linear stays the visibility layer, the strategy-sync loop stays the apex, the spec-as-contract principle stays load-bearing. Lands as four sequential commits (P4 → P3 → P1 → P2) that ship value alone if you stop after any of them.

#### Sync-Safe Overrides (`.claude/overrides/`)
Projects can now customize synced skills, SOPs, and `method.md` without forking and without losing upstream improvements. The sync script applies overrides on top of the upstream copy and surfaces a **drift warning** when upstream changes a file you override.

- `.claude/overrides/skills/<name>/skill.md` — full-file replacement
- `.claude/overrides/sop/<file>.md` — full-file replacement
- `.claude/overrides/method.md.patch` — unified diff
- `.claude/overrides/MANIFEST.md` — human-curated index (what + why)

Failed patches dry-run first — they don't half-apply. See `method.md` § Sync-Safe Overrides.

#### First-class scale tiers in `/launch` (Quick / Standard / Heavy)
`/launch` now resolves a **tier** for every issue. Tiers shape *which gates apply*; complexity (Low/Medium/High) shapes *how execution is routed*. The two are orthogonal.

- **Quick** — 1–3 stories, AC-as-plan. Skips spec review, milestone-readiness, plan review, QA agent. Routes to batch runner.
- **Standard** (default) — Existing pipeline.
- **Heavy** — Adds security review + mandatory `/strategy-sync` before close. Always full VBW planning, batch runner disallowed.

Tier inference is **always confirmed with the human** — auto escalation/de-escalation is disallowed by design. Per-tier templates live at `templates/tier-{quick,standard,heavy}.md`. Per-project tier configuration in `method.config.md` § Tiers.

#### `/pipekit-help` skill + opt-in next-step nudge
Push-based replacement for "what skill do I run now?" — replaces pull-based skill discovery in a 12-step pipeline.

- `/pipekit-help` reads project state (branch, recent commits, presence of `PLAN.md` / `REVIEW.md` / `VERIFICATION.md`, `.pipekit/pending-strategy-sync` marker, Linear status) and recommends exactly one next step with a one-line why.
- Rules live in `skills/pipekit-help/state-rules.md` — first match wins; customizable via the override system.
- `scripts/pipekit-next-step-nudge.sh` is an **opt-in** Stop hook that suggests `/pipekit-help` after pipeline-relevant skills finish. Scoped by transcript inspection (silent unless the previous turn invoked a pipeline skill).

#### Fresh-chat discipline (documented enforcement)
The spec-as-contract principle ("no stage may introduce guesswork into the next stage") only holds if downstream agents read prior stage output as documents, not as recalled conversation.

- New `method.md` § Fresh-Chat Discipline section lists which transitions require a new conversation and why.
- Preamble nudges added to skills that cross stage boundaries: `/launch`, `/light-spec-revise`, `/review-plan`, `/strategy-sync`.

### Other Changes Since v1.1.0

This release also bundles the Tier 1 / Tier 2 / Tier 3 `/launch` refactor that landed prior to the BMAD upgrade pack:

- `/launch` split into open + close phases; Pipekit owns Linear status transitions, VBW owns plan/execute/verify
- `/review-plan` standalone skill spawning the `plan-reviewer` agent at `model: opus`
- Post-archive hook (`scripts/pipekit-post-archive.sh`) → `/strategy-sync` nudge via `.pipekit/pending-strategy-sync` marker
- Batch-promote SOP and `/launch --close` messaging
- Canonical `.claude/rules/` hub-and-spoke template (`pipekit-discipline`, `pipekit-tooling`, `pipekit-security`)
- `sync-method.sh` self-update guard + re-exec for single-invocation upgrades

### Deprecations

- `/launch --deep` — no-op since Tier 1; emits a one-line warning. Use `/vbw:vibe --execute --effort=max` instead.

### Migration

For consuming projects on v1.1.0:

1. `./scripts/sync-method.sh v1.2.0` — pulls everything.
2. (Optional) Add `## Tiers` section to `method.config.md` if you want to disable a tier or document tier policy. Default is all three available with **Standard** as fallback.
3. (Optional) Wire the next-step nudge by adding the snippet from `sop/Skills_SOP.md` § Next-Step Nudges to `.claude/settings.local.json`.
4. (Optional) Migrate any pre-v1.2.0 forked skills into `.claude/overrides/skills/<name>/skill.md` so they stop getting clobbered on sync.

No breaking changes. Existing pipelines run unchanged with **Standard** tier as the default.

---

## v1.1.0-opus4.7 — 2026-04-17

Adapted methodology to Claude Opus 4.7 behavioral changes:

- DesignDirection template counters Opus 4.7's default cream/serif/terracotta aesthetic; requires 4 distinct directions before building.
- Literal-scope authoring guidelines added to skills.
- Explicit subagent guidance for Opus 4.7.
- `Session_Management_SOP.md` for Claude Code + Opus 4.7 context handling.

---

## Earlier

See `git log` and `PIPEKIT_IMPROVEMENTS.md` for pre-v1.1.0 history.
