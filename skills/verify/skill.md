---
name: verify
description: V2.7 verify — tier-aware evidence-gated pre-deploy gate. Writes Logs/Verify/<date>/<id>/{evidence.txt,reality-check.md,verify-complete.md} when tier != quick. Use when a Linear issue is ready for verify (Stage 3). Use when /work finished and you need a Pass/Partial/Fail verdict per AC before pk ship.
---

# /verify

> **North star:** safe and frictionless. Helps, never adds work.

You verify that a feature branch's work is shippable. You run the project's pre-deploy gate (tests, lint, types), enumerate human-decision flags, and — when configured or invoked with `--qa` — spawn a QA review subagent that checks the diff against the issue's acceptance criteria.

**v2.7 evidence layer.** For tier:standard and tier:heavy, every run produces three files under `Logs/Verify/<YYYYMMDD>/<ISSUE>/`:

- `evidence.txt` — raw gate output with per-command exit codes and durations, plus appended `FLAG: ...` lines
- `reality-check.md` — structured verdict with gate results table, QA block, flags, status reasoning
- `verify-complete.md` — minimal sentinel written only on PASS

The Day 3 wiring will have `pk ship` read `verify-complete.md` as a hard gate. Day 2 (this skill) only **writes** the artifacts; `pk ship` does not yet consult them.

## Triggers

- `/verify` — primary; uses current branch's issue ID
- `/verify <ISSUE-ID>` — explicit
- `/verify --qa` — force QA review even if `Require QA review: false`
- "verify this" / "is this ready to ship?"

## Required preconditions

1. You are inside a worktree on a feature branch (or pass an explicit issue ID).
2. There are committed changes on the branch (else: nothing to verify).
3. `method.config.md` § Pre-Deploy Gate is configured (else `/verify` exits with a clear "configure your gate" message).

## Step 0 — Resolve issue, tier, and evidence dir

```bash
CURRENT=$(git branch --show-current)
ISSUE="${1:-}"
[ -z "$ISSUE" ] && ISSUE=$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)
[ -z "$ISSUE" ] && { echo "ERROR: pass an issue ID or run on a feature branch." >&2; exit 1; }

# Need at least one commit ahead of integration
INTEGRATION=$(pk config "Integration branch" "dev")
COMMITS_AHEAD=$(git rev-list --count "origin/$INTEGRATION..HEAD" 2>/dev/null || echo 0)
[ "$COMMITS_AHEAD" = "0" ] && { echo "ERROR: no commits ahead of $INTEGRATION — nothing to verify." >&2; exit 1; }

# Tier resolution — v2.7. Falls back to "standard" when Linear is unreachable.
TIER=$(pk_linear_tier "$ISSUE" 2>/dev/null || echo "standard")

# Stable per-run stamp; one directory per issue per day. Re-runs overwrite.
STAMP=$(date -u +%Y%m%dT%H%MZ)
TODAY=$(date -u +%Y%m%d)
VERIFY_DIR="Logs/Verify/${TODAY}/${ISSUE}"
```

## Step 0.5 — Tier-gated dispatch (one-screen contract)

| Tier | Evidence layer | reality-check.md | verify-complete.md | QA subagent | pk ship gate |
|---|---|---|---|---|---|
| quick | no | virtual (printed only) | virtual | only if `--qa` | warn-but-proceed (Day 3) |
| standard | yes | written | written on PASS | per config + `--qa` | hard, file required (Day 3) |
| heavy | yes | written | written on PASS | per config + `--qa` | hard, file required (Day 3) |

Antagonistic review (mandatory in heavy, opt-in via `--review` in standard) is wired Day 4.

For tier:quick, the rest of this skill executes against stdout only — no file writes — and Step 6 / Step 7 are skipped. For tier:standard and tier:heavy, every step below appends to or writes the files under `$VERIFY_DIR`.

## Step 1 — Read configuration

Read from `method.config.md`:

- `Require QA review` (default `false`) — controls whether QA subagent runs by default
- `Backend` (default `vbw`) — used for QA subagent type selection
- `## Pre-Deploy Gate` — bash code block of test/lint/type commands

Resolve `--qa`:
- Explicit `--qa` flag → run QA
- `Require QA review: true` in config → run QA
- Else → skip QA

Print one line:

```
Verify: <ISSUE-ID>  ·  Tier: <TIER>  ·  Gate: yes  ·  QA: <yes|no>  ·  Evidence: <VERIFY_DIR | (quick, virtual)>
```

## Step 2 — Initialize evidence layer (skip for tier:quick)

For `TIER != quick`, create the evidence directory and write the header:

```bash
if [ "$TIER" != "quick" ]; then
  mkdir -p "$VERIFY_DIR"
  cat > "$VERIFY_DIR/evidence.txt" <<EOF
# /verify evidence — $ISSUE
# stamp: $STAMP
# tier: $TIER
# integration: $INTEGRATION
# commits-ahead: $COMMITS_AHEAD

EOF
fi
```

Re-runs **overwrite** `evidence.txt` rather than appending — each `/verify` invocation is a fresh snapshot of "what would ship from this HEAD."

## Step 3 — Run the pre-deploy gate

Extract the bash block from the config's § Pre-Deploy Gate section. Run each command through a writer that captures the exit code and duration.

Implementation:

```bash
# Read the bash block between ```bash and ``` after the "## Pre-Deploy Gate" heading.
# The leading awk uses `next` after matching the start line so the end-pattern
# check (/^## /) does not also match the start line and self-terminate the range.
awk '/^## Pre-Deploy Gate[[:space:]]*$/{flag=1; next} /^## /{flag=0} flag' method.config.md \
  | awk '/^```bash/,/^```$/' \
  | grep -v '^```' > /tmp/pk-gate.sh

set -o pipefail

# tier:quick — bulk runner, stdout only.
if [ "$TIER" = "quick" ]; then
  bash /tmp/pk-gate.sh
  GATE_RC=$?
else
  # tier:standard / heavy — per-command writer with anchors.
  run_gate_command() {
    local cmd="$1"
    printf '==> $ %s\n' "$cmd" >> "$VERIFY_DIR/evidence.txt"
    local start; start=$(date +%s)
    bash -c "$cmd" 2>&1 | tee -a "$VERIFY_DIR/evidence.txt"
    local rc=${PIPESTATUS[0]}
    printf 'exit: %d\nduration: %ds\n\n' "$rc" "$(($(date +%s) - start))" >> "$VERIFY_DIR/evidence.txt"
    return $rc
  }

  GATE_RC=0
  while IFS= read -r line; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    run_gate_command "$line" || GATE_RC=$?
  done < /tmp/pk-gate.sh
fi
```

If `GATE_RC != 0`:

```
✗ Pre-deploy gate FAILED.

The first failing command's last 30 lines:
<output>

Next: fix the gate failure, then re-run /verify (idempotent).
```

For `TIER != quick`, still write `reality-check.md` (Step 6) with status NEEDS WORK. Do **not** write `verify-complete.md`. Do **not** run QA review on a failed gate.

If `GATE_RC == 0`, print:

```
✓ Pre-deploy gate PASSED (<command list>).
```

Continue to step 4 only if QA is enabled.

## Step 4 — QA review subagent (if QA enabled)

### Step 4a — Fetch the spec for AC reference

Use Linear MCP `mcp__linear-server__get_issue` with `<ISSUE-ID>`. Capture the full description.

### Step 4b — Compute the diff

```bash
INTEGRATION=$(pk config "Integration branch" "dev")
git diff --stat "origin/$INTEGRATION...HEAD"
git diff "origin/$INTEGRATION...HEAD"
```

### Step 4c — Spawn the QA subagent

Backend-pluggable:

- **vbw** backend: use `subagent_type: "vbw:vbw-qa"` (project must have VBW installed)
- **native** backend: use `subagent_type: "general-purpose"`

Use Task tool with:

- `description: "QA review of <ISSUE-ID>"`
- Prompt template:
  ```
  You are a QA reviewer doing goal-backward verification.

  Linear issue: <ISSUE-ID>
  Branch: <CURRENT>

  Spec (from Linear):
  <full description from step 4a>

  Diff (relative to origin/<INTEGRATION>):
  <output of git diff --stat>
  <output of git diff>

  Your job:
  1. Read the spec's Acceptance Criteria.
  2. Walk each AC. For each, find the diff line(s) that fulfills it. If you cannot find one, the AC is unmet.
  3. Look for things the spec REQUIRED but the diff DOESN'T touch (omissions).
  4. Look for things the diff DID that the spec didn't authorize (scope creep).
  5. Note any obvious bugs you can see (logic errors, missing null checks in financial math, RLS bypasses).

  Return verdict in this exact format:

  **Verdict:** Pass | Partial | Fail
  **Reasoning:** <2–4 sentences>

  **Per-AC table:**
  | # | AC summary | Status | Evidence |
  |---|---|---|---|
  | 1 | <text> | Met / Unmet / Partial | <file:line or "no change found"> |

  **Omissions:** <list of spec requirements not addressed in diff, or "none">

  **Scope creep:** <list of diff changes not authorized by spec, or "none">

  **Bugs noticed:** <list of obvious bugs, or "none observed">

  Verdict rules:
  - Pass — every AC has Met evidence; no omissions; no significant scope creep; no bugs noticed
  - Partial — most ACs Met but specific gaps exist (Partial ACs allowed; minor scope creep allowed if defensible)
  - Fail — fundamental ACs Unmet, OR scope creep significant enough to block ship, OR bugs noticed
  ```

Wait for the subagent to return. Capture its full verdict block as `QA_BLOCK` (Day 4 will rewrite this to a Write-to-reality-check pattern with anchor-emit discipline; Day 2 keeps the parent-side capture). Print verbatim — no editorializing.

Set `QA_VERDICT` to `Pass | Partial | Fail` for use in Step 6 status reasoning.

## Step 5 — Human-decision flag enumeration

After the gate (and QA, if run), enumerate any **human-decision flags** present. A flag is anything that should pause the auto-ship chain even when the headline verdict is Pass. The principle: the auto-chain is a feature, but it must not bypass a human eye when there is any signal worth a human eye.

Run these checks in order. Surface every match. For `TIER != quick`, also append each surfaced flag as a `FLAG: ...` line to `$VERIFY_DIR/evidence.txt`.

### Flag check A — Migration files in diff

```bash
MIGRATION_DIR=$(pk config "Migration dir" "")
if [ -n "$MIGRATION_DIR" ]; then
  MIGRATION_FILES=$(git diff --name-only "origin/$INTEGRATION...HEAD" -- "$MIGRATION_DIR" 2>/dev/null)
  if [ -n "$MIGRATION_FILES" ]; then
    echo "FLAG: migration files in diff — review for irreversibility, RLS, search_path"
    [ "$TIER" != "quick" ] && printf 'FLAG: migration files in diff: %s\n' "$(echo "$MIGRATION_FILES" | tr '\n' ' ')" >> "$VERIFY_DIR/evidence.txt"
  fi
fi
```

Migrations are high-stakes and always warrant a human eye, regardless of QA verdict. Even a "trivial column add" can ship a destructive default backfill or a missing `search_path` on a `SECURITY DEFINER` function.

### Flag check B — QA Pass with non-empty sub-sections

When QA ran and returned **Pass**, also parse the verdict block for non-"none" content in:

- **Omissions** line: anything other than `none` (case-insensitive)
- **Scope creep** line: anything other than `none`
- **Bugs noticed** line: anything other than `none observed` / `none`

A Pass with non-empty sub-sections means the subagent classified the work as shippable in aggregate but still flagged items worth surfacing. Treat each non-empty sub-section as one flag.

### Flag check C — `--qa` was forced by user

If the user invoked `/verify --qa` (regardless of `Require QA review` config), they signaled they want eyes on it. The Pass verdict from QA is necessary but not sufficient — auto-ship would short-circuit the intent of the explicit flag.

Surface as: `FLAG: --qa forced — user explicitly requested QA, do not auto-ship without confirm`

### Flag check D — `/work` cross-skill marker

`/work`'s Step 6.5 writes `.pk-work/<ISSUE-ID>.flags` (one line per flag) when self-reference grep surfaces matches, behavioral self-check finds gaps, or a documented Risk-fallback was invoked during execution. Read it here.

```bash
MARKER=".pk-work/${ISSUE}.flags"
if [ -f "$MARKER" ]; then
  echo "FLAGS from /work (Step 6.5):"
  sed 's/^/  FLAG: /' "$MARKER"
  if [ "$TIER" != "quick" ]; then
    sed 's/^/FLAG: \/work marker — /' "$MARKER" >> "$VERIFY_DIR/evidence.txt"
  fi
fi
```

The marker is `.pk-work/` per repo convention; gitignored.

### Tally

After all four checks, count flags:

```bash
FLAG_COUNT=<sum of flags surfaced above>
```

If `FLAG_COUNT > 0`, the verdict is treated as **Pass-with-flags** in Step 8's auto-ship decision, even if the QA verdict block says Pass. This is the load-bearing rule for F6.

Print one summary line:

```
Flags: <count>  ·  Auto-ship: <will-fire | paused>
```

## Step 6 — Write reality-check.md (skip for tier:quick)

For `TIER != quick`, render `$VERIFY_DIR/reality-check.md` with this structure:

```markdown
# reality-check — <ISSUE>

- stamp: <STAMP>
- tier: <TIER>
- integration: <INTEGRATION>
- commits-ahead: <COMMITS_AHEAD>
- sha: <git rev-parse HEAD>
- status: <PASS | NEEDS WORK>

## Gate results

| Command | Exit | Duration | Anchor |
|---|---|---|---|
| <cmd 1> | <rc> | <s> | evidence.txt:L<line> |
| <cmd 2> | <rc> | <s> | evidence.txt:L<line> |

(Reconstruct rows from `==> $ ...` / `exit:` / `duration:` triplets in evidence.txt. Line anchors point to the `==>` row of each command.)

## QA verdict

<QA_BLOCK verbatim, or "Not run.">

## Antagonistic review

Not applicable for tier:<TIER>. (Wired Day 4 for tier:heavy; opt-in via `--review` for tier:standard.)

## Flags surfaced

<bulleted list of all flags from Step 5, or "none">

## Status reasoning

<2–4 sentences. Examples:
 - "Gate green, QA Pass, 0 flags → PASS."
 - "Gate green, QA Pass, 2 flags (migration files; --qa forced) → PASS (auto-ship paused for human decision)."
 - "Gate red on `pnpm turbo run lint` (exit 1) → NEEDS WORK.">

## Next actions

<hint copy from Step 8's verdict table, scoped to this run's verdict + flag count>
```

Use the Write tool with `file_path = "$VERIFY_DIR/reality-check.md"` to land the file. Re-runs overwrite.

## Step 7 — Write verify-complete.md on PASS (skip for tier:quick)

For `TIER != quick` AND status == PASS, write `$VERIFY_DIR/verify-complete.md`:

```markdown
# verify-complete

issue: <ISSUE>
stamp: <STAMP>
tier: <TIER>
status: PASS
evidence: evidence.txt
reality-check: reality-check.md
sha: <git rev-parse HEAD>
```

**Status logic (Day 2 — loose):**

- Gate red → NEEDS WORK (no `verify-complete.md`)
- QA ran and Verdict == Fail → NEEDS WORK (no `verify-complete.md`)
- Otherwise (gate green AND no QA-Fail) → PASS (write `verify-complete.md`)

Flags do **not** downgrade the status — they pause auto-ship in Step 8 but the file still gets written. Day 3 wires `pk ship` to consult `verify-complete.md`; the Step 8 flag-pause is the additional human-gate layer.

If the status is NEEDS WORK and a previous PASS run left a stale `verify-complete.md` on disk, delete it explicitly so the next `pk ship` (after Day 3 wires the gate) cannot trust a stale sentinel:

```bash
[ -f "$VERIFY_DIR/verify-complete.md" ] && [ "$STATUS" != "PASS" ] && rm "$VERIFY_DIR/verify-complete.md"
```

## Step 8 — Hand off (with auto-ship for the /work rollover path)

Based on verdict + flag tally, print the next-action:

| Verdict | Flags | Next |
|---|---|---|
| Pass (gate only) | 0 | `pk ship` (auto-shipped if invoked with `--auto-ship`; otherwise hint only) |
| Pass (gate + QA) | 0 | `pk ship` (auto-shipped if invoked with `--auto-ship`; otherwise hint only) |
| **Pass** | **≥1** | **Pause. List flags. Auto-ship is forbidden. User runs `pk ship` manually after reviewing — or `/work --resume` to address a flag, or amends the commit to document the accept decision.** |
| Partial | any | Read the per-AC table. Decide: amend with `/work` (if gap is real), or ship anyway with `git commit --amend` documenting the gap. Then `pk ship`. |
| Fail (gate) | any | Fix the failing command, then re-run `/verify` (idempotent). |
| Fail (QA) | any | Stop. Either: expand `/work <ID>` to address Unmet ACs; OR `pk delegate <ID> "the spec needs <X>"` to refine spec; OR override consciously with documented decision. |

For `TIER != quick`, also print the artifact paths:

```
Evidence:        <VERIFY_DIR>/evidence.txt
Reality check:   <VERIFY_DIR>/reality-check.md
Verify complete: <VERIFY_DIR>/verify-complete.md  (present only on PASS)
```

### Auto-ship rollover (Pass + zero flags only, only when invoked with --auto-ship)

Auto-ship fires when **all three** conditions hold:

1. The verdict is **Pass** (gate green; QA Pass if QA ran).
2. The flag tally from Step 5 is **zero** (no migration files, no QA Pass-with-non-empty sub-sections, no `--qa` force, no `/work` advisory marker).
3. This skill was invoked with the `--auto-ship` argument (passed via the Skill tool's `args` parameter by `/work`'s Step 7 rollover).

Behavior:

1. Print: `✓ /verify Pass + 0 flags — auto-running pk ship`
2. Run `pk ship` via bash. Use no flags — `pk ship` reads `Integration branch` from `method.config.md` to pick the destination, which gives `dev` for Piper-style multi-env projects and `main` for single-env projects (correct in both cases). v2.6.0+: opens the PR as **Draft**; outside reviewers (Semgrep + claude-review per `templates/ci/`) do not fire yet.
3. If `pk ship` succeeds: print its output (PR URL + Linear transition) and exit. The hand-off should remind the user that outside reviewers will fire when they run `pk ready <ID>` — that's the merge-moment gesture, not part of the auto-flow.
4. If `pk ship` fails (push rejected, gh CLI error, branch protection): surface the error verbatim and STOP. Do NOT auto-retry — push failures usually mean branch protection, lockfile drift, or remote conflicts that need human eyes.

`--review` (antagonistic review) stays opt-in; the user runs `pk ship --review` separately if they want it. The Draft default is also opt-out-able via `pk ship --ready` for one-shot tiny WITs where iteration won't happen.

### Pass-with-flags pause (the F6 gate — load-bearing)

When the verdict is Pass but `FLAG_COUNT > 0`, **do not auto-ship under any circumstance**, even with `--auto-ship`. Print:

```
✓ Pass with <N> flag(s) — auto-ship paused for human decision.

Flags surfaced:
  <flag 1>
  <flag 2>
  ...

To proceed:
  • Address the flag(s), then re-run /verify.
  • OR accept the flag(s): document the accept decision in the commit
    (git commit --amend --no-edit -m '<existing>\n\nAccepted flags: <reason>')
    and run `pk ship` manually.
  • OR /work --resume <ISSUE-ID> if execution gaps remain.
```

Then **stop**. The chain does not advance to `pk ship` without explicit human action. This rule is non-negotiable — it is the entire reason Step 5 exists. Skipping it on agent judgment reintroduces the F6 failure mode the canary 2026-05-14 surfaced.

### Standalone /verify (no --auto-ship)

If `--auto-ship` is **not** in this skill's args (standalone `/verify` invocation), do NOT auto-ship regardless of verdict or flag count. Print the hint and let the user pace. The flag list still gets surfaced — it just informs the user's manual `pk ship` decision instead of gating it.

**Why an arg, not an env var:** env vars set in one Bash tool call don't propagate to subsequent Bash calls — each invocation is a fresh subshell. The only reliable cross-skill signal is the Skill tool's `args` parameter.

**Partial / Fail with `--auto-ship`:** still no auto-ship. Auto-ship is gated on Pass + zero flags, not on the arg alone. The arg only authorizes the *clean Pass branch* to ship; flags or failures always pause for human attention.

## Failure model

| Failure | Behavior |
|---|---|
| No commits ahead of integration | Refuse with clear message. |
| Pre-Deploy Gate not configured | Print: "Configure § Pre-Deploy Gate in method.config.md, then re-run." |
| Gate command fails | Stop. Print failing command + last 30 lines. Write reality-check.md with status NEEDS WORK. Don't run QA. Don't write verify-complete.md. |
| QA subagent type missing (e.g., `vbw:vbw-qa` not installed) | Fall back to `general-purpose`. Warn. |
| Spec has no AC | QA subagent should report "AC missing" as Fail; user gets clear next-action. |
| `$VERIFY_DIR` unwritable (perms, disk full) | Print error, fall through to stdout-only mode for this run (tier downgraded to virtual). Day 3 gate will block ship in this case since `verify-complete.md` cannot be written. |
| Linear unreachable for tier lookup | `pk_linear_tier` returns "standard" — evidence layer still written. |

## What this skill does NOT do

- No session-log writes — `/pk-exit` owns the session log.
- No Linear status updates — `pk ship` and `pk done` post the necessary ones.
- No PR creation — `pk ship` is separate.
- No re-running of failed tests — fix and re-invoke (idempotent).
- No `Logs/Verify/` pruning — consuming projects own retention; recommend gitignore (see `STARTUP.md`).
- No antagonistic review (Day 4 wires this for tier:heavy mandatory + tier:standard `--review` opt-in).

## Comparison with v2.6

| Concern | v2.6 (`/verify`) | v2.7 (`/verify`) |
|---|---|---|
| Tier awareness | Implicit | Explicit `tier:quick|standard|heavy` via `pk_linear_tier` |
| Evidence artifact | None | `Logs/Verify/<date>/<id>/evidence.txt` with per-command exit + duration |
| Reality check | Printed to stdout | Written to `reality-check.md` for standard/heavy |
| Verify-complete sentinel | None | `verify-complete.md` on PASS (read by `pk ship` Day 3) |
| Pass-with-flags pause | Yes (Step 3.5) | Yes (Step 5) — unchanged behavior |
| Auto-ship rollover | Yes (Step 4) | Yes (Step 8) — unchanged behavior |
