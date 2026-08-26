---
name: pk-bug
description: Bug pipeline — intake, reproduce, regression-test-first, fix, ship, postmortem. Wraps /work and pk ship with discipline gates. Invoke when a bug is reported or spotted. Linear is the source of truth — resume by passing the issue ID.
---

# /pk-bug Skill

You run the **bug pipeline**: a disciplined wrapper around the daily loop that enforces *regression-test-first* fixing. The point: a bug, once fixed, must never silently re-ship — there must be a test that would have caught it.

## When to use

Invoke when:
- A bug is reported by a user
- You spot a bug during dev or QA
- You're resuming a bug already in flight (`/pk-bug <ISSUE-ID>`)

Do NOT use for:
- New features (use `pk next` → `/work`)
- Spec work (use `/light-spec`)
- PR review of an unrelated change (use `/pr-fix`)

## Invocation forms

```
/pk-bug                       # new bug, prompts for everything
/pk-bug "<one-liner>"         # new bug, description prefilled
/pk-bug <ISSUE-ID>            # resume — reads Linear, routes to right phase
```

## Source of truth

**Linear is authoritative.** This skill stores no local state. Every resume reads the Linear issue (status, body, comments) and routes to the correct phase. New session safe.

Read `method.config.md` for:
- Linear team ID, workflow state IDs
- Pre-deploy gate commands

## Preflight — checkout guard  *(applies to Phases 1–2 only)*

Phases 1–2 (intake + reproduce) run from the **repo-root integration-branch checkout** (`main` or the configured integration branch). The moment Phase 2 reproduces the bug, `pk branch <ID>` cuts an isolated worktree off `origin/<integration>` (see `bin/pk`) and **every phase from 3 on runs inside that worktree** — so diagnosis, the failing test, and the fix never touch the shared integration checkout and never collide with other agents working there. (Reproduce is read-mostly; the working-tree writes that used to sit on `main` — the test file especially — now land in the worktree, committed test-first.)

Before entering Phase 1 (new bug), or any resume that routes to Phase 2, check the current checkout:

```bash
current=$(git rev-parse --abbrev-ref HEAD)
# integration = `Integration branch` from method.config.md (pk falls back to origin/dev, else origin/HEAD)
```

- You're in the repo-root checkout (not inside another `pk branch` worktree) → **proceed.** Phase 2 cuts this bug's worktree for you once it reproduces; `pk branch` bases off `origin/<integration>` regardless of which local branch you're on, so the baseline is always current integration HEAD.
- You're inside an existing `pk branch` worktree → **STOP** (running a new bug's intake/reproduce here would nest worktrees). Tell the user:
  > `/pk-bug` intake + reproduce should run from the repo-root checkout, not inside the `<other>` worktree — Phase 2 cuts this bug's own worktree once it reproduces. `cd <repo-root>` and re-invoke, or finish/park the current worktree first. (To resume a bug already past Phase 2, pass its `<ISSUE-ID>` — that routes straight into its worktree.)

This guard does **not** apply to resume routing into Phases 3–8 — by then the worktree exists and running from inside it (`statusType=started`) is the correct location.

## Resume routing

When invoked with an existing `<ISSUE-ID>`, query Linear and enter the phase below:

Routing keys off Linear's `statusType` (not display name) so projects with custom statuses like `Parked` route correctly. **If the resolved phase is 1–4, run the Preflight checkout guard above first;** phases 5–8 skip it (the worktree already exists).

| Linear state                                                            | Enter phase |
|------------------------------------------------------------------------|-------------|
| Issue not yet created                                                   | 1 — Intake |
| `statusType=backlog`, no "Reproduced:" comment                          | 2 — Reproduce (cuts the worktree on success) |
| `statusType=started`, worktree exists, **no** `test(<ID>)` commit in branch | 3 — Diagnose + Test |
| `statusType=started`, `test(<ID>)` commit exists, no fix commit          | 4 — Commit/confirm test-first, then 5 — Fix |
| `statusType=started` + PR open (or status named UAT/Review)             | 6 — PR review + merge to dev |
| Merged to dev, not on main                                              | 7 — Promote dev → main |
| `statusType=completed`, no postmortem comment (priority ≤ Medium = 3)   | 8 — Postmortem |
| `statusType=completed`, postmortem present                              | report complete, exit |

Heuristics for state detection:
- "Reproduced" = Linear comment starting with `Reproduced:` (you write this in Phase 2, just before cutting the worktree)
- "Worktree exists" = `git worktree list` shows a `<ISSUE-ID>` worktree (cut in Phase 2)
- "Test commit exists" = from inside that worktree, `git log --oneline` shows a `test(<ISSUE-ID>):` commit
- "Postmortem present" = Linear comment containing `# Postmortem` heading

For resume into Phases 3–8, `cd` into the existing `<ISSUE-ID>` worktree first (that's where the branch's work lives).

---

## Phase 1 — Intake

**Goal:** create a well-formed Linear issue.

1. Ask the user the questions in `templates/intake.md`. If a one-liner was passed, prefill the description hint.
2. **Priority heuristic** to show the user (Linear `priority` field — native, no custom labels):
   - `Urgent` (1) — data loss / auth bypass / money / production down
   - `High` (2) — core flow broken (e.g. sign-out failing for magic-link users)
   - `Medium` (3) — degraded UX, workaround exists
   - `Low` (4) — cosmetic / single-user / edge case
3. **Urgent fast path:** if user picks `Urgent`, skip detailed intake — capture one-liner + priority, mark issue body with `**Fast-path: Urgent** — fill in details during postmortem`. Postmortem becomes mandatory + reviewer sign-off in Phase 8.
4. Create Linear issue:
   - Team: from `method.config.md`
   - Status: backlog-type (e.g. `Backlog` or `Parked` — anything with `statusType=backlog`)
   - Priority: 1–4 per the heuristic above
   - Labels: `Bug` (no severity labels — priority is the native field)
   - Body: filled `templates/intake.md`
5. Echo `<ISSUE-ID>` to the user. Advance to Phase 2.

---

## Phase 2 — Reproduce  *(GATE)*

**Goal:** reproduce locally before any diagnosis.

1. Read repro steps from the Linear issue body.
2. Reproduce by the most direct path:
   - **UI bug:** Playwright MCP, walk the steps
   - **Backend logic:** `curl` / direct test invocation
   - **Auth flow** (e.g. magic-link sign-out): full e2e — sign in, observe state, sign out, assert state changed
3. **Gate decision:**
   - **Reproduced** → comment on Linear:
     ```
     Reproduced: <one-line evidence>
     - Method: <Playwright | curl | manual>
     - Artifact: <screenshot path | log snippet | n/a>
     ```
     Then **cut the worktree and move into it immediately** — every phase from here runs in isolation, off the shared integration checkout:
     ```bash
     pk branch <ISSUE-ID>     # creates worktree + branch off origin/<integration>, Linear → In Progress
     cd <worktree-path>       # pk prints the path; all of Phase 3+ runs here
     ```
     Advance to Phase 3 (inside the worktree).
   - **Cannot reproduce** → Linear status to `Triage` or label `needs-info`, comment with everything tried. **STOP. Do not guess-fix.** Inform user, exit. (No worktree was cut — you're still on the integration checkout, nothing to clean up.)

---

## Phase 3 — Diagnose + Failing Regression Test  *(GATE)*

**Goal:** find root cause AND write a test that fails because the bug exists. **Done inside the worktree** (cut in Phase 2) — the test file is written here and committed test-first in Phase 4.

### 3a — Diagnose

Use the scientific method:
1. State a hypothesis (1 sentence)
2. Verify by reading the relevant code / logs / DB
3. Narrow until you have a one-paragraph root-cause statement
4. Append the root cause to the Linear issue body under `## Root Cause`

If diagnosis takes more than ~30 minutes of investigation, consider spawning a dedicated debugging subagent (`general-purpose`) to investigate in a fresh context. Don't burn the main context on a deep dive.

### 3b — Write the failing test

Pick the right test type for the bug:

| Bug type | Test type | Location convention |
|----------|-----------|---------------------|
| Logic / data layer | Unit or integration | colocated `*.test.ts` |
| UI behavior | Playwright e2e | `tests/e2e/` |
| Pure visual / spacing | Playwright visual snapshot (`toHaveScreenshot()`) | `tests/e2e/visual/` |
| Auth / session flow | Playwright e2e (full session lifecycle) | `tests/e2e/auth/` |

**Auth-flow test shape (illustrative — adapt to your stack):**
```ts
test('user state is fully cleared after sign-out', async ({ page }) => {
  await signIn(page, testUser);
  await expect(page).toHaveURL('/dashboard');
  await signOut(page);
  await expect(page).toHaveURL('/login');
  // Critical: session is actually gone, not just UI redirect
  const cookies = await page.context().cookies();
  expect(cookies.find(c => c.name.includes('auth'))).toBeUndefined();
  await page.goto('/dashboard');
  await expect(page).toHaveURL('/login');  // protected route bounces
});
```

### Gate

Run the test. It MUST fail for the **right reason** — the bug exists, not a setup error.

- ✅ Test imports cleanly, the bug-specific assertion fails → continue
- ❌ Import error / fixture missing / timeout / 500 from setup → fix the test, do not advance

Append test path to Linear issue body under `## Regression Test`.

---

## Phase 4 — Commit the failing test  *(test-first audit trail)*

**Goal:** land the failing test as the first commit, before any fix. The worktree already exists (cut in Phase 2), so this is just the commit — no branch handoff, no stash.

1. Commit ONLY the test (from inside the worktree):
   ```
   git add <test-path>
   git commit -m "test(<ISSUE-ID>): add failing regression test for <one-liner>"
   ```
2. Verify: `git log --oneline` shows the `test(<ISSUE-ID>)` commit as the latest, and re-running the test still **fails** (the fix hasn't been written yet).

This commit is the audit trail. Anyone reading `git log` later sees the test landed before the fix — and because the test was authored in the worktree from the start, there's no orphaned-on-main / stash-handoff risk.

---

## Phase 5 — Fix + Verify + Ship

**Goal:** make the test pass, ship.

1. Hand off to `/work <ISSUE-ID>` with this directive in the prompt:
   > A regression test exists at `<test-path>` and currently fails. Your job is to make it pass without modifying the test file. The root cause is documented in the issue body under `## Root Cause`.
2. After `/work` completes:
   - Run the regression test alone — must pass
   - Run `/verify` — full pre-deploy gate
3. `pk ship` — opens PR, Linear → `UAT`
   - For auth / RLS / migration bugs: `pk ship --review` to invoke the antagonistic reviewer

---

## Phase 6 — PR review + merge to dev

1. Optional but encouraged for priority ≤ Medium (1–3):
   - Auth / security bugs → `/pr-security-review`
   - General code quality → `/pr-fix`
2. Address review feedback (commit on the same branch)
3. Merge PR to `dev`
4. `pk done <ISSUE-ID>` — verifies merged, cleans worktree+branch, posts commit summary to Linear

---

## Phase 7 — Promote dev → main

- `Urgent` → run `pk promote` immediately (solo promote, do not batch)
- `High` / `Medium` / `Low` → leave for the next batched promote. Comment on Linear: `Awaiting next dev → main promote.`

After main deploys, Linear should auto-transition to `Done` (per the existing automation).

---

## Phase 8 — Postmortem

**Mandatory for priority ≤ Medium (1–3). Optional but recommended for low.**

1. Append a Linear comment using `templates/postmortem.md`:
   - What broke (1 sentence)
   - Which gate should have caught it
   - One change to prevent recurrence
2. **Urgent only:** request reviewer sign-off in the comment thread. The bug is not closed out until that sign-off lands — **whatever state Linear is showing.**

   **Do not read this as "sign off before the issue reaches `Done`."** It almost never will. `pk ship` puts the issue ID at the front of the PR title (`bin/pk`: `--title "${issue}: ${title}"`), so wherever Linear's GitHub integration is configured to transition on merge, the issue flips to `Done` back at **Phase 6** — two phases before this one. (Phase 7's note about the deploy auto-transition is the same mechanism, one phase later.) A gate keyed on "before `Done`" is unreachable by construction: an Urgent bug arrives at `Done` with no postmortem and no sign-off, and nothing anywhere reports it. **`Done` is not evidence that this phase ran.**

   Gate on the artifact instead. An Urgent bug is closed out when its issue carries **both** a `# Postmortem` comment and a filled-in reviewer sign-off. `/linear-hygiene` Phase 2c reports issues missing either.

   *Anchor: SiteLine PIPER-766, 2026-08-25 — an Urgent bug auto-closed on merge and sat `Done` with no postmortem. It got written a day later only because the operator went looking, and it was the postmortem that found the actual gate: an ESLint rule (`no-inner-declarations`) dropped from `eslint:recommended` in v9, silently off ever since. The fix alone would have left that open for the next occurrence.*
3. If "one change to prevent recurrence" is concrete (e.g. "add Playwright e2e for every auth-method × sign-out combo"), create a follow-up Linear issue or add a rule to `.claude/rules/`.

---

## Invariants

| Rule | Enforcement |
|------|-------------|
| Phases 1–2 run from the integration checkout; Phases 3–8 run in the worktree | Preflight guard (STOP if invoked inside another worktree); Phase 2 cuts the worktree on repro |
| No fix code before failing test exists | Phase 3 writes the test; Phase 4 commits it test-first, before any fix |
| Cannot repro → STOP | Phase 2 gate; mark `needs-info`, exit (no worktree cut) |
| Linear is the source of truth | Resume always re-reads Linear, never local state |
| Postmortem mandatory for priority 1–3 | Phase 8; reviewer sign-off if Urgent. Gate on the **artifact** (a `# Postmortem` comment + filled sign-off), never on the issue reaching `Done` — the PR-title auto-transition beats Phase 8 to it |
| Urgent → solo promote | Phase 7 |
| Test commit lands before fix commit | Phase 4 commits the test; Phase 5 writes the fix |

## Failure modes to avoid

- **Don't skip Phase 2** because the bug "obviously" exists. Unrepro'd bugs get guess-fixed and ship as silent regressions.
- **Don't write the test after the fix.** A test written against passing code tests the fix, not the spec — it won't catch the same bug class re-introduced later.
- **Don't fold test + fix into one commit.** The audit trail is part of the value.
- **Don't promote `Urgent` bugs in a batch.** Blast radius mismatch.
- **Don't treat `Done` as proof Phase 8 ran.** The PR-title auto-transition closes the issue at merge, before the postmortem exists. Check for the `# Postmortem` comment, not the state.

## Common Rationalizations

| You're about to say… | The rebuttal |
|---|---|
| "The fix is obvious, repro is a waste of time" | Phase 2 is a GATE because unrepro'd bugs get guess-fixed and ship as silent regressions — and "this error is probably X" is a Red Flag, not a diagnosis. Can't repro → `needs-info`, not a guess-fix. |
| "I'll write the test after the fix" | A test written against passing code tests the fix, not the spec (Red Flags). Test-first is the audit trail — the failing commit *is* the repro record. |
| "It's urgent — skip the process" | Urgent changes the *routing* (solo promote, Phase 7), not the discipline. The postmortem stays mandatory for priority 1–3; urgency is when guess-fixes are most tempting and most expensive. |
| "Linear already says `Done` — the bug is finished" | `Done` arrived from the PR-title auto-transition at Phase 6; nobody decided the work was complete. For priority 1–3 the postmortem is still owed, and for Urgent so is the sign-off. The state is a side effect of a merge — the artifact is the evidence. |
| "It's three small bugs, I'll batch them in one run" | One bug per run — a bundle gets one repro, one test, one postmortem, and two of the three bugs lose their audit trail. Split first (`/linear-hygiene`'s bundle rule exists for the same reason). |

## Origin

Built locally in rs-vault, dogfooded on RS-94 (magic-link Enter-key OAuth misroute, 2026-05-07), promoted to Pipekit upstream after the first clean run. The pattern: build a candidate skill in a consuming project under `.claude/skills/<name>/`, dogfood on a real ticket, promote to `pipekit/skills/<name>/` once it earns its keep, sync back via `sync-method.sh`.
