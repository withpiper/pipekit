# Pipekit CI Templates

GitHub Actions workflow templates for the **Path 3 reviewer model** shipped in v2.6.0.

## What's in here

| File | Reviewer | Type | Credit cost |
|------|----------|------|-------------|
| `semgrep.yml` | Semgrep | Deterministic static analysis | Free (Community Rules) |
| `claude-review.yml` | Claude Code Action | Semantic, LLM-based | Per-call, OAuth-token-gated |

Together they implement Pipekit's outside-reviewer model: Semgrep catches the classes it's specifically tuned for (injection, XSS, hardcoded secrets, dependency risks, OWASP top ten), Claude catches the semantic / cross-file pattern issues Semgrep can't see.

Held back for v2.6.x: GitHub Copilot, GPT-4-based reviewers, and Codex GHAs — disqualified on the **IP-absorption pattern** (see `resources/v2.6.0-candidates.md` § "Why OpenAI/Microsoft are disqualified"), not on quality grounds.

## Installation

Copy the files you want into your consuming project's `.github/workflows/`:

```bash
cp pipekit/templates/ci/semgrep.yml       .github/workflows/
cp pipekit/templates/ci/claude-review.yml .github/workflows/
```

Then **edit the `branches:` list in each file** to match your project's release-class branches:

- **2-tier (dev → main)**: `branches: [main]`
- **3-tier (dev → beta → main)**: `branches: [beta, main]`

The list should mirror `method.config.md`'s `Ship environments` minus the first env (which is the day-to-day integration branch, where reviews would burn credit on every shipped WIT).

`claude-review.yml` also requires the `CLAUDE_CODE_OAUTH_TOKEN` repo secret (Settings → Secrets and variables → Actions → New repository secret). Get the token via the Claude Code Action setup flow.

## Trigger model — why `opened` + `ready_for_review` only

Both templates trigger on:

```yaml
on:
  pull_request:
    types: [opened, ready_for_review]
```

**No `synchronize`.** Every push to a Ready PR would otherwise fire the reviewer — wasteful on heavy-iteration PRs (Piper's WIT-463 was a 23-commit feature branch; 23 reviews × per-call cost = the problem). `synchronize` is exactly the wrong event to gate "outside review" on.

**`ready_for_review` is the merge-moment signal.** Combined with Pipekit's Draft-PR lifecycle below, the reviewer fires once at PR-open (if not Draft) and once when the user flips Draft → Ready (the "I'm done iterating, review it now" gesture).

## Draft-PR lifecycle (v2.6.0 #6)

Pipekit defaults `pk ship` to opening PRs as **Draft**. Iterate freely on a Draft PR without firing reviews. When you're ready to merge, run `pk ready <ID>` to flip Draft → Ready, which fires the `ready_for_review` event — that's when the outside reviewers run.

```bash
pk ship                # opens PR as Draft. No reviewers fire.
# ... iterate, push, fix, push ...
pk ready WIT-123       # flips Draft → Ready. Reviewers fire here.
# ... review, address feedback if any ...
pk done WIT-123 --merge
```

Use `pk ship --ready` to skip the Draft state on tiny one-shot PRs where iteration won't happen.

## Skip-on-trivial guard (`claude-review.yml` only)

The Claude template includes a `triage` job that skips the (paid) semantic review on:

- **Doc-only PRs** — every changed file is `.md`, `.txt`, or `.rst`
- **Trivial PRs** — total LOC changed `< 5` (typo fixes, single-constant tweaks)

Semgrep doesn't need this guard — it's free and short-running.

The threshold matches v2.6.0 #5 Option B (the decided path on path-restriction): all-paths review with a credit-floor, instead of an allowlist that might miss bugs in less-trafficked paths. PR #331 evidence: claude-review caught two must-fix bugs including one in a UI path that any reasonable allowlist would have excluded.

## Path filtering — intentionally absent

Earlier drafts of this template proposed restricting Claude reviews to `supabase/migrations/**`, `**/api/**`, `**/auth/**`, etc. **That was rejected for v2.6.0** based on empirical data from Piper PR #331: claude-review caught project-specific-rule violations (`export default` rule in `budget-editor-view.tsx`) and cross-file UUID-validation gaps in paths a reasonable allowlist would have excluded.

If your project's review costs become prohibitive, the lever is **the skip-on-trivial threshold** (raise LOC from 5 to 50, or extend the doc-only filter to `.json` / `.lock` / `.snap` files), not a path allowlist.

## Reference implementations

- **Semgrep**: Piper PR #335 (`3706208`, 2026-05-18) — 1059 rules / 56 files / 54s on a 6083+/350- promote PR. Zero findings on that PR (wrong PR class for Semgrep's strengths); pays off on user-input handling, dep upgrades, pattern-heavy code.
- **claude-review trigger config**: Piper PR #317 (Draft-skip + `ready_for_review`) + PR #330 (drop `synchronize`).

## Related Pipekit gestures

- `pk ship` — opens PR (Draft by default). Will not fire reviewers until `pk ready` flip.
- `pk ship --ready` — opens PR Ready immediately (fires reviewers; use for one-shot tiny WITs).
- `pk ready <ID>` — flips Draft → Ready (fires reviewers).
- `/pr-fix --second-opinion=gemini` — opt-in local second opinion via Gemini Flash (covered in `pr-fix` skill, v2.6.0+). Use when you want a non-Claude, non-OpenAI-stack second read on a specific PR without standing up a GHA.

## Custom Semgrep rules

Pipekit ships starter Semgrep rules at `templates/ci/semgrep-rules/`. Currently:

- **`uuid-route-params.yml`** — flags dynamic route params flowing into Supabase queries without UUID validation. Deterministic backup for the failure mode surfaced 2026-05-18 (PR #331 claude-review caught it in three files; PR #341 had the same pattern and claude-review missed it). Copy to your project at `.semgrep/uuid-route-params.yml` and add `--config=.semgrep/` to your Semgrep invocation.

These are **starter rules** — test against your codebase before enabling in CI. Patterns may need tuning to your project's route conventions.

## `/pr-fix` flags (v2.6.0)

These flags ship alongside the CI templates:

- **`/pr-fix --from-review`** — skip the local Phase 3 fresh review; ingest existing PR review comments (typically from `claude-review.yml`) and feed them into Phase 4 aggregation + Phase 5 discussion. Use after the GHA reviewer has run to "address what claude-review flagged" without re-reviewing.
- **`/pr-fix --second-opinion=gemini`** — after Phase 4, invoke Gemini Flash for a parallel review. Opt-in only — counts against your Gemini quota. Requires `GEMINI_API_KEY`. See `skills/pr-fix/skill.md` § 4.6 for the full procedure and the thinking-tokens gotcha.

The flags compose: `/pr-fix --review --from-review --second-opinion=gemini` reviews-only, ingests GHA, adds Gemini.
