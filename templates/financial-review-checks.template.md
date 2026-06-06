# Financial Review Checks — {PROJECT}

Project-specific checks consumed by the portable `/financial-review` skill. Copy this
file to your project (default path `resources/financial-review-checks.md`, or set
`Financial review checks` in `method.config.md`) and fill in every section for your
schema and code. The skill supplies the discipline + report shape; this file supplies
the substance. Keep it committed — it's project-owned, never overwritten by sync.

> Examples below are drawn from a real finance platform (budgets → sections →
> subsections → line items, with client + DB calculation layers). Replace them with
> your own; delete what doesn't apply.

---

## Test command

The calculation test suite that establishes the baseline. A non-zero exit is a **Critical** finding.

```bash
# EXAMPLE — replace:
cd "$(git rev-parse --show-toplevel)" && npx jest tests/calculations.test.js --verbose
```

## Calculation source files

The files the skill reads to understand the math (the source of truth + where it's recomputed).

```
# EXAMPLE — replace:
src/app/js/utils/calculations.js     # client-side line-item math
supabase/migrations/                 # GENERATED ALWAYS AS columns / RPCs (DB-side math)
src/app/js/pages/budget-edit-main.js # inline margin / footer calculations
tests/TEST_COVERAGE.md               # documented integrity checks + known issues
```

## DB integrity queries

Run against the configured DB (your project's DB MCP / `execute_sql`). Each query should
return **zero rows** on a healthy system; any returned row is a **Critical** discrepancy.
Tolerance for float comparisons: `> 0.01` unless noted.

```sql
-- EXAMPLE Check 1 — stored/view total matches recomputed line-item sum
-- (replace tables/columns with yours)
SELECT p.id, p.name, pt.total_sum AS view_total, COALESCE(s.computed_total,0) AS computed_total
FROM projects p
JOIN project_totals pt ON pt.id = p.id
LEFT JOIN LATERAL (
  SELECT SUM(li.total) AS computed_total FROM line_items li WHERE li.project_id = p.id
) s ON true
WHERE ABS(COALESCE(pt.total_sum,0) - COALESCE(s.computed_total,0)) > 0.01;
```

```sql
-- EXAMPLE Check 2 — child-level total matches its line items
-- EXAMPLE Check 3 — derived rate (fee/tax/markup) drawn from the right source
```

## Client ↔ server parity

The formulas to compare between the client implementation and the DB/server definition.
A mismatch is **High**.

```
# EXAMPLE — replace with your formulas:
subtotal = qty * unit_cost * multiplier
tax      = subtotal * tax_pct
total    = subtotal + tax
# markup formats the client must match the DB on: 20%, -10%, +50, -200, =800, null
```

## Margin / footer / derived metrics

Inline/derived calculations to verify (guards, rounding, base correctness). **Medium** unless
they produce a user-visible wrong number (then **High**).

```
# EXAMPLE:
margin = (out_total - in_total) / out_total * 100   # guard divide-by-zero
fee base respects per-section include flags
contingency applied to both internal and client-facing totals
```

## Snapshot / version integrity (optional)

If the project has versioned snapshots / a version-comparison RPC, the math + sign
conventions to verify. Delete this section if not applicable.

## Regression-watch paths

Paths the skill greps for changes in the last 7 days (any change here → manual review flag).

```
# EXAMPLE — replace:
supabase/migrations/
src/app/js/utils/calculations.js
src/app/js/pages/budget-edit-main.js
```

## Known gaps

Carried into every report's "Known Gaps" section so they're tracked, not rediscovered.

```
# EXAMPLE:
- GP%/NP% computed inline in the footer, not as testable functions
- No cash-flow model yet
```
