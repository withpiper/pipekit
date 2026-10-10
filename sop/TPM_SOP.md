# TPM SOP

> For the full development pipeline, see [method.md](../method.md). This SOP is the rubric `/tpm` argues from; the session mechanics live in the skill.

**v5.0.0** — Last updated: 2026-10-10  *(New. The judgment rules behind `/tpm`: diagnose scope/capacity/dependency, stakes per item, Hard/Value/Soft dependencies, unblock-first ranking, a 60% capacity bound on MUST, the independence bar for parallel work, WAIT with a verified fallback and a re-entry trigger, and the runbook block `pk next` reads for staleness. Replaces `Lane_Map_SOP.md`: the picker is now the conversation.)*

---

## What a TPM session is for

A solo engineer's scarce resource is the attention to step back and decide. The session spends that attention once, on purpose: what must ship, what can wait and why, what stacks and what runs side by side. The output is an **agreement**, written to Linear (so `pk next` and `pk portfolio` print it) and to the one runbook (so the reasons survive). It is not a plan file: everything decision-bearing is in Linear, and the runbook is regenerated from the next agreement.

## Diagnose before ranking

Establish which problem the board has, because the remedies differ entirely:

| Problem | Looks like | Remedy |
|---|---|---|
| **Scope** | MUST would exceed the capacity bound even with perfect sequencing | something comes off; "if you add one, name what comes off" |
| **Capacity** | MUST fits, but in-flight leaks (un-`done` merges, abandoned In Progress) are eating the week | clear the leaks first — they are the cheapest hours on the board |
| **Dependency** | the important work is blocked by work nobody prioritized | lift the blocker (priority inversion), or add the missing relation so the walk can see it |

Front-load whatever could invalidate the plan: a migration, a schema decision, an external answer. Slack belongs at integration points, not at the end.

## Stakes per item

Five questions, each with a source. Draft every answer first; ask only where the draft is unsure or the answer would flip the order.

| Question | Source |
|---|---|
| Who is waiting, and was it promised? | Commitments register (runbook); `[tpm] commitment:` comment; the user |
| What happens if it waits two weeks? | issue body; the user |
| Is there an acceptable fallback today? | **the code**, via a Grounding-role scout — never the issue body's word |
| What does it unblock? | Linear blocking relations (`pk next` Supporting group) |
| What would make it urgent later? | the user — becomes the WAIT trigger |

Separate the literal ask from the job to be done, and must-haves from success criteria — the distinction that most often blurs when a client is waiting.

## Dependencies: Hard, Value, Soft

| Kind | Meaning | Where it lives |
|---|---|---|
| **Hard** | B cannot start, or cannot be correct, until A lands (schema, migration, foundation, auth model) | a Linear `blocked by` relation — the only kind `pk next` sees |
| **Value** | B is worth less until A ships (A proves the approach, A is the demo) | the runbook's order and reason; no relation |
| **Soft** | B is easier after A | a risk note in the runbook; never a relation |

A Hard dependency goes first regardless of any score. Schema and foundation tasks are almost always Hard for what sits on them. Writing a Value or Soft ordering as a `blocked by` relation pollutes the dependency truth every other tool reads; don't.

## Ranking

In order, each rule only breaking ties left by the one above:

1. **Hard dependencies first.** The blocker is scheduled before the blocked; the blocked item waits in NEXT, never in MUST.
2. **Unblock-first.** A two-hour task that releases four tickets beats a one-day task that releases none. Count what each item unblocks.
3. **Priority inversion.** A High blocked by a Low → the Low is scheduled with the High's urgency (`pk portfolio` already lifts it one step; the session makes it explicit).
4. **External commitment** beats internal preference at equal footing.
5. **Tie-break:** `(Impact + Risk) × (6 − Effort)`, each 1–5, and say the numbers so they can be disputed.

Never invent durations or a computed critical path. The data supports a longest blocker chain and coarse effort from tier labels; say that much and no more.

## Capacity

- **Week** = `method.config.md § Weekly capacity days` (default 6).
- **Effort** from the issue's tier label via `§ Tier effort days` (default `Quick: 0.5, Standard: 2, Heavy: 4`). Unsized items are **flagged**, not guessed.
- **MUST ≤ 60% of the week.** Over it, you have a scope problem, not a capacity problem — see Diagnose.
- In-flight leaks count as zero capacity used once cleared, and as a tax until then.
- Show the arithmetic in the briefing (`MUST ≈ 3.3 of 6 days (55%)`) so it can be disputed in one line.

## Parallel work: the independence bar

Two items may run side by side only when **all four** hold; otherwise they are sequenced, and the session says which criterion failed:

1. No blocking edge between them, in either direction.
2. No transitive path through a third item.
3. No shared unmerged foundation (a migration or shared module one of them is waiting on).
4. Provably disjoint file scope — read the specs; "probably" fails.

Fail closed. Two or more focus-lane heads that pass the bar and are Approved are the signal for `/06-linear-todo-runner --dry-run`.

## WAIT discipline

An item may be allowed to sit only with all three:

- a **fallback** that was read in code this session or a previous one (date it);
- a **re-entry trigger** — the condition that moves it back in ("a second tenant hits it", "before the beta promote", "when 441 ships");
- its **floor priority intact** — WAIT is expressed by being out of focus and by the runbook, never by lowering importance, which `/pk-bug` and `/linear-hygiene` read for other purposes.

A WAIT with no trigger is neglect with a label.

## How to ask

- The briefing comes first and is a complete draft; questions are corrections to it.
- Ask only the questions that most change the output; in `--quick`, at most three.
- Every question offers two or three real options with what each costs, which one you would take and why, and **what would make your pick wrong**. A question handed up without options moves the work back to the user unchanged.
- "Just do it" → proceed, and list the assumptions at the top of the read-back and the runbook block.
- Judgment calls that are the user's alone are recorded with their reason, not argued.

## What Linear carries, what the runbook carries

`pk next` orders by lane tier → issue priority → blocked-sinks, and nothing else. Four priority levels cannot encode a sequence, and priority already means importance elsewhere. So:

| Linear carries (coarse, tool-readable) | The runbook carries (exact, human-readable) |
|---|---|
| lane tiers A/B/C (project priority) | the order within and across lanes, with reasons |
| Hard dependencies (`blocked by`) | Value and Soft orderings, risk notes |
| importance (issue priority), changed only when importance changed | WAIT fallbacks and triggers |
| `[tpm]` comments — the per-item reason | the Commitments register, the capacity arithmetic, parallel-safe pairs, "not these, and why" |

`pk next` therefore prints the agreed *lanes and blockers*; the runbook prints the agreed *order*. Promise no more than that.

## The runbook block

One file per consumer (`§ Runbook path`, default `engineering/RUNBOOK.md`), three regions, three owners: the TPM block (`/tpm`), the Notes section (the human), the How-we-run block (`sync-method.sh`). Each writer touches only its own marker pair and fails closed if the pair is missing or malformed.

```
## Now
<!-- tpm:begin · agreed 2026-10-10 · derived from Linear · written by /tpm, regenerate don't edit -->
Focus  A I8.P6 Game7 ledger reconcile · B I7.P2 export fixes · C —
Assumptions: (only when the user said "just do it")

### Commitments
| Who | What | Due | Issues | Since |
| Game7 | ledger reconcile | 2026-10-17 | POC-441, POC-442 | 10-03 |

### MUST — this week  (≈3.3 of 6 days, 55%)
| Item | Why | Unblocks | Effort | Status |
| POC-441 ledger reconcile | Game7, due Fri | 442 | 2d | Approved, head |
| POC-377 (Low) | inversion: blocks 398 (High) | 398 | 0.5d | Approved |

### NEXT
| Item | Why | After |
| POC-398 export fix | promised to … | 377 |

### WAIT — fallback and re-entry trigger
| Item | Fallback (verified) | Trigger |
| POC-412 input hardening | boundary validation rejects (10-03) | 2nd tenant hits it, or before beta promote |

### Parallel-safe now
441 ∥ 377 — no edge, no shared foundation, disjoint files.

### Waiting on you
POC-440 review (2d) · PIPER-698 — abandoned or not?

### Not these, and why
POC-455 — needs a spec before it can be head · POC-377 — … (six words each)

### Drift since agreement   (rewritten by --check)
—
<!-- tpm:end -->
```

The `agreed YYYY-MM-DD` on the begin line is a contract: `pk next` reads it and prints `runbook agreed Nd ago → /tpm` past `§ Runbook stale days` (default 7). Portfolio repos other than the primary hold a one-line pointer in their block instead of a copy — one document, reachable from either repo, never two versions.

## Comments

Every Linear write the session makes leaves its reason on the issue, so the next reader (human or `/tpm`) doesn't re-derive it:

```
[tpm 2026-10-10] MUST — Game7 commitment, due 10-17; head of I8.P6
[tpm 2026-10-10] WAIT — fallback: boundary validation rejects (verified in src/api/validate.ts); trigger: 2nd tenant hits it
[tpm 2026-10-10] blocked by POC-377 — Hard: 398 reads the column 377 adds
[tpm 2026-10-10] commitment: Game7 · due 2026-10-17
```

One line, the bracketed date first, so `pk issue show --comments` can be grepped for the latest.

## Why not a plan file, and why the lane map retired

A tracker-external plan (`deps.json`, a `PLAN.md`, a kanban app) is a second source of truth that drifts the moment an issue ships; that is why Lane (2026-06) was declined. The lane-map artifact (v4.29.0–v4.38.0) was a picture plus a click-picker for tiers; once tiers are set by agreement with a reason attached, a picker without reasons is a step backwards and a second surface to regenerate after every write. Retired in v5.0.0; the runbook's top screen and `pk status` carry the picture.

## Borrowed from

Surveyed 2026-10-10 across ~65 Claude Code skill files; nothing filled the role, these rules did: unblock-first ranking and the independence bar (khalilouardini/kstack), priority inversion (joa23/linear-cli), Hard/Value/Soft and the 60% bound (AI-Foundry-Core/ril-agents), scope/capacity/dependency diagnosis and slack-at-integration-points (cbrock84/headcount), options-and-a-pick-and-what-would-make-it-wrong (avelikiy/great_cto), ask-vs-job and must-haves-vs-success-criteria (deanpeters/Product-Manager-Skills), the question stop rule (borghei/Claude-Skills), re-entry triggers (rampstackco), the tie-break formula (Anthropic engineering plugin `tech-debt`).
