---
name: pr-fix
description: Pluggable-engine PR review (pr-review-toolkit agents by default, built-in fallback) with two-axis severity×confidence triage and interactive remediation. Use when a PR needs review + structured fix triage. Use when pk ship --review surfaced findings. Use to address an existing review via --from-review. Different from /pr-security-review (security-only).
---

# PR Fix

You are a precision PR reviewer with a **pluggable review engine**: by default you fan out the `pr-review-toolkit` specialist agents; with `--engine=builtin` you run Pipekit's own reference-file dimensions. Either way you dedup, triage on two independent axes (**severity × confidence**), and drive an interactive fix workflow. You surface real issues high-signal-first — high-confidence *or* high-severity findings up front, the rest kept auditable — then fix them with user approval.

## Triggers

- `/pr-fix` — "review and fix the PR", "check the PR for issues", "fix PR issues"
- `/pr-fix --review` — "just review the PR", "review only"
- `/pr-fix --quick` — "quick fix", "auto-fix critical issues"
- `/pr-fix --from-review` — "address the GHA review", "fix what claude-review flagged" (skip Phase 3 fresh review; ingest existing GHA review comments instead)
- `/pr-fix --second-opinion=gemini` — "get a Gemini second opinion", "what does Gemini think" (after Phase 4, also surface a Gemini Flash review as a parallel report — opt-in only)
- `/pr-fix --engine=builtin` — "review without the plugin", "use the built-in reviewer" (skip pr-review-toolkit; use Pipekit's reference-file review)
- `/pr-fix --runs=2` — "double-check it", "run the review twice" (fan the native review out N times; recurrence across runs raises confidence)
- `/pr-fix security` — "check security", "review security"
- `/pr-fix errors tests` — "check error handling and tests"

## Arguments

- **Flags:**
  - `--review` (phases 1-4 only, no fixes)
  - `--quick` (skip discussion, auto-fix Critical + High)
  - `--from-review` (skip Phase 3 fresh review; ingest existing PR review comments — typically from `claude-review.yml` GHA — and feed them into Phase 4 aggregation)
  - `--second-opinion=gemini` (after Phase 4, invoke a Gemini Flash second-opinion review; surface its findings as a parallel report. Requires `GEMINI_API_KEY` env var. Use sparingly — counts against your Gemini quota.)
  - `--engine=native|builtin` (which engine runs Phase 3. Default `native` = the `pr-review-toolkit` plugin agents, **fail-loud if the plugin is absent** — see §3.0. `builtin` = Pipekit's own reference-file review, no plugin dependency.)
  - `--runs=N` (default 1; run the native fan-out N times and raise confidence on findings that recur — see §3.1)
- **Dimensions:** `correctness`, `security`, `errors`, `tests` — overrides auto-routing, loads only named dimensions
- **Flag interactions:**
  - `--from-review` and `--quick` compose (ingest GHA findings → auto-fix Critical + High)
  - `--from-review` and `--second-opinion=gemini` compose (ingest GHA findings → also get Gemini's read)
  - `--second-opinion=gemini` runs after Phase 4 regardless of whether Phase 3 was fresh or ingested
  - All four can compose: `/pr-fix --review --from-review --second-opinion=gemini` reviews-only, ingests GHA, adds Gemini, no fixes

## Reference Files

| File | Dimension | Load condition |
|---|---|---|
| `references/correctness.md` | Correctness & Compliance | ALWAYS |
| `references/security.md` | Security | Migrations, API routes, supabase lib, auth code, SQL, or supabase imports in diff |
| `references/error-handling.md` | Error Handling | `try`/`catch`/`.catch(`/`onError`/`throw`/`captureException` in diff, or any API route |
| `references/test-coverage.md` | Test Coverage | Any non-test source file changed |

---

## Phase 1: Intent

Understand what the PR is trying to accomplish before reviewing any code.

### 1.1 Identify the PR

```bash
git branch --show-current
gh pr view --json title,body,labels,baseRefName,headRefName,additions,deletions,files,commits
```

If no PR exists:
> "No open PR found for branch `{branch}`. Want me to review the diff against dev anyway, or create a PR first?"

If reviewing without PR: use `git diff dev...HEAD` as the diff source.

### 1.2 Build Context

```bash
git diff dev...HEAD --stat
git log dev..HEAD --oneline
```

### 1.2.5 Cross-spec handoff scan

If the PR's Linear issue (or referenced sibling issues) contains phrases like *"X will replace…"*, *"X consumes…"*, *"X provides…"*, that's a load-bearing handoff promise. **Predecessor specs may carry ACs that this PR is responsible for landing**, even if the PR's own spec doesn't list them.

For each cross-spec reference found in the issue:

1. Fetch the predecessor's spec via Linear MCP
2. Extract any "this issue's successor will…" handoff promises
3. **Verify each promise landed in the diff:**
   - "Wires X into Y" → grep the diff for `Y` references that introduce `X`
   - "Replaces placeholder Z" → grep the diff for `Z` removal AND replacement
   - "Persists data via W" → confirm a Server Action / migration / RLS rule for W exists
4. **Any unfulfilled handoff is a Critical finding** — same severity as a missing AC, regardless of whether the current PR's own AC list passes.

This catches the class of miss surfaced 2026-05-02 by RS-64 in rs-vault: the PR shipped its own ACs cleanly but never delivered the integration step its predecessor (RS-63) had promised. Both passed; the app was broken.

### 1.3 Synthesize Intent

Write a 2-3 sentence **intent statement**: what the PR is doing and why, derived from title, body, commit messages, and diff shape. This anchors the entire review.

Present to user:
- Intent statement
- Branch: `{head}` -> `{base}`
- Files changed: N (X source, Y tests, Z migrations)
- Lines: +A / -D

---

## Phase 2: Route

Classify changed files and determine which dimensions to load.

### 2.1 File Classification

Apply tags to each changed file:

| File pattern | Tags |
|---|---|
| `supabase/migrations/**` | `migration`, `security`, `database` |
| `**/api/**/*.ts` | `api`, `security` |
| `lib/supabase/**` | `security` |
| `**/auth/**`, `**/middleware.ts` | `security`, `auth` |
| `**/*.test.*`, `**/*.spec.*` | `test-only` |
| `packages/utils/src/**` | `financial`, `must-test` |
| `packages/ui/src/**` | `component` |
| `lib/hooks/**`, `lib/queries/**` | `data-layer` |
| `lib/ai/**` | `ai` |
| `*.sql` | `database`, `security` |

### 2.2 Dimension Loading

| Dimension | Load when | Override keyword |
|---|---|---|
| Correctness | ALWAYS | `correctness` |
| Security | Any file tagged `security`, `auth`, `database`, or importing `@/lib/supabase/*` | `security` |
| Error Handling | Diff contains `try`, `catch`, `.catch(`, `onError`, `throw`, `captureException`, or any `api`-tagged file | `errors` |
| Test Coverage | Any non-`test-only` source file changed | `tests` |

**Argument override:** If user passes dimension keywords (`/pr-fix security errors`), load ONLY those dimensions. Skip auto-routing.

### 2.3 Report Routing

Tell the user which dimensions loaded and why (one line each):
> **Dimensions loaded:** Correctness (always), Security (API routes changed), Error Handling (catch blocks in diff)
> **Skipped:** Test Coverage (only test files changed)

---

## Phase 3: Review

Phase 3 produces the finding set. The review **engine** is pluggable — resolve it in 3.0, run the matching path, then everything converges at 3.4 (normalize) and feeds Phase 4.

### 3.0 Resolve the review engine

Default engine is **native** — the `pr-review-toolkit` plugin's specialist agents (deeper, multi-perspective review). Overrides:
- `--engine=builtin` — use Pipekit's own reference-file review (3.2). Zero plugin dependency.
- `--from-review` — skip a fresh review; ingest existing PR review comments (3.3).

**Fail loud if native is unavailable.** Before running native, confirm the toolkit agents resolve (e.g. `pr-review-toolkit:code-reviewer`). If the plugin is not installed, STOP — do not silently downgrade:

> ✗ pr-review-toolkit plugin not installed — this skill's default review engine needs it.
>   → install the plugin, OR  → re-run with `--engine=builtin`.

A silent fallback to the weaker engine is itself a quiet quality regression; the user must know which engine reviewed their PR.

### 3.1 Native engine — pr-review-toolkit agents (default)

Fan out the toolkit's specialists in parallel as **read-only** subagents (they return findings to you; they do NOT post to the PR — this skill owns the aggregated output). Map Phase 2's routing to agents:

| Agent | Spawn when |
|---|---|
| `pr-review-toolkit:code-reviewer` | ALWAYS — general correctness + cross-WIT integration |
| `pr-review-toolkit:silent-failure-hunter` | Error-handling patterns in diff, or any API / mutation / migration |
| `pr-review-toolkit:pr-test-analyzer` | Any non-test source file changed |
| `pr-review-toolkit:type-design-analyzer` | New or changed exported types |
| `pr-review-toolkit:comment-analyzer` | Substantial new doc-comments / docstrings |

Each agent prompt MUST carry: the diff (save to `/tmp/pr<N>.diff` once, have agents read it), the Phase 1 intent statement, the project's matching `references/` file(s) (so project-specific checks still inform the native review), and the **coverage-first instruction** verbatim:

> Report every candidate, including low-confidence and low-severity ones — a downstream step filters; your job is coverage, not filtering. Return each finding with (a) an impact **severity** (Critical / High / Medium / Low — how bad if real) AND (b) your **confidence** it is real (0-100). These are independent: a catastrophic-but-uncertain finding is exactly what to surface.

**Pipekit historical finders — run in the same parallel wave.** The toolkit's specialists review the diff in isolation; these two add *temporal* signal the plugin agents structurally lack — how the touched code got here, and what reviewers already said about it. Spawn them as read-only subagents in the **same fan-out** as the toolkit agents (not before — they are peers, and their findings converge at 3.4 like any other). Both are dependency-free (`git` + `gh` only), so spawn them in the **builtin** path (§3.2) too.

| Finder | Spawn when |
|---|---|
| **git-history** | The diff modifies or deletes existing lines (skip on pure greenfield adds — no blame to read) |
| **prior-pr-comments** | A PR exists and `gh` is authenticated (best-effort; returns nothing if no prior PRs touched these files) |

Both carry the same coverage-first instruction (severity + confidence, every candidate) and the same inputs (diff at `/tmp/pr<N>.diff`, the Phase 1 intent statement). Their finder-specific prompts:

> **git-history finder.** For each file the diff *modifies or deletes* (ignore pure additions), run `git log --oneline -n 20 -- <file>` and `git blame` on the changed line ranges (pre-image line numbers). Look for: (a) a line this PR changes/removes that a *recent* commit added deliberately to fix a bug — flag a possible **regression** of that fix (cite the prior commit sha + subject); (b) a guard / null-check / validation being removed whose blame points to a fix or incident commit; (c) high-churn regions (same lines rewritten across several recent commits) — flag as fragile, recommend extra test coverage. Report each as a finding with `file:line`, a severity (regressing a known fix = High or above), and a confidence. If history shows nothing relevant, return an empty finding set — do not invent.

> **prior-pr-comments finder.** For each changed file, find recently merged PRs that touched it: `gh pr list --state merged --limit 30 --json number,title,files --jq '.[] | select(.files[].path == "<file>") | .number'` (or `gh search prs`). For each such PR, fetch its review comments: `gh api repos/{owner}/{repo}/pulls/<N>/comments --jq '.[] | {path,line,body}'`. Check whether any past comment describes an issue that **reapplies** to the current diff at the same file/region. Report each reapplying comment as a finding: `file:line`, the original PR # + the reviewer's point, severity inferred from the comment, confidence ≈ 70 (past feedback is a lead, not proof it recurs here). Skip comments already resolved by the current code. If `gh` is unauthenticated or no prior PRs exist, return empty — never block the review.

`--runs=N` (N>1): run the fan-out N times, merge in 3.4, and raise confidence on findings that recur across runs (recurrence is a reality signal); tag run-once findings `[unstable]`. Default N=1.

### 3.2 Builtin engine — reference-file review (`--engine=builtin`)

The dependency-free path. Read ONLY the `references/` files for the dimensions Phase 2 loaded, get the diff (`git diff dev...HEAD`), and systematically check every checklist item against the changed lines.

Your job here is **coverage**: surface every candidate and score it honestly — do **not** self-censor a finding before scoring it. Each potential finding gets a confidence score (0-100):

| Pattern | Adjustment |
|---|---|
| Matches a rule marked Critical in a reference file | +20 (floor 85) |
| In newly added lines (not modified existing) | +10 |
| In deleted lines | SKIP — do not report issues in removed code |
| Requires runtime context to verify | -15 |
| Style/preference not documented in reference files | Cap at 60 |
| Missing functionality outside the PR's stated scope | Cap at 50 |

Never shade a score down to stay quiet. Filtering happens in Phase 4, not here.

**Also run the two dependency-free historical finders from §3.1** (git-history, prior-pr-comments) here — they need no plugin, and their temporal signal is as valuable to the builtin path as to native.

### 3.3 `--from-review` — ingest existing PR review comments instead

When `--from-review` is set, skip the fresh review (native or builtin) and ingest the existing PR review comments. The typical source is `templates/ci/claude-review.yml` (Path 3 reviewer) or Semgrep — but any reviewer comments are fair game, **including a `pr-review-toolkit` run that already posted to the PR**.

```bash
PR_NUM=$(gh pr view --json number -q .number)
gh pr view "$PR_NUM" --json reviews -q '.reviews[] | select(.state != "DISMISSED")'
gh api repos/{owner}/{repo}/pulls/$PR_NUM/comments
```

For each comment build a finding: `path`+`line` (or `original_line` if outdated) → **Location**; `body` → **What**/**Why** (parse Critical/High/Medium markers if present, else infer severity from tone); reviewer login → **Source**; **Confidence** = `85` (trusted external reviewer, not auto-100 — shared blind spots). Classify by Phase 2 routing; default unclassifiable findings to `Correctness`; flag outdated comments `[stale-line]`. `--from-review` composes with native/builtin as an additional merge source.

### 3.4 Normalize to two axes (severity + confidence)

Whatever engine produced them, every finding converges to the same shape, with **two independent axes kept separate**:

- **Severity** — impact if the finding is real: **Critical** (data loss / RLS bypass / auth break / financial corruption / destructive op) · **High** (must fix before merge) · **Medium** (should fix soon) · **Low** (nit). Assigned on blast radius, NOT on how sure you are.
- **Confidence (0-100)** — likelihood the finding is real.

Never collapse the two into one number — `severity=Critical, confidence=20` is a valid, important finding (catastrophic if real, merely uncertain). Phase 4 triages on both.

Also record: **Dimension**, **Location** (`file:line` — mandatory, no vague findings), **Title**, **What** (the problem), **Why** (impact), **How** (specific fix with code example).

Per engine: **native** — take each agent's severity bucket as Severity; derive Confidence from the agent's hedging language and recurrence across `--runs` (≈85 for a confidently-stated finding, lower when hedged, +10 per recurrence, cap 99). The two historical finders (§3.1) report explicit severity + confidence — use them verbatim (git-history per its blame evidence; prior-pr-comments ≈70). **builtin** — Severity from §4.2's impact table, Confidence from 3.2's scoring. **--from-review** — Severity parsed from the comment, Confidence 85.

---

## Phase 4: Aggregate & Triage

Merge findings across agents/dimensions, dedup, then triage on **two axes**.

### 4.1 Deduplication Rules

1. **Same file + line range (within 5 lines):** the specialist wins (Security > Error Handling > Test Coverage > Correctness); keep the higher **severity** (break ties by higher confidence). Note the dropped location.
2. **Same root cause at different lines:** keep the higher-severity finding; reference the other location.
3. **Test-only PRs:** if only test files changed, suppress Test Coverage findings.
4. **Cross-agent overlap (native):** the toolkit's agents overlap (e.g. code-reviewer + silent-failure-hunter both flag error handling) — dedup by file:line + root cause, keeping the more specific write-up.
5. **Historical corroboration (native):** when a historical finder (git-history / prior-pr-comments) flags the same file:line + root cause as a specialist, do NOT just drop it — keep the specialist's write-up but **raise its confidence** (+10, cap 99) and note the corroboration (e.g. "+ git-history: regresses fix abc123"). A finding independently surfaced by diff-review *and* history is more likely real — the recurrence-is-a-reality-signal principle applied across finders, not just across `--runs`.

### 4.2 Severity is impact, not a confidence band

Severity = blast radius **if the finding is real**, assigned independently of confidence:

| Severity | Means | Examples |
|---|---|---|
| **Critical** | data loss / RLS bypass / auth break / financial corruption / destructive op | missing RLS, fail-open prod guard, financial calc bug, service role in client code |
| **High** | must fix before merge; won't break prod the instant it ships | missing auth check, silent failure swallowing a money error, non-idempotent migration |
| **Medium** | should fix soon | unchecked Supabase error response, missing channel handler |
| **Low** | nit / cleanup | naming, style, loose typing |

A Critical finding can carry **any** confidence. Do not down-rate severity because confidence is low — that is the exact mistake this two-axis model exists to prevent.

### 4.3 Triage on two axes + present

|   | **confidence ≥ 80** (likely real) | **confidence < 80** (uncertain) |
|---|---|---|
| **severity ≥ High** | **FIX** — auto-fix-eligible (`--quick`) | **INVESTIGATE** — surface up top, do NOT auto-fix, flag "catastrophic if real — verify" |
| **severity ≤ Medium** | **Quick-fix / nit** | **Below-threshold** coverage list |

- **Surface in the main report if `confidence ≥ 80` OR `severity ≥ High`.** A Critical/High finding is never buried by low confidence. (The PR #408 fail-open guard — Critical severity, 78 confidence — surfaces here, not in the collapsed list.)
- **Order by severity-dominant priority:** `priority = 0.7 × severity_weight + 0.3 × confidence`, where severity_weight = Critical 100 / High 80 / Medium 55 / Low 30. Sort descending.
- **Below-threshold list = low severity AND low confidence only** — never a high-severity item.

```markdown
## PR Review: {intent statement}   ·   engine: {native | builtin | from-review}
**Scope:** {N files, +A/-D}   **Findings:** {C Critical, H High, M Medium} · {I to investigate}

### Fix / surfaced
| # | Sev | Conf | Dim | File:Line | Finding |
|---|-----|------|-----|-----------|---------|
| 1 | Critical | 95 | Security | api/review/route.ts:45 | Missing internal user ID lookup |

### ⚠ Investigate — high severity, low confidence (verify before trusting either way)
| # | Sev | Conf | Dim | File:Line | Finding |
|---|-----|------|-----|-----------|---------|
| 7 | Critical | 30 | Security | …seed.sql:38 | Prod-guard may fail open on empty env |
```

Expand each surfaced finding with **What / Why / How**. Then the collapsed low/low list:

> <details><summary>{K} below-threshold findings (low severity & conf &lt; 80) — expand</summary>
>
> | Sev | Conf | Dim | File:Line | Finding |
> |-----|------|-----|-----------|---------|
> | Low | 55 | Correctness | foo.ts:12 | Possible off-by-one (needs runtime context) |
>
> </details>

Nothing is discarded — the matrix decides prominence, not existence.

### 4.4 Acknowledge Strengths

Note what is well-done in the changeset. A review that only lists problems is incomplete.

### 4.5 If Nothing Surfaces

> "No findings cleared the surfacing bar (confidence ≥ 80 or severity ≥ High). Reviewed {N} files across {dimensions} via the {engine} engine. The code looks ready for merge."

If there are below-threshold findings, still render the collapsed coverage list from §4.3 beneath this message. "Nothing surfaced" must never read as "the model found nothing" — it means nothing cleared the bar; low-severity/low-confidence items still live in the coverage list.

**If `--review` flag is set, stop here.**

### 4.6 If `--second-opinion=gemini` — append a parallel Gemini report

When the flag is set, after Phase 4's report is printed, invoke Gemini Flash for an independent read. This is the **opt-in Gemini path** per the v2.6.0 Path 3 reviewer model — Gemini is *not* a standing reviewer, but it's available on-demand for "I want a non-Claude, non-OpenAI-stack second opinion on this specific PR."

Preconditions:
- `GEMINI_API_KEY` must be set in the environment. Refuse with a clear error if missing:
  > `--second-opinion=gemini requires GEMINI_API_KEY. Get a free key at https://aistudio.google.com/apikey and export it in your shell.`

Procedure:

1. Capture the full diff:
   ```bash
   git diff dev...HEAD > /tmp/pr-fix-diff-$$.patch
   ```

2. Build a prompt for Gemini that includes:
   - The Phase 1 intent statement
   - The diff
   - The Phase 4 report (so Gemini can comment on what was missed, not duplicate)
   - Instructions: "Independently review this diff. Surface any findings the Claude review (above) missed or under-emphasized. Return Critical / High / Medium with `file:line` citations. Be terse; ≤500 words."

3. Call Gemini Flash. Use `gemini-flash-latest` (free-tier eligible). **Watch the thinking-token gotcha**: Gemini 2.5+ Flash uses internal thinking tokens that count against `maxOutputTokens`. On first invocation in this skill, set `maxOutputTokens=65536` and `generationConfig.thinkingConfig.thinkingBudget=-1` (uncapped):

   ```bash
   curl -sS -X POST \
     "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$GEMINI_API_KEY" \
     -H 'Content-Type: application/json' \
     -d "$(jq -n --arg prompt "$PROMPT" '{
       contents: [{parts: [{text: $prompt}]}],
       generationConfig: {
         maxOutputTokens: 65536,
         thinkingConfig: { thinkingBudget: -1 }
       }
     }')"
   ```

   **Do NOT use `gemini-3.1-pro-preview` or `gemini-pro-latest`** — both resolve to a paid-tier model with zero free quota; the API returns 429. Stick to `gemini-flash-latest`.

4. Parse the response. The Gemini response shape: `.candidates[0].content.parts[0].text` contains the review markdown. Print it verbatim under a heading:

   ```markdown
   ---

   ## Gemini Second Opinion

   _Gemini Flash, independent review. Findings here did not pass through Phase 4 deduplication — treat as a parallel report, not a merged set. Confidence = 70 (external model, no shared training with Claude reviewer)._

   {gemini's review verbatim}
   ```

5. **Do NOT merge Gemini's findings into the main Phase 4 report.** Keep them parallel for user judgment. The point of a second opinion is comparison, not consensus.

6. Clean up the temp file.

**Cost note:** each invocation uses Gemini API quota. Free tier covers casual use; for heavy use the cost is small but non-zero. The flag exists for the "I want one more set of eyes on this important PR" case, not for every review.

**Vendor framing:** Gemini is acceptable risk under Pipekit's vendor model (see `resources/v2.6.0-candidates.md` § "Why OpenAI/Microsoft are disqualified"). Google's track record is closer to Anthropic's than to OpenAI/Microsoft's — moderate-but-acceptable IP-absorption surface. If your project's risk tolerance is tighter, skip this flag and rely on Semgrep + Claude.

---

## Phase 5: Discuss

Interactive approval gate. Never make fix decisions for the user.

### 5.1 Ask for Input

> "Which findings should I fix? You can say **all**, list numbers (e.g., **1, 3, 4**), or tell me to **skip** any with a reason."

**Wait for the user's response. Do not proceed without it.**

### 5.2 Build Fix Plan

Based on user feedback:

```markdown
## Approved Fix Plan

1. [#1] api/review/route.ts:45 — Add internal user ID lookup
2. [#3] api/chat/route.ts:30 — Replace empty catch with captureException + error response

Skipped:
- #2: User declined (intentional pattern for this use case)

Deferred:
- #4: Test coverage — will address in follow-up
```

### 5.3 Confirm

> "Ready to proceed with fixes 1 and 3?"

**Wait for explicit approval.**

### 5.4 Quick Mode (`--quick`)

If `--quick` is set, skip the interactive gate:
- Auto-approve the **FIX** quadrant only — severity ≥ High **AND** confidence ≥ 80.
- **Never auto-fix the INVESTIGATE quadrant** (high severity, low confidence). Applying an unverified fix to an uncertain finding can do more harm than the finding — list those, recommend verification, and stop short of editing them.
- Skip Medium/Low and below-threshold.
- Proceed to Phase 6 with the FIX set.

---

## Phase 6: Fix

Execute approved fixes with per-fix commits and post-fix validation.

### 6.1 Execution Order

1. Critical severity first, then High, then Medium
2. Within same severity: Security fixes first (they can affect other fixes)

### 6.2 Per-Fix Workflow

For each approved fix:

1. **Edit** — Make the targeted change using the Edit tool. Minimal, precise edits. Preserve existing code style.
2. **Stage** — `git add {specific files only}`
3. **Commit** — Structured message:
   ```
   fix: {brief description}

   PR review finding #{n}: {title}
   Dimension: {dimension}
   Confidence: {score}
   ```

### 6.3 Validation Gate

After ALL fixes are committed, run the pre-deploy gate:

```bash
pnpm turbo run check-types 2>&1 | tail -30
pnpm turbo run lint 2>&1 | tail -30
pnpm turbo run test 2>&1 | tail -30
```

If migrations were touched:
```bash
supabase db lint
```

**If any gate fails:**
1. Identify which fix caused the failure (check the error output)
2. Attempt one auto-remediation (fix the issue, amend the commit)
3. If auto-remediation fails, present the error to the user and ask for guidance

### 6.4 Push

```bash
git push
```

### 6.5 Summary Report

```markdown
## Fixes Applied

| # | Finding | Commit | Status |
|---|---------|--------|--------|
| 1 | Missing user ID lookup | abc1234 | Fixed |
| 3 | Empty catch block | def5678 | Fixed |

**Validation:** check-types PASS, lint PASS, test PASS

**Next steps:**
- [ ] Review changes in GitHub
- [ ] Request re-review if needed
- [ ] Merge when ready
```

### 6.6 Post Linear comment (visibility)

After fixes are pushed, post a Linear comment on the PR's linked issue summarizing the triage. This closes the mid-loop visibility gap — Linear sees `In Progress → UAT → [Released →] Done` today, but the *what happened with this review* context lives only on the PR.

> **Expected harness warning (F10):** the subagent or tool that writes to Linear from inside `/pr-fix` will emit a generic "external action" security warning, because posting a comment to Linear is a write to an external system. This is expected — Phase 6.6 is an explicit, sanctioned action of this skill. Do not pause for re-confirmation, do not improvise a transparency note in the chat. Surface the warning verbatim in the hand-off summary with the line: *"Phase 6.6 Linear write fired — the external-action warning is the expected security notice for this sanctioned step."* Surfaced 2026-05-14 canary; documented v2.4.3.3.

Identify the Linear issue from:
- The PR title's `<TEAM>-<N>:` prefix (e.g. `RS-73: …`), OR
- The PR body's `Closes <TEAM>-<N>` line, OR
- The current branch name's `feature/<TEAM>-<N>-…` token.

Post via `pk_linear_comment <ISSUE-ID> "<body>"` (the helper `pk done` uses), or via the Linear MCP `mcp__linear-server__linear_createComment` tool. Body format:

```markdown
**`/pr-fix` triage complete** (PR #<N>)

- **Fixed:** <count> (commits <sha1>..<shaN>)
  - <list each finding briefly>
- **Rejected:** <count>
  - <each, with reason — e.g. "C1 — AG Grid var() support verified via MCP">
- **Deferred:** <count>
  - <each, with follow-up issue link if opened>

PR: <pr-url>
```

If the PR has no linked Linear issue (no `<TEAM>-<N>` reference anywhere), skip this step silently — print `(no Linear issue linked; skipping comment)` and continue.

---

## Edge Cases

| Situation | Response |
|---|---|
| No PR exists | Offer to review `git diff dev...HEAD` or help create a PR |
| Empty diff | "No changes to review." Stop. |
| Nothing surfaces (no conf ≥ 80, no sev ≥ High) | Confirm code looks good; still render the below-threshold coverage list. List what was reviewed and which engine ran. |
| User skips all findings | "Understood — no fixes made. Findings documented above for reference." |
| User wants to fix something not in findings | Accept it — add to the fix plan manually |
| Branch behind base | Warn before Phase 6: "Branch is N commits behind {base}. Consider rebasing first." |
| Validation fails after fixes | Identify cause, one auto-fix attempt, then ask user |
| Draft PR | Still reviewable; note draft status in Phase 1 output |

---

## Calibration Rules

1. **Coverage when finding, two-axis triage when displaying.** Surface and score every candidate honestly — never self-censor before scoring. The main report surfaces a finding when confidence ≥ 80 **or** severity ≥ High: a false positive among the high-confidence items erodes trust, while a high-severity/low-confidence item routes to **INVESTIGATE** (surfaced, not auto-fixed). Only low-severity *and* low-confidence items stay in the collapsed coverage list — never discarded. Suppression happens at display, not at finding.
2. **File:line is mandatory.** Every finding must include a specific location. "Consider improving error handling" is not actionable.
3. **Reference files are the authority.** Only flag issues documented in the reference files. Do not invent new rules.
4. **Deleted code is invisible.** Never report issues in removed lines.
5. **Scope is sacred.** Do not flag missing features that are outside the PR's stated intent.
6. **Deduplication is mandatory.** Same issue reported twice is a skill bug.
7. **Strengths matter.** Acknowledge what's done well.
8. **Never make decisions for the user.** Present findings, wait for approval, then execute.

---

## Related Skills

- `/code-review` — Lighter-weight review (no interactive discussion, no fixes)
- `/security-review` — Comprehensive weekly security audit (full codebase, not PR-scoped)
- `/commit` — For committing after manual fixes
- `pk ship` — Opens the feature → integration-branch PR; `pk promote` walks the chain to main
