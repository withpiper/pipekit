# FROZEN SPEC — POC-48 — round-2 head-to-head

> Single frozen contract for the POC-48 bounded head-to-head (native-improved vs VBW-full).
> Verbatim from Linear POC-48 (Status: Approved, Readiness 9/10, tier:heavy). Frozen 2026-06-07.
> Target repo: SiteLine. Depends on POC-47 (Done & live). Winner of the head-to-head ships.

# Administrative block: derived-fee percentage rows on a rolled-up base

**Status:** Approved · **Complexity:** High (~14-20h) · **Tier:** tier:heavy → route through `financial-review`
**Linear Project:** i1-p1 Budget Block Types · **Depends on:** POC-47 (block_type + income-aware rollup) — ✅ Done & live on dev+prod

## Problem

SiteLine has no way to charge derived overhead fees (insurance, overhead, accounting) as a percentage of a budget's billable cost base. The `include_in_admin_total` flag already exists on sections and is exposed in the Organize palette and `get_budget_data`, but it is wired to nothing — toggling it has zero effect. Event production companies routinely bill these admin fees as a percentage of project costs; today they hand-calculate and hard-enter them, which breaks whenever underlying costs change.

## Goal

A single Administrative block exists per budget. It appears automatically when any section's admin toggle is on, holds editable percentage rows (insurance, overhead, …), and charges each row's percentage against a derived base equal to the straight sum of the pre-tax OUT subtotals of every admin-toggled section. The charge stays correct and live as underlying costs change, and agrees to the cent across editor, dashboard, PDF, and Excel.

## Scope

**In scope:** consume `include_in_admin_total` to compute the admin base (sum of pre-tax, billable, non-excluded OUT subtotals of admin-toggled non-admin sections); auto-create/show-hide lifecycle of the single Administrative block + initial subsection; bind percentage rows to the derived base via the existing line engine; evaluation order (non-admin subtotals → admin base → admin rows → below-the-line production fee & contingency, which include admin block's out when fee flags on, default on); self-reference guard + single-admin-block enforcement; source-note rendering in editor, PDF (`pdf-blocks.js`), Excel (`budget-edit-exports.js`); admin contribution in SQL read paths (`get_budget_data`/`project_totals`/`section_totals`) matching JS rollup to the cent; regression + behavioral + parity tests.

**Out of scope:** Revenue block (POC-49) + Staffing; dashboard IN-side contingency double-count fix (POC-72); any formula language / multi-base / per-row distinct bases (one base per budget only); changing production-fee or contingency formulas (admin merely joins their existing bases via standard fee flags).

## Decisions (authoritative)

- **Block identity:** exactly one `block_type='admin'` section per budget, auto-managed (not user-created). Reuses POC-47 income-shaped netting (admin in `INCOME_BLOCK_TYPES`) — its rows' OUT is money-in that nets into profit.
- **Base definition:** straight sum of pre-tax OUT subtotals (`out_subtotal`, billable rows only; excluded sections/subsections contribute nothing) of every **non-admin** section with `include_in_admin_total = true`. Pre-tax, client-verifiable.
- **Percentage-row encoding (authoritative):** a row's percentage is stored as its `qty`, as a **decimal fraction** (10% → `0.10`), rendered as a percent in UI. The row's out-rate is the **derived base** (not stored authoritatively). Optional in-cost is a **flat currency amount** in the line's in-cost field; does **not** scale with the percentage. Markup unused. At compute time both renderers derive: `out_subtotal = qty(fraction) × base`; line profit = `out_subtotal − in_cost`; margin = `profit ÷ out_subtotal` (margin "—" when `out_subtotal = 0`). IN/profit side likewise derived from `{qty, base, in_cost}`, not summed from stored generated columns.
- **Fee membership:** admin block's own `include_in_production_fee`/`include_in_contingency` default **true**, toggleable off.
- **Evaluation order & no cycle:** base built only from OUT subtotals of cost sections, never below-the-line fees → admin → production fee → contingency forms no cycle. Admin section always excluded from its own base.
- **Toggle-off lifecycle:** when the last admin toggle turns off, the block is **hidden and its row data preserved**; flipping any admin toggle back on restores rows intact. A single toggle never destroys hand-entered financial data. While hidden it contributes nothing.
- **Hidden-block editability:** while hidden, preserved rows are **inert** — not viewable/editable on any surface; editable again only when an admin toggle reveals the block.
- **Base binding:** admin base + each row charge are **derived at compute time in both renderers** (JS rollup AND SQL read paths, mirroring POC-47 income netting), enforced by a parity test. No write-amplification trigger.
- **Read boundary — surfaces that must derive (never trust stored) admin-row `out_*`:** `computeProjectRollup` (`budget-rollup.js`, JS authority); SQL read paths `get_budget_data`, `project_totals`, `section_totals`; the editor section-subtotal loop (`budget-edit-main.js:2119-2139`); exports (`pdf-blocks.js`, `budget-edit-exports.js`) — exports compliant **as long as** they consume `computeProjectRollup` not raw row columns (verified). `getProjectWithTotals` (`js/database/projects.js:231`) is a dead read path (zero callers per POC-72) and must be **deleted or annotated**. No other code may read admin-row `out_*` directly.
- **Single-source-of-truth / parity:** admin base + row charges computed once per renderer, must agree to the cent between JS rollup and SQL views (parity test, per POC-47).
- **Source-note ordering:** "Based on: …" names listed in budget's **section display order, ascending**, identically in editor, PDF, Excel (parity-testable).
- **Editability:** after auto-creation the subsection + rows fully user-editable (add/rename/delete rows, rename subsection). Block *container* is toggle-managed, not manually deleted while any admin toggle is on.
- **Self-reference guard in palette:** Organize palette does not offer an admin toggle on the admin block itself.
- **Zero-percent rows:** a `0%` row is valid — stores `qty = 0`, renders, exports, charges `$0.00`.

## Requirements

- [ ] Turning on any section's `include_in_admin_total` creates (first time) + reveals the single Administrative block; turning all off hides it while preserving rows.
- [ ] Admin base = straight sum of pre-tax OUT subtotals of all admin-toggled non-admin, non-excluded sections, excluding the admin block itself.
- [ ] Each percentage row charges `qty(fraction) × base`, in-cost default 0 (flat currency), no markup; optional in-cost reduces that row's margin only.
- [ ] Admin-row OUT (and profit/margin) is **derived** (`= qty × live base`, `profit = out − in_cost`) in every read surface listed; no read path sums stored admin-row `out_*`.
- [ ] Base is live: when a contributing section's pre-tax OUT subtotal changes, every admin row's charge updates.
- [ ] Block shows a source note naming contributing sections in section display order.
- [ ] Admin block participates in production-fee and contingency bases per its fee flags (default on).
- [ ] Admin contribution renders in editor, PDF, Excel, and is included in all grand totals.
- [ ] A `0%` row renders, exports, charges `$0.00` without error.
- [ ] JS rollup and SQL read paths agree on every admin-affected figure to the cent.
- [ ] Budgets with no admin-toggled sections are byte-for-byte unchanged from today.

## Acceptance Criteria

- [ ] **First-appearance auto-create:** budget with no admin block + section "Production" ($1,000 pre-tax OUT subtotal); turn on Production's admin toggle → Administrative block with one empty subsection appears, source note "Based on: Production".
- [ ] **Derived charge:** admin block on $1,000 base; add "Insurance" at 10% → charge displays $100.00, in-cost 0, margin 100%.
- [ ] **Live base update:** Insurance 10% on $1,000; edit Production so section pre-tax OUT subtotal = $1,500 → Insurance charge updates to $150.00 in editor without manual edit.
- [ ] **Stored columns not trusted:** admin row whose persisted `out_subtotal` is stale; read via `get_budget_data` + dashboard → admin charge = `qty × current base`, not stored value.
- [ ] **Multi-section base + source note:** "Production" ($1,000) + "Travel" ($500) both admin-toggled → base = $1,500, source note "Based on: Production, Travel" (display order).
- [ ] **Optional in-cost reduces margin:** Insurance $100 on $1,000 base; enter $50 in-cost → profit $50, margin 50%; change % to 20% (charge $200) → in-cost stays $50 (flat).
- [ ] **Self-reference guard:** admin block exists → its own rows excluded from base; palette shows no admin toggle for the admin block.
- [ ] **Hide + preserve on toggle-off:** one admin-toggled section + admin block w/ Insurance row; turn that toggle off → block hidden, contributes nothing; turn an admin toggle back on → Insurance row reappears with prior % intact.
- [ ] **Participates in below-the-line fees:** admin block charging $100, production-fee flag on; production fee 10% → admin block's $100 in the production-fee base, consistent editor + dashboard.
- [ ] **Export rendering:** admin block w/ Insurance row + source note; export PDF + Excel → each shows admin block, charge, "Based on: …" (same order), grand totals include admin charge.
- [ ] **Zero-percent row:** admin row 0% on non-zero base → charge $0.00, appears in editor + exports, no error.
- [ ] **Parity (computed figure):** fixture w/ admin-toggled sections at fractional cents (7.5% tax, odd unit costs); admin base, each admin row charge, production fee, contingency, budgeted total, final total, profit via JS rollup AND SQL views → each agrees abs diff < 0.005.
- [ ] **Empty/zero base:** admin-toggled section billable OUT subtotal $0, admin row 10% → charge $0.00, no NaN/error.

## Technical Context

- **Foundation (done):** POC-47 added `block_type` to `sections` (`admin` income-shaped, in `INCOME_BLOCK_TYPES`), threaded through `get_budget_data` (`supabase/migrations/20260606120100_get_budget_data_block_type.sql`), made `computeProjectRollup` (`src/app/js/utils/budget-rollup.js`) + `project_totals`/`section_totals` block-type-aware with JS↔SQL parity tests. `include_in_admin_total` exists since `20260123102032_versioned_sections.sql`, already returned by `get_budget_data`.
- **Existing code:** flag toggle UI + `toggleSectionFeeFlag()` ~`budget-edit-main.js:5572` (palette render ~5328); rollup `budget-rollup.js` (`computeProjectRollup`, `INCOME_BLOCK_TYPES`, fee-base accumulators); line math `calculations.js` (`calculateOutSubtotal`, `calculateOutCost`); section OUT subtotal `budget-edit-main.js:2119-2139`; subsection creation `database/sections.js` (`createSubsection`); exports `pdf-blocks.js` (~307-334) + `budget-edit-exports.js`.
- **Dead read path:** `getProjectWithTotals` (`js/database/projects.js:231`) `select('*')` exposing divergent total columns, zero callers (POC-72). Delete or annotate as part of read-boundary work.
- **Database:** no schema change strictly required for the flag (exists). A new migration computes the admin base/row charge in SQL read paths. New migration timestamp strictly later than latest on disk — re-check tail immediately before merge (frozen-file invariant).
- **Authority:** Postgres numeric semantics authoritative for rounding; JS rollup conforms. JS rollup + SQL views are two renderers of one model, agree to the cent (POC-47 parity rule).
- **Patterns:** POC-47's "compute once per renderer, enforce with a parity test"; round-at-line → sum-exact → round-derived ordering.

## Notes

Heavy tier: mandatory `financial-review` at hand-off; `/strategy-sync` before close. Sibling of POC-49 (Revenue). POC-72 (dashboard IN-side contingency double-count) is separately tracked — do NOT fold its fix in. Accepted design note: single-section base is permitted (design-awareness only, no blocker).
