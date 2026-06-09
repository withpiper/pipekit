# POC-57 — Verdict (native vs vbw, blind-judged)

> **Status: pilot (1 rep per arm), concluded by the real ship.** Scored blind by a fresh-context
> judge that never read `judge/KEY.private.txt` and grounded every load-bearing claim against the
> live SiteLine repo + the team's *actually-shipped* POC-57 migration chain. De-blinded after scoring.
> This is a **directional** data point, **not** co-equal statistical justification with POC-48
> round-two — read it as a caution flag, not a coronation.

## What POC-57 was

A head-to-head on a real SiteLine feature (MVP client **Approve** action on a published
`budget_snapshots` version — durable single sign-off; frozen contract in `SPEC.frozen.md`,
== `judge/CONTRACT.md`). Three arms off the same base (`exp/POC-57-base`):

| Arm | What it is | In judged pairing? |
|---|---|---|
| `native-1` | Pipekit `/work` **native** backend (3.0 default — task DAG on the Workflow primitive) | **yes → impl-A** |
| `vbw-1` | Pipekit `/work` **vbw** backend (`vbw-dev` executes `/work`'s inline plan) | **yes → impl-B** |
| `vbwfull-1` | The full `vbw-lead→vbw-dev→vbw-qa` pipeline ("VBW the system", which `/work` never invokes) | no — but **its DB layer is what shipped** |

The blind pairing scored was **native (A) vs vbw (B)** — the two executors `/work` actually offers.

## De-blind key

```
impl-A = native-1
impl-B = vbw-1
```

## Result — the two arms failed in opposite directions

| Criterion | native (A) | vbw (B) |
|---|---|---|
| AC1 persist + live re-render | **PARTIAL** — `approved_at` from **client clock** (forgeable, Medium) | **PASS** — `now()` server-side |
| AC2 stamp from `approved_at`, both surfaces | PASS | PASS |
| AC3 no-access write rejected at DB | PASS | PASS |
| AC4 no Approve on draft (UX+DB) | PASS | PASS |
| AC5 no re-approval (UX+DB) | PASS | PASS |
| AC6 publisher notification enqueues | **FAIL** — `SECURITY INVOKER` trigger can't call `enqueue_notification` (revoked from `authenticated`); wrapped in `RAISE WARNING` → **silently never fires** | **PARTIAL** — `SECURITY DEFINER` trigger in the *correct* context (works), but **no fail-open wrap** → a publisher who lost access **rolls back the approval** |
| Write path: **NO SECURITY DEFINER** (spec-DEFINED, POC-87) | **PASS** — plain RLS UPDATE + INVOKER guard (matches what shipped) | **FAIL** — write path is a `SECURITY DEFINER` RPC (violates a DEFINED decision) |
| Approver-identity forgery blocked | PASS | PASS |
| Timestamp forgery blocked | **FAIL** | PASS |
| Tests authored | **FAIL — zero** | **PASS** — RLS authz suite (non-mutation asserts) + `formatVersionLabel` unit tests, test-commit-first |
| Commit discipline | atomic, not test-first | atomic, test-first ordering |

### Both arms failed AC6 (notification) — the most important finding
Neither backend shipped a correct notification path. native's is dead-on-arrival (silent
permission-denied); vbw's works on the happy path but is fail-closed (missing exception wrap).
The `enqueue_notification` grant reality (revoked from `authenticated`, postgres-only, raises if
recipient lacks access) is a non-obvious landmine neither fully cleared. The shipped reference
needed a dedicated, heavily-commented migration (`...120200`) to get **both** halves right
(SECURITY DEFINER **and** `BEGIN/EXCEPTION` fail-open).

## Blind winner, and the de-blinded reading

**Blind verdict: impl-B (vbw) wins, medium confidence** — it satisfied more of the contract
(AC1–AC5 outright + AC6's hard part) and shipped a real adversarial test suite, where native
failed AC6 and left a forgeable timestamp.

**De-blinded, the honest reading is a split, not a vbw win:**

- **native got the architecture right.** Its plain-RLS / no-SECDEF write path matched both the
  spec's DEFINED POC-87 decision **and** what ultimately shipped. vbw *violated* that DEFINED
  decision with a SECDEF RPC. On the dimension the spec author cared most about, native was correct.
- **native got the execution wrong in its known weak spot.** Zero tests + a client-clock timestamp
  are exactly the failure modes a test suite catches — and "not authoring tests" is the *same* gap
  the SHIP-RUNCARD flagged as "the exact gap that cost native the blind panel." This is a **repeated**
  native weakness, not a one-off.
- **vbw was more thorough but over-reached** — tested, server-bound, working notification context,
  but bought it with a spec-violating architecture and a fail-closed edge.

If the rubric treats "violated a DEFINED decision" as a disqualifier, **native wins on compliance** —
at the cost of an untested, partially-broken delivery. That tension is the cleanest takeaway.

## How it actually resolved (the strongest signal)

The team did **not** pick a backend wholesale. The shipped feature is a **hybrid**: the QA'd DB
layer came from the `vbwfull` arm (plain RLS — native's architecture, vbw-the-system's execution),
and **native finished the consuming UI** on top of it. Even that composite needed two follow-up
migrations to close issues *both* judged arms had (`...120500` server-clock; `...120200` fail-open
notification). The real-world answer was *compose + gate*, not *crown a backend*.

## What this means for Pipekit 3.0

POC-57 does **not** overturn the native-default decision (POC-48 round-two justifies that), and it
does **not** cleanly confirm "native wins" either. Its load-bearing lesson is narrower and it
*reinforces* 3.0's design rather than challenging it:

> Native's architectural judgment is sound; its recurring weakness is execution discipline
> (test-authoring, server-side detail). That is precisely the gap the **gate layer**
> (`/verify` test-first enforcement, `/pr-security-review`, `/financial-review`) — which **both
> backends run** — exists to backstop. The safety net is the gate, not the executor.

**Caveats:** single pilot rep per arm (`-1`), so this is directional; the verdict is rubric-dependent
(compliance vs delivered-quality flip the winner); and the judged pairing excludes `vbwfull`, whose
DB layer is the one that shipped.
