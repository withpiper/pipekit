---
name: verify
description: verify — tier-aware evidence-gated pre-deploy gate. tier:standard|heavy write Logs/Verify/<date>/<id>/{evidence.txt,reality-check.md,verify-complete.md}; tier:quick writes only verify-complete.md on PASS. pk ship gates on a verify-complete.md whose sha matches HEAD. Use when a Linear issue is ready for verify (Stage 3). Use when /work finished and you need a Pass/Partial/Fail verdict per AC before pk ship.
---

# /verify

> **North star:** safe and frictionless. Helps, never adds work.

You verify that a feature branch's work is shippable. You run the project's pre-deploy gate (tests, lint, types), enumerate human-decision flags, and — when configured or invoked with `--qa` — spawn a QA review subagent that checks the diff against the issue's acceptance criteria.

**v2.7 evidence layer.** For tier:standard and tier:heavy, every run produces three files under `Logs/Verify/<YYYYMMDD>/<ISSUE>/`:

- `evidence.txt` — raw gate output with per-command exit codes and durations, plus appended `FLAG: ...` lines
- `reality-check.md` — structured verdict with gate results table, QA block, flags, status reasoning
- `verify-complete.md` — minimal sentinel written on PASS; `tier:quick` writes **only** this file (a virtual sentinel), the other two stay stdout-only

`pk ship` reads `verify-complete.md` as a hard, **sha-matched** gate: it accepts a sentinel under any date dir whose `sha:` line matches the commit being shipped (`git rev-parse HEAD`). Without a HEAD-matching sentinel, ship aborts — bypass via `--force` (Linear audit comment) or `PK_VERIFY_BYPASS=1` (emergency, logs to bypass.log). Every tier writes the sentinel on PASS, so quick is no longer a warn-but-proceed special case.

## Triggers

- `/verify` — primary; uses current branch's issue ID
- `/verify <ISSUE-ID>` — explicit
- `/verify --qa` — force QA review even if `Require QA review: false`
- `/verify --review` — force antagonistic review (mandatory anyway for tier:heavy)
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

| Tier | Evidence layer | reality-check.md | verify-complete.md | QA subagent | Antagonistic review | pk ship gate |
|---|---|---|---|---|---|---|
| quick | no | virtual (printed only) | minimal, on PASS | only if `--qa` | never | hard, sha-matched |
| standard | yes | written | written on PASS | per config + `--qa` | auto on sensitive-path diffs; opt-in via `--review` otherwise | hard, sha-matched |
| heavy | yes | written | written on PASS | per config + `--qa` | mandatory | hard, sha-matched |

Sensitive-path patterns are documented in Step 5.

For tier:quick, the rest of this skill executes against stdout only — Steps 5 and 7 are skipped and no `evidence.txt` / `reality-check.md` is written — **except Step 8**, which on PASS writes a single minimal `verify-complete.md` so `pk ship`'s sha-matched gate can confirm this commit was verified. For tier:standard and tier:heavy, every step below appends to or writes the files under `$VERIFY_DIR`. Step 5 (antagonistic) is also skipped for tier:standard unless `--review` is passed.

## Step 1 — Read configuration

Read from `method.config.md`:

- `Require QA review` (default `false`) — controls whether QA subagent runs by default
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

For `TIER != quick`, still write `reality-check.md` (Step 7) with status NEEDS WORK. Do **not** write `verify-complete.md`. Do **not** run QA review on a failed gate. Do **not** run antagonistic review on a failed gate.

If `GATE_RC == 0`, print:

```
✓ Pre-deploy gate PASSED (<command list>).
```

Continue to step 4 only if QA is enabled.

## Step 4 — QA review subagent (if QA enabled)

### Step 4a — Fetch the spec for AC reference

Use Linear MCP `mcp__linear-server__linear_getIssueById` with `<ISSUE-ID>`. Capture the full description.

### Step 4b — Compute the diff

```bash
INTEGRATION=$(pk config "Integration branch" "dev")
git diff --stat "origin/$INTEGRATION...HEAD"
git diff "origin/$INTEGRATION...HEAD"
```

### Step 4c — Spawn the QA subagent

Use `subagent_type: "general-purpose"`.

The subagent is configured with `allowed-tools: Read, Bash, Write` (the `Write` permission is what lets it land the verdict file). Run it on the **verification** tier per `method.config.md § Model Policy` (default `sonnet`, effort `high`).

Use Task tool with:

- `description: "QA review of <ISSUE-ID>"`
- Prompt template:
  ```
  You are a QA reviewer doing goal-backward verification.

  Linear issue: <ISSUE-ID>
  Branch: <CURRENT>
  Tier: <TIER>

  Write target: <VERIFY_DIR>/qa-verdict.md
    Use the Write tool to create this file with the verdict block below.
    Return only a one-line confirmation: "QA verdict written: <path>".

  Spec (from Linear):
  <full description from step 4a>

  Gate evidence (for anchor cites):
  <VERIFY_DIR>/evidence.txt
    Cite gate output as `evidence.txt:L<line>` — point at the `==> $ ...`
    header row for each command, not the body.

  Diff (relative to origin/<INTEGRATION>):
  <output of git diff --stat>
  <output of git diff>

  Your job:
  1. Read the spec's Acceptance Criteria.
  2. Walk each AC. For each, find the diff line(s) that fulfills it. If you cannot find one, the AC is unmet.
  3. Look for things the spec REQUIRED but the diff DOESN'T touch (omissions).
  4. Look for things the diff DID that the spec didn't authorize (scope creep).
  5. Note any obvious bugs you can see (logic errors, missing null checks in financial math, RLS bypasses).

  Anchor-emit discipline:
  - Cite source lines as `<file>:<line>` (e.g., `app/lib/budget.ts:88`)
  - Cite gate output as `evidence.txt:L<line>` (the `==> $` header row)
  - Vague refs ("somewhere in the auth module") are invalid — re-grep until you have a line.

  Write to <VERIFY_DIR>/qa-verdict.md exactly this shape:

  ## QA verdict

  **Verdict:** Pass | Partial | Fail
  **Reasoning:** <2–4 sentences>

  **Per-AC table:**
  | # | AC summary | Status | Evidence |
  |---|---|---|---|
  | 1 | <text> | Met / Unmet / Partial | `<file>:<line>` or "no change found" |

  **Omissions:** <list of spec requirements not addressed in diff, or "none">

  **Scope creep:** <list of diff changes not authorized by spec, or "none">

  **Bugs noticed:** <list of obvious bugs with file:line, or "none observed">

  Verdict rules:
  - Pass — every AC has Met evidence; no omissions; no significant scope creep; no bugs noticed
  - Partial — most ACs Met but specific gaps exist (Partial ACs allowed; minor scope creep allowed if defensible)
  - Fail — fundamental ACs Unmet, OR scope creep significant enough to block ship, OR bugs noticed
  ```

The subagent returns only a one-line confirmation; the verdict block lives in the file. Parent-side parsing is removed — Step 7 reads `qa-verdict.md` and inlines it into `reality-check.md`.

After the subagent returns, read `$VERIFY_DIR/qa-verdict.md` and grep the **Verdict:** line to set `QA_VERDICT` (`Pass | Partial | Fail`) for use in Step 6 flag check B and Step 7 status reasoning.

If the subagent fails to write the file (Write permission denied, disk full), surface the error and treat the QA verdict as `Fail` — better to block ship than to ship on a silently-missing verdict.

## Step 5 — Antagonistic review (mandatory tier:heavy; auto for sensitive-path diffs on tier:standard; opt-in via --review on tier:standard; skipped tier:quick)

Antagonistic review is a separate, adversarial subagent with the **same inputs** as QA (diff + AC list) but a different lens: find what is wrong, not whether it shipped. The prompt is the **verbatim DOUBT prompt** from `pipekit-discipline.md` § Completion Claims — never paraphrase it, the wording is load-bearing.

Run conditions:

```bash
RUN_ADVERSARIAL=false
TRIGGER_REASON=""

# tier:heavy — always fires
if [ "$TIER" = "heavy" ]; then
  RUN_ADVERSARIAL=true
  TRIGGER_REASON="tier:heavy mandatory"
fi

# tier:standard — explicit --review flag fires
if [ "$TIER" = "standard" ] && echo "$@" | grep -q -- '--review'; then
  RUN_ADVERSARIAL=true
  TRIGGER_REASON="--review flag"
fi

# tier:standard — sensitive-path auto-trigger (mirrors /pr-fix patterns)
if [ "$TIER" = "standard" ] && [ "$RUN_ADVERSARIAL" = "false" ]; then
  SENSITIVE_PATHS=$(git diff --name-only "origin/$INTEGRATION...HEAD" 2>/dev/null \
    | grep -E '(supabase/migrations/|/auth/|/middleware\.|/rls\.|/policies\.)' || true)
  SENSITIVE_CONTENT=""
  if git diff "origin/$INTEGRATION...HEAD" 2>/dev/null \
    | grep -qE 'SECURITY DEFINER|GRANT EXECUTE|REVOKE EXECUTE|CREATE POLICY|ALTER POLICY'; then
    SENSITIVE_CONTENT="yes"
  fi
  if [ -n "$SENSITIVE_PATHS" ] || [ -n "$SENSITIVE_CONTENT" ]; then
    RUN_ADVERSARIAL=true
    TRIGGER_REASON="sensitive-path auto-trigger"
    echo "⚠ Antagonistic review auto-triggered on tier:standard — diff touches sensitive surface."
    [ -n "$SENSITIVE_PATHS" ] && echo "  Paths: $(echo "$SENSITIVE_PATHS" | tr '\n' ' ')"
    [ -n "$SENSITIVE_CONTENT" ] && echo "  Content: RLS/SECURITY DEFINER/GRANT-EXECUTE pattern in diff"
  fi
fi

if [ "$RUN_ADVERSARIAL" = "false" ]; then
  : # skip to Step 6
else
  echo "Antagonistic review: $TRIGGER_REASON"
fi
```

If `RUN_ADVERSARIAL=false`, skip to Step 6.

**Sensitive-path patterns** mirror `/pr-fix`'s plan (which lands Week 4). Defaults:
- **Paths:** `supabase/migrations/`, `/auth/`, `/middleware\.`, `/rls\.`, `/policies\.`
- **Content (diff body grep):** `SECURITY DEFINER`, `GRANT EXECUTE`, `REVOKE EXECUTE`, `CREATE POLICY`, `ALTER POLICY`

The reasoning: these are the exact surfaces where shipping without adversarial review historically caused incidents — RLS bypasses, missing `search_path` on SECURITY DEFINER functions, GRANT scope creep. Trivial-but-not-quick standard issues that don't touch these surfaces stay opt-in (no token blowup on `tier:standard` typo fixes). Project-specific path/content overrides can be added to `method.config.md` in a future `[verify.sensitive_paths]` block (deferred to v2.7.1+).

### Step 5a — Spawn the adversarial subagent

Use `subagent_type: "general-purpose"` (same agent as QA — only the prompt differs).

Configure with `allowed-tools: Read, Bash, Write`. Run it on the **plan-review / adversarial** tier per `method.config.md § Model Policy` (default `opus`, effort `xhigh`) — adversarial review benefits from deeper reasoning.

Use Task tool with:

- `description: "Antagonistic review of <ISSUE-ID>"`
- Prompt template (the verbatim DOUBT prompt wrapped with Write target + inputs):
  ```
  Write target: <VERIFY_DIR>/adversarial.md
    Use the Write tool to create this file with your findings.
    Return only a one-line confirmation: "Adversarial findings written: <path>".

  Anchor-emit discipline:
  - Cite source lines as `<file>:<line>`
  - Cite gate output as `evidence.txt:L<line>`
  - No vague refs.

  Write to <VERIFY_DIR>/adversarial.md exactly this shape:

  ## Antagonistic review

  Findings (or "No issues found after thorough examination."):

  | # | Finding | File:line | Class |
  |---|---|---|---|
  | 1 | <text> | `<file>:<line>` | unstated_assumption \| edge_case \| coupling \| contract_violation \| convention_break \| failure_mode |

  ---

  Adversarial review. Find what is wrong with this artifact.
  Assume the author is overconfident. Look for:
  - Unstated assumptions
  - Edge cases not handled
  - Hidden coupling or shared state
  - Ways the contract could be violated
  - Existing conventions this might break
  - Failure modes under unexpected input

  Do NOT validate. Do NOT summarize. Find issues, or state
  explicitly that you cannot find any after thorough examination.

  ARTIFACT:
  <output of git diff --stat>
  <output of git diff>

  CONTRACT:
  <full Linear issue description from Step 4a — the AC list is the contract>
  ```

The adversarial subagent's job is to find issues — it does NOT classify them. Classification happens in the parent's RECONCILE step (per `pipekit-discipline.md` § Completion Claims): AC misread → Valid actionable → Valid trade-off → Noise. That step is the user's, not the subagent's.

After the subagent returns, read `$VERIFY_DIR/adversarial.md` and count findings to set `ADVERSARIAL_FINDING_COUNT`. Used in Step 7 status reasoning and Step 6 flag check E (added below).

### Doubt theater check

Per the discipline rule: "2+ cycles with substantive findings, zero actionable classifications = you're validating, not doubting." `/verify` only runs the loop **once** by design (subagent finds issues; the user classifies during the ship decision), so this check is not enforced here. It belongs to a future multi-cycle iteration-loop skill. Day-4 deliverable surfaces the findings; user judgment closes the loop.

## Step 6 — Human-decision flag enumeration

After the gate, QA, and antagonistic review (if run), enumerate any **human-decision flags** present. A flag is anything that should pause the auto-ship chain even when the headline verdict is Pass. The principle: the auto-chain is a feature, but it must not bypass a human eye when there is any signal worth a human eye.

Run these checks in order. Surface every match. For `TIER != quick`, also append each surfaced flag as a `FLAG: ...` line to `$VERIFY_DIR/evidence.txt`.

### Flag check A — Migration files in diff (auto-reviewed)

```bash
MIGRATION_DIR=$(pk config "Migration dir" "")
MIGRATION_FILES=""
if [ -n "$MIGRATION_DIR" ]; then
  MIGRATION_FILES=$(git diff --name-only "origin/$INTEGRATION...HEAD" -- "$MIGRATION_DIR" 2>/dev/null)
fi
```

If `MIGRATION_FILES` is non-empty, **never surface a bare pointer.** Migrations are high-stakes and always warrant a human eye regardless of QA verdict — but the human's job is to *approve a verdict*, not to perform the review. A "trivial column add" can ship a destructive default backfill or a missing `search_path` on a `SECURITY DEFINER` function, and handing the user a raw `git show` asks them to catch exactly the class of issue this skill exists to catch. So when migration files are present, spawn a review subagent and attach its verdict to the flag.

#### Spawn the migration-review subagent

Fires whenever `MIGRATION_FILES` is non-empty, on **every tier** (migrations are high-stakes regardless of tier). Complementary to Step 5's antagonistic review — that pass is a generic "find what's wrong" lens; this one applies the structured migration rubric and returns a Hold/Approve verdict against named rubric IDs.

Backend-pluggable:
- prefer `subagent_type: "pr-review-toolkit:code-reviewer"` (the same specialist `/pr-security-review` uses)
- fall back to `general-purpose` if the toolkit isn't installed (warn, mirroring the QA fallback in the Failure model)

Configure `allowed-tools: Read, Bash, Write`, on the **plan-review / adversarial** tier per `method.config.md § Model Policy` (default `opus`, effort `xhigh` — migrations are high-stakes on every tier). Use the Task tool with:

- `description: "Migration review of <ISSUE-ID>"`
- Prompt:
  ```
  Write target: <VERIFY_DIR>/migration-review.md
    (if $VERIFY_DIR is unset — tier:quick — skip the file and return the verdict block inline).
    Return only a one-line confirmation: "Migration review written: <verdict>".

  Apply the migration rubric from the /pr-security-review skill. Read it first — it lives at
  `.claude/skills/pr-security-review/skill.md` (consuming projects) or
  `skills/pr-security-review/skill.md` (Pipekit itself) — read § "Migration rubric (M1–M8)"
  and apply every item. ALSO apply, only when the diff body contains the triggering pattern:
    - RLS rubric (R1–R6)            — diff contains CREATE POLICY / ALTER POLICY / ENABLE ROW LEVEL SECURITY
    - SECURITY DEFINER rubric (S1–S8) — diff contains SECURITY DEFINER
    - GRANT/REVOKE rubric (G1–G3)   — diff contains GRANT / REVOKE
  If you cannot read the skill file, fall back to checking these categories directly:
  idempotency; destructive DDL without a data-migration plan; NOT NULL columns without
  default/backfill; FK ON DELETE behavior; RLS enablement + at least one policy;
  search_path on SECURITY DEFINER functions; type regeneration present in the diff;
  timestamp ordering of the migration filename.

  Anchor-emit discipline: cite every finding as `<file>:<line>`. No vague refs.

  Write exactly this shape:

  ## Migration review — <ISSUE>

  **Verdict:** Hold | Approve with notes | Approve
  **Files:** <migration files reviewed>
  **Findings:** N Critical · N High · N Medium · N Low · N Nit

  | # | Sev | Rubric | File:line | Finding | Remediation |
  |---|---|---|---|---|---|
  | 1 | High | M3 | `<file>:<line>` | <issue> | <action> |

  (or, if clean: "No issues found after thorough examination — Verdict: Approve.")

  Verdict rule: any Critical or High finding → Hold. Medium/Low/Nit only → Approve with notes.
  No findings → Approve.

  ARTIFACT:
  <output of: git diff "origin/$INTEGRATION...HEAD" -- "$MIGRATION_DIR">

  CONTRACT:
  <full Linear issue description — the AC list>
  ```

After the subagent returns, read `<VERIFY_DIR>/migration-review.md` (or the inline block on tier:quick), grep the **Verdict:** line into `MIGRATION_VERDICT`, then surface the flag carrying the verdict — never a bare pointer:

```bash
echo "FLAG: migration review — ${MIGRATION_VERDICT} — see migration-review.md ($(echo "$MIGRATION_FILES" | tr '\n' ' '))"
[ "$TIER" != "quick" ] && printf 'FLAG: migration review: %s — files: %s\n' "$MIGRATION_VERDICT" "$(echo "$MIGRATION_FILES" | tr '\n' ' ')" >> "$VERIFY_DIR/evidence.txt"
```

The verdict — `Hold` included — is surfaced for the user to RECONCILE; it does **not** auto-downgrade the `/verify` status, consistent with how antagonistic findings and every other flag behave (Step 8). The migration flag still pauses auto-ship (Step 9). The only thing that changed: the user now approves `Hold: M3 missing backfill on line 14` or `Approve — no findings`, instead of a `git show` they were never positioned to act on.

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

### Flag check E — Antagonistic review surfaced findings

If Step 5 ran and `ADVERSARIAL_FINDING_COUNT > 0`, surface one flag per finding (or one aggregate flag, your choice — the count matters more than the granularity):

```bash
if [ -n "$ADVERSARIAL_FINDING_COUNT" ] && [ "$ADVERSARIAL_FINDING_COUNT" -gt 0 ]; then
  echo "FLAG: antagonistic review surfaced $ADVERSARIAL_FINDING_COUNT finding(s) — see adversarial.md"
  [ "$TIER" != "quick" ] && printf 'FLAG: antagonistic review: %d finding(s)\n' "$ADVERSARIAL_FINDING_COUNT" >> "$VERIFY_DIR/evidence.txt"
fi
```

Adversarial findings are advisory — they do not auto-downgrade the QA verdict — but they always warrant a human eye before ship. The RECONCILE step (per `pipekit-discipline.md` § Completion Claims) is the user's: AC misread → Valid actionable → Valid trade-off → Noise.

### Flag check F — Security-sensitive change (auto-gated; v4.4.0)

This is where the feature-scoped security gate (gap #3) actually fires. `/verify` is the only point in the `/work → /verify → pk ship` auto-rollover with a human-decision seam, so the gate runs here as a flag rather than as a standalone step the auto-chain would skip.

```bash
SECCATS=$(pk config "Security categories" "")
[ -n "$SECCATS" ] && [ ! -f "$SECCATS" ] && SECCATS=""   # configured but absent → treat as not-configured
```

If `SECCATS` is empty (no categories file), **skip this check silently** — the gate is opt-in per project, exactly like `/prod-ready` and `/financial-review`. If it points at a real file, run the gate:

1. **Determine the changed surface** (committed work on this branch, never the working tree):
   ```bash
   git fetch -q origin "$INTEGRATION" 2>/dev/null || true   # best-effort; worktrees share the object store
   CHANGED=$(git diff --name-only "origin/$INTEGRATION...HEAD" 2>/dev/null)
   [ -z "$CHANGED" ] && CHANGED=$(git diff --name-only "$INTEGRATION...HEAD" 2>/dev/null)
   CHANGED=$(printf '%s\n' "$CHANGED" | grep -v '^Reports/' )   # don't classify the gate's own past reports
   ```
   If `CHANGED` is **still empty** after both committed-diff attempts, do **not** emit a clean pass — the surface is *indeterminate* (stale/missing `origin/$INTEGRATION`, detached HEAD). Surface `FLAG: security gate — could not determine changed surface; classify manually` and treat it as a flag (fail-safe, mirroring `/prod-ready`'s blank-build handling — a miss here would ship an unreviewed sensitive change).

2. **Classify + review** by following the `/security-gate` skill (`skills/security-gate/skill.md`, or `.claude/skills/` in consuming projects) against `CHANGED`, using the project's `$SECCATS` definitions and the `sop/Security_Gate_SOP.md` per-category checklists. Spawn it as the gate's own read-only sub-agents (`general-purpose`, execution tier per `method.config.md § Model Policy` — default `sonnet`, effort `medium` — `allowed-tools: Read, Bash, Grep, Glob`). The verdict is `PASS` (no category matched, or all matched checklists clean) / `FAIL` (any confirmed Critical or High) / `WARNINGS` (Medium/Low only).

Surface the flag carrying the verdict — never a bare pointer (same discipline as the migration flag):

```bash
echo "FLAG: security gate — ${SECGATE_VERDICT} — categories: ${SECGATE_MATCHED:-none} — see Security_Gate_*.md"
[ "$TIER" != "quick" ] && printf 'FLAG: security gate: %s — categories: %s\n' "$SECGATE_VERDICT" "${SECGATE_MATCHED:-none}" >> "$VERIFY_DIR/evidence.txt"
```

3. **On PASS, write the secgate sentinel** (v4.17.0 — `pk ship` hard-requires it on any categories-armed project, so the embedded gate run must leave the same artifact a standalone `/security-gate` run would; without this, the auto-ship rollover would block right after its own gate passed):
   ```bash
   if [ "$SECGATE_VERDICT" = "PASS" ]; then
     _sg_dir="Logs/SecurityGate/$(date +%Y%m%d)/${ISSUE}"
     mkdir -p "$_sg_dir"
     printf '# secgate-complete\n\nissue: %s\nstatus: PASS\nsha: %s\ncategories: %s\n' \
       "$ISSUE" "$(git rev-parse HEAD)" "${SECGATE_MATCHED:-none}" > "$_sg_dir/secgate-complete.md"
   fi
   ```
   Never on FAIL / WARNINGS-to-block / indeterminate — the missing sentinel is what makes `pk ship` refuse.

A `PASS` with **no category matched** is the common, cheap case — emit no flag (the gate ran and found nothing sensitive), but **still write the sentinel**. Only a category match (whether the verdict is FAIL, WARNINGS, or even a clean PASS the user should see) surfaces a flag. Like every other flag, a security-gate FAIL **pauses auto-ship** (Step 9) for the user to RECONCILE; it does **not** auto-downgrade the `/verify` status. As of v4.17.0 the gate is **hard** at the `pk ship` seam: no HEAD-matching PASS sentinel on an armed project → ship refuses (`--force` / `PK_SECGATE_BYPASS=1` escape).

### Tally

After all six checks, count flags:

```bash
FLAG_COUNT=<sum of flags surfaced above>
```

If `FLAG_COUNT > 0`, the verdict is treated as **Pass-with-flags** in Step 9's auto-ship decision, even if the QA verdict block says Pass. This is the load-bearing rule for F6.

Print one summary line:

```
Flags: <count>  ·  Auto-ship: <will-fire | paused>
```

## Step 7 — Write reality-check.md (skip for tier:quick)

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

<inline contents of `$VERIFY_DIR/qa-verdict.md`, or "Not run.">

## Antagonistic review

<inline contents of `$VERIFY_DIR/adversarial.md`, or "Not run (tier:<TIER>, no --review).">

## Migration review

<inline contents of `$VERIFY_DIR/migration-review.md`, or "No migration files in diff.">

## Flags surfaced

<bulleted list of all flags from Step 6, or "none">

## Status reasoning

<2–4 sentences. Examples:
 - "Gate green, QA Pass, 0 flags → PASS."
 - "Gate green, QA Pass, 2 flags (migration files; --qa forced) → PASS (auto-ship paused for human decision)."
 - "Gate green, antagonistic review 3 findings → PASS (auto-ship paused; user reconciles findings before ship)."
 - "Gate red on `pnpm turbo run lint` (exit 1) → NEEDS WORK.">

## Next actions

<hint copy from Step 9's verdict table, scoped to this run's verdict + flag count>
```

Use the Write tool with `file_path = "$VERIFY_DIR/reality-check.md"` to land the file. Re-runs overwrite. The QA and adversarial sections inline the fragment files written by their respective subagents — assembly happens here, not at subagent boundaries (parent-side parsing is for inclusion, not for verdict computation).

## Step 8 — Write verify-complete.md on PASS (every tier, quick included)

On PASS, write `$VERIFY_DIR/verify-complete.md` — **for every tier**. `pk ship`'s gate accepts a sentinel under any date dir whose `sha:` matches the commit being shipped (`git rev-parse HEAD`), so the sha line is load-bearing: write the **full 40-char HEAD sha**, exactly `sha: <40-hex>` on its own line.

```bash
if [ "$STATUS" = "PASS" ]; then
  mkdir -p "$VERIFY_DIR"            # tier:quick skipped dir creation in Step 2; create it now
  SHA=$(git rev-parse HEAD)
  if [ "$TIER" = "quick" ]; then
    cat > "$VERIFY_DIR/verify-complete.md" <<EOF
# verify-complete

issue: $ISSUE
stamp: $STAMP
tier: quick
status: PASS
mode: virtual
sha: $SHA
EOF
  else
    cat > "$VERIFY_DIR/verify-complete.md" <<EOF
# verify-complete

issue: $ISSUE
stamp: $STAMP
tier: $TIER
status: PASS
evidence: evidence.txt
reality-check: reality-check.md
sha: $SHA
EOF
  fi
fi
```

For `tier:quick` this minimal sentinel is the **only** file written — `evidence.txt` and `reality-check.md` stay virtual (stdout). It exists solely so `pk ship`'s gate can confirm "verify passed at this exact commit" without re-deriving tier or guessing the date. (Before v4 the gate special-cased `tier:quick` as warn-but-proceed and re-derived tier from Linear at ship time; a Linear flake or a midnight UTC rollover then caused false aborts. The sentinel-per-tier + sha match removes both.)

**Status logic:**

- Gate red → NEEDS WORK (no `verify-complete.md`)
- QA ran and Verdict == Fail → NEEDS WORK (no `verify-complete.md`)
- Otherwise (gate green AND no QA-Fail) → PASS (write `verify-complete.md`)

Antagonistic findings do **not** downgrade the status — they pause auto-ship in Step 9 via Flag check E, but the file still gets written. The reasoning: adversarial review surfaces issues for the user to RECONCILE; classification (actionable vs trade-off vs noise) is the user's, not the subagent's. Pre-classifying as Fail would short-circuit the discipline.

Flags do **not** downgrade the status — they pause auto-ship in Step 9 but the file still gets written. `pk ship` consults `verify-complete.md` (Day 3); the Step 9 flag-pause is the additional human-gate layer.

If the status is NEEDS WORK and a previous PASS run left a stale `verify-complete.md` on disk, delete it explicitly so the next `pk ship` cannot trust a stale sentinel:

```bash
[ -f "$VERIFY_DIR/verify-complete.md" ] && [ "$STATUS" != "PASS" ] && rm "$VERIFY_DIR/verify-complete.md"
```

## Step 9 — Hand off (with auto-ship for the /work rollover path)

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
2. The flag tally from Step 6 is **zero** (no migration files, no QA Pass-with-non-empty sub-sections, no `--qa` force, no `/work` advisory marker, no antagonistic findings, no matched security category).
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

Then **stop**. The chain does not advance to `pk ship` without explicit human action. This rule is non-negotiable — it is the entire reason Step 6 exists. Skipping it on agent judgment reintroduces the F6 failure mode the canary 2026-05-14 surfaced.

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
| QA subagent type unavailable | Warn and skip QA rather than blocking the gate. |
| Spec has no AC | QA subagent should report "AC missing" as Fail; user gets clear next-action. |
| `$VERIFY_DIR` unwritable (perms, disk full) | Print error, fall through to stdout-only mode for this run (tier downgraded to virtual). Day 3 gate will block ship in this case since `verify-complete.md` cannot be written. |
| Linear unreachable for tier lookup | `pk_linear_tier` returns "standard" — evidence layer still written. |

## When NOT to use

- Design / code-quality review of a PR — that's `/pr-fix` (interactive triage) or `pk ship --review` (antagonistic). `/verify` checks spec adherence, not what the spec forgot to ask.
- Security audit — `/pr-security-review` (PR-scoped) or `/security-review` (repo-wide). `/verify`'s Step 6 security gate is a classifier pass, not a review.
- Interactive UAT — `/verify` proves the code passes its gates; it is **not** a substitute for the human exercising the feature (RUNBOOK step [5e], the non-skippable Stage 3 gate).
- Production-readiness — operational preconditions (monitoring, backups, flags) are `/prod-ready`, run once per feature at the production boundary, not per task.

## Common Rationalizations

| You're about to say… | The rebuttal |
|---|---|
| "It's a small change — skip the gate" | The gate is the gate. Simple-feeling changes are where silent regressions live (`pipekit-discipline.md` Red Flags, row 1 — it's row 1 because this excuse keeps recurring). |
| "I already ran the tests earlier this session" | The evidence layer exists because *"Done" kept overstating reality* — issues marked shipped that git never built (v2.7.0-rc5 log-mining, both consumers). Exit codes in `evidence.txt` at this SHA, or it didn't happen. |
| "CI will catch it on the PR anyway" | CI is the backstop, not the gate. A red PR wastes the reviewer pass and blocks the merge lane — `/verify` is cheaper than a bounced PR. |
| "The preview/dashboard looks right" | A vendor-UI affirmative state is a *claim*, not evidence of effect (Red Flags). Closing on a green checkbox you never exercised is the false-ship pattern. |
| "The gate fails on something unrelated — `--no-verify` past it" | Never route around a failing gate; fix the cause, or if the gate itself has drifted from CI, that's its own bug — raise it (`pipekit-tooling.md` § Pre-Deploy Gate). |

## What this skill does NOT do

- No session-log writes — `/pk-exit` owns the session log.
- No Linear status updates — `pk ship` and `pk done` post the necessary ones.
- No PR creation — `pk ship` is separate.
- No re-running of failed tests — fix and re-invoke (idempotent).
- No `Logs/Verify/` pruning — artifacts are intentionally committed as the per-PR audit trail (v2.7.0-rc1 decision). Consuming projects own retention via periodic cleanup commits (e.g., quarterly `git rm -r Logs/Verify/<old-date>/`). Do NOT gitignore — the verify-complete.md sentinel travels with the merge as evidence that the pre-deploy gate passed at that SHA.
- No source modifications. Subagents have `Read, Bash, Write` — `Write` is scoped to `$VERIFY_DIR`. They do not edit project source files.

## Comparison with v2.6

| Concern | v2.6 (`/verify`) | v2.7 (`/verify`) |
|---|---|---|
| Tier awareness | Implicit | Explicit `tier:quick|standard|heavy` via `pk_linear_tier` |
| Evidence artifact | None | `Logs/Verify/<date>/<id>/evidence.txt` with per-command exit + duration |
| Reality check | Printed to stdout | Written to `reality-check.md` for standard/heavy |
| Verify-complete sentinel | None | `verify-complete.md` on PASS (read by `pk ship` Day 3) |
| Pass-with-flags pause | Yes (Step 3.5) | Yes (Step 6) — flag check E added for antagonistic findings |
| Auto-ship rollover | Yes (Step 4) | Yes (Step 9) — unchanged behavior |
| Antagonistic review | Not present | Mandatory tier:heavy; auto on sensitive-path diffs for tier:standard; opt-in `--review` for tier:standard otherwise |
| QA verdict capture | Parent-side parse | Subagent writes `$VERIFY_DIR/qa-verdict.md`; parent inlines into reality-check.md |
