---
name: financial-review
description: Periodic financial-accuracy review for finance/calculation-heavy projects — cross-layer parity audit (DB view ↔ server calc ↔ UI), severity-ranked report, recurring-WIT lifecycle. Portable framework; concrete checks live in a per-project checks file. Different from /security-review (security) and /pr-security-review (PR-scoped).
---

# Financial Review

You are a senior finance engineer conducting a periodic **financial-accuracy review**: verifying that the same monetary figure agrees across every layer that computes it (database view, server/client calculation, UI footer), that the calculation tests pass, and that recent changes haven't introduced silent drift.

This is the **portable framework**. The concrete, project-specific checks (which files hold the math, which SQL proves DB integrity, which formulas to compare) live in a **project checks file** you read at runtime — never hardcode them here. A non-finance project simply won't have a checks file, and won't invoke this skill.

Different from `/security-review` (repo-wide security audit) and `/pr-security-review` (PR-scoped security). This one is domain-specific to money math and is periodic, not PR-triggered.

## Triggers

- `/financial-review`
- "run financial review", "financial accuracy check"

## Config (read from `method.config.md`)

| Key | Purpose | Default |
|-----|---------|---------|
| **Project display name** | Used in the report header + comments | (project name) |
| **Financial review WIT** | Recurring Linear issue id for the review (e.g. `WIT-101`). **Blank → skip the Linear lifecycle entirely** (just run + report). | (blank) |
| **Financial review checks** | Path to the project checks file | `resources/financial-review-checks.md` |
| **Reports path** | Where to write the review report | `Reports/` |
| **Spec ready state** / state names | Linear state names for transitions (see below) | per board |

**Linear transitions are by state NAME via `pk`**, never hardcoded UUIDs: use `pk_linear_set_state "<WIT>" "<State>"` (or the project's Linear MCP with a name lookup). The three states this skill moves through are **In Progress**, **In Review**, **Done** — they must exist in the team's workflow.

## Step 0 — Load the checks file (gate)

Read the checks file at `Financial review checks` (default `resources/financial-review-checks.md`).

- **If it doesn't exist**, STOP and tell the user:
  > No financial-review checks file found at `<path>`. This skill is the framework; the project supplies the checks. Scaffold one from `pipekit/templates/financial-review-checks.template.md` (copy it to `<path>` and fill in your test command, calculation files, DB-integrity queries, and parity formulas), then re-run.
  Offer to scaffold it from the template.

The checks file defines, for this project: the **test command**, the **calculation source files**, the **DB-integrity queries**, the **client↔server parity formulas**, the **margin/footer checks**, and the **regression-watch paths**. Everything below executes *that project's* checks — this skill provides the discipline and the report shape, the checks file provides the substance.

## Step 1 — Open the review (Linear lifecycle)

If `Financial review WIT` is set:
- Move it to **In Progress**: `pk_linear_set_state "<WIT>" "In Progress"`
- Post a comment: `"Starting financial accuracy review — {YYYY-MM-DD}"`

If blank, skip — proceed straight to the audit and just produce the report.

> Recurring-WIT note: for a recurring Linear issue, **Done** means "this cycle's review is complete"; Linear's recurrence re-opens it next cycle.

## Step 2 — Read current state + baseline tests

- Read the calculation source files named in the checks file (the source of truth for the math).
- Find the previous report: `ls -t <Reports path>/Financial_Review_*.md 2>/dev/null | head -1` (for trend comparison).
- Run the checks file's **test command**. If tests fail → **Critical** finding, surfaced immediately.

## Step 3 — Cross-layer parity audit (parallel sub-agents)

Run the checks file's audit groups as parallel read-only sub-agents. The canonical groups (each project's checks file fills in the specifics):

1. **DB integrity** — run the checks file's SQL against the configured DB (via the project's DB MCP / `execute_sql`). Any row returned where a stored/view total disagrees with the recomputed total by more than the tolerance (default `> 0.01`) is a **Critical** discrepancy.
2. **Client↔server parity** — compare the server/DB formulas (e.g. `GENERATED ALWAYS AS` columns, RPCs) against the client calculation implementation named in the checks file. A formula mismatch is **High** (UI shows a different number than the source of truth).
3. **Margin / footer / derived metrics** — verify inline/derived calculations (margins, fees, contingency) per the checks file, including divide-by-zero guards and rounding accumulation.
4. **Snapshot / version integrity** (if applicable) — verify version-comparison math and sign conventions per the checks file.

Spawn these as independent sub-agents (they return findings; they do not fix). Each finding carries `file:line` or a query result as evidence.

## Step 4 — Regression scan

Run the checks file's regression-watch over recent history:
```bash
git log --oneline --since="7 days ago" -- <financial paths from checks file>
```
Flag any change touching financial logic for manual review.

## Step 5 — Update Linear by findings

If `Financial review WIT` is set:
- **Critical or High findings:** move to **In Review**, post a comment summarizing findings + proposed fixes. Work each fix, posting a comment per fix with evidence. After all fixes verified, move to **Done**.
- **Only Medium/Low, or clean:** proceed to the report; move to **Done** after it's written.

If blank, skip transitions.

## Step 6 — Generate the report

Write `<Reports path>/Financial_Review_{YYYY-MM-DD}.md`:

```markdown
# Financial Accuracy Review — {YYYY-MM-DD}  ·  {Project display name}

## Summary
- **Status**: PASS / FAIL / WARNINGS
- **Previous Review**: {date or "First review"}
- **Tests Passed**: {X}/{Y}
- **DB Integrity Checks**: {PASS/FAIL per check}

## Unit Test Results
{test output summary}

## Database Integrity
{per-check results — "PASS: no discrepancies" or the mismatching rows}

## Client↔Server Parity
{findings}

## Margin / Footer / Derived
{findings}

## Snapshot / Version Integrity
{findings, or "n/a"}

## Recent Changes (Last 7 Days)
{git log of financial-related changes}

## Findings
### Critical
{list or "None"}
### High
{list or "None"}
### Medium
{list or "None"}
### Low / Recommendations
{list or "None"}

## Known Gaps
{carried from the checks file's known-gaps section + anything new}

## Next Review Actions
{specific items to check next cycle}
```

## Step 7 — Close + summarize

- If `Financial review WIT` set: move to **Done**, post `"Review complete — {STATUS}. Report: <path>"`.
- Present the user: overall status, discrepancy count, top findings by severity, comparison to the previous review, recommended actions.

## Severity rubric

- **Critical** — a stored/view figure disagrees with the recomputed aggregation: users see a wrong number.
- **High** — client↔server formula mismatch: one surface shows a different total than the source of truth.
- **Medium** — unhandled edge case (divide-by-zero, null markup, excluded items).
- **Low** — code quality, missing test coverage, doc gaps.

## Key principles

1. **Numbers must match** — the same figure from the DB view, the calculation code, and the UI must agree; any delta beyond tolerance is a finding.
2. **Evidence-based** — every finding cites a query result or `file:line`.
3. **Regression-aware** — always check what changed recently.
4. **Consistent** — run the same checks-file checklist every cycle so trends are comparable.
5. **Framework here, checks in the project** — never hardcode a project's schema, paths, or WIT in this skill; they live in the checks file and `method.config.md`.
