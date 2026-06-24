# Tier: Quick

> Lightweight track for small, contained changes. AC is the plan. Skips spec review, plan review, and the milestone-readiness gate.

## When to use

- 1–3 stories, single PR, single sitting
- AC fits comfortably in the issue description
- No cross-cutting architectural impact
- No new dependencies, env vars, or schema changes
- A failed change is fully reversible by reverting the PR

## When NOT to use

- Touches authn/authz, payments, billing, or PII handling → use Heavy
- Adds or modifies a Strategy doc concern → use Standard or Heavy
- More than one PR will be needed → use Standard
- You can't write the AC in 5 bullets → use Standard

## Gates

| Gate | Quick |
|------|-------|
| Spec exists (description has AC section) | ✅ required |
| Spec review (Linear agent) | ⏭ skipped |
| Human approval | ✅ required |
| Dependency check | ✅ required |
| Milestone-readiness (siblings specced) | ⏭ skipped |
| PLAN.md + plan review | ⏭ skipped |
| Execution | ✅ via batch runner / `/linear-todo-runner` |
| QA agent | ⏭ skipped (CI + UAT only) |
| Strategy sync | ⏭ skipped |

## Routing

`/work` routes Quick tier directly to in-context execution (or `/linear-todo-runner` for batch parallel execution of multiple Quick issues). No PLAN.md generated — the AC section is the executable plan.

## Required artifacts

- `## Acceptance Criteria` section in Linear issue description
- (No spec, no plan, no QA report)

## Close path

`pk ship` → Linear → UAT (PR open on preview). UAT pass → merge PR → `pk done PROJ-XXX` (cleanup + Linear UAT → `In <FirstEnv>`) → `pk promote <env>` walks the chain (→ `In <Env>` for intermediate hops, → Done for the final hop; 2-tier: `pk promote` with no arg).
