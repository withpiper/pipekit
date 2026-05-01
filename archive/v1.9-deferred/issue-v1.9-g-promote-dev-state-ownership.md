## Summary

Three skills now transition the same Linear issue, with overlapping responsibilities and no documented ownership boundary. Surfaced in v1.8 code review (2026-04-30).

## The conflict

- `/branch --linear`: Approved → **In Progress** (`branch/skill.md:147-151`)
- `/launch`: Approved → **Building** (`launch/skill.md:214-217`)
- `/g-promote-dev` step 8: any pre-Building state → **In Progress** (`g-promote-dev/skill.md:165-183`)

By the time `/g-promote-dev` runs (after `/launch` has built and verified), the issue is already in Building or UAT. The skill's table correctly says `Building | UAT | Done → leave as-is`, but the entry behavior `Specced | Approved → In Progress` is wrong in the canonical Pipekit flow.

## Why it matters

If an issue is in `Specced` or `Approved` when `/g-promote-dev` runs, it means the user **bypassed `/launch`**. Quietly transitioning to In Progress hides that bypass and makes audit harder.

## Proposed fix

`/g-promote-dev`'s role at promote-dev time is to **attach the PR**, not advance state. State should already be Building (from `/launch` open) or UAT (from `/launch --close`).

**Two options:**

1. **PR-link only** — drop step 8 entirely. If state isn't already Building/UAT/Done, that's a bug elsewhere; promote-dev shouldn't paper over it.
2. **Warn-don't-advance** — keep step 8 but rewrite as: "If state ∉ {Building, UAT, Done}, print warning 'Issue is in {state}; expected Building/UAT. Did you skip /launch?' and continue without transition."

Lean: option 1. Simpler, enforces the gate.

## Acceptance criteria

- [ ] `/g-promote-dev` no longer transitions Linear state on its own
- [ ] Documented ownership: /branch owns Approved → In Progress, /launch owns In Progress → Building / Building → UAT, /launch --close owns UAT → Done
- [ ] If state is unexpected at promote-dev time, surface a warning rather than silently fixing
- [ ] Update `method.md` § Pipeline with the explicit ownership map

## Priority

P2 — workflow correctness bug. Won't fire today because users follow the canonical /launch path; will surface once /g-promote-dev gets used outside that path.
