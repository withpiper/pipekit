# Tier: Standard

> Default Pipekit pipeline. Full spec → review → plan → review → execute → QA loop. Use this unless there's a specific reason to escalate to Heavy or de-escalate to Quick.

## When to use

- This is the default. Most feature work lives here.
- Anything that doesn't qualify for Quick and isn't security-sensitive enough for Heavy

## Gates

| Gate | Standard |
|------|----------|
| Spec exists (`## Light Spec` section) | ✅ required |
| Spec review (Linear agent) | ✅ required |
| Human approval | ✅ required |
| Dependency check | ✅ required |
| Milestone-readiness (siblings specced) | ✅ required |
| VBW plan | ✅ required (Medium/High complexity) |
| Plan review (`/review-plan`) | ✅ required (Medium/High complexity) |
| Execution | ✅ VBW Dev (Medium/High) or batch runner (Low) |
| QA agent | ✅ required |
| Strategy sync | recommended (post-ship, batched) |

## Routing

Inside Standard, complexity still routes execution:

| Complexity | Route |
|------------|-------|
| Low (~2–4h) | `/linear-todo-runner`, AC-as-plan |
| Medium (~6–10h) | VBW Lead → plan review → Dev → QA |
| High (~12–20h+) | VBW Lead → plan review → Dev → QA, likely multi-task |

## Required artifacts

- Light spec in Linear (`## Light Spec`, `## Acceptance Criteria`)
- `PLAN.md` in `.vbw-planning/phases/<slug>/` (Medium/High)
- Plan-review report (Medium/High)
- QA verification report

## Close path

`pk ship` → Linear → UAT. UAT pass → merge PR → `pk done PROJ-XXX` (cleanup only; no state change) → `pk promote <env>` walks the chain (→ Released for intermediate hops, → Done for the final hop). `/strategy-sync` can be run per-issue or batched at end of phase.
