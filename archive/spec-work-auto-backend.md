> **SUPERSEDED (Pipekit v3.2.0, 2026-06-13).** This spec proposed the complexity-based `auto` backend router for `/work`. The `auto` router was **removed** in v3.2.0 when the `vbw` backend was deprecated (native is the default and only non-legacy executor; `vbw` is an explicit legacy opt-in, removal targeted v4.0.0). The config-parser-reliability problem this doc also raised (#1 below) was fixed independently via the `pk config` helper. Archived for rationale trail only — do not implement.

---

## Light Spec

**Status:** Draft (SUPERSEDED — see banner above)
**Complexity:** Low (~2-4h)
**Linear Project:** Pipekit

### Problem

`/work` reads `Backend` from `method.config.md` as a fixed project-level value (`vbw` or `native`). Two problems:

1. The config parser is unreliable — the skill tells Claude to grep for `Backend`, but the table uses bold markdown (`**Backend**`), causing Claude to miss the value and silently fall back to the `vbw` default. rs-vault (configured `native`) observed this firsthand: `/work` printed `Backend: vbw` and dispatched VBW agents.
2. There is no complexity-aware routing. Projects like Piper need simple issues executed inline (native) and complex issues escalated to VBW — but the config today forces a single choice for the whole project.

### Goal

`/work` selects the execution backend correctly: fixed (`native` or `vbw`) when configured, or automatically from the plan when `auto` is configured. The routing decision is always visible to the user before execution begins.

### Proposed Solution

- Fix config parsing: replace the grep/LLM-parse approach with an explicit `bin/pk pk_config "Backend" "vbw"` bash call in Step 1.
- Add `Backend: auto` as a valid third config value in `method.config.template.md`.
- When `auto` is active, evaluate the written plan at Step 3b against a routing heuristic and resolve to `native` or `vbw`.
- Print the resolved backend + routing reason one line before dispatch, regardless of mode.

### Scope

**In scope:**
- Fix Step 1 to use `bin/pk pk_config` for reliable backend value extraction
- Add `auto` to the valid backend values (Triggers, Step 1, Failure model)
- New Step 3c: routing logic that runs after plan is written, only when `auto` is active
- Print `Routing: <reason> → <backend>` before Step 5 dispatch (all modes)
- Update `method.config.template.md` to document `auto` as a valid value

**Out of scope:**
- Auto-routing to `06-linear-todo-runner` (that remains a manual, explicit invocation)
- Changes to `vbw` or `native` execution paths (Step 5 is unchanged)
- Any changes to the `--backend=` CLI override (already overrides everything)

### Decisions

- **Routing heuristic signals:** File count in plan, presence of migration file paths, presence of packages not already imported in the spec's referenced files. All three are readable from the written plan without additional file I/O.
- **Routing threshold:** ≤3 files AND no migration AND no unfamiliar package → `native`. Any other combination → `vbw`.
- **Routing timing:** After Step 3b (plan written), before Step 4 (verdict gate). User approves the plan; the routing line prints immediately after `proceed`, before dispatch. No second approval step.
- **`--backend=` override still wins:** If the user passed `--backend=native` or `--backend=vbw` explicitly, `auto` routing is skipped entirely. Print `Backend: native (explicit override)` in Step 1 as today.
- **Config parse fix is non-breaking:** `bin/pk pk_config "Backend" "vbw"` returns the same values as before for `vbw` and `native` projects. The fix is invisible to those projects.

### Requirements

- [ ] Step 1 uses `bin/pk pk_config "Backend" "vbw"` via Bash, not LLM grep
- [ ] `auto` is accepted as a valid backend value; any other value (including blank) triggers the existing unknown-backend refusal
- [ ] When `Backend: auto`, Step 1 prints `Backend: auto` (not resolved yet)
- [ ] Step 3c exists and runs only when effective backend is `auto`
- [ ] Step 3c evaluates: (a) count of "Files to touch" entries, (b) whether any path matches `*/migrations/*` or `*.sql`, (c) whether any package listed is not resolvable in `package.json`
- [ ] Step 3c resolves to `native` if: file count ≤3, no migration path, no unfamiliar package
- [ ] Step 3c resolves to `vbw` otherwise
- [ ] After `proceed` at Step 4, print one line: `Routing: <signal summary> → <native|vbw>` (auto mode) or `Backend: <native|vbw>` (fixed mode)
- [ ] Step 5 dispatch uses the resolved backend, not the raw config value
- [ ] `method.config.template.md` documents `auto` as a valid Backend value with a one-line description

### Acceptance Criteria

- [ ] Given `method.config.md` has `Backend: native` (bold markdown), when `/work` runs Step 1, then it prints `Backend: native` (not `vbw`) — verifiable by running `/work` on rs-vault
- [ ] Given `Backend: auto` and a plan with 2 files and no migration, when user says `proceed`, then the routing line reads `Routing: 2 files, no migration → native` and a native execution path is used
- [ ] Given `Backend: auto` and a plan with 5 files, when user says `proceed`, then the routing line reads `Routing: 5 files → vbw` and `vbw:vbw-dev` is dispatched
- [ ] Given `Backend: auto` and a plan containing a `supabase/migrations/` path, when user says `proceed`, then routing resolves to `vbw` regardless of file count
- [ ] Given `/work RS-XX --backend=native` with `Backend: auto` in config, then Step 1 prints `Backend: native (explicit override)` and Step 3c is skipped
- [ ] Given `/work RS-XX --backend=invalid`, then skill refuses: `Unknown backend 'invalid'. Valid: vbw, native, auto.`

### Technical Context

- **Existing code:** `skills/work/skill.md` — all changes are to this file's prose instructions
- **Config binary:** `bin/pk pk_config "<Key>" "<default>"` — already ships in consuming projects via sync; handles bold markdown table format
- **Template:** `method.config.template.md` — add `auto` to the Backend row comment
- **Patterns to follow:** All other Step N additions in the skill follow the existing header + code-block format
- **Authority:** `bin/pk pk_config` is authoritative for config value extraction; LLM grep is not

### Risks & Open Questions

- `bin/pk pk_config` availability: the binary is synced into consuming projects but must exist at `bin/pk`. If absent, the skill should fall back to grep with a warning — or refuse and tell the user to run `/pipekit-update`. Planner to decide fallback behavior.
- Unfamiliar-package detection in Step 3c is the weakest signal — it requires Claude to cross-reference package names against `package.json`. This could be slow or inaccurate. Planner may choose to drop this signal and rely only on file count + migration presence, which are unambiguous.

### Notes

- This bundles two separate bugs (config parse) + one feature (auto routing) into one skill edit. They are coupled because fixing the parse bug changes Step 1, and the auto-routing adds Step 3c — easier to review as one change than two.
- rs-vault stays on `Backend: native` (no change needed).
- Piper would move to `Backend: auto` after this ships.
- The RUNBOOK.md and `method.config.template.md` commentary should note that `auto` is the recommended default for multi-complexity projects.
