# Light Spec Template

> Canonical template for structured specs. Used by `/light-spec` and the Spec Review Agent.
> This is an AI→AI contract: Generator → Reviewer → Planner. Every rule must be explicit, unambiguous, and enforceable.

## Light Spec

**Status:** Draft | Agent-Reviewed | Planning-Ready
**Complexity:** Low (~2-4h) | Medium (~6-10h) | High (~12-20h+)
**Phase:** [initiative `i{N}.` name or TBD]
**Linear Project:** [project name or TBD]

### Problem
[What's broken, missing, or suboptimal? Why does this matter? 2-3 sentences max.]

### Goal
[What is true after this is done? Define the end-state, not the work. 1-2 sentences.]

### Proposed Solution
[What are we building? High-level approach in 3-5 bullets. Describe outcomes, not implementation steps.]

### Scope

**In scope:**
- [concrete deliverable 1 — describe the outcome, not the method]
- [concrete deliverable 2]

**Out of scope:**
- [explicitly excluded item — prevents scope creep during planning]

### Decisions
[Key behavioral decisions that affect implementation. Each must be DEFINED or marked [TBD].]

- **[Decision area]:** [chosen approach] | [TBD — needs input from ___]

### Requirements
- [ ] [functional requirement 1]
- [ ] [functional requirement 2]
- [ ] [functional requirement N]

### Acceptance Criteria
[Each criterion MUST define an **input or state** and an **observable output**. For UI criteria, reference the specific surface (page, component, modal). A criterion the planner cannot verify is not a criterion.]

- [ ] [Given <state/input>, when <action>, then <observable output on specific surface>]
- [ ] [criterion N]

**Invalid patterns (spec fails review if these appear):**
- "All tests pass" — test counts are not acceptance criteria
- "Works correctly" — define what correct means
- "UI is updated" — specify which page/component and what changes
- Any criterion without a concrete expected behavior

### Technical Context
[What exists today that's relevant? Keep it brief — `/work`'s planner will do deep exploration during planning.]

- **Existing code:** [relevant paths or "greenfield"]
- **Database:** [relevant tables or "new tables needed"]
- **Dependencies:** [external libs, APIs, other features]
- **Patterns to follow:** [existing patterns in the codebase to match]
- **Authority:** [For data/calculations: where is the source of truth? DB | utils | POC | API. If multiple layers, explicitly define precedence — e.g., "DB is authoritative; utils must match DB behavior." Never leave authority ambiguous when two layers could disagree.]

### Migration Plan
[**Required only if this spec changes the database schema** (tables, columns, types, constraints, indexes, RLS policies, functions, triggers). If no schema change, delete this section. The schema change MUST land as a migration file — not an ad-hoc `ALTER` or a hand-edited schema dump. The AI still does all the DDL work; only the artifact is constrained. See `sop/Database_SOP.md`. Answer all six; a `[TBD]` that would force the planner to guess a task boundary blocks planning.]

- **Schema objects:** [tables/columns/constraints/indexes/policies/functions touched]
- **Migration tool + dir:** [from `method.config.md § Migration dir` — e.g. `supabase/migrations/`]
- **Forward intent:** [what the migration asserts, in outcome terms — not literal SQL]
- **Rollback intent:** [how it's undone, or "irreversible — data loss on revert" stated explicitly]
- **Data backfill:** [existing-data transform/default/backfill needs; nullable-vs-NOT-NULL; sentinels — or "none"]
- **Authorization:** [RLS policy / GRANT for new tables/columns; default deny — or "n/a, no new access path"]

### Risks & Open Questions
- [risk or unknown 1 — e.g., "Unclear if RLS policy covers this case"]
- [risk or unknown 2]
- [question for planning to resolve]

### Notes
[Anything else: related issues, prior art, user feedback, design links, etc.]
