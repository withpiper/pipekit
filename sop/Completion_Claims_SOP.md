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
2. **AC wrong — artifact right, spec stale** — the finding is a genuine
   artifact-vs-AC contradiction, and on inspection the **AC** is the
   incorrect half. Amend the AC to describe what actually ships, and say
   why, in the same change. This is not a lesser finding than class 3 — it
   is the same defect pointing the other way.
3. **Valid + actionable** — real issue requiring a change to the artifact.
   Change it, re-loop.
4. **Valid trade-off** — issue is real but cost of fixing exceeds cost of
   accepting. Document the trade-off explicitly so the user sees it.
5. **Noise** — reviewer flagged something that's actually correct under
   context the reviewer didn't have.

### The closure rule — a contradiction never resolves to "trade-off"

A finding of the shape *"the artifact does X, the AC says Y"* has exactly
two legal resolutions: **change the artifact** (class 3) or **amend the AC**
(class 2). Both are usually cheap, and both can land in the same change.
What is never legal is shipping with the two still disagreeing and no record
of which half is authoritative.

Class 4 is where that illegal third option hides, so the distinction matters:
a trade-off is *"both options are defensible and we chose one, here is why."*
It is **not** *"the spec says X, we shipped Y, and we left both standing."*
The second leaves the next reader unable to tell which half is true, and the
spec quietly becomes fiction — at which point every later reviewer inherits a
contract they cannot trust.

Note the corollary: this rule does **not** make an AC contradiction
merge-blocking, and it should not be read that way. Amending a stale AC is a
two-line edit, not a schedule risk. The requirement is that the disagreement
is *resolved*, not that the artifact always yields.

*Anchor: SiteLine PIPER-770, 2026-08-25 — a pre-merge adversarial review
caught the artifact contradicting its own spec's stated confirmation contract
and recorded the verdict "honest UI, unamended spec": the code was right and
the AC was wrong. It was classified a trade-off and deferred to a follow-up,
so neither half was amended. The behaviour shipped, priced things wrong for a
day, and came back as its own Medium bug. Detection worked — 7 hours before
merge. Classification is what failed.*

## 5. STOP

Stop when:

- Next iteration returns only trivial or already-considered findings, OR
- 3 cycles completed (escalate to user, don't grind a fourth alone), OR
- User explicitly says "ship it."

**Doubt theater red flag**: across 2+ cycles where the reviewer surfaced
substantive findings, zero findings were classified as **either class 2 (AC
wrong) or class 3 (valid + actionable)** — i.e. nothing you were told
produced a change to the artifact *or* to the contract. You are validating,
not doubting. Stop and escalate.

Class 2 counts here deliberately: amending a stale AC is a real correction,
not a dodge. What the flag is looking for is a loop where every finding is
absorbed as a trade-off or dismissed as noise, leaving both halves untouched.
