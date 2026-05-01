## Summary

`/launch --auto` (`skills/launch/skill.md:439-549`) is ~110 lines of nested decision logic with five branching pause points. The patch-release cadence v1.8.0.1 → v1.8.0.4 already iterated on default behaviors (Revise default flipped from `proceed` to re-review in v1.8.0.3). The skill is at the upper edge of what a fresh Claude session can execute deterministically.

Surfaced in v1.8 code review (2026-04-30).

## Issues

### 1. Revise default ordering is fragile

The "Revise default = re-review, NOT proceed" callout (skill.md:483) overrides what the AskUserQuestion options list (skill.md:480) implies. An agent skimming options-then-callout will pick `proceed` because it's listed first under Pass.

**Fix:** reorder the Revise options list so `apply-fixes-and-re-review` is presented first/explicitly marked default.

### 2. Stalemate detection is under-specified

Step 3d (skill.md:494) requires the orchestrator to compare round-3 blocking items against round-2 blocking items textually. The skill doesn't define what "overlaps" means:

- String equality?
- Semantic match?
- Bullet-by-bullet?

Two different agents will compute "overlaps" differently — fragile foundation for a stalemate-break.

**Fix:** define overlap precisely. Suggested: "any blocking-item text from round 2 reappears verbatim or paraphrased in round 3; if 2+ items overlap, declare stalemate."

### 3. Skill size approaches deterministic-execution limit

Five nested decision points (verdict pause, revise loop, stalemate at round 3, QA verdict pause, pause-for-end-session vs close-now) in one prose document. Cognitive load on the executing agent is high. Patch releases on this section have been frequent.

**Fix options:**

- **A.** Extract `--auto` orchestration into a separate skill (`/launch-auto`) so gate-only `/launch` stays scannable. Pro: clean separation. Con: two skills to maintain.
- **B.** Restructure the existing skill with an explicit state machine (numbered states with transitions), not prose narrative. Pro: deterministic. Con: more verbose.
- **C.** Leave as-is, just fix #1 and #2. Pro: minimal change. Con: doesn't address the size issue, future patches keep accreting.

Lean: **B** — state-machine restructure. Keeps one skill, makes execution deterministic.

## Acceptance criteria

- [ ] Revise default option is unambiguous to a fresh agent (default re-review, not proceed)
- [ ] "Overlaps" / stalemate condition is precisely defined
- [ ] Skill structure supports deterministic execution (state machine OR extracted orchestrator)
- [ ] Patch-release cadence on `/launch` decreases (lagging indicator)

## Priority

P2 — works in practice; degrades when an agent skims rather than reads carefully.

## Related

v1.8.0.2 (#20), v1.8.0.3 (#22), v1.8.0.4 (#21) all touched this section.
