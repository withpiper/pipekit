# TPM SOP

> For the full development pipeline, see [method.md](../method.md). This SOP is the rubric `/tpm` argues from; the session mechanics live in the skill.

**v5.4.0** — Last updated: 2026-10-31  *(v5.4.0 — incident anchors keep their month and their lesson, not a former consumer's name or issue id; sample ids are PROJ-nnn; "WIT" is "issue"; the example week is a generic single-repo week)*

---

## What a TPM session is for

A solo engineer's scarce resource is the attention to step back and decide. The session spends that attention once, on purpose: what must ship, what can wait and why, what stacks and what runs side by side. The output is an **agreement**, written to Linear (so `pk next` and `pk portfolio` print it) and to the weekly plan (so the order, the reasons and the commands survive in a form the engineer reads every morning). The plan is derived: everything decision-bearing is in Linear, and the plan is regenerated from the next agreement. The runbook is how the project runs; the plan is what the engineer does this week. Different readers, different cadence, two files.

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
| Who is waiting, and was it promised? | Commitments register (plan); `[tpm] commitment:` comment; the user |
| What happens if it waits two weeks? | issue body; the user |
| Is there an acceptable fallback today? | **the code**, via a Grounding-role scout under the scout contract below — never the issue body's word, never the scout's summary |
| What does it unblock? | Linear blocking relations (`pk next` Supporting group) |
| What would make it urgent later? | the user — becomes the WAIT trigger |

Separate the literal ask from the job to be done, and must-haves from success criteria — the distinction that most often blurs when a client is waiting.

**The scout contract.** A fallback claim is accepted only when the scout returns three things: the sink or guard with `file:line`; the fallback (constraint, check, filter, policy) with its `file:line` or migration id; and whether the path is **outward-facing** — reachable by a client or an unauthenticated user — or internal. A verdict without those three is re-run, not summarised. Anchor: first real run, 2026-10-11 — the scout called two internal `menu.js` sinks unmitigated and the outward client-portal cell mitigated; the code said the reverse, and the inverted reason reached the read-back.

## Dependencies: Hard, Value, Soft

| Kind | Meaning | Where it lives |
|---|---|---|
| **Hard** | B cannot start, or cannot be correct, until A lands (schema, migration, foundation, auth model) | a Linear `blocked by` relation — the only kind `pk next` sees |
| **Value** | B is worth less until A ships (A proves the approach, A is the demo) | the plan's order and reason; no relation |
| **Soft** | B is easier after A | a risk note in the plan; never a relation |

A Hard dependency goes first regardless of any score. Schema and foundation tasks are almost always Hard for what sits on them. Writing a Value or Soft ordering as a `blocked by` relation pollutes the dependency truth every other tool reads; don't.

**A draft pulls its blocker in.** When a worktree already holds a draft of B, A (its Hard blocker) is a candidate for the week whether or not anything else lifts it — the draft is sunk work that A unlocks. Anchor: 2026-10-11, 1167's three-commit draft was flagged as a leak while 1154, its blocker, was absent from the briefing.

## Ranking

In order, each rule only breaking ties left by the one above:

1. **Hard dependencies first.** The blocker is scheduled before the blocked; the blocked item waits in NEXT, never in MUST.
2. **Unblock-first.** A two-hour task that releases four tickets beats a one-day task that releases none. Count what each item unblocks.
3. **Priority inversion.** A High blocked by a Low → the Low is scheduled with the High's urgency (`pk portfolio` already lifts it one step; the session makes it explicit).
4. **External commitment** beats internal preference at equal footing.
5. **Tie-break:** `(Impact + Risk) × (6 − Effort)`, each 1–5, and say the numbers so they can be disputed.

Never invent durations or a computed critical path. The data supports a longest blocker chain and coarse effort from tier labels; say that much and no more.

## Capacity

Capacity is counted in **session-days**: one Claude Code session working for one day. An engineer who runs three sessions side by side has three session-days per working day.

- **Week** = `method.config.md § Weekly capacity days`, in session-days: working days × the sessions the user actually runs on an average day. One session, six days → `6` (the default). Three sessions, five days → `15`. Peak concurrency is not the number; the average is.
- **Effort** per item from its tier label via `§ Tier effort days`, in the same unit. The default `Quick: 0.5, Standard: 2, Heavy: 4` describes one session doing everything by hand; a user who runs several sessions and lets `/work` execute has measured closer to `Quick: 0.1, Standard: 0.5, Heavy: 1`. Unsized items are **flagged**, not guessed.
- **Ask before you trust the numbers.** When either key is unset, the briefing says so, uses the default, and asks for the real figures as the first question. Both keys are proposed as rows for the key table (`§ V2`); `pk config` reads them from anywhere in the file, but the next reader looks in the key table.
- **MUST ≤ 60% of the week.** Over it, you have a scope problem, not a capacity problem — see Diagnose. Under it, the headroom is slack, not a target: nothing is pulled in to fill it unless the user asks.
- In-flight leaks count as zero capacity used once cleared, and as a tax until then.
- Show the arithmetic in the briefing (`MUST ≈ 3.9 of 15 session-days (26%)`) so it can be disputed in one line.

Anchor: first real run, 2026-10-11 — the calendar-day defaults were four to five times too large for the user; a week that was 41% full read as "your five don't fit".

## Parallel work: the independence bar

Two items may run side by side only when **all four** hold; otherwise they are sequenced, and the session says which criterion failed:

1. No blocking edge between them, in either direction.
2. No transitive path through a third item.
3. No shared unmerged foundation (a migration or shared module one of them is waiting on).
4. Provably disjoint file scope — read the specs; "probably" fails.

Fail closed. A pair that fails only criterion 4 on mechanical overlap (both add a trigger to the same table, both regenerate the schema dump) is **built in parallel and merged in sequence** — the plan says which merges first and on which day. Two or more focus-lane heads that pass the bar and are Approved can run as parallel `pk branch` + `/work` sessions.

## WAIT discipline

An item may be allowed to sit only with all three:

- a **fallback** that was read in code this session or a previous one (date it), under the scout contract;
- a **re-entry trigger** — the condition that moves it back in ("a second tenant hits it", "before the beta promote", "when 441 ships");
- its **floor priority intact** — WAIT is expressed by being out of focus and by the plan, never by lowering importance, which `/pk-bug` and `/linear-hygiene` read for other purposes.

A WAIT with no trigger is neglect with a label. A WAIT row reaches the read-back with its fallback filled, or marked `unverified — scout running` in the row; a blank cell is not a row.

## Themes

The user groups work by meaning — "the eval loop", "the <Customer> board" — and the grouping crosses lanes. The lane read cannot see it. So the briefing asks for themes and promises the board cannot show, and each theme the user names is checked: which issues it really covers, which of the named issues are something else (a bug in a neighbouring lane that merely sounds related), and whether it has three buildable issues. Three or more → a lane, cut with `/phase-plan --cut`. Fewer → a `Themes` line in the plan, carried forward so the next session sees it without being told again. Anchor: 2026-10-11, the user's "Eval Loop" was one real Langfuse theme across two initiatives plus three Smart Start / Drop Zone bugs that were not eval work.

## How to ask

- The briefing comes first and is a complete draft; questions are corrections to it.
- **One question per turn.** The one that most changes the output, with its options and your pick; then wait for the answer. Bundled questions get the first one answered and the rest lost — on the first real run the user missed the third of three. In `--quick`, at most three questions, still one per turn.
- Every question offers two or three real options with what each costs, which one you would take and why, and **what would make your pick wrong**. A question handed up without options moves the work back to the user unchanged.
- **Titles beside IDs.** Every identifier in a briefing, question, read-back, comment or plan line carries its title. The user does not know the board by number, and an ID they cannot place is a question they cannot answer.
- **Gloss the words.** The first time a term of this SOP appears in front of the user — leak, floor, criterion 4, "not changing" — say in a clause what it means. Citing the rule is not the same as being understood.
- "Just do it" → proceed, and list the assumptions at the top of the read-back and the plan.
- Judgment calls that are the user's alone are recorded with their reason, not argued.

## What Linear carries, what the plan carries

`pk next` orders by lane tier → issue priority → blocked-sinks, and nothing else. Four priority levels cannot encode a sequence, and priority already means importance elsewhere. So:

| Linear carries (coarse, tool-readable) | The weekly plan carries (exact, human-readable) |
|---|---|
| lane tiers A/B/C (project priority) | the order within and across lanes, with reasons |
| Hard dependencies (`blocked by`) | Value and Soft orderings, risk notes |
| importance (issue priority), changed only when importance changed | WAIT fallbacks and triggers |
| `[tpm]` comments — the per-item reason | the Commitments register, the capacity arithmetic, parallel-safe pairs and merge order, "not these, and why" |
| `[tpm] on-merge:` notes — a write deferred to a merge, read back by `pk done` | which session builds what, the command to run, the merge day |

`pk next` therefore prints the agreed *lanes and blockers*; the plan prints the agreed *order and the day's commands*. Promise no more than that.

## The weekly plan

One file per portfolio, in the primary repo (`§ Plan path`, default `engineering/WEEKLY_PLAN.md`), written only by `/tpm` between `<!-- tpm:begin · agreed YYYY-MM-DD … -->` and `<!-- tpm:end -->`, regenerated from each agreement. It is a **task list for the engineer**, not a digest of Linear: it opens with what to type, grouped by the concurrent sessions the user runs, and only then shows the picture. Rules that hold on every line: the issue's title beside its ID, a Linear link on the first mention, the repo to `pk branch` from when the portfolio has more than one, the effort, and the merge day when it is constrained. Sections, in this order:

```
# <Project> — Week of Mon 2026-10-12
<!-- tpm:begin · agreed 2026-10-11 · derived from Linear · written by /tpm, regenerate don't edit -->
**Agreed Sun 2026-10-11.** One commitment: <Customer> gets the reconciliation ledger, live on app.example.com, by Fri 2026-10-16.
Capacity 15 session-days. Planned: MUST 3.9 + NEXT 2.2 = 6.1.   (Assumptions: … — only after "just do it")

## Start now
| Session | Run | What | Merge |
| 1 | `pk branch PROJ-1132` | Ledger versions: never-publish guard + reconcile_note column | Mon 10-12 — first migration of the week |
| 2 | `pk branch PROJ-986`  | Store each budget version's key metrics once in the DB      | Tue 10-13 — after 1132 |
| 3 | `pk branch PROJ-546`  | Three remaining stored-XSS sinks                             | when green — no migration |

## Session 1 — <Customer> ledger  (lane A · I5.P4 Vendor Invoices vs Quotes)
- [ ] **[PROJ-1132](…) Ledger versions: never-publish guard …** · Standard 0.5 · migration
      Before merging: … Then merge **Mon 10-12**.
- [ ] **[PROJ-1130](…) Reconcile view on Compare …** · Heavy 1.0 · after 1132 · merge by **Wed 10-14**
- [ ] **Ship it.** `pk ship` → `pk promote beta` → `pk promote main` (Thu). Friday is slack.

## Session 2 — …            ## Session 3 — …            ## Free slot — …

## If the week runs long
Drop in this order: 1071 … → spec 1134 …. Sequence spills: 1167 if 1154 is late · …

## Lanes — the picture
| Tier | Lane | Flow |
| A | I5.P4 Vendor Invoices vs Quotes | 1132 Ledger guard ▸ 1130 Reconcile view ▸ promote → <Customer> Fri |
| B | I8.P6 Dashboard Redesign        | 986 Store metrics ⇢ spec 997 Read-only surfaces                            |
| C | I3.P1 XSS output-encoding       | 546 Three sinks → swap C to I7.P10                                        |
▸ hard dependency (in Linear as blocked by) · ⇢ soft order · → then

## Don't merge together
- 1132 ∥ 986 — both add triggers on budget_snapshots and regenerate the schema dump. Build side by side, merge Mon then Tue.

## Merge calendar
| Day | Migration merge (one per day) | Also merge when green |

## Commitments
| Who | What | Due | Issues | Since |

## Waiting on you  (hand work, not Linear writes)
- [ ] 1168 … → Needs Spec · remove 3 orphan worktrees (paths) · commit this file …

## Parked (WAIT) — each has a fallback read in code and a trigger to come back
| Issue | Why it can wait | Comes back when |

## Not this week, and why
PROJ-1155 … — lane out of focus · … (six words each)

## Themes  (carried until they are lanes)
Eval loop: 1115 + 963 + 1114 — under the three-issue floor until 1115's spec yields build issues.

## Notes from the session
- Grounding finding (10-11): …

### Drift since agreement  (rewritten by /tpm --check)
—
<!-- tpm:end -->
```

The example is a single-repo portfolio; a multi-repo portfolio adds a `Repo` column to the Start-now and Lanes tables and names the repo beside each issue line.

The `agreed YYYY-MM-DD` on the begin line is a contract: `pk next` reads it and prints `plan agreed Nd ago → /tpm` past `§ Plan stale days` (default 7), and `plan: no agreement yet → /tpm` while the synced skeleton's marker carries no date. The runbook's `## Now` block holds one pointer line to the plan — `This week → engineering/WEEKLY_PLAN.md · agreed 2026-10-11` — and in the other repos of the portfolio `Portfolio weekly plan → ../<primary-repo>/engineering/WEEKLY_PLAN.md · agreed 2026-10-11`: one document, reachable from either repo, never two versions. Two repos on **one** Linear board (same `Team ID`) are the common solo shape — one board, two codebases: the board is read and written once, from the primary, and the sibling's worktrees, PRs and sessions are the only thing the session reads from it.

Before v5.1.0 the agreement was the `## Now` block of the runbook itself. The runbook is how the project runs and is read when something is unfamiliar; the plan is read every morning. A consumer whose runbook still holds a full block gets it moved on the next `/tpm`.

## Comments

Every Linear write the session makes leaves its reason on the issue, so the next reader (human or `/tpm`) doesn't re-derive it:

```
[tpm 2026-10-10] MUST — <Customer> commitment, due 10-17; head of I8.P6
[tpm 2026-10-10] WAIT — fallback: boundary validation rejects (verified in src/api/validate.ts:88); trigger: 2nd tenant hits it
[tpm 2026-10-10] blocked by PROJ-377 — Hard: 398 reads the column 377 adds
[tpm 2026-10-10] commitment: <Customer> · due 2026-10-17
[tpm 2026-10-11] on-merge: pk focus I7.P10 C --swap · tier C moves to Finance settings once this merges
```

One line, the bracketed date first, so `pk issue show --comments` can be grepped for the latest. The `on-merge:` form is machine-read: `pk done` collects every `[tpm DATE] on-merge: <command> · <why>` on the issue it just closed out, prints the commands and asks before running the ones that start with `pk`. It is how a decision that depends on a merge ("the day 546 merges, C swaps") survives without anyone remembering it.

## Why not a hand-maintained plan, and why the lane map retired

A plan kept by hand outside the tracker (`deps.json`, a `PLAN.md` someone edits, a kanban app) is a second source of truth that drifts the moment an issue ships; that is why Lane (2026-06) was declined. The weekly plan is not that: it is written only by `/tpm`, from Linear, regenerated at every agreement, and Linear wins on any disagreement (`--check` says so). The lane-map artifact (v4.29.0–v4.38.0) was a picture plus a click-picker for tiers; once tiers are set by agreement with a reason attached, a picker without reasons is a step backwards and a second surface to regenerate after every write. Retired in v5.0.0. What the lane map got right — a start-now row, lanes as flows with arrows, short titles on every chip, the repo to branch from, a collision list before you parallelize — is the shape of the plan's lower half.

## Borrowed from

Surveyed 2026-10-10 across ~65 Claude Code skill files; nothing filled the role, these rules did: unblock-first ranking and the independence bar (khalilouardini/kstack), priority inversion (joa23/linear-cli), Hard/Value/Soft and the 60% bound (AI-Foundry-Core/ril-agents), scope/capacity/dependency diagnosis and slack-at-integration-points (cbrock84/headcount), options-and-a-pick-and-what-would-make-it-wrong (avelikiy/great_cto), ask-vs-job and must-haves-vs-success-criteria (deanpeters/Product-Manager-Skills), the question stop rule (borghei/Claude-Skills), re-entry triggers (rampstackco), the tie-break formula (Anthropic engineering plugin `tech-debt`). The plan's shape (2026-10-11) borrows from the retired lane map's frontier, flows and collision register.
