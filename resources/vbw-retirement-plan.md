# VBW Full Retirement — Migration Plan

**Status:** DRAFT for approval · **Authored:** 2026-06-21 · **Owner:** Ethan
**Goal (user's words):** *"retire VBW fully and remove it from the computer fully."*

> This plan supersedes the "3-layer epic" framing in [[vbw_deprecation]]. Grounding sweep on
> 2026-06-21 showed the live functional coupling is far smaller than that memory implies. The
> executor was already removed in v4.0.0; what's left is one advisory hook, two file-read paths,
> a cosmetic doc/brand surface, and the on-disk plugin install.

---

## 1. What "retire VBW" actually means — two scopes

The phrase bundles two efforts that differ by an order of magnitude in effort and risk. The plan
treats them separately and recommends doing only the first now.

| | **Scope A — Decouple + uninstall** | **Scope B — Retire the planning-layer concept** |
|---|---|---|
| **What** | Stop *depending on the VBW plugin runtime*; debrand docs; uninstall the plugin from this machine. | Replace the planning layer itself — `.vbw-planning/`, `/vbw:init`, `/roadmap-create` phase-merge, `/phase-plan`, `/review-plan`, `pk_vbw_*` — with a native phase surface. |
| **Why you'd do it** | "Remove VBW from the computer." Get rid of the SessionStart noise, the PreCompact JSON error, the stale `/vbw:vibe` resume banner, and the brand. | Do a *fresh greenfield bootstrap* of a brand-new project with zero VBW dependency. |
| **Blocks on** | Re-homing one advisory commit hook. That's it. | Designing a Stage-0 phase-scaffold replacement (the real design work). |
| **Effort** | ~1 session. Fully reversible. | Multi-session design track. Greenfield-bootstrap quality risk. |
| **Needed for existing consumers?** | Yes — achieves the user's stated goal. | **No.** Piper + SiteLine are both years past Stage 0. Their `.vbw-planning/` files are inert data. |

**Recommendation: execute Scope A now. Defer Scope B** until there's an actual new-project bootstrap
that needs it. Scope A delivers "VBW is gone from the computer" today; Scope B is only exercised by
greenfield `/startup` on a project that doesn't exist yet.

The rest of this plan details Scope A end-to-end, then sketches Scope B as a deferred appendix.

---

## 2. Grounded footprint inventory (2026-06-21)

Three tiers, by how load-bearing each is.

### Tier A — Live functional coupling (must handle before uninstall)

| Item | Where | Reality |
|---|---|---|
| **Advisory commit-format hook** | plugin `scripts/validate-commit.sh`, registered PostToolUse on `Bash` | `# Non-blocking feedback only (always exit 0)`. Surfaces `"Commit message does not match format…"` to the model. **Soft nudge, not a gate.** Pipekit ships *no* commit hook of its own — verified `.claude/hooks/` does not exist. This is the **only** thing the plugin gives Pipekit that Pipekit uses. |
| **`pk next` phase grouping** | `bin/pk:225` reads `.vbw-planning/PHASES.md` `## Current Phase:`; `bin/pk:241` reads `.vbw-planning/linear-map.json` | Plain `grep`/`jq` on disk files. **Does not call the plugin.** Uninstalling the plugin does not break this. Live on **Piper** (`## Current Phase: WP-3`); **not** used on SiteLine (no Current Phase). |
| **`pk done` plan finalize** | `bin/pk:782` `pk_vbw_find_plan`, `bin/pk:814` `pk_vbw_finalize_plan`, called at `bin/pk:1633` | Reads/writes `.vbw-planning/phases/*/PLAN.md` + writes SUMMARY.md. **Best-effort, skips silently** when no matching PLAN.md. Plain file I/O, no plugin call. `.vbw-planning/phases/` frozen since 2026-05-17 on both consumers, so this no-ops in practice. |

**Key fact:** of Tier A, only the **commit hook** breaks when the plugin is uninstalled. The two
bin/pk paths read files that remain on disk; the plugin's absence is irrelevant to them.

### Tier B — Dead-but-present (cosmetic debrand)

| Item | Count | Notes |
|---|---|---|
| VBW mentions in `skills/` + `sop/` | ~190 across 21 files | Heaviest: `sop/VBW_Help.md` (31), `skills/roadmap-create` (30), `skills/sync-linear` (27), `sop/Linear_SOP.md` (24), `skills/startup` (23). |
| VBW mentions in core docs | ~181 | `method.md` (49), `GUIDE.md` (48), `VBW_COMMANDS.md` (34), `README.md` (23), `CLAUDE.md` (12), `RUNBOOK.md` (7), `STARTUP.md` (5), `method.config.template.md` (3). |
| `pk_vbw_*` function names + comments | bin/pk | Functional code; rename is cosmetic but touches a shipped script — do last, carefully. |
| `archive/`, `experiments/`, `Logs/Sessions/` | ~hundreds | **Leave untouched.** Historical record. Debranding history is revisionism and pure churn. |

### Tier C — On-disk machine install (the "remove from the computer" target)

| Item | Location |
|---|---|
| Plugin cache | `~/.claude/plugins/cache/vbw-marketplace/vbw/1.37.1/` (33 dirs, 7 agents, ~24 hook scripts) |
| Enable flag | `~/.claude/settings.json:53` → `"vbw@vbw-marketplace": true` |
| Statusline hook | `~/.claude/settings.json:39` → resolves `vbw-statusline.sh` |
| `/vbw:*` slash commands | `~/.claude.json` (22 vbw references) |
| Hook registrations | plugin `hooks/hooks.json` — 11 events, ~24 scripts. Most gated on `vbw-lead\|vbw-dev\|…` agent matchers that **never match** a Pipekit native `/work` session. The few firing every session: `session-start.sh` (the stale `/vbw:vibe` resume banner), `compaction-instructions.sh` (**the PreCompact JSON-schema error you just saw in `/compact`**), `validate-commit.sh`, `validate-summary.sh`, `prompt-preflight.sh`, `bash-guard.sh`. |

Uninstalling removes all of Tier C at once — including the two active noise sources (resume banner +
PreCompact error). That's a net session-quality *improvement*, not just a cleanup.

---

## 3. Scope A — execution plan (ordered, reversible)

### Phase A0 — Re-home the commit hook (the one functional must-do)

This is the only thing that must land *before* uninstall. Two honest options:

- **A0-a (recommended): re-home as a Pipekit-owned hook.** Create `.claude/hooks/validate-commit.sh`
  in pipekit (port the plugin's logic — it's ~70 lines, already battle-tested against the
  false-positive classes: multi-line `-m`, two-`-m` body, chained commits, heredoc PR bodies).
  Register it in a committed `.claude/settings.json` PostToolUse/Bash block. Ship it in the sync
  payload so consumers inherit it. Net: the advisory nudge survives plugin removal, and it becomes
  Pipekit's own — no external dependency.
- **A0-b: accept the loss.** The hook is advisory, never blocked anything, and commit format is
  already self-discipline reinforced by the memory + CLAUDE.md. Drop it. Lowest effort; loses the
  automated nudge.

> **DECIDED (2026-06-21): A0-a.** Re-home as a Pipekit-owned hook — ~1 file, makes good on the
> "commit format is enforced by a hook" claim in CLAUDE.md/[[feedback_commit_format]] without the
> claim silently becoming false the moment the plugin is gone, and removes the last plugin dependency.

**Correctness note for the plan:** [[feedback_commit_format]] and CLAUDE.md call the format
"enforced by a PostToolUse hook." It is **advisory, not enforced** (the script always exits 0). If
A0-b is chosen, that memory + the CLAUDE.md line must be corrected to "convention, self-disciplined."
If A0-a, the claim becomes true-and-owned.

### Phase A1 — bin/pk back-compat fallback (optional, low-risk)

Make the two read paths not *require* the `.vbw-planning/` brand path, so future projects (and the
eventual Scope B) have a native home, while existing consumers keep working unchanged:

1. `pk_current_phase` (`bin/pk:225`): read `.pipekit/PHASES.md` first, fall back to
   `.vbw-planning/PHASES.md`.
2. `pk_vbw_match_issue_phase` (`bin/pk:241`): read `.pipekit/linear-map.json` first, fall back to
   `.vbw-planning/linear-map.json`.
3. Leave `pk_vbw_find_plan` / `pk_vbw_finalize_plan` as-is for now (frozen, no-op in practice) — or
   add the same fallback. Rename `pk_vbw_*` → `pk_phase_*` only as part of the cosmetic pass (A3),
   with smoke-suite coverage, since it's shipped code.

This phase is **optional for "uninstall the plugin"** (the files stay on disk, grep still reads
them). It's worth doing because it's the cheap half of Scope B and removes the brand from the *only*
functional code path. Guard with `tests/pk-smoke.sh`.

### Phase A2 — Uninstall the plugin from the machine (Tier C)

After A0 lands. Each step reversible (re-add the marketplace + re-enable to restore):

1. Set `~/.claude/settings.json:53` → `"vbw@vbw-marketplace": false` (or remove the entry).
2. Remove the statusline hook at `~/.claude/settings.json:39` (or replace with a non-VBW statusline).
3. Remove `/vbw:*` command registrations from `~/.claude.json` (22 refs).
4. `rm -rf ~/.claude/plugins/cache/vbw-marketplace/` (the install). **Confirm with user first —
   destructive, per discipline rules.** Reversible only via re-install from the marketplace.
5. Verify: new session has no `/vbw:vibe` resume banner, no PreCompact JSON error, statusline intact,
   `pk next` still groups by phase on Piper, commit-hook nudge still fires (if A0-a).

> **Hard stop / confirmation gate:** steps 1–4 mutate `~/.claude/settings.json`, `~/.claude.json`, and
> delete a cache dir — all outside the repo, all affecting *every* Claude Code session on this machine
> (not just Pipekit). Get explicit go before executing, back up both JSON files first.

### Phase A3 — Debrand the docs (Tier B, cosmetic, batchable)

Lowest risk, highest line-count. Do *after* uninstall proves the decouple works, so the docs describe
the new reality. Order by leverage:

1. **`VBW_COMMANDS.md` + `sop/VBW_Help.md`** — these are *about* VBW. Decide per-file: retire
   (move to `archive/`) vs. rewrite as "Pipekit phase model (formerly VBW planning layer)." Recommend
   retire `VBW_COMMANDS.md` to archive (the executor it documented is gone); fold any still-true
   planning-layer content into a renamed `sop/Phase_Planning_SOP.md`.
2. **Core docs** (`method.md`, `GUIDE.md`, `README.md`, `CLAUDE.md`, `RUNBOOK.md`, `STARTUP.md`) —
   replace "VBW planning layer" → "Pipekit phase planning"; "`.vbw-planning/`" → "`.pipekit/`"
   (with a one-line back-compat note); drop the "Pipekit wraps VBW" framing now that nothing is
   wrapped. Re-stamp constitutional docs (method/RUNBOOK/GUIDE) per release checklist.
3. **Skills** (`roadmap-create`, `sync-linear`, `startup`, `01-light-spec`, `spec-preflight`, `work`,
   `phase-plan`, `review-plan`, `00-roadmap-review`, `pipekit-help`, etc.) — repoint `.vbw-planning/`
   references and de-VBW the prose. These are the Stage-0 planning commands; **prose-only debrand
   here, no behavior change** (behavior change is Scope B).
4. **bin/pk rename** `pk_vbw_*` → `pk_phase_*` + comment debrand, smoke-suite green.
5. `method.config.template.md` — drop the `Backend:` row entirely (v4.0.0 made native the sole
   executor; the field only exists to surface a stale config and refuse).

**Do not touch** `archive/`, `experiments/`, `Logs/Sessions/`. History stays as written.

### Phase A4 — Consumer migration (Piper + SiteLine, per-repo PRs)

**DECIDED (2026-06-21): migrate, don't keep-in-place.** The 2026-06-21 inventory showed `.vbw-planning/`
is overwhelmingly a historical planning archive + dead executor state, not live data:

| Consumer | Tracked files | What's live | What it is |
|---|---|---|---|
| **Piper** | 109 | `PHASES.md` (`## Current Phase: WP-3`) + `linear-map.json` — drive `pk next` phase grouping | rest = `phases/…`×73 planning artifacts, `codebase/…`×10 `/vbw:init` analysis, `.agent-worktrees/…` runtime cruft |
| **SiteLine** | 153 | **nothing** — no `PHASES.md`, no `linear-map.json`, so `pk next` phase mode never engages | `milestones/…`×139 planning artifacts + dead state |

Per-repo cleanup PR (normal Pipekit sync + tidy). **Archive ≠ delete** — planning artifacts are the
record of *how* each project's phases were planned, and the planning-layer concept is being kept
(Scope B deferred), so they're preserved, just out of the brand path. Only dead *runtime* state is
deleted/gitignored.

- **SiteLine first** (single-tier `main`, zero live value): `git mv .vbw-planning archive/vbw-planning`
  (or `.pipekit/archive/`). Nothing reads it → cannot regress. Confirm `pk next` unchanged (it was
  already flat-mode).
- **Piper second** (3-tier `dev`→beta→main, phase-aware live): `git mv .vbw-planning/PHASES.md
  .pipekit/PHASES.md` + `git mv .vbw-planning/linear-map.json .pipekit/linear-map.json`; archive the
  rest under `.pipekit/archive/` (or `archive/vbw-planning/`); delete/gitignore the runtime cruft.
  **Verify `pk next` still groups by `WP-3` after** (this is the only regression surface in the whole plan).

Depends on A1's native-path fallback being live so bin/pk reads `.pipekit/` first.

---

## 4. Risk register & rollback

| Risk | Likelihood | Mitigation / rollback |
|---|---|---|
| Commit-format nudge lost on uninstall | Certain if A0 skipped | A0-a re-homes it; or A0-b + correct the memory/CLAUDE.md claim. |
| `pk next` phase grouping breaks on Piper | Low — files stay on disk | A1 fallback reads both paths; verify on Piper post-uninstall. Rollback: files untouched, re-enabling plugin not even required. |
| Uninstall breaks an *unrelated* non-Pipekit session that used `/vbw:*` | Low | Back up both JSON files; re-enable flag restores everything. Check no other active project depends on VBW execution before deleting the cache. |
| Statusline disappears | Medium (it's a VBW script) | Replace `settings.json:39` with a neutral statusline before/at uninstall; don't just delete. |
| Debrand introduces stale cross-refs | Medium (~370 mentions) | Do A3 incrementally, grep-verify no dangling `.vbw-planning` / `/vbw:` after each file; smoke suite for bin/pk. |
| Greenfield `/startup` later needs the planning runtime | Deferred | That's exactly Scope B. Until a new project bootstraps, not a real risk. Document the gap in `/startup` so it fails loud, not silent. |

**Global rollback:** Scope A is reversible at every step except the `rm -rf` of the plugin cache (re-installable from the marketplace). Nothing in the repo is destroyed; debrand is normal version-controlled edits.

---

## 5. Recommended sequence & effort

```
A0  re-home commit hook (A0-a)        ~1 file        ← only pre-uninstall must-do   [user decision: a/b]
A1  bin/pk native-path fallback        ~3 edits + smoke
A2  uninstall plugin from machine      JSON edits + rm  ← CONFIRMATION GATE (touches ~/.claude globally)
A3  debrand docs/skills/bin            ~25 files, batched, re-stamp constitutional docs → release PR
A4  consumer archival                  keep-in-place now; migrate to .pipekit/ later (per-repo PRs)
─────────────────────────────────────────────────────────────────────────────────────
B   planning-layer rewrite onto native phase surface   DEFERRED — only when a new greenfield bootstrap needs it
```

Ship A0–A3 as one Pipekit release (likely **v4.1.0** — "VBW fully decoupled; plugin no longer
required"). A4 is consumer-side follow-up. B is a future design track.

**Both gating decisions resolved (2026-06-21):**
1. ✅ **A0-a** — re-home the advisory commit hook as a Pipekit-owned `.claude/hooks/validate-commit.sh`.
2. ✅ **A4 migrate** — `git mv` live files to `.pipekit/`, archive planning artifacts, delete dead runtime state. (SiteLine: nothing live → archive whole dir. Piper: 2 live files → `.pipekit/`, verify `pk next`.)

Ready to execute A0 → A1 → A2 (confirmation gate) → A3 → A4.

---

## Scope B (now in scope): Linear-native phase surface

**Decided 2026-06-21.** The phase surface becomes **Linear Initiatives → Projects → Issues**, replacing
`.vbw-planning/PHASES.md` + `linear-map.json` entirely (deleted, not migrated). This replaces the vague
"rebuild `/vbw:init` phase derivation" with a concrete native target. **Validated live against Piper's
Linear** (read-only GraphQL probe, 2026-06-21).

### What the live probe proved

| Gate | Result |
|---|---|
| Initiatives enabled? | ✅ Live — Piper has 7 initiatives, **already containing the phase projects**. `Piper Setup`=old phase-01, `Piper Pitch`=old phase-02. The `.vbw-planning/` files are a stale mirror; the hierarchy already exists natively. |
| Schema (`sortOrder`/`status`/`state`)? | ✅ All fields resolve via bin/pk's existing GraphQL helper. |
| Ordering via `sortOrder`? | ❌ **Unreliable.** Within `Piper Pitch`, `sortOrder` orders projects `P11,P8,P4,P3,P1,P5,P10,P6,P7,P9,P2` — Linear's internal drag-rank, not phase sequence. |
| Ordering via name prefix? | ✅ **Mandatory + sufficient.** `P{N}.` prefix is the only coherent order. |
| Drift today? | `PHASES.md` says `Current Phase: WP-3`; Linear says `Piper Pitch` active, P1 done, P2 next. **Already diverged** — proves the drift this kills. |

### The design (name-prefix ordering — `sortOrder` ignored)

| Concept | Native mechanism | Consumer migration |
|---|---|---|
| Phase identity | Linear **Initiative**, named `i{N}. label` | rename ~5 delivery initiatives to add `i{N}.` prefix |
| Phase order | parse `^i(\d+)\.` (case-insensitive) | — |
| Roadmap opt-in | only `i{N}.`-prefixed initiatives count → strategic themes (`Product Vision`) auto-excluded, no config list | — |
| Sub-phase | Linear **Project**, already named `P{N}. label` | **none** — Piper/SiteLine already use `P{N}.` |
| Project order | parse `^P(\d+)\.` (case-insensitive) | — |
| Current phase | lowest `i{N}` initiative whose `status` != `Completed` | — |
| Current project | lowest `P{N}` whose `state` != `completed`/`canceled` in it | — |
| Issue grouping | **existing** `pk_linear_issues_in_state_project` (project-ID + state filter) | none — works unchanged |

### bin/pk work — ✅ BUILT + VERIFIED (2026-06-21, working tree on main, uncommitted)

1. ✅ `pk_linear_initiatives_json` — `initiatives(first:50){ nodes{ id name status projects(first:50){ nodes{ id name state }}}}` via `pk_linear_gql`. Empty on no-key/error.
2. ✅ Name-prefix ordering — jq `capture("^[iI](?<n>[0-9]+)\\.")|.n|tonumber` (numeric, so `P2` < `P10`); `sortOrder` ignored.
3. ✅ `pk_native_phase_context` → `<name>\t<project-id>`: lowest `i{N}` initiative whose `status != Completed`, then its lowest `P{N}` project whose `state ∉ {completed,canceled}`. Unprefixed initiatives (strategic themes) excluded.
4. ✅ `pk_phase_context` dispatcher — native wins; falls back to the legacy `.vbw-planning/` files (renamed `pk_file_current_phase_*`). Emits `<name>\t<project-id>\t<source>`.
5. ✅ `cmd_next` rewired to one `pk_phase_context` fetch; shows `Phase: X (Linear)` when native; source-aware empty-phase hint.
6. ✅ `pk status` — `pk_native_roadmap_summary` prints the ordered `i{N}.`→current-`P{N}.` walk; silent pre-migration.
7. ✅ Reuses `pk_linear_issues_in_state_project` unchanged for issue grouping.
8. ✅ 4 smoke unit-tests added (`tests/pk-smoke.sh`, sourced-mode, no network): derivation, empty-input, no-prefix fallback, roadmap walk. **Suite 39/39.**

**Verification:** jq derivation tested against real Piper initiatives JSON (prefixed → `i1. Pitch → P2. Budget Editor`, correctly skipping completed `P1`); live read-only run against Piper's Linear (7 initiatives; un-prefixed → correctly defers to fallback; `pk status` clean, roadmap section hidden). `bash -n` clean.

**Fallback note:** currently falls back to `.vbw-planning/PHASES.md` (where the files live today). When A1 moves them to `.pipekit/`, repoint the fallback. Remove the fallback entirely once both consumers are `i{N}.`-prefixed in Linear.

**Not yet done (rest of Scope B):** skill rewrites (`/roadmap-create`, `/phase-plan`), consumer initiative-renames in Linear (needs write confirmation), docs (method.md phase-surface section, method.config.template).

### Skill rewrites

- `/roadmap-create` + `/phase-plan`: create/order **Initiatives + Projects in Linear** (named with
  prefixes) instead of writing `PHASES.md`. If the MCP can't set `sortOrder`, **naming carries the order**
  (the chosen mechanism anyway) — so the MCP write-order question is moot. Confirm the tacticlaunch MCP can
  `initiativeCreate` / attach projects; if not, these stay manual-in-Linear + skill-guided.
- `/vbw:init` greenfield phase scaffold → propose an initiative/project skeleton the user creates in Linear
  (the one genuinely net-new piece; still far simpler than a file-based phase engine).
- `pk_vbw_find_plan` / `pk_vbw_finalize_plan`: delete — `/work`'s `.pk-work/<ID>-PLAN.md` is the native
  plan home; the VBW PLAN.md path is vestigial (frozen, no-op).

### Consumer migration (one-time, mostly already done)

- **Piper:** initiatives already exist with the right projects. Add `i{N}.` prefixes to the ~5 delivery
  initiatives (Pitch→`i1.`, Produce→`i2.`, …); leave `Product Vision` unprefixed (strategic). Then delete
  `.vbw-planning/PHASES.md` + `linear-map.json`. Verify `pk next` derives the same current project.
- **SiteLine:** confirm its `milestones/` map to Linear initiatives the same way; apply prefixes; delete files.

### Open research (non-blocking)

- Does the tacticlaunch MCP support `initiativeCreate` + project-attach for `/roadmap-create`? (If no →
  skill guides manual Linear setup; ordering still works via naming.)
- SiteLine initiative/project topology (probe its Linear the same way before its migration).

---

*Cross-refs: [[vbw_deprecation]] (two-layer rule, executor removed v4.0.0), [[pipekit_3_0_status]]
(current release state), [[feedback_commit_format]] (the "enforced" claim this plan corrects),
[[pipekit_tracking_model]] (why this lives in resources/, not Linear).*
