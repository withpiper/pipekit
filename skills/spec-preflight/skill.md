---
name: spec-preflight
description: Empirical pre-flight checks on a Linear issue's spec. Verifies file paths, line refs, phase-detect baseline, Linear status, and dependencies against reality. Read-only.
---

# Spec Preflight Skill

You verify that the empirical claims in a Linear issue's spec match reality, *before* `pk branch <ID>` + `/work` consume the spec. Spec Review Agent reviews narrative coherence; this skill reviews facts. The two are complementary — agent review catches "is the spec well-shaped?", `/spec-preflight` catches "is the spec still true?".

This skill is **read-only**: it never edits the spec, never transitions Linear status, never writes any project file. Output goes to stdout only. (A scratch file under `/tmp/` is acceptable for analysis state.)

Read `method.config.md` for project context (Linear team prefix, state IDs, project root).

## Triggers

- `/spec-preflight PROJ-XXX` — verify a single specced issue
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
| Linear issue body | `mcp__linear-server__get_issue` with `includeRelations: true` | Spec body + status + blocked_by |
| File paths from spec | `Read` or `Glob` | Confirm cited files exist |
| Line ranges from spec | `Read` with `offset`/`limit` | Confirm line citations resolve to real content |
| `phase-detect.sh` output | Bash via the v1.4.1 lookup chain (see Step 3) | Confirm stated VBW baseline is current |
| Linear status (re-fetched) | `mcp__linear-server__get_issue` | Compare current status against spec body's claim |
| Each `blocked_by` issue | `mcp__linear-server__get_issue` | Confirm dependency claims of "Done" |

## Algorithm

### Step 1 — Fetch the issue

Call `mcp__linear-server__get_issue` with `id: PROJ-XXX` and `includeRelations: true`. Capture:

- `title`, `identifier`
- Full `description` (the spec body)
- Current `state.name` (e.g., `Approved`, `Specced`, `Building`)
- `relations` filtered to `blocked_by` (each carries an issue identifier and its state)

If the issue isn't found or has no description: stop and report `"PROJ-XXX has no spec body. Run /light-spec first."`. Do not proceed to checks.

### Step 2 — Parse empirical claims

Walk the spec body and bucket claims into five categories. Use these heuristics — when in doubt, prefer false-positive (treat ambiguous text as a claim and verify it) over false-negative (silently skipping a claim).

1. **File paths.** Any backtick-quoted token containing `/` or a file extension (e.g., `` `supabase/config.toml` ``, `` `src/lib/auth.ts` ``). Treat absolute paths and project-relative paths the same way. Strip surrounding punctuation.
2. **Line citations.** Match `line N of <file>`, `lines N-M of <file>`, `<file>:N`, `<file>:N-M`. Capture the file token and the line range.
3. **Phase-detect baselines.** Phrases like `phase_count=N`, `next_phase_state=<value>`, `qa_status=<value>`, especially when they appear in §Acceptance Criteria after wording like *"currently returns"*, *"baseline is"*, *"expect"*. Capture the field name and stated value.
4. **Linear status claim.** A line in the spec body of the form `Status: <name>` (typical Light Spec metadata). Capture the stated status.
5. **Dependency claims.** Cross-references to other Linear issues (`PROJ-NN`) inside §Dependencies, §Blocked by, or in narrative prose like *"blocked by PROJ-42 (Done)"*. The blocker list also comes from `relations.blocked_by` in Step 1 — combine both sources, dedupe by identifier.

If a category yields zero claims, that's fine — record it as `n/a` in the verdict, not a failure.

### Step 3 — Verify each claim

For every parsed claim, verify against reality. Check categories in this order so that infrastructure-degraded checks don't block file-path checks (which are always verifiable).

#### 3a — File paths

For each path, prefer `Read` (cheaper than Glob for known paths). On `ENOENT`, fall back to `Glob` with the basename to detect renames. Record:

- `exists` — file present at the cited path
- `renamed_to` — if Glob found a single match elsewhere, surface it

A missing file is a real divergence (fail-loud), not infrastructure noise.

#### 3b — Line citations

For each `<file>:N` or `<file>:N-M`, call `Read` with `offset: N` and `limit: M-N+1` (or `1` for a single line). Record:

- `resolves` — the line range exists (file is at least N lines long)
- Optionally capture the cited content for the verdict (helps the user see if the line still says what the spec claims)

A line range past EOF is a divergence — record `resolves: false`.

#### 3c — phase-detect baseline

Resolve `phase-detect.sh` using the same lookup chain as `/work` (which inherited it from the v1 `/launch` Step 1.6 logic):

```bash
PHASE_DETECT=""
if command -v phase-detect.sh >/dev/null 2>&1; then
  PHASE_DETECT="phase-detect.sh"
elif [ -x ".vbw-planning/scripts/phase-detect.sh" ]; then
  PHASE_DETECT=".vbw-planning/scripts/phase-detect.sh"
else
  for c in "$HOME"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/phase-detect.sh; do
    [ -x "$c" ] && PHASE_DETECT="$c"
    # Don't break — alphabetic glob expansion means later iterations
    # overwrite with higher-versioned VBW installs.
  done
fi

if [ -n "$PHASE_DETECT" ]; then
  "$PHASE_DETECT" > /tmp/pipekit-spec-preflight-vbw.txt 2>/dev/null
  PHASE_DETECT_RC=$?
else
  PHASE_DETECT_RC=127
fi
```

If `PHASE_DETECT_RC != 0` or the script is unavailable: record the phase-detect category as `VBW state unverified — phase-detect.sh unavailable`. This is graceful degradation, not failure. Do not fail the verdict on this category alone.

If the script ran, parse its output line-by-line (it emits `key=value` pairs). For each phase-detect baseline claim from Step 2, compare stated value against actual value. Record `match` / `mismatch (spec says X, actual Y)`.

#### 3d — Linear status

Re-fetch the issue (or reuse Step 1's payload if still in scope). Compare `state.name` to the spec body's `Status:` line. Record `match` or `mismatch (spec says X, actual Y)`. The spec body claim is a documentation artifact, not the source of truth — Linear is. The point is to surface drift so the human knows the spec body is stale.

#### 3e — Dependencies

For each `blocked_by` identifier (from `relations` and from any narrative claims in Step 2.5), call `mcp__linear-server__get_issue` and read `state.name`. Record `Done` / `<other>`. The pass criterion is "every blocker is Done"; anything else is a real gate failure that `pk branch` / `/work` would also catch — surfacing it pre-flight saves a round trip.

If the Linear MCP server times out or is unavailable on any individual fetch: record that specific dependency as `unverified — Linear API timeout` and continue. Do not fail the whole verdict on infrastructure flake. (See Graceful Degradation below.)

### Step 4 — Render verdict

Print a single block to stdout. Use checkmarks (`✓`), warning markers (`⚠`), and failure markers (`✗`) so humans can scan it fast. Format:

```
Pre-flight checks for PROJ-XXX ({tier} tier):

  ✓ File paths: {n_pass}/{n_total} exist
  ✓ Line refs: {n_pass}/{n_total} resolve
  ⚠ phase-detect baseline: spec says {field}={stated}, actual={observed}
  ✓ Linear status: {state} (matches spec)
  ✓ Dependencies: {n_done}/{n_total} Done

Verdict: {PASS | REVISE} — {one-line reason if REVISE}
{action hint if REVISE}
```

Verdict rules:

- **PASS** — every category is `✓` or `n/a` (no claims of that type) or graceful-degradation `⚠ unverified` for phase-detect / Linear API. The user can proceed to `pk branch <ID>` without manual gut-checking.
- **REVISE** — at least one real divergence: missing file, unresolved line, phase-detect mismatch, status mismatch, or non-Done dependency. The user updates the spec (or resolves the blocker) before `pk branch`.

When emitting REVISE, point at *where* in the spec the divergence sits — by AC number, by section heading, or by the claim text — so the human can edit surgically rather than re-reading the whole spec.

### Step 5 — Stop

Print the verdict. Do nothing else. Do not call `pk branch` or `/work`. Do not transition Linear. Do not write any project file (NEXT.md is retired in v2 anyway, but this skill writes nothing — it gates the next move).

## Graceful Degradation

These rules are explicit so the skill stays useful when infrastructure is partially down:

| Condition | Behavior |
|-----------|----------|
| `phase-detect.sh` not found anywhere | Phase-detect category records `⚠ VBW state unverified`. Verdict is still PASS-eligible if all other categories pass. |
| `phase-detect.sh` exits non-zero | Same as above — record `⚠ VBW state unverified` with the exit code in `--explain` mode. |
| Linear MCP timeout fetching the main issue | Stop. The skill needs the spec body to do anything else. Report `"Linear API unavailable — re-run later."`. |
| Linear MCP timeout fetching a blocker | Record that dependency as `⚠ unverified`. Verdict is PASS-eligible if all other categories pass. |
| File doesn't exist | Real divergence. Record `✗`. Triggers REVISE. Not graceful — file-presence is verifiable without infrastructure. |
| Line range past EOF | Same as above — `✗`, REVISE. |

Graceful degradation never *upgrades* the verdict (a `⚠` cannot become `✓`); it just keeps a single failure mode from blocking the rest of the report.

## Output Examples

PASS verdict:

```
Pre-flight checks for RS-87 (Standard tier):

  ✓ File paths: 4/4 exist
  ✓ Line refs: 2/2 resolve
  ✓ phase-detect baseline: phase_count=1 (matches spec)
  ✓ Linear status: Approved (matches spec)
  ✓ Dependencies: 2/2 Done

Verdict: PASS — spec is empirically current. Proceed to pk branch RS-87.
```

REVISE with a real divergence:

```
Pre-flight checks for RS-51 (Standard tier):

  ✓ File paths: 5/5 exist
  ✓ Line refs: 3/3 resolve
  ⚠ phase-detect baseline: spec says phase_count=0, actual=1
  ✓ Linear status: Approved (matches spec)
  ✓ Dependencies: 2/2 Done

Verdict: REVISE — phase-detect baseline divergence at AC #1.
Update the spec's "currently returns phase_count=0" line before pk branch.
```

REVISE with infrastructure degradation plus a real divergence:

```
Pre-flight checks for RS-92 (Quick tier):

  ✗ File paths: 2/3 exist (missing: src/lib/old-auth.ts)
  ✓ Line refs: 1/1 resolve
  ⚠ VBW state unverified — phase-detect.sh unavailable
  ✓ Linear status: Approved (matches spec)
  ⚠ Dependencies: 1/2 verified — RS-89 Linear API timeout

Verdict: REVISE — src/lib/old-auth.ts cited in §Technical Context no longer exists.
Likely renamed during recent refactor; update the spec path before pk branch.
```

## Rules of Engagement

- **Read-only.** Never edit the spec. Never transition Linear. Never write any project file. The only writes allowed are scratch files under `/tmp/` for parsing state.
- **No false confidence.** A graceful-degradation `⚠` is not a `✓`. The verdict surfaces what was unverified so the human can re-run later or accept the gap.
- **Specific divergences.** When something fails, name *which* claim failed (AC #, section heading, file path, dependency identifier) — not just "phase-detect mismatch." The user shouldn't have to grep the spec to find what to fix.
- **Don't recurse into the daily loop.** This skill ends at the verdict. The user invokes `pk branch <ID>` themselves on PASS (then `/work` from inside the worktree), or `/light-spec-revise` on REVISE.

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/light-spec` | Produces the spec this skill verifies. |
| Spec Review Agent | Reviews narrative coherence. `/spec-preflight` reviews empirical claims — complementary, not redundant. |
| `/light-spec-revise` | Where the user goes on REVISE if the spec body is the problem (most cases). |
| `pk branch` + `/work` | The v2 daily loop consumes specs that have passed `/spec-preflight`. `/work` also reads `phase-detect.sh` (inherited from v1's `/launch` Step 1.6 logic), but as a runtime informational gate, not as a spec-vs-reality check. |
