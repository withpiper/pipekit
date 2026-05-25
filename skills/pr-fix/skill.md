---
name: pr-fix
description: Precision 4-dimension PR review with confidence-gated findings and interactive remediation. Use when a PR has reviewer comments needing structured triage. Use when pk ship --review surfaced findings. Different from /pr-security-review (security-only).
---

# PR Fix

You are a precision PR reviewer. Your job is to perform diff-based review across 4 dimensions with conditional routing, confidence scoring, deduplication, and an interactive fix workflow. You find real issues with zero noise, then fix them with user approval.

## Triggers

- `/pr-fix` — "review and fix the PR", "check the PR for issues", "fix PR issues"
- `/pr-fix --review` — "just review the PR", "review only"
- `/pr-fix --quick` — "quick fix", "auto-fix critical issues"
- `/pr-fix --from-review` — "address the GHA review", "fix what claude-review flagged" (skip Phase 3 fresh review; ingest existing GHA review comments instead)
- `/pr-fix --second-opinion=gemini` — "get a Gemini second opinion", "what does Gemini think" (after Phase 4, also surface a Gemini Flash review as a parallel report — opt-in only)
- `/pr-fix security` — "check security", "review security"
- `/pr-fix errors tests` — "check error handling and tests"

## Arguments

- **Flags:**
  - `--review` (phases 1-4 only, no fixes)
  - `--quick` (skip discussion, auto-fix Critical + High)
  - `--from-review` (skip Phase 3 fresh review; ingest existing PR review comments — typically from `claude-review.yml` GHA — and feed them into Phase 4 aggregation)
  - `--second-opinion=gemini` (after Phase 4, invoke a Gemini Flash second-opinion review; surface its findings as a parallel report. Requires `GEMINI_API_KEY` env var. Use sparingly — counts against your Gemini quota.)
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

For each loaded dimension, read its reference file and apply the checklist against the diff.

### 3.0 If `--from-review` — ingest GHA review comments instead

When the `--from-review` flag is set, skip the fresh review (3.1 / 3.2 / 3.3) and ingest the existing PR review comments instead. The typical source is `templates/ci/claude-review.yml` (Path 3 reviewer), but any external reviewer comments are fair game.

```bash
PR_NUM=$(gh pr view --json number -q .number)

# All review submissions (top-level "Approve / Request Changes / Comment").
gh pr view "$PR_NUM" --json reviews -q '.reviews[] | select(.state != "DISMISSED")'

# Inline comments tied to specific file:line.
gh api repos/{owner}/{repo}/pulls/$PR_NUM/comments
```

For each review comment, build a structured finding:

| Source field | Becomes |
|---|---|
| `path` + `line` (or `original_line` if outdated) | **Location** (`file:line`) |
| `body` | **What** + **Why** (parse the comment's structure if it follows Critical/High/Medium markers; else infer severity from tone) |
| User of the reviewer | **Source** (e.g., `claude-review[bot]`, `semgrep[bot]`) |
| — | **Confidence** = `85` (external reviewers we trust; not auto-elevated to 100 because they share blind spots with claude-review) |

Apply Phase 2's dimension routing to classify each finding (file path → Security / Correctness / Errors / Tests). Comments that don't fit a dimension are tagged `Correctness` by default.

Outdated comments (where the source line has changed): include with a flag `[stale-line]` next to the location.

**Skip 3.1, 3.2, 3.3 entirely under `--from-review`.** Jump straight to Phase 4 with the ingested findings as the input set.

### 3.1 Read References

Read ONLY the reference files for loaded dimensions. Do not read skipped dimensions.

### 3.2 Analyze the Diff

Get the full diff:
```bash
git diff dev...HEAD
```

For each loaded dimension, systematically check every item in the reference file's checklist against the changed lines.

### 3.3 Confidence Scoring

Every potential finding gets a confidence score (0-100):

| Pattern | Adjustment |
|---|---|
| Matches a rule marked Critical in a reference file | +20 (floor 85) |
| In newly added lines (not modified existing) | +10 |
| In deleted lines | SKIP — do not report issues in removed code |
| Requires runtime context to verify | -15 |
| Style/preference not documented in reference files | Cap at 60 (auto-filtered) |
| Missing functionality outside the PR's stated scope | Cap at 50 (auto-filtered) |

**Threshold: Only findings scoring >= 80 survive.** Everything below is discarded. Silence is better than noise.

### 3.4 Format Each Finding

For each surviving finding, record:
- **Dimension** (Correctness / Security / Error Handling / Test Coverage)
- **Severity** (Critical / High / Medium — see Phase 4)
- **Confidence** (80-100)
- **Location** (`file:line` — mandatory, no vague findings)
- **Title** (one-line summary)
- **What** (the problem)
- **Why** (impact if not fixed)
- **How** (specific fix with code example)

---

## Phase 4: Aggregate

Merge findings from all dimensions into a single, deduplicated, severity-ranked report.

### 4.1 Deduplication Rules

1. **Same file + line range (within 5 lines):** The specialist dimension wins. Priority: Security > Error Handling > Test Coverage > Correctness. The losing finding is dropped entirely.

2. **Same root cause at different lines:** Keep only the higher-severity finding. Add a note referencing the other location.

3. **Test-only PRs:** If the PR modifies only test files, suppress all Test Coverage findings.

### 4.2 Severity Mapping

| Severity | Confidence range | Examples |
|---|---|---|
| **Critical** | 90-100 | Missing RLS, user ID invariant violation, financial calc bug, empty catch block, service role in client code |
| **High** | 85-89 | Wrong Supabase client, missing auth check, silent failure in catch, manual query keys, non-idempotent migration |
| **Medium** | 80-84 | Naming violations, missing channel error handler, unchecked Supabase error response |

### 4.3 Present Report

```markdown
## PR Review: {intent statement}

**Dimensions:** {list of loaded dimensions}
**Scope:** {N files analyzed, +A/-D lines}
**Findings:** {X Critical, Y High, Z Medium}

| # | Sev | Dim | File:Line | Finding | Conf |
|---|-----|-----|-----------|---------|------|
| 1 | Critical | Security | api/review/route.ts:45 | Missing internal user ID lookup | 95 |
| 2 | Critical | Correctness | lib/queries/budget.ts:88 | Manual query key | 90 |
| 3 | High | Error Handling | api/chat/route.ts:30 | Empty catch swallows Langfuse error | 87 |
| 4 | Medium | Test Coverage | packages/utils/src/markup.ts | New edge case untested | 82 |
```

Then expand each finding with **What / Why / How**.

### 4.4 Acknowledge Strengths

Note what is well-done in the changeset. A review that only lists problems is incomplete.

### 4.5 If No Findings

> "No issues found above the 80-confidence threshold. Reviewed {N} files across {dimensions}. The code looks ready for merge."

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

If `--quick` flag is set, skip this phase entirely:
- Auto-approve all Critical and High findings
- Skip Medium findings
- Proceed directly to Phase 6

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

Post via `pk_linear_comment <ISSUE-ID> "<body>"` (the helper `pk done` uses), or via the Linear MCP `mcp__linear-server__save_comment` tool. Body format:

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
| No findings >= 80 | Confirm code looks good. List what was reviewed. |
| User skips all findings | "Understood — no fixes made. Findings documented above for reference." |
| User wants to fix something not in findings | Accept it — add to the fix plan manually |
| Branch behind base | Warn before Phase 6: "Branch is N commits behind {base}. Consider rebasing first." |
| Validation fails after fixes | Identify cause, one auto-fix attempt, then ask user |
| Draft PR | Still reviewable; note draft status in Phase 1 output |

---

## Calibration Rules

1. **Precision over recall.** A false positive erodes trust. Only report >= 80 confidence. Silence is better than noise.
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
