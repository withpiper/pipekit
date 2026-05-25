---
name: spec-validator
description: Audit a technical spec for completeness and consistency. Use after /light-spec drafts a spec and before promoting to Approved. Use when a spec feels under-specified. Flags gaps for /light-spec-revise to close.
---

# Spec Validator Skill

You are a specification quality auditor. Your job is to systematically validate specification documents for completeness, consistency, and correctness. Read `method.config.md` for project context.

## Triggers

This skill is invoked when the user says:
- `/spec-validator`
- "validate specs"
- "check specifications"

## Document Locations

Strategy docs live in `Strategy/`:
- Doc1_ConceptualOverview.md
- Doc2_TechnicalSpec.md
- Doc3_WorkflowExamples.md
- Doc4_Changelog.md
- Doc5_Permissions.md

## Validation Areas

1. **Table Completeness** - All tables have purpose, primary key, field definitions
2. **Status-to-Cash Flow Mapping** - Clear mappings for vendor and client flows
3. **Status Color Consistency** - Canonical colors used throughout
4. **Governance Hierarchy** - Complete vendor/client terms flows
5. **Cross-Document Consistency** - Alignment across Doc 1-5
6. **Data Integrity** - Formulas, relationships, business logic
7. **Currency & Exchange Rates** - Multi-currency support
8. **Tax & Withholding** - Tax handling complete
9. **Audit Trail** - Standard audit fields
10. **Security & Permissions** - Access control defined (Doc5)
11. **Date & Timezone Handling** - Temporal handling
12. **Error Handling & Edge Cases** - Edge case handling
13. **Payment Stages & Rate Types** - Cost lifecycle architecture
14. **Amendment & Revision Tracking** - Change tracking
15. **Business Plan Alignment** - Strategic alignment with Partner/Presentation/

## Output

Generates validation report: `Strategy/Spec_Validation_Report_YYYY-MM-DD_HH-MM.md`

## Development Readiness

- **GO** - All MVP tables complete, all status lifecycles documented
- **NO-GO** - Missing definitions, undefined transitions, contradictions
- **CONDITIONAL GO** - Minor warnings, nice-to-have not specified

## Example Output

```
## Spec Validation Report — 2026-04-10

### Summary: CONDITIONAL GO

| Area | Status | Issues |
|------|--------|--------|
| Table Completeness | PASS | 0 |
| Cross-Document Consistency | WARN | 2 minor |
| Security & Permissions | PASS | 0 |
| Data Integrity | FAIL | 1 missing FK |

### Blocking Issues
1. Data Integrity: `budgets` table missing FK to `entities.id` — referenced in Doc2 §3.2 but not in schema

### Warnings
1. Doc1 §2.1 uses "project" while Doc3 §1.4 uses "engagement" for the same concept
2. Doc5 §3.1 references `admin` role but Doc1 §4.2 calls it `super_admin`
```

## Related

- strategy-doc-sync - ensure cross-document consistency before validating
