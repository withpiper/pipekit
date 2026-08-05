---
name: spec-preflight
description: Empirical pre-flight checks on a Linear issue's spec. Use right before /work consumes a spec. Use when a spec has been sitting in Approved for >1 week and reality may have drifted. Verifies file paths, symbol/line refs, deps. Read-only.
---

# Spec Preflight Skill

You verify that the empirical claims in a Linear issue's spec match reality, *before* `pk branch <ID>` + `/work` consume the spec. Spec Review Agent reviews narrative coherence; this skill reviews facts. The two are complementary — agent review catches "is the spec well-shaped?", `/spec-preflight` catches "is the spec still true?".

This skill is **read-only**: it never edits the spec, never transitions Linear status, never writes any project file. Output goes to stdout only. (A scratch file under `/tmp/` is acceptable for analysis state.)

Read `method.config.md` for project context (Linear team prefix, state IDs, project root).

## Triggers

- `/spec-preflight PROJ-XXX` — verify a single specced issue
- `/spec-preflight PROJ-XXX --accept` — downgrade Phase 3.6 hard-fails (`✗`) to warnings (`⚠`). Use for accepted-risk cases (e.g., tooling intentionally absent, to be bootstrapped later). The findings still appear in the report; only the blocking verdict softens.
- "pre-flight PROJ-XXX" / "verify spec PROJ-XXX"

## When to use

Between Spec Review Agent passing and `pk branch`. The pipeline position:

```
/light-spec → Spec Review Agent → human approval → /spec-preflight → pk branch <ID> → /work
```

For Quick-tier issues that skip agent review entirely, this skill is the only automated check before `pk branch` — surface it in the Quick-tier template too.

## When NOT to use

- The issue isn't specced yet — the skill has nothing empirical to verify. Run `/light-spec` first.
- Mid-execution. Empirical claims drift while building; this skill validates the spec contract, not in-flight work.

## Inputs (read-only)

| Source | Tool | Purpose |
|--------|------|---------|
| Linear issue body | `mcp__linear-server__linear_getIssueById` with `includeRelations: true` | Spec body + status + blocked_by |
| File paths from spec | `Read` or `Glob` | Confirm cited files exist |
| Line ranges from spec | `Read` with `offset`/`limit` | Confirm line citations resolve to real content |
| Symbol/heading refs from spec | `Grep` | Confirm cited symbols/headings exist in the cited files |
| Linear status (re-fetched) | `mcp__linear-server__linear_getIssueById` | Compare current status against spec body's claim |
| Each `blocked_by` issue | `mcp__linear-server__linear_getIssueById` | Confirm dependency claims of "Done" |
| `Strategy docs path` (from `method.config.md`) | `Glob` + `Read` | Probe 3.6a — canonical-doc cross-check (#21) |
| `Platform` (from `method.config.md`) | none — heuristic match against spec body | Probe 3.6b — platform-capability check (#20) |
| `package.json` + lockfile (root + workspace pkgs) | `Read` + `Grep` | Probe 3.6c — tooling availability (#22) |
| Migration files cited in spec | `Read` (and optionally a Supabase MCP `execute_sql` for read-only `SELECT COUNT(*)` violator counts) | Probe 3.6d — migration data-shape (#24) |

## Algorithm

### Step 1 — Fetch the issue

Call `mcp__linear-server__linear_getIssueById` with `id: PROJ-XXX` and `includeRelations: true`. Capture:

- `title`, `identifier`
- Full `description` (the spec body)
- Current `state.name` (e.g., `Approved`, `Specced`, `Building`)
- `relations` filtered to `blocked_by` (each carries an issue identifier and its state)

If the issue isn't found or has no description: stop and report `"PROJ-XXX has no spec body. Run /light-spec first."`. Do not proceed to checks.

### Step 2 — Parse empirical claims

Walk the spec body and bucket claims into four categories. Use these heuristics — when in doubt, prefer false-positive (treat ambiguous text as a claim and verify it) over false-negative (silently skipping a claim).

1. **File paths.** Any backtick-quoted token containing `/` or a file extension (e.g., `` `supabase/config.toml` ``, `` `src/lib/auth.ts` ``). Treat absolute paths and project-relative paths the same way. Strip surrounding punctuation.
2. **Code citations (line + symbol).** Line forms: `line N of <file>`, `lines N-M of <file>`, `<file>:N`, `<file>:N-M` — capture the file token and line range. Symbol forms (the preferred citation style, v4.23.0+ — `/light-spec` now emits path + symbol because line numbers rot fastest): `` `<file>` → `<symbol>` ``, `<symbol>() in <file>`, a backticked symbol and backticked file named in the same sentence, and `<file> § <heading>` for markdown targets — capture the file token and the symbol/heading text.
3. **Linear status claim.** A line in the spec body of the form `Status: <name>` (typical Light Spec metadata). Capture the stated status.
4. **Dependency claims.** Cross-references to other Linear issues (`PROJ-NN`) inside §Dependencies, §Blocked by, or in narrative prose like *"blocked by PROJ-42 (Done)"*. The blocker list also comes from `relations.blocked_by` in Step 1 — combine both sources, dedupe by identifier.

If a category yields zero claims, that's fine — record it as `n/a` in the verdict, not a failure.

### Step 3 — Verify each claim

For every parsed claim, verify against reality. Check categories in this order so that infrastructure-degraded checks don't block file-path checks (which are always verifiable).

#### 3a — File paths

For each path, prefer `Read` (cheaper than Glob for known paths). On `ENOENT`, fall back to `Glob` with the basename to detect renames. Record:

- `exists` — file present at the cited path
- `renamed_to` — if Glob found a single match elsewhere, surface it

A missing file is a real divergence (fail-loud), not infrastructure noise.

**Exception — explicit-NEW markers.** Before flagging a missing file as `✗`, check whether the surrounding spec text marks the path as a NEW file the implementation will create. Treat any of the following as an explicit-NEW marker on the line of the path, on the same line, on the line before, or in a section header within 5 lines above:

- `NEW` (bold, plain, or in parentheses): `**NEW**`, `(NEW)`, `, NEW`
- `(new)` / `(new file)`
- "**Files to create**" or "**New files**" section heading that contains the path
- `NEW: <path>` prefix

When an explicit-NEW marker is present, record the path as `🆕 expected-new` instead of `✗ missing` — the spec is asserting this file will be created, not that it exists. The Phase 1–3 verdict treats `🆕 expected-new` as `✓` for the file-paths category. The pre-existing files in the same list still get verified normally; only the NEW-marked paths get the downgrade.

Why: WIT-348 and WIT-451 (both Pipekit v2.4.x canary subjects) listed NEW components explicitly in their specs (`line-item-actions.tsx`, `line-item-edit-dialog.tsx`, `move-line-item-dialog.tsx`), each clearly annotated NEW in the Technical Context section. v2.4.0's preflight emitted `✗` for all of them, which over-stated the divergence and forced manual exception-noting in the verdict. v2.4.2 collapses that noise.

#### 3b — Code citations (line + symbol)

For each `<file>:N` or `<file>:N-M`, call `Read` with `offset: N` and `limit: M-N+1` (or `1` for a single line). Record:

- `resolves` — the line range exists (file is at least N lines long)
- Optionally capture the cited content for the verdict (helps the user see if the line still says what the spec claims)

A line range past EOF is a divergence — record `resolves: false`.

For each symbol/heading citation, `Grep` the cited file for the symbol's definition or the heading text (for a symbol, match declaration-shaped lines first — `function <sym>|const <sym>|def <sym>|class <sym>|export.*<sym>` — falling back to any occurrence; for a heading, match `^#+\s*<heading>`). Record:

- `resolves` — the symbol/heading exists in the cited file
- `moved_to` — if absent from the cited file, `Grep` the repo (excluding `node_modules/`) for the same declaration; a single hit elsewhere is a move — surface the new location, mirroring 3a's `renamed_to`

A symbol found nowhere is a divergence (`✗`, REVISE). A moved symbol is `⚠` with the new location — the spec needs a path update, but the contract still exists. When a citation carries both a symbol and a line number, the symbol is authoritative: if the symbol resolves at a different line, record `⚠ drifted (symbol at line X, spec says Y)` rather than `✗`.

#### 3c — Linear status

Re-fetch the issue (or reuse Step 1's payload if still in scope). Compare `state.name` to the spec body's `Status:` line. Record `match` or `mismatch (spec says X, actual Y)`. The spec body claim is a documentation artifact, not the source of truth — Linear is. The point is to surface drift so the human knows the spec body is stale.

#### 3d — Dependencies

For each `blocked_by` identifier (from `relations` and from any narrative claims in Step 2.5), call `mcp__linear-server__linear_getIssueById` and read `state.name`. Record `Done` / `<other>`. The pass criterion is "every blocker is Done"; anything else is a real gate failure that `pk branch` / `/work` would also catch — surfacing it pre-flight saves a round trip.

If the Linear MCP server times out or is unavailable on any individual fetch: record that specific dependency as `unverified — Linear API timeout` and continue. Do not fail the whole verdict on infrastructure flake. (See Graceful Degradation below.)

### Step 3.6 — Project signal probes

Steps 1–3 verify claims the spec **explicitly makes** (this file exists, that line resolves, this WIT is Done). Step 3.6 probes claims the spec **implies** — by referencing a tool, by proposing a platform-specific mechanism, by drafting a migration, or by anchoring to a non-canonical source. These are the "environmental blindness" gaps the v2.3.x recovery surfaced; without them, downstream agents read a spec that's internally consistent but reality-divergent.

Each probe runs independently. A miss in one does not skip the others. Findings render as a separate category-block under the verdict. Where a probe needs `method.config.md` keys, fall through gracefully if the key is unset.

#### 3.6a — Canonical-doc cross-check (handoff #21)

**Trigger:** the spec body contains any of `POC`, `parity with POC`, `POC pattern`, `the POC` (case-insensitive) AND `method.config.md`'s `Strategy docs path` resolves to an existing directory.

**Probe:**
1. Read `Strategy docs path` from `method.config.md` (default: `Strategy/`).
2. `Glob` `<path>/*.md` and `<path>/**/*.md`. Capture the file list.
3. For each Strategy doc, scan the first 200 lines (section index) for headings that overlap concept words from the spec body. Concept words: nouns appearing in the spec's §Goal, §Acceptance Criteria headings, or italicized key terms.
4. **Strategy-citation check (v2.4.2):** scan the spec body for inline citations of any Strategy doc — patterns like `Strategy/Doc<N>`, `Strategy/Doc<N>_<name>.md`, `Strategy/Doc<N> §<section>`, or an `Authority hierarchy` table that names a Strategy file as the authority for a concern. If the spec body cites ≥1 Strategy doc inline, treat the cross-check as **performed** (the spec author already did the work the probe is asking for) and downgrade the emit to `✓ Canonical docs: Strategy cited inline at <doc>:<section>` instead of `⚠`.

**Emit (default `⚠` — ambiguous; the human decides whether topic overlap is load-bearing):**

```
⚠ Canonical docs: Strategy at <path> contains <N> doc(s); spec body references POC.
    Cross-check spec claims against:
      - Strategy/<doc1>.md (sections: ...)
      - Strategy/<doc2>.md (sections: ...)
    Strategy is canonical for this project; POC may diverge.
```

**Emit when Strategy is cited inline in the spec body (v2.4.2 downgrade):**

```
✓ Canonical docs: spec body cites Strategy inline (<list of cited docs+sections>);
    cross-check performed in-spec. No further action.
```

If `Strategy docs path` is unset OR the directory is empty: record `n/a — no Strategy docs configured`. Do not warn — projects without Strategy docs are valid.

Why the downgrade was added: WIT-451's revised spec body cited Strategy/Doc6 §2.1, Strategy/Doc6 §3.3 line 86, and Strategy/Doc2 §3.3.1 throughout — and had an explicit "Authority hierarchy" table naming Strategy as the canonical source for the 5-action button set, conversation surface, and line-item canonical fields. v2.4.0's probe still emitted `⚠ Cross-check spec claims against Strategy` because the trigger ("POC mentioned + Strategy/ exists") fired blindly. The downgrade keeps the probe useful for specs that haven't done the cross-check while letting fully-cited specs pass cleanly.

#### 3.6b — Platform capability (handoff #20)

**Trigger:** the spec body contains any of `ALTER DATABASE`, `SET app\.`, `current_setting\(`, `pg_db_role_setting`, `GUC`, or other Postgres custom-parameter patterns.

**Probe:** (only runs when the trigger fires — if no GUC pattern appears in the spec, this probe renders as `✓ n/a`)

1. Read `Platform` from `method.config.md`. Recognized values: `managed-supabase`, `self-hosted-postgres`, `none`. Default: unset (treated as "unconfigured").
2. If `Platform: managed-supabase`: managed Supabase blocks the `postgres` role from `ALTER DATABASE … SET <custom>` even when role-owns the DB (verified empirically during WIT-450, handoff #20). Emit `✗` (hard fail) with the known-blocker note.
3. If `Platform: self-hosted-postgres`: emit `⚠` reminder to confirm the role has `ALTER DATABASE` privilege on the target DB.
4. If `Platform` unset or `none`: emit `⚠ Platform key not configured — GUC capability unverified for this deployment` and continue. Spec author should set `Platform` so the next preflight gives a definitive answer.

**Emit (`✗` for managed-supabase, `⚠` otherwise):**

```
✗ Platform capability: spec proposes GUC-based mechanism (ALTER DATABASE … SET app.X);
    Platform=managed-supabase blocks this — postgres role lacks SET DATABASE privilege
    even as db owner (handoff #20, verified at WIT-450 against piper-prod + piper-dev).
    Redesign with a sentinel-table pattern OR change Platform if the deployment moved.
```

#### 3.6c — Tooling availability (handoff #22)

**Trigger:** an Acceptance Criterion line mentions any known test runner / quality tool / framework name. Detection list (extend as projects evolve):

| Tool | Package(s) to grep for |
|------|----------------------|
| Playwright | `@playwright/test`, `playwright` |
| Cypress | `cypress` |
| Jest | `jest` |
| Vitest | `vitest` |
| Storybook | `@storybook/`, `storybook` |
| Lighthouse | `lighthouse`, `lighthouse-ci`, `@lhci/cli` |
| ESLint | `eslint` |
| Prettier | `prettier` |
| MSW | `msw` |
| Testing Library | `@testing-library/` |

**Probe:**
1. Locate `package.json` files: repo root + every workspace `package.json` discoverable via `Glob` `**/package.json` (skip `node_modules/`).
2. For each tool detected in an AC, `Grep` the combined package.json set for the package names listed above (check both `dependencies` and `devDependencies`).
3. Also check the lockfile (`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock`) — a package in the lockfile but not `package.json` means it's a transitive dep, not directly callable. Treat as absent.

**Emit (`✗` hard fail — high-confidence blocker, downgradeable to `⚠` with `--accept`):**

```
✗ Tooling availability: AC #5 requires Playwright but @playwright/test not in
    package.json (dependencies or devDependencies). The AC is unsatisfiable as
    written. Either:
      a) bootstrap @playwright/test (separate WIT first), or
      b) rewrite AC against an existing test runner (Vitest is configured).
```

If the AC mentions a tool but the same AC also says "to be added" / "follow-up" / "next phase": downgrade to `⚠` automatically — the spec author already acknowledged the gap.

#### 3.6d — Migration data shape (handoff #24)

**Trigger:** the spec body cites a migration path under `Migration dir` (from `method.config.md`), OR proposes a migration with `CHECK`, `NOT NULL`, type narrowing (`varchar(255)` → `varchar(64)`), or column rename language.

**Probe:**
1. `Read` each cited migration file (or the spec's inline SQL block).
2. Scan for:
   - `ALTER TABLE … ADD CONSTRAINT … CHECK \(`
   - `ALTER TABLE … ALTER COLUMN … SET NOT NULL`
   - `ALTER TABLE … RENAME COLUMN`
   - Type-narrowing `ALTER COLUMN … TYPE`
3. For each constraint, build the inverse predicate as a `SELECT COUNT(*)` query. Example: `CHECK (show_end_date <= onsite_end_date)` becomes `SELECT COUNT(*) FROM <table> WHERE NOT (show_end_date <= onsite_end_date);`.
4. **If a Supabase MCP is bound** (any `mcp__supabase-*__execute_sql` tool available in this session): run the query against the parent project (read-only `SELECT` — safe even on prod-tier). Emit the count.
5. **If no MCP is bound**: emit the query template for the user to run manually.

**Emit (`⚠` — surface for review; the spec author decides whether 0 violators is required or whether to add a backfill):**

```
⚠ Migration data shape: 2 new constraint(s) on populated columns.
    Run violator counts against parent project before merging:

      -- CHECK (show_end_date <= onsite_end_date)
      SELECT COUNT(*) FROM projects WHERE NOT (show_end_date <= onsite_end_date);
      -- count via piper-dev MCP: 1 violator

      -- NOT NULL on projects.production_start
      SELECT COUNT(*) FROM projects WHERE production_start IS NULL;
      -- count via piper-dev MCP: 0 violators

    Decide per row: backfill, default, or block migration until data is consistent.
```

This is the same shape gap as WIT-384's per-PR branch DBs running `with_data: false` — schema-only validation passes, data-incompatibility fails at apply-time against the populated parent. The probe shifts that discovery left, to spec-time.

#### When `--accept` is in effect

If the skill was invoked with `--accept`:
- Phase 3.6 hard-fails (`✗`) downgrade to warnings (`⚠`).
- A banner line appears above the verdict: `--accept: Phase 3.6 hard-fails downgraded to warnings.`
- Steps 1–3 hard-fails are unaffected (file-presence / line-ref / dependency failures remain blocking — `--accept` does not bypass empirical claim divergence).

### Step 4 — Render verdict

Print a single block to stdout. Use checkmarks (`✓`), warning markers (`⚠`), and failure markers (`✗`) so humans can scan it fast. Format:

```
Pre-flight checks for PROJ-XXX ({tier} tier):

  ─ Empirical claims (Phase 1–3)
  ✓ File paths: {n_pass}/{n_total} exist
  ✓ Code refs (line/symbol): {n_pass}/{n_total} resolve
  ✓ Linear status: {state} (matches spec)
  ✓ Dependencies: {n_done}/{n_total} Done

  ─ Project signal probes (Phase 3.6)
  {emoji} Canonical docs: {message or n/a}
  {emoji} Platform capability: {message or n/a}
  {emoji} Tooling availability: {message or n/a}
  {emoji} Migration data shape: {message or n/a}

Verdict: {PASS | REVISE} — {one-line reason if REVISE}
{action hint if REVISE}
```

Verdict rules:

- **PASS** — every category is `✓` or `n/a` (no claims of that type) or graceful-degradation `⚠ unverified` for the Linear API. Phase 3.6 may emit `⚠` (warnings) and still PASS — warnings inform but don't block.
- **REVISE** — at least one real divergence in Phases 1–3 (missing file, unresolved line, status mismatch, non-Done dependency) OR a Phase 3.6 hard-fail (`✗`: managed-Supabase GUC pattern; tooling absent from `package.json`). The user updates the spec (or resolves the blocker) before `pk branch`.
- **REVISE (downgraded with `--accept`)** — Phase 3.6 hard-fails alone don't force REVISE when `--accept` is in effect; they appear as warnings. Phase 1–3 hard-fails are never downgradeable.

When emitting REVISE, point at *where* in the spec the divergence sits — by AC number, by section heading, by file path, or by the migration constraint — so the human can edit surgically rather than re-reading the whole spec.

### Step 5 — Stop

Print the verdict. Do nothing else. Do not call `pk branch` or `/work`. Do not transition Linear. Do not write any project file (NEXT.md is retired in v2 anyway, but this skill writes nothing — it gates the next move).

## Graceful Degradation

These rules are explicit so the skill stays useful when infrastructure is partially down:

| Condition | Behavior |
|-----------|----------|
| Linear MCP timeout fetching the main issue | Stop. The skill needs the spec body to do anything else. Report `"Linear API unavailable — re-run later."`. |
| Linear MCP timeout fetching a blocker | Record that dependency as `⚠ unverified`. Verdict is PASS-eligible if all other categories pass. |
| File doesn't exist | Real divergence. Record `✗`. Triggers REVISE. Not graceful — file-presence is verifiable without infrastructure. |
| Line range past EOF | Same as above — `✗`, REVISE. |
| `Strategy docs path` unset / dir empty | Canonical-docs probe records `n/a`. Not a warning — projects without Strategy docs are valid. |
| `Platform` key unset | Platform-capability probe records `⚠ Platform key not configured — capability unverified` only if the spec body triggered the probe (GUC pattern detected). |
| No `package.json` discoverable | Tooling-availability probe records `⚠ no package.json found — tooling claims unverified`. Verdict PASS-eligible. |
| No Supabase MCP bound | Migration-data-shape probe emits query templates for manual run. No `⚠` from this alone — surfacing the query is the deliverable. |

Graceful degradation never *upgrades* the verdict (a `⚠` cannot become `✓`); it just keeps a single failure mode from blocking the rest of the report.

## Output Examples

PASS verdict:

```
Pre-flight checks for RS-87 (Standard tier):

  ─ Empirical claims (Phase 1–3)
  ✓ File paths: 4/4 exist
  ✓ Code refs (line/symbol): 2/2 resolve
  ✓ Linear status: Approved (matches spec)
  ✓ Dependencies: 2/2 Done

  ─ Project signal probes (Phase 3.6)
  ✓ Canonical docs: n/a — no Strategy docs configured
  ✓ Platform capability: n/a — no GUC pattern in spec
  ✓ Tooling availability: 1/1 verified (Vitest in package.json)
  ✓ Migration data shape: n/a — no migration cited

Verdict: PASS — spec is empirically current. Proceed to pk branch RS-87.
```

REVISE with a Phase 1–3 divergence:

```
Pre-flight checks for RS-51 (Standard tier):

  ─ Empirical claims (Phase 1–3)
  ✓ File paths: 5/5 exist
  ✓ Code refs (line/symbol): 3/3 resolve
  ✗ Linear status: Needs Spec (spec body says Approved)
  ✓ Dependencies: 2/2 Done

  ─ Project signal probes (Phase 3.6)
  ✓ Canonical docs: n/a — no Strategy docs configured
  ✓ Platform capability: n/a
  ✓ Tooling availability: n/a — no test runner in ACs
  ✓ Migration data shape: n/a

Verdict: REVISE — Linear status diverges from the spec body.
Update the spec's "Status: Approved" line (or advance the issue) before pk branch.
```

REVISE with the WIT-348 canary pattern (#21 + #22):

```
Pre-flight checks for WIT-348 (Standard tier):

  ─ Empirical claims (Phase 1–3)
  ⚠ File paths: 4/6 exist (renamed: projects.js → database/projects.js,
                            budget-edit-main.js → pages/budget-edit-main.js)
  ✓ Code refs (line/symbol): 2/2 resolve
  ✓ Linear status: Specced (matches spec)
  ✓ Dependencies: 1/1 Done

  ─ Project signal probes (Phase 3.6)
  ⚠ Canonical docs: Strategy at Strategy/ contains 2 doc(s); spec body references POC.
      Cross-check spec claims against:
        - Strategy/Doc1_ConceptualOverview.md §3.1 (project lifecycle dates)
        - Strategy/Doc2_TechnicalSpec.md §3.2.3 (six date fields, engagement defaults)
      Strategy defines 6 lifecycle date fields; spec claims 5. Reconcile before approval.
  ✓ Platform capability: n/a — no GUC pattern in spec
  ✗ Tooling availability: AC #5 requires Playwright but @playwright/test not in
      package.json. Either bootstrap (separate WIT) or rewrite against Vitest.
  ⚠ Migration data shape: 5 chronological CHECK constraint(s) on projects (populated).
      Run violator counts via piper-dev MCP before merging:
        SELECT COUNT(*) FROM projects WHERE NOT (show_end_date <= onsite_end_date);
        SELECT COUNT(*) FROM projects WHERE NOT (project_start_date <= production_start);
        -- (3 more)

Verdict: REVISE
  - File path renames (2): update §Technical Context paths.
  - Canonical-doc divergence: spec claims 5 fields, Strategy says 6. Reconcile §Goal + ACs.
  - Tooling absent: AC #5 Playwright requirement unsatisfiable until bootstrap WIT lands.
  - Migration data shape: 5 CHECKs on populated table — run violator counts first.
```

REVISE downgraded with `--accept`:

```
--accept: Phase 3.6 hard-fails downgraded to warnings.

Pre-flight checks for WIT-348 (Standard tier):

  ─ Empirical claims (Phase 1–3)
  ✓ File paths: 6/6 exist
  ✓ Code refs (line/symbol): 2/2 resolve
  ✓ Linear status: Specced (matches spec)
  ✓ Dependencies: 1/1 Done

  ─ Project signal probes (Phase 3.6)
  ⚠ Canonical docs: ...
  ⚠ Tooling availability: AC #5 Playwright absent (--accept: hard-fail downgraded)
  ⚠ Migration data shape: ...

Verdict: PASS (with --accept warnings) — proceed knowing the listed gaps are accepted-risk.
```

## Rules of Engagement

- **Read-only.** Never edit the spec. Never transition Linear. Never write any project file. The only writes allowed are scratch files under `/tmp/` for parsing state.
- **No false confidence.** A graceful-degradation `⚠` is not a `✓`. The verdict surfaces what was unverified so the human can re-run later or accept the gap.
- **Specific divergences.** When something fails, name *which* claim failed (AC #, section heading, file path, dependency identifier) — not just "a mismatch." The user shouldn't have to grep the spec to find what to fix.
- **Don't recurse into the daily loop.** This skill ends at the verdict. The user invokes `pk branch <ID>` themselves on PASS (then `/work` from inside the worktree), or `/light-spec-revise` on REVISE.

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/light-spec` | Produces the spec this skill verifies. |
| Spec Review Agent | Reviews narrative coherence. `/spec-preflight` reviews empirical claims — complementary, not redundant. |
| `/light-spec-revise` | Where the user goes on REVISE if the spec body is the problem (most cases). |
| `pk branch` + `/work` | The daily loop consumes specs that have passed `/spec-preflight`. |
