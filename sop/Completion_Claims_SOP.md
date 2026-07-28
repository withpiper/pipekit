# Completion Claims SOP

**v4.22.0** — Last updated: 2026-07-28

The full completion-claims loop. The trigger and short form live in
`.claude/rules/pipekit-discipline.md § Completion Claims` (always loaded);
this SOP is the demand-loaded procedure — open it when you're about to run
the loop, not before.

Run this before declaring any non-trivial decision or completed work. It
catches vibes-masquerading-as-decisions before they ship.

## 1. CLAIM

Before any non-trivial decision, write the claim in this exact form:

```
CLAIM: <the assertion you're about to make in one sentence>
WHY THIS MATTERS: <what breaks or who suffers if the claim is wrong>
```

If you can't write the claim that compactly, you have a vibe, not a decision.

## 2. EXTRACT

Pass the ARTIFACT and the CONTRACT to the reviewer. Strip your reasoning. If
you hand over conclusions, you'll get back validation of your conclusions.

- **ARTIFACT** = the code, diff, spec, or decision document being reviewed
- **CONTRACT** = what the artifact is supposed to satisfy (for Pipekit: the
  Linear issue's AC list)

## 3. DOUBT

Spawn a fresh-context subagent with this prompt verbatim:

```
Adversarial review. Find what is wrong with this artifact.
Assume the author is overconfident. Look for:
- Unstated assumptions
- Edge cases not handled
- Hidden coupling or shared state
- Ways the contract could be violated
- Existing conventions this might break
- Failure modes under unexpected input

Do NOT validate. Do NOT summarize. Find issues, or state
explicitly that you cannot find any after thorough examination.

ARTIFACT: <paste artifact>
CONTRACT: <paste contract>
```

## 4. RECONCILE

For each finding the reviewer returns, classify in this **precedence order**
(first matching class wins):

1. **AC misread** — reviewer flagged something specifically because the
   CONTRACT (AC) you provided was unclear or incomplete. Fix the AC first,
   re-classify on the next cycle. (Adapts doubt-driven-development's
   "Contract misread" to Linear acceptance criteria; the AC is the contract.)
2. **Valid + actionable** — real issue requiring a change to the artifact.
   Change it, re-loop.
3. **Valid trade-off** — issue is real but cost of fixing exceeds cost of
   accepting. Document the trade-off explicitly so the user sees it.
4. **Noise** — reviewer flagged something that's actually correct under
   context the reviewer didn't have.

## 5. STOP

Stop when:

- Next iteration returns only trivial or already-considered findings, OR
- 3 cycles completed (escalate to user, don't grind a fourth alone), OR
- User explicitly says "ship it."

**Doubt theater red flag**: across 2+ cycles where the reviewer surfaced
substantive findings, zero findings were classified as actionable. You are
validating, not doubting. Stop and escalate.
